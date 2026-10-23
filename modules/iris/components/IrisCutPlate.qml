import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A plate in a chamfered Design's silhouette (IrisStyle.fieldChamfer): square, with the upper-right and lower-left corners
// cut at 45° by the field's own cut, so a plate laid over a body (a hover, a press, an open piece) follows its outline.
// A ring round a plate (`stroke`, laid inside the outline so a whole-pixel rule stays whole) takes `cutLength` grown by
// how far it stands out, so its cut runs parallel to the plate's.
// Built only while it shows or masks: under a round Design every row carried a hidden Shape and its pen.
Item {
    id: root
    property color color: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 0
    property real cutLength: IrisStyle.chamferCut
    readonly property real cut: Math.min(root.cutLength, Math.min(root.width, root.height) / 2)
    readonly property real s: root.strokeWidth / 2
    Loader {
        anchors.fill: parent
        active: root.visible || root.layer.enabled
        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.color
                strokeColor: root.strokeWidth > 0 ? root.stroke : "transparent"
                strokeWidth: root.strokeWidth
                joinStyle: ShapePath.MiterJoin
                startX: root.s; startY: root.s
                PathLine { x: root.width - root.cut; y: root.s }
                PathLine { x: root.width - root.s; y: root.cut }
                PathLine { x: root.width - root.s; y: root.height - root.s }
                PathLine { x: root.cut; y: root.height - root.s }
                PathLine { x: root.s; y: root.height - root.cut }
                PathLine { x: root.s; y: root.s }
            }
        }
    }
}
