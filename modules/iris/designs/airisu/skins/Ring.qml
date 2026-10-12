import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's progress ring (SYSTEM.md §6): a postmark (消印). Two concentric rules with a band between them, and the
// progress is the band inked from the top, clockwise, in the host's tint. The band's width follows the host's stroke.
Item {
    id: root
    property Item host
    readonly property real progress: Math.max(0, Math.min(1, root.host?.progress ?? 0))
    readonly property real band: Math.max(3, Math.round((root.host?.stroke ?? 2.5) + Airisu.d))
    readonly property real outer: Math.max(0, Math.min(width, height) / 2 - Airisu.hair / 2)
    readonly property real inner: Math.max(0, root.outer - root.band)
    readonly property color tint: root.host?.tint ?? Airisu.ink

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Airisu.inkThird
            strokeWidth: Airisu.hair
            fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.outer; radiusY: root.outer; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: Airisu.inkThird
            strokeWidth: Airisu.hair
            fillColor: "transparent"
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: root.inner; radiusY: root.inner; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            id: progressPath
            strokeColor: root.tint
            strokeWidth: root.band
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            readonly property real r: (root.outer + root.inner) / 2
            PathAngleArc { centerX: root.width / 2; centerY: root.height / 2; radiusX: progressPath.r; radiusY: progressPath.r; startAngle: -90; sweepAngle: 360 * root.progress }
        }
    }
}
