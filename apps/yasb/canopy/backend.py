from __future__ import annotations

import asyncio
import ctypes
import logging
import os
import time

from PyQt6.QtCore import QObject, QTimer, pyqtSignal
from PyQt6.QtGui import QImage
from PyQt6.QtWidgets import QApplication

from .model import State, Track


class Backend(QObject):
    changed = pyqtSignal(str)
    tray_menu_started = pyqtSignal()
    _wm_connect = pyqtSignal(dict)
    _wm_update = pyqtSignal(dict, dict)
    _wm_disconnect = pyqtSignal()
    _instance = None

    @classmethod
    def instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self, tray=True):
        super().__init__()
        from core.events.komorebi import KomorebiEvent
        from core.events.service import EventService
        from core.widgets.services.komorebi.client import KomorebiClient
        from core.widgets.services.komorebi.event_listener import KomorebiEventListener
        from core.widgets.services.volume.service import AudioOutputService
        from core.widgets.services.brightness.service import BrightnessService
        from core.widgets.services.media.media import WindowsMedia
        from core.widgets.services.battery.battery_api import BatteryAPI

        self.state = State()
        from .system_modes import SystemModes
        self._modes = SystemModes(self)
        self._modes.changed.connect(self._modes_changed)
        self._modes.pending_changed.connect(self._mode_pending)
        self._modes.failed.connect(self._mode_failed)
        self._events = EventService()
        self._komorebi = KomorebiClient()
        self._listener = KomorebiEventListener('canopy')
        self._events.register_event(KomorebiEvent.KomorebiConnect, self._wm_connect)
        self._events.register_event(KomorebiEvent.KomorebiUpdate, self._wm_update)
        self._events.register_event(KomorebiEvent.KomorebiDisconnect, self._wm_disconnect)
        self._wm_connect.connect(self._set_wm)
        self._wm_update.connect(lambda _event, state: self._set_wm(state))
        self._wm_disconnect.connect(lambda: self._set_wm({}))
        self._listener.start()
        QTimer.singleShot(3000, lambda: self._set_wm({}) if not self.state.wm else None)
        self._audio = AudioOutputService()
        self._audio.register_widget(self)
        self._brightness = BrightnessService.instance(ddc_poll_interval=0)
        self._brightness.brightness_changed.connect(lambda *_: self.refresh_brightness(False))
        self._media = WindowsMedia()
        self._media.media_properties_changed.connect(self._properties_changed)
        self._media.current_session_changed.connect(self._properties_changed)
        self._battery = BatteryAPI.instance()
        self._media_key = None
        self._media_anchor = None
        self._clock = (0.0, time.monotonic(), False, 1.0)
        self._album = ''
        self._album_revision = 0
        self._art = None
        self._last_image = None
        self._icons = {}
        self._tray_client = self._tray_thread = None
        self._tray_refresh_timer = QTimer(self)
        self._tray_refresh_timer.setSingleShot(True)
        self._tray_refresh_timer.setInterval(200)
        self._tray_refresh_timer.timeout.connect(self._tray_refresh)
        if tray:
            QTimer.singleShot(0, self.start_tray)
        self._media_timer = QTimer(self)
        self._media_timer.timeout.connect(self._sync_media)
        self._media_timer.start(250)
        self._status_timer = QTimer(self)
        self._status_timer.timeout.connect(self.refresh_status)
        self._status_timer.start(10000)
        self._audio_timer = QTimer(self)
        self._audio_timer.timeout.connect(self._update_label)
        self._audio_timer.start(2000)
        QTimer.singleShot(0, self.refresh_status)
        QTimer.singleShot(0, self._update_label)
        QApplication.instance().aboutToQuit.connect(self.shutdown)

    def _set_wm(self, state):
        self.state.wm = state
        self.state.connection_error = '' if state else 'Waiting for Komorebi. Check that it is running in your desktop session.'
        self.changed.emit('wm')

    def workspaces(self, monitor):
        from .monitor_workspaces import workspace_view
        return workspace_view(self.state.wm, monitor)

    def focus_workspace(self, monitor, index):
        from .monitor_workspaces import elements, resolve_monitor
        if isinstance(monitor, dict):
            monitor, _ = resolve_monitor(self.state.wm, monitor)
        if not isinstance(monitor, int) or not isinstance(index, int) or index < 0:
            return
        if not 0 <= monitor < len(elements(self.state.wm.get('monitors', {}))):
            return
        self._komorebi.activate_workspace(monitor, index)

    def _fail(self, message, error):
        logging.error('%s %s', message, error, exc_info=True)
        self.state.error = message
        self.changed.emit('error')

    def _update_label(self):
        try:
            endpoint = self._audio.get_volume_interface()
            speaker = self._audio.get_speakers()
            self.state.audio_available = endpoint is not None
            if endpoint:
                self.state.volume = round(endpoint.GetMasterVolumeLevelScalar() * 100)
                self.state.muted = bool(endpoint.GetMute())
            self.state.audio_device = speaker.FriendlyName if speaker else ''
            self.changed.emit('audio')
        except Exception as error:
            self._fail('Audio control is unavailable.', error)

    def _reinitialize_audio(self):
        self._update_label()

    def set_volume(self, value):
        self.state.error = ''
        try:
            endpoint = self._audio.get_volume_interface()
            if endpoint:
                endpoint.SetMasterVolumeLevelScalar(max(0, min(100, value)) / 100, None)
                self._update_label()
        except Exception as error:
            self._fail('Could not change volume.', error)

    def set_mute(self, value):
        self.state.error = ''
        try:
            endpoint = self._audio.get_volume_interface()
            if endpoint:
                endpoint.SetMute(bool(value), None)
                self._update_label()
        except Exception as error:
            self._fail('Could not change playback mute.', error)

    def refresh_brightness(self, request=True):
        from .native import monitor_identity
        if request:
            self._brightness.refresh_now()
        displays = []
        self._display_handles = {}
        with self._brightness._lock:
            monitors = [(handle, info.device, info.name, info.is_internal, info.brightness, info.supports_ddc or info.supports_scheme) for handle, info in self._brightness._monitors.items()]
        for i, (handle, device, name, internal, brightness, supported) in enumerate(monitors):
            identifier = monitor_identity(device)
            if identifier:
                self._display_handles[identifier] = handle
            displays.append({'id': identifier or f'unavailable:{handle}', 'name': 'Built-in display' if internal else name or f'Display {i + 1}', 'brightness': brightness if identifier and supported else None})
        self.state.displays = displays
        self.changed.emit('brightness')

    def set_brightness(self, identifier, value):
        self.state.error = ''
        self.refresh_brightness(False)
        if identifier not in self._display_handles:
            self.state.error = 'The selected display was disconnected. Reopen Quick controls.'
            self.changed.emit('error')
            return
        self._brightness.set_brightness(self._display_handles[identifier], value)

    def refresh_status(self):
        self._modes.refresh()
        try:
            from winrt.windows.networking.connectivity import NetworkInformation
            profile = NetworkInformation.get_internet_connection_profile()
            self.state.connected = profile is not None
            self.state.network = profile.profile_name if profile else 'No connection'
            status = self._battery.get_status()
            self.state.battery = status.percent if status else None
            self.state.charging = status.is_charging if status else False
            self.state.power_plugged = status.power_plugged if status else False
        except Exception as error:
            logging.warning('Could not refresh desktop status: %s', error)
        self.changed.emit('status')
        from core.utils.win32.bindings import IsWindow
        stale = [data for data in self._icons.values() if not IsWindow(data.hWnd)]
        for data in stale:
            self._tray_deleted(data)

    def _properties_changed(self):
        session = self._media.current_session
        if session is None:
            self._album = ''
            self._sync_media()
            return
        key = (session.app_id, session.title, session.artist)
        if key != self._media_key:
            self._album = ''
        self._album_revision += 1
        asyncio.get_running_loop().create_task(self._read_album(session, key, self._album_revision))
        self._sync_media()

    async def _read_album(self, session, key, revision):
        try:
            with self._media._smtc_lock:
                if session.session is None:
                    return
                operation = session.session.try_get_media_properties_async()
            properties = await operation
            album = properties.album_title or ''
            del properties
            current = self._media.current_session
            if current and revision == self._album_revision and (current.app_id, current.title, current.artist) == key:
                self._album = album
                self._sync_media()
        except Exception as error:
            logging.debug('Album metadata unavailable: %s', error)

    def _sync_media(self):
        session = self._media.current_session
        if session is None:
            if self.state.track:
                self.state.track = None
                self._media_key = None
                self.changed.emit('media')
            return
        now = time.monotonic()
        key = (session.app_id, session.title, session.artist)
        anchor = (session.last_snapshot_pos, session.last_update_time)
        position, started, playing, rate = self._clock
        projected = position + (now - started) * rate if playing else position
        if key != self._media_key or anchor != self._media_anchor:
            projected = session.last_snapshot_pos
            if session.is_playing and session.last_update_time > 0:
                projected += max(0, time.time() - session.last_update_time) * session.playback_rate
            self._clock = (projected, now, session.is_playing, session.playback_rate)
        elif (playing, rate) != (session.is_playing, session.playback_rate):
            self._clock = (projected, now, session.is_playing, session.playback_rate)
        self._media_key, self._media_anchor = key, anchor
        if session.thumbnail is not self._last_image:
            self._last_image = session.thumbnail
            self._art = None
            if session.thumbnail:
                image = session.thumbnail.convert('RGBA')
                self._art = QImage(image.tobytes(), image.width, image.height, QImage.Format.Format_RGBA8888).copy()
        self.state.track = Track(session.title or 'Unknown track', session.artist, self._album, session.is_playing, max(0, min(session.duration, projected)) if session.duration > 0 else max(0, projected), max(0, session.duration), self._art)
        self.changed.emit('media')

    def media(self, action):
        self.state.error = ''
        {'play_pause': self._media.play_pause, 'previous': self._media.prev, 'next': self._media.next}[action]()

    def open_settings(self, page):
        self.state.error = ''
        try:
            os.startfile(f'ms-settings:{page}')
            self.changed.emit('error')
        except OSError as error:
            self._fail('Could not open Windows settings.', error)

    def power_action(self, action):
        from .power import perform_power_action
        self.state.error = ''
        try:
            perform_power_action(action)
            self.changed.emit('error')
        except Exception as error:
            self._fail(f'Could not {action}. Windows may not support or allow this action.', error)

    def _modes_changed(self, values):
        for name, value in values.items():
            setattr(self.state, name, value)
        self.changed.emit('status')

    def _mode_pending(self, mode, pending):
        if pending:
            self.state.pending_modes.add(mode)
            self.state.mode_errors.pop(mode, None)
        else:
            self.state.pending_modes.discard(mode)
            if mode not in self.state.mode_errors and self.state.error.startswith('Could not change '):
                self.state.error = ''
        self.changed.emit('status')

    def _mode_failed(self, message):
        logging.warning('%s', message)
        self.state.error = message
        self.changed.emit('error')

    def set_airplane_mode(self, enabled):
        self.state.error = ''
        self._modes.set_mode('airplane_mode', enabled)

    def set_battery_saver(self, enabled):
        self.state.error = ''
        self._modes.set_mode('battery_saver', enabled)

    def refresh_modes(self):
        self._modes.refresh()

    def set_wifi_enabled(self, enabled):
        self.state.error = ''
        self._modes.set_mode('wifi_enabled', enabled)

    def set_bluetooth_enabled(self, enabled):
        self.state.error = ''
        self._modes.set_mode('bluetooth_enabled', enabled)

    def start_tray(self):
        from core.widgets.yasb.systray import SystrayWidget
        self._tray_client, self._tray_thread = SystrayWidget.get_monitor_instance(False)
        self._tray_client.icon_modified.connect(self._tray_modified)
        self._tray_client.icon_deleted.connect(self._tray_deleted)
        self._tray_client.update_icons.connect(self._tray_refresh_timer.start)
        if not self._tray_thread.isRunning():
            self._tray_thread.start()

    def _tray_refresh(self):
        from core.utils.win32.bindings.user32 import RegisterWindowMessage, SendNotifyMessage
        from core.bar_helper import AppBarManager
        manager = AppBarManager()
        manager.suppress()
        SendNotifyMessage(0xFFFF, RegisterWindowMessage('TaskbarCreated'), 0, 0)
        QTimer.singleShot(0, manager.unsuppress)

    @staticmethod
    def _tray_key(data):
        return str(data.guid) if data.guid else (data.hWnd, data.uID)

    def _tray_modified(self, data):
        from core.widgets.services.systray.utils import IconData
        from core.widgets.yasb.systray import SystrayWidget
        key = self._tray_key(data)
        existing = self._icons.setdefault(key, IconData())
        SystrayWidget.update_icon_data(self, existing, data)
        self.state.tray = [icon for icon in self._icons.values() if icon.dwState != 1]
        self.changed.emit('tray')

    def _tray_deleted(self, data):
        self._icons.pop(self._tray_key(data), None)
        self.state.tray = [icon for icon in self._icons.values() if icon.dwState != 1]
        self.changed.emit('tray')

    def shutdown(self):
        self._modes.shutdown()
        self._listener.stop()
        self._listener.wait(1200)
        self._audio.unregister_widget(self)
        if self._tray_client:
            self._tray_client.destroy()
        if self._tray_thread:
            self._tray_thread.quit()
            self._tray_thread.wait(1200)
