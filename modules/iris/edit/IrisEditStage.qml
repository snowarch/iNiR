pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.modules.common.functions
import qs.modules.iris.style
import qs
import qs.services
import qs.modules.iris.components
import qs.modules.iris.frame

// Arranging widgets: the family's paper the desktop recedes onto, and the card's edge. Loaded three times by the desktop
// (shared Background): `under` paints the paper and the card's shadow behind the shrunk desktop, `over` draws the
// card's hairline on top of it and gives the desktop `cardMask`, the card's shape at full size, to cut its corners, and
// `inside` (shrunk with the desktop, under its widgets) draws where the frame, the Island, its bubbles and the Dock
// rest, so the card is the screen as it will be and a widget is seen keeping clear of them.
Item {
    id: root

    property string side: "under"
    property string output: ""
    property var room: null
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

    // ── inside: the bodies where they rest, in desktop px ──
    readonly property real hair: 1 / Math.max(0.2, root.card.s)
    readonly property var bodies: root.side === "inside" ? DesktopArrange.bodiesOf(root.output) : []
    // What a carried widget lines up with, or was let go beside, lights up.
    readonly property var lit: {
        const out = {}
        if (root.side !== "inside" || DesktopArrange.dragOutput !== root.output || DesktopArrange.phase === "idle")
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
    // The field's own tint (glass shows the wallpaper through it, unblurred here) and its rim.
    readonly property color bodyFill: IrisStyle.glassy ? IrisStyle.bodyTint : IrisStyle.bodySurface
    readonly property color bodyLine: IrisStyle.hairlineStrong
    // A body welded to an edge reaches it, and meets the frame's inner edge (or the screen's) in two fillets.
    function welded(b: var): string {
        const edge = String(b?.joins ?? "")
        if (edge.length === 0) return ""
        const r = root.room ?? { left: 0, top: 0, right: root.width, bottom: root.height }
        // The field melts by a smooth union: its fillet reads about two thirds of `fuse` wide.
        // AIRISU joins with a 45 deg gusset of at most two cuts instead.
        const f = root.cut ? Math.min(Number(b.fuse ?? 0), 2 * IrisStyle.chamferCut)
            : Math.max(0, Math.min(Number(b.fuse ?? 0) * 0.65, 48))
        const arc = (sweep, x, y) => root.cut ? `L ${x} ${y}` : `A ${f} ${f} 0 0 ${sweep} ${x} ${y}`
        const at = ({ top: r.top, bottom: r.bottom, left: r.left, right: r.right })[edge]
        if (at === undefined) return ""
        let p = ""
        if (edge === "top" || edge === "bottom") {
            // Over the welded half too, so the body's corners on that side come out square.
            const y0 = edge === "top" ? 0 : b.y + b.h / 2
            const y1 = edge === "top" ? b.y + b.h / 2 : root.height
            p += `M ${b.x} ${y0} L ${b.x + b.w} ${y0} L ${b.x + b.w} ${y1} L ${b.x} ${y1} Z `
            if (f > 0.5) {
                const s = edge === "top" ? 1 : -1
                p += `M ${b.x - f} ${at} L ${b.x + 1} ${at} L ${b.x + 1} ${at + s * f} L ${b.x} ${at + s * f} ${arc(edge === "top" ? 0 : 1, b.x - f, at)} Z `
                p += `M ${b.x + b.w + f} ${at} L ${b.x + b.w - 1} ${at} L ${b.x + b.w - 1} ${at + s * f} L ${b.x + b.w} ${at + s * f} ${arc(edge === "top" ? 1 : 0, b.x + b.w + f, at)} Z `
            }
        } else {
            const x0 = edge === "left" ? 0 : b.x + b.w / 2
            const x1 = edge === "left" ? b.x + b.w / 2 : root.width
            p += `M ${x0} ${b.y} L ${x1} ${b.y} L ${x1} ${b.y + b.h} L ${x0} ${b.y + b.h} Z `
            if (f > 0.5) {
                const s = edge === "left" ? 1 : -1
                p += `M ${at} ${b.y - f} L ${at} ${b.y + 1} L ${at + s * f} ${b.y + 1} L ${at + s * f} ${b.y} ${arc(edge === "left" ? 1 : 0, at, b.y - f)} Z `
                p += `M ${at} ${b.y + b.h + f} L ${at} ${b.y + b.h - 1} L ${at + s * f} ${b.y + b.h - 1} L ${at + s * f} ${b.y + b.h} ${arc(edge === "left" ? 0 : 1, at, b.y + b.h + f)} Z `
            }
        }
        return p
    }

    // The frame's band round the screen with its hole cut like the real one, and the bodies resting on it: drawn
    // opaque into one layer that takes the tint's alpha once, so a weld over the band never doubles it.
    readonly property color ghostInk: Qt.rgba(root.bodyFill.r, root.bodyFill.g, root.bodyFill.b, 1)
    readonly property string holePath: {
        const r = root.room
        if (!r) return ""
        return root.outline(r.left, r.top, r.right - r.left, r.bottom - r.top, IrisFrame.cornerRadius,
            root.cut ? IrisStyle.chamferCut : 0)
    }
    function cutOf(b: var): real { return root.cut ? Math.min(IrisStyle.chamferCut, Math.round(b.h / 3)) : 0 }
    Item {
        visible: root.side === "inside"
        anchors.fill: parent
        opacity: root.bodyFill.a
        layer.enabled: root.side === "inside" && root.bodyFill.a < 0.999
        Shape {
            visible: IrisFrame.framed && root.holePath.length > 0
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillRule: ShapePath.OddEvenFill
                fillColor: root.ghostInk
                strokeColor: "transparent"
                strokeWidth: 0
                PathSvg { path: `M 0 0 L ${root.width} 0 L ${root.width} ${root.height} L 0 ${root.height} Z ` + root.holePath }
            }
            // The inner rim, under the bodies so a weld covers it where the Island or the Dock joins the frame.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.tint(root.ghostInk, root.bodyLine)
                strokeWidth: 1.5 * root.hair
                PathSvg { path: root.holePath }
            }
        }
        Repeater {
            model: root.bodies
            delegate: Shape {
                id: fill
                required property var modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: root.ghostInk
                    strokeColor: "transparent"
                    strokeWidth: 0
                    PathSvg { path: root.welded(fill.modelData) }
                }
                ShapePath {
                    fillColor: root.ghostInk
                    strokeColor: "transparent"
                    strokeWidth: 0
                    PathSvg {
                        path: root.outline(fill.modelData.x, fill.modelData.y, fill.modelData.w, fill.modelData.h,
                            fill.modelData.radius ?? 0, root.cutOf(fill.modelData))
                    }
                }
            }
        }
    }
    // A floating body's rim; a body a carried widget meets lights in accent.
    Repeater {
        model: root.bodies
        delegate: Item {
            id: body
            required property var modelData
            readonly property bool hot: Boolean(root.lit[body.modelData.id])
            readonly property bool weld: String(body.modelData.joins ?? "").length > 0
            x: body.modelData.x
            y: body.modelData.y
            width: body.modelData.w
            height: body.modelData.h
            Shape {
                anchors.fill: parent
                visible: !body.weld || body.hot
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: body.hot ? IrisStyle.accent : root.bodyLine
                    strokeWidth: (body.hot ? 1.5 : 1) * root.hair
                    PathSvg { path: root.outline(0, 0, body.width, body.height, body.modelData.radius ?? 0, root.cutOf(body.modelData)) }
                }
            }
            // Its name, at its true size on the card, when it fits.
            Text {
                anchors.centerIn: parent
                text: body.modelData.name ?? ""
                visible: implicitWidth + 12 * root.hair <= body.width && implicitHeight + 4 * root.hair <= body.height
                color: body.hot ? IrisStyle.text : IrisStyle.textTertiary
                font.family: IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeCaption * root.hair
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: 110; easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
}
