import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style
import "../components"

// AIRISU's switch: a machine's rocker printed as two boxes in one ruled die, O and I, the marks every appliance switch
// carries, so it reads in any language. The box taken holds a plate: off, a step of ink under the O; on, the seal under
// the I (what is live). The plate stops in its box (a detent), it never springs. The pointer brings the die's crop marks,
// the keyboard brings them in shu, a press drops the plate in register. One that cannot be taken is ruled dashed, its
// plate sunk. On a chosen row's plate it takes that plate's inks. The host keeps the toggle, the keys and the name.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.pressed ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property bool keyed: root.host?.keyed ?? false
    readonly property bool reversed: root.host?.reversed ?? false
    readonly property int inset: Math.max(2, Math.round(2 * Airisu.d))
    readonly property int run: root.pressed && root.available ? Airisu.hair : 0
    readonly property int cut: Math.max(2, Math.round(root.height / 4))
    readonly property color rule: root.reversed ? IrisStyle.selectionDetail : Airisu.inkThird
    readonly property color plate: root.on ? (root.reversed ? IrisStyle.selectionLabel : Airisu.seal)
        : (root.reversed ? IrisStyle.selectionDetail : Airisu.cell)
    readonly property color plateInk: root.on ? (root.reversed ? IrisStyle.selectionFill : Airisu.inkOnSeal)
        : (root.reversed ? IrisStyle.selectionLabel : Airisu.ink)
    readonly property color idleInk: root.reversed ? IrisStyle.selectionDetail : Airisu.inkThird
    readonly property real cellWidth: (root.width - 2 * root.inset) / 2

    ADie {
        anchors.fill: parent
        kind: "chamfer"
        cut: root.cut
        stroke: root.rule
        strokeWidth: Airisu.hair
        dashed: !root.available
    }
    // The plate under the box taken, and the deeper pull under it that a press shows.
    ALacquer {
        visible: root.available && root.run > 0
        x: plate.x - root.run
        y: plate.y - root.run
        width: plate.width
        height: plate.height
        cut: plate.cut
        lacquer: Airisu.underPlate(root.plate)
    }
    ALacquer {
        id: plate
        width: Math.round(root.cellWidth)
        height: root.height - 2 * root.inset
        x: (root.on ? root.width - root.inset - width : root.inset) + root.run
        y: root.inset + root.run
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        cut: Math.max(2, root.cut - root.inset)
        lacquer: root.available ? root.plate : Airisu.dim
    }
    // O and I, drawn on the module: a compass ring and a bar of the same stroke.
    Shape {
        id: marks
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real glyph: Math.round(root.height * 0.36)
        readonly property real stroke: Math.max(1.5, Math.round(1.6 * Airisu.d * 2) / 2)
        readonly property real offX: root.inset + root.cellWidth / 2
        readonly property real onX: root.width - root.inset - root.cellWidth / 2
        readonly property real cy: root.height / 2
        ShapePath {
            fillColor: "transparent"
            strokeColor: !root.available ? root.idleInk : root.on ? root.idleInk : root.plateInk
            strokeWidth: marks.stroke
            PathAngleArc {
                centerX: marks.offX + (root.on ? 0 : root.run)
                centerY: marks.cy + (root.on ? 0 : root.run)
                radiusX: marks.glyph / 2
                radiusY: marks.glyph / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
        ShapePath {
            fillColor: "transparent"
            strokeColor: !root.available ? root.idleInk : root.on ? root.plateInk : root.idleInk
            strokeWidth: marks.stroke
            capStyle: ShapePath.FlatCap
            startX: marks.onX + (root.on ? root.run : 0)
            startY: marks.cy - marks.glyph / 2 + (root.on ? root.run : 0)
            PathLine { relativeX: 0; relativeY: marks.glyph }
        }
    }
    AMarks {
        anchors.fill: parent
        shown: (root.available && root.hovered) || root.keyed
        color: root.keyed ? Airisu.seal : Airisu.marks
    }
}
