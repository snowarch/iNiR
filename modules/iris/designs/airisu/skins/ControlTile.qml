import QtQuick
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.control
import "../components"

// AIRISU's control in the Control Center: a key (AKey) of the body's next coat, on or off. What says it is on is the
// seal box (ASeal) in its corner, stamped in the pigment Settings › Control Center › Accent names (the accent, or a tame
// for Ink); a recording always stamps the accent, because it is live. Lit keys never turn into plates of shu: a grid of
// them would be the 2 parts of seal spent ten times over. The sign and the box stand at the head and the name at the
// foot, as a label is set on a part. Round is cut as a key too, its box at its foot like the logo's square; a wide control
// keeps its key at the head of the strip, stamped in the seal while on, with its name and state beside it. The grid keeps
// every click and list; the library shelf in edit mode draws its tiles with the same key (`bare`: the name is set under
// it, not inside).
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
    readonly property int run: root.shift

    readonly property color tint: root.control?.tint ?? IrisStyle.accent
    readonly property bool live: (root.control?.moduleId ?? "") === "record"
    readonly property color lacquer: root.live || Qt.colorEqual(root.tint, IrisStyle.accent) ? Airisu.seal
        // Ink's quiet lacquer is tame itself: its coat sat a hair from the off key and an "on" read as off.
        : Qt.colorEqual(root.tint, IrisStyle.text) ? Airisu.pigment("system")
        : Airisu.seal
    // The colour the key is: the body's next coat, half into the stock when it cannot answer.
    readonly property color face: !root.ready ? Airisu.dim : Airisu.groundRaised
    readonly property color ink: !root.ready ? Airisu.inkThird : Airisu.inkOn(root.face)
    readonly property color inkSecond: !root.ready ? Airisu.inkThird : Airisu.inkSecond
    readonly property int shift: root.pressed ? Airisu.offset : 0

    // ── Tile: the key is the whole cell.
    AKey {
        visible: root.shape === "tile"
        anchors.fill: parent
        lacquer: root.face
        hovered: root.hovered
        pressed: root.pressed
        keyed: root.keyed
        available: root.ready
        readonly property int pad: Airisu.u(2.5)
        MaterialSymbol {
            x: parent.pad + root.run
            y: parent.pad + root.run
            text: root.control?.glyph ?? ""
            fill: root.lit ? 1 : 0
            iconSize: Math.round(21 * root.d)
            color: root.ink
        }
        AText {
            visible: IrisControlOptions.labelled && !(root.spec.bare ?? false)
            x: parent.pad + root.run
            y: parent.height - parent.pad - height + root.run
            width: parent.width - 2 * parent.pad
            size: IrisStyle.typeFootnote
            font.weight: Font.Bold
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: IrisStyle.typeCaption
            text: root.control?.label ?? ""
            color: root.lit ? root.ink : root.inkSecond
        }
        ASeal {
            id: tileSeal
            x: parent.width - parent.pad - width + root.run
            y: parent.pad + Math.round(4 * root.d) + root.run
            stamped: root.lit
            seal: root.lacquer
            available: root.ready
        }
    }

    // ── Round: the person's disc is cut by AIRISU's die like every key (a grid of grey discs is any shell's), its
    // seal box at its foot like the logo's square.
    Item {
        visible: root.shape === "disc"
        readonly property real side: Math.min(parent.width, parent.height)
        width: side
        height: side
        anchors.centerIn: parent
        AKey {
            anchors.fill: parent
            lacquer: root.face
            hovered: root.hovered
            pressed: root.pressed
            keyed: root.keyed
            available: root.ready
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
        ASeal {
            width: Math.max(6, Math.round(parent.side * 0.24))
            height: width
            x: parent.width - width + Math.round(width * 0.25) + root.run
            y: parent.height - height + Math.round(width * 0.25) + root.run
            visible: root.lit
            stamped: root.lit
            seal: root.lacquer
            available: root.ready
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
