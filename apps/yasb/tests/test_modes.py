import asyncio
import ctypes
from ctypes import wintypes
from threading import Event
from types import SimpleNamespace
from uuid import UUID

from PyQt6.QtTest import QTest

from core.widgets.canopy import system_modes


def test_windows_saver_reads_standard_savings_and_toggles_the_correct_direction(monkeypatch):
    # Windows 11 on AC: Energy saver is standard (1), while the legacy flag is 0.
    state = [1]
    writes, registrations, releases = [], [], []
    callback_type = ctypes.WINFUNCTYPE(wintypes.ULONG, ctypes.c_void_p, wintypes.ULONG, ctypes.c_void_p)
    guid = UUID('550e8400-e29b-41d4-a716-446655440000').bytes_le

    def legacy_status(output):
        ctypes.cast(output, ctypes.POINTER(wintypes.BYTE))[3] = 0
        return True

    def register(setting, flags, subscription, handle):
        assert ctypes.string_at(setting, 16) == guid
        assert flags == 2
        callback = callback_type(ctypes.cast(subscription, ctypes.POINTER(ctypes.c_void_p))[0])
        payload = ctypes.create_string_buffer(guid + (4).to_bytes(4, 'little') + state[0].to_bytes(4, 'little'))
        ctypes.cast(handle, ctypes.POINTER(wintypes.HANDLE))[0] = 123
        registrations.append(123)
        callback(None, 0x8013, ctypes.addressof(payload))
        return 0

    def unregister(handle):
        releases.append(handle.value)
        return 0

    def publish(name, type_id, payload, size, scope):
        value = ctypes.cast(payload, ctypes.POINTER(wintypes.DWORD)).contents.value
        assert name == 0x41C6013DA3BC3075 and size == 4
        assert value in (1, 2)
        writes.append(value)
        state[0] = 1 if value == 1 else 0
        return 0

    libraries = {
        'kernel32': SimpleNamespace(GetSystemPowerStatus=legacy_status),
        'powrprof': SimpleNamespace(PowerSettingRegisterNotification=register,
                                   PowerSettingUnregisterNotification=unregister),
        'ntdll': SimpleNamespace(RtlPublishWnfStateData=publish),
    }
    monkeypatch.setattr(system_modes.ctypes, 'WinDLL', lambda name, **kwargs: libraries[name])
    driver = system_modes.WindowsModes()
    assert driver.read('battery_saver') is True
    driver.write('battery_saver', False)
    assert driver.read('battery_saver') is False
    driver.write('battery_saver', True)
    assert driver.read('battery_saver') is True
    assert writes == [2, 1]
    assert len(registrations) == 3 and releases == registrations


def wait_until(predicate, timeout=2000):
    for _ in range(timeout // 10):
        if predicate():
            return
        QTest.qWait(10)
    assert predicate()


class FakeModes:
    def __init__(self):
        self.values = {mode: False for mode in system_modes.MODE_NAMES}
        self.writes = []

    def read(self, mode):
        return self.values[mode]

    def write(self, mode, value):
        self.writes.append((mode, value))
        self.values[mode] = value


def test_native_writes_run_off_ui_thread_and_confirm_readback(app):
    started, release = Event(), Event()

    class DelayedModes(FakeModes):
        def write(self, mode, value):
            started.set()
            assert release.wait(2)
            super().write(mode, value)

    driver = DelayedModes()
    service = system_modes.SystemModes(driver=driver)
    snapshots, pending = [], []
    service.changed.connect(snapshots.append)
    service.pending_changed.connect(lambda mode, value: pending.append((mode, value)))
    try:
        wait_until(lambda: snapshots)
        assert service.set_mode('airplane_mode', True)
        assert not service.set_mode('airplane_mode', False)
        wait_until(started.is_set)
        assert pending == [('airplane_mode', True)]
        assert snapshots[-1]['airplane_mode'] is False
        release.set()
        wait_until(lambda: len(pending) == 2)
        assert snapshots[-1]['airplane_mode'] is True
        assert pending[-1] == ('airplane_mode', False)
    finally:
        release.set()
        service.shutdown()
    assert not service._worker.isRunning()


def test_native_write_failure_preserves_real_state_and_reports_error(app):
    class DeniedModes(FakeModes):
        def write(self, mode, value):
            raise OSError('Access denied by Windows')

    service = system_modes.SystemModes(driver=DeniedModes())
    snapshots, errors, pending = [], [], []
    service.changed.connect(snapshots.append)
    service.failed.connect(errors.append)
    service.pending_changed.connect(lambda mode, value: pending.append((mode, value)))
    try:
        wait_until(lambda: snapshots)
        service.set_mode('battery_saver', True)
        wait_until(lambda: errors)
        assert snapshots[-1]['battery_saver'] is False
        assert 'Access denied' in errors[0]
        assert pending[-1] == ('battery_saver', False)
    finally:
        service.shutdown()


def test_radio_permission_denial_never_reaches_native_writer(app):
    async def exercise():
        async def denied():
            return False

        driver = FakeModes()
        service = system_modes.SystemModes(driver=driver, request_radio_access=denied)
        errors = []
        service.failed.connect(errors.append)
        try:
            service.set_mode('wifi_enabled', True)
            await asyncio.sleep(0)
            assert errors and 'denied permission' in errors[0]
            assert not driver.writes
            assert not service._pending
        finally:
            service.shutdown()
    asyncio.run(exercise())


def test_unconfirmed_native_change_never_reports_on(app):
    class IgnoredWrite(FakeModes):
        def write(self, mode, enabled):
            self.writes.append((mode, enabled))

    service = system_modes.SystemModes(driver=IgnoredWrite())
    service._worker.confirmation_timeout = .01
    errors, snapshots = [], []
    service.failed.connect(errors.append)
    service.changed.connect(snapshots.append)
    try:
        service.set_mode('battery_saver', True)
        wait_until(lambda: errors)
        assert 'did not confirm' in errors[0]
        assert snapshots[-1]['battery_saver'] is False
        assert not service._pending
    finally:
        service.shutdown()
