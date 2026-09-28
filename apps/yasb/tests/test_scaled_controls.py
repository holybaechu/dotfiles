from PyQt6.QtCore import QPoint, Qt
from PyQt6.QtTest import QTest

from core.widgets.canopy import theme
from core.widgets.canopy.controls import Button, Slider


def test_scaled_button_keeps_click_target(app):
    clicked = []
    button = Button('Open', callback=lambda: clicked.append(True))
    button.show()
    assert button.size().width() == button.size().height() == theme.px(32)
    QTest.mouseClick(button, Qt.MouseButton.LeftButton, pos=button.rect().center())
    assert clicked == [True]
    button.deleteLater()


def test_scaled_slider_maps_pointer_to_full_value_range(app):
    committed = []
    slider = Slider('Volume', committed.append, commit=True)
    slider.setFixedWidth(theme.px(200))
    slider.show()
    assert slider.height() == theme.px(32)
    QTest.mouseClick(slider, Qt.MouseButton.LeftButton, pos=QPoint(theme.px(12), slider.height() // 2))
    assert committed[-1] == 0
    QTest.mouseClick(slider, Qt.MouseButton.LeftButton, pos=QPoint(slider.width() - theme.px(12), slider.height() // 2))
    assert committed[-1] == 100
    slider.deleteLater()
