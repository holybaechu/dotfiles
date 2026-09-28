import os
import sys
from pathlib import Path

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'.upstream/src'))
import core.widgets
core.widgets.__path__.append(str(ROOT))

import pytest
from PyQt6.QtWidgets import QApplication, QVBoxLayout, QWidget
from PyQt6.QtTest import QTest
from core.widgets.canopy import theme
from core.widgets.canopy.model import PreviewBackend
from core.widgets.canopy.widget import Canvas
from core.widgets.canopy.island import Panel


@pytest.fixture(scope='session')
def app():
    instance = QApplication.instance() or QApplication([])
    theme.install_theme(instance)
    yield instance


@pytest.fixture
def desktop(app, monkeypatch):
    import core.widgets.canopy.island as island
    monkeypatch.setattr(island, 'reduced_motion', lambda: True)
    root = QWidget()
    root.resize(1280, 720)
    layout = QVBoxLayout(root)
    layout.setContentsMargins(0, 0, 0, 0)
    layout.setSpacing(0)
    backend = PreviewBackend(2)
    canvas = Canvas(backend, root)
    layout.addWidget(canvas)
    layout.addStretch(1)
    root.show()
    QTest.qWait(40)
    yield root, canvas, backend
    if Panel.active:
        Panel.active.timer.stop()
        Panel.active.hide()
        Panel.active.deleteLater()
        Panel.active = None
    backend.deleteLater()
    root.deleteLater()
    app.processEvents()
