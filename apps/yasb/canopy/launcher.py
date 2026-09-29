from __future__ import annotations

from functools import lru_cache

from PIL import Image, ImageFilter
from PyQt6.QtCore import QEvent, QEasingCurve, QPointF, QRect, QRectF, QSize, Qt, QTimer, QVariantAnimation
from PyQt6.QtGui import QColor, QImage, QPainter, QPen, QPixmap
from PyQt6.QtWidgets import QApplication, QHBoxLayout, QLineEdit, QListWidget, QListWidgetItem, QStyle, QStyledItemDelegate, QVBoxLayout, QWidget

from . import theme as t
from .controls import Label
from .effects import image_to_pil, pil_to_image
from .native import disable_native_rounding, reduced_motion


def launcher_geometry(screen: QRect, width=t.px(520), height=t.px(460)):
    """Keep the entire popup inside the work area, including negative origins."""
    width, height = min(width, screen.width() - t.px(24)), min(height, screen.height() - t.px(24))
    width, height = max(1, width), max(1, height)
    x = screen.x() + (screen.width() - width) // 2
    y = screen.y() + round(screen.height() * .44 - height / 2)
    y = max(screen.top(), min(y, screen.bottom() - height + 1))
    return QRect(x, y, width, height)


@lru_cache(maxsize=8)
def popup_shadow(width, height):
    image = QImage(width, height, QImage.Format.Format_RGBA8888)
    image.fill(Qt.GlobalColor.transparent)
    painter = QPainter(image)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.fillPath(t.squircle(QRectF(t.dp(20), t.dp(20), width - t.dp(40), height - t.dp(40)), t.dp(32)), QColor('black'))
    painter.end()
    alpha = image_to_pil(image).getchannel('A')
    layer = Image.new('RGBA', alpha.size)
    layer.putalpha(alpha.filter(ImageFilter.GaussianBlur(t.dp(9))).point(lambda a: round(a * .65)))
    return pil_to_image(layer)


def frosted_backdrop(image, width, height):
    """Blur at half logical resolution so opening stays quick at high DPI."""
    if image.isNull():
        return QImage()
    sample = image_to_pil(image).resize((max(1, width // 2), max(1, height // 2)), Image.Resampling.BILINEAR)
    return pil_to_image(sample.filter(ImageFilter.GaussianBlur(t.dp(12))))


def result_category(result):
    path = result.action_data.get('path', '')
    if path.startswith('CPL::'):
        return 'Control Panel'
    if result.provider == 'settings':
        return 'Settings'
    if result.provider == 'file_search':
        return 'Folder' if result.action_data.get('is_folder') else 'File'
    return 'Application'


class SearchInput(QLineEdit):
    composing = False

    def inputMethodEvent(self, event):
        self.composing = bool(event.preeditString())
        super().inputMethodEvent(event)


class SearchSymbol(QWidget):
    def __init__(self):
        super().__init__()
        self.setFixedSize(t.px(24), t.px(30))

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(QColor(t.GREEN), t.dp(1.8)))
        painter.drawEllipse(t.rect(3, 6, 12, 12))
        painter.drawLine(QPointF(t.dp(13.5), t.dp(16.5)), QPointF(t.dp(20), t.dp(23)))


class ResultDelegate(QStyledItemDelegate):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.icons = {}

    def sizeHint(self, option, index):
        return QSize(t.px(200), t.px(54))

    def paint(self, painter, option, index):
        result = index.data(Qt.ItemDataRole.UserRole)
        if result is None:
            return
        painter.save()
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        rect = QRectF(option.rect).adjusted(t.dp(18), t.dp(2), -t.dp(18), -t.dp(2))
        selected = bool(option.state & QStyle.StateFlag.State_Selected)
        hovered = bool(option.state & QStyle.StateFlag.State_MouseOver)
        if selected or hovered:
            painter.fillPath(t.squircle(rect, t.dp(14)), QColor(t.RAISED if selected else t.SURFACE))
        if selected:
            painter.fillPath(t.squircle(QRectF(rect.left() + t.dp(1), rect.top() + t.dp(16), t.dp(3), t.dp(18)), t.dp(1.5)), QColor(t.GREEN))
        icon_rect = QRectF(rect.left() + t.dp(14), rect.top() + t.dp(10), t.dp(30), t.dp(30))
        key = (result.icon_path, result.icon_char, option.widget.devicePixelRatioF())
        if key not in self.icons:
            from core.widgets.services.quick_launch.icon_utils import load_and_scale_icon, svg_to_pixmap
            pixmap = QPixmap()
            if result.icon_path:
                pixmap = load_and_scale_icon(result.icon_path, t.px(30), key[2])
            if pixmap.isNull() and result.icon_char.lstrip().startswith('<svg'):
                pixmap = svg_to_pixmap(result.icon_char, t.px(30), key[2])
            self.icons[key] = pixmap
        pixmap = self.icons[key]
        if not pixmap.isNull():
            painter.drawPixmap(icon_rect, pixmap, QRectF(pixmap.rect()))
        else:
            t.icon(painter, 'app-window', icon_rect.adjusted(t.dp(3), t.dp(3), -t.dp(3), -t.dp(3)), t.GREEN if selected else t.MUTED)
        text_rect = QRectF(rect.left() + t.dp(58), rect.top() + t.dp(7), rect.width() - t.dp(84), t.dp(20))
        t.text(painter, text_rect, result.title, 13, weight=500)
        category = result_category(result)
        description = result.description.strip()
        subtitle = category if not description or description == category else f'{category} · {description}'
        t.text(painter, text_rect.translated(0, t.dp(20)).adjusted(0, 0, 0, -t.dp(4)), subtitle, 10, t.MUTED)
        painter.restore()


class Launcher(QWidget):
    active = None

    @classmethod
    def toggle(cls, owner, preview_parent=None):
        if cls.active and cls.active.isVisible():
            cls.active.close_launcher()
            return
        from .launcher_service import LauncherService
        from .model import PreviewBackend
        if preview_parent is not None or isinstance(owner.backend, PreviewBackend):
            service = getattr(owner, '_launcher_service', None)
            if service is None:
                service = LauncherService(preview=True)
                service.setParent(owner)
                owner.destroyed.connect(service.shutdown)
                owner._launcher_service = service
        else:
            service = LauncherService.instance()
        popup = cls(owner, service, preview_parent)
        cls.active = popup
        popup.show_launcher()

    def __init__(self, owner, service, preview_parent=None):
        flags = Qt.WindowType.Widget if preview_parent is not None else Qt.WindowType.Tool | Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint
        super().__init__(preview_parent if preview_parent is not None else owner, flags)
        self.owner, self.service, self.preview_parent = owner, service, preview_parent
        self.query_id = None
        self.query_pending = True
        self.closing = False
        self.disposed = False
        self.launching = False
        self.setWindowTitle('Canopy launcher')
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAttribute(Qt.WidgetAttribute.WA_DeleteOnClose)
        self.setMinimumSize(1, 1)
        area = preview_parent.rect() if preview_parent is not None else owner.screen().availableGeometry()
        if preview_parent is None:
            self.setScreen(owner.screen())
        self.setGeometry(launcher_geometry(area))
        self.opacity = 1.0
        self.backdrop = QImage()

        layout = QVBoxLayout(self)
        # Keep the scroll viewport flush with the panel edge; inset rows and
        # header content separately so the scrollbar isn't trapped in padding.
        layout.setContentsMargins(t.px(20), t.px(34), t.px(20), t.px(30))
        layout.setSpacing(t.px(8))
        heading = QHBoxLayout()
        heading.setContentsMargins(t.px(25), 0, t.px(25), 0)
        heading.setSpacing(t.px(12))
        heading.addWidget(SearchSymbol())
        self.search = SearchInput()
        self.search.setAccessibleName('Search applications, settings and files')
        self.search.setPlaceholderText('Search apps, settings and files…')
        self.search.setFont(t.font(17, 400))
        self.search.setMinimumWidth(0)
        self.search.setFixedHeight(t.px(48))
        self.search.setStyleSheet(f'QLineEdit {{ color:{t.TEXT}; background:transparent; border:0; padding:0; selection-background-color:{t.GREEN}; selection-color:{t.BLACK}; }}')
        heading.addWidget(self.search, 1)
        layout.addLayout(heading)
        self.status = Label('Applications & settings', 10, t.MUTED)
        self.status.setContentsMargins(t.px(26), 0, t.px(26), 0)
        self.status.setFixedHeight(t.px(22))
        layout.addWidget(self.status)
        self.results = QListWidget()
        self.results.setAccessibleName('Search results')
        self.results.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        self.results.setMouseTracking(True)
        self.results.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.results.setVerticalScrollMode(QListWidget.ScrollMode.ScrollPerPixel)
        self.results.setStyleSheet(f'QListWidget {{background:transparent; border:0; outline:0;}} QScrollBar:vertical {{width:{t.px(4)}px; background:transparent;}} QScrollBar::handle:vertical {{background:{t.RAISED};min-height:{t.px(24)}px;border-radius:{t.dp(2)}px;}} QScrollBar::add-line:vertical,QScrollBar::sub-line:vertical{{height:0;}} QScrollBar::add-page:vertical,QScrollBar::sub-page:vertical{{background:transparent;}}')
        self.delegate = ResultDelegate(self.results)
        self.results.setItemDelegate(self.delegate)
        self.results.itemClicked.connect(self.open_result)
        layout.addWidget(self.results, 1)
        self.message = Label('', 12, t.MUTED)
        self.message.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.message.setContentsMargins(t.px(26), 0, t.px(26), 0)
        self.message.setWordWrap(True)
        layout.addWidget(self.message, 1)
        self.message.hide()
        self.footer = Label('↑↓  Navigate     Enter  Open     Esc  Close', 10, t.MUTED, family=t.UTILITY_FAMILY)
        self.footer.setContentsMargins(t.px(26), t.px(6), 0, 0)
        self.footer.setFixedHeight(t.px(26))
        layout.addWidget(self.footer)

        self.debounce = QTimer(self)
        self.debounce.setSingleShot(True)
        self.debounce.setInterval(80)
        self.debounce.timeout.connect(self.submit_query)
        self.search.textChanged.connect(self.query_changed)
        self.blur_timer = QTimer(self)
        self.blur_timer.setSingleShot(True)
        self.blur_timer.timeout.connect(self.check_blur)
        self.animation = QVariantAnimation(self)
        self.animation.setEasingCurve(QEasingCurve.Type.OutCubic)
        self.animation.valueChanged.connect(self.set_opacity)
        self.animation.finished.connect(self.animation_finished)
        self.after_close = None
        service.results_ready.connect(self.receive_results)
        service.state_changed.connect(self.state_changed)
        service.error.connect(self.show_error)
        service.icon_ready.connect(self.icon_ready)
        service.launched.connect(self.launched)
        owner.destroyed.connect(self.dispose)
        QApplication.instance().installEventFilter(self)
        QApplication.instance().aboutToQuit.connect(self.dispose)

    def show_launcher(self):
        self.capture_backdrop()
        self.show()
        self.raise_()
        if self.preview_parent is None:
            disable_native_rounding(self)
            self.activateWindow()
            from core.utils.win32.window_actions import force_foreground_focus
            force_foreground_focus(int(self.winId()))
        self.search.setFocus(Qt.FocusReason.OtherFocusReason)
        # The shared service outlives each popup; pick up installed/removed apps.
        self.service.refresh()
        self.submit_query()
        if not reduced_motion() and self.preview_parent is None:
            self.set_opacity(0.)
            self.animation.setDuration(140)
            self.animation.setStartValue(0.)
            self.animation.setEndValue(1.)
            self.animation.start()

    def capture_backdrop(self):
        # Capture before showing our window. A clipped, in-memory backdrop keeps
        # blur out of the transparent shadow gutter and never blurs the controls.
        panel = self.rect().adjusted(t.px(20), t.px(20), -t.px(20), -t.px(20))
        if self.preview_parent is not None:
            source = panel.translated(self.pos())
            image = self.preview_parent.grab(source).toImage()
        else:
            screen = self.screen()
            position = self.mapToGlobal(panel.topLeft()) - screen.geometry().topLeft()
            image = screen.grabWindow(0, position.x(), position.y(), panel.width(), panel.height()).toImage()
        self.backdrop = frosted_backdrop(image, panel.width(), panel.height())

    def set_opacity(self, value):
        self.opacity = float(value)
        if self.preview_parent is None:
            self.setWindowOpacity(self.opacity)

    def query_changed(self):
        # Keep the previous rows visible until replacement results arrive.
        # They are no longer actionable while the new query is pending.
        self.query_id = None
        self.query_pending = True
        self.debounce.start()

    def submit_query(self):
        if self.closing:
            return
        self.launching = False
        self.query_pending = True
        self.query_id = self.service.search(self.search.text())
        if self.service.loading:
            self.state_changed('loading')

    def state_changed(self, state):
        if self.closing:
            return
        if state == 'loading' and not self.results.count():
            self.show_message('Finding applications…')
        elif state == 'error':
            self.show_error(self.service.error_message)

    def receive_results(self, request_id, results):
        if self.closing or request_id != self.query_id:
            return
        preserve_position = not self.query_pending
        current = self.results.currentItem()
        selected_id = current.data(Qt.ItemDataRole.UserRole).id if current else None
        previous_row = self.results.currentRow()
        scroll = self.results.verticalScrollBar().value()
        self.query_pending = False
        results = [result for result in results if not result.is_separator]
        previous = [self.results.item(i).data(Qt.ItemDataRole.UserRole) for i in range(self.results.count())]
        if results != previous:
            self.results.setUpdatesEnabled(False)
            self.results.clear()
            for result in results:
                item = QListWidgetItem(result.title)
                item.setData(Qt.ItemDataRole.UserRole, result)
                item.setToolTip(f'{result.title}\n{result.description}')
                if result.is_loading or not result.action_data or not result.id:
                    item.setFlags(Qt.ItemFlag.NoItemFlags)
                self.results.addItem(item)
            self.results.setUpdatesEnabled(True)
        self.results.setVisible(bool(self.results.count()))
        self.message.setVisible(not self.results.count())
        if self.results.count():
            row = 0
            if preserve_position:
                row = next((i for i, result in enumerate(results) if result.id == selected_id),
                           max(0, min(previous_row, len(results) - 1)))
            self.results.setCurrentRow(row)
            if preserve_position:
                self.results.verticalScrollBar().setValue(scroll)
        else:
            self.message.setText('No matches. Try another name.' if self.search.text().strip() else 'No applications found. Press Ctrl+R to refresh.')
        self.status.setText('Files · Everything' if self.search.text().lstrip().lower().startswith('file ') else 'Applications, settings & files')
        self.status.setToolTip('Type file followed by a name to search only files. Ctrl+R refreshes applications.')

    def show_message(self, message):
        self.message.setText(message)
        self.message.show()
        self.results.hide()

    def show_error(self, message):
        if self.closing:
            return
        self.launching = False
        self.status.setText(message or 'Could not complete search. Press Ctrl+R to retry.')
        self.status.setToolTip(self.status.text())
        if not self.results.count():
            self.show_message(self.status.text())

    def icon_ready(self, result_id, path):
        for index in range(self.results.count()):
            result = self.results.item(index).data(Qt.ItemDataRole.UserRole)
            if result.id == result_id:
                result.icon_path = path
        self.results.viewport().update()

    def open_result(self, item=None):
        if self.closing or self.launching or self.query_pending or self.search.composing:
            return
        item = item or self.results.currentItem()
        if item is None or not item.flags() & Qt.ItemFlag.ItemIsEnabled:
            return
        self.launching = True
        if not self.service.launch(item.data(Qt.ItemDataRole.UserRole)):
            self.launching = False

    def launched(self, result):
        if self.launching:
            self.close_launcher(immediate=True)

    def check_blur(self):
        if self.preview_parent is None and not self.isActiveWindow():
            self.close_launcher()

    def close_launcher(self, callback=None, immediate=False):
        if callback:
            self.after_close = callback
        if self.closing and not immediate:
            return
        self.closing = True
        self.debounce.stop()
        self.blur_timer.stop()
        self.animation.stop()
        if immediate or reduced_motion() or self.preview_parent is not None:
            self.dispose()
        else:
            self.animation.setDuration(90)
            self.animation.setStartValue(self.opacity)
            self.animation.setEndValue(0.)
            self.animation.start()

    def animation_finished(self):
        if self.closing:
            self.dispose()

    def dispose(self):
        if self.disposed:
            return
        self.disposed = True
        self.closing = True
        self.debounce.stop()
        self.blur_timer.stop()
        self.animation.stop()
        QApplication.instance().removeEventFilter(self)
        if Launcher.active is self:
            Launcher.active = None
        self.hide()
        callback, self.after_close = self.after_close, None
        self.deleteLater()
        if callback:
            QTimer.singleShot(0, callback)

    def eventFilter(self, obj, event):
        if not self.isVisible() or self.closing:
            return False
        if event.type() == QEvent.Type.KeyPress and isinstance(obj, QWidget) and (obj is self or self.isAncestorOf(obj)):
            if self.search.composing:
                return False
            key = event.key()
            if key == Qt.Key.Key_Escape:
                self.close_launcher()
                return True
            if key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                self.open_result()
                return True
            if key in (Qt.Key.Key_Up, Qt.Key.Key_Down, Qt.Key.Key_PageUp, Qt.Key.Key_PageDown):
                step = {Qt.Key.Key_Up: -1, Qt.Key.Key_Down: 1, Qt.Key.Key_PageUp: -5, Qt.Key.Key_PageDown: 5}[key]
                self.results.setCurrentRow(max(0, min(self.results.count() - 1, self.results.currentRow() + step)))
                return True
            if key == Qt.Key.Key_R and event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                self.service.refresh()
                return True
        if event.type() == QEvent.Type.WindowDeactivate and obj is self:
            self.blur_timer.start(140)
        if event.type() == QEvent.Type.MouseButtonPress and hasattr(event, 'globalPosition'):
            # The trigger button owns toggling, otherwise its click would reopen us.
            if obj is getattr(self.owner, 'launcher', None):
                return False
            point = self.mapFromGlobal(event.globalPosition().toPoint())
            if not t.squircle(QRectF(self.rect()).adjusted(t.dp(20), t.dp(20), -t.dp(20), -t.dp(20)), t.dp(32)).contains(QPointF(point)):
                self.close_launcher()
        return False

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.drawImage(0, 0, popup_shadow(self.width(), self.height()))
        rect = QRectF(self.rect()).adjusted(t.dp(20), t.dp(20), -t.dp(20), -t.dp(20))
        path = t.squircle(rect, t.dp(32))
        if self.backdrop.isNull():
            painter.fillPath(path, QColor(t.BLACK))
        else:
            painter.save()
            painter.setClipPath(path)
            painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
            painter.drawImage(rect, self.backdrop)
            painter.fillPath(path, QColor(6, 12, 8, 178))
            painter.restore()
        painter.setPen(QPen(QColor(89, 112, 91, 120), t.dp(1)))
        painter.drawPath(path)

    def closeEvent(self, event):
        self.dispose()
        event.accept()
