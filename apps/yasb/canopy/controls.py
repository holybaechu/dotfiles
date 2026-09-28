from __future__ import annotations

from PyQt6.QtCore import QEasingCurve, QPointF, QRectF, QSize, Qt, QVariantAnimation, pyqtSignal
from PyQt6.QtGui import QColor, QPainter, QPen
from PyQt6.QtWidgets import QAbstractButton, QLabel, QSlider, QVBoxLayout, QWidget

from . import theme as t


class Label(QLabel):
    def __init__(self, value='', size=12, color=t.TEXT, weight=400, parent=None, family=None):
        super().__init__(value, parent)
        self.setFont(t.font(size, weight, family))
        self.setStyleSheet(f'color:{color};background:transparent;border:0;')
        self.setMinimumWidth(0)


class Icon(QWidget):
    def __init__(self, glyph, size=(18, 24), glyph_size=18, color=t.TEXT):
        super().__init__()
        self.glyph, self.glyph_size, self.color = glyph, glyph_size, color
        self.setFixedSize(*(t.px(value) for value in size))
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        size = t.dp(self.glyph_size * 1.05)
        t.icon(painter, self.glyph, QRectF((self.width() - size) / 2, (self.height() - size) / 2, size, size), self.color)


class Button(QAbstractButton):
    def __init__(self, label='', glyph='', callback=None, size=(32, 32), glyph_size=18, color=t.MUTED, background=None, radius=None, parent=None, text_size=12, text_weight=400, text_family=None):
        super().__init__(parent)
        self.glyph, self.glyph_size = glyph, glyph_size
        self.color, self.background, self.radius = color, background, t.dp(8) if radius is None else radius
        self.text_size, self.text_weight, self.text_family = text_size, text_weight, text_family
        self._fill = QColor(background or 'transparent')
        self._transition = QVariantAnimation(self)
        self._transition.setDuration(120)
        curve = QEasingCurve(QEasingCurve.Type.BezierSpline)
        curve.addCubicBezierSegment(QPointF(.2, 0), QPointF(0, 1), QPointF(1, 1))
        self._transition.setEasingCurve(curve)
        self._transition.valueChanged.connect(self._update_fill)
        self.pressed.connect(self._animate_fill)
        self.released.connect(self._animate_fill)
        self.setAccessibleName(label)
        self.setToolTip(label)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        if size:
            self.setFixedSize(*(t.px(value) for value in size))
        if callback:
            self.clicked.connect(callback)

    def enterEvent(self, event):
        self._animate_fill()
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._animate_fill()
        super().leaveEvent(event)

    def hideEvent(self, event):
        # Qt can destroy an expanding panel after the event loop has stopped.
        # Its child color animations must not retain live paint callbacks then.
        self._transition.stop()
        self._fill = QColor(self.background or 'transparent')
        super().hideEvent(event)

    def focusInEvent(self, event):
        self.update()
        super().focusInEvent(event)

    def focusOutEvent(self, event):
        self.update()
        super().focusOutEvent(event)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if not self.isEnabled():
            p.setOpacity(.5)
        if self._fill.alpha():
            p.fillPath(t.squircle(self.rect(), self.radius), self._fill)
        self.draw_contents(p)
        if t.keyboard_focus(self):
            p.setPen(QPen(QColor(t.BLACK if self.background == t.GREEN else t.GREEN), t.dp(2)))
            inset = t.dp(1)
            p.drawPath(t.squircle(QRectF(self.rect()).adjusted(inset, inset, -inset, -inset), max(0, self.radius - inset)))

    def _update_fill(self, color):
        self._fill = color
        self.update()

    def _animate_fill(self):
        from .native import reduced_motion
        fill = self.background
        if self.isDown():
            fill = t.GREEN_PRESSED if fill == t.GREEN else t.PRESSED
        elif self.underMouse() and self.isEnabled():
            fill = t.GREEN_HOVER if fill == t.GREEN else t.RAISED
        target = QColor(fill or 'transparent')
        self._transition.stop()
        if not self.isVisible() or reduced_motion():
            self._update_fill(target)
        else:
            self._transition.setStartValue(self._fill)
            self._transition.setEndValue(target)
            self._transition.start()

    def draw_contents(self, painter):
        if self.glyph:
            s = t.dp(self.glyph_size * 1.05)
            t.icon(painter, self.glyph, QRectF((self.width() - s) / 2, (self.height() - s) / 2, s, s), self.color)
        else:
            t.text(painter, QRectF(self.rect()), self.text(), self.text_size, weight=self.text_weight, align=Qt.AlignmentFlag.AlignCenter, family=self.text_family)


class Slider(QSlider):
    committed = pyqtSignal(int)

    def __init__(self, name, callback, commit=False, parent=None):
        super().__init__(Qt.Orientation.Horizontal, parent)
        self.setRange(0, 100)
        self.setSingleStep(1)
        self.setPageStep(10)
        self.setFixedHeight(t.px(32))
        self.setAccessibleName(name)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setCursor(Qt.CursorShape.SizeHorCursor)
        self._dragging = False
        (self.committed if commit else self.valueChanged).connect(callback)

    def set_external_value(self, value):
        if self._dragging:
            return
        old = self.blockSignals(True)
        self.setValue(round(value))
        self.blockSignals(old)
        self.update()

    def _from_point(self, x):
        return max(0, min(100, round((x - t.dp(12)) * 100 / max(1, self.width() - t.dp(24)))))

    def mousePressEvent(self, event):
        if self.isEnabled() and event.button() == Qt.MouseButton.LeftButton:
            self.setFocus(Qt.FocusReason.MouseFocusReason)
            self._dragging = True
            self.setSliderDown(True)
            self.setValue(self._from_point(event.position().x()))
            event.accept()

    def mouseMoveEvent(self, event):
        if self._dragging:
            self.setValue(self._from_point(event.position().x()))

    def mouseReleaseEvent(self, event):
        if self._dragging:
            self._dragging = False
            self.setSliderDown(False)
            self.committed.emit(self.value())
        self.update()

    def keyPressEvent(self, event):
        mapping = {Qt.Key.Key_Left: -1, Qt.Key.Key_Down: -1, Qt.Key.Key_Right: 1, Qt.Key.Key_Up: 1, Qt.Key.Key_PageDown: -10, Qt.Key.Key_PageUp: 10}
        if event.key() in mapping:
            self.setValue(self.value() + mapping[event.key()])
        elif event.key() == Qt.Key.Key_Home:
            self.setValue(0)
        elif event.key() == Qt.Key.Key_End:
            self.setValue(100)
        else:
            return super().keyPressEvent(event)
        self.committed.emit(self.value())
        self.update()
        event.accept()

    def wheelEvent(self, event):
        event.ignore()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if not self.isEnabled():
            p.setOpacity(.5)
        x = t.dp(12) + (self.width() - t.dp(24)) * self.value() / 100
        track_y, track_h, gap = t.dp(8), t.dp(16), t.dp(6)
        left_end = x - t.dp(2) - gap
        right_start = x + t.dp(2) + gap
        if self.value() > 0 and left_end > 0:
            p.fillPath(t.squircle(QRectF(0, track_y, left_end, track_h), corners=tuple(map(t.dp, (8, 2, 2, 8)))), QColor(t.GREEN))
        if self.value() < 100 and right_start < self.width():
            p.fillPath(t.squircle(QRectF(right_start, track_y, self.width() - right_start, track_h), corners=tuple(map(t.dp, (2, 8, 8, 2)))), QColor(t.RAISED))
        h = t.dp(28 if self.underMouse() or self._dragging else 24)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(QColor(t.GREEN))
        p.drawRoundedRect(QRectF(x - t.dp(2), (self.height() - h) / 2, t.dp(4), h), t.dp(2), t.dp(2))
        if t.keyboard_focus(self):
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.setPen(QPen(QColor(t.GREEN), t.dp(2)))
            p.drawRoundedRect(QRectF(x - t.dp(11), t.dp(1), t.dp(22), t.dp(28)), t.dp(8), t.dp(8))


class Surface(QWidget):
    def __init__(self, parent=None, radius=None, color=t.SURFACE):
        super().__init__(parent)
        self.radius, self.color = t.dp(18) if radius is None else radius, color
        self.box = QVBoxLayout(self)
        self.box.setContentsMargins(*map(t.px, (16, 12, 16, 12)))
        self.box.setSpacing(0)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.fillPath(t.squircle(self.rect(), self.radius), QColor(self.color))


class Cover(QWidget):
    def __init__(self, size=104, parent=None):
        super().__init__(parent)
        self.setFixedSize(t.px(size), t.px(size))
        self.image = None
        self.compact = size == 26

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        path = t.squircle(self.rect(), t.dp(8 if self.compact else 26))
        p.fillPath(path, QColor(t.SURFACE))
        p.setClipPath(path)
        if self.image and not self.image.isNull():
            image = self.image
            side = min(image.width(), image.height())
            p.drawImage(QRectF(self.rect()), image, QRectF((image.width() - side) / 2, (image.height() - side) / 2, side, side))
        else:
            size = t.dp(15 if self.compact else 48)
            t.icon(p, 'music-2' if self.compact else 'disc-3', QRectF((self.width() - size) / 2, (self.height() - size) / 2, size, size), t.GREEN)
