import os
import sys
from pathlib import Path

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
import launch
from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout
from core.widgets.canopy import theme
from core.widgets.canopy.widget import Canvas
from core.widgets.canopy.model import PreviewBackend
from core.widgets.canopy.island import Panel

app = QApplication([])
theme.install_theme(app)
desktop = QWidget()
desktop.resize(1280, 900)
layout = QVBoxLayout(desktop)
backend = PreviewBackend()
canvas = Canvas(backend)
layout.addWidget(canvas)
desktop.show()
exercised = []

def change_card_before_quit():
    assert Panel.active is not None, 'The shutdown probe did not open a panel.'
    backend.set_wifi_enabled(False)
    exercised.append(True)

QTimer.singleShot(100, lambda: canvas.right.toggle('quick'))
QTimer.singleShot(320, change_card_before_quit)
QTimer.singleShot(350, app.quit)
result = app.exec()
assert exercised, 'The shutdown probe did not exercise the mode cards.'
assert Panel.active is None, 'The native panel effect outlived QApplication shutdown.'
raise SystemExit(result)
