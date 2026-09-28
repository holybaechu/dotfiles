from pathlib import Path
from threading import Thread
from types import SimpleNamespace

import pytest
import yaml
from PyQt6.QtTest import QTest

from core.widgets.canopy.island import Panel
from core.widgets.canopy.widget import CanopyWidget, Config


def test_whkd_command_routes_to_launcher_on_qt_thread(app, monkeypatch):
    from core.widgets.canopy.launcher import Launcher
    from core.widgets.canopy import launcher_commands

    def fail_flow():
        raise AssertionError('Flow Launcher must not open')

    config_path = Path(__file__).resolve().parents[3] / 'home/dot_config/yasb/config.yaml'
    options = yaml.safe_load(config_path.read_text())['widgets']['canopy']['options']
    config = Config.model_validate({'preview': True, **options})
    assert not config.keybindings
    whkd = (config_path.parents[1] / 'whkdrc.tmpl').read_text()
    assert 'alt + space' in whkd and 'ToggleLauncher.ps1' in whkd

    opened = []
    monkeypatch.setattr(Launcher, 'toggle', lambda owner, preview_parent=None: opened.append((owner, preview_parent)))
    widget = CanopyWidget(config)
    monkeypatch.setattr(widget.backend, 'open_launcher', fail_flow, raising=False)
    widget.show()
    commands = launcher_commands.LauncherCommands()
    focused = []
    def active_screen(mouse, window, screens):
        focused.append((mouse, window, screens))
        return widget.screen().name()
    monkeypatch.setattr(launcher_commands, 'find_focused_screen', active_screen)
    worker = Thread(target=lambda: launcher_commands.process_command('toggle-launcher'))
    worker.start()
    worker.join()
    # Queued delivery must never access a widget on the CLI pipe thread.
    assert not opened
    app.processEvents()
    assert opened == [(widget.canvas, None)]
    assert focused == [(False, True, [widget.screen().name()])]
    commands.shutdown()
    commands.deleteLater()
    widget.close()
    widget.backend.deleteLater()
    widget.deleteLater()
    app.processEvents()


def test_other_cli_commands_still_reach_yasb(monkeypatch):
    from core.utils import controller
    from core.widgets.canopy.launcher_commands import process_command
    received = []
    monkeypatch.setattr(controller, 'process_cli_command', received.append)
    process_command('reload')
    process_command('toggle-bar --screen primary')
    assert received == ['reload', 'toggle-bar --screen primary']


@pytest.mark.parametrize(('command', 'accepted'), [(b'toggle-launcher', True), (b'show-bar', True), (b'toggle-launcher extra', False), (b'unknown', False), (b'\xff', False)])
def test_cli_transport_acknowledges_only_supported_commands(monkeypatch, command, accepted):
    from core.widgets.canopy import launcher_commands as commands
    replies, dispatched = [], []
    monkeypatch.setattr(commands, 'ReadFile', lambda *_: (True, command))
    monkeypatch.setattr(commands, 'WriteFile', lambda _, reply: replies.append(reply) or True)
    handler = SimpleNamespace(cli_command=dispatched.append)
    commands.CanopyPipeHandler._handle_client_connection(handler, 123)
    assert replies == [b'ACK' if accepted else b'CLI Unknown Command']
    assert dispatched == ([command.decode()] if accepted else [])


def test_bar_button_opens_launcher_after_closing_panel(desktop, monkeypatch):
    from core.widgets.canopy.launcher import Launcher

    def fail_flow():
        raise AssertionError('Flow Launcher must not open')

    _, canvas, _ = desktop
    monkeypatch.setattr(canvas.backend, 'open_launcher', fail_flow, raising=False)
    opened = []
    monkeypatch.setattr(Launcher, 'toggle', lambda owner, preview_parent=None: opened.append((owner, preview_parent)))
    canvas.right.toggle('quick')
    assert Panel.active and Panel.active.isVisible()
    canvas.launcher.click()
    QTest.qWait(250)
    assert opened == [(canvas, canvas.preview_parent)]
    assert Panel.active is None
