import ctypes
from ctypes import wintypes

import win32api
import win32con
import win32security

SHTDN_REASON_FLAG_PLANNED = 0x80000000


def _exit_windows(flag):
    exit_windows = ctypes.WinDLL('user32', use_last_error=True).ExitWindowsEx
    exit_windows.argtypes = [wintypes.UINT, wintypes.DWORD]
    exit_windows.restype = wintypes.BOOL
    if not exit_windows(flag, SHTDN_REASON_FLAG_PLANNED):
        raise ctypes.WinError(ctypes.get_last_error())


def perform_power_action(action):
    """Request a Windows action without forcing applications to discard changes."""
    if action == 'lock':
        lock = ctypes.WinDLL('user32', use_last_error=True).LockWorkStation
        lock.argtypes = []
        lock.restype = wintypes.BOOL
        if not lock():
            raise ctypes.WinError(ctypes.get_last_error())
        return
    if action == 'logout':
        _exit_windows(win32con.EWX_LOGOFF)
        return
    if action not in ('shutdown', 'reboot', 'sleep', 'hibernate'):
        raise ValueError(f'Unknown power action: {action}')

    access = win32security.TOKEN_ADJUST_PRIVILEGES | win32security.TOKEN_QUERY
    token = win32security.OpenProcessToken(win32api.GetCurrentProcess(), access)
    previous = None
    try:
        privilege = win32security.LookupPrivilegeValue(None, win32security.SE_SHUTDOWN_NAME)
        previous = win32security.AdjustTokenPrivileges(token, False, [(privilege, win32security.SE_PRIVILEGE_ENABLED)])
        error = win32api.GetLastError()
        if error:
            raise ctypes.WinError(error)
        if action in ('sleep', 'hibernate'):
            suspend = ctypes.WinDLL('powrprof', use_last_error=True).SetSuspendState
            suspend.argtypes = [ctypes.c_ubyte, ctypes.c_ubyte, ctypes.c_ubyte]
            suspend.restype = ctypes.c_ubyte
            if not suspend(action == 'hibernate', False, False):
                raise ctypes.WinError(ctypes.get_last_error())
        else:
            flag = win32con.EWX_POWEROFF if action == 'shutdown' else win32con.EWX_REBOOT
            _exit_windows(flag)
    finally:
        try:
            if previous is not None:
                win32security.AdjustTokenPrivileges(token, False, previous)
        finally:
            token.Close()
