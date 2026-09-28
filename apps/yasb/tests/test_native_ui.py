import datetime as dt
import pytest

from PyQt6.QtCore import QPoint, QPointF, QRectF, Qt
from PyQt6.QtTest import QTest
from PyQt6.QtWidgets import QApplication

from core.widgets.canopy.controls import Button, Slider
from core.widgets.canopy.island import Panel, panel_geometry
from core.widgets.canopy.panels import Calendar
from core.widgets.canopy import theme


def open_panel(canvas, kind):
    (canvas.center if kind == 'media' else canvas.right).toggle(kind)
    QTest.qWait(180)
    return Panel.active


def test_workspaces_keep_radio_navigation_and_selection(desktop):
    root, canvas, backend = desktop
    button = canvas.workspaces.buttons[0]
    button.setFocus()
    QTest.keyClick(button, Qt.Key.Key_Right)
    assert backend.workspace == 1
    assert canvas.workspaces.buttons[1].isChecked()


def test_quick_controls_match_actions_and_primary_focus(desktop):
    root, canvas, backend = desktop
    panel = open_panel(canvas, 'quick')
    assert root.rect().contains(panel.geometry()), 'Quick controls and shadow must fit on screen'
    assert panel.body.content.volume.hasFocus()
    assert not any('microphone' in widget.accessibleName().lower() for widget in panel.findChildren(Button))
    QTest.keyClick(panel.body.content.volume, Qt.Key.Key_Home)
    assert backend.state.volume == 0
    image = panel.body.content.volume.grab().toImage()
    assert image.pixelColor(image.width() // 2, round(theme.dp(15) * image.devicePixelRatio())).name() == theme.RAISED
    QTest.keyClick(panel.body.content.volume, Qt.Key.Key_End)
    assert backend.state.volume == 100
    QTest.mouseClick(panel.body.content.mute, Qt.MouseButton.LeftButton)
    assert backend.state.muted is True


def test_brightness_rows_address_independent_displays(desktop):
    root, canvas, backend = desktop
    panel = open_panel(canvas, 'quick')
    rows = panel.body.content.display_widgets
    assert len(rows) == 2
    QTest.keyClick(rows[1].slider, Qt.Key.Key_Left)
    assert backend.state.displays[1]['brightness'] == 74
    assert backend.state.displays[0]['brightness'] == 65
    backend.state.displays.pop()
    backend.changed.emit('brightness')
    QTest.qWait(40)
    assert set(rows) == {0}


def test_media_artwork_progress_and_playback_remain_available(desktop):
    root, canvas, backend = desktop
    panel = open_panel(canvas, 'media')
    content = panel.body.content
    assert content.play.hasFocus()
    assert content.cover.image is not None
    QTest.mouseClick(content.play, Qt.MouseButton.LeftButton)
    assert backend.state.track.playing is False
    position = backend.state.track.position
    QTest.qWait(300)
    assert backend.state.track.position == position
    next_button = next(button for button in content.findChildren(Button) if button.accessibleName() == 'Next track')
    QTest.mouseClick(next_button, Qt.MouseButton.LeftButton)
    assert backend.state.track.title == 'Preview track 2'
    assert backend.state.track.position == 0


def test_calendar_handles_month_end_and_leap_year(desktop):
    calendar = Calendar(desktop[2])
    calendar.month = dt.date(2028, 1, 1)
    calendar.change_month(1)
    assert calendar.month == dt.date(2028, 2, 1)
    assert len(calendar.days) == 42
    assert calendar.days[0].date.weekday() == 0
    assert any(day.date == dt.date(2028, 2, 29) and day.isEnabled() for day in calendar.days)
    calendar.deleteLater()


def test_calendar_keyboard_navigation_crosses_month_boundaries(desktop):
    panel = open_panel(desktop[1], 'calendar')
    calendar = panel.body.content
    calendar.focus_date(dt.date(2028, 2, 29))
    selected = next(day for day in calendar.days if day.date == dt.date(2028, 2, 29))
    QTest.keyClick(selected, Qt.Key.Key_Right)
    assert calendar.focused_date == dt.date(2028, 3, 1)
    assert calendar.month == dt.date(2028, 3, 1)
    assert sum(day.focusPolicy() == Qt.FocusPolicy.StrongFocus for day in calendar.days) == 1


def test_tray_right_click_forwards_actions_and_guards_native_menu(desktop, monkeypatch):
    from core.widgets.canopy.tray import TrayButton
    panel = open_panel(desktop[1], 'tray')
    buttons = panel.findChildren(TrayButton)
    assert len(buttons) == 3
    actions = []
    monkeypatch.setattr(buttons[0], 'send_action', actions.append)
    QTest.mouseClick(buttons[0], Qt.MouseButton.RightButton)
    assert actions == [0x0204, 0x0205]
    assert panel.native_menu_until > 0
    assert not panel.closing
    QTest.mouseClick(panel, Qt.MouseButton.LeftButton, pos=QPoint(3, panel.height() - 3))
    QTest.qWait(150)
    assert Panel.active is None


def test_shadow_click_and_escape_collapse_panel(desktop):
    root, canvas, backend = desktop
    panel = open_panel(canvas, 'quick')
    QTest.mouseClick(panel, Qt.MouseButton.LeftButton, pos=QPoint(3, panel.height()-3))
    QTest.qWait(150)
    assert Panel.active is None
    panel = open_panel(canvas, 'media')
    QTest.keyClick(panel.body.content.play, Qt.Key.Key_Escape)
    QTest.qWait(150)
    assert Panel.active is None
    assert canvas.center.isEnabled()


def test_switching_panels_restores_the_previous_section(desktop):
    root, canvas, backend = desktop
    open_panel(canvas, 'media')
    canvas.right.toggle('quick')
    QTest.qWait(320)
    assert Panel.active.kind == 'quick'
    assert canvas.center.isEnabled()
    assert not canvas.right.isEnabled()


def test_geometry_supports_negative_monitor_origins_and_edge_corners():
    screen = QRectF(-1920, 0, 1920, 1080)
    source = QRectF(-256, 0, 256, 40)
    rect, edge = panel_geometry(source, screen, 352, 430)
    assert edge == 'right'
    assert rect.right() <= screen.right()
    assert rect.left() >= screen.left()
    shape = theme.squircle(QRectF(0, 0, 352, 430), corners=(0, 0, 0, 44))
    assert shape.contains(QPointF(351, 429))
    assert not shape.contains(QPointF(1, 429))


@pytest.mark.parametrize('interval', [1 / 60, 1 / 30, .1])
def test_expansion_does_not_reverse_on_delayed_frames(desktop, monkeypatch, interval):
    import core.widgets.canopy.island as island
    monkeypatch.setattr(island, 'reduced_motion', lambda: False)
    now = [100.0]
    monkeypatch.setattr(island.time, 'monotonic', lambda: now[0])
    root, canvas, backend = desktop
    canvas.right.toggle('quick')
    panel = Panel.active
    panel.timer.stop()
    heights = [panel.current[3]]
    for _ in range(50):
        now[0] += interval
        panel.tick()
        heights.append(panel.current[3])
    reversals = [b - a for a, b in zip(heights, heights[1:]) if b < a - .25]
    assert not reversals, f'Expansion moved backwards: {reversals}'
    assert abs(heights[-1] - panel.target.height()) < .1


def test_panel_content_does_not_shift_horizontally_during_morph(desktop):
    panel = open_panel(desktop[1], 'quick')
    left = round(panel.target.x() - panel.bounds.x())
    positions = []
    for fraction in (.1, .3, .49, .51, .7, .9):
        panel.current[0] = panel.target.x() + 50 + fraction
        panel.update_geometry()
        positions.append(panel.scroll.mapTo(panel, QPoint()).x())
    assert positions == [left] * len(positions), f'Content shifts: {positions}'


@pytest.mark.parametrize(('fps', 'expected'), [
    (60, [.780604015625, .955114802059, .998121368776, 1]),
    (120, [.756370060845, .942058418765, .996722748918, .999989515482]),
])
def test_panel_spring_keyframes_at_multiple_frame_rates(desktop, monkeypatch, fps, expected):
    import core.widgets.canopy.island as island
    monkeypatch.setattr(island, 'reduced_motion', lambda: False)
    now = [100.0]
    monkeypatch.setattr(island.time, 'monotonic', lambda: now[0])
    desktop[1].right.toggle('quick')
    panel = Panel.active
    panel.timer.stop()
    start = panel.source.height()
    distance = panel.target.height() - start
    frames = {round(fps * seconds) for seconds in (.1, .2, .4, .8)}
    progress = []
    for frame in range(1, round(fps * .8) + 1):
        now[0] += 1 / fps
        panel.tick()
        if frame in frames:
            progress.append((panel.current[3] - start) / distance)
    assert progress == pytest.approx(expected, abs=.0003)


def test_scrollbar_only_appears_after_overflowing_panel_finishes_opening(desktop, monkeypatch):
    import core.widgets.canopy.island as island
    monkeypatch.setattr(island, 'reduced_motion', lambda: False)
    root, canvas, backend = desktop
    backend.state.displays += [{'id': index, 'name': f'Display {index}', 'brightness': 50} for index in (2, 3)]
    canvas.right.toggle('quick')
    panel = Panel.active
    QTest.qWait(20)
    scrollbar = panel.scroll.verticalScrollBar()
    assert not scrollbar.isVisible(), 'Scrollbar flashes during expansion'
    QTest.qWait(850)
    assert panel.done_opening
    assert scrollbar.maximum() > 0
    assert scrollbar.isVisible()
    panel.close_panel()
    assert not scrollbar.isVisible(), 'Scrollbar remains visible during collapse'
