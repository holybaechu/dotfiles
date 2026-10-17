//@ pragma UseQApplication
//@ pragma IconTheme Adwaita
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    IpcHandler {
        target: "launcher"
        function toggle(): void { CanopyState.toggleLauncher(null); }
        function files(): void {
            CanopyState.targetScreen = CanopyState.focusedScreen();
            CanopyState.panel = "";
            CanopyState.launcherQuery = "file ";
            CanopyState.launcherOpen = true;
        }
    }
    IpcHandler {
        target: "panel"
        function toggle(): void { CanopyState.togglePanel("quick", null); }
        function show(kind: string): void {
            if (!["quick", "media", "calendar", "tray", "notifications", "power"].includes(kind)) return;
            CanopyState.targetScreen = CanopyState.focusedScreen();
            CanopyState.launcherOpen = false;
            CanopyState.panel = kind;
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 40
            color: "transparent"
            WlrLayershell.namespace: "canopy-bar"
            BarContent { anchors.fill: parent; output: bar.screen; hostWindow: bar }
        }
    }
    PanelWindow {
        id: launcherWindow
        readonly property bool requested: CanopyState.launcherOpen && !panelMotion.present
        visible: requested || launcher.opacity > 0
        screen: CanopyState.targetScreen || Quickshell.screens[0]
        anchors.top: true
        margins.top: screen ? Math.round(screen.height * 0.44 - height / 2) : 100
        implicitWidth: Math.min(520, screen ? screen.width : 520)
        implicitHeight: 460
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "canopy-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        mask: Region { item: launcher }
        BackgroundEffect.blurRegion: Region { item: launcher; radius: 20 }
        LauncherContent {
            id: launcher
            anchors.fill: parent
            anchors.margins: 20
            opacity: launcherWindow.requested ? 1 : 0
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#60000000"; shadowBlur: 0.7; shadowVerticalOffset: 8 }
            Behavior on opacity {
                enabled: CanopyState.panel.length === 0 && !Theme.reducedMotion
                NumberAnimation { duration: launcherWindow.requested ? 140 : 90; easing.type: Easing.OutCubic }
            }
        }
        onRequestedChanged: { if (requested) launcher.reset(CanopyState.launcherQuery); }
        Connections {
            target: CanopyState
            function onLauncherQueryChanged() { if (launcherWindow.requested) launcher.reset(CanopyState.launcherQuery); }
        }
    }
    HyprlandFocusGrab {
        active: launcherWindow.requested
        windows: [launcherWindow]
        onCleared: { if (CanopyState.launcherOpen) CanopyState.launcherOpen = false; }
    }
    PanelWindow {
        id: panelWindow
        property string displayedKind: "quick"
        property var displayedScreen: null
        readonly property var sourceSizes: CanopyState.islandWidths[screen ? screen.name : ""] || ({media: 256, right: 240})
        visible: panelMotion.present
        screen: displayedScreen || CanopyState.targetScreen || Quickshell.screens[0]
        anchors { top: true; right: panelMotion.rightEdge }
        implicitWidth: Math.min(panelMotion.implicitWidth, screen ? screen.width : panelMotion.implicitWidth)
        implicitHeight: panelMotion.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "canopy-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: Region { item: panelMotion.hitArea }

        function syncPanel() {
            if (!CanopyState.panel.length) {
                panelMotion.expanded = false;
                return;
            }
            const requestedScreen = CanopyState.targetScreen || CanopyState.focusedScreen();
            if (panelMotion.present && (displayedKind !== CanopyState.panel || displayedScreen !== requestedScreen)) {
                panelMotion.expanded = false;
                return;
            }
            displayedKind = CanopyState.panel;
            displayedScreen = requestedScreen;
            panelMotion.expanded = true;
        }
        CanopyPanel {
            id: panelMotion
            anchors.fill: parent
            kind: panelWindow.displayedKind
            hostWindow: panelWindow
            availableHeight: panelWindow.screen ? panelWindow.screen.height - 24 : 876
            sourceWidth: rightEdge ? panelWindow.sourceSizes.right : panelWindow.sourceSizes.media
            onClosed: panelWindow.syncPanel()
        }
        Binding { target: CanopyState; property: "coveredPanel"; value: panelMotion.present ? panelWindow.displayedKind : "" }
        Binding { target: CanopyState; property: "coveredScreen"; value: panelMotion.present ? panelWindow.displayedScreen : null }
        Connections {
            target: CanopyState
            function onPanelChanged() { panelWindow.syncPanel(); }
            function onTargetScreenChanged() { panelWindow.syncPanel(); }
        }
    }
    HyprlandFocusGrab {
        active: panelMotion.expanded && !CanopyState.trayMenuOpen
        windows: [panelWindow]
        onCleared: { if (panelMotion.expanded && !CanopyState.trayMenuOpen) CanopyState.panel = ""; }
    }
    PanelWindow {
        visible: CanopyState.notifications.length > 0 && CanopyState.panel.length === 0
        screen: CanopyState.focusedScreen()
        anchors { top: true; right: true }
        margins.top: 48
        margins.right: 8
        implicitWidth: 380
        implicitHeight: toasts.implicitHeight
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "canopy-notifications"
        ColumnLayout {
            id: toasts
            anchors.fill: parent
            spacing: 8
            Repeater {
                model: CanopyState.notifications.slice(-3)
                NotificationCard {
                    id: toast
                    required property var modelData
                    notification: modelData
                    Layout.fillWidth: true
                    Timer {
                        interval: Math.max(1000, toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 6000)
                        running: !CanopyState.preview && toast.modelData.expireTimeout !== 0
                        onTriggered: toast.modelData.expire()
                    }
                }
            }
        }
    }
}
