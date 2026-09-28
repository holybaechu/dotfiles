import os
import sys
from pathlib import Path

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
import launch
from PyQt6 import sip
from PyQt6.QtCore import QAbstractAnimation, QTimer
from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout
from core.widgets.canopy import theme
from core.widgets.canopy.widget import Canvas
from core.widgets.canopy.model import PreviewBackend
from core.widgets.canopy.controls import Button
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
transitions = []

def change_card_before_quit():
    assert Panel.active is not None, 'The shutdown probe did not open a panel.'
    transitions.extend(button._transition for button in Panel.active.findChildren(Button))
    backend.set_wifi_enabled(False)

QTimer.singleShot(100, lambda: canvas.right.toggle('quick'))
QTimer.singleShot(320, change_card_before_quit)
QTimer.singleShot(350, app.quit)
QTimer.singleShot(1500, lambda: app.exit(1))
result = app.exec()
assert transitions, 'The shutdown probe did not exercise the mode cards.'
assert all(sip.isdeleted(animation) or animation.state() == QAbstractAnimation.State.Stopped
           for animation in transitions), 'A hidden control animation outlived the event loop.'
assert Panel.active is None, 'The native panel effect outlived QApplication shutdown.'
raise SystemExit(result)
