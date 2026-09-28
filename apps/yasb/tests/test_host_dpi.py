from types import SimpleNamespace

import pytest

from core.utils.win32 import app_bar
from core.widgets.canopy import host


@pytest.mark.parametrize('ratio,expected_height', [(1, 40), (1.25, 50), (1.5, 60), (2, 80)])
@pytest.mark.parametrize('edge', [app_bar.AppBarEdge.Top, app_bar.AppBarEdge.Bottom])
def test_appbar_uses_physical_monitor_rect_at_native_dpi(monkeypatch, ratio, expected_height, edge):
    physical = (-2880, -720, 0, 1080)
    monkeypatch.setattr(host, '_monitor_info', lambda hwnd: (91, {'Monitor': physical, 'Device': r'\\.\DISPLAY2'}))
    bar = host.PhysicalWin32AppBar()
    bar.app_bar_data = SimpleNamespace(hWnd=42, uEdge=edge, rc=SimpleNamespace(left=0, top=0, right=0, bottom=0))
    # Deliberately unlike the native monitor: Qt uses logical geometry on mixed-DPI desktops.
    screen = SimpleNamespace(devicePixelRatio=lambda: ratio, geometry=lambda: SimpleNamespace(x=lambda: -2880, width=lambda: 1440))

    bar.position_bar(40, screen, scale_screen=True)

    rect = bar.app_bar_data.rc
    assert (rect.left, rect.right) == (physical[0], physical[2])
    assert rect.bottom - rect.top == expected_height
    if edge == app_bar.AppBarEdge.Top:
        assert (rect.top, rect.bottom) == (physical[1], physical[1] + expected_height)
    else:
        assert (rect.top, rect.bottom) == (physical[3] - expected_height, physical[3])


def test_monitor_identity_uses_native_display_name_without_primary_fallback(monkeypatch):
    monkeypatch.setattr(host, '_monitor_info', lambda hwnd: (91, {'Monitor': (-2880, -720, 0, 1080), 'Device': r'\\.\DISPLAY2'}))
    assert host.window_monitor_identity(42) == {'id': 91, 'name': 'DISPLAY2'}
    monkeypatch.setattr(host, '_monitor_info', lambda hwnd: None)
    assert host.window_monitor_identity(42) == {'id': None, 'name': ''}


def test_installation_replaces_the_class_used_by_yasb_bar(monkeypatch):
    import core.bar as bar_module

    with monkeypatch.context() as scoped:
        scoped.setattr(app_bar, 'Win32AppBar', host._OriginalWin32AppBar)
        host.install_host_fixes()
        assert app_bar.Win32AppBar is host.PhysicalWin32AppBar
        assert bar_module.app_bar.Win32AppBar is host.PhysicalWin32AppBar
