import QtQuick
import QtQuick.Controls

Slider {
    id: control
    property string label: ""
    signal committed(real level)
    from: 0
    to: 100
    stepSize: 1
    implicitHeight: 32
    leftPadding: 10
    rightPadding: 10
    hoverEnabled: true
    Accessible.name: label
    opacity: enabled ? 1 : 0.5
    onMoved: { if (!pressed) committed(value); }
    onPressedChanged: { if (!pressed) committed(value); }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) value = from;
        else if (event.key === Qt.Key_End) value = to;
        else if (event.key === Qt.Key_PageUp) value = Math.min(to, value + 10);
        else if (event.key === Qt.Key_PageDown) value = Math.max(from, value - 10);
        else return;
        moved(); event.accepted = true;
    }
    background: Item {
        x: 0
        y: 0
        width: control.width
        height: control.height
        readonly property real positionX: 12 + (width - 24) * control.visualPosition
        CanopySurface {
            x: 0; y: 8
            width: Math.max(0, parent.positionX - 8); height: 16
            visible: control.visualPosition > 0
            color: Theme.accent
            radius: 8
            topRightRadius: 2; bottomRightRadius: 2
        }
        CanopySurface {
            x: parent.positionX + 8; y: 8
            width: Math.max(0, parent.width - x); height: 16
            visible: control.visualPosition < 1
            color: Theme.raised
            radius: 8
            topLeftRadius: 2; bottomLeftRadius: 2
        }
    }
    handle: Rectangle {
        x: 10 + (control.width - 24) * control.visualPosition
        y: (control.height - height) / 2
        width: 4
        height: control.hovered || control.pressed ? 28 : 24
        radius: 2
        color: Theme.accent
        Rectangle {
            anchors.centerIn: parent
            width: 22; height: 30; radius: 8
            visible: control.visualFocus
            color: "transparent"
            border.color: Theme.accent
            border.width: 2
        }
        Behavior on height { NumberAnimation { duration: 100 } }
    }
}
