"""Open the existing launcher from whkd through YASB's local CLI pipe."""
from __future__ import annotations

import logging
import sys
import threading

from PyQt6.QtCore import QObject, Qt, pyqtSignal, pyqtSlot
from PyQt6.QtWidgets import QApplication

from core.events.service import EventService
from core.utils.cli_server import CliPipeHandler, ReadFile, WriteFile
from core.utils.win32.utils import find_focused_screen

EVENT = 'canopy_toggle_launcher'


class LauncherCommands(QObject):
    requested = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        # Pipe commands arrive on a worker thread; widget access stays on Qt's thread.
        self.requested.connect(self.toggle, Qt.ConnectionType.QueuedConnection)
        self.events = EventService()
        self.events.register_event(EVENT, self.requested)
        QApplication.instance().aboutToQuit.connect(self.shutdown)

    @pyqtSlot()
    def toggle(self):
        from .widget import CanopyWidget

        widgets = [widget for widget in QApplication.allWidgets()
                   if isinstance(widget, CanopyWidget) and widget.isVisible()]
        if not widgets:
            return
        screen = find_focused_screen(False, True, screens=[widget.screen().name() for widget in widgets])
        widget = next((widget for widget in widgets if widget.screen().name() == screen), widgets[0])
        logging.info('Toggling Canopy launcher from whkd on %s', widget.screen().name())
        widget.canvas.launch()

    def shutdown(self):
        self.events.unregister_event(EVENT, self.requested)


def process_command(command):
    if command.strip() == 'toggle-launcher':
        EventService().emit_event(EVENT)
    else:
        from core.utils.controller import process_cli_command
        process_cli_command(command)


class CanopyPipeHandler(CliPipeHandler):
    def _handle_client_connection(self, pipe):
        # YASB's transport has a fixed command allowlist. Extend it here, keeping
        # the pinned upstream checkout untouched and its reload handshake intact.
        success, data = ReadFile(pipe, 64 * 1024)
        if not success or not data:
            return
        try:
            command = data.decode('utf-8').strip()
        except UnicodeDecodeError:
            WriteFile(pipe, b'CLI Unknown Command')
            return
        verb = command.split()[0].lower() if command else ''
        allowed = verb in ('stop', 'reload', 'show-bar', 'hide-bar', 'toggle-bar') or command == 'toggle-launcher'
        if not allowed:
            WriteFile(pipe, b'CLI Unknown Command')
            return
        if not WriteFile(pipe, b'ACK'):
            return
        if verb == 'reload':
            threading.Thread(target=self._restart_pipe_server, daemon=True).start()
        self.cli_command(command)


def start_cli_server():
    handler = CanopyPipeHandler(process_command)
    handler.start_cli_pipe_server()
    sys._cli_pipe_handler = handler
