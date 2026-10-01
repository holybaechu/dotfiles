import ctypes
from types import SimpleNamespace

import pytest
from core.widgets.canopy import taskbar


@pytest.fixture
def native(monkeypatch):
    windows = {
        100: ['Shell_TrayWnd', 7, True, True],
        200: ['Shell_SecondaryTrayWnd', 7, True, True],
        300: ['Shell_TrayWnd', 99, True, True],  # YASB's tray proxy
    }
    state = [3]  # ABS_AUTOHIDE | ABS_ALWAYSONTOP

    def find(parent, previous, name, title):
        return next((hwnd for hwnd, item in windows.items() if hwnd > previous and item[0] == name), 0)

    def appbar(message, pointer):
        data = ctypes.cast(pointer, ctypes.POINTER(taskbar._AppBarData)).contents
        if message == 10:
            state[0] = data.lParam
        return state[0]

    monkeypatch.setattr(taskbar.win32gui, 'FindWindowEx', find)
    monkeypatch.setattr(taskbar.win32process, 'GetWindowThreadProcessId', lambda hwnd: (1, 7 if hwnd == 10 else windows[hwnd][1]))
    monkeypatch.setattr(taskbar.win32gui, 'IsWindowEnabled', lambda hwnd: windows[hwnd][2])
    monkeypatch.setattr(taskbar.win32gui, 'IsWindowVisible', lambda hwnd: windows[hwnd][3])
    monkeypatch.setattr(taskbar.win32gui, 'EnableWindow', lambda hwnd, value: windows[hwnd].__setitem__(2, bool(value)))
    monkeypatch.setattr(taskbar.win32gui, 'ShowWindow', lambda hwnd, value: windows[hwnd].__setitem__(3, value != taskbar.win32con.SW_HIDE))
    driver = taskbar.WindowsTaskbar.__new__(taskbar.WindowsTaskbar)
    driver._shell_window = lambda: 10
    driver._appbar = appbar
    driver._original_state = None
    driver._original_windows = {}
    return SimpleNamespace(driver=driver, windows=windows, state=state)


def test_default_off_covers_all_monitors_without_disabling_canopy_tray_and_restores_on_exit(app, native):
    controller = taskbar.TaskbarController(driver=native.driver)
    try:
        controller.refresh()
        assert native.driver.read() is False
        assert native.windows[100][2:] == native.windows[200][2:] == [False, False]
        assert native.windows[300][2:] == [True, True]
        controller.set_enabled(True)
        assert native.driver.read() is True
        assert native.state[0] == 2
        controller.set_enabled(False)
        assert native.driver.read() is False
        # Explorer can recreate a taskbar while Canopy is running.
        native.windows[100][3] = True
        native.windows[400] = ['Shell_SecondaryTrayWnd', 7, True, True]
        controller.refresh()
        assert native.windows[100][2:] == [False, False]
        assert native.windows[400][2:] == [False, False]
    finally:
        controller.shutdown()
    assert native.driver.read() is True
    assert native.state[0] == 3
    assert native.windows[400][2:] == [True, True]
    assert not controller.timer.isActive()


def test_denied_taskbar_change_reports_actual_state_and_can_be_restored(app, native, monkeypatch):
    controller = taskbar.TaskbarController(driver=native.driver)
    snapshots = []
    controller.changed.connect(lambda value, error: snapshots.append((value, error)))
    try:
        monkeypatch.setattr(taskbar.win32gui, 'EnableWindow', lambda *_: None)
        controller.refresh()
        assert snapshots[-1][0] is None
        assert 'did not confirm' in snapshots[-1][1]
    finally:
        controller.shutdown()
    assert native.driver.read() is True
