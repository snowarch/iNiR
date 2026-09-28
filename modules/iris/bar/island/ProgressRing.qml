pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Shape {
    id: ring
    property real progress: 0
    property color tint: IrisStyle.text
    property real stroke: Math.max(2, 2.5 * IrisStyle.density)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: IrisStyle.tintFill(ring.tint)
        strokeWidth: ring.stroke
        fillColor: "transparent"
        PathAngleArc {
            centerX: ring.width / 2
            centerY: ring.height / 2
            radiusX: ring.width / 2 - ring.stroke / 2
            radiusY: ring.width / 2 - ring.stroke / 2
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
            radiusX: ring.width / 2 - ring.stroke / 2
            radiusY: ring.width / 2 - ring.stroke / 2
            startAngle: -90
            sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
        }
    }
}
