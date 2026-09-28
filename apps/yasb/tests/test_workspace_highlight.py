from PyQt6.QtCore import QPoint, Qt
from PyQt6.QtTest import QTest
from PyQt6.QtGui import QPixmap
from PyQt6.QtWidgets import QApplication
from core.widgets.canopy import theme


def snapshot(group):
    group.timer.stop()
    QApplication.instance().setProperty('canopyKeyboard', False)
    for button in group.buttons:
        button.setAttribute(Qt.WidgetAttribute.WA_UnderMouse, False)
    # Sample fractional logical font sizes at two device pixels per logical
    # pixel, so glyph hinting does not dominate the overlap/color assertions.
    ratio = max(2, group.devicePixelRatioF())
    pixmap = QPixmap(round(group.width() * ratio), round(group.height() * ratio))
    pixmap.setDevicePixelRatio(ratio)
    pixmap.fill(Qt.GlobalColor.transparent)
    group.render(pixmap)
    return pixmap.toImage()


def test_click_does_not_recolor_labels_before_the_highlight_moves(desktop):
    group = desktop[1].workspaces
    first, second = group.buttons[:2]
    group.current = [float(first.x()), float(first.width())]
    before = snapshot(group)
    QTest.mouseClick(second, Qt.MouseButton.LeftButton)
    group.current = [float(first.x()), float(first.width())]
    after = snapshot(group)
    assert second.isChecked()
    assert after == before, 'Workspace text changed color before the highlight reached it'


def test_highlight_recolors_only_the_overlapped_part_of_a_label(desktop):
    group = desktop[1].workspaces
    button = group.buttons[0]
    button.setText('888')
    button.setFixedWidth(theme.px(60))
    group.setFixedWidth(group.box.sizeHint().width())
    group.box.activate()
    group.current = [theme.dp(-100), theme.dp(60)]
    uncovered = snapshot(group)
    scale = uncovered.devicePixelRatio() * theme.DESIGN_SCALE
    ink = [(x, y) for x in range(round(10 * scale), round(50 * scale)) for y in range(round(8 * scale), round(18 * scale)) if 100 < uncovered.pixelColor(x, y).red() < 190]
    assert ink, 'Uncovered text should use the normal light color'
    group.current = [0., theme.dp(60)]
    covered = snapshot(group)
    gain = max(covered.pixelColor(x, y).lightness() - uncovered.pixelColor(x, y).lightness() for x, y in ink)
    assert gain > 20, f'Highlight text lightness gain: {gain}'
    group.current = [theme.dp(-30), theme.dp(60)]
    half = snapshot(group)
    left = tuple(round(value * scale) for value in (8, 8, 20, 10))
    right = tuple(round(value * scale) for value in (32, 8, 20, 10))
    assert half.copy(*left) == covered.copy(*left)
    assert half.copy(*right) == uncovered.copy(*right)
