pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Arranging widgets under Material: the surface the desktop recedes onto, and the card's edge. Loaded three times by
// the desktop (shared Background): `under` lays the surface and the card's shadow behind the shrunk desktop, `over` draws
// the card's outline on top and gives the desktop `cardMask`, the card's shape at full size, to cut its corners, and
// `inside` (shrunk with the desktop, under its widgets) draws where the bar and the dock rest.
Item {
    id: root
    property string side: "under"
    property string output: ""
    property var room: null
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    property bool waiting: false
    readonly property real p: Math.max(0, Math.min(1, root.card.p))
    readonly property real cardX: root.card.x
    readonly property real cardY: root.card.y
    readonly property real cardW: root.width * root.card.s
    readonly property real cardH: root.height * root.card.s
    readonly property real cornerSize: Appearance.rounding.large * root.p

    // The surface: Material's base layer with a quiet dot lattice, tiled from one cell so nothing repaints per frame.
    Rectangle {
        visible: root.side === "under"
        anchors.fill: parent
        color: Appearance.colors.colLayer0
        opacity: root.waiting ? 0 : Math.min(1, root.p * 1.6)
        Image {
            readonly property int pitch: 12
            readonly property color ink: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.12)
            anchors.fill: parent
            fillMode: Image.Tile
            smooth: false
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='" + pitch + "' height='" + pitch
                + "'><circle cx='" + pitch / 2 + "' cy='" + pitch / 2 + "' r='1' fill='rgb(" + Math.round(ink.r * 255) + ","
                + Math.round(ink.g * 255) + "," + Math.round(ink.b * 255) + ")' fill-opacity='" + ink.a.toFixed(3) + "'/></svg>"
        }
    }
    RectangularShadow {
        visible: root.side === "under"
        x: root.cardX
        y: root.cardY + 8 * root.p
        width: root.cardW
        height: root.cardH
        radius: root.cornerSize
        blur: 36
        spread: -6
        color: ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.55 * root.p)
    }
    // The card's shape at the desktop's own size (it is shrunk with it).
    readonly property Item cardMask: root.side === "over" ? mask : null
    Item {
        id: mask
        visible: false
        width: root.width
        height: root.height
        layer.enabled: root.side === "over"
        Rectangle {
            anchors.fill: parent
            radius: root.cornerSize / Math.max(0.2, root.card.s)
            antialiasing: true
        }
    }
    Rectangle {
        visible: root.side === "over"
        x: root.cardX
        y: root.cardY
        width: root.cardW
        height: root.cardH
        radius: root.cornerSize
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, root.p)
        antialiasing: true
    }

    // ── inside: the bar and the dock where they rest, in desktop px ──
    readonly property real hair: 1 / Math.max(0.2, root.card.s)
    readonly property var lit: {
        const out = {}
        if (root.side !== "inside" || DesktopArrange.dragOutput !== root.output || DesktopArrange.phase === "idle")
            return out
        for (const line of DesktopArrange.slots)
            for (const id of (line?.ids ?? [])) out[id] = true
        for (const id in DesktopArrange.matched) out[id] = true
        return out
    }
    Repeater {
        model: root.side === "inside" ? DesktopArrange.bodiesOf(root.output) : []
        delegate: Rectangle {
            id: body
            required property var modelData
            readonly property bool hot: Boolean(root.lit[body.modelData.id])
            x: body.modelData.x
            y: body.modelData.y
            width: body.modelData.w
            height: body.modelData.h
            radius: body.modelData.radius ?? 0
            color: Appearance.colors.colLayer0
            border.width: (body.hot ? 2 : 1) * root.hair
            border.color: body.hot ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
            Behavior on border.color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
            StyledText {
                anchors.centerIn: parent
                text: body.modelData.name ?? ""
                visible: implicitWidth + 16 * root.hair <= body.width && implicitHeight + 4 * root.hair <= body.height
                color: body.hot ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller * root.hair
                font.weight: Font.Medium
            }
        }
    }
}
