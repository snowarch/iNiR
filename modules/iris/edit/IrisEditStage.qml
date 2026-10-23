pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.modules.common.functions
import qs.modules.iris.style
import qs
import qs.services
import qs.modules.iris.components
import qs.modules.iris.frame

// Arranging widgets: what the desktop recedes over, and the card's edge. Loaded by the desktop (shared Background):
// `under` lays the wallpaper softly blurred and dimmed behind the card with its shadow, `over` draws the card's hairline
// and gives the desktop `cardMask`, the card's shape at full size, to cut its corners. The chassis recedes into the card
// with the desktop (IrisBar), so the frame, the Island and the Dock on the card are the real ones; the edit window
// (IrisEditDesk) loads `lit`, the rims of the bodies a carried widget meets, drawn over them.
Item {
    id: root

    property string side: "under"
    property string output: ""
    property var room: null
    property var card: ({ x: 0, y: 0, s: 1, p: 0 })
    // The card's own still is still decoding: the real wallpaper keeps showing round the card meanwhile.
    property bool waiting: false
    // The wallpaper's still, for the stage.
    property string still: ""

    readonly property real d: IrisStyle.density
    readonly property real p: Math.max(0, Math.min(1, root.card.p))
    readonly property real cardX: root.card.x
    readonly property real cardY: root.card.y
    readonly property real cardW: root.width * root.card.s
    readonly property real cardH: root.height * root.card.s
    readonly property bool cut: IrisStyle.fieldChamfer
    readonly property real cornerSize: (root.cut ? IrisStyle.chamferCut : Math.round(22 * root.d)) * root.p
    readonly property color paper: IrisStyle.paper

    // The stage: the person's own wallpaper, out of focus and a step darker (lighter in light), so the card reads as
    // the thing in front. Decoded small and blurred once; nothing is drawn per frame but its opacity.
    Item {
        visible: root.side === "under"
        anchors.fill: parent
        opacity: root.waiting ? 0 : Math.min(1, root.p * 1.6)
        Rectangle { anchors.fill: parent; color: root.paper }
        Image {
            id: stageStill
            anchors.fill: parent
            visible: false
            source: root.side === "under" ? root.still : ""
            sourceSize: Qt.size(Math.round(root.width / 3), Math.round(root.height / 3))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
        MultiEffect {
            anchors.fill: parent
            source: stageStill
            visible: stageStill.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 40
            saturation: -0.15
            autoPaddingEnabled: false
        }
        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha(root.paper, IrisStyle.light ? 0.32 : 0.46) // iris-literal: the stage's dim over the blurred wallpaper
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
    // The card's corner in desktop px and whether it is cut: the desktop's own shader draws the shape.
    readonly property real cardCorner: root.cornerSize / Math.max(0.2, root.card.s)
    readonly property bool cardCut: root.cut
    Item {
        id: mask
        visible: false
        width: root.width
        height: root.height
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

    // ── lit: the bodies a carried widget meets, their rims over the shrunk chassis ──
    readonly property real hair: 1 / Math.max(0.2, root.card.s)
    readonly property var bodies: root.side === "lit" ? DesktopArrange.bodiesOf(root.output) : []
    readonly property var lit: {
        const out = {}
        if (root.side !== "lit" || DesktopArrange.dragOutput !== root.output || DesktopArrange.phase === "idle")
            return out
        for (const line of DesktopArrange.slots)
            for (const id of (line?.ids ?? [])) out[id] = true
        for (const id in DesktopArrange.matched) out[id] = true
        return out
    }
    // One outline for every shape: a capsule's ends are arcs, a smaller radius is the field's squircle (a quartic
    // superellipse over 1.8409 r, apex where the circle's was), AIRISU cuts top-right and bottom-left at 45 deg.
    function outline(x: real, y: real, w: real, h: real, r: real, cut: real): string {
        if (cut > 0) {
            const c = Math.min(cut, w / 2, h / 2)
            return `M ${x} ${y} L ${x + w - c} ${y} L ${x + w} ${y + c} L ${x + w} ${y + h} L ${x + c} ${y + h} L ${x} ${y + h - c} Z`
        }
        const half = Math.min(w, h) / 2
        if (r >= half - 0.5) {
            const k = half
            return w >= h
                ? `M ${x + k} ${y} L ${x + w - k} ${y} A ${k} ${k} 0 0 1 ${x + w - k} ${y + h} L ${x + k} ${y + h} A ${k} ${k} 0 0 1 ${x + k} ${y} Z`
                : `M ${x} ${y + k} A ${k} ${k} 0 0 1 ${x + w} ${y + k} L ${x + w} ${y + h - k} A ${k} ${k} 0 0 1 ${x} ${y + h - k} Z`
        }
        const R = Math.min(r * 1.8409, half)
        if (R <= 0.5)
            return `M ${x} ${y} L ${x + w} ${y} L ${x + w} ${y + h} L ${x} ${y + h} Z`
        const pts = []
        const corner = (cx, cy, from) => {
            for (let i = 0; i <= 8; i++) {
                const t = from + i / 8 * Math.PI / 2
                const c = Math.cos(t), sn = Math.sin(t)
                pts.push((cx + R * Math.sign(c) * Math.sqrt(Math.abs(c))).toFixed(2) + " " + (cy + R * Math.sign(sn) * Math.sqrt(Math.abs(sn))).toFixed(2))
            }
        }
        corner(x + w - R, y + R, -Math.PI / 2)
        corner(x + w - R, y + h - R, 0)
        corner(x + R, y + h - R, Math.PI / 2)
        corner(x + R, y + R, Math.PI)
        return "M " + pts.join(" L ") + " Z"
    }
    function cutOf(b: var): real { return root.cut ? Math.min(IrisStyle.chamferCut, Math.round(b.h / 3)) : 0 }
    Item {
        visible: root.side === "lit"
        width: root.width
        height: root.height
        transform: [
            Scale { xScale: root.card.s; yScale: root.card.s },
            Translate { x: root.card.x; y: root.card.y }
        ]
        Repeater {
            model: root.bodies
            delegate: Shape {
                id: rim
                required property var modelData
                readonly property bool hot: Boolean(root.lit[rim.modelData.id])
                x: rim.modelData.x
                y: rim.modelData.y
                width: rim.modelData.w
                height: rim.modelData.h
                opacity: rim.hot ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 110; easing.type: IrisStyle.feedbackEasing } }
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ColorUtils.applyAlpha(IrisStyle.accent, 0.12) // iris-literal: a lit body's wash, under its accent rim
                    strokeColor: IrisStyle.accent
                    strokeWidth: 2 * root.hair
                    PathSvg { path: root.outline(0, 0, rim.width, rim.height, rim.modelData.radius ?? 0, root.cutOf(rim.modelData)) }
                }
            }
        }
    }
}
