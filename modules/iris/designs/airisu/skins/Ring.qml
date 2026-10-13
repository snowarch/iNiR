import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's progress ring: a gauge (計器), not a ring. A 270° groove sunk into the body, open at the foot like a dial
// with a needle, and the host's tint laid along it from the lower left, clockwise, as far as the progress goes, cut
// square; at its end a needle of ink crosses the groove, so the reading is a point on a scale and not only a length. The
// band's width follows the host's stroke.
Item {
    id: root
    property Item host
    readonly property real progress: Math.max(0, Math.min(1, root.host?.progress ?? 0))
    readonly property real band: Math.max(3, Math.round((root.host?.stroke ?? 2.5) + Airisu.d))
    readonly property real r: Math.max(0, Math.min(width, height) / 2 - root.band / 2)
    readonly property color tint: root.host?.tint ?? Airisu.seal
    readonly property real from: 135
    readonly property real sweep: 270
    readonly property real end: (root.from + root.sweep * root.progress) * Math.PI / 180
    readonly property real cx: root.width / 2
    readonly property real cy: root.height / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Airisu.slot
            strokeWidth: root.band
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.r; radiusY: root.r; startAngle: root.from; sweepAngle: root.sweep }
        }
        ShapePath {
            strokeColor: root.tint
            strokeWidth: root.band
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathAngleArc { centerX: root.cx; centerY: root.cy; radiusX: root.r; radiusY: root.r; startAngle: root.from; sweepAngle: root.sweep * root.progress }
        }
        // The needle: across the groove and a hair past it on both sides.
        ShapePath {
            strokeColor: Airisu.ink
            strokeWidth: Math.max(1.5, Airisu.hair * 1.5)
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            startX: root.cx + Math.cos(root.end) * (root.r - root.band / 2 - Airisu.hair)
            startY: root.cy + Math.sin(root.end) * (root.r - root.band / 2 - Airisu.hair)
            PathLine {
                x: root.cx + Math.cos(root.end) * (root.r + root.band / 2 + Airisu.hair)
                y: root.cy + Math.sin(root.end) * (root.r + root.band / 2 + Airisu.hair)
            }
        }
    }
}
