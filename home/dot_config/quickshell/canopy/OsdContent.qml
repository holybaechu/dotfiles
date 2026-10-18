import QtQuick
import QtQuick.Layouts

CanopySurface {
    id: root
    implicitWidth: 280
    implicitHeight: 76
    color: Theme.surface
    radius: 24
    borderColor: Qt.alpha(Theme.border, 0.2)
    borderWidth: 1
    opacity: OsdState.shown ? 1 : 0
    readonly property bool present: OsdState.shown || opacity > 0
    Behavior on opacity {
        enabled: !Theme.reducedMotion
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16
        CanopyIcon {
            name: OsdState.kind === "brightness" ? "sun" : OsdState.muted ? "volume-x"
                : OsdState.value > 50 ? "volume-2" : OsdState.value > 0 ? "volume-1" : "volume"
            color: OsdState.muted ? Theme.muted : Theme.accent
            size: 24
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: OsdState.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                Text {
                    text: OsdState.muted ? "Muted" : OsdState.value + "%"
                    color: Theme.muted
                    font.family: Theme.utilityFont
                    font.pixelSize: 12
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Theme.raised
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, OsdState.muted ? 0 : OsdState.value / 100))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                }
            }
        }
    }
}
