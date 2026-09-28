from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QColor, QPainter, QPen

from core.widgets.services.systray.systray_widget import IconWidget
from . import theme as t


class TrayButton(IconWidget):
    def __init__(self, data, backend):
        super().__init__()
        self.data, self.backend = data, backend
        self.setMinimumSize(t.px(60), t.px(78))
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setAccessibleName(data.szTip or data.exe or 'Tray icon')
        self.setToolTip(self.accessibleName())
        self.setCursor(Qt.CursorShape.PointingHandCursor)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.RightButton:
            self.backend.tray_menu_started.emit()
        super().mousePressEvent(event)

    def keyPressEvent(self, event):
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Space):
            self.send_action(0x0201)
            self.send_action(0x0202)
        elif event.key() == Qt.Key.Key_Menu or (event.key() == Qt.Key.Key_F10 and event.modifiers() & Qt.KeyboardModifier.ShiftModifier):
            self.backend.tray_menu_started.emit()
            self.send_action(0x0204)
            self.send_action(0x0205)
        else:
            super().keyPressEvent(event)

    def enterEvent(self, event):
        self.send_notify_message(0x0200)
        if self.data.uVersion >= 4:
            self.send_notify_message(0x0406)
        self.update()
        super().enterEvent(event)

    def leaveEvent(self, event):
        if self.data.uVersion >= 4:
            self.send_notify_message(0x0407)
        self.update()
        super().leaveEvent(event)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.underMouse():
            p.fillPath(t.squircle(self.rect(), t.dp(18)), QColor(t.SURFACE))
        x = (self.width() - t.dp(42)) / 2
        p.fillPath(t.squircle(QRectF(x, t.dp(8), t.dp(42), t.dp(42)), t.dp(14)), QColor(t.RAISED))
        if self.data.icon_image:
            p.drawImage(QRectF(x + t.dp(10), t.dp(18), t.dp(22), t.dp(22)), self.data.icon_image)
        t.text(p, QRectF(t.dp(4), t.dp(58), self.width() - t.dp(8), t.dp(15)), (self.data.szTip or self.data.exe).split('\n')[0], 11, t.MUTED, align=Qt.AlignmentFlag.AlignCenter)
        if t.keyboard_focus(self):
            p.setPen(QPen(QColor(t.GREEN), t.dp(2)))
            p.drawPath(t.squircle(QRectF(self.rect()).adjusted(t.dp(1), t.dp(1), -t.dp(1), -t.dp(1)), t.dp(18)))
