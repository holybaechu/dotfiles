import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: root
    property var hostWindow: null
    property var menuItem: null
    readonly property var items: CanopyState.trayItems
    spacing: 16
    function showMenu(button, item) {
        if (!item.hasMenu || !root.hostWindow || CanopyState.preview) return;
        if (trayMenu.visible) trayMenu.close();
        menuItem = item;
        const position = button.mapToItem(null, 0, button.height);
        trayMenu.anchor.rect.x = Math.round(position.x);
        trayMenu.anchor.rect.y = Math.round(position.y);
        // Release the panel's focus grab before the native popup takes focus.
        CanopyState.trayMenuOpen = true;
        trayMenu.open();
        if (!trayMenu.visible) CanopyState.trayMenuOpen = false;
    }
    QsMenuAnchor {
        id: trayMenu
        menu: root.menuItem ? root.menuItem.menu : null
        anchor.window: root.hostWindow
        onClosed: CanopyState.trayMenuOpen = false
    }
    Component.onDestruction: {
        if (trayMenu.visible) trayMenu.close();
        CanopyState.trayMenuOpen = false;
    }
    GridLayout {
        visible: root.items.length > 0
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: root.items
            CanopyButton {
                id: trayButton
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 56
                radius: 16
                hint: modelData.tooltipTitle || modelData.title || modelData.id
                contentItem: Item {
                    Image { anchors.centerIn: parent; width: 24; height: 24; source: trayButton.modelData.icon; sourceSize.width: 24; sourceSize.height: 24; fillMode: Image.PreserveAspectFit }
                }
                onClicked: {
                    if (modelData.onlyMenu) root.showMenu(trayButton, modelData);
                    else modelData.activate();
                }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: root.showMenu(trayButton, trayButton.modelData) }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: trayButton.modelData.secondaryActivate() }
            }
        }
    }
    Text {
        visible: root.items.length === 0
        Layout.fillWidth: true; Layout.preferredHeight: 120
        text: "No tray icons available"
        color: Theme.muted; font.family: Theme.font; font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
    }
    Text { visible: root.items.length > 0; text: "Right-click an icon for its menu."; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
}
