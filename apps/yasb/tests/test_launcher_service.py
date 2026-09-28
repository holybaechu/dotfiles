from importlib import import_module
from threading import Event
from types import SimpleNamespace

import pytest
from PyQt6.QtTest import QTest

from core.widgets.canopy.launcher_service import (
    LauncherService, PreviewLauncherProvider, WindowsLauncherProvider,
)
from core.widgets.services.quick_launch.base_provider import ProviderResult


def wait_until(predicate, timeout=2000):
    for _ in range(timeout // 10):
        if predicate():
            return
        QTest.qWait(10)
    assert predicate(), 'The asynchronous operation did not complete.'


@pytest.fixture
def service(app):
    instance = LauncherService(preview=True)
    yield instance
    instance.shutdown()


def test_preview_search_is_async_and_fuzzy(service):
    received = []
    service.results_ready.connect(lambda request, items: received.append((request, items)))
    request = service.search('vsc')
    assert not received
    wait_until(lambda: received)
    assert received[-1][0] == request
    assert received[-1][1][0].title == 'Visual Studio Code'
    assert not service.loading


def test_empty_query_and_no_matches(service):
    received = []
    service.results_ready.connect(lambda _, items: received.append(items))
    service.search('', limit=4)
    wait_until(lambda: received)
    assert len(received[-1]) == 4
    service.search('no-such-application-123456')
    wait_until(lambda: len(received) == 2)
    assert received[-1] == []


def test_stale_inflight_results_are_discarded(app):
    started, release = Event(), Event()

    class DelayedProvider(PreviewLauncherProvider):
        def search(self, text, limit, icons):
            if text == 'slow':
                started.set()
                assert release.wait(2)
            return super().search(text, limit, icons)

    instance = LauncherService(provider=DelayedProvider())
    received = []
    instance.results_ready.connect(lambda request, items: received.append((request, items)))
    try:
        instance.search('slow')
        wait_until(started.is_set)
        newest = instance.search('codex')
        release.set()
        wait_until(lambda: received)
        assert [request for request, _ in received] == [newest]
        assert received[0][1][0].title == 'Codex'
    finally:
        release.set()
        instance.shutdown()


def test_launch_uses_trusted_result_copy(service):
    received, launched = [], []
    service.results_ready.connect(lambda _, items: received.extend(items))
    service.launched.connect(launched.append)
    service.search('codex')
    wait_until(lambda: received)
    received[0].action_data['path'] = 'forged-command.exe'
    assert service.launch(received[0])
    wait_until(lambda: launched)
    assert launched[0].action_data['path'] == 'C:\\Preview\\Codex.lnk'
    assert not service.launch(ProviderResult(title='Unknown', id='unknown'))
    assert not service.launch(ProviderResult(title='Information'))


def test_failure_is_visible_and_shutdown_is_idempotent(app):
    class BrokenProvider(PreviewLauncherProvider):
        def search(self, *args):
            raise RuntimeError('Search failed for testing')

    instance = LauncherService(provider=BrokenProvider())
    errors = []
    instance.error.connect(errors.append)
    try:
        instance.search('anything')
        wait_until(lambda: errors)
        assert instance.error_message == 'Search failed for testing'
        assert not instance.loading
    finally:
        instance.shutdown()
        instance.shutdown()
    assert not instance._worker.isRunning()


def test_launch_failure_keeps_service_available(app):
    class BrokenLaunch(PreviewLauncherProvider):
        def launch(self, result):
            raise OSError('Windows could not open this item')

    instance = LauncherService(provider=BrokenLaunch())
    received, errors, launched = [], [], []
    instance.results_ready.connect(lambda _, items: received.extend(items))
    instance.error.connect(errors.append)
    instance.launched.connect(launched.append)
    try:
        instance.search('codex')
        wait_until(lambda: received)
        assert instance.launch(received[0])
        wait_until(lambda: errors)
        assert not launched
        assert instance._worker.isRunning()
    finally:
        instance.shutdown()


def native_fixture(apps=(), files=(), available=True, ipc_error=False):
    provider = WindowsLauncherProvider()
    provider._apps = SimpleNamespace(_service=SimpleNamespace(icon_paths={}, apps=[]), get_results=lambda _: list(apps))
    provider._settings = SimpleNamespace(get_results=lambda _: [])
    provider._everything = SimpleNamespace(available=available, has_ipc_error=ipc_error,
                                           search=lambda query, limit: list(files)[:limit])
    return provider


def test_combined_results_reserve_everything_slots():
    apps = [ProviderResult(title=f'Project App {i}', provider='apps', id=str(i),
                           action_data={'path': f'app{i}.lnk'}) for i in range(20)]
    files = [{'path': f'C:\\project{i}.txt', 'name': f'project{i}.txt', 'is_folder': False}
             for i in range(20)]
    results = native_fixture(apps, files).search('project', 12, {})
    assert len(results) == 12
    assert results[0].provider == 'apps'
    assert len([r for r in results if r.provider == 'file_search']) == 4


@pytest.mark.parametrize('available,ipc_error', [(False, False), (True, True)])
def test_explicit_file_search_reports_unavailable_without_actions(available, ipc_error):
    provider = native_fixture(available=available, ipc_error=ipc_error)
    result = provider.search('file report', 24, {})[0]
    assert result.title == 'Everything is unavailable'
    assert not result.id
    assert not result.action_data
    assert provider.search('report', 24, {}) == []


def test_control_panel_and_settings_are_searchable_without_prefix():
    control = ProviderResult(title='Sound', id='sound', provider='apps',
                             action_data={'path': 'CPL::{abc}::Microsoft.Sound'})
    settings = ProviderResult(title='Sound', provider='settings', action_data={'uri': 'ms-settings:sound'})
    provider = native_fixture([control])
    provider._settings = SimpleNamespace(get_results=lambda _: [settings])
    results = provider.search('sound', 24, {})
    assert results[0].description == 'Control Panel'
    assert results[1].id == 'ms-settings:sound'


def test_english_canonical_names_find_localized_control_panel_items():
    provider = native_fixture()
    provider._apps._service.apps = [('장치 관리자', 'CPL::{abc}::Microsoft.DeviceManager', None)]
    result = provider.search('device manager', 24, {})[0]
    assert result.title == '장치 관리자'
    assert result.description == 'Control Panel · Device Manager'
    assert result.action_data['path'] == 'CPL::{abc}::Microsoft.DeviceManager'


@pytest.mark.parametrize('path,expected,parameters', [
    ('UWP::Microsoft.Test_123!App', 'shell:AppsFolder\\Microsoft.Test_123!App', None),
    ('CPL::{abc}::Microsoft.Sound', 'C:\\Windows\\System32\\control.exe', '/name Microsoft.Sound'),
])
def test_windows_shell_destinations_are_separate_from_parameters(monkeypatch, path, expected, parameters):
    shell32 = import_module('core.utils.win32.bindings.shell32')

    calls = []
    monkeypatch.setenv('WINDIR', 'C:\\Windows')
    monkeypatch.setattr(shell32, 'shell_execute', lambda target, **kwargs: calls.append((target, kwargs)) or 33)
    provider = native_fixture()
    provider._apps._history = SimpleNamespace(record=lambda *_: None)
    provider.launch(ProviderResult(title='Test', provider='apps', action_data={'path': path}))
    assert calls == [(expected, {'parameters': parameters})]


def test_windows_shell_failure_is_not_reported_as_success(monkeypatch):
    shell32 = import_module('core.utils.win32.bindings.shell32')

    monkeypatch.setattr(shell32, 'shell_execute', lambda *args, **kwargs: 2)
    with pytest.raises(OSError, match='error 2'):
        native_fixture().launch(ProviderResult(title='Display', provider='settings',
                                               action_data={'uri': 'ms-settings:display'}))
