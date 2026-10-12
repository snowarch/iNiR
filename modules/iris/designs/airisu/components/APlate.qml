import QtQuick
import QtQuick.Shapes

// A plate of AIRISU's bar: lacquer, cut where the board cuts it. `cuts` names the corners taken off at 45° by
// `Airisu.cut` ("br" lower right, "bl" lower left, "tr", "tl"); `taper` draws the centre plate, its top inset by the
// cut on both sides, so it reads as a wedge hanging from the edge. Children sit on top.
Item {
    id: root
    property var cuts: []
    property bool taper: false
    property color colour: Airisu.lacquer
    readonly property real c: Math.min(Airisu.cut, height / 3)
    function has(corner: string): bool { return root.cuts.indexOf(corner) >= 0 }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.colour
            strokeColor: "transparent"
            startX: root.taper || root.has("tl") ? root.c : 0; startY: 0
            PathLine { x: root.width - (root.taper || root.has("tr") ? root.c : 0); y: 0 }
            PathLine { x: root.width; y: root.has("tr") ? root.c : root.taper ? root.height : 0 }
            PathLine { x: root.width; y: root.height - (root.has("br") ? root.c : 0) }
            PathLine { x: root.width - (root.has("br") ? root.c : 0); y: root.height }
            PathLine { x: root.has("bl") ? root.c : 0; y: root.height }
            PathLine { x: 0; y: root.height - (root.has("bl") ? root.c : 0) }
            PathLine { x: 0; y: root.has("tl") ? root.c : root.taper ? root.height : 0 }
            PathLine { x: root.taper || root.has("tl") ? root.c : 0; y: 0 }
        }
    }
}
