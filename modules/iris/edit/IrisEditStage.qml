pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components

// Arranging widgets: the family's paper the desktop recedes onto, and the card's edge. Loaded twice by the desktop
// (shared Background): `under` paints the paper and the card's shadow behind the shrunk desktop, `over` draws the
// card's hairline on top of it and gives the desktop `cardMask`, the card's shape at full size, to cut its corners.
Item {
    id: root

    property string side: "under"
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    // The card's own still is still decoding: the real wallpaper keeps showing round the card meanwhile.
    property bool waiting: false

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
        opacity: root.waiting ? 0 : Math.min(1, root.p * 1.6)

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

    // The card's shape at the desktop's own size (it is shrunk with it): rounded in iRiS, the 45 deg cut in AIRISU.
    readonly property Item cardMask: root.side === "over" ? mask : null
    Item {
        id: mask
        visible: false
        width: root.width
        height: root.height
        layer.enabled: root.side === "over"
        readonly property real r: root.cornerSize / Math.max(0.2, root.card.s)
        Rectangle {
            anchors.fill: parent
            visible: !root.cut
            radius: mask.r
            antialiasing: true
        }
        Shape {
            anchors.fill: parent
            visible: root.cut
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: "white"
                PathSvg {
                    path: {
                        const r = mask.r, w = mask.width, h = mask.height
                        return `M 0 0 L ${w - r} 0 L ${w} ${r} L ${w} ${h} L ${r} ${h} L 0 ${h - r} Z`
                    }
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
