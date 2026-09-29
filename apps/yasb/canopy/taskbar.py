"""Temporarily disable Explorer's taskbars while Canopy owns the desktop bar."""
import ctypes
from ctypes import wintypes
import logging

import win32con
import win32gui
import win32process
from PyQt6.QtCore import QObject, QTimer, pyqtSignal


class _AppBarData(ctypes.Structure):
    _fields_ = [('cbSize', wintypes.DWORD), ('hWnd', wintypes.HWND),
                ('uCallbackMessage', wintypes.UINT), ('uEdge', wintypes.UINT),
                ('rc', wintypes.RECT), ('lParam', ctypes.c_ssize_t)]


class WindowsTaskbar:
    def __init__(self):
        self._shell_window = ctypes.WinDLL('user32').GetShellWindow
        self._shell_window.argtypes = []
        self._shell_window.restype = wintypes.HWND
        self._appbar = ctypes.WinDLL('shell32').SHAppBarMessage
        self._appbar.argtypes = [wintypes.DWORD, ctypes.POINTER(_AppBarData)]
        self._appbar.restype = ctypes.c_size_t
        self._original_state = None
        self._original_windows = {}

    def windows(self):
        shell = self._shell_window()
        if not shell:
            return []
        explorer_pid = win32process.GetWindowThreadProcessId(shell)[1]
        windows = []
        for name in ('Shell_TrayWnd', 'Shell_SecondaryTrayWnd'):
            hwnd = 0
            while hwnd := win32gui.FindWindowEx(0, hwnd, name, None):
                # YASB also owns a Shell_TrayWnd for tray callbacks. Leave it alone.
                if win32process.GetWindowThreadProcessId(hwnd)[1] == explorer_pid:
                    windows.append(hwnd)
        return windows

    def _state(self, hwnd, value=None):
        data = _AppBarData()
        data.cbSize = ctypes.sizeof(data)
        data.hWnd = hwnd
        if value is not None:
            data.lParam = value
            self._appbar(10, ctypes.byref(data))  # ABM_SETSTATE
        return int(self._appbar(4, ctypes.byref(data)))  # ABM_GETSTATE

    def read(self):
        windows = self.windows()
        if not windows:
            return None
        states = [(bool(win32gui.IsWindowEnabled(hwnd)), bool(win32gui.IsWindowVisible(hwnd))) for hwnd in windows]
        if all(enabled and visible for enabled, visible in states):
            return True
        return False if all(not enabled and not visible for enabled, visible in states) else None

    def set_enabled(self, enabled):
        windows = self.windows()
        if not windows:
            raise OSError('The Windows taskbar is unavailable in this session.')
        state = self._state(windows[0])
        if self._original_state is None:
            self._original_state = state
        for hwnd in windows:
            key = (hwnd, win32process.GetWindowThreadProcessId(hwnd)[1])
            self._original_windows.setdefault(key, (bool(win32gui.IsWindowEnabled(hwnd)), bool(win32gui.IsWindowVisible(hwnd))))
        # Release the taskbar's reserved screen space before hiding its windows.
        target = state & ~1 if enabled else state | 1  # ABS_AUTOHIDE
        if state != target and self._state(windows[0], target) != target:
            raise OSError('Windows did not confirm the taskbar layout change.')
        for hwnd in windows:
            if bool(win32gui.IsWindowEnabled(hwnd)) != enabled:
                win32gui.EnableWindow(hwnd, enabled)
            if bool(win32gui.IsWindowVisible(hwnd)) != enabled:
                win32gui.ShowWindow(hwnd, win32con.SW_SHOWNA if enabled else win32con.SW_HIDE)
        if self.read() is not enabled:
            raise OSError('Windows did not confirm the taskbar visibility change.')

    def restore(self):
        windows = self.windows()
        if self._original_state is None or not windows:
            return
        for hwnd in windows:
            key = (hwnd, win32process.GetWindowThreadProcessId(hwnd)[1])
            enabled, visible = self._original_windows.get(key, (True, True))
            win32gui.EnableWindow(hwnd, enabled)
            win32gui.ShowWindow(hwnd, win32con.SW_SHOWNA if visible else win32con.SW_HIDE)
        self._state(windows[0], self._original_state)


class TaskbarController(QObject):
    changed = pyqtSignal(object, str)

    def __init__(self, parent=None, *, driver=None):
        super().__init__(parent)
        self.driver = driver or WindowsTaskbar()
        self.enabled = False
        self._last = None
        self._closed = False
        self.timer = QTimer(self)
        self.timer.setInterval(500)
        self.timer.timeout.connect(self.refresh)
        self.timer.start()
        QTimer.singleShot(0, self.refresh)

    def _publish(self, error=''):
        try:
            state = self.driver.read()
        except Exception as failure:
            state, error = None, str(failure)
        result = (state, error)
        if result != self._last:
            self._last = result
            if error:
                logging.warning('Could not change Windows Taskbar: %s', error)
            self.changed.emit(*result)

    def refresh(self):
        if self._closed:
            return
        try:
            # Explorer and display changes can recreate or show taskbar windows.
            if not self.enabled:
                self.driver.set_enabled(False)
            self._publish()
        except Exception as error:
            self._publish(str(error))

    def set_enabled(self, enabled):
        if self._closed:
            return
        try:
            self.driver.set_enabled(enabled)
            self.enabled = enabled
            self._publish()
        except Exception as error:
            self._publish(str(error))

    def shutdown(self):
        if self._closed:
            return
        self._closed = True
        self.timer.stop()
        try:
            self.driver.restore()
        except Exception:
            logging.exception('Could not restore Windows Taskbar on exit.')
