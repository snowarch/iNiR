pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.widgets.shapes
import "shapes/shapes/corner-rounding.js" as CornerRounding
import "shapes/material-shapes.js" as MaterialShapes
import "shapes/shapes/point.js" as Point
import "shapes/shapes/rounded-polygon.js" as RoundedPolygon

// A single aspect-aware cookie polygon. The source polygon is generated at
// the host aspect ratio, so ShapeCanvas fits it without stretching the lobes.
ShapeCanvas {
    id: root

    property string shape: "cookie12" // pill | cookie6 | cookie9 | cookie12
    // A face is always sized by its host; inherited polygon bounds must not
    // feed back into anchored width/height while aspect regenerates the shape.
    implicitWidth: 0
    implicitHeight: 0
    readonly property real aspect: Math.max(0.2, width / Math.max(height, 1))
    function _polygon() {
        if (root.shape === "pill") {
            return RoundedPolygon.RoundedPolygon.rectangle(
                root.aspect, 1, new CornerRounding.CornerRounding(0.5))
        }

        const source = root.shape === "cookie6" ? MaterialShapes.getCookie6Sided()
            : root.shape === "cookie9" ? MaterialShapes.getCookie9Sided()
            : MaterialShapes.getCookie12Sided()
        return source.transformed((x, y) => new Point.Point(x * root.aspect, y))
    }

    polygonIsNormalized: false
    fitToCanvas: true
    roundedPolygon: root._polygon()

    // No animation override: ShapeCanvas already honours reduced motion, and its
    // default is the expressive overshoot. Overriding it with elementResize
    // flattened the pill → cookie morph into a plain ease.
}
