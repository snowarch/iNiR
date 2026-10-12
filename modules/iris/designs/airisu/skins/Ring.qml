import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's progress ring (board Components): a needle gauge's 270° arc, open at the bottom, square ends; under 15 %
// it turns kerria amber, the only warning colour.
Item {
    id: root
    property Item host
    readonly property real progress: Math.max(0, Math.min(1, root.host?.progress ?? 0))
    readonly property real stroke: root.host?.stroke ?? 2
    readonly property real radius: Math.max(0, Math.min(width, height) / 2 - root.stroke / 2)
    readonly property color tint: root.progress < 0.15 ? Airisu.amber : (root.host?.tint ?? Airisu.gofun)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Airisu.socket
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.radius; radiusY: root.radius; startAngle: 135; sweepAngle: 270 }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.radius; radiusY: root.radius; startAngle: 135; sweepAngle: 270 * root.progress }
        }
    }
}
