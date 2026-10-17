import QtQuick
import QtQuick.Layouts

CanopySurface {
    id: root
    required property var notification
    implicitHeight: body.implicitHeight + 24
    color: Theme.surface
    radius: 18
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        RowLayout {
            Text { text: root.notification.appName || "Notification"; textFormat: Text.PlainText; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
            CanopyButton { iconName: "x"; iconSize: 13; hint: "Dismiss notification"; implicitWidth: 24; implicitHeight: 24; onClicked: CanopyState.dismiss(root.notification) }
        }
        Text { text: root.notification.summary; textFormat: Text.PlainText; color: Theme.text; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Text { text: root.notification.body; textFormat: Text.PlainText; visible: text.length > 0; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; wrapMode: Text.Wrap; Layout.fillWidth: true }
        Flow {
            Layout.fillWidth: true
            visible: (root.notification.actions || []).length > 0
            spacing: 4
            Repeater {
                model: root.notification.actions || []
                CanopyButton { required property var modelData; text: modelData.text; onClicked: { if (!CanopyState.preview) modelData.invoke(); } }
            }
        }
    }
}
