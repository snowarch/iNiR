import QtQuick
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.control
import "../components"

// AIRISU's control in the Control Center: a key (AKey). Off, it is the body's next coat with its sign and name; turned
// on, the lacquer is laid across it at 45° in the pigment Settings › Control Center › Accent names (the accent, a
// tame for Ink, or each control's line colour), its sign and name cut out in that lacquer's ink; a recording is
// always the accent, because it is live. Round keeps the person's disc; a wide control keeps its key at the head of the
// strip, sunk into it while off, with its name and state beside it. The grid keeps every click and list; the library
// shelf in edit mode draws its tiles with the same key (`bare`: the name is set under it, not inside).
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
    readonly property int shift: 0
    readonly property int run: root.pressed ? Airisu.hair : 0

    readonly property color tint: root.control?.tint ?? IrisStyle.accent
    readonly property bool live: (root.control?.moduleId ?? "") === "record"
    readonly property color lacquer: root.live || Qt.colorEqual(root.tint, IrisStyle.accent) ? Airisu.seal
        // Ink's quiet lacquer is tame itself: its coat sat a hair from the off key and an "on" read as off.
        : Qt.colorEqual(root.tint, IrisStyle.text) ? Airisu.pigment("system")
        : Airisu.seal
    // The colour the key is now: its lacquer when on, the body's next coat when off, half into the stock when it cannot answer.
    readonly property color face: !root.ready ? Airisu.dim : root.lit ? root.lacquer : Airisu.groundRaised
    readonly property color ink: !root.ready ? Airisu.inkThird : Airisu.inkOn(root.face)
    readonly property color inkSecond: !root.ready ? Airisu.inkThird : root.lit ? Airisu.inkSecondOn(root.face) : Airisu.inkSecond

    // ── Tile: the key is the whole cell.
    AKey {
        visible: root.shape === "tile"
        anchors.fill: parent
        lacquer: root.face
        hovered: root.hovered
        pressed: root.pressed
        keyed: root.keyed
        available: root.ready
        Column {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.run
            anchors.verticalCenterOffset: root.run
            width: parent.width - Airisu.u(2)
            spacing: Math.round(2 * root.d)
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.control?.glyph ?? ""
                fill: root.lit ? 1 : 0
                iconSize: Math.round(21 * root.d)
                color: root.ink
            }
            AText {
                visible: IrisControlOptions.labelled && !(root.spec.bare ?? false)
                width: Math.min(implicitWidth, parent.width)
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                size: IrisStyle.typeFootnote
                font.weight: root.lit ? Font.Bold : Font.Medium
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: IrisStyle.typeCaption
                text: root.control?.label ?? ""
                color: root.lit ? root.ink : root.inkSecond
            }
        }
    }

    // ── Round: the person's disc, coloured the same way; the pointer steps it, a press deepens it.
    Rectangle {
        visible: root.shape === "disc"
        readonly property real side: Math.min(parent.width, parent.height)
        width: side
        height: side
        anchors.centerIn: parent
        radius: side / 2
        color: root.ready && (root.hovered || root.pressed)
            ? Airisu.step(root.face, root.pressed ? Airisu.pressStep : Airisu.hoverStep) : root.face
        Behavior on color { enabled: Airisu.moving; ColorAnimation { duration: Airisu.snap } }
        border.width: root.keyed ? Airisu.strong : 0
        border.color: root.lit ? root.ink : Airisu.seal
        MaterialSymbol {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.run
            anchors.verticalCenterOffset: root.run
            text: root.control?.glyph ?? ""
            fill: root.lit ? 1 : 0
            iconSize: Math.round(Math.min(21 * root.d, parent.width * 0.46))
            color: root.ink
        }
    }

    // ── Wide: its key at the head of the strip, its name and state beside it.
    Item {
        visible: root.shape === "wide"
        anchors.fill: parent
        readonly property real key: Number(root.spec.key ?? 0)
        AKey {
            anchors.fill: parent
            lacquer: root.ready ? Airisu.groundRaised : Airisu.dim
            hovered: root.hovered
            pressed: root.pressed
            keyed: root.keyed
            available: root.ready
        }
        ALacquer {
            id: wideKey
            x: Math.round((parent.height - height) / 2) + root.run
            y: Math.round((parent.height - height) / 2) + root.run
            width: parent.key
            height: parent.key
            cut: Airisu.cutFor(height)
            // Off, the key is sunk into the strip; on, its lacquer is laid in it.
            lacquer: root.lit && root.ready ? root.lacquer : Airisu.slot
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.control?.glyph ?? ""
                fill: root.lit ? 1 : 0
                iconSize: Math.round(Math.min(19 * root.d, parent.width * 0.5))
                color: root.lit && root.ready ? Airisu.inkOn(root.lacquer) : root.ready ? Airisu.ink : Airisu.inkThird
            }
        }
        Column {
            x: wideKey.x + wideKey.width + Math.round(10 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.run
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
                size: IrisStyle.typeFootnote
                font.weight: Font.Medium
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: IrisStyle.typeCaption
                text: root.ready ? (root.control?.detail ?? "") : Translation.tr("Unavailable")
                color: root.ready ? Airisu.inkSecond : Airisu.inkThird
            }
        }
        // Where its list opens: a chevron, turned down and in the accent while the list is open under the grid.
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
}
