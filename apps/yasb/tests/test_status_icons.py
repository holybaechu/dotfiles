import json
import sys
from types import ModuleType, SimpleNamespace

from PyQt6.QtCore import Qt
from PyQt6.QtTest import QTest
from core.widgets.canopy.backend import Backend
from core.widgets.canopy import theme
from core.widgets.canopy.island import Panel
from core.widgets.canopy.status_icons import battery_icon, brightness_icon, volume_icon


def open_quick(desktop):
    desktop[1].right.toggle('quick')
    QTest.qWait(180)
    return Panel.active.body.content


def test_bar_highlights_connected_wifi_only_while_connected(desktop):
    _, canvas, backend = desktop
    assert ('wifi', theme.GREEN) in canvas.status.symbols
    backend.state.connected = False
    backend.changed.emit('status')
    assert ('wifi-off', theme.MUTED) in canvas.status.symbols


def test_volume_icon_updates_in_both_bar_and_panel(desktop):
    _, canvas, backend = desktop
    quick = open_quick(desktop)
    for percent, expected in [(0, 'volume'), (1, 'volume-1'), (50, 'volume-1'), (51, 'volume-2'), (100, 'volume-2')]:
        backend.set_volume(percent)
        assert quick.mute.glyph == expected
        assert (expected, theme.TEXT) in canvas.status.symbols
    backend.set_mute(True)
    assert quick.mute.glyph == 'volume-x'
    assert ('volume-x', theme.GREEN) in canvas.status.symbols
    backend.state.audio_available = False
    backend.changed.emit('audio')
    assert quick.mute.glyph == 'volume-off'
    assert ('volume-off', theme.MUTED) in canvas.status.symbols
    assert not quick.volume.isEnabled()


def test_brightness_icons_follow_individual_displays_and_slider_preview(desktop):
    backend = desktop[2]
    backend.state.displays[0]['brightness'] = 20
    backend.state.displays[1]['brightness'] = 90
    quick = open_quick(desktop)
    first, second = quick.display_widgets.values()
    assert first.symbol.glyph == 'sun-dim'
    assert second.symbol.glyph == 'sun'
    QTest.keyClick(first.slider, Qt.Key.Key_End)
    assert first.symbol.glyph == 'sun'
    assert second.symbol.glyph == 'sun'
    backend.state.displays.pop()
    backend.changed.emit('brightness')
    assert first.symbol.isHidden()
    assert quick.brightness_symbol.glyph == 'sun'
    first.slider.setValue(50)
    assert quick.brightness_symbol.glyph == 'sun-medium'
    assert first.symbol.glyph == 'sun-medium'


def test_battery_icon_updates_in_both_bar_and_footer(desktop, monkeypatch):
    _, canvas, backend = desktop
    quick = open_quick(desktop)
    drawn = []
    original = theme.icon
    def capture(painter, name, rect, color=theme.TEXT):
        drawn.append((name, color))
        return original(painter, name, rect, color)
    monkeypatch.setattr(theme, 'icon', capture)
    for percent, plugged, expected in [(0, False, 'battery'), (10, False, 'battery-warning'), (25, False, 'battery-low'), (60, False, 'battery-medium'), (100, False, 'battery-full'), (10, True, 'battery-charging')]:
        backend.state.battery, backend.state.power_plugged = percent, plugged
        backend.changed.emit('status')
        expected_color = theme.GREEN if plugged else theme.ERROR if percent <= 15 else theme.TEXT
        assert (expected, expected_color) in canvas.status.symbols
        drawn.clear()
        quick.battery.grab()
        assert (expected, theme.TEXT) in drawn


def test_battery_power_source_and_charging_are_shown_separately(desktop, monkeypatch):
    _, canvas, backend = desktop
    connectivity = ModuleType('winrt.windows.networking.connectivity')
    connectivity.NetworkInformation = SimpleNamespace(get_internet_connection_profile=lambda: None)
    monkeypatch.setitem(sys.modules, connectivity.__name__, connectivity)
    backend._icons = {}
    backend._modes = SimpleNamespace(refresh=lambda: None)
    quick = open_quick(desktop)
    drawn_text = []
    original = theme.text

    def capture(painter, rect, value, *args, **kwargs):
        color = args[1] if len(args) > 1 else kwargs.get('color', theme.TEXT)
        drawn_text.append((value, color))
        return original(painter, rect, value, *args, **kwargs)

    monkeypatch.setattr(theme, 'text', capture)
    for percent, charging, plugged, caption, icon in [
        (99, False, True, 'Plugged in', 'battery-charging'),
        (60, True, True, 'Charging', 'battery-charging'),
        (60, False, False, 'On battery', 'battery-medium'),
    ]:
        backend._battery = SimpleNamespace(get_status=lambda: SimpleNamespace(percent=percent, is_charging=charging, power_plugged=plugged))
        Backend.refresh_status(backend)
        drawn_text.clear()
        quick.battery.grab()
        assert backend.state.battery == percent
        assert backend.state.charging is charging
        assert backend.state.power_plugged is plugged
        assert (f'Battery {percent}% · {caption}', theme.TEXT) in drawn_text
        drawn_text.clear()
        canvas.status.grab()
        assert (f'{percent}%', theme.TEXT) in drawn_text
        assert (icon, theme.GREEN if plugged else theme.TEXT) in canvas.status.symbols


def test_all_status_variants_have_bundled_icons():
    bundled = json.loads((theme.ASSETS / 'icons.json').read_text())
    variants = {brightness_icon(value) for value in (None, 0, 33, 34, 66, 67, 100)}
    variants |= {volume_icon(value, muted, available) for value in (0, 1, 50, 51, 100) for muted in (False, True) for available in (False, True)}
    variants |= {battery_icon(value, plugged) for value in (None, 0, 1, 15, 16, 35, 36, 75, 76, 100) for plugged in (False, True)}
    assert variants <= bundled.keys()
