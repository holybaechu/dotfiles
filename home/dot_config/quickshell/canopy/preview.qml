//@ pragma UseQApplication
//@ pragma IconTheme Adwaita
import QtQuick
import QtQuick.Effects
import Quickshell

ShellRoot {
    FloatingWindow {
        id: window
        implicitWidth: 1440
        implicitHeight: 900
        color: "#1b2317"
        title: "Canopy preview"
        Rectangle {
            id: canvas
            anchors.fill: parent
            color: window.color
            focus: true
            Image { id: wallpaper; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.local/share/backgrounds/canopy.jpg"; fillMode: Image.PreserveAspectCrop }
            BarContent { id: bar; anchors { top: parent.top; left: parent.left; right: parent.right } }
            CanopyPanel {
                id: popup
                property string displayedKind: "quick"
                x: rightEdge ? canvas.width - width : (canvas.width - width) / 2
                width: implicitWidth
                height: implicitHeight
                kind: displayedKind
                hostWindow: window
                availableHeight: canvas.height - 24
                sourceWidth: rightEdge ? bar.rightWidth : bar.mediaWidth
                onClosed: canvas.syncPanel()
            }
            Binding { target: CanopyState; property: "coveredPanel"; value: popup.present ? popup.kind : "" }
            Binding { target: CanopyState; property: "coveredScreen"; value: null }
            Item {
                x: launcher.x; y: launcher.y; width: launcher.width; height: launcher.height
                visible: launcher.visible
                opacity: launcher.opacity
                ShaderEffectSource {
                    id: backdrop
                    sourceItem: wallpaper
                    sourceRect: Qt.rect(launcher.x, launcher.y, launcher.width, launcher.height)
                    width: launcher.width; height: launcher.height
                    visible: false
                }
                CanopySurface { id: backdropMask; anchors.fill: parent; radius: 32; color: "white"; layer.enabled: true; visible: false }
                MultiEffect { anchors.fill: parent; source: backdrop; autoPaddingEnabled: false; blurEnabled: true; blurMax: 64; blur: 1; maskEnabled: true; maskSource: backdropMask }
            }
            LauncherContent {
                id: launcher
                readonly property bool requested: CanopyState.launcherOpen && !popup.present
                x: (canvas.width - width) / 2
                y: canvas.height * 0.44 - height / 2
                width: 480
                height: 420
                visible: requested || opacity > 0
                opacity: requested ? 1 : 0
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#60000000"; shadowBlur: 0.7; shadowVerticalOffset: 8 }
                Behavior on opacity {
                    enabled: CanopyState.panel.length === 0 && !Theme.reducedMotion
                    NumberAnimation { duration: launcher.requested ? 140 : 90; easing.type: Easing.OutCubic }
                }
                onRequestedChanged: { if (requested) reset(CanopyState.launcherQuery); }
            }
            Text {
                anchors { left: parent.left; bottom: parent.bottom; margins: 24 }
                text: "CANOPY  /  Click an island · Space: quick controls · Esc: close"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 12
            }
            Keys.onSpacePressed: { if (!CanopyState.launcherOpen) CanopyState.togglePanel("quick", null); }
            Keys.onEscapePressed: CanopyState.close()
            function syncPanel() {
                if (!CanopyState.panel.length) { popup.expanded = false; return; }
                if (popup.present && popup.kind !== CanopyState.panel) { popup.expanded = false; return; }
                popup.displayedKind = CanopyState.panel;
                popup.expanded = true;
            }
            Connections {
                target: CanopyState
                function onPanelChanged() { canvas.syncPanel(); }
            }
        }
        Timer { interval: 200; running: true; onTriggered: CanopyState.togglePanel("quick", null) }
        Timer {
            interval: 1200
            running: Quickshell.env("CANOPY_SCREENSHOT").length > 0
            onTriggered: canvas.grabToImage(result => {
                result.saveToFile(Quickshell.env("CANOPY_SCREENSHOT"));
                Qt.quit();
            })
        }
    }
}
