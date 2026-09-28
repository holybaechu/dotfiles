from __future__ import annotations

import time
from math import ceil

from pydantic import BaseModel, Field
from PyQt6.QtCore import QDate, QLocale, QPoint, QRectF, QSize, Qt, QTime, QTimer
from PyQt6.QtGui import QColor, QFontMetricsF, QPainter, QPainterPath
from PyQt6.QtWidgets import QHBoxLayout, QRadioButton, QSizePolicy, QWidget

from core.widgets.base import BaseWidget
from core.validation.widgets.base_model import KeybindingConfig
from . import theme as t
from .controls import Button
from .island import FadeBlur, Panel
from .status_icons import battery_icon, volume_icon


class Config(BaseModel):
    preview: bool = False
    keybindings: list[KeybindingConfig] = Field(default_factory=list)


class Divider(QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(t.px(9), t.px(36))

    def paintEvent(self, event):
        p = QPainter(self)
        p.fillRect(t.rect(4, 13, 1, 10), QColor(t.SURFACE))


class LayoutLabel(QWidget):
    def __init__(self):
        super().__init__()
        self.caption = ''
        self.setFixedHeight(t.px(36))

    def setText(self, value):
        self.caption = value
        self.setFixedWidth(t.px(20) + ceil(QFontMetricsF(t.font(10), self).horizontalAdvance(value)))
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        t.icon(painter, 'panels-top-left', t.rect(0, 10.5, 15, 15), t.MUTED)
        t.text(painter, QRectF(t.dp(20), 0, self.width() - t.dp(20), t.dp(36)), self.caption, 10, t.MUTED)


class WorkspaceButton(QRadioButton):
    def __init__(self, name, occupied, action, parent):
        super().__init__(name, parent)
        self.occupied = occupied
        self.setAccessibleName(f'Workspace {name}')
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.clicked.connect(action)
        self.setFixedHeight(t.WORKSPACE_HEIGHT)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        highlight = self.parentWidget().highlight_path().translated(-self.x(), -self.y())
        outside = QPainterPath()
        outside.addRect(QRectF(self.rect()))
        highlight = highlight.intersected(outside)
        outside = outside.subtracted(highlight)
        p.save()
        p.setClipPath(outside)
        if self.underMouse() and not self.isChecked():
            p.fillPath(t.squircle(self.rect(), t.WORKSPACE_HIGHLIGHT_RADIUS), QColor(t.RAISED))
        t.text(p, QRectF(self.rect()), self.text(), 11, t.MUTED, 500, Qt.AlignmentFlag.AlignCenter)
        if self.occupied:
            p.fillRect(QRectF(self.width() / 2 - t.dp(2), t.WORKSPACE_HEIGHT - t.dp(5), t.dp(4), t.dp(2)), QColor(t.MUTED))
        p.restore()
        if not highlight.isEmpty():
            p.save()
            p.setClipPath(highlight)
            t.text(p, QRectF(self.rect()), self.text(), 11, t.TEXT, 600, Qt.AlignmentFlag.AlignCenter)
            p.restore()
        if t.keyboard_focus(self):
            from PyQt6.QtGui import QPen
            p.setPen(QPen(QColor(t.GREEN), t.dp(2)))
            p.drawPath(t.squircle(QRectF(self.rect()).adjusted(t.dp(1), t.dp(1), -t.dp(1), -t.dp(1)), max(0, t.WORKSPACE_HIGHLIGHT_RADIUS - t.dp(1))))


class Workspaces(QWidget):
    def __init__(self, owner):
        super().__init__()
        self.owner = owner
        self.box = QHBoxLayout(self)
        self.box.setContentsMargins(0, 0, 0, 0)
        self.box.setSpacing(t.px(3))
        self.buttons = []
        self.current = [0., t.dp(26)]
        self.velocity = [0., 0.]
        self.target = [0., t.dp(26)]
        self.timer = QTimer(self)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.timer.setInterval(t.frame_interval(self.screen()))
        self.timer.timeout.connect(self._step)
        self.setFixedHeight(t.WORKSPACE_HEIGHT)
        self.waiting = False

    def sync(self, workspaces, width):
        names = [w['name'] for w in workspaces]
        if [button.text() for button in self.buttons] != names:
            for button in self.buttons:
                self.box.removeWidget(button)
                button.deleteLater()
            self.buttons = []
            for i, workspace in enumerate(workspaces):
                button = WorkspaceButton(workspace['name'], workspace['occupied'], lambda _checked=False, index=i: self.owner.backend.focus_workspace(self.owner.monitor_handle(), index), self)
                self.buttons.append(button)
                self.box.addWidget(button)
        self.waiting = not workspaces
        minimum = t.px(16 if width <= t.px(600) else 19 if width <= t.px(740) else 26)
        for button, workspace in zip(self.buttons, workspaces):
            button.setFixedWidth(max(minimum, button.fontMetrics().horizontalAdvance(button.text()) + t.px(6 if width <= t.px(740) else 12)))
            button.occupied = workspace['occupied']
            button.setChecked(workspace['active'])
            button.update()
        self.setFixedWidth(self.box.sizeHint().width() if workspaces else t.px(86))
        self.box.activate()
        selected = next((button for button in self.buttons if button.isChecked()), None)
        if selected:
            self.target = [float(selected.x()), float(selected.width())]
            if not self.owner.animated:
                self.current = self.target[:]
            if not self.timer.isActive(): self.previous = time.monotonic()
            self.timer.start()
        self.update()

    def _step(self):
        now = time.monotonic()
        elapsed = min(2, max(0, (now - self.previous) * 60))
        self.previous = now
        done = True
        for i in range(2):
            self.velocity[i] = self.velocity[i] * .2 + (self.target[i] - self.current[i]) * .22 * elapsed
            self.current[i] += self.velocity[i]
            done &= abs(self.current[i] - self.target[i]) < .1 and abs(self.velocity[i]) < .1
        if done:
            self.current = self.target[:]
            self.timer.stop()
        self.update()
        for button in self.buttons:
            button.update()

    def highlight_path(self):
        if not any(button.isChecked() for button in self.buttons):
            return QPainterPath()
        return t.squircle(QRectF(self.current[0], 0, self.current[1], t.WORKSPACE_HEIGHT), t.WORKSPACE_HIGHLIGHT_RADIUS)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.waiting:
            t.text(p, QRectF(self.rect()), 'Komorebi…', 12, t.MUTED)
        else:
            p.fillPath(self.highlight_path(), QColor(t.RAISED))
            p.fillPath(t.squircle(QRectF(self.current[0] + t.dp(7), t.WORKSPACE_HEIGHT - t.dp(2), max(0, self.current[1] - t.dp(14)), t.dp(2)), t.dp(1)), QColor(t.GREEN))


class Section(QWidget):
    def __init__(self, canvas, side, left=t.SECTION_PADDING, right=t.SECTION_PADDING):
        super().__init__(canvas)
        self.canvas, self.side = canvas, side
        self.box = QHBoxLayout(self)
        self.box.setContentsMargins(left, t.SECTION_PADDING, right, t.SECTION_PADDING)
        self.box.setSpacing(t.px(4))
        self.effect = FadeBlur(self)
        self.setGraphicsEffect(self.effect)
        self.covered = False
        self.timer = QTimer(self)
        self.timer.setTimerType(Qt.TimerType.PreciseTimer)
        self.timer.setInterval(t.frame_interval(self.screen()))
        self.timer.timeout.connect(self._fade)

    def cover(self, covered):
        self.covered = covered
        self.setEnabled(not covered)
        self.fade_start = time.monotonic()
        self.initial = self.effect.opacity
        self.initial_blur = self.effect.blur
        self.timer.start()

    def _fade(self):
        elapsed = time.monotonic() - self.fade_start
        progress = min(1, elapsed / (.12 if self.covered else .24))
        fraction = 1 - (1 - progress) ** 3
        opacity = self.initial + ((0 if self.covered else 1) - self.initial) * fraction
        blur_progress = min(1, elapsed / (.12 if self.covered else .28))
        blur = self.initial_blur + ((t.dp(4) if self.covered else 0) - self.initial_blur) * (1 - (1 - blur_progress) ** 3)
        self.effect.set_amount(opacity, blur if self.canvas.animated else 0, -blur / 2 if self.canvas.animated else 0)
        if blur_progress >= 1: self.timer.stop()

    def toggle(self, kind):
        origin = self.mapTo(self.canvas.preview_parent, QPoint()) if self.canvas.preview_parent else self.mapToGlobal(QPoint())
        source = QRectF(origin.x(), origin.y(), self.width(), self.height())
        Panel.toggle(kind, self, source, self.canvas.backend, self.canvas.preview_parent)


class MediaButton(Button):
    def __init__(self, canvas, section):
        super().__init__('Open media panel', callback=lambda: section.toggle('media'), size=None, radius=t.BAR_HIGHLIGHT_RADIUS)
        self.canvas = canvas
        self.setFixedHeight(t.BAR_BUTTON_HEIGHT)

    def draw_contents(self, p):
        track = self.canvas.backend.state.track
        p.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        inset = t.BAR_BUTTON_PADDING
        end = self.width() - inset
        text_x = inset + t.dp(31)
        path = t.squircle(QRectF(inset, inset, t.dp(24), t.dp(24)), t.dp(7))
        p.fillPath(path, QColor(t.SURFACE))
        if track and track.art and not track.art.isNull():
            p.save()
            p.setClipPath(path)
            side = min(track.art.width(), track.art.height())
            p.drawImage(QRectF(inset, inset, t.dp(24), t.dp(24)), track.art, QRectF((track.art.width() - side) / 2, (track.art.height() - side) / 2, side, side))
            p.restore()
        else:
            t.icon(p, 'music-2' if track else 'app-window', QRectF(inset + t.dp(4), inset + t.dp(4), t.dp(16), t.dp(16)), t.GREEN)
        title = track.title if track else self.canvas.window_title or 'Desktop'
        subtitle = track.artist if track else f'{self.canvas.layout_name} · Komorebi'
        t.text(p, QRectF(text_x, inset, end - text_x, t.dp(12)), title, 11, weight=600)
        time_width = 0
        if track:
            value = f'{t.duration(track.position)} / {t.duration(track.duration)}' if track.duration else t.duration(track.position)
            p.setFont(t.utility_font(10))
            metrics = QFontMetricsF(p.font(), p.device())
            time_width = ceil(metrics.horizontalAdvance(value)) + t.px(6)
            suffix = f' / {t.duration(track.duration)}' if track.duration else ''
            suffix_width = ceil(metrics.horizontalAdvance(suffix))
            t.text(p, QRectF(end - time_width, t.dp(16), time_width - suffix_width, t.dp(12)), t.duration(track.position), 10, t.TEXT, align=Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, family=t.UTILITY_FAMILY)
            t.text(p, QRectF(end - suffix_width, t.dp(16), suffix_width, t.dp(12)), suffix, 10, t.MUTED, family=t.UTILITY_FAMILY)
        t.text(p, QRectF(text_x, t.dp(16), max(0, end - text_x - time_width - t.dp(6)), t.dp(12)), subtitle, 10, t.MUTED)


class Status(Button):
    def __init__(self, canvas, section):
        super().__init__('Open sound and network controls', callback=lambda: section.toggle('quick'), size=None, radius=t.BAR_HIGHLIGHT_RADIUS)
        self.canvas = canvas
        self.setFixedHeight(t.BAR_BUTTON_HEIGHT)

    def sync(self):
        state, width = self.canvas.backend.state, self.canvas.width()
        self.symbols = []
        if width > t.px(600):
            self.symbols.append(('wifi' if state.connected else 'wifi-off', t.GREEN if state.connected else t.MUTED))
        volume_color = t.MUTED if not state.audio_available else t.GREEN if state.muted else t.TEXT
        self.symbols.append((volume_icon(state.volume, state.muted, state.audio_available), volume_color))
        if state.battery is not None:
            battery_color = t.GREEN if state.power_plugged else t.ERROR if state.battery <= 15 else t.TEXT
            self.symbols.append((battery_icon(state.battery, state.power_plugged), battery_color))
        self.gap = t.px(9 if width > t.px(600) else 5)
        self.percent = f'{state.battery}%' if state.battery is not None and width > t.px(740) else ''
        self.percent_width = ceil(QFontMetricsF(t.utility_font(11), self).horizontalAdvance(self.percent))
        total = 2 * t.BAR_BUTTON_PADDING + t.dp(15) * len(self.symbols) + self.gap * (len(self.symbols) - 1)
        if self.percent:
            total += t.dp(8) + self.percent_width
        self.content_width = total - 2 * t.BAR_BUTTON_PADDING
        self.setFixedWidth(ceil(total))
        self.update()

    def draw_contents(self, p):
        x = (self.width() - self.content_width) / 2
        for index, (glyph, color) in enumerate(self.symbols):
            if index: x += self.gap
            t.icon(p, glyph, QRectF(x, (self.height() - t.dp(15)) / 2, t.dp(15), t.dp(15)), color)
            x += t.dp(15)
        if self.percent:
            t.text(p, QRectF(x + t.dp(8), 0, self.percent_width, self.height()), self.percent, 11, t.TEXT, family=t.UTILITY_FAMILY)


class Clock(Button):
    def __init__(self, canvas, section):
        super().__init__('Open calendar', callback=lambda: section.toggle('calendar'), size=None, radius=t.BAR_HIGHLIGHT_RADIUS)
        self.canvas = canvas
        self.setFixedHeight(t.BAR_BUTTON_HEIGHT)
        self.timer = QTimer(self)
        self.timer.setSingleShot(True)
        self.timer.timeout.connect(self.sync)
        self.sync()

    def sync(self):
        date = QDate.currentDate()
        locale = QLocale()
        self.time_text = QTime.currentTime().toString('HH:mm')
        self.date_text = locale.toString(date, 'd일 (ddd)' if locale.language() == QLocale.Language.Korean else 'd ddd') if self.canvas.width() > t.px(1000) else ''
        self.date_width = ceil(QFontMetricsF(t.font(10), self).horizontalAdvance(self.date_text)) if self.date_text else 0
        self.setFixedWidth(2 * t.BAR_BUTTON_PADDING + ceil(QFontMetricsF(t.utility_font(12, 600), self).horizontalAdvance(self.time_text)) + (self.date_width + t.px(9) if self.date_text else 0))
        self.timer.start(60000 - round(time.time() * 1000) % 60000)
        self.canvas.right.effect.invalidate()
        self.update()

    def draw_contents(self, p):
        inset = t.BAR_BUTTON_PADDING
        if self.date_text:
            t.text(p, QRectF(inset, 0, self.date_width, self.height()), self.date_text, 10, t.MUTED)
        time_x = inset + (self.date_width + t.px(9) if self.date_text else 0)
        t.text(p, QRectF(time_x, 0, self.width() - time_x - inset, self.height()), self.time_text, 12, weight=600, family=t.UTILITY_FAMILY)


class Canvas(QWidget):
    def __init__(self, backend, preview_parent=None):
        super().__init__()
        from .native import reduced_motion
        self.backend, self.preview_parent = backend, preview_parent
        self.animated = not reduced_motion()
        self.monitor_handle = lambda: 0
        self.monitor_index = 0
        self.layout_name = self.window_title = ''
        self.setFixedHeight(t.BAR_HEIGHT)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.left = Section(self, 'left', t.EDGE_INSET, t.SECTION_PADDING)
        self.center = Section(self, 'center')
        self.right = Section(self, 'right', t.SECTION_PADDING, t.EDGE_INSET)
        self.launcher = Button('Open app launcher', 'windows10', self.launch, glyph_size=15, color=t.GREEN, radius=t.BAR_HIGHLIGHT_RADIUS)
        self.left.box.addWidget(self.launcher)
        self.workspaces = Workspaces(self)
        self.left.box.addWidget(self.workspaces)
        self.layout_divider = Divider()
        self.left.box.addWidget(self.layout_divider)
        from .controls import Label
        self.layout_label = LayoutLabel()
        self.left.box.addWidget(self.layout_label)
        self.media_button = MediaButton(self, self.center)
        self.center.box.addWidget(self.media_button)
        self.error_button = Button('Show connection problems', 'circle-alert', lambda: self.right.toggle('quick'), glyph_size=15, color=t.ERROR, radius=t.BAR_HIGHLIGHT_RADIUS)
        self.right.box.addWidget(self.error_button)
        self.right.box.addWidget(Button('Show system tray', 'chevron-down', lambda: self.right.toggle('tray'), glyph_size=15, radius=t.BAR_HIGHLIGHT_RADIUS))
        self.right.box.addWidget(Divider())
        self.status = Status(self, self.right)
        self.right.box.addWidget(self.status)
        self.right.box.addWidget(Divider())
        self.clock = Clock(self, self.right)
        self.right.box.addWidget(self.clock)
        backend.changed.connect(self.sync)
        self.sync('all')

    def launch(self):
        from .launcher import Launcher

        if Panel.active and Panel.active.isVisible():
            Panel.active.close_panel(lambda: Launcher.toggle(self, self.preview_parent))
        else:
            Launcher.toggle(self, self.preview_parent)

    def sync(self, part):
        if part in ('media', 'wm', 'all'): self.center.effect.invalidate()
        if part in ('audio', 'status', 'all', 'error'): self.right.effect.invalidate()
        if part in ('wm', 'all'): self.left.effect.invalidate()
        if part in ('wm', 'all'):
            workspaces, self.layout_name, self.window_title, self.monitor_index = self.backend.workspaces(self.monitor_handle())
            self.workspaces.sync(workspaces, self.width())
            self.layout_label.setText(self.layout_name)
        if part in ('audio', 'status', 'all'):
            self.status.sync()
        if part in ('media', 'wm', 'all'):
            self.media_button.update()
        self.error_button.setVisible(bool(self.backend.state.problem))
        self.error_button.setToolTip(self.backend.state.problem)
        if part != 'media': self.place_sections()

    def resizeEvent(self, event):
        self.launcher.setVisible(self.width() > t.px(600))
        self.layout_label.setVisible(self.width() > t.px(1000) and bool(self.layout_name))
        self.layout_divider.setVisible(not self.layout_label.isHidden())
        self.clock.sync()
        self.status.sync()
        workspaces, self.layout_name, self.window_title, self.monitor_index = self.backend.workspaces(self.monitor_handle())
        self.workspaces.sync(workspaces, self.width())
        self.place_sections()

    def place_sections(self):
        center_width = t.px(130 if self.width() <= t.px(600) else 160 if self.width() <= t.px(740) else 200 if self.width() <= t.px(1000) else 256)
        self.left.setGeometry(0, 0, self.left.box.sizeHint().width(), t.BAR_HEIGHT)
        self.center.setGeometry((self.width() - center_width) // 2, 0, center_width, t.BAR_HEIGHT)
        self.right.setGeometry(self.width() - self.right.box.sizeHint().width(), 0, self.right.box.sizeHint().width(), t.BAR_HEIGHT)
        self.update()

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        for section in (self.left, self.center, self.right):
            t.notch(p, QRectF(section.geometry()), section.side)


class CanopyWidget(BaseWidget):
    validation_schema = Config
    event_listener = None

    def __init__(self, config):
        super().__init__(class_name='canopy-widget')
        from .backend import Backend
        from .model import PreviewBackend
        self.backend = PreviewBackend() if config.preview else Backend.instance()
        self.canvas = Canvas(self.backend)
        self.register_callback('toggle_launcher', self.canvas.launch)
        self.widget_layout.addWidget(self.canvas)
        self.setFixedHeight(t.BAR_HEIGHT)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        QTimer.singleShot(0, self.bind_bar)

    def bind_bar(self):
        bar = self.window()
        if hasattr(bar, '_bar_frame'):
            layout = bar._bar_frame.layout()
            for index, stretch in enumerate((0, 1, 0)):
                layout.setColumnStretch(index, stretch)
            from .host import window_monitor_identity
            self.canvas.monitor_handle = lambda: window_monitor_identity(int(self.window().winId()))
            handle = bar.windowHandle()
            if handle and not getattr(self, '_screen_bound', False):
                handle.screenChanged.connect(self.screen_changed)
                self._screen_bound = True
            for widget in (self.canvas.left, self.canvas.center, self.canvas.right, self.canvas.workspaces):
                widget.timer.setInterval(t.frame_interval(self.screen()))
            self.canvas.sync('all')

    def screen_changed(self, screen):
        for widget in (self.canvas.left, self.canvas.center, self.canvas.right, self.canvas.workspaces):
            widget.timer.setInterval(t.frame_interval(screen))
        self.canvas.sync('all')
