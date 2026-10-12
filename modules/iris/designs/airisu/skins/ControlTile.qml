import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.control
import "../components"

// AIRISU's control in the Control Center: a box on a printed form. Off, it is the ruled box with its sign and name; on,
// the box is inked solid in the pigment Settings › Control Center › Accent names (the seal, the ink, or each control's
// line colour), its sign and name reversed out; a recording is always the seal, because it is live. Round prints the
// box as a round stamp with its name under it, and a wide control keeps its key at the head of a ruled strip with its
// state set beside it. The pointer brings the crop marks, the keyboard the seal's, a press runs the plate out of
// register, and a control that cannot answer is a dashed box in the third ink. The grid keeps every click and list.
// The library shelf in edit mode draws its tiles with the same box (`bare`: the name is set under it, not inside).
Item {
    id: root
    property Item host
    readonly property var spec: root.host?.skinData ?? ({})
    readonly property var control: root.spec.control ?? null
    readonly property string shape: root.spec.shape ?? "tile"
    readonly property bool lit: root.control?.lit ?? false
    readonly property bool ready: (root.control?.ready ?? true) && (root.host?.enabled ?? true)
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: (root.host?.down ?? false) && root.ready
    readonly property bool keyed: root.host?.visualFocus ?? false
    readonly property real d: Airisu.d
    // How far the plate runs out of register while pressed (IrisButton carries its content by it).
    readonly property int shift: 0

    // The pigment a lit box is inked in, as the plates of this print.
    readonly property color tint: root.control?.tint ?? IrisStyle.accent
    readonly property bool live: (root.control?.moduleId ?? "") === "record"
    readonly property string pigment: root.live || Qt.colorEqual(root.tint, IrisStyle.accent) ? "seal"
        : Qt.colorEqual(root.tint, IrisStyle.text) ? "ink" : "line"
    readonly property color fill: root.pigment === "seal" ? Airisu.seal : root.pigment === "ink" ? Airisu.ink : root.tint
    readonly property color under: root.pigment === "seal" ? Airisu.sealUnder : root.pigment === "ink" ? Airisu.inkUnder
        : ColorUtils.mix(root.tint, Airisu.ground, 0.55) // iris-literal: a line colour's under-plate
    readonly property color reversed: root.pigment === "seal" ? Airisu.inkOnSeal : root.pigment === "ink" ? Airisu.reverse
        : IrisStyle.onTintFor(root.tint)
    readonly property color ink: !root.ready ? Airisu.inkThird : Airisu.ink

    // ── Tile: the box is the whole cell.
    APrint {
        id: box
        visible: root.shape === "tile"
        anchors.fill: parent
        die: "rect"
        pressed: root.pressed
        fill: root.lit && root.ready ? root.fill : "transparent"
        under: root.lit ? root.under : Airisu.inkUnder
        stroke: root.lit && root.ready ? "transparent" : root.ink
        strokeWidth: root.lit && root.ready ? 0 : Airisu.hair
        dashed: !root.ready
        Column {
            anchors.centerIn: parent
            width: parent.width - Airisu.u(2)
            spacing: Math.round(2 * root.d)
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.control?.glyph ?? ""
                fill: root.lit ? 1 : 0
                iconSize: Math.round(21 * root.d)
                color: root.lit && root.ready ? root.reversed : root.ink
            }
            AText {
                visible: IrisControlOptions.labelled && !(root.spec.bare ?? false)
                width: Math.min(implicitWidth, parent.width)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                size: IrisStyle.typeFootnote
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: IrisStyle.typeCaption
                text: root.control?.label ?? ""
                color: root.lit && root.ready ? root.reversed : root.ready ? Airisu.inkSecond : Airisu.inkThird
            }
        }
    }

    // ── Round: a round stamp.
    Item {
        id: stamp
        visible: root.shape === "disc"
        anchors.fill: parent
        readonly property real r: Math.min(width, height) / 2
        readonly property int run: root.pressed ? Airisu.registration : 0
        Shape {
            visible: root.pressed
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.lit ? root.under : "transparent"
                strokeColor: root.lit ? "transparent" : Airisu.inkUnder
                strokeWidth: root.lit ? 0 : Airisu.hair
                PathAngleArc { centerX: stamp.width / 2; centerY: stamp.height / 2; radiusX: stamp.r - Airisu.hair / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
        }
        Item {
            width: stamp.width
            height: stamp.height
            x: stamp.run
            y: stamp.run
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.lit && root.ready ? root.fill : "transparent"
                    strokeColor: root.lit && root.ready ? "transparent" : root.ink
                    strokeWidth: root.lit && root.ready ? 0 : Airisu.hair
                    strokeStyle: root.ready ? ShapePath.SolidLine : ShapePath.DashLine
                    dashPattern: [2, 2]
                    PathAngleArc { centerX: stamp.width / 2; centerY: stamp.height / 2; radiusX: stamp.r - Airisu.hair / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
                }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.control?.glyph ?? ""
                fill: root.lit ? 1 : 0
                iconSize: Math.round(Math.min(21 * root.d, stamp.width * 0.46))
                color: root.lit && root.ready ? root.reversed : root.ink
            }
        }
    }

    // ── Wide: its key at the head of a ruled strip, its name and state beside it.
    Item {
        visible: root.shape === "wide"
        anchors.fill: parent
        readonly property real key: Number(root.spec.key ?? 0)
        APrint {
            anchors.fill: parent
            die: "rect"
            pressed: root.pressed
            stroke: root.ink
            strokeWidth: Airisu.hair
            dashed: !root.ready
        }
        APrint {
            id: wideKey
            x: Math.round((parent.height - height) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.key
            height: parent.key
            die: "rect"
            pressed: root.pressed
            fill: root.lit && root.ready ? root.fill : "transparent"
            under: root.lit ? root.under : Airisu.inkUnder
            stroke: root.lit && root.ready ? "transparent" : root.ink
            strokeWidth: root.lit && root.ready ? 0 : Airisu.hair
            dashed: !root.ready
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.control?.glyph ?? ""
                fill: root.lit ? 1 : 0
                iconSize: Math.round(Math.min(19 * root.d, parent.width * 0.5))
                color: root.lit && root.ready ? root.reversed : root.ink
            }
        }
        Column {
            x: wideKey.x + wideKey.width + Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - (chevron.visible ? chevron.width + Math.round(14 * root.d) : Math.round(10 * root.d))
            spacing: 0
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: root.control?.label ?? ""
                color: root.ready ? Airisu.ink : Airisu.inkThird
            }
            AText {
                width: parent.width
                visible: text.length > 0
                voice: "ruby"
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: IrisStyle.typeCaption
                text: root.ready ? (root.control?.detail ?? "") : Translation.tr("Unavailable")
                color: root.ready ? Airisu.inkSecond : Airisu.inkThird
            }
        }
        // Where its list opens: a chevron, turned down and in the seal's type while the list is open under the grid.
        MaterialSymbol {
            id: chevron
            visible: root.spec.chevron ?? false
            anchors.right: parent.right
            anchors.rightMargin: Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            text: (root.spec.open ?? false) ? "expand_more" : "chevron_right"
            iconSize: Math.round(17 * root.d)
            color: (root.spec.open ?? false) ? Airisu.sealText : Airisu.inkSecond
        }
    }

    // Short marks: they stand in the grid's gutter and stop short of the next box.
    ATombo {
        anchors.fill: parent
        air: Math.max(2, Math.round(2 * root.d))
        length: Math.max(3, Math.round(4 * root.d))
        shown: root.hovered && root.ready && !root.pressed
        focusMarks: root.keyed
    }
}
