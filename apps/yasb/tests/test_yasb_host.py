from pathlib import Path
import subprocess
import sys

import yaml
from PyQt6.QtTest import QTest
from core.bar import Bar
from core.utils.widget_builder import WidgetBuilder
from core.validation.config import YasbConfig


def test_configured_windows_renderer_keeps_antialiased_text_at_native_dpi():
    result = subprocess.run([sys.executable, str(Path(__file__).with_name('dpi_probe.py'))], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stdout + result.stderr


def test_application_can_quit_while_a_panel_is_expanding():
    result = subprocess.run([sys.executable, str(Path(__file__).with_name('shutdown_probe.py'))], capture_output=True, text=True, timeout=10)
    assert result.returncode == 0, 'An open panel prevented application shutdown.\n' + result.stdout + result.stderr


def test_managed_config_builds_full_width_native_widget(app, monkeypatch):
    import core.bar as host
    monkeypatch.setattr(host.app_bar, 'Win32AppBar', lambda: None)
    repository = Path(__file__).resolve().parents[3]
    folder = repository / 'home/dot_config/yasb'
    config = YasbConfig.model_validate(yaml.safe_load((folder / 'config.yaml').read_text()))
    config.widgets['canopy']['options']['preview'] = True
    options = config.bars['canopy']
    options.window_flags.windows_app_bar = False
    widgets, listeners = WidgetBuilder(config.widgets).build_widgets(options.widgets.model_dump())
    assert len(widgets['center']) == 1
    assert not listeners
    bar = Bar('test', 'canopy', app.primaryScreen(), (folder / 'styles.css').read_text(), widgets, options)
    QTest.qWait(80)
    canvas = widgets['center'][0].canvas
    assert canvas.width() == bar.width()
    assert canvas.height() == bar.height() == 40
    assert canvas.left.x() == 0
    assert canvas.right.geometry().right() == bar.width() - 1
    assert not canvas.center.geometry().intersects(canvas.right.geometry())
    widgets['center'][0].backend.deleteLater()
    bar.close()
    app.processEvents()
