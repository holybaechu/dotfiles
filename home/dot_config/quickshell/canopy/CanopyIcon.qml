import QtQuick
import "IconData.js" as IconData

Item {
    id: icon
    property string name: "app-window"
    property color color: Theme.text
    property int size: 18
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.fill: parent
        sourceSize.width: Math.ceil(icon.width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(icon.height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        source: {
            const data = IconData.icons[icon.name] || IconData.icons["app-window"];
            return "data:image/svg+xml;utf8," + encodeURIComponent(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + (data.width || 24) + ' ' + (data.height || 24) + '">'
                + data.body.replace(/currentColor/g, icon.color.toString()) + '</svg>');
        }
    }
}
