import QtQuick
import QtQuick.Shapes
import qs.modules.common.functions

// A panel of coloured lacquer (色漆), AIRISU's one surface: cut by the Design's die (45° off two opposite corners) and
// painted, like a livery, with a second coat whose edge runs at the same 45°. `share` is how far the coat has come from
// the start side, 0 to 1, and it carries data: a level, the part of a song played, the part of the hour gone. When the
// lacquer's colour changes it is not faded: the new colour is laid across the panel from the start side along the same
// cut, so a surface that changes subject reads as one being repainted.
Item {
    id: root
    property color lacquer: Airisu.sticker
    property color coat: "transparent"
    property real share: 0
    // The coat may run along the foot only (a band), as tall as `band`; 0 covers the whole height. `head` lays the band
    // along the top instead.
    property real band: 0
    property bool head: false
    property int cut: Airisu.chamfer
    property bool cutTopRight: true
    property bool cutBottomLeft: true
    property bool cutTopLeft: false
    property bool cutBottomRight: false
    property bool moving: Airisu.moving
    // How a change of share moves: a detent for a level, nothing for a clock that is only read.
    property int travel: Airisu.snap
    // Shunkei-nuri (春慶塗): a texture provider of the panel's own size (a picture) seen through the lacquer, which is
    // then laid as a glaze of `glaze` strength, the way transparent lacquer shows the grain of the wood under it.
    property Item texture: null
    property real glaze: 0.72

    readonly property real w: Math.max(0, root.width)
    readonly property real h: Math.max(0, root.height)
    readonly property real c: Math.max(0, Math.min(root.cut, root.w / 2, root.h / 2))

    // The die as a convex polygon, clockwise from the top left.
    readonly property var die: {
        const w = root.w, h = root.h, c = root.c
        const p = []
        if (root.cutTopLeft) { p.push(Qt.point(0, c)); p.push(Qt.point(c, 0)) } else p.push(Qt.point(0, 0))
        if (root.cutTopRight) { p.push(Qt.point(w - c, 0)); p.push(Qt.point(w, c)) } else p.push(Qt.point(w, 0))
        if (root.cutBottomRight) { p.push(Qt.point(w, h - c)); p.push(Qt.point(w - c, h)) } else p.push(Qt.point(w, h))
        if (root.cutBottomLeft) { p.push(Qt.point(c, h)); p.push(Qt.point(0, h - c)) } else p.push(Qt.point(0, h))
        return p
    }
    // The part of a polygon on the near side of a 45° cut that has come `s` of the way across (it leans forward, its
    // top ahead of its foot), and at most `top` from the foot when the coat is a band.
    // The edge travels its own lean plus the width, so a band (whose lean is only its own height) starts at once and
    // reads the share it carries, instead of lying hidden for the panel's height first.
    function cutAt(points: var, s: real, top: real): var {
        const band = top > 0 ? Math.min(top, root.h) : root.h
        // The band's foot, where the edge starts: the panel's foot, or the band's own when it runs along the head.
        const foot = top > 0 && root.head ? band : root.h
        const reach = -band + Math.max(0, Math.min(1, s)) * (root.w + band)
        let out = root.clip(points, p => p.x - (foot - p.y) - reach)
        if (top > 0)
            out = root.head ? root.clip(out, p => p.y - band) : root.clip(out, p => (root.h - band) - p.y)
        return out
    }
    // The part still ahead of that cut, so a colour being laid never lies over the one it replaces (a see-through lacquer
    // would darken where both are).
    function aheadOf(points: var, s: real): var {
        const h = root.h
        const reach = -h + Math.max(0, Math.min(1, s)) * (root.w + h)
        return root.clip(points, p => reach - (p.x - (h - p.y)))
    }
    // Sutherland–Hodgman against one half-plane, f(p) <= 0 kept.
    function clip(points: var, f: var): var {
        const out = []
        const n = points.length
        for (let i = 0; i < n; ++i) {
            const a = points[i], b = points[(i + 1) % n]
            const fa = f(a), fb = f(b)
            if (fa <= 0) out.push(a)
            if ((fa < 0 && fb > 0) || (fa > 0 && fb < 0)) {
                const t = fa / (fa - fb)
                out.push(Qt.point(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y)))
            }
        }
        return out
    }
    function closed(points: var): var { return points.length > 2 ? points.concat([points[0]]) : [] }

    // The coat's share, moved by a detent (never a spring).
    property real shown: root.share
    Behavior on shown {
        enabled: root.moving && root.travel > 0
        NumberAnimation { duration: root.travel; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
    }

    // Repainting: the colour shown, the one under it while the new one is laid on, and how far it has come.
    property color _top: root.lacquer
    property color _under: root.lacquer
    property real _laid: 1
    property bool _ready: false
    Component.onCompleted: { root._top = root.lacquer; root._under = root.lacquer; root._ready = true }
    onLacquerChanged: {
        if (!root._ready) return
        if (Qt.colorEqual(root.lacquer, root._top)) return
        if (!root.moving || root.w <= 0) {
            root._top = root.lacquer
            root._under = root.lacquer
            root._laid = 1
            return
        }
        // Mid-repaint, the colour half laid is taken as finished: the new coat goes over what the eye already sees.
        root._under = root._laid >= 0.5 ? root._top : root._under
        root._top = root.lacquer
        repaint.restart()
    }
    NumberAnimation {
        id: repaint
        target: root
        property: "_laid"
        from: 0
        to: 1
        duration: Airisu.tear
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Airisu.curve
        onFinished: root._under = root._top
    }

    function glazed(c: color): color { return root.texture ? Qt.rgba(c.r, c.g, c.b, c.a * root.glaze) : c }
    // Where the coat runs the whole height over a lacquer that can be seen through, the lacquer stops at the coat's edge
    // instead of lying under it (two see-through coats would darken where both are).
    readonly property bool coated: root.shown > 0.001 && root.coat.a > 0
    readonly property var coatRegion: root.coated ? root.cutAt(root.die, root.shown, root.band) : []
    readonly property var bare: root.coated && root.band <= 0 && (root.texture !== null || root.lacquer.a < 0.999)
        ? root.aheadOf(root.die, root.shown) : root.die

    // A quiet key at rest paints nothing: its Shape is not even built (a Shape with its paths is a dozen objects and a
    // triangulation at first sync, and Settings makes thousands of these on a page switch).
    readonly property bool paints: root.texture !== null || root.coated || root._top.a > 0 || (root._laid < 1 && root._under.a > 0)
    Loader {
        anchors.fill: parent
        active: root.paints
        sourceComponent: lacquerShape
    }
    Component {
        id: lacquerShape
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                fillItem: root.texture
                strokeColor: "transparent"
                strokeWidth: 0
                PathPolyline { path: root.texture ? root.closed(root.die) : [] }
            }
            ShapePath {
                fillColor: root.glazed(root._laid < 1 ? root._under : root._top)
                strokeColor: "transparent"
                strokeWidth: 0
                PathPolyline { path: root._laid < 1 ? root.closed(root.aheadOf(root.bare, root._laid)) : root.closed(root.bare) }
            }
            ShapePath {
                fillColor: root._laid < 1 ? root.glazed(root._top) : "transparent"
                strokeColor: "transparent"
                strokeWidth: 0
                PathPolyline { path: root._laid < 1 ? root.closed(root.cutAt(root.bare, root._laid, 0)) : [] }
            }
            ShapePath {
                fillColor: root.glazed(root.coat)
                strokeColor: "transparent"
                strokeWidth: 0
                PathPolyline { path: root.coated ? root.closed(root.coatRegion) : [] }
            }
        }
    }
}
