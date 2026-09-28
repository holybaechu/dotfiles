from math import ceil
from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QColor, QFontMetricsF, QPainter
from PyQt6.QtWidgets import QWidget
from . import theme as t
from .status_icons import battery_icon


class Percentage(QWidget):
    def __init__(self, size=24):
        super().__init__()
        self.size = size
        self.value = '—'
        small = 11 if size == 24 else 10
        width = ceil(QFontMetricsF(t.utility_font(size), self).horizontalAdvance('100')) + t.px(2) + ceil(QFontMetricsF(t.utility_font(small), self).horizontalAdvance('%'))
        self.setFixedSize(width, t.px(29 if size == 24 else 20))

    def setText(self, value):
        self.value = str(value).rstrip('%')
        self.update()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.TextAntialiasing)
        suffix = '' if self.value == '—' else '%'
        small = 11 if self.size == 24 else 10
        suffix_width = ceil(QFontMetricsF(t.utility_font(small), p.device()).horizontalAdvance(suffix))
        t.text(p, QRectF(0, 0, self.width() - suffix_width - t.dp(2), self.height()), self.value, self.size, align=Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, family=t.UTILITY_FAMILY)
        t.text(p, QRectF(self.width() - suffix_width, self.height() - t.dp(small + 6), suffix_width, t.dp(small + 4)), suffix, small, t.MUTED, family=t.UTILITY_FAMILY)


class BatteryFooter(QWidget):
    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self.setFixedHeight(t.px(31))

    def paintEvent(self, event):
        state = self.backend.state
        p = QPainter(self)
        p.fillRect(QRectF(0, t.dp(4), self.width(), t.dp(1)), QColor(t.RAISED))
        power_status = 'Charging' if state.charging else 'Plugged in' if state.power_plugged else 'On battery'
        t.text(p, QRectF(0, t.dp(17), self.width() - t.dp(24), t.dp(14)), f'Battery {state.battery}% · {power_status}', 11, t.TEXT)
        t.icon(p, battery_icon(state.battery, state.power_plugged), QRectF(self.width() - t.dp(15), t.dp(16), t.dp(15), t.dp(15)), t.TEXT)
