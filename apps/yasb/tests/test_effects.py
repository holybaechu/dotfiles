from PIL import Image, ImageFilter
from PyQt6.QtCore import QPoint, Qt
from core.widgets.canopy.island import Panel
from PyQt6.QtTest import QTest
from core.widgets.canopy import theme


def quick_panel(desktop):
    desktop[1].right.toggle('quick')
    QTest.qWait(180)
    panel = Panel.active
    panel.timer.stop()
    panel.grab()
    return panel


def test_blur_frames_reuse_filters_for_unchanged_controls(desktop, monkeypatch):
    panel = quick_panel(desktop)
    filters = []
    original = Image.Image.filter
    def filtered(image, operation):
        if isinstance(operation, ImageFilter.GaussianBlur):
            filters.append(operation.radius)
        return original(image, operation)
    monkeypatch.setattr(Image.Image, 'filter', filtered)
    for frame in range(30):
        panel.effect.set_amount(.7, theme.dp(3.9 - frame * .12))
        panel.grab()
    assert len(filters) <= 3, f'Repeated expensive blur work on {len(filters)} animation frames'


def test_volume_update_replaces_cached_panel_during_blur(desktop):
    panel = quick_panel(desktop)
    slider = panel.body.content.volume
    point = slider.mapTo(panel, QPoint(slider.width() // 4, theme.px(15)))
    panel.effect.set_amount(.7, theme.dp(2))
    before = panel.grab().toImage().pixelColor(point)
    desktop[2].set_volume(0)
    after = panel.grab().toImage().pixelColor(point)
    assert before.green() > after.green() + 10
    assert after.blue() > after.red(), 'The emptied rail should return to the slate surface'


def test_cached_blur_keeps_solid_surface_brightness_constant(desktop):
    panel = quick_panel(desktop)
    surface = panel.body.content.brightness
    point = surface.mapTo(panel, QPoint(surface.width() // 2, theme.px(8)))
    shades = []
    for blur in (2, 1.5, 1, .5, 0):
        panel.effect.set_amount(.7, theme.dp(blur))
        shades.append(panel.grab().toImage().pixelColor(point).red())
    assert max(shades) - min(shades) <= 10, f'Crossfade changed surface brightness: {shades}'


def test_closing_panel_does_not_accept_slider_keys(desktop):
    panel = quick_panel(desktop)
    before = desktop[2].state.volume
    panel.close_panel()
    QTest.keyClick(panel.body.content.volume, Qt.Key.Key_End)
    assert desktop[2].state.volume == before
