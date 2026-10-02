from __future__ import annotations

import json
import math
import os
from functools import lru_cache
from pathlib import Path

from PyQt6.QtCore import QEvent, QObject, QPointF, QRectF, Qt
from PyQt6.QtGui import QColor, QFont, QFontDatabase, QPainter, QPainterPath
from PyQt6.QtSvg import QSvgRenderer
from PyQt6.QtWidgets import QApplication

ASSETS = Path(__file__).parent / 'assets'
DESIGN_SCALE = 1.0


def dp(value):
    """Convert a Canopy design pixel to a Qt logical pixel, before monitor DPI."""
    return value * DESIGN_SCALE


def px(value):
    """Integer widget/layout extent; retain nonzero one-pixel affordances."""
    result = round(dp(value))
    return (1 if value > 0 else -1) if value and not result else result


def rect(x, y, width, height):
    return QRectF(dp(x), dp(y), dp(width), dp(height))


BLACK = '#000000'
SURFACE = '#11160f'
RAISED = '#293522'
PRESSED = '#3c502b'
GREEN = '#7cab3d'
GREEN_PRESSED = '#719c37'
GREEN_HOVER = '#92bd56'
TEXT = '#f0f3e7'
MUTED = '#aab69e'
DISABLED = '#849575'
ERROR = '#eea99a'
BAR_HEIGHT = px(40)
BAR_BUTTON_HEIGHT = px(32)
WORKSPACE_HEIGHT = px(26)
ISLAND_RADIUS = dp(16)
SECTION_PADDING = (BAR_HEIGHT - BAR_BUTTON_HEIGHT) // 2
BAR_HIGHLIGHT_RADIUS = max(0, ISLAND_RADIUS - SECTION_PADDING)
WORKSPACE_INSET = (BAR_HEIGHT - WORKSPACE_HEIGHT) // 2
WORKSPACE_HIGHLIGHT_RADIUS = max(0, ISLAND_RADIUS - WORKSPACE_INSET)
BAR_BUTTON_PADDING = SECTION_PADDING
EDGE_INSET = SECTION_PADDING
PANEL_INSET = px(18)
PANEL_RADIUS = dp(44)
PANEL_WIDTHS = {name: px(width) for name, width in {'media': 420, 'quick': 352, 'calendar': 320, 'tray': 336}.items()}
FONT_FAMILY = 'Inter'
DISPLAY_FAMILY = 'Bahnschrift'
UTILITY_FAMILY = 'Consolas'


def frame_interval(screen):
    return max(4, round(1000 / max(60, screen.refreshRate())))


def install_theme(app: QApplication):
    global FONT_FAMILY
    font_id = QFontDatabase.addApplicationFont(str(ASSETS / 'Inter.ttf'))
    families = QFontDatabase.applicationFontFamilies(font_id)
    if families:
        FONT_FAMILY = families[0]
    for filename in ('malgun.ttf', 'malgunbd.ttf'):
        fallback = Path(os.environ.get('WINDIR', 'C:/Windows')) / 'Fonts' / filename
        if fallback.exists(): QFontDatabase.addApplicationFont(str(fallback))
    app.setFont(font())
    app.setStyleSheet(f'QToolTip {{ background:{SURFACE}; color:{TEXT}; border:1px solid {RAISED}; padding:{px(6)}px; }}')
    tracker = KeyboardFocus(app)
    app.installEventFilter(tracker)
    app.canopy_focus_tracker = tracker


def font(size=12, weight=400, family=None):
    family = family or FONT_FAMILY
    value = QFont(family)
    value.setFamilies([family, FONT_FAMILY, 'Segoe UI', 'Malgun Gothic'])
    # Point sizes preserve fractional font sizes; Qt then applies native per-monitor DPI.
    value.setPointSizeF(dp(size) * 72 / 96)
    value.setWeight(QFont.Weight(weight))
    value.setStyleStrategy(QFont.StyleStrategy.PreferAntialias | QFont.StyleStrategy.NoSubpixelAntialias)
    value.setHintingPreference(QFont.HintingPreference.PreferVerticalHinting)
    value.setFeature(QFont.Tag('tnum'), 1)
    return value


def display_font(size=16, weight=500):
    return font(size, weight, DISPLAY_FAMILY)


def utility_font(size=11, weight=400):
    return font(size, weight, UTILITY_FAMILY)


class KeyboardFocus(QObject):
    def eventFilter(self, obj, event):
        if event.type() == QEvent.Type.KeyPress and event.key() in (Qt.Key.Key_Tab, Qt.Key.Key_Backtab, Qt.Key.Key_Left, Qt.Key.Key_Right, Qt.Key.Key_Up, Qt.Key.Key_Down):
            QApplication.instance().setProperty('canopyKeyboard', True)
        elif event.type() == QEvent.Type.MouseButtonPress:
            QApplication.instance().setProperty('canopyKeyboard', False)
        return False


def keyboard_focus(widget):
    return widget.hasFocus() and bool(QApplication.instance().property('canopyKeyboard'))


def _corner(path, cx, cy, radius, start, end):
    if radius <= 0:
        return
    for i in range(1, 21):
        angle = start + (end - start) * i / 20
        c, s = math.cos(angle), math.sin(angle)
        path.lineTo(cx + radius * math.copysign(abs(c) ** .5, c), cy + radius * math.copysign(abs(s) ** .5, s))


def squircle(rect, radius=dp(8), corners=None):
    rect = QRectF(rect)
    x, y, w, h = rect.x(), rect.y(), rect.width(), rect.height()
    tl, tr, br, bl = [max(0, min(r, w / 2, h / 2)) for r in (corners or (radius,) * 4)]
    path = QPainterPath(QPointF(x + tl, y))
    path.lineTo(x + w - tr, y)
    _corner(path, x + w - tr, y + tr, tr, -math.pi / 2, 0)
    path.lineTo(x + w, y + h - br)
    _corner(path, x + w - br, y + h - br, br, 0, math.pi / 2)
    path.lineTo(x + bl, y + h)
    _corner(path, x + bl, y + h - bl, bl, math.pi / 2, math.pi)
    path.lineTo(x, y + tl)
    _corner(path, x + tl, y + tl, tl, math.pi, math.pi * 1.5)
    path.closeSubpath()
    return path


def notch(painter, rect, edge):
    painter.fillPath(squircle(rect, corners=(0, 0, 0 if edge == 'right' else ISLAND_RADIUS, 0 if edge == 'left' else ISLAND_RADIUS)), QColor(BLACK))
    for side in ('left', 'right'):
        if side == edge:
            continue
        painter.save()
        if side == 'right':
            painter.translate(rect.right() + ISLAND_RADIUS, rect.top())
            painter.scale(-1, 1)
        else:
            painter.translate(rect.left() - ISLAND_RADIUS, rect.top())
        path = QPainterPath(QPointF(0, 0))
        path.lineTo(ISLAND_RADIUS, 0)
        path.lineTo(ISLAND_RADIUS, ISLAND_RADIUS)
        _corner(path, 0, ISLAND_RADIUS, ISLAND_RADIUS, 0, -math.pi / 2)
        path.closeSubpath()
        painter.fillPath(path, QColor(BLACK))
        painter.restore()


@lru_cache(maxsize=160)
def icon_renderer(name, color):
    data = json.loads((ASSETS / 'icons.json').read_text(encoding='utf-8')).get(name)
    if not data:
        raise ValueError(f'Unknown icon: {name}')
    body = data['body'].replace('currentColor', color)
    return QSvgRenderer(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {data.get("width",24)} {data.get("height",24)}">{body}</svg>'.encode())


def icon(painter: QPainter, name, rect, color=TEXT):
    icon_renderer(name, color).render(painter, QRectF(rect))


def text(painter, rect, value, size=12, color=TEXT, weight=400, align=Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter, elide=True, family=None):
    painter.setFont(font(size, weight, family))
    painter.setPen(QColor(color))
    value = str(value)
    if elide:
        value = painter.fontMetrics().elidedText(value, Qt.TextElideMode.ElideRight, max(0, int(rect.width())))
    painter.drawText(QRectF(rect), align, value)


def duration(seconds):
    seconds = max(0, int(seconds))
    return f'{seconds // 60}:{seconds % 60:02d}'
