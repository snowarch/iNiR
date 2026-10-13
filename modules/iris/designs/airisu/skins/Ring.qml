import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's progress ring: a groove sunk into the body and the host's tint laid in it from the top, clockwise, as far as
// the progress goes, cut square at its ends. The band's width follows the host's stroke.
Item {
    id: root
    property Item host
    readonly property real progress: Math.max(0, Math.min(1, root.host?.progress ?? 0))
    readonly property real band: Math.max(3, Math.round((root.host?.stroke ?? 2.5) + Airisu.d))
    readonly property real r: Math.max(0, Math.min(width, height) / 2 - root.band / 2)
    readonly property color tint: root.host?.tint ?? Airisu.seal

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Airisu.slot
            strokeWidth: root.band
            fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: root.band
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.r; radiusY: root.r; startAngle: -90; sweepAngle: 360 * root.progress }
        }
    }
}
