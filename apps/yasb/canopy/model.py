from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from PyQt6.QtCore import QObject, QRectF, QTimer, Qt, pyqtSignal
from PyQt6.QtGui import QColor, QImage, QPainter


@dataclass
class Track:
    title: str = ''
    artist: str = ''
    album: str = ''
    playing: bool = False
    position: float = 0
    duration: float = 0
    art: QImage | None = None


@dataclass
class State:
    track: Track | None = None
    volume: int = 0
    muted: bool = False
    audio_available: bool = False
    audio_device: str = ''
    connected: bool = False
    network: str = ''
    battery: int | None = None
    charging: bool = False
    power_plugged: bool = False
    battery_saver: bool | None = None
    airplane_mode: bool | None = None
    wifi_enabled: bool | None = None
    bluetooth_enabled: bool | None = None
    pending_modes: set[str] = field(default_factory=set)
    mode_errors: dict[str, str] = field(default_factory=dict)
    displays: list[dict] = field(default_factory=list)
    tray: list[Any] = field(default_factory=list)
    error: str = ''
    connection_error: str = ''
    wm: dict = field(default_factory=dict)

    @property
    def problem(self):
        return '\n'.join(value for value in (self.error, self.connection_error) if value)


class PreviewBackend(QObject):
    changed = pyqtSignal(str)
    tray_menu_started = pyqtSignal()

    def __init__(self, displays=2):
        super().__init__()
        self.state = State(track=Track('Preview track 1', 'Sample artist', 'Sample album', True, 42, 240), volume=50, audio_available=True, audio_device='Speakers', connected=True, network='Wi-Fi', battery=84, battery_saver=False, airplane_mode=False, wifi_enabled=True, bluetooth_enabled=True)
        art = QImage(100, 100, QImage.Format.Format_RGB32)
        from . import theme
        art.fill(QColor(theme.SURFACE))
        painter = QPainter(art)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(theme.GREEN))
        painter.drawEllipse(15, 15, 70, 70)
        painter.setBrush(QColor(theme.SURFACE))
        painter.drawEllipse(37, 37, 26, 26)
        painter.end()
        self.state.track.art = art
        self.state.displays = [{'id': index, 'name': 'Built-in display' if index == 0 else f'External display {index}', 'brightness': 65 + index * 10} for index in range(displays)]
        from core.widgets.services.systray.utils import IconData
        for index, (label, glyph) in enumerate((('Volume', 'volume-2'), ('Network', 'wifi'), ('Music', 'music-2'))):
            image = QImage(44, 44, QImage.Format.Format_ARGB32_Premultiplied)
            image.fill(Qt.GlobalColor.transparent)
            painter = QPainter(image)
            theme.icon(painter, glyph, QRectF(0, 0, 44, 44))
            painter.end()
            self.state.tray.append(IconData(uID=index, szTip=label, icon_image=image))
        self.workspace = 0
        self._timer = QTimer(self)
        self._timer.timeout.connect(self._tick)
        self._timer.start(250)

    def _tick(self):
        if self.state.track and self.state.track.playing:
            self.state.track.position = min(self.state.track.duration, self.state.track.position + .25)
            self.changed.emit('media')

    def workspaces(self, monitor):
        return [{'name': str(i + 1), 'active': i == self.workspace, 'occupied': i < 3} for i in range(8)], 'BSP', 'Desktop preview', 0

    def focus_workspace(self, monitor, index):
        self.workspace = index
        self.changed.emit('wm')

    def set_volume(self, value):
        self.state.volume = value
        self.changed.emit('audio')

    def set_mute(self, value):
        self.state.muted = value
        self.changed.emit('audio')

    def set_brightness(self, identifier, value):
        for display in self.state.displays:
            if display['id'] == identifier:
                display['brightness'] = value
        self.changed.emit('brightness')

    def refresh_brightness(self):
        self.changed.emit('brightness')

    def media(self, action):
        if action == 'play_pause':
            self.state.track.playing = not self.state.track.playing
        else:
            self.state.track.title = 'Preview track 2' if action == 'next' else 'Preview track 1'
            self.state.track.position = 0
        self.changed.emit('media')

    def open_settings(self, page):
        pass

    def set_airplane_mode(self, enabled):
        self.state.airplane_mode = enabled
        self.changed.emit('status')

    def set_battery_saver(self, enabled):
        self.state.battery_saver = enabled
        self.changed.emit('status')

    def refresh_modes(self):
        self.changed.emit('status')

    def set_wifi_enabled(self, enabled):
        self.state.wifi_enabled = enabled
        self.changed.emit('status')

    def set_bluetooth_enabled(self, enabled):
        self.state.bluetooth_enabled = enabled
        self.changed.emit('status')
