import threading
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
from PyQt6.QtCore import QObject
from core.widgets.canopy.backend import Backend
from core.widgets.canopy.model import State


@pytest.fixture
def backend(app):
    value = Backend.__new__(Backend)
    QObject.__init__(value)
    value.state = State()
    value._media_key = value._media_anchor = value._last_image = value._art = None
    value._clock = (0, 0, False, 1)
    value._album = ''
    yield value
    value.deleteLater()


def test_sparse_timeline_predicts_pause_resume_seek_and_track_change(backend, monkeypatch):
    now = [100.0]
    monkeypatch.setattr('core.widgets.canopy.backend.time.monotonic', lambda: now[0])
    monkeypatch.setattr('core.widgets.canopy.backend.time.time', lambda: now[0] + 1000)
    session = SimpleNamespace(app_id='player', title='First', artist='Artist', is_playing=True, last_snapshot_pos=10, last_update_time=1100, playback_rate=1, duration=200, thumbnail=None)
    backend._media = SimpleNamespace(current_session=session)
    backend._sync_media()
    assert backend.state.track.position == 10
    now[0] += 4
    backend._sync_media()
    assert backend.state.track.position == 14
    session.is_playing = False
    backend._sync_media()
    now[0] += 10
    backend._sync_media()
    assert backend.state.track.position == 14
    session.is_playing = True
    backend._sync_media()
    now[0] += 2
    backend._sync_media()
    assert backend.state.track.position == 16
    session.last_snapshot_pos, session.last_update_time = 90, 1116
    backend._sync_media()
    assert backend.state.track.position == 90
    session.title, session.last_snapshot_pos = 'Next', 0
    backend._sync_media()
    assert backend.state.track.position == 0
    now[0] += 500
    backend._sync_media()
    assert backend.state.track.position == 200
    backend._media.current_session = None
    backend._sync_media()
    assert backend.state.track is None


def test_brightness_revalidates_device_identity_when_handle_is_reused(backend, monkeypatch):
    monitor = SimpleNamespace(device='DISPLAY1', name='External', is_internal=False, brightness=65, supports_ddc=True, supports_scheme=False)
    backend._brightness = SimpleNamespace(_lock=threading.Lock(), _monitors={7: monitor}, set_brightness=Mock())
    identity = ['display-A']
    monkeypatch.setattr('core.widgets.canopy.native.monitor_identity', lambda _: identity[0])
    backend.refresh_brightness(False)
    backend.set_brightness('display-A', 50)
    backend._brightness.set_brightness.assert_called_once_with(7, 50)
    backend._brightness.set_brightness.reset_mock()
    identity[0] = 'display-B'
    backend.set_brightness('display-A', 10)
    backend._brightness.set_brightness.assert_not_called()
    assert 'disconnected' in backend.state.error
    assert backend.state.displays[0]['id'] == 'display-B'


def test_ambiguous_mirrored_display_is_read_only(backend, monkeypatch):
    monitor = SimpleNamespace(device='DISPLAY1', name='Mirrored', is_internal=False, brightness=65, supports_ddc=True, supports_scheme=False)
    backend._brightness = SimpleNamespace(_lock=threading.Lock(), _monitors={7: monitor}, set_brightness=Mock())
    monkeypatch.setattr('core.widgets.canopy.native.monitor_identity', lambda _: None)
    backend.refresh_brightness(False)
    assert backend.state.displays[0]['brightness'] is None
    backend.set_brightness('unavailable:7', 10)
    backend._brightness.set_brightness.assert_not_called()
