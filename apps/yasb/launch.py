from __future__ import annotations

import argparse
import asyncio
import logging
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / '.upstream' / 'src'))
import core.widgets
core.widgets.__path__.append(str(ROOT))


def preview(snapshot=None, panel='quick', displays=2):
    if snapshot:
        os.environ['QT_QPA_PLATFORM'] = 'offscreen'
    from PyQt6.QtCore import QTimer
    from PyQt6.QtGui import QColor, QPainter
    from PyQt6.QtWidgets import QApplication, QVBoxLayout, QWidget
    from core.widgets.canopy import theme
    from core.widgets.canopy.model import PreviewBackend
    from core.widgets.canopy.widget import Canvas
    from core.widgets.canopy.island import Panel

    class Desktop(QWidget):
        def paintEvent(self, event):
            painter = QPainter(self)
            painter.fillRect(self.rect(), QColor('#262626'))

    app = QApplication([])
    theme.install_theme(app)
    desktop = Desktop()
    desktop.setWindowTitle('Canopy native preview')
    desktop.resize(1280, 720)
    layout = QVBoxLayout(desktop)
    layout.setContentsMargins(0, 0, 0, 0)
    layout.setSpacing(0)
    backend = PreviewBackend(displays)
    canvas = Canvas(backend, desktop)
    layout.addWidget(canvas)
    layout.addStretch(1)
    desktop.show()
    if panel == 'launcher':
        QTimer.singleShot(100, canvas.launch)
    elif panel != 'bar':
        QTimer.singleShot(100, lambda: (canvas.center if panel == 'media' else canvas.right).toggle(panel))
    if snapshot:
        def save():
            destination = Path(snapshot).resolve()
            destination.parent.mkdir(parents=True, exist_ok=True)
            desktop.grab().save(str(destination))
            if Panel.active:
                Panel.active.hide()
            app.quit()
        QTimer.singleShot(1400, save)
    return app.exec()


def load_environment():
    from dotenv import load_dotenv
    from env import get_env_path, set_font_engine
    load_dotenv(get_env_path(), override=True)
    set_font_engine()
    logging.info('Canopy font renderer: %s', os.environ.get('YASB_FONT_ENGINE', 'gdi'))


def start():
    import main
    from core.widgets.canopy.host import install_host_fixes
    from core.widgets.canopy.launcher_commands import LauncherCommands, start_cli_server
    from core.widgets.canopy.launcher_service import LauncherService
    from core.widgets.canopy.theme import install_theme
    install_host_fixes()
    original = main.YASBApplication

    class Application(original):
        def __init__(self, args):
            super().__init__(args)
            install_theme(self)
            self.canopy_commands = LauncherCommands(self)
            LauncherService.instance()

    main.YASBApplication = Application
    main.start_cli_server = start_cli_server
    main.init_logger()
    def report_error(kind, value, traceback):
        logging.critical('Canopy stopped after an unhandled error.', exc_info=(kind, value, traceback))
        raise SystemExit(1)
    sys.excepthook = report_error
    load_environment()
    with main.single_instance_lock():
        main.start_cli_server()
        main.main()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--reload', action='store_true')
    parser.add_argument('--toggle-launcher', action='store_true', help='Toggle the launcher in the running Canopy bar')
    parser.add_argument('--snapshot')
    parser.add_argument('--panel', choices=['bar', 'media', 'quick', 'calendar', 'tray', 'launcher'], default='quick')
    parser.add_argument('--displays', type=int, default=2)
    options, extra = parser.parse_known_args()
    if options.reload or options.toggle_launcher:
        from cli import CLIHandler
        CLIHandler().send_command_to_application('toggle-launcher' if options.toggle_launcher else 'reload')
        raise SystemExit(0)
    if options.preview or options.snapshot:
        raise SystemExit(preview(options.snapshot, options.panel, options.displays))
    start()
