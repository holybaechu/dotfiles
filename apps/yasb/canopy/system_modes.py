"""Native mode switches with asynchronous writes and verified Windows readback."""
from __future__ import annotations

import ctypes
import asyncio
from ctypes import wintypes
from queue import Queue
from threading import Event
import time

from PyQt6.QtCore import QObject, QThread, pyqtSignal
from PyQt6.QtWidgets import QApplication

MODE_NAMES = {'wifi_enabled': 'Wi-Fi', 'bluetooth_enabled': 'Bluetooth',
              'airplane_mode': 'Airplane mode', 'battery_saver': 'Battery saver'}


class _SystemPowerStatus(ctypes.Structure):
    _fields_ = [
        ('ACLineStatus', wintypes.BYTE),
        ('BatteryFlag', wintypes.BYTE),
        ('BatteryLifePercent', wintypes.BYTE),
        ('SystemStatusFlag', wintypes.BYTE),
        ('BatteryLifeTime', wintypes.DWORD),
        ('BatteryFullLifeTime', wintypes.DWORD),
    ]


def _read_power_status():
    kernel32 = ctypes.WinDLL('kernel32', use_last_error=True)
    read = kernel32.GetSystemPowerStatus
    read.argtypes = [ctypes.POINTER(_SystemPowerStatus)]
    read.restype = wintypes.BOOL
    status = _SystemPowerStatus()
    if not read(ctypes.byref(status)):
        raise ctypes.WinError(ctypes.get_last_error())
    return status


def battery_saver_enabled() -> bool | None:
    """Return the documented saver flag; never guess from charge or power mode.

    https://learn.microsoft.com/windows/win32/api/winbase/ns-winbase-system_power_status
    """
    try:
        flag = _read_power_status().SystemStatusFlag
        return bool(flag) if flag in (0, 1) else None
    except (OSError, AttributeError):
        return None


def _radio_manager():
    # The same native interface used by Windows' radio management UI.
    # https://github.com/fafalone/RadioMan
    from comtypes import GUID, IUnknown, COMMETHOD, HRESULT, CoCreateInstance

    class IRadioManager(IUnknown):
        _iid_ = GUID('{DB3AFBFB-08E6-46C6-AA70-BF9A34C30AB7}')
        _methods_ = [
            COMMETHOD([], HRESULT, 'IsRMSupported', (['out'], ctypes.POINTER(wintypes.DWORD), 'supported')),
            COMMETHOD([], HRESULT, 'GetUIRadioInstances', (['out'], ctypes.POINTER(ctypes.c_void_p), 'instances')),
            COMMETHOD([], HRESULT, 'GetSystemRadioState',
                      (['out'], ctypes.POINTER(wintypes.BOOL), 'enabled'),
                      (['out'], ctypes.POINTER(wintypes.BOOL), 'hardware'),
                      (['out'], ctypes.POINTER(wintypes.DWORD), 'reason')),
            COMMETHOD([], HRESULT, 'SetSystemRadioState', (['in'], wintypes.BOOL, 'enabled')),
        ]

    return CoCreateInstance(GUID('{581333F6-28DB-41BE-BC7A-FF201F12F3F6}'),
                            interface=IRadioManager, clsctx=4)


class WindowsModes:
    def read(self, mode):
        if mode in ('wifi_enabled', 'bluetooth_enabled'):
            return asyncio.run(_radio_state(mode))
        if mode == 'battery_saver':
            return battery_saver_enabled()
        if mode != 'airplane_mode':
            raise ValueError('Unknown system mode.')
        radio = _radio_manager()
        if not radio.IsRMSupported():
            return None
        enabled, _, _ = radio.GetSystemRadioState()
        return not bool(enabled) if enabled in (0, 1) else None

    def write(self, mode, enabled):
        if mode in ('wifi_enabled', 'bluetooth_enabled'):
            asyncio.run(_set_radio_state(mode, enabled))
        elif mode == 'airplane_mode':
            radio = _radio_manager()
            if not radio.IsRMSupported():
                raise OSError('Airplane mode is unavailable on this device.')
            # This API controls radio enablement, the inverse of Airplane mode.
            radio.SetSystemRadioState(int(not enabled))
        elif mode == 'battery_saver':
            _set_battery_saver(enabled)
        else:
            raise ValueError('Unknown system mode.')


def _set_battery_saver(enabled):
    # Verified against the installed Windows 11 SettingsHandlers_OneCore_BatterySaver.dll:
    # its simple toggle publishes DWORD 2 for on, 1 for off. No power-plan changes.
    _publish_saver_override(2 if enabled else 1)


def _publish_saver_override(value):
    ntdll = ctypes.WinDLL('ntdll')
    publish = ntdll.RtlPublishWnfStateData
    publish.argtypes = [ctypes.c_ulonglong, ctypes.c_void_p, ctypes.c_void_p,
                        wintypes.ULONG, ctypes.c_void_p]
    publish.restype = wintypes.LONG
    payload = wintypes.DWORD(value)
    status = publish(0x41C6013DA3BC3075, None, ctypes.byref(payload), ctypes.sizeof(payload), None)
    if status < 0:
        raise OSError(f'Windows refused the battery saver change (NTSTATUS 0x{status & 0xffffffff:08X}).')


async def _matching_radios(mode):
    from winrt.windows.devices.radios import Radio, RadioKind
    kind = RadioKind.WI_FI if mode == 'wifi_enabled' else RadioKind.BLUETOOTH
    return [radio for radio in await Radio.get_radios_async() if radio.kind == kind]


async def _radio_state(mode):
    from winrt.windows.devices.radios import RadioState
    radios = await _matching_radios(mode)
    if not radios:
        return None
    if any(radio.state == RadioState.ON for radio in radios):
        return True
    return False if any(radio.state == RadioState.OFF for radio in radios) else None


async def _set_radio_state(mode, enabled):
    from winrt.windows.devices.radios import RadioAccessStatus, RadioState
    radios = await _matching_radios(mode)
    if not radios:
        raise OSError(f'No {MODE_NAMES[mode]} radio was found.')
    for radio in radios:
        if radio.state == RadioState.DISABLED:
            raise OSError(f'{MODE_NAMES[mode]} is disabled by hardware or Windows policy.')
        # Do not request permission from the background thread or during discovery.
        result = await radio.set_state_async(RadioState.ON if enabled else RadioState.OFF)
        if result != RadioAccessStatus.ALLOWED:
            raise OSError(f'Windows denied access to the {MODE_NAMES[mode]} radio.')


async def _request_radio_access():
    from winrt.windows.devices.radios import Radio, RadioAccessStatus
    return await Radio.request_access_async() == RadioAccessStatus.ALLOWED


class _ModeWorker(QThread):
    snapshot = pyqtSignal(dict)
    completed = pyqtSignal(str, str)
    confirmation_timeout = 4

    def __init__(self, driver):
        super().__init__()
        self.driver = driver
        self.commands = Queue()
        self.stopping = Event()

    def _read(self):
        values = {'mode_errors': {}}
        for mode in MODE_NAMES:
            try:
                values[mode] = self.driver.read(mode)
                if values[mode] is None:
                    values['mode_errors'][mode] = f'{MODE_NAMES[mode]} is unavailable on this device.'
            except Exception as error:
                values[mode] = None
                values['mode_errors'][mode] = str(error)
        return values

    def run(self):
        import pythoncom

        pythoncom.CoInitialize()
        try:
            while not self.stopping.is_set():
                item = self.commands.get()
                if item is None:
                    break
                mode, enabled = item
                error_message = ''
                if mode:
                    try:
                        self.driver.write(mode, enabled)
                        deadline = time.monotonic() + self.confirmation_timeout
                        while not self.stopping.is_set():
                            if self.driver.read(mode) is enabled:
                                break
                            if time.monotonic() >= deadline:
                                raise OSError(f'Windows did not confirm the change to {MODE_NAMES[mode]}.')
                            self.stopping.wait(.1)
                    except Exception as error:
                        error_message = str(error)
                if not self.stopping.is_set():
                    values = self._read()
                    if error_message:
                        values['mode_errors'][mode] = error_message
                    self.snapshot.emit(values)
                    self.completed.emit(mode, error_message)
        finally:
            pythoncom.CoUninitialize()


class SystemModes(QObject):
    changed = pyqtSignal(dict)
    pending_changed = pyqtSignal(str, bool)
    failed = pyqtSignal(str)
    _retiring = []

    def __init__(self, parent=None, *, driver=None, request_radio_access=None):
        super().__init__(parent)
        self._closed = False
        self._refresh_pending = False
        self._pending = set()
        self._access_request = request_radio_access or (_request_radio_access if driver is None else None)
        self._radio_access_allowed = self._access_request is None
        self._radio_requests = {}
        self._access_task = None
        self._worker = _ModeWorker(driver or WindowsModes())
        self._worker.snapshot.connect(self._on_snapshot)
        self._worker.completed.connect(self._on_completed)
        if parent:
            parent.destroyed.connect(self.shutdown)
        app = QApplication.instance()
        if app:
            app.aboutToQuit.connect(self.shutdown)
        self._worker.start()
        self.refresh()

    def refresh(self):
        if not self._closed and not self._refresh_pending:
            self._refresh_pending = True
            self._worker.commands.put(('', False))

    def set_mode(self, mode, enabled):
        if self._closed or mode not in MODE_NAMES or mode in self._pending:
            return False
        self._pending.add(mode)
        self.pending_changed.emit(mode, True)
        if mode in ('wifi_enabled', 'bluetooth_enabled') and not self._radio_access_allowed:
            self._radio_requests[mode] = bool(enabled)
            if self._access_task is None:
                try:
                    # Called by the card on the qasync GUI thread, only after a user click.
                    self._access_task = asyncio.get_running_loop().create_task(self._authorize_radios())
                except RuntimeError:
                    self._radio_requests.pop(mode, None)
                    self._on_completed(mode, 'The Windows radio permission request needs the desktop event loop.')
        else:
            self._worker.commands.put((mode, bool(enabled)))
        return True

    async def _authorize_radios(self):
        error = ''
        try:
            if not await self._access_request():
                error = 'Windows denied permission to control device radios.'
            else:
                self._radio_access_allowed = True
        except asyncio.CancelledError:
            return
        except Exception as failure:
            error = str(failure)
        finally:
            self._access_task = None
        requests, self._radio_requests = self._radio_requests, {}
        if not self._closed:
            for mode, enabled in requests.items():
                if error:
                    self._on_completed(mode, error)
                else:
                    self._worker.commands.put((mode, enabled))

    def _on_snapshot(self, values):
        if not self._closed:
            self.changed.emit(values)

    def _on_completed(self, mode, error):
        if self._closed:
            return
        if mode:
            self._pending.discard(mode)
            self.pending_changed.emit(mode, False)
            if error:
                if mode in ('wifi_enabled', 'bluetooth_enabled'):
                    self._radio_access_allowed = self._access_request is None
                self.failed.emit(f'Could not change {MODE_NAMES[mode]}. {error}')
        else:
            self._refresh_pending = False

    def shutdown(self):
        if self._closed:
            return
        self._closed = True
        if self._access_task:
            self._access_task.cancel()
        self._worker.stopping.set()
        self._worker.commands.put(None)
        if not self._worker.wait(2000):
            # Never destroy a QThread while Windows is finishing a COM request.
            self._retiring.append(self._worker)
            worker = self._worker
            worker.finished.connect(lambda: self._retiring.remove(worker) if worker in self._retiring else None)
