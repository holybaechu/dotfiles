from threading import Event

import pytest
from PyQt6.QtTest import QTest

from core.widgets.canopy.launcher_service import LauncherService, PreviewLauncherProvider
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
