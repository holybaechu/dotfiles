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
    yield value
    value.deleteLater()


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
