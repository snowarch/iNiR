pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions

// Arranging widgets under Material: the surface the desktop recedes onto, and the card's edge. Loaded twice by the
// desktop (shared Background): `under` lays the surface and the card's shadow behind the shrunk desktop, `over` draws
// the card's outline on top and gives the desktop `cardMask`, the card's shape at full size, to cut its corners.
Item {
    id: root
    property string side: "under"
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
}
