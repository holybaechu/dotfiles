import os
import sys
from pathlib import Path

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'.upstream/src'))
import core.widgets
core.widgets.__path__.append(str(ROOT))

import pytest
from PyQt6.QtWidgets import QApplication
from core.widgets.canopy import theme


@pytest.fixture(scope='session')
def app():
    instance = QApplication.instance() or QApplication([])
    theme.install_theme(instance)
    yield instance
