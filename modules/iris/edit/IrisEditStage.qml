pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components

// Arranging widgets: the family's paper the desktop recedes onto, and the card's edge. Loaded twice by the desktop
// (shared Background): `under` paints the paper and the card's shadow behind the shrunk desktop, `over` closes the
// card's corners and draws its hairline on top of it.
Item {
    id: root

    property string side: "under"
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    property string wallpaper: ""

    readonly property real d: IrisStyle.density
    readonly property real p: Math.max(0, Math.min(1, root.card.p))
    readonly property real cardX: root.card.x
    readonly property real cardY: root.card.y
    readonly property real cardW: root.width * root.card.s
    readonly property real cardH: root.height * root.card.s
    readonly property bool cut: IrisStyle.fieldChamfer
    readonly property real cornerSize: (root.cut ? IrisStyle.chamferCut : Math.round(22 * root.d)) * root.p
    readonly property color paper: IrisStyle.paper

    // The paper: ink with the family's dot grid, tiled from one cell so nothing is painted per frame.
    Rectangle {
        visible: root.side === "under"
        anchors.fill: parent
        color: root.paper
        // Until the card's still is decoded, the real wallpaper keeps showing round the card instead of a dark card.
        opacity: root.wallpaper.length > 0 && still.status !== Image.Ready ? 0 : Math.min(1, root.p * 1.6)

        Image {
            readonly property real pitch: Math.max(4, Math.round(8 * root.d))
            readonly property color ink: IrisStyle.paperDot
            anchors.fill: parent
            fillMode: Image.Tile
            smooth: false
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='" + pitch + "' height='" + pitch
                + "'><circle cx='" + pitch / 2 + "' cy='" + pitch / 2 + "' r='" + Math.max(0.75, root.d)
                + "' fill='rgb(" + Math.round(ink.r * 255) + "," + Math.round(ink.g * 255) + "," + Math.round(ink.b * 255)
                + ")' fill-opacity='" + ink.a.toFixed(3) + "'/></svg>"
        }
    }

    IrisBodyShadow {
        visible: root.side === "under"
        x: root.cardX
        y: root.cardY + 10 * root.d * root.p
        width: root.cardW
        height: root.cardH
        radius: root.cut ? 0 : root.cornerSize
        blur: 42 * root.d
        spread: -8 * root.d
        color: ColorUtils.applyAlpha(IrisStyle.shadow, IrisStyle.shadow.a * root.p)
    }

    Image {
        id: still
        visible: root.side === "under" && root.wallpaper.length > 0
        x: root.cardX
        y: root.cardY
        width: root.cardW
        height: root.cardH
        source: root.wallpaper
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    // The card's corners, closed with paper (rounded in iRiS, the 45 deg cut in AIRISU).
    Shape {
        visible: root.side === "over" && root.cornerSize > 0.5
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: -1
            fillColor: root.paper
            readonly property real r: root.cornerSize
            readonly property real l: root.cardX
            readonly property real t: root.cardY
            readonly property real rr: root.cardX + root.cardW
            readonly property real b: root.cardY + root.cardH
            PathSvg {
                path: {
                    const r = parent.r, l = parent.l, t = parent.t, rr = parent.rr, b = parent.b
                    if (root.cut)
                        return `M ${rr - r} ${t} L ${rr} ${t} L ${rr} ${t + r} Z M ${l} ${b - r} L ${l + r} ${b} L ${l} ${b} Z`
                    const k = 0.5523 * r
                    return `M ${l} ${t} L ${l + r} ${t} C ${l + r - k} ${t} ${l} ${t + r - k} ${l} ${t + r} Z`
                        + ` M ${rr} ${t} L ${rr} ${t + r} C ${rr} ${t + r - k} ${rr - r + k} ${t} ${rr - r} ${t} Z`
                        + ` M ${rr} ${b} L ${rr - r} ${b} C ${rr - r + k} ${b} ${rr} ${b - r + k} ${rr} ${b - r} Z`
                        + ` M ${l} ${b} L ${l} ${b - r} C ${l} ${b - r + k} ${l + r - k} ${b} ${l + r} ${b} Z`
                }
            }
        }
    }

    Rectangle {
        visible: root.side === "over" && !root.cut
        x: root.cardX
        y: root.cardY
        width: root.cardW
        height: root.cardH
        radius: root.cornerSize
        color: "transparent"
        border.width: IrisStyle.devicePx
        border.color: ColorUtils.applyAlpha(IrisStyle.hairline, IrisStyle.hairline.a * root.p)
        antialiasing: true
    }
}
