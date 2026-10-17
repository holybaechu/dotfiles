import QtQuick
import QtQuick.Shapes
import "Geometry.js" as Geometry

Item {
    id: island
    property string edge: "center"
    Shape {
        x: -16
        width: parent.width + 32
        height: parent.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Theme.black
            strokeWidth: 0
            PathSvg { path: Geometry.island(island.width + 32, island.height, island.edge) }
        }
    }
}
