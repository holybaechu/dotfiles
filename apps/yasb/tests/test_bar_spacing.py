import pytest
from PyQt6.QtCore import QPoint, Qt
from PyQt6.QtTest import QTest
from core.widgets.canopy import theme
from core.widgets.canopy.controls import Button
from core.widgets.canopy.details import Percentage


@pytest.mark.parametrize('size', [16, 24])
def test_percentage_renders_all_three_digits_at_100(app, monkeypatch, size):
    rendered = []
    original = theme.text
    def inspect(painter, rect, value, *args, **kwargs):
        original(painter, rect, value, *args, **kwargs)
        rendered.append(painter.fontMetrics().elidedText(str(value), Qt.TextElideMode.ElideRight, int(rect.width())))
    monkeypatch.setattr(theme, 'text', inspect)
    label = Percentage(size)
    label.setText('100%')
    label.grab()
    assert rendered == ['100', '%'], f'Percentage was shortened to {rendered}'
    width = label.width()
    label.setText('9%')
    assert label.width() == width
    label.deleteLater()


def test_panel_trigger_highlights_share_vertical_geometry(desktop):
    _, canvas, backend = desktop
    backend.state.battery = 100
    backend.changed.emit('status')
    QTest.qWait(20)
    tray = next(button for button in canvas.right.findChildren(Button) if button.accessibleName() == 'Show system tray')
    controls = [canvas.media_button, canvas.status, canvas.clock, tray, canvas.launcher]
    bounds = [(button.mapTo(canvas, QPoint()).y(), button.height()) for button in controls]
    assert len(set(bounds)) == 1, f'Hover backgrounds have different padding: {bounds}'


@pytest.mark.parametrize('percent', [9, 99, 100])
def test_status_hover_keeps_equal_side_padding_for_battery_percentages(desktop, monkeypatch, percent):
    _, canvas, backend = desktop
    backend.state.battery = percent
    backend.changed.emit('status')
    bounds = []
    original_icon, original_text = theme.icon, theme.text
    def icon(painter, name, rect, *args, **kwargs):
        bounds.append((rect.left(), rect.right()))
        return original_icon(painter, name, rect, *args, **kwargs)
    def text(painter, rect, value, *args, **kwargs):
        bounds.append((rect.left(), rect.right()))
        return original_text(painter, rect, value, *args, **kwargs)
    monkeypatch.setattr(theme, 'icon', icon)
    monkeypatch.setattr(theme, 'text', text)
    canvas.status.grab()
    left_padding = min(left for left, _ in bounds)
    right_padding = canvas.status.width() - max(right for _, right in bounds)
    assert left_padding == pytest.approx(right_padding)
    assert theme.BAR_BUTTON_PADDING <= left_padding < theme.BAR_BUTTON_PADDING + 1
