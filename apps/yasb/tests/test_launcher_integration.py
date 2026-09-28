from threading import Thread

from core.widgets.canopy.widget import CanopyWidget, Config


def test_whkd_command_routes_to_launcher_on_qt_thread(app, monkeypatch):
    from core.widgets.canopy.launcher import Launcher
    from core.widgets.canopy import launcher_commands

    opened = []
    monkeypatch.setattr(Launcher, 'toggle', lambda owner, preview_parent=None: opened.append((owner, preview_parent)))
    widget = CanopyWidget(Config(preview=True))
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
