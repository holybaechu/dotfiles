from math import ceil
from PyQt6.QtCore import QPoint, QRectF, Qt, QTimer
from PyQt6.QtGui import QColor, QFontMetricsF, QPainter
from PyQt6.QtWidgets import QMenu, QWidget
from . import theme as t
from .controls import Button
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
        self.setFixedHeight(t.px(40))
        self.power = Button('Power options', 'power', self.show_power_menu,
                            size=(32, 32), glyph_size=15, color=t.TEXT, parent=self)
        self.menu = QMenu(self)
        self.menu.setFont(t.font(12))
        self.menu.setStyleSheet(f'''
            QMenu {{ background:{t.SURFACE}; color:{t.TEXT}; border:1px solid {t.RAISED};
                     border-radius:{t.px(10)}px; padding:{t.px(6)}px; }}
            QMenu::item {{ padding:{t.px(8)}px {t.px(14)}px; border-radius:{t.px(6)}px; }}
            QMenu::item:selected {{ background:{t.RAISED}; }}
            QMenu::separator {{ height:1px; background:{t.RAISED}; margin:{t.px(4)}px; }}
        ''')
        for action, label in (('lock', 'Lock'), ('logout', 'Sign out'), ('sleep', 'Sleep'),
                              ('hibernate', 'Hibernate'), ('reboot', 'Restart'), ('shutdown', 'Shut down')):
            if action == 'reboot':
                self.menu.addSeparator()
            item = self.menu.addAction(label)
            # Let the menu dismiss before a native call locks or suspends Windows.
            item.triggered.connect(lambda checked=False, name=action:
                                   QTimer.singleShot(0, lambda: backend.power_action(name)))

    def resizeEvent(self, event):
        self.power.move(self.width() - self.power.width(), t.px(8))
        super().resizeEvent(event)

    def show_power_menu(self):
        size = self.menu.sizeHint()
        anchor = self.power.mapToGlobal(QPoint(self.power.width(), 0))
        self.menu.popup(anchor - QPoint(size.width(), size.height() + t.px(4)))

    def hideEvent(self, event):
        self.menu.hide()
        super().hideEvent(event)

    def paintEvent(self, event):
        state = self.backend.state
        p = QPainter(self)
        p.fillRect(QRectF(0, t.dp(4), self.width(), t.dp(1)), QColor(t.RAISED))
        if state.battery is None:
            return
        power_status = 'Charging' if state.charging else 'Plugged in' if state.power_plugged else 'On battery'
        t.icon(p, battery_icon(state.battery, state.power_plugged), QRectF(0, t.dp(16), t.dp(15), t.dp(15)), t.TEXT)
        t.text(p, QRectF(t.dp(23), t.dp(17), self.width() - t.dp(63), t.dp(14)), f'{state.battery}% · {power_status}', 11, t.TEXT)
