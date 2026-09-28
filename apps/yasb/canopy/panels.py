from __future__ import annotations

import calendar
import datetime as dt

from PyQt6.QtCore import QDate, QLocale, QRectF, Qt, pyqtSignal
from PyQt6.QtGui import QColor, QPainter, QPen, QTextLayout, QTextOption
from PyQt6.QtWidgets import QGridLayout, QHBoxLayout, QVBoxLayout, QWidget

from . import theme as t
from .controls import Button, Cover, Icon, Label, Slider, Surface
from .details import Percentage, BatteryFooter
from .status_icons import brightness_icon, volume_icon


def row(parent=None, margins=(0, 0, 0, 0), spacing=8):
    widget = QWidget(parent)
    layout = QHBoxLayout(widget)
    layout.setContentsMargins(*(t.px(value) for value in margins))
    layout.setSpacing(t.px(spacing))
    return widget, layout


class SettingsLink(Button):
    def __init__(self, name, backend, page, parent=None):
        super().__init__(name, callback=lambda: backend.open_settings(page), size=None, parent=parent)
        self.caption = name
        self.setFixedHeight(t.px(24))

    def draw_contents(self, p):
        t.text(p, QRectF(0, 0, self.width() - t.dp(22), self.height()), self.caption, 11, t.TEXT if self.underMouse() else t.MUTED)
        side = t.dp(13)
        t.icon(p, 'chevron-right', QRectF(self.width() - side, (self.height() - side) / 2, side, side), t.MUTED)


class ModeCard(Button):
    """Keep the checked state tied to Windows' confirmed state, not the click."""

    def __init__(self, name, glyph, backend, state_field, callback, settings_page, parent=None):
        super().__init__(name, callback=self._toggle,
                         size=None, background=t.SURFACE, radius=t.dp(18), parent=parent)
        self.caption, self.symbol, self.backend = name, glyph, backend
        self.state_field = state_field
        self._toggle_action = callback
        self.settings_arrow = Button(f'Open {name} settings', 'arrow-up-right',
                                     lambda: backend.open_settings(settings_page),
                                     size=(26, 30), glyph_size=13, parent=self)
        self.setFixedHeight(t.px(51))
        self.setCheckable(True)
        self.sync()

    @property
    def toggle_enabled(self):
        return self.enabled_state is not None and self.state_field not in self.backend.state.pending_modes

    def _toggle(self):
        if self.toggle_enabled:
            self._toggle_action(not self.enabled_state)

    def resizeEvent(self, event):
        self.settings_arrow.move(self.width() - t.px(29), t.px(10))
        super().resizeEvent(event)

    def nextCheckState(self):
        # QAbstractButton normally flips on click, before the native write completes.
        pass

    @property
    def enabled_state(self):
        return getattr(self.backend.state, self.state_field)

    @property
    def subtitle(self):
        value = self.enabled_state
        if self.state_field in self.backend.state.pending_modes:
            return 'Updating…'
        return ('On' if value else 'Off') if value is not None else 'Unavailable'

    def sync(self):
        value = self.enabled_state
        pending = self.state_field in self.backend.state.pending_modes
        self.setChecked(value is True)
        # Keep the Settings arrow usable even when the native toggle is unavailable.
        self.setCursor(Qt.CursorShape.PointingHandCursor if self.toggle_enabled else Qt.CursorShape.ArrowCursor)
        self.settings_arrow.color = t.BLACK if value else t.MUTED
        background = t.GREEN if value else t.SURFACE
        if self.settings_arrow.background != background:
            self.settings_arrow.background = background
            self.settings_arrow._animate_fill()
        self.settings_arrow.update()
        if self.background != background:
            self.background = background
            self._animate_fill()
        hint = self.backend.state.mode_errors.get(self.state_field)
        if not hint:
            hint = f'{self.caption}: {self.subtitle.lower()}.'
            if value is not None and not pending:
                hint += f' Turn {"off" if value else "on"}.'
        self.setToolTip(hint)
        self.setAccessibleDescription(hint)
        self.update()

    def draw_contents(self, p):
        color = t.BLACK if self.enabled_state else t.TEXT
        secondary = t.BLACK if self.enabled_state else t.MUTED
        glyph = 'wifi-off' if self.symbol == 'wifi' and self.enabled_state is False else self.symbol
        t.icon(p, glyph, QRectF(t.dp(12), t.dp(16), t.dp(18), t.dp(18)), secondary)
        t.text(p, QRectF(t.dp(38), t.dp(9), self.width() - t.dp(65), t.dp(16)), self.caption, 11, color, weight=500)
        t.text(p, QRectF(t.dp(38), t.dp(26), self.width() - t.dp(65), t.dp(14)), self.subtitle, 11, secondary)


class BrightnessRow(QWidget):
    def __init__(self, display, backend, parent=None):
        super().__init__(parent)
        self.identifier = display['id']
        box = QVBoxLayout(self)
        box.setContentsMargins(0, 0, 0, 0)
        box.setSpacing(t.px(7))
        heading, heading_box = row()
        self.symbol = Icon(brightness_icon(display['brightness']), (16, 20), 14, t.MUTED)
        self.name = Label(display['name'], 11, t.MUTED)
        self.name.setToolTip(display['name'])
        self.percent = Percentage(16)
        heading_box.addWidget(self.symbol)
        heading_box.addWidget(self.name, 1)
        heading_box.addWidget(self.percent)
        box.addWidget(heading)
        self.slider = Slider(f"Brightness {display['name']}", lambda value: backend.set_brightness(self.identifier, value), commit=True)
        self.slider.valueChanged.connect(self.preview_level)
        box.addWidget(self.slider)
        self.unsupported = Label('Use the monitor controls, or enable DDC/CI.', 11, t.MUTED)
        self.unsupported.setWordWrap(True)
        box.addWidget(self.unsupported)
        self.sync(display)

    def preview_level(self, value):
        self.percent.setText(f'{value}%')
        self.symbol.glyph = brightness_icon(value)
        self.symbol.update()

    def sync(self, display):
        self.name.setText(display['name'])
        available = display['brightness'] is not None
        self.slider.setEnabled(available)
        self.unsupported.setVisible(not available)
        if not self.slider.isSliderDown():
            self.slider.set_external_value(display['brightness'] or 0)
            self.percent.setText(f"{round(display['brightness'])}%" if available else '—')
            self.symbol.glyph = brightness_icon(display['brightness'])
            self.symbol.update()


class Quick(QWidget):
    size_changed = pyqtSignal()

    def __init__(self, backend, parent=None):
        super().__init__(parent)
        self.backend = backend
        box = QVBoxLayout(self)
        box.setContentsMargins(0, 0, 0, 0)
        box.setSpacing(t.px(12))
        self.brightness = Surface()
        heading, heading_box = row(spacing=8)
        heading.setFixedHeight(t.px(28))
        self.brightness_symbol = Icon('monitor')
        heading_box.addWidget(self.brightness_symbol)
        heading_box.addWidget(Label('Brightness', weight=500), 1)
        heading_box.addWidget(Button('Open display settings', 'arrow-up-right', lambda: backend.open_settings('display'), (28, 28), 13))
        self.brightness.box.addWidget(heading)
        self.brightness.box.addSpacing(t.px(8))
        self.brightness_rows = QVBoxLayout()
        self.brightness_rows.setContentsMargins(0, 0, 0, 0)
        self.brightness_rows.setSpacing(t.px(12))
        self.brightness.box.addLayout(self.brightness_rows)
        self.display_widgets = {}
        self.no_displays = Label('Finding displays…', 11, t.MUTED)
        self.brightness.box.addWidget(self.no_displays)
        box.addWidget(self.brightness)
        volume = Surface()
        volume_heading, volume_heading_box = row()
        volume_heading.setFixedHeight(t.px(32))
        self.mute = Button('Mute playback', 'volume-2', lambda: backend.set_mute(not backend.state.muted))
        self.mute.setCheckable(True)
        volume_heading_box.addWidget(self.mute)
        volume_heading_box.addWidget(Label('Volume', weight=500))
        self.muted_label = Label('Muted', 10, t.MUTED)
        volume_heading_box.addWidget(self.muted_label)
        volume_heading_box.addStretch(1)
        self.volume_label = Percentage(24)
        volume_heading_box.addWidget(self.volume_label)
        volume.box.addWidget(volume_heading)
        volume.box.addSpacing(t.px(10))
        self.volume = Slider('Volume', backend.set_volume)
        self.volume.valueChanged.connect(lambda value: self.volume_label.setText(f'{value}%'))
        volume.box.addWidget(self.volume)
        volume.box.addSpacing(t.px(10))
        self.device = SettingsLink('Speakers', backend, 'sound')
        volume.box.addWidget(self.device)
        box.addWidget(volume)
        shortcuts, shortcuts_box = row()
        self.wifi = ModeCard('Wi-Fi', 'wifi', backend, 'wifi_enabled', backend.set_wifi_enabled, 'network-wifi')
        self.bluetooth = ModeCard('Bluetooth', 'bluetooth', backend, 'bluetooth_enabled', backend.set_bluetooth_enabled, 'bluetooth')
        shortcuts_box.addWidget(self.wifi, 1)
        shortcuts_box.addWidget(self.bluetooth, 1)
        box.addWidget(shortcuts)
        modes, modes_box = row()
        self.airplane = ModeCard('Airplane mode', 'plane', backend, 'airplane_mode', backend.set_airplane_mode, 'network-airplanemode')
        self.battery_saver = ModeCard('Battery saver', 'leaf', backend, 'battery_saver', backend.set_battery_saver, 'batterysaver')
        modes_box.addWidget(self.airplane, 1)
        modes_box.addWidget(self.battery_saver, 1)
        box.addWidget(modes)
        self.battery = BatteryFooter(backend)
        box.addWidget(self.battery)
        self.sync('all')
        backend.changed.connect(self.sync)
        backend.refresh_brightness()
        backend.refresh_modes()

    def preview_brightness(self, value):
        if len(self.display_widgets) == 1:
            self.brightness_symbol.glyph = brightness_icon(value)
            self.brightness_symbol.update()

    def sync(self, part):
        if part not in ('brightness', 'audio', 'status', 'all'):
            return
        state = self.backend.state
        if part in ('brightness', 'all'):
            ids = [item['id'] for item in state.displays]
            for identifier in list(self.display_widgets):
                if identifier not in ids:
                    widget = self.display_widgets.pop(identifier)
                    self.brightness_rows.removeWidget(widget)
                    widget.deleteLater()
            for display in state.displays:
                identifier = display['id']
                if identifier not in self.display_widgets:
                    widget = BrightnessRow(display, self.backend)
                    widget.slider.valueChanged.connect(self.preview_brightness)
                    self.display_widgets[identifier] = widget
                    self.brightness_rows.addWidget(widget)
                self.display_widgets[identifier].sync(display)
                self.display_widgets[identifier].symbol.setVisible(len(state.displays) > 1)
            self.brightness_symbol.glyph = brightness_icon(state.displays[0]['brightness']) if len(state.displays) == 1 else 'monitor'
            self.brightness_symbol.update()
            self.no_displays.setVisible(not state.displays)
            self.no_displays.setText('No brightness controls found. Open display settings to check the connection.')
            self.no_displays.setWordWrap(True)
            self.size_changed.emit()
        if part in ('audio', 'all'):
            self.volume.set_external_value(state.volume)
            self.volume.setEnabled(state.audio_available)
            self.volume_label.setText(f'{state.volume}%')
            self.mute.setEnabled(state.audio_available)
            self.mute.setChecked(state.muted)
            self.mute.glyph = volume_icon(state.volume, state.muted, state.audio_available)
            self.mute.color = t.MUTED if not state.audio_available else t.GREEN if state.muted else t.TEXT
            self.mute.update()
            self.muted_label.setVisible(state.muted)
            self.device.caption = state.audio_device or 'Open sound settings'
            self.device.update()
        if part in ('status', 'all'):
            self.wifi.sync()
            self.bluetooth.sync()
            self.airplane.sync()
            self.battery_saver.sync()
            self.battery.setVisible(state.battery is not None)
            self.battery.update()
        self.update()


class MediaInfo(QWidget):
    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self.setMinimumWidth(0)
        self.setFixedHeight(t.px(104))

    def paintEvent(self, event):
        track = self.backend.state.track
        if not track:
            return
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.TextAntialiasing)
        title_font = t.display_font(25, 600)
        title_font.setLetterSpacing(title_font.SpacingType.PercentageSpacing, 96.5)
        p.setFont(title_font)
        p.setPen(QColor(t.TEXT))
        layout = QTextLayout(track.title, title_font)
        option = QTextOption()
        option.setWrapMode(QTextOption.WrapMode.WrapAtWordBoundaryOrAnywhere)
        layout.setTextOption(option)
        layout.beginLayout()
        lines = []
        for _ in range(2):
            line = layout.createLine()
            if not line.isValid(): break
            line.setLineWidth(self.width())
            lines.append(line)
        layout.endLayout()
        total = len(lines) * t.dp(27.6) + (t.dp(25) if track.artist else 0) + (t.dp(17) if track.album else 0)
        y = max(0, (self.height() - total) / 2)
        for index, line in enumerate(lines):
            value = track.title[line.textStart():line.textStart() + line.textLength()]
            if index == 1 and line.textStart() + line.textLength() < len(track.title):
                value = p.fontMetrics().elidedText(track.title[line.textStart():], Qt.TextElideMode.ElideRight, self.width())
            p.drawText(0, round(y + p.fontMetrics().ascent()), value)
            y += t.dp(27.6)
        if track.artist:
            y += t.dp(8)
            t.text(p, QRectF(0, y, self.width(), t.dp(17)), track.artist, 13)
            y += t.dp(17)
        if track.album:
            t.text(p, QRectF(0, y + t.dp(3), self.width(), t.dp(14)), track.album, 11, t.MUTED)


class Progress(QWidget):
    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self.setFixedHeight(t.px(25))

    def paintEvent(self, event):
        track = self.backend.state.track
        if not track or track.duration <= 0:
            return
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        path = t.squircle(QRectF(0, 0, self.width(), t.dp(4)), t.dp(2))
        p.fillPath(path, QColor(t.RAISED))
        p.setClipPath(path)
        p.fillRect(QRectF(0, 0, self.width() * min(1, track.position / track.duration), t.dp(4)), QColor(t.GREEN))
        p.setClipping(False)
        t.text(p, QRectF(0, t.dp(10), self.width() / 2, t.dp(15)), t.duration(track.position), 11, family=t.UTILITY_FAMILY)
        t.text(p, QRectF(self.width() / 2, t.dp(10), self.width() / 2, t.dp(15)), t.duration(track.duration), 11, t.MUTED, align=Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, family=t.UTILITY_FAMILY)


class Media(QWidget):
    size_changed = pyqtSignal()

    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        box = QVBoxLayout(self)
        box.setContentsMargins(0, 0, 0, 0)
        box.setSpacing(0)
        self.empty = Label('No media playing\n\nPlay something in a media app to see it here.', 12, t.MUTED)
        self.empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.empty.setFixedHeight(t.px(120))
        box.addWidget(self.empty)
        self.content = QWidget()
        body = QVBoxLayout(self.content)
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)
        top, top_box = row(spacing=18)
        self.cover = Cover()
        self.info = MediaInfo(backend)
        top_box.addWidget(self.cover)
        top_box.addWidget(self.info, 1)
        body.addWidget(top)
        body.addSpacing(t.px(18))
        self.progress = Progress(backend)
        body.addWidget(self.progress)
        body.addSpacing(t.px(14))
        transport, transport_box = row()
        transport_box.addStretch(1)
        transport_box.addWidget(Button('Previous track', 'skip-back', lambda: backend.media('previous'), (40, 40), 22, background=t.SURFACE, radius=t.dp(16)))
        self.play = Button('Pause', 'pause', lambda: backend.media('play_pause'), (64, 40), 22, t.BLACK, t.GREEN, t.dp(20))
        transport_box.addWidget(self.play)
        transport_box.addWidget(Button('Next track', 'skip-forward', lambda: backend.media('next'), (40, 40), 22, background=t.SURFACE, radius=t.dp(16)))
        transport_box.addStretch(1)
        body.addWidget(transport)
        body.addSpacing(t.px(14))
        output, output_box = row(spacing=6)
        output_box.addStretch(1)
        headphone = Button('Audio output', 'headphones', size=(13, 14), glyph_size=13)
        headphone.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        headphone.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
        output_box.addWidget(headphone)
        self.device = Label('', 11, t.MUTED)
        output_box.addWidget(self.device)
        output_box.addStretch(1)
        body.addWidget(output)
        box.addWidget(self.content)
        backend.changed.connect(self.sync)
        self.sync('all')

    def sync(self, part):
        if part not in ('media', 'audio', 'all'):
            return
        track = self.backend.state.track
        was_visible = not self.content.isHidden()
        self.empty.setVisible(track is None)
        self.content.setVisible(track is not None)
        if track:
            self.cover.image = track.art
            self.cover.update()
            self.info.setToolTip('\n'.join(filter(None, [track.title, track.artist, track.album])))
            self.info.update()
            self.progress.setVisible(track.duration > 0)
            self.progress.update()
            self.play.glyph = 'pause' if track.playing else 'play'
            self.play.setAccessibleName('Pause' if track.playing else 'Play')
            self.play.setToolTip(self.play.accessibleName())
            self.play.update()
            self.device.setText(self.backend.state.audio_device or 'System audio')
        if was_visible != (track is not None):
            self.size_changed.emit()


class CalendarDay(Button):
    def __init__(self, date, current_month, index, owner):
        super().__init__(date.isoformat(), size=(32, 32))
        self.date, self.index, self.owner = date, index, owner
        self.current_month = current_month
        self.setAccessibleName(QLocale().toString(QDate(date.year, date.month, date.day), QLocale.FormatType.LongFormat))
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus if date == owner.focused_date else Qt.FocusPolicy.ClickFocus)

    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.underMouse() and self.date != dt.date.today():
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(QColor(t.SURFACE))
            p.drawEllipse(QRectF(self.rect()))
        self.draw_contents(p)
        if t.keyboard_focus(self):
            p.setBrush(Qt.BrushStyle.NoBrush)
            p.setPen(QPen(QColor(t.GREEN), t.dp(2)))
            inset = t.dp(1)
            p.drawEllipse(QRectF(self.rect()).adjusted(inset, inset, -inset, -inset))

    def draw_contents(self, p):
        today = self.date == dt.date.today()
        if today:
            p.setPen(Qt.PenStyle.NoPen)
            p.setBrush(QColor(t.GREEN))
            p.drawEllipse(QRectF(self.rect()))
        color = t.BLACK if today else t.TEXT if self.date.month == self.current_month else t.DISABLED
        t.text(p, QRectF(self.rect()), str(self.date.day), 12, color, align=Qt.AlignmentFlag.AlignCenter)

    def keyPressEvent(self, event):
        move = {Qt.Key.Key_Left: -1, Qt.Key.Key_Right: 1, Qt.Key.Key_Up: -7, Qt.Key.Key_Down: 7}.get(event.key())
        if move is not None:
            self.owner.focus_date(self.date + dt.timedelta(days=move))
        elif event.key() in (Qt.Key.Key_Home, Qt.Key.Key_End):
            self.owner.focus_date(self.date + dt.timedelta(days=-self.date.weekday() + (6 if event.key() == Qt.Key.Key_End else 0)))
        elif event.key() in (Qt.Key.Key_PageUp, Qt.Key.Key_PageDown):
            amount = -1 if event.key() == Qt.Key.Key_PageUp else 1
            number = self.date.year * 12 + self.date.month - 1 + amount
            year, month = number // 12, number % 12 + 1
            self.owner.focus_date(dt.date(year, month, min(self.date.day, calendar.monthrange(year, month)[1])))
        else:
            return super().keyPressEvent(event)
        event.accept()


class Calendar(QWidget):
    size_changed = pyqtSignal()

    def __init__(self, backend):
        super().__init__()
        today = dt.date.today()
        self.month = today.replace(day=1)
        self.focused_date = today
        self.box = QVBoxLayout(self)
        self.box.setContentsMargins(0, 0, 0, 0)
        self.box.setSpacing(t.px(16))
        header, layout = row()
        layout.addWidget(Button('Previous', 'chevron-left', lambda: self.change_month(-1)))
        self.heading = Button('Back to this month', callback=self.reset, size=None, text_size=18, text_weight=600, text_family=t.DISPLAY_FAMILY)
        self.heading.setFixedHeight(t.px(32))
        layout.addWidget(self.heading, 1)
        layout.addWidget(Button('Next', 'chevron-right', lambda: self.change_month(1)))
        self.box.addWidget(header)
        self.grid = QWidget()
        self.grid_box = QGridLayout(self.grid)
        self.grid_box.setContentsMargins(0, 0, 0, 0)
        self.grid_box.setHorizontalSpacing(t.px(4))
        self.grid_box.setVerticalSpacing(t.px(4))
        self.box.addWidget(self.grid)
        self.days = []
        self.rebuild()

    def reset(self):
        self.month = dt.date.today().replace(day=1)
        self.focused_date = dt.date.today()
        self.rebuild()

    def focus_date(self, date):
        self.focused_date = date
        if self.month != date.replace(day=1):
            self.month = date.replace(day=1)
            self.rebuild()
        for button in self.days:
            button.setFocusPolicy(Qt.FocusPolicy.StrongFocus if button.date == date else Qt.FocusPolicy.ClickFocus)
            if button.date == date:
                button.setFocus(Qt.FocusReason.TabFocusReason)

    def change_month(self, amount):
        number = self.month.year * 12 + self.month.month - 1 + amount
        self.month = dt.date(number // 12, number % 12 + 1, 1)
        self.focused_date = self.month
        self.rebuild()

    def rebuild(self):
        locale = QLocale()
        if locale.language() == QLocale.Language.Korean:
            label = f'{self.month.year}년 {self.month.month}월'
        else:
            label = f'{locale.monthName(self.month.month)} {self.month.year}'
        self.heading.setText(label)
        while self.grid_box.count():
            item = self.grid_box.takeAt(0)
            item.widget().deleteLater()
        for i in range(7):
            weekday = Label(locale.dayName(i + 1, QLocale.FormatType.NarrowFormat), 10, t.MUTED, 500)
            weekday.setAlignment(Qt.AlignmentFlag.AlignCenter)
            weekday.setFixedHeight(t.px(30))
            self.grid_box.addWidget(weekday, 0, i)
        start = self.month - dt.timedelta(days=self.month.weekday())
        self.days = []
        for i in range(42):
            button = CalendarDay(start + dt.timedelta(days=i), self.month.month, i, self)
            self.days.append(button)
            self.grid_box.addWidget(button, 1 + i // 7, i % 7, Qt.AlignmentFlag.AlignCenter)
        self.size_changed.emit()


class Tray(QWidget):
    size_changed = pyqtSignal()

    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self.box = QVBoxLayout(self)
        self.box.setContentsMargins(0, 0, 0, 0)
        self.box.setSpacing(t.px(16))
        self.grid = QWidget()
        self.grid_layout = QGridLayout(self.grid)
        self.grid_layout.setContentsMargins(0, 0, 0, 0)
        self.grid_layout.setSpacing(t.px(8))
        self.box.addWidget(self.grid)
        self.empty = Label('No tray icons available', color=t.MUTED)
        self.empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.empty.setFixedHeight(t.px(120))
        self.box.addWidget(self.empty)
        self.footer = Label('Right-click an icon for its menu.', 11, t.MUTED)
        self.box.addWidget(self.footer)
        self._keys = None
        backend.changed.connect(self.sync)
        self.sync('tray')

    def sync(self, part):
        if part not in ('tray', 'all'):
            return
        from .tray import TrayButton
        icons = self.backend.state.tray
        keys = [(str(item.guid), item.hWnd, item.uID, item.szTip, item.hIcon) for item in icons]
        if keys == self._keys:
            return
        self._keys = keys
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            item.widget().deleteLater()
        for index, data in enumerate(icons):
            self.grid_layout.addWidget(TrayButton(data, self.backend), index // 4, index % 4)
        self.empty.setVisible(not icons)
        self.grid.setVisible(bool(icons))
        self.footer.setVisible(bool(icons))
        self.size_changed.emit()


class PanelBody(QWidget):
    size_changed = pyqtSignal()

    def __init__(self, kind, backend, parent=None):
        super().__init__(parent)
        self.kind, self.backend = kind, backend
        box = QVBoxLayout(self)
        box.setContentsMargins(*map(t.px, (18, 3, 18, 18)))
        box.setSpacing(t.px(18))
        heading, layout = row(spacing=6)
        self.title = Label({'quick': 'Quick controls', 'media': 'Now playing', 'calendar': 'Calendar', 'tray': 'System tray'}[kind], 17, weight=600, family=t.DISPLAY_FAMILY)
        self.title.setFixedHeight(t.px(24))
        layout.addWidget(self.title, 1)
        box.addWidget(heading)
        self.content = {'quick': Quick, 'media': Media, 'calendar': Calendar, 'tray': Tray}[kind](backend)
        self.content.size_changed.connect(self.size_changed)
        box.addWidget(self.content)
        self.error = Label('', 11, t.ERROR)
        self.error.setWordWrap(True)
        box.addWidget(self.error)
        backend.changed.connect(self.sync)
        self.sync('all')

    def sync(self, part):
        old = not self.error.isHidden()
        self.error.setText(self.backend.state.problem)
        self.error.setVisible(bool(self.backend.state.problem))
        if old != bool(self.backend.state.problem):
            self.size_changed.emit()

    def primary_control(self):
        if self.kind == 'quick' and self.content.volume.isEnabled():
            return self.content.volume
        if self.kind == 'media' and self.backend.state.track:
            return self.content.play
        return self.findChild(Button)
