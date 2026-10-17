import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

CanopySurface {
    id: root
    property string kind: CanopyState.panel
    property string pendingPower: ""
    property var hostWindow: null
    property bool paintBackground: true
    property bool rightEdge: kind !== "media"
    readonly property bool resizing: (loader.item as QuickSettings)?.resizing ?? false
    implicitWidth: kind === "quick" || kind === "power" ? 352 : kind === "calendar" ? 320 : kind === "tray" ? 336 : 420
    implicitHeight: body.y + body.implicitHeight + (kind === "quick" ? 8 : 18)
    radius: 44
    topLeftRadius: 0
    topRightRadius: 0
    bottomRightRadius: rightEdge ? 0 : radius
    color: paintBackground ? Theme.black : "transparent"
    focus: true
    Keys.onEscapePressed: CanopyState.close()
    onKindChanged: pendingPower = ""

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 3 }
        spacing: 18
        Text {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            text: ({quick: "Quick controls", media: "Now playing", calendar: "Calendar", tray: "System tray", notifications: "Notifications", power: "Power options"})[root.kind] || "Quick controls"
            color: Theme.text; font.family: Theme.displayFont; font.pixelSize: 17; font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
        }
        Loader {
            id: loader
            Layout.fillWidth: true
            sourceComponent: root.kind === "media" ? media : root.kind === "calendar" ? calendar
                : root.kind === "tray" ? tray : root.kind === "notifications" ? notifications : root.kind === "power" ? power : quick
        }
        Text { visible: CanopyState.lastError.length > 0; text: CanopyState.lastError; textFormat: Text.PlainText; color: Theme.error; font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
    Component { id: quick; QuickSettings {} }
    Component { id: media; MediaContent {} }
    Component { id: calendar; CalendarContent {} }
    Component { id: tray; TrayContent { hostWindow: root.hostWindow } }
    Component {
        id: notifications
        ColumnLayout {
            spacing: 12
            Text { visible: CanopyState.notifications.length === 0; text: "All caught up."; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12; Layout.preferredHeight: 120; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            ScrollView {
                id: notificationScroll
                visible: CanopyState.notifications.length > 0
                Layout.fillWidth: true
                implicitHeight: Math.min(440, cards.implicitHeight)
                clip: true
                contentWidth: availableWidth
                ColumnLayout {
                    id: cards
                    width: notificationScroll.availableWidth
                    spacing: 8
                    Repeater { model: CanopyState.notifications; NotificationCard { required property var modelData; notification: modelData; Layout.fillWidth: true } }
                }
            }
        }
    }
    Component {
        id: power
        ColumnLayout {
            spacing: 6
            Repeater {
                model: [
                    {label: "Lock", icon: "lock", action: "lock", confirm: false},
                    {label: "Sign out", icon: "arrow-up-right", action: "logout", confirm: true},
                    {label: "Sleep", icon: "moon", action: "suspend", confirm: false},
                    {label: "Hibernate", icon: "moon", action: "hibernate", confirm: false},
                    {label: "Restart", icon: "power", action: "reboot", confirm: true},
                    {label: "Shut down", icon: "power", action: "poweroff", confirm: true}
                ]
                CanopyButton {
                    id: powerAction
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.topMargin: modelData.action === "reboot" ? 8 : 0
                    implicitHeight: 36
                    hint: modelData.label
                    accent: root.pendingPower === modelData.action
                    contentItem: RowLayout {
                        spacing: 10
                        CanopyIcon { name: powerAction.modelData.icon; size: 16; color: powerAction.accent ? Theme.black : Theme.muted }
                        Text { text: (powerAction.accent ? "Confirm " : "") + powerAction.modelData.label; color: powerAction.accent ? Theme.black : Theme.text; font.family: Theme.font; font.pixelSize: 12; Layout.fillWidth: true }
                    }
                    onClicked: {
                        if (modelData.confirm && root.pendingPower !== modelData.action) { root.pendingPower = modelData.action; return; }
                        if (modelData.action === "logout") CanopyState.run(["hyprctl", "dispatch", "hl.dsp.exit()"], true);
                        else if (modelData.action === "lock") CanopyState.run(["loginctl", "lock-session"], true);
                        else CanopyState.run(["systemctl", modelData.action], true);
                    }
                }
            }
            CanopyButton { text: "Back to quick controls"; Layout.fillWidth: true; Layout.topMargin: 8; onClicked: { root.pendingPower = ""; CanopyState.panel = "quick"; } }
        }
    }
}
