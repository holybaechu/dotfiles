import ctypes
from ctypes import wintypes


class GuiThreadInfo(ctypes.Structure):
    _fields_ = [('cbSize', wintypes.DWORD), ('flags', wintypes.DWORD), ('active', wintypes.HWND), ('focus', wintypes.HWND), ('capture', wintypes.HWND), ('menu', wintypes.HWND), ('move', wintypes.HWND), ('caret', wintypes.HWND), ('rect', wintypes.RECT)]


def menu_active():
    info = GuiThreadInfo()
    info.cbSize = ctypes.sizeof(info)
    return bool(ctypes.windll.user32.GetGUIThreadInfo(0, ctypes.byref(info)) and info.flags & 0x1C)


def reduced_motion():
    enabled = wintypes.BOOL(True)
    ctypes.windll.user32.SystemParametersInfoW(0x1042, 0, ctypes.byref(enabled), 0)
    return not bool(enabled.value)


def disable_native_rounding(widget):
    value = ctypes.c_int(1)
    ctypes.windll.dwmapi.DwmSetWindowAttribute(wintypes.HWND(int(widget.winId())), 33, ctypes.byref(value), ctypes.sizeof(value))


def monitor_identity(device):
    import win32api
    import pywintypes
    active = []
    index = 0
    while True:
        try:
            display = win32api.EnumDisplayDevices(device, index, 1)
        except pywintypes.error:
            break
        if display.StateFlags & 1:
            active.append(display.DeviceID)
        index += 1
    return active[0] if len(active) == 1 else None
