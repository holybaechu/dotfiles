import QtQuick
import QtQuick.Shapes
import "Geometry.js" as Geometry

Item {
    id: surface
    property color color: Theme.black
    property real radius: 12
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius
    property color borderColor: "transparent"
    property real borderWidth: 0
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: surface.color
            strokeColor: surface.borderColor
            strokeWidth: surface.borderWidth
            PathSvg { path: Geometry.squircle(0, 0, surface.width, surface.height,
                [surface.topLeftRadius, surface.topRightRadius, surface.bottomRightRadius, surface.bottomLeftRadius]) }
        }
    }
}
