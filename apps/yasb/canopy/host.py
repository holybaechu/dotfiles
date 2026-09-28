"""Small Canopy fixes for YASB's Windows host integration."""

from __future__ import annotations

import logging

import pywintypes
import win32api
import win32con

from core.utils.win32 import app_bar


_OriginalWin32AppBar = app_bar.Win32AppBar


def _monitor_info(hwnd):
    """Return the window's native monitor, with no primary-screen fallback."""
    try:
        monitor = win32api.MonitorFromWindow(int(hwnd), win32con.MONITOR_DEFAULTTONULL)
        return (int(monitor), win32api.GetMonitorInfo(monitor)) if monitor else None
    except (TypeError, ValueError, OSError, pywintypes.error):
        return None


def window_monitor_identity(hwnd):
    """Resolve a bar HWND to the monitor ID and Windows DISPLAY name."""
    found = _monitor_info(hwnd)
    if not found:
        return {'id': None, 'name': ''}
    monitor, info = found
    device = info.get('Device', '')
    return {'id': monitor, 'name': device.rsplit('\\', 1)[-1] if device else ''}


class PhysicalWin32AppBar(_OriginalWin32AppBar):
    """Send physical monitor coordinates to the Win32 AppBar API."""

    def create_appbar(self, hwnd, *args, **kwargs):
        if _monitor_info(hwnd) is None:
            logging.warning('Skipping Canopy AppBar registration for a disconnected window monitor: %s', hwnd)
            return
        return super().create_appbar(hwnd, *args, **kwargs)

    def position_bar(self, app_bar_height, screen, scale_screen=False, bar_name=None):
        found = _monitor_info(self.app_bar_data.hWnd)
        if not found:
            logging.warning('Skipping Canopy AppBar positioning for a disconnected window monitor')
            return
        _monitor, info = found
        left, top, right, bottom = info['Monitor']
        height = min(bottom - top, max(1, round(app_bar_height * screen.devicePixelRatio())))
        rect = self.app_bar_data.rc
        rect.left, rect.right = left, right
        if self.app_bar_data.uEdge == app_bar.AppBarEdge.Top:
            rect.top, rect.bottom = top, top + height
        else:
            rect.top, rect.bottom = bottom - height, bottom
        logging.debug('Canopy AppBar %s physical rect: %s, DPR %.2f', bar_name or '', (rect.left, rect.top, rect.right, rect.bottom), screen.devicePixelRatio())


def install_host_fixes():
    """Patch the module Bar uses before YASB creates any bars."""
    app_bar.Win32AppBar = PhysicalWin32AppBar
