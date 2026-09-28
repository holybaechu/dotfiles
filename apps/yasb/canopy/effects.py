from __future__ import annotations

import math

from PIL import Image, ImageFilter
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QImage, QPainter
from PyQt6.QtWidgets import QGraphicsEffect

from . import theme as t


def image_to_pil(image):
    image = image.convertToFormat(QImage.Format.Format_RGBA8888)
    return Image.frombytes('RGBA', (image.width(), image.height()), image.bits().asstring(image.sizeInBytes()))


def pil_to_image(image, ratio=1):
    value = QImage(image.tobytes(), image.width, image.height, image.width * 4, QImage.Format.Format_RGBA8888).copy()
    value.setDevicePixelRatio(ratio)
    return value


class FadeBlur(QGraphicsEffect):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.opacity, self.blur, self.offset_y = 1.0, 0.0, 0.0
        self._snapshot = self._input = None
        self._levels = {}

    def invalidate(self, *_):
        self._snapshot = self._input = None
        self._levels.clear()

    def sourceChanged(self, flags):
        self.invalidate()
        super().sourceChanged(flags)

    def set_amount(self, opacity, blur, offset_y=0):
        if opacity <= .001 or opacity >= .999 or self.opacity <= .001 or self.opacity >= .999:
            self.invalidate()
        self.opacity, self.blur, self.offset_y = opacity, blur, offset_y
        self.update()

    def boundingRectFor(self, rect):
        return rect.adjusted(-t.dp(5), -t.dp(5), t.dp(5), t.dp(5))

    def _capture(self):
        self._snapshot, self._offset = self.sourcePixmap(Qt.CoordinateSystem.LogicalCoordinates, QGraphicsEffect.PixmapPadMode.PadToEffectiveBoundingRect)
        if self._snapshot.isNull():
            self._snapshot = None
            return False
        ratio = self._snapshot.devicePixelRatio()
        image = self._snapshot.toImage().scaled(math.ceil(self._snapshot.width() / ratio), math.ceil(self._snapshot.height() / ratio), Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
        self._input = image_to_pil(image)
        return True

    def _level(self, radius):
        if radius not in self._levels:
            image = pil_to_image(self._input.filter(ImageFilter.GaussianBlur(radius)))
            image = image.scaled(self._snapshot.size(), Qt.AspectRatioMode.IgnoreAspectRatio, Qt.TransformationMode.SmoothTransformation)
            image.setDevicePixelRatio(self._snapshot.devicePixelRatio())
            self._levels[radius] = image
        return self._levels[radius]

    def draw(self, painter):
        if self.opacity <= .001:
            return
        painter.save()
        painter.translate(0, self.offset_y)
        if self.blur < .01:
            self.invalidate()
            painter.setOpacity(self.opacity)
            self.drawSource(painter)
        elif self._snapshot is not None or self._capture():
            one, two, four = t.dp(1), t.dp(2), t.dp(4)
            low, high = (0, one) if self.blur < one else (one, two) if self.blur < two else (two, four)
            weight = min(1, (self.blur ** 2 - low ** 2) / (high ** 2 - low ** 2))
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
            painter.setOpacity(self.opacity * weight)
            painter.drawImage(self._offset, self._level(high))
            if weight < 1:
                # Add weighted premultiplied layers on the black shell without darkening the crossfade.
                painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_Plus)
                painter.setOpacity(self.opacity * (1 - weight))
                if low:
                    painter.drawImage(self._offset, self._level(low))
                else:
                    painter.drawPixmap(self._offset, self._snapshot)
        painter.restore()
