import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property string caption: ""
    property string symbol: ""
    property bool active: false
    property bool available: true
    property bool busy: false
    property bool showSettings: false
    property string subtitle: available ? active ? "On" : "Off" : "Unavailable"
    signal toggled()
    signal settingsRequested()
    implicitHeight: 51
    implicitWidth: 154
    Button {
        id: control
        anchors.fill: parent
        leftPadding: 12
        rightPadding: root.showSettings ? 40 : 12
        topPadding: 0
        bottomPadding: 0
        enabled: root.available && !root.busy
        hoverEnabled: true
        Accessible.name: root.caption + ": " + root.subtitle
        ToolTip.visible: hovered
        ToolTip.text: root.caption + ": " + root.subtitle
        onClicked: root.toggled()
        background: CanopySurface {
            radius: 18
            color: root.active ? (control.down ? "#719c37" : control.hovered ? "#92bd56" : Theme.accent)
                : control.down ? Theme.selection : control.hovered ? Theme.raised : Theme.surface
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 16; color: "transparent"; border.width: control.visualFocus ? 2 : 0; border.color: Theme.accent }
        }
        contentItem: RowLayout {
            spacing: 8
            CanopyIcon {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
                size: 18
                name: root.symbol
                color: root.active ? Theme.black : Theme.muted
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text { Layout.fillWidth: true; text: root.caption; color: root.active ? Theme.black : Theme.text; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: root.subtitle; color: root.active ? Theme.black : Theme.muted; font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight }
            }
        }
    }
    CanopyButton {
        visible: root.showSettings
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        width: 28; height: 32
        padding: 0
        iconName: "arrow-up-right"
        iconSize: 13
        textColor: root.active ? Theme.black : Theme.muted
        hint: "Open " + root.caption.toLowerCase() + " settings"
        onClicked: root.settingsRequested()
    }
}
