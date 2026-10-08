pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// An Item, not the Shape itself: a Shape takes its implicit size from its paths, so in a layout the radius fed the
// size it was computed from (a binding loop on radiusX).
Item {
    id: ring
    property real progress: 0
    property color tint: IrisStyle.text
    property real stroke: Math.max(2, 2.5 * IrisStyle.density)
    readonly property real radius: Math.max(0, Math.min(ring.width, ring.height) / 2 - ring.stroke / 2)

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.tintFill(ring.tint)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.tint
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: ring.radius
                radiusY: ring.radius
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
            }
        }
    }
}
