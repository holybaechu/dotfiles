import os
import sys
from pathlib import Path
from tempfile import TemporaryDirectory

root = Path(__file__).resolve().parents[1]
repository = root.parents[1]
configuration = TemporaryDirectory()
(Path(configuration.name) / '.env').write_text((repository / 'home/dot_config/yasb/dot_env').read_text())
os.environ['YASB_CONFIG_HOME'] = configuration.name
os.environ['YASB_FONT_ENGINE'] = 'native'
sys.path.insert(0, str(root))
from launch import load_environment
load_environment()

from PyQt6.QtWidgets import QApplication, QWidget
from PyQt6.QtCore import QRectF, Qt
from PyQt6.QtGui import QPainter, QColor
from core.widgets.canopy.island import FadeBlur
from core.widgets.canopy import theme

app = QApplication([])
theme.install_theme(app)


class Text(QWidget):
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.fillRect(self.rect(), QColor('black'))
        theme.text(painter, QRectF(self.rect()), 'Canopy · Native text 0123456789', 12)


container = QWidget()
container.resize(400, 80)
direct, layer = Text(container), Text(container)
direct.setGeometry(0, 0, 400, 40)
layer.setGeometry(0, 40, 400, 40)
layer.setGraphicsEffect(FadeBlur(layer))
container.setAttribute(Qt.WidgetAttribute.WA_DontShowOnScreen)
container.show()
app.processEvents()
image = container.grab().toImage()
half = image.height() // 2
shades = {image.pixelColor(x, y).red() for y in range(half) for x in range(image.width())}
assert len(shades) > 64, f'Text edges are quantized to {len(shades)} shades'
assert all(image.pixel(x, y) == image.pixel(x, y + half) for y in range(half) for x in range(image.width())), 'The effect layer reduced text resolution'
print(f'Font smoothing: {len(shades)} shades; effect retains DPR {image.devicePixelRatio()}')
