import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool accent: false
    property bool iconOnly: false
    property string iconName: ""
    property int iconSize: 18
    property real radius: 12
    property color textColor: accent || checked ? Theme.black : Theme.text
    property string hint: text
    implicitHeight: 32
    implicitWidth: Math.max(32, contentItem.implicitWidth + 22)
    hoverEnabled: true
    font.family: iconOnly ? Theme.icons : Theme.font
    font.pixelSize: iconOnly ? 17 : 12
    Accessible.name: hint
    ToolTip.visible: hovered && hint.length > 0
    ToolTip.text: hint
    contentItem: Item {
        implicitWidth: control.iconName ? control.iconSize : caption.implicitWidth
        implicitHeight: control.iconName ? control.iconSize : caption.implicitHeight
        CanopyIcon {
            anchors.centerIn: parent
            visible: control.iconName.length > 0
            name: control.iconName || "app-window"
            size: control.iconSize
            color: control.textColor
            opacity: control.enabled ? 1 : 0.45
        }
        Text {
            id: caption
            anchors.fill: parent
            visible: !control.iconName
            text: control.text
            font: control.font
            color: control.textColor
            opacity: control.enabled ? 1 : 0.45
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
    background: CanopySurface {
        radius: control.radius
        color: control.accent || control.checked ? Theme.accent
             : control.down ? Theme.selection : control.hovered ? Theme.raised : "transparent"
        borderWidth: control.visualFocus ? 1 : 0
        borderColor: Theme.accent
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
