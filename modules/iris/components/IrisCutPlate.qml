import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A plate in a chamfered Design's silhouette (IrisStyle.fieldChamfer): square, with the upper-right and lower-left corners
// cut at 45° by the field's own cut, so a plate laid over a body (a hover, a press, an open piece) follows its outline.
Shape {
    id: root
    property color color: "transparent"
    readonly property real cut: Math.min(IrisStyle.chamferCut, Math.min(root.width, root.height) / 2)
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0
        startX: 0; startY: 0
        PathLine { x: root.width - root.cut; y: 0 }
        PathLine { x: root.width; y: root.cut }
        PathLine { x: root.width; y: root.height }
        PathLine { x: root.cut; y: root.height }
        PathLine { x: 0; y: root.height - root.cut }
        PathLine { x: 0; y: 0 }
    }
}
