from __future__ import annotations

import time
from functools import lru_cache

from PIL import Image, ImageFilter
from PyQt6 import sip
from PyQt6.QtCore import QEvent, QPoint, QPointF, QRect, QRectF, Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QColor, QImage, QPainter, QRegion
from PyQt6.QtWidgets import QApplication, QScrollArea, QWidget

from . import theme as t
from .effects import FadeBlur, image_to_pil, pil_to_image
from .native import disable_native_rounding, menu_active, reduced_motion
from .panels import PanelBody


@lru_cache(maxsize=48)
def shadow(width, height, left_radius, right_radius):
    image = QImage(width + t.px(96), height + t.px(96), QImage.Format.Format_RGBA8888)
    image.fill(Qt.GlobalColor.transparent)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.fillPath(t.squircle(QRectF(t.dp(48), t.dp(48), width, height), corners=(0, 0, right_radius, left_radius)), QColor('white'))
    painter.end()
    alpha = image_to_pil(image).getchannel('A')
    result = Image.new('RGBA', alpha.size)
    for radius, offset, strength in ((12, 10, .28), (4, 2, .2)):
        layer = Image.new('RGBA', alpha.size)
        shifted = Image.new('L', alpha.size)
        shifted.paste(alpha.filter(ImageFilter.GaussianBlur(t.dp(radius))).point(lambda a: round(a * strength)), (0, t.px(offset)))
        layer.putalpha(shifted)
        result = Image.alpha_composite(result, layer)
    return pil_to_image(result)


def paint_shadow(painter, rect, left, right):
    radius = max(left, right)
    size = 2 * radius + t.px(2)
    sprite = shadow(size, size, left, right)
    cap = radius + t.px(48)
    source = [0, cap, cap + t.px(2), sprite.width()]
    xs = [rect.left() - t.dp(48), rect.left() + radius, rect.right() - radius, rect.right() + t.dp(48)]
    ys = [rect.top() - t.dp(48), rect.top() + radius, rect.bottom() - radius, rect.bottom() + t.dp(48)]
    painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
    for row in range(3):
        for column in range(3):
            target = QRectF(xs[column], ys[row], xs[column + 1] - xs[column], ys[row + 1] - ys[row])
            crop = QRectF(source[column], source[row], source[column + 1] - source[column], source[row + 1] - source[row])
            painter.drawImage(target, sprite, crop)


def panel_geometry(source, screen, width, height):
    width = min(max(width, source.width()), screen.width())
    height = min(height, screen.bottom() - source.top())
    edge = 'left' if source.left() <= screen.left() + 1 else 'right' if source.right() >= screen.right() - 1 else 'center'
    left = screen.left() if edge == 'left' else screen.right() - width if edge == 'right' else max(screen.left(), min(screen.right() - width, source.center().x() - width / 2))
    return QRectF(left, source.top(), width, height), edge


class Panel(QWidget):
    finished = pyqtSignal()
    active = None

    @classmethod
    def toggle(cls, kind, owner, source, backend, preview_parent=None):
        from .launcher import Launcher
        if Launcher.active and Launcher.active.isVisible():
            Launcher.active.close_launcher(immediate=True)
        if cls.active and cls.active.isVisible():
            old = cls.active
            same = old.kind == kind and old.owner is owner
            old.close_panel(None if same else lambda: cls.toggle(kind, owner, source, backend, preview_parent))
            return
        panel = cls(kind, owner, source, backend, preview_parent)
        cls.active = panel
        panel.show_panel()

    def __init__(self, kind, owner, source, backend, preview_parent=None):
        super().__init__(preview_parent, Qt.WindowType.Widget if preview_parent else Qt.WindowType.Tool | Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.kind, self.owner, self.backend = kind, owner, backend
        self.return_focus = QApplication.focusWidget()
        owner.destroyed.connect(self.owner_destroyed)
        self.preview_parent = preview_parent
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setWindowTitle('Canopy panel')
        if not preview_parent: self.setScreen(owner.screen())
        self.source = QRectF(source)
        self.screen_rect = QRectF(preview_parent.rect()) if preview_parent else QRectF(owner.screen().geometry())
        self.body = PanelBody(kind, backend)
        self.viewport_widget = QWidget(self)
        self.scroll = QScrollArea(self.viewport_widget)
        self.scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        self.scroll.setWidgetResizable(False)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll.setStyleSheet(f'QScrollArea {{ background:transparent;border:0; }} QScrollBar:vertical {{ width:{t.px(6)}px;background:{t.BLACK}; }} QScrollBar::handle:vertical {{background:{t.GREEN};min-height:{t.px(24)}px;border-radius:{t.dp(3)}px;}} QScrollBar::add-line:vertical,QScrollBar::sub-line:vertical{{height:0;}} QScrollBar::add-page:vertical,QScrollBar::sub-page:vertical{{background:transparent;}}')
        self.scroll.viewport().setStyleSheet('background:transparent;')
        self.scroll.setWidget(self.body)
        self.effect = FadeBlur(self.body)
        self.body.setGraphicsEffect(self.effect)
        self.body.size_changed.connect(lambda: QTimer.singleShot(0, self.fit_content))
        self.backend.changed.connect(self.invalidate_content)
        self._problem = self.backend.state.problem
        self.reduced = reduced_motion()
        self._disposed = False
        self.closing = False
        self.done_opening = False
        self.after_close = None
        self.native_menu_until = 0.0
        self.focus_grace = 0.0
        self.backend.tray_menu_started.connect(self._menu_started)
        self.current = [source.x(), source.y(), source.width(), source.height(), t.dp(16), t.dp(16)]
        self.velocity = [0.] * 6
        self.target = QRectF()
        self.edge = 'center'
        self.fit_content(initial=True)
        self.timer = QTimer(self)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.timer.setInterval(t.frame_interval(owner.screen()))
        self.timer.timeout.connect(self.tick)
        self.brightness_timer = QTimer(self)
        self.brightness_timer.setInterval(5000)
        self.brightness_timer.timeout.connect(self.backend.refresh_brightness)
        self.blur_timer = QTimer(self)
        self.blur_timer.setSingleShot(True)
        self.blur_timer.timeout.connect(self._check_blur)
        QApplication.instance().installEventFilter(self)
        QApplication.instance().aboutToQuit.connect(self.dispose)

    def fit_content(self, initial=False):
        if self.closing:
            return
        width = min(max(t.PANEL_WIDTHS[self.kind], self.source.width()), self.screen_rect.width())
        self.body.setFixedWidth(round(width))
        self.body.layout().activate()
        height = self.body.layout().sizeHint().height()
        self.target, self.edge = panel_geometry(self.source, self.screen_rect, width, height)
        if height > self.target.height():
            self.body.setFixedWidth(round(width) - t.px(6))
            self.body.layout().activate()
            height = self.body.layout().sizeHint().height()
        self.body.setFixedHeight(height)
        self.effect.invalidate()
        rect = self.target.adjusted(-t.dp(48), -t.dp(48), t.dp(48), t.dp(48)).intersected(self.screen_rect)
        self.bounds = rect.toAlignedRect()
        self.setGeometry(self.bounds)
        if initial:
            if self.edge == 'left': self.current[4] = 0
            if self.edge == 'right': self.current[5] = 0
        elif self.done_opening:
            if not self.timer.isActive(): self.previous = time.monotonic()
            self.timer.start()
        self.update_geometry()

    def invalidate_content(self, part):
        if self._disposed:
            return
        parts = {'quick': ('brightness', 'audio', 'status'), 'media': ('media', 'audio'), 'tray': ('tray',), 'calendar': ()}
        problem = self.backend.state.problem
        if part in ('all', 'error', *parts[self.kind]) or problem != self._problem:
            self.effect.invalidate()
            self.effect.update()
        self._problem = problem

    def show_panel(self):
        self.started = self.previous = time.monotonic()
        self.owner.cover(True)
        self.show()
        self.raise_()
        if not self.preview_parent:
            disable_native_rounding(self)
            self.activateWindow()
        self.focus_grace = time.monotonic() + .2
        self.tick()
        self.timer.start()
        if self.kind == 'quick': self.brightness_timer.start()

    def owner_destroyed(self):
        if self._disposed:
            return
        self.timer.stop()
        self.hide()
        if Panel.active is self: Panel.active = None
        self.deleteLater()

    def dispose(self):
        """Release native effect resources while QApplication is still alive."""
        if self._disposed:
            return
        self._disposed = self.closing = True
        self.timer.stop()
        self.brightness_timer.stop()
        self.blur_timer.stop()
        QApplication.instance().removeEventFilter(self)
        self.backend.changed.disconnect(self.invalidate_content)
        self.backend.tray_menu_started.disconnect(self._menu_started)
        self.hide()
        self.body.setGraphicsEffect(None)
        self.effect = None
        if Panel.active is self:
            Panel.active = None
        self.deleteLater()

    def _destination(self):
        rect = self.source if self.closing else self.target
        radius = t.dp(16) if self.closing else t.PANEL_RADIUS
        return [rect.x(), rect.y(), rect.width(), rect.height(), 0 if self.edge == 'left' else radius, 0 if self.edge == 'right' else radius]

    def tick(self):
        if self._disposed:
            return
        now = time.monotonic()
        elapsed_frames = min(2, max(0, (now - self.previous) * 60))
        self.previous = now
        destination = self._destination()
        settled = True
        for i, target in enumerate(destination):
            if self.reduced:
                self.current[i] = target
                continue
            delta = target - self.current[i]
            movement = self.velocity[i] * (1 - .86) + delta * .19 * elapsed_frames
            if abs(delta) < .1 and abs(movement) < .1:
                self.current[i], self.velocity[i] = target, 0
            else:
                self.current[i] += movement
                self.velocity[i] = movement
                settled = False
        elapsed = (now - self.started) * 1000
        if self.closing:
            opacity = max(0, 1 - elapsed / (100 if self.reduced else 120)) ** 3
        else:
            fraction = min(1, max(0, (elapsed - (0 if self.reduced else 70)) / (100 if self.reduced else 220)))
            opacity = 1 - (1 - fraction) ** 3
        self.opacity = opacity
        self.effect.set_amount(opacity, 0 if self.reduced else t.dp(4) * (1 - opacity), 0 if self.reduced else t.dp(4) * (1 - opacity))
        self.viewport_widget.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, opacity < .8 or self.closing)
        self.update_geometry()
        self.update()
        if settled and ((self.closing and opacity <= 0) or (not self.closing and opacity >= 1)):
            self.current = destination
            self.update_geometry()
            self.timer.stop()
            if self.closing:
                self.hide()
                self.owner.cover(False)
                if self.return_focus and not sip.isdeleted(self.return_focus):
                    self.return_focus.setFocus(Qt.FocusReason.OtherFocusReason)
                QApplication.instance().removeEventFilter(self)
                if Panel.active is self: Panel.active = None
                self.finished.emit()
                callback = self.after_close
                self.deleteLater()
                if callback: QTimer.singleShot(0, callback)
            elif not self.done_opening:
                self.done_opening = True
                self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                control = self.body.primary_control()
                if control: control.setFocus(Qt.FocusReason.OtherFocusReason)

    def update_geometry(self):
        x, y, w, h, left, right = self.current
        self.local_shape = QRectF(x - self.bounds.x(), y - self.bounds.y(), max(0, w), max(0, h))
        self.viewport_widget.setGeometry(self.rect())
        clip = t.squircle(self.local_shape, corners=(0, 0, right, left))
        self.viewport_widget.setMask(QRegion(clip.toFillPolygon().toPolygon()))
        self.scroll.setGeometry(round(self.target.x() - self.bounds.x()), round(self.target.y() - self.bounds.y()), round(self.target.width()), round(self.target.height()))

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        x, y, w, h, left, right = self.current
        p.setOpacity(getattr(self, 'opacity', 0))
        if w > 0 and h > 0:
            cap = min(w, h) / 2
            paint_shadow(p, self.local_shape, int(min(left, cap)), int(min(right, cap)))
        p.setOpacity(1)
        p.fillPath(t.squircle(self.local_shape, corners=(0, 0, right, left)), QColor(t.BLACK))

    def close_panel(self, callback=None):
        if self.closing:
            if callback: self.after_close = callback
            return
        self.closing = True
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.after_close = callback
        self.started = self.previous = time.monotonic()
        self.brightness_timer.stop()
        self.blur_timer.stop()
        self.timer.start()

    def _menu_started(self):
        if self.isVisible() and self.kind == 'tray':
            self.native_menu_until = time.monotonic() + 1.5

    def _check_blur(self):
        if self.closing or self.preview_parent:
            return
        if time.monotonic() < self.focus_grace or time.monotonic() < self.native_menu_until or menu_active() or QApplication.activePopupWidget():
            self.blur_timer.start(100)
        elif not self.isActiveWindow():
            self.close_panel()

    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.Quit:
            self.dispose()
            return False
        if not self.isVisible():
            return False
        if self.closing:
            return event.type() == QEvent.Type.KeyPress and isinstance(obj, QWidget) and self.isAncestorOf(obj)
        popup = QApplication.activePopupWidget()
        if popup and self.isAncestorOf(popup.parentWidget()):
            return False
        if event.type() == QEvent.Type.KeyPress and event.key() == Qt.Key.Key_Escape:
            if self.kind == 'tray' and menu_active(): return False
            self.close_panel()
            return True
        if event.type() == QEvent.Type.KeyPress and isinstance(obj, QWidget) and self.isAncestorOf(obj) and self.viewport_widget.testAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents):
            return True
        if event.type() == QEvent.Type.WindowDeactivate and obj is self:
            self.blur_timer.start(140)
        if event.type() == QEvent.Type.MouseButtonPress and hasattr(event, 'globalPosition'):
            point = event.globalPosition().toPoint()
            if self.preview_parent:
                point = self.preview_parent.mapFromGlobal(point)
            shape = QRectF(*self.current[:4])
            path = t.squircle(shape, corners=(0, 0, self.current[5], self.current[4]))
            if not path.contains(QPointF(point)):
                self.close_panel()
        return False

    def closeEvent(self, event):
        if not self.closing:
            event.ignore()
            self.close_panel()
        else:
            event.accept()
