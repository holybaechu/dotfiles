import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

Item {
    id: bar
    property var output: null
    property var hostWindow: null
    readonly property var monitor: CanopyState.preview || !output ? null : Hyprland.monitorFor(output)
    readonly property int activeWorkspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
    readonly property bool panelHere: CanopyState.coveredPanel.length > 0 && (!output || CanopyState.coveredScreen === output)
    readonly property string windowTitle: monitor && monitor.activeWorkspace
        ? monitor.activeWorkspace.lastIpcObject.lastwindowtitle || "Desktop" : "Desktop"
    readonly property int mediaWidth: width <= 600 ? 130 : width <= 740 ? 160 : width <= 1000 ? 200 : 256
    readonly property real rightWidth: rightIsland.width
    function registerGeometry() { CanopyState.registerIslands(output, leftRow.implicitWidth + 8, mediaWidth, rightWidth); }
    onRightWidthChanged: registerGeometry()
    onMediaWidthChanged: registerGeometry()
    onOutputChanged: registerGeometry()
    Component.onCompleted: registerGeometry()
    implicitHeight: 40
    function duration(value) { value = Math.max(0, Math.floor(value || 0)); return Math.floor(value / 60) + ":" + (value % 60).toString().padStart(2, "0"); }

    component Divider: Item {
        implicitWidth: 9
        implicitHeight: 32
        Rectangle { anchors.centerIn: parent; width: 1; height: 10; color: Theme.surface }
    }
    CanopyIsland {
        edge: "left"
        width: leftRow.implicitWidth + 8
        height: 40
        RowLayout {
            id: leftRow
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 4
            CanopyButton {
                visible: bar.width > 600
                implicitWidth: 32
                iconName: "cachyos"
                iconSize: 15
                textColor: Theme.accent
                hint: "Open Canopy launcher"
                onClicked: CanopyState.toggleLauncher(bar.output)
            }
            Item {
                id: workspaces
                readonly property int buttonWidth: bar.width <= 600 ? 16 : bar.width <= 740 ? 19 : 26
                readonly property real selectedX: (Math.max(1, Math.min(8, bar.activeWorkspace)) - 1) * (buttonWidth + 3)
                Layout.preferredWidth: buttonWidth * 8 + 3 * 7
                Layout.preferredHeight: 26
                onSelectedXChanged: workspaceMotion.move([selectedX])
                Component.onCompleted: workspaceMotion.snap([selectedX])
                CanopySpring { id: workspaceMotion; retention: 0.2; force: 0.22 }
                CanopySurface {
                    x: workspaceMotion.values[0]
                    width: workspaces.buttonWidth; height: 26; radius: 9; color: Theme.raised
                    Rectangle { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: Math.max(4, parent.width - 14); height: 2; radius: 1; color: Theme.accent }
                }
                Row {
                    spacing: 3
                    Repeater {
                        model: 8
                        CanopyButton {
                            required property int index
                            readonly property var workspace: CanopyState.preview ? null : Hyprland.workspaces.values.find(w => w.id === index + 1)
                            readonly property bool occupied: CanopyState.preview ? index < 3 : workspace ? workspace.toplevels.values.length > 0 : false
                            implicitWidth: workspaces.buttonWidth
                            implicitHeight: 26
                            radius: 9
                            text: (index + 1).toString()
                            font.pixelSize: 11
                            font.weight: bar.activeWorkspace === index + 1 ? Font.DemiBold : Font.Medium
                            textColor: bar.activeWorkspace === index + 1 ? Theme.text : Theme.muted
                            hint: "Workspace " + text
                            onClicked: CanopyState.focusWorkspace(index + 1, bar.output)
                            Rectangle {
                                visible: parent.occupied && bar.activeWorkspace !== parent.index + 1
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                                width: 4; height: 2; color: Theme.muted
                            }
                        }
                    }
                }
            }
        }
    }
    CanopyIsland {
        anchors.horizontalCenter: parent.horizontalCenter
        width: bar.mediaWidth
        height: 40
        CanopyButton {
            id: media
            readonly property bool covered: bar.panelHere && CanopyState.coveredPanel === "media"
            property real concealment: covered ? 1 : 0
            anchors.fill: parent
            anchors.margins: 4
            enabled: !covered
            opacity: covered ? 0 : 1
            transform: Translate { y: Theme.reducedMotion ? 0 : -2 * media.concealment }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: !Theme.reducedMotion; blurMax: Theme.transitionBlurMax; blur: media.concealment }
            Behavior on opacity { NumberAnimation { duration: media.covered ? 120 : 240; easing.type: Easing.OutCubic } }
            Behavior on concealment { NumberAnimation { duration: media.covered ? 120 : 280; easing.type: Easing.OutCubic } }
            hint: "Open media panel"
            onClicked: CanopyState.togglePanel("media", bar.output)
            contentItem: Item {
                CanopySurface {
                    id: cover
                    width: 24; height: 24; radius: 7; color: Theme.surface
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        id: thumbnail
                        anchors.fill: parent
                        source: CanopyState.player ? CanopyState.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                        layer.enabled: true
                    }
                    CanopySurface { id: thumbnailMask; anchors.fill: parent; radius: 7; color: "white"; layer.enabled: true; visible: false }
                    MultiEffect { anchors.fill: parent; source: thumbnail; maskEnabled: true; maskSource: thumbnailMask; visible: thumbnail.status === Image.Ready }
                    CanopyIcon {
                        anchors.centerIn: parent; size: 16; color: Theme.accent
                        name: CanopyState.player || CanopyState.preview ? "music-2" : "app-window"
                        visible: thumbnail.status !== Image.Ready
                    }
                }
                Column {
                    anchors { left: cover.right; leftMargin: 7; right: parent.right; verticalCenter: parent.verticalCenter }
                    Text {
                        width: parent.width; height: 12; elide: Text.ElideRight
                        text: CanopyState.player || CanopyState.preview ? CanopyState.mediaTitle : bar.windowTitle
                        color: Theme.text; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold
                    }
                    RowLayout {
                        width: parent.width; height: 12; spacing: 6
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            text: CanopyState.player || CanopyState.preview ? CanopyState.mediaArtist : "Dwindle · Hyprland"
                            color: Theme.muted; font.family: Theme.font; font.pixelSize: 10
                        }
                        Text {
                            visible: bar.width > 740 && (CanopyState.preview || CanopyState.player !== null)
                            text: CanopyState.preview ? "0:42 / 4:00" : bar.duration(CanopyState.player ? CanopyState.player.position : 0) + " / " + bar.duration(CanopyState.player ? CanopyState.player.length : 0)
                            color: Theme.muted; font.family: Theme.utilityFont; font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
    CanopyIsland {
        id: rightIsland
        edge: "right"
        anchors.right: parent.right
        width: statusRow.implicitWidth + 8
        height: 40
        RowLayout {
            id: statusRow
            readonly property bool covered: bar.panelHere && CanopyState.coveredPanel !== "media"
            property real concealment: covered ? 1 : 0
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 4
            enabled: !covered
            opacity: covered ? 0 : 1
            transform: Translate { y: Theme.reducedMotion ? 0 : -2 * statusRow.concealment }
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: !Theme.reducedMotion; blurMax: Theme.transitionBlurMax; blur: statusRow.concealment }
            Behavior on opacity { NumberAnimation { duration: statusRow.covered ? 120 : 240; easing.type: Easing.OutCubic } }
            Behavior on concealment { NumberAnimation { duration: statusRow.covered ? 120 : 280; easing.type: Easing.OutCubic } }
            CanopyButton {
                visible: CanopyState.lastError.length > 0
                implicitWidth: 26; iconName: "circle-alert"; iconSize: 15; textColor: Theme.error
                hint: CanopyState.lastError
                onClicked: CanopyState.togglePanel("quick", bar.output)
            }
            CanopyButton {
                implicitWidth: 26; iconName: "chevron-down"; iconSize: 15; hint: "System tray"
                onClicked: CanopyState.togglePanel("tray", bar.output)
            }
            CanopyButton {
                implicitWidth: 26; iconName: "bell"; iconSize: 15
                textColor: CanopyState.notifications.length > 0 ? Theme.accent : Theme.muted
                hint: "Notifications" + (CanopyState.notifications.length > 0 ? " (" + CanopyState.notifications.length + ")" : "")
                onClicked: CanopyState.togglePanel("notifications", bar.output)
            }
            Divider {}
            CanopyButton {
                implicitWidth: indicators.implicitWidth + 8
                hint: "Sound, network and power"
                onClicked: CanopyState.togglePanel("quick", bar.output)
                contentItem: Row {
                    id: indicators
                    spacing: bar.width > 600 ? 9 : 5
                    CanopyIcon {
                        visible: bar.width > 600
                        anchors.verticalCenter: parent.verticalCenter
                        size: 15; name: CanopyState.preview || CanopyState.networkState.indexOf("connected") === 0 ? "wifi" : "wifi-off"
                        color: name === "wifi" ? Theme.accent : Theme.muted
                    }
                    CanopyIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 15; name: CanopyState.muted ? "volume-x" : CanopyState.volume <= 0 ? "volume" : CanopyState.volume <= 50 ? "volume-1" : "volume-2"
                        color: CanopyState.muted ? Theme.accent : Theme.text
                    }
                    CanopyIcon {
                        visible: CanopyState.batteryText.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        size: 15; name: CanopyState.charging ? "battery-charging" : CanopyState.batteryPercentage <= 15 ? "battery-warning" : CanopyState.batteryPercentage <= 35 ? "battery-low" : CanopyState.batteryPercentage <= 75 ? "battery-medium" : "battery-full"
                        color: CanopyState.charging ? Theme.accent : CanopyState.batteryPercentage <= 15 ? Theme.error : Theme.text
                    }
                    Text {
                        visible: bar.width > 740 && CanopyState.batteryText.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: CanopyState.batteryText; color: Theme.text; font.family: Theme.utilityFont; font.pixelSize: 11
                    }
                }
            }
            Divider {}
            CanopyButton {
                implicitWidth: clockRow.implicitWidth + 8
                hint: "Calendar"
                onClicked: CanopyState.togglePanel("calendar", bar.output)
                contentItem: Row {
                    id: clockRow
                    spacing: 9
                    Text {
                        visible: bar.width > 1000
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.locale().name.indexOf("ko") === 0 ? Qt.formatDateTime(clock.date, "d일 (ddd)") : Qt.formatDateTime(clock.date, "d ddd")
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 10
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.text; font.family: Theme.utilityFont; font.pixelSize: 12; font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
