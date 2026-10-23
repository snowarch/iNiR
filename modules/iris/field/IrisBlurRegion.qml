pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.iris.frame
import qs.modules.iris.style

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
    // A table rebuilt with the same bodies is no move: restarting the settle on it kept a still Island on the coarse
    // three-row corners forever, the stair steps under its blur.
    property string shapesKey: ""
    // Hundredths: a spring's float noise is no move, and the region is whole pixels anyway.
    function valueKey(v: var): string { return typeof v === "number" ? v.toFixed(2) : String(v) }
    function keyOf(list: var): string {
        return list.map(s => root.bodyKey(s)).join("|")
    }
    function bodyKey(s: var): string {
        return Object.keys(s).filter(k => typeof s[k] !== "object").map(k => k + ":" + root.valueKey(s[k])).join(",")
    }
    onShapesChanged: {
        const key = root.keyOf(root.shapes ?? [])
        if (key === root.shapesKey) return
        root.shapesKey = key
        if ((root.shapes ?? []).length < (root.held ?? []).length) { perFrame.stop(); root.held = root.shapes ?? [] }
        else {
            root.dirty = true
            poke.x = poke.x > 0 ? 0 : 1
            if (!perFrame.running) perFrame.restart()
        }
        root.settled = false
        settle.restart()
    }
    // Lets a source that coalesces its own table bring it up to date before the region reads it.
    property var beforeTake: null
    function take(): void {
        root.beforeTake?.()
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
    readonly property bool empty: root.pieces.length === 0 && root.built.runs.length === 0 && !root.framed
    onBuiltChanged: { root.placePieces(); root.placeRuns() }

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
    readonly property var memo: ({ frame: null, runs: null, rows: null, keys: null })
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
        const curve = root.squircles(s) ? Math.min(r * root.squircleReach, Math.min(s.width, s.height) / 2) : 0
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
            const inset = curve > 0 ? root.squircleInset(off, curve) : off >= r ? 0 : r - Math.sqrt(Math.max(0, r * r - (r - off) ** 2))
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
        const key = g(s) + "," + k + "," + IrisStyle.fieldChamfer + "|" + (t === null ? "frame:" + g(root.memo.frame) + "," + root.windowWidth + "," + root.windowHeight
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
        // The field's squircleBox: walked on circular corners, the blur held a sliver outside every large shoulder and
        // missed one inside a join's (12 px past an open Island's lower corners, 36 short of a resting Island's join).
        const reachK = root.squircleReach
        const box = b => {
            const hx = b.width / 2, hy = b.height / 2, m = hx < hy ? hx : hy
            const r = Math.min(Number(b.radius ?? 0), m)
            const cx = b.x + hx, cy = b.y + hy
            if (r < 0.5 || r >= m - 0.5) {
                const ex = hx - r, ey = hy - r
                return (x, y) => {
                    const qx = Math.abs(x - cx) - ex, qy = Math.abs(y - cy) - ey
                    const ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0
                    return Math.sqrt(ox * ox + oy * oy) + Math.min(qx > qy ? qx : qy, 0) - r
                }
            }
            const reach = Math.min(r * reachK, m), ex = hx - reach, ey = hy - reach
            return (x, y) => {
                const qx = Math.abs(x - cx) - ex, qy = Math.abs(y - cy) - ey
                if (qx <= 0 || qy <= 0) {
                    const ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0
                    return Math.sqrt(ox * ox + oy * oy) + Math.min(qx > qy ? qx : qy, 0) - reach
                }
                const x2 = qx * qx, y2 = qy * qy, l = Math.sqrt(Math.sqrt(x2 * x2 + y2 * y2)), l3 = l * l * l
                const gx = x2 * qx / l3, gy = y2 * qy / l3
                return (l - reach) / Math.sqrt(gx * gx + gy * gy)
            }
        }
        // A chamfered Design draws square boxes cut at 45° and joins them with a gusset whose legs are the blade's
        // (IrisField.frag cutBox, smoothUnion): measured the round way, the blur filled a fillet the field never drew.
        const blade = IrisStyle.fieldChamfer ? IrisStyle.chamferCut : 0
        const cutBox = (b, c, mask) => {
            const hx = b.width / 2, hy = b.height / 2, cx = b.x + hx, cy = b.y + hy, cc = Math.min(c, hx, hy)
            return (x, y) => {
                const dx = x - cx, dy = y - cy, qx = Math.abs(dx) - hx, qy = Math.abs(dy) - hy
                const ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0
                let d = Math.sqrt(ox * ox + oy * oy) + Math.min(qx > qy ? qx : qy, 0)
                const cuts = mask === 0 ? dx * dy < 0 : mask === -1 ? dy < 0 : mask === -2 ? dy > 0 : mask === -3 ? dx < 0 : dx > 0
                if (cc > 0.5 && cuts) d = Math.max(d, (Math.abs(dx) + Math.abs(dy) - (hx + hy - cc)) * 0.70710678)
                return d
            }
        }
        const own = blade > 0 ? cutBox(s, blade, root.cutMaskOf(s)) : box(s)
        const joined = blade > 0 ? (t === null ? cutBox(root.memo.frame, Number(root.memo.frame.radius ?? 0), 0) : cutBox(t, blade, root.cutMaskOf(t)))
            : box(t === null ? root.memo.frame : t)
        const sign = t === null ? -1 : 1, limit = -root.inset, gusset = Math.min(k, 2 * blade)
        const inside = blade > 0
            ? (x, y) => { const a = sign * joined(x, y), b = own(x, y); return Math.min(Math.min(a, b), (a + b - gusset * 0.5) * 0.70710678) < limit }
            : (x, y) => {
                const a = sign * joined(x, y), b = own(x, y)
                const h = Math.max(0, Math.min(1, 0.5 + 0.5 * (b - a) / k))
                return b + (a - b) * h - k * h * (1 - h) < limit
            }
        root.lines(s, inside, true, 2 * k, exact, mine)
        root.lines(s, inside, false, 2 * k, exact, mine)
        for (const q of mine) out.push(q)
    }
    // A chamfered Design's body (IrisField.frag `bodyBox`: the upper-right and lower-left corners cut at 45°) is blurred as
    // the rows its cut leaves, by the same centre rule moved in half a pixel along the cut's normal: one rect for the
    // square middle, one per row of each cut (every third row while it moves, taking the narrowest of the three), so no
    // blurred corner shows past the blade.
    function chamfered(s: var, cut: real, exact: bool, out: var): void {
        const i = root.inset
        // The corners the blade takes (IrisField.frag cutsCorner): the Design's pair, or the two a welded body shows.
        const mask = root.cutMaskOf(s)
        const ul = mask === -1 || mask === -3, ur = mask === 0 || mask === -1 || mask === -4
        const ll = mask === 0 || mask === -2 || mask === -3, lr = mask === -2 || mask === -4
        const c = Math.min(cut, s.width / 2, s.height / 2)
        const top = root.lo(s.y + i), bottom = root.hi(s.y + s.height - i)
        const left = root.lo(s.x + i), right = root.hi(s.x + s.width - i)
        if (bottom <= top || right <= left) return
        const reach = c + i * Math.SQRT2
        const span = n => {
            const cy = n + 0.5
            let a = left, b = right
            const fromTop = cy - s.y, fromBottom = s.y + s.height - cy
            if (fromTop < reach && ur) b = Math.min(b, root.lo(s.x + s.width - reach + fromTop))
            if (fromTop < reach && ul) a = Math.max(a, root.hi(s.x + reach - fromTop))
            if (fromBottom < reach && ll) a = Math.max(a, root.hi(s.x + reach - fromBottom))
            if (fromBottom < reach && lr) b = Math.min(b, root.lo(s.x + s.width - reach + fromBottom))
            return [a, b]
        }
        const step = exact || c <= 0.5 ? 1 : 3
        let open = null
        const flush = () => {
            if (open && open.b > open.a) out.push({ x: open.a, y: open.from, width: open.b - open.a, height: open.to - open.from })
            open = null
        }
        for (let n = top; n < bottom; n += step) {
            const end = Math.min(bottom, n + step)
            let a = left, b = right
            for (let m = n; m < end; m++) {
                const q = span(m)
                a = Math.max(a, q[0])
                b = Math.min(b, q[1])
            }
            if (open && open.a === a && open.b === b) open.to = end
            else { flush(); open = { a: a, b: b, from: n, to: end } }
        }
        flush()
    }
    // A round Design's large corner is a squircle (IrisField.frag squircleBox): the quartic over SQUIRCLE_REACH times the
    // radius. A round Rect region blurred up to 0.85 px past its shoulder (at a radius of 30), so the body is blurred as
    // its rows, as a cut body is: one rect for the square middle, one per row of the corners (every third row while it
    // moves, the narrowest of the three). Capsules and discs keep their round Rect, as the shader keeps their arcs.
    readonly property real squircleReach: 1.8409
    function squircles(s: var): bool {
        const m = Math.min(s.width, s.height) / 2
        const r = Math.min(Number(s.radius ?? 0), m)
        return r >= 0.5 && r < m - 0.5
    }
    // How far in from the side a squircle corner of `reach` stands at `t` from its top or bottom edge.
    function squircleInset(t: real, reach: real): real {
        if (t >= reach) return 0
        const v = reach - Math.max(0, t)
        return reach - Math.pow(Math.max(0, Math.pow(reach, 4) - Math.pow(v, 4)), 0.25)
    }
    function squircled(s: var, exact: bool, out: var): void {
        const i = root.inset
        const m = Math.min(s.width, s.height) / 2
        const reach = Math.min(Number(s.radius ?? 0) * root.squircleReach, m) - i
        const top = root.lo(s.y + i), bottom = root.hi(s.y + s.height - i)
        const left = root.lo(s.x + i), right = root.hi(s.x + s.width - i)
        if (bottom <= top || right <= left) return
        const span = n => {
            const cy = n + 0.5
            const k = root.squircleInset(Math.min(cy - s.y - i, s.y + s.height - i - cy), reach)
            return [Math.max(left, root.hi(s.x + i + k)), Math.min(right, root.lo(s.x + s.width - i - k))]
        }
        const step = exact ? 1 : 3
        let open = null
        const flush = () => {
            if (open && open.b > open.a) out.push({ x: open.a, y: open.from, width: open.b - open.a, height: open.to - open.from })
            open = null
        }
        for (let n = top; n < bottom; n += step) {
            const end = Math.min(bottom, n + step)
            let a = left, b = right
            for (let q = n; q < end; q++) {
                const row = span(q)
                a = Math.max(a, row[0])
                b = Math.min(b, row[1])
            }
            if (open && open.a === a && open.b === b) open.to = end
            else { flush(); open = { a: a, b: b, from: n, to: end } }
        }
        flush()
    }
    // IrisField.cutMask, for the same window: which corners a welded body's blade takes (0 the Design's pair).
    function cutMaskOf(s: var): int {
        const list = !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
        if (!root.framed || !list.includes("frame")) return 0
        const reach = root.band + 2
        if (s.y + s.height >= root.windowHeight - reach) return -1
        if (s.y <= reach) return -2
        if (s.x + s.width >= root.windowWidth - reach) return -3
        if (s.x <= reach) return -4
        return 0
    }
    // Bodies and runs live in pools of child regions, grown on demand and emptied when unused. Ninety-six bound
    // pieces re-read the whole table on every build, a moving body's every frame, for the handful a scene uses.
    readonly property Component pieceComponent: Component { Piece {} }
    property var piecePool: []
    property int piecesPlaced: 0
    function placePieces(): void {
        const pieces = root.built?.bodies ?? [], pool = root.piecePool
        while (pool.length < pieces.length) {
            const made = root.pieceComponent.createObject(root)
            root.regions.push(made)
            pool.push(made)
        }
        const reach = Math.max(root.piecesPlaced, pieces.length)
        for (let n = 0; n < reach; n++) pool[n].p = pieces[n] ?? null
        root.piecesPlaced = pieces.length
    }
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
        // A body that sits where it sat in the last build is still: its own rows and its joins with still bodies are
        // exact at once, from the cache. Only what moves is walked coarse, so one moving body (a visualizer, a banner)
        // no longer keeps every other contour on three-row stairs until everything rests.
        const before = root.memo.keys ?? {}, keys = {}
        const still = s => { const key = root.bodyKey(s); keys[key] = true; return before[key] === true }
        const rowsCache = root.memo.rows ?? {}, rowsKept = {}
        const b = root.band
        root.memo.frame = { x: b, y: b, width: root.windowWidth - 2 * b, height: root.windowHeight - 2 * b, radius: root.cornerRadius }
        const cut = IrisStyle.fieldChamfer ? IrisStyle.chamferCut : 0
        const stillOf = {}
        for (const s of list) stillOf[root.bodyKey(s)] = still(s)
        for (const s of list) {
            const i = root.inset
            const mine = exact || stillOf[root.bodyKey(s)]
            if (cut > 0 || root.squircles(s)) {
                const key = root.bodyKey(s) + "," + cut + "," + root.cutMaskOf(s)
                let rows = mine ? rowsCache[key] : null
                if (!rows) {
                    rows = []
                    if (cut > 0) root.chamfered(s, cut, mine, rows)
                    else root.squircled(s, mine, rows)
                }
                if (mine) rowsKept[key] = rows
                for (const q of rows) runs.push(q)
            } else out.push({ x: s.x + i, y: s.y + i, width: s.width - 2 * i, height: s.height - 2 * i, radius: Math.max(0, Number(s.radius ?? 0) - i) })
            const joins = !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
            for (const id of joins) {
                if (id === "frame") {
                    if (root.joinsFrame) root.joinRuns(s, null, mine, runs, cache, kept)
                } else if (byId[id]) root.joinRuns(s, byId[id], exact || (mine && stillOf[root.bodyKey(byId[id])]), runs, cache, kept)
            }
        }
        root.memo.runs = kept
        root.memo.rows = rowsKept
        root.memo.keys = keys
        root.frameCuts(runs)
        return { bodies: out.slice(0, 70), runs: runs }
    }




    // A chamfered Design's frame opening (IrisField.frag frameBox) is square at the upper-left and lower-right and cut at
    // the other two by a blade the size the round corner would have been. A round hole here blurred a curved patch into
    // the square corners, past any band, and left the band's blades unblurred. The blades' rows are held half a pixel
    // inside the drawn edge along its normal, as a cut body's are.
    function frameCuts(runs: var): void {
        if (root.framed && !IrisStyle.fieldChamfer) { root.frameShoulders(runs); return }
        if (!root.framed || !IrisStyle.fieldChamfer) return
        const edge = root.hi(root.band - root.inset)
        const x0 = edge, y0 = edge
        const x1 = Math.round(root.windowWidth) - edge, y1 = Math.round(root.windowHeight) - edge
        const c = Math.min(root.cornerRadius, (x1 - x0) / 2, (y1 - y0) / 2)
        const lean = root.inset * Math.SQRT2
        for (let n = y0; n < y0 + Math.ceil(c); n++) {
            const reach = c - (n + 0.5 - y0) - lean
            const a = root.hi(x1 - reach)
            if (reach > 0 && a < x1) runs.push({ x: a, y: n, width: x1 - a, height: 1 })
        }
        for (let n = y1 - Math.ceil(c); n < y1; n++) {
            const reach = c - (y1 - n - 0.5) - lean
            const b = root.lo(x0 + reach)
            if (reach > 0 && b > x0) runs.push({ x: x0, y: n, width: b - x0, height: 1 })
        }
    }

    // A round Design's opening is a squircle too (IrisField.frag frameBox): the band reaches further in along its
    // shoulders than the round hole cut from the region, so those rows of band are put back, held half a pixel inside
    // the drawn edge.
    function frameShoulders(runs: var): void {
        const edge = root.hi(root.band - root.inset)
        const x1 = Math.round(root.windowWidth) - edge, y1 = Math.round(root.windowHeight) - edge
        const m = Math.min(root.windowWidth - 2 * root.band, root.windowHeight - 2 * root.band) / 2
        const r = Math.min(root.cornerRadius, m)
        if (r < 0.5 || r >= m - 0.5) return
        const reach = Math.min(r * root.squircleReach, m)
        const band = root.band, far = root.windowHeight - band
        for (let n = edge; n < edge + Math.ceil(reach); n++) {
            for (const row of [n, y1 - 1 - (n - edge)]) {
                const t = row === n ? row + 0.5 - band : far - (row + 0.5)
                const k = root.squircleInset(t, reach) - root.inset
                if (k <= 0) continue
                const a = root.hi(band + k), b = root.lo(root.windowWidth - band - k)
                if (a > edge) runs.push({ x: edge, y: row, width: a - edge, height: 1 })
                if (b < x1) runs.push({ x: b, y: row, width: x1 - b, height: 1 })
            }
        }
    }

    component Piece: Region {
        id: piece
        property var p: null
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
            // Concentric with the frame's inner corner: the hole is grown by the pixel rounding of its edge. A chamfered
            // Design's opening is square, its two blades put back as rows (frameCuts).
            radius: IrisStyle.fieldChamfer ? 0 : Math.round(root.cornerRadius + root.band - edge)
        }
    }
    // Empty: its only job is to make the region change, which schedules the window's polish.
    Region { id: poke; width: 0; height: 0 }
}
