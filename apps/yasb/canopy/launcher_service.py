"""Shared, asynchronous Windows application and Everything search for Canopy."""
from __future__ import annotations

import copy
import logging
import os
import tempfile
from queue import Queue
from threading import Event
from types import SimpleNamespace

from PyQt6.QtCore import QObject, QThread, Qt, pyqtSignal
from PyQt6.QtWidgets import QApplication

from core.widgets.services.quick_launch.base_provider import ProviderResult


class WindowsLauncherProvider:
    """Reuse the pinned YASB index/ranking without configuring its global service."""

    def discover(self):
        from core.utils.win32.app_loader import AppListLoader
        from core.widgets.services.quick_launch.providers.apps import AppsProvider
        from core.widgets.services.quick_launch.providers.file_search import _EverythingBackend
        from core.widgets.services.quick_launch.providers.settings import SettingsProvider

        self.apps = []
        loader = AppListLoader()
        loader.apps_loaded.connect(self._set_apps, Qt.ConnectionType.DirectConnection)
        # Run in our existing worker; do not start a second, unowned QThread.
        loader.clear_cache()
        loader.run()
        self._apps = AppsProvider({'show_recent': True, 'show_description': False})
        self._apps._service = SimpleNamespace(apps=self.apps, icon_paths={})
        self._settings = SettingsProvider()
        self._everything = _EverythingBackend()
        return self.apps

    def _set_apps(self, apps):
        self.apps = apps

    def search(self, text, limit, icons):
        from core.widgets.services.quick_launch.fuzzy import _split_camel, fuzzy_score
        from core.widgets.services.quick_launch.providers.file_search import _get_file_icon

        files_only = text.lstrip().lower().startswith('file ')
        text = text.strip()
        query = text[4:].strip() if files_only else text
        results = []
        if not files_only:
            self._apps._service.icon_paths = icons
            results = self._apps.get_results(text)
            aliases = {}
            existing = {r.id for r in results}
            for name, path, _ in self._apps._service.apps:
                if not path.startswith('CPL::'):
                    continue
                key = f'{name}::{path}'
                alias = _split_camel(path.rsplit('::', 1)[-1].rsplit('.', 1)[-1])
                aliases[key] = alias
                score = fuzzy_score(text, alias) if text else None
                if score is not None and key not in existing:
                    results.append(ProviderResult(title=name, provider='apps', id=key,
                                                  icon_path=icons.get(key, ''),
                                                  action_data={'name': name, 'path': path}))
            for result in results:
                path = result.action_data['path']
                alias = aliases.get(result.id, '')
                result.description = ('Control Panel' + (' · ' + alias if alias else '')
                                      if path.startswith('CPL::') else 'Application')
            if text:
                # Reserve room for precise Settings matches ahead of weak fuzzy app matches.
                settings = self._settings.get_results(text)
                for result in settings:
                    result.id = result.action_data['uri']
                strong, weak = [], []
                for result in results:
                    searchable = result.title + ' ' + aliases.get(result.id, '')
                    (strong if text.casefold() in searchable.casefold() else weak).append(result)
                results = strong + settings + weak
        if query and (files_only or len(query) >= 2):
            raw = self._everything.search(query, limit) if self._everything.available else []
            for entry in raw:
                path = entry['path']
                results.append(ProviderResult(
                    title=entry['name'], description=path,
                    icon_char=_get_file_icon(entry['name'], entry['is_folder']),
                    provider='file_search', id='file::' + path,
                    action_data={'path': path, 'is_folder': entry['is_folder']},
                ))
            if files_only and (not self._everything.available or self._everything.has_ipc_error):
                results = [ProviderResult(
                    title='Everything is unavailable',
                    description='Start Everything, then search again.', provider='file_search',
                )]
        elif files_only:
            results = [ProviderResult(
                title='Search files and folders', description='Type a filename after “file ”.',
                provider='file_search',
            )]
        # Always give matching files a few visible slots in combined searches.
        if not files_only:
            files = [r for r in results if r.provider == 'file_search']
            others = [r for r in results if r.provider != 'file_search']
            reserve = min(5, len(files), max(1, limit // 3)) if files else 0
            results = others[:limit - reserve] + files[:max(reserve, limit - len(others))]
        return results[:limit]

    def launch(self, result):
        from core.utils.win32.bindings.shell32 import shell_execute

        path = result.action_data.get('path', '')
        parameters = None
        if result.provider == 'settings':
            target = result.action_data['uri']
            if not target.startswith('ms-settings:'):
                raise ValueError('Invalid Settings destination.')
        elif path.startswith('UWP::'):
            target = 'shell:AppsFolder\\' + path[5:]
        elif path.startswith('CPL::'):
            target = os.path.join(os.environ['WINDIR'], 'System32', 'control.exe')
            canonical = path[5:].rsplit('::', 1)[-1]
            parameters = '/name ' + canonical
        elif path and os.path.exists(path):
            target = path
        else:
            raise FileNotFoundError('This item is no longer available. Search again or refresh the launcher.')
        # Pass the destination separately to ShellExecuteW, never through a command shell.
        code = shell_execute(target, parameters=parameters)
        if not code or code <= 32:
            raise OSError(f'Windows could not open {result.title} (error {code or 0}).')
        if result.provider == 'apps':
            self._apps._history.record(result.title, path)


class PreviewLauncherProvider:
    """Small deterministic catalog; preview launches never start real processes."""

    def __init__(self):
        self.launched = []

    def discover(self):
        self.items = [
            ProviderResult(title=name, description='Application', provider='apps', id=name,
                           action_data={'name': name, 'path': f'C:\\Preview\\{name}.lnk'})
            for name in ('Arc', 'Calculator', 'Codex', 'Everything', 'File Explorer',
                         'Microsoft Edge', 'Notepad', 'Spotify', 'Visual Studio Code', 'Windows Terminal')
        ]
        self.items += [ProviderResult(title='Sound', description='Control Panel', provider='apps',
                                      id='control-sound', action_data={'path': 'CPL::Microsoft.Sound'}),
                       ProviderResult(title='Display', description='System > Display', provider='settings',
                                      id='ms-settings:display', action_data={'uri': 'ms-settings:display'})]
        return []

    def search(self, text, limit, icons):
        from core.widgets.services.quick_launch.fuzzy import fuzzy_score

        if text.lower().startswith('file '):
            return [ProviderResult(title='Canopy notes.md', description='C:\\Preview\\Canopy notes.md',
                                   provider='file_search', id='preview-file',
                                   action_data={'path': 'C:\\Preview\\Canopy notes.md', 'is_folder': False})]
        matches = [(fuzzy_score(text.strip(), item.title), item) for item in self.items]
        matches = [(score, item) for score, item in matches if score is not None]
        matches.sort(key=lambda pair: (-pair[0], pair[1].title.casefold()))
        return [copy.deepcopy(item) for _, item in matches[:limit]]

    def launch(self, result):
        self.launched.append(result.id)


class _LauncherWorker(QThread):
    catalog_ready = pyqtSignal(list)
    results_ready = pyqtSignal(str, list)
    failed = pyqtSignal(str, str)
    launched = pyqtSignal(object)

    def __init__(self, provider):
        super().__init__()
        self.provider = provider
        self.commands = Queue()
        self.stopping = Event()
        self.latest = ''
        self.known = {}

    def run(self):
        import pythoncom

        pythoncom.CoInitialize()
        try:
            self._discover()
            while not self.stopping.is_set():
                command = self.commands.get()
                if command is None:
                    break
                kind, payload = command
                request = ''
                try:
                    if kind == 'refresh':
                        self._discover()
                    elif kind == 'search':
                        request, text, limit, icons = payload
                        if request != self.latest:
                            continue
                        results = self.provider.search(text, limit, icons)
                        if request == self.latest and not self.stopping.is_set():
                            self.known = {r.id: copy.deepcopy(r) for r in results if r.id}
                            self.results_ready.emit(request, results)
                    elif kind == 'launch':
                        result = self.known.get(payload)
                        if result is None:
                            raise ValueError('This result is out of date. Search again.')
                        self.provider.launch(result)
                        if not self.stopping.is_set():
                            self.launched.emit(result)
                except Exception as error:
                    logging.exception('Canopy launcher %s failed', kind)
                    if not self.stopping.is_set():
                        self.failed.emit(request, str(error))
        finally:
            pythoncom.CoUninitialize()

    def _discover(self):
        try:
            apps = self.provider.discover()
            if not self.stopping.is_set():
                self.catalog_ready.emit(apps)
        except Exception as error:
            logging.exception('Canopy application discovery failed')
            if not self.stopping.is_set():
                self.failed.emit('discovery', str(error))


class LauncherService(QObject):
    results_ready = pyqtSignal(str, list)
    state_changed = pyqtSignal(str)
    error = pyqtSignal(str)
    icon_ready = pyqtSignal(str, str)
    launched = pyqtSignal(object)
    _instance = None
    _retiring_workers = []

    @classmethod
    def instance(cls):
        if cls._instance is None or cls._instance._closed:
            cls._instance = cls()
        return cls._instance

    def __init__(self, parent=None, *, preview=False, provider=None):
        super().__init__(parent)
        self.loading = True
        self.error_message = ''
        self._closed = False
        self._counter = 0
        self._latest = ''
        self._icons = {}
        self._results = {}
        self._icon_worker = None
        self._preview = preview or provider is not None
        self._worker = _LauncherWorker(provider or (PreviewLauncherProvider() if preview else WindowsLauncherProvider()))
        self._worker.catalog_ready.connect(self._on_catalog)
        self._worker.results_ready.connect(self._on_results)
        self._worker.failed.connect(self._on_error)
        self._worker.launched.connect(self.launched)
        app = QApplication.instance()
        if app:
            app.aboutToQuit.connect(self.shutdown)
        self._worker.start()

    def search(self, text, limit=24):
        self._counter += 1
        self._latest = str(self._counter)
        self.error_message = ''
        if not self._closed:
            self._worker.latest = self._latest
            self._worker.commands.put(('search', (self._latest, text, max(1, min(limit, 100)), dict(self._icons))))
        return self._latest

    def launch(self, result):
        if self._closed or not result.id or result.id not in self._results:
            return False
        # Only the ID crosses to the worker, which holds its own trusted copy.
        self._worker.commands.put(('launch', result.id))
        return True

    def refresh(self):
        if not self._closed:
            self.loading = True
            self.error_message = ''
            self.state_changed.emit('loading')
            self._worker.commands.put(('refresh', None))

    def _on_catalog(self, apps):
        if self._closed:
            return
        self.loading = False
        self.error_message = ''
        self.state_changed.emit('ready')
        if self._preview or not apps:
            return
        from core.widgets.services.quick_launch.icon_resolver import IconResolverWorker, compute_extraction_size

        if self._icon_worker and self._icon_worker.isRunning():
            self._icon_worker.stop()
            self._retire(self._icon_worker)
        icons_dir = os.path.join(tempfile.gettempdir(), 'yasb_quick_launch_icons')
        os.makedirs(icons_dir, exist_ok=True)
        screen = QApplication.primaryScreen()
        size = compute_extraction_size(32, screen.devicePixelRatio() if screen else 1)
        self._icon_worker = IconResolverWorker(apps, icons_dir, size=size)
        self._icon_worker.icon_ready.connect(self._on_icon)
        self._icon_worker.start()

    def _on_icon(self, key, path):
        if not self._closed:
            self._icons[key] = path
            self.icon_ready.emit(key, path)

    def _on_results(self, request, results):
        if not self._closed and request == self._latest:
            self._results = {r.id: r for r in results if r.id}
            self.results_ready.emit(request, results)

    def _on_error(self, request, message):
        if self._closed or (request not in ('', 'discovery', self._latest)):
            return
        self.loading = False
        self.error_message = message
        self.state_changed.emit('error')
        self.error.emit(message)

    @classmethod
    def _retire(cls, worker):
        # Keep ownership until OS work returns, even if shutdown exceeds our wait.
        if not worker.isRunning():
            return
        cls._retiring_workers.append(worker)
        worker.finished.connect(lambda: cls._retiring_workers.remove(worker) if worker in cls._retiring_workers else None)

    def shutdown(self):
        if self._closed:
            return
        self._closed = True
        self._worker.stopping.set()
        self._worker.commands.put(None)
        if self._icon_worker:
            self._icon_worker.stop()
            if not self._icon_worker.wait(2000):
                self._retire(self._icon_worker)
        if not self._worker.wait(12000):
            self._retire(self._worker)
