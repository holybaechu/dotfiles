import pytest

from PyQt6.QtCore import QRect, Qt
from PyQt6.QtGui import QInputMethodEvent
from PyQt6.QtTest import QTest

from core.widgets.canopy.launcher import Launcher, launcher_geometry, result_category
from core.widgets.canopy.island import Panel
from core.widgets.services.quick_launch.base_provider import ProviderResult


@pytest.fixture
def popup(desktop):
    _, canvas, _ = desktop
    canvas.launch()
    value = Launcher.active
    for _ in range(60):
        QTest.qWait(10)
        if value.results.count():
            break
    assert value.results.count()
    yield value
    if Launcher.active:
        Launcher.active.close_launcher(immediate=True)


@pytest.mark.parametrize('screen', [QRect(0, 40, 1920, 1040), QRect(-1920, -100, 1920, 1080), QRect(2000, 0, 640, 480)])
def test_popup_is_centered_above_midpoint_and_fits_work_area(screen):
    rect = launcher_geometry(screen)
    assert screen.contains(rect)
    assert abs(rect.center().x() - screen.center().x()) <= 1
    assert rect.center().y() <= screen.center().y()


def test_typing_selects_result_and_enter_launches_without_real_apps(popup):
    assert popup.search.hasFocus()
    QTest.keyClicks(popup.search, 'code')
    QTest.qWait(160)
    assert popup.results.currentItem().text() == 'Codex'
    QTest.keyClick(popup.search, Qt.Key.Key_Down)
    selected = popup.results.currentItem().text()
    QTest.keyClick(popup.search, Qt.Key.Key_Return)
    for _ in range(100):
        if Launcher.active is None:
            break
        QTest.qWait(10)
    assert Launcher.active is None
    assert popup.service._worker.provider.launched[-1] == selected


def test_new_text_preserves_rows_but_disables_stale_activation_until_update(popup):
    stale_id = popup.query_id
    old = popup.results.currentItem().data(Qt.ItemDataRole.UserRole)
    count = popup.results.count()
    popup.search.setText('not-the-old-query')
    assert popup.results.count() == count
    assert popup.results.currentItem().data(Qt.ItemDataRole.UserRole).id == old.id
    popup.receive_results(stale_id, [old])
    assert popup.results.count() == count
    QTest.keyClick(popup.search, Qt.Key.Key_Return)
    assert not popup.service._worker.provider.launched
    QTest.qWait(180)
    assert popup.message.isVisible()
    assert 'No matches' in popup.message.text()


def test_escape_and_repeat_trigger_dismiss(popup, desktop):
    QTest.keyClick(popup.search, Qt.Key.Key_Escape)
    assert Launcher.active is None
    desktop[1].launch()
    assert Launcher.active is not None
    desktop[1].launch()
    assert Launcher.active is None


def test_ime_composition_does_not_launch_or_dismiss(popup):
    from PyQt6.QtWidgets import QApplication
    QApplication.sendEvent(popup.search, QInputMethodEvent('한', []))
    assert popup.search.composing
    QTest.keyClick(popup.search, Qt.Key.Key_Return)
    assert Launcher.active is popup
    assert not popup.service._worker.provider.launched


def test_information_row_cannot_be_launched(popup):
    popup.receive_results(popup.query_id, [ProviderResult(title='Everything is unavailable', provider='file_search')])
    assert not popup.results.item(0).flags() & Qt.ItemFlag.ItemIsEnabled
    QTest.keyClick(popup.search, Qt.Key.Key_Return)
    assert Launcher.active is popup
    assert not popup.service._worker.provider.launched


def test_opening_bar_panel_dismisses_launcher(popup, desktop):
    desktop[1].right.toggle('calendar')
    assert Launcher.active is None
    assert Panel.active.kind == 'calendar'


def test_result_categories_distinguish_control_panel_settings_and_folders():
    assert result_category(ProviderResult(title='Sound', action_data={'path': 'CPL::{id}::Microsoft.Sound'})) == 'Control Panel'
    assert result_category(ProviderResult(title='Sound', provider='settings')) == 'Settings'
    assert result_category(ProviderResult(title='Downloads', provider='file_search', action_data={'is_folder': True})) == 'Folder'
