from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from PyQt6.QtCore import QObject
from core.widgets.canopy import power
from core.widgets.canopy.backend import Backend
from core.widgets.canopy.model import PreviewBackend, State


@pytest.fixture
def native(monkeypatch):
    token = Mock()
    previous = [(123, 0)]
    adjust = Mock(return_value=previous)
    exit_windows = Mock(return_value=True)
    suspend = Mock(return_value=True)
    lock = Mock(return_value=True)
    monkeypatch.setattr(power.win32api, 'GetCurrentProcess', lambda: 1)
    monkeypatch.setattr(power.win32api, 'GetLastError', lambda: 0)
    monkeypatch.setattr(power.win32security, 'OpenProcessToken', Mock(return_value=token))
    monkeypatch.setattr(power.win32security, 'LookupPrivilegeValue', lambda *_: 123)
    monkeypatch.setattr(power.win32security, 'AdjustTokenPrivileges', adjust)
    monkeypatch.setattr(power.ctypes, 'WinDLL', lambda *_, **__: SimpleNamespace(SetSuspendState=suspend, LockWorkStation=lock, ExitWindowsEx=exit_windows))
    return SimpleNamespace(token=token, previous=previous, adjust=adjust, exit=exit_windows, suspend=suspend, lock=lock)


@pytest.mark.parametrize('action, flag', [('shutdown', power.win32con.EWX_POWEROFF), ('reboot', power.win32con.EWX_REBOOT)])
def test_shutdown_preserves_unsaved_applications_and_restores_privilege(native, action, flag):
    power.perform_power_action(action)
    native.exit.assert_called_once_with(flag, 0x80000000)
    native.adjust.assert_called_with(native.token, False, native.previous)
    native.token.Close.assert_called_once()


def test_denied_privilege_never_requests_suspend(native, monkeypatch, app):
    monkeypatch.setattr(power.win32api, 'GetLastError', lambda: 1300)
    backend = Backend.__new__(Backend)
    QObject.__init__(backend)
    backend.state = State()
    backend.power_action('sleep')
    assert 'Could not sleep' in backend.state.error
    native.suspend.assert_not_called()
    native.exit.assert_not_called()
    native.adjust.assert_called_with(native.token, False, native.previous)
    native.token.Close.assert_called_once()
    backend.deleteLater()


def test_failed_sleep_restores_privilege_and_keeps_wake_events(native, monkeypatch):
    native.suspend.return_value = False
    monkeypatch.setattr(power.ctypes, 'get_last_error', lambda: 5)
    with pytest.raises(OSError):
        power.perform_power_action('sleep')
    native.suspend.assert_called_once_with(False, False, False)
    native.adjust.assert_called_with(native.token, False, native.previous)
    native.token.Close.assert_called_once()


def test_preview_power_actions_do_not_reach_windows(native):
    for action in ('lock', 'logout', 'sleep', 'hibernate', 'reboot', 'shutdown'):
        PreviewBackend.power_action(None, action)
    native.lock.assert_not_called()
    native.suspend.assert_not_called()
    native.exit.assert_not_called()
    native.adjust.assert_not_called()
