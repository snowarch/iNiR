pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.iris.frame

Region {
    id: root

    property var shapes: []
    property bool framed: false
    property bool joinsFrame: root.framed
    property real windowWidth: 0
    property real windowHeight: 0
    property real band: IrisFrame.band
    property real cornerRadius: IrisFrame.cornerRadius
    // Niri blurs exactly the whole-pixel rects it is given, with no AA: at a 12 % tint that 1-bit step was the
    // visible contour and stair-stepped on every curve. A pixel is blurred when its centre lies half a pixel inside
    // the silhouette, so the step stays within the field's lit glass edge (IrisField.frag) and no sharp ring shows.
    // Region geometry is whole pixels (qint32, truncated), so every edge is rounded here by that centre rule.
    property real inset: 0.5
    // First and past-the-last pixel whose centre is strictly inside; a tie stays out on both sides.
    function lo(v: real): int { return Math.floor(v - 0.5) + 1 }
    function hi(v: real): int { return Math.ceil(v - 0.5) }
    // Rebuilding this region is JS plus 70 bound sub-regions, and the chassis composes its table from several sources that each arrive
    // on their own: it is built once per frame inside the window's polish, where the background effect reads it (a zero timer ran
    // after that polish and left unblurred wallpaper around an opening body). The settle pass carries the exact resting contour.
    property var held: []
    property bool dirty: false
    // A body that leaves (a dismissed banner, a closed card) takes its region with it in the same turn: the
    // region reaches the compositor only with a frame that has something to draw, and a turn later the frame
    // that removed the body is gone, so its blur stayed until the next repaint.
    onShapesChanged: {
        if ((root.shapes ?? []).length < (root.held ?? []).length) { perFrame.stop(); root.held = root.shapes ?? [] }
        else {
            root.dirty = true
            poke.x = poke.x > 0 ? 0 : 1
            if (!perFrame.running) perFrame.restart()
        }
        root.settled = false
        settle.restart()
    }
    function take(): void {
        if (!root.dirty) return
        root.dirty = false
        perFrame.stop()
        root.held = root.shapes ?? []
    }
    // Qt polishes the content item before every frame with something new: rebuilding here reaches the background effect with it.
    property Connections framePolish: Connections {
        target: root.window?.contentItem ?? null
        ignoreUnknownSignals: true
        function onPolished(): void { root.take() }
    }
    property Timer perFrame: Timer { interval: 0; onTriggered: root.take() }
    property Timer settle: Timer { interval: 96; onTriggered: { root.dirty = false; root.held = root.shapes ?? []; root.settled = true; root.kick() } }
    // Moving, a join is walked in 4 px strides and stays up to 3 px inside the silhouette; settled, to the pixel.
    property bool settled: true
    readonly property var built: root.build(root.held ?? [], root.settled)
    readonly property var pieces: root.built.bodies
    readonly property bool empty: root.pieces.length === 0 && !root.framed
    onBuiltChanged: root.placeRuns()

    // The window this region blurs. The region publishes itself, as DMS's WindowBlur does: nothing
    // while the window is hidden, a fresh commit once the shape settles (a nested Region can change
    // without the compositor hearing of it) and null before the window goes, so no blur outlives
    // the body it belonged to.
    property var window: null
    // ext-background-effect is double-buffered: polish updates its pending region,
    // but a settled/empty scene may not draw another frame to commit that change.
    // Request a frame only at publication boundaries, never continuously.
    function commitFrame(): void {
        const quickWindow = root.window?.contentItem?.Window.window
        if (root.window?.visible && quickWindow) quickWindow.update()
    }
    function apply(): void {
        if (!root.window) return
        root.window.BackgroundEffect.blurRegion = root.empty || !root.window.visible ? null : root
        root.commitFrame()
    }
    function kick(): void {
        if (!root.window || root.empty || !root.window.visible) return root.apply()
        root.window.BackgroundEffect.blurRegion = null
        root.window.BackgroundEffect.blurRegion = root
        root.commitFrame()
    }
    onEmptyChanged: root.apply()
    onWindowChanged: root.apply()
    property Connections windowState: Connections {
        target: root.window
        ignoreUnknownSignals: true
        function onVisibleChanged(): void { root.window.visible ? root.kick() : root.apply() }
    }
    Component.onCompleted: root.apply()
    Component.onDestruction: if (root.window) root.window.BackgroundEffect.blurRegion = null

    // The field's own distances (IrisField.frag), so a join is measured on the shape it draws.
    function boxDistance(s: var, x: real, y: real): real {
        const hx = s.width / 2, hy = s.height / 2
        const r = Math.min(Number(s.radius ?? 0), hx, hy)
        const qx = Math.abs(x - s.x - hx) - (hx - r), qy = Math.abs(y - s.y - hy) - (hy - r)
        const ox = Math.max(qx, 0), oy = Math.max(qy, 0)
        return Math.sqrt(ox * ox + oy * oy) + Math.min(Math.max(qx, qy), 0) - r
    }
    function frameDistance(x: real, y: real): real {
        return -root.boxDistance(root.memo.frame, x, y)
    }
    // The frame's inner box, set once per build from inside the `pieces` binding, so it must not notify: built
    // per evaluation it was 95 % of the build (2.5 ms against 0.13).
    readonly property var memo: ({ frame: null, runs: null })
    function smoothUnion(a: real, b: real, k: real): real {
        if (k <= 0.001) return Math.min(a, b)
        const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (b - a) / k))
        return b + (a - b) * h - k * h * (1 - h)
    }
    // A joined body is blurred where the field draws it: its smooth union with what it joins swells the body
    // and draws the fillets, so every row and column that crosses the body is walked out from the body's own
    // span to the last pixel whose centre the union holds. Consecutive lines with the same span are one rect.
    function lines(s: var, inside: var, rows: bool, reach: real, exact: bool, out: var): void {
        const i = root.inset
        const acrossLo = rows ? s.y : s.x, acrossLen = rows ? s.height : s.width
        const alongLo = rows ? s.x : s.y, alongLen = rows ? s.width : s.height
        const limit = rows ? root.windowWidth : root.windowHeight
        const r = Math.min(Number(s.radius ?? 0), s.width / 2, s.height / 2)
        const test = (along, across) => rows ? inside(along, across) : inside(across, along)
        // The last pixel centre from `from` (inside) toward `to` that the union holds: 4 px strides, then 1 px.
        const walk = (from, to, across) => {
            const dir = to > from ? 1 : -1
            let at = from
            while (dir * (to - at) >= 4 && test(at + dir * 4, across)) at += dir * 4
            while (exact && dir * (to - at) >= 1 && test(at + dir, across)) at += dir
            return at
        }
        // Past the body too: the union swells its far edge and fills the pixel line where it meets what it joins.
        const first = Math.max(0, Math.floor(acrossLo - reach / 2))
        const last = Math.min((rows ? root.windowHeight : root.windowWidth) - 1, Math.ceil(acrossLo + acrossLen + reach / 2) - 1)
        const band = root.framed ? root.hi(root.band - i) : 0, size = rows ? root.windowHeight : root.windowWidth
        const mid = Math.floor(alongLo + alongLen / 2) + 0.5
        // One line: the pixels the union holds around the body's middle, walked out from the body's own span (its
        // rounded corners included). Null where the band already blurs it or the union misses the middle.
        const span = n => {
            if (n < band || n >= size - band) return null
            const across = n + 0.5
            if (!test(mid, across)) return null
            const off = Math.max(0, Math.min(across - acrossLo, acrossLo + acrossLen - across))
            const inset = off >= r ? 0 : r - Math.sqrt(Math.max(0, r * r - (r - off) ** 2))
            const edgeA = Math.min(mid, Math.floor(alongLo + inset + i) + 1.5), edgeB = Math.max(mid, Math.ceil(alongLo + alongLen - inset - i) - 1.5)
            return [Math.max(0, Math.floor(walk(test(edgeA, across) ? edgeA : mid, Math.max(0.5, Math.ceil(alongLo + inset) - reach - 0.5), across))),
                Math.min(limit - 1, Math.floor(walk(test(edgeB, across) ? edgeB : mid, Math.min(limit - 0.5, Math.floor(alongLo + alongLen - inset) + reach + 0.5), across)))]
        }
        const same = (p, q) => p === q || (p !== null && q !== null && p[0] === q[0] && p[1] === q[1])
        // Every fourth line, then each line between two that differ: the union is smooth, so between two equal
        // lines nothing turns.
        const spans = []
        let prev = first
        spans[first] = span(first)
        for (let n = Math.min(first + 4, last); n > prev; n = Math.min(n + 4, last)) {
            spans[n] = span(n)
            const fill = same(spans[prev], spans[n])
            for (let m = prev + 1; m < n; m++) spans[m] = fill ? spans[prev] : span(m)
            prev = n
            if (n === last) break
        }
        let open = null
        const flush = () => {
            if (!open) return
            out.push(rows ? { x: open.a, y: open.from, width: open.b - open.a + 1, height: open.to - open.from + 1 }
                : { x: open.from, y: open.a, width: open.to - open.from + 1, height: open.b - open.a + 1 })
            open = null
        }
        for (let n = first; n <= last; n++) {
            const q = spans[n]
            if (!q) { flush(); continue }
            if (open && open.a === q[0] && open.b === q[1]) open.to = n
            else { flush(); open = { a: q[0], b: q[1], from: n, to: n } }
        }
        flush()
    }
    // A join's runs are kept while both bodies and the window stay put: in a morph only the moving body is walked.
    function joinRuns(s: var, t: var, exact: bool, out: var, cache: var, kept: var): void {
        const k = Math.max(0, Number(s.fuse ?? 0))
        if (k < 0.5) return
        const g = b => b.x + "," + b.y + "," + b.width + "," + b.height + "," + (b.radius ?? 0)
        const key = g(s) + "," + k + "|" + (t === null ? "frame:" + g(root.memo.frame) + "," + root.windowWidth + "," + root.windowHeight
            : g(t)) + "|" + root.framed + "," + root.band
        // A still body keeps its exact runs while another one moves; only a moving one is walked coarse.
        const known = cache[key] ?? (exact ? null : cache[key + "~"])
        if (known) {
            kept[cache[key] ? key : key + "~"] = known
            for (const q of known) out.push(q)
            return
        }
        const mine = []
        kept[exact ? key : key + "~"] = mine
        // Plain numbers in closures: this runs ~10k times a build, and a QML property read per call made it 15 ms.
        const box = b => {
            const hx = b.width / 2, hy = b.height / 2, r = Math.min(Number(b.radius ?? 0), hx, hy)
            const cx = b.x + hx, cy = b.y + hy, ex = hx - r, ey = hy - r
            return (x, y) => {
                const qx = Math.abs(x - cx) - ex, qy = Math.abs(y - cy) - ey
                const ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0
                return Math.sqrt(ox * ox + oy * oy) + Math.min(qx > qy ? qx : qy, 0) - r
            }
        }
        const own = box(s), joined = box(t === null ? root.memo.frame : t), sign = t === null ? -1 : 1, limit = -root.inset
        const inside = (x, y) => {
            const a = sign * joined(x, y), b = own(x, y)
            const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (b - a) / k))
            return b + (a - b) * h - k * h * (1 - h) < limit
        }
        root.lines(s, inside, true, 2 * k, exact, mine)
        root.lines(s, inside, false, 2 * k, exact, mine)
        for (const q of mine) out.push(q)
    }
    // Runs past the declared pieces live in a pool of child regions, grown on demand and zeroed when unused.
    readonly property Component runComponent: Component { Region {} }
    property var runPool: []
    function placeRuns(): void {
        const runs = root.built.runs, pool = root.runPool
        while (pool.length < runs.length) {
            const made = root.runComponent.createObject(root)
            root.regions.push(made)
            pool.push(made)
        }
        for (let n = 0; n < pool.length; n++) {
            const q = runs[n] ?? null, r = pool[n]
            r.x = q ? q.x : 0
            r.y = q ? q.y : 0
            r.width = q ? q.width : 0
            r.height = q ? q.height : 0
        }
    }
    function build(list: var, exact: bool): var {
        const byId = {}
        for (const s of list) if (s.id) byId[s.id] = s
        const out = []
        const runs = []
        const cache = root.memo.runs ?? {}, kept = {}
        const b = root.band
        root.memo.frame = { x: b, y: b, width: root.windowWidth - 2 * b, height: root.windowHeight - 2 * b, radius: root.cornerRadius }
        for (const s of list) {
            const i = root.inset
            out.push({ x: s.x + i, y: s.y + i, width: s.width - 2 * i, height: s.height - 2 * i, radius: Math.max(0, Number(s.radius ?? 0) - i) })
            const joins = !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
            for (const id of joins) {
                if (id === "frame") {
                    if (root.joinsFrame) root.joinRuns(s, null, exact, runs, cache, kept)
                } else if (byId[id]) root.joinRuns(s, byId[id], exact, runs, cache, kept)
            }
        }
        root.memo.runs = kept
        return { bodies: out.slice(0, 70), runs: runs }
    }




    component Piece: Region {
        id: piece
        required property int index
        readonly property var p: root.pieces[piece.index] ?? null
        x: piece.p ? root.lo(piece.p.x) : 0
        y: piece.p ? root.lo(piece.p.y) : 0
        width: piece.p ? Math.max(0, root.hi(piece.p.x + piece.p.width) - root.lo(piece.p.x)) : 0
        height: piece.p ? Math.max(0, root.hi(piece.p.y + piece.p.height) - root.lo(piece.p.y)) : 0
        // A disc (a bubble, a satellite) is an ellipse: as a rounded box of odd size its radius truncates and bulges.
        readonly property bool disc: piece.p !== null && Math.abs(piece.p.width - piece.p.height) < 1
            && piece.p.radius >= piece.p.width / 2 - 0.5
        shape: piece.disc ? RegionShape.Ellipse : RegionShape.Rect
        radius: piece.p && !piece.disc ? Math.ceil(piece.p.radius) : 0
    }

    Region {
        width: root.framed ? root.windowWidth : 0
        height: root.framed ? root.windowHeight : 0
        Region {
            intersection: Intersection.Subtract
            readonly property int edge: root.hi(root.band - root.inset)
            x: edge
            y: edge
            width: Math.max(0, root.windowWidth - 2 * edge)
            height: Math.max(0, root.windowHeight - 2 * edge)
            // Concentric with the frame's inner corner: the hole is grown by the pixel rounding of its edge.
            radius: Math.round(root.cornerRadius + root.band - edge)
        }
    }
    // Empty: its only job is to make the region change, which schedules the window's polish.
    Region { id: poke; width: 0; height: 0 }
    Piece { index: 0 }
    Piece { index: 1 }
    Piece { index: 2 }
    Piece { index: 3 }
    Piece { index: 4 }
    Piece { index: 5 }
    Piece { index: 6 }
    Piece { index: 7 }
    Piece { index: 8 }
    Piece { index: 9 }
    Piece { index: 10 }
    Piece { index: 11 }
    Piece { index: 12 }
    Piece { index: 13 }
    Piece { index: 14 }
    Piece { index: 15 }
    Piece { index: 16 }
    Piece { index: 17 }
    Piece { index: 18 }
    Piece { index: 19 }
    Piece { index: 20 }
    Piece { index: 21 }
    Piece { index: 22 }
    Piece { index: 23 }
    Piece { index: 24 }
    Piece { index: 25 }
    Piece { index: 26 }
    Piece { index: 27 }
    Piece { index: 28 }
    Piece { index: 29 }
    Piece { index: 30 }
    Piece { index: 31 }
    Piece { index: 32 }
    Piece { index: 33 }
    Piece { index: 34 }
    Piece { index: 35 }
    Piece { index: 36 }
    Piece { index: 37 }
    Piece { index: 38 }
    Piece { index: 39 }
    Piece { index: 40 }
    Piece { index: 41 }
    Piece { index: 42 }
    Piece { index: 43 }
    Piece { index: 44 }
    Piece { index: 45 }
    Piece { index: 46 }
    Piece { index: 47 }
    Piece { index: 48 }
    Piece { index: 49 }
    Piece { index: 50 }
    Piece { index: 51 }
    Piece { index: 52 }
    Piece { index: 53 }
    Piece { index: 54 }
    Piece { index: 55 }
    Piece { index: 56 }
    Piece { index: 57 }
    Piece { index: 58 }
    Piece { index: 59 }
    Piece { index: 60 }
    Piece { index: 61 }
    Piece { index: 62 }
    Piece { index: 63 }
    Piece { index: 64 }
    Piece { index: 65 }
    Piece { index: 66 }
    Piece { index: 67 }
    Piece { index: 68 }
    Piece { index: 69 }
    Piece { index: 70 }
    Piece { index: 71 }
    Piece { index: 72 }
    Piece { index: 73 }
    Piece { index: 74 }
    Piece { index: 75 }
    Piece { index: 76 }
    Piece { index: 77 }
    Piece { index: 78 }
    Piece { index: 79 }
    Piece { index: 80 }
    Piece { index: 81 }
    Piece { index: 82 }
    Piece { index: 83 }
    Piece { index: 84 }
    Piece { index: 85 }
    Piece { index: 86 }
    Piece { index: 87 }
    Piece { index: 88 }
    Piece { index: 89 }
    Piece { index: 90 }
    Piece { index: 91 }
    Piece { index: 92 }
    Piece { index: 93 }
    Piece { index: 94 }
    Piece { index: 95 }
}
