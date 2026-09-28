"""Run in a separate Qt process for each simulated per-monitor DPR."""
import os
from pathlib import Path
import sys

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
os.environ['QT_SCREEN_SCALE_FACTORS'] = sys.argv[1]
os.environ.pop('QT_SCALE_FACTOR', None)
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import launch
from PyQt6.QtCore import Qt
from PyQt6.QtTest import QTest
from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout
from core.widgets.canopy import theme
from core.widgets.canopy.widget import Canvas
from core.widgets.canopy.model import PreviewBackend

app = QApplication([])
theme.install_theme(app)
root = QWidget()
root.resize(640, 360)
layout = QVBoxLayout(root)
layout.setContentsMargins(0, 0, 0, 0)
backend = PreviewBackend()
canvas = Canvas(backend, root)
layout.addWidget(canvas)
layout.addStretch()
root.show()
app.processEvents()
dpr = float(sys.argv[1])
assert canvas.devicePixelRatioF() == dpr
assert canvas.height() == 40
image = canvas.grab().toImage()
assert image.height() == round(40 * dpr)
assert canvas.launcher.height() == 32
assert canvas.launcher.mapTo(canvas, canvas.launcher.rect().topLeft()).y() == 4
QTest.mouseClick(canvas.workspaces.buttons[7], Qt.MouseButton.LeftButton)
assert backend.workspace == 7
print(f'DPR={dpr}: logical bar=40, physical bar={image.height()}, workspace click=8')
root.close()
backend._timer.stop()
