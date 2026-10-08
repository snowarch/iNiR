pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.iris.frame
import qs.modules.iris.style

// The compositor's blur for the part of the music frame that moves. The chassis region holds the frame at rest, the
// bodies and their joins: some five hundred child regions that Quickshell unites again on every change, which at
// the display rate saturated the GUI thread. Each side that swells gets a strip of its own below the chassis (mapped
// before it; Niri stacks a layer's surfaces in mapping order) whose region holds only what the swell adds: the band
// past its resting line, its moving corners and the fillets it makes against a body, the pixels the field draws
// (IrisField.frag), found per line with the field's own distance.
Scope {
    id: root

    property var screen: null
    // The compositor-glass bodies the chassis publishes (their joins to the frame make fillets that move too).
    property var shapes: []
    // True while the frame is compositor glass and the music moves it.
    property bool active: false
    property vector4d edgeWave: Qt.vector4d(0, 0, 0, 0)
    property real waveClock: 0
    property real smoothing: 0
    property real band: IrisFrame.band
    property real cornerRadius: IrisFrame.cornerRadius
    readonly property real inset: 0.5
    readonly property real windowWidth: root.screen?.width ?? 0
    readonly property real windowHeight: root.screen?.height ?? 0
    // Fixed so a layer surface never resizes per frame: the band, the widest swell, the corner and a fillet.
    readonly property int depth: Math.ceil(root.band + 18 * IrisStyle.density * 3 + root.cornerRadius + 1.25 * 64 + 8)
    readonly property bool waving: root.active && (root.edgeWave.x > 0.01 || root.edgeWave.y > 0.01
        || root.edgeWave.z > 0.01 || root.edgeWave.w > 0.01)
    function lo(v: real): int { return Math.floor(v - 0.5) + 1 }
    function hi(v: real): int { return Math.ceil(v - 0.5) }

    // The chassis maps once this is true, so it lands above the strips: every strip has put one frame on screen, or
    // the fallback ran out (a strip that never draws must not keep the chassis away).
    readonly property bool ready: root.fallbackDone || (leftStrip.drawn && rightStrip.drawn && topStrip.drawn && bottomStrip.drawn)
    property bool fallbackDone: false
    property Timer fallback: Timer { interval: 300; running: true; onTriggered: root.fallbackDone = true }

    // Once a frame: IrisFramePulse moves the level, then the phase, on every tick it runs; the phase is the clock.
    onWaveClockChanged: root.place()
    onWavingChanged: root.place()

    readonly property var waveTables: ({ size: "", rows: null, columns: null })
    readonly property var waveEdges: ({})
    // The wave's two terms per pixel line, as IrisField.frag writes them (sin(n·f + t)), split into sin(n·f) and
    // cos(n·f) once per size: each frame is then products and sums, with no sine per line.
    function waveTable(count: int, f1: real, f2: real): var {
        const table = { s1: new Float64Array(count), c1: new Float64Array(count), s2: new Float64Array(count), c2: new Float64Array(count) }
        for (let n = 0; n < count; n++) {
            const c = n + 0.5
            table.s1[n] = Math.sin(c * f1); table.c1[n] = Math.cos(c * f1)
            table.s2[n] = Math.sin(c * f2); table.c2[n] = Math.cos(c * f2)
        }
        return table
    }
    // The field's frame with the wave and its smooth union with every body joined to it near this edge: the band,
    // its moving corners and the fillets it makes where it swells against a body. One closure per side, taking a
    // depth from that edge and a line, with no helper calls inside: this runs thousands of times a frame in QML's
    // engine, where each call and each Math.min is measurable.
    function waveCluster(bodies: var, alongY: var, alongX: var, g: var, vertical: bool, far: bool): var {
        const b = g.b, R = g.R, W = g.W, H = g.H, wx = g.wx, wy = g.wy, wz = g.wz, ww = g.ww
        const count = bodies.length, J = new Float64Array(count * 10)
        for (let n = 0; n < count; n++) {
            const s = bodies[n], hx = s.width / 2, hy = s.height / 2, r = Math.min(Number(s.radius ?? 0), hx, hy)
            const k = Math.max(0, Number(s.fuse ?? g.k)), reach = Math.ceil(1.25 * k) + 2, o = n * 10
            J[o] = s.x + hx; J[o + 1] = s.y + hy; J[o + 2] = hx - r; J[o + 3] = hy - r; J[o + 4] = r; J[o + 5] = k
            J[o + 6] = s.x - reach; J[o + 7] = s.y - reach; J[o + 8] = s.x + s.width + reach; J[o + 9] = s.y + s.height + reach
        }
        const depth = vertical ? W : H
        return (a, line) => {
            const d0 = far ? depth - 1 - a : a
            const px = vertical ? d0 : line, py = vertical ? line : d0
            const x = px + 0.5, y = py + 0.5, ay = alongY[py], ax = alongX[px]
            const lx = b + wx * ay, ly = b + wy * ax, hxp = W - b - wz * ay, hyp = H - b - ww * ax
            let halfX = (hxp - lx) / 2, halfY = (hyp - ly) / 2
            if (halfX < 0) halfX = 0
            if (halfY < 0) halfY = 0
            let r = R < halfX ? R : halfX
            if (halfY < r) r = halfY
            let qx = x - (lx + hxp) / 2, qy = y - (ly + hyp) / 2
            qx = (qx < 0 ? -qx : qx) - (halfX - r); qy = (qy < 0 ? -qy : qy) - (halfY - r)
            let ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0, m = qx > qy ? qx : qy
            const f = -(Math.sqrt(ox * ox + oy * oy) + (m < 0 ? m : 0) - r)
            let d = f
            for (let n = 0; n < count; n++) {
                const o = n * 10
                if (x < J[o + 6] || x > J[o + 8] || y < J[o + 7] || y > J[o + 9]) continue
                qx = x - J[o]; qy = y - J[o + 1]
                qx = (qx < 0 ? -qx : qx) - J[o + 2]; qy = (qy < 0 ? -qy : qy) - J[o + 3]
                ox = qx > 0 ? qx : 0; oy = qy > 0 ? qy : 0; m = qx > qy ? qx : qy
                const body = Math.sqrt(ox * ox + oy * oy) + (m < 0 ? m : 0) - J[o + 4]
                const k = J[o + 5]
                let u
                if (k > 0.001) {
                    let h = 0.5 + 0.5 * (body - f) / k
                    h = h < 0 ? 0 : h > 1 ? 1 : h
                    u = body + (f - body) * h - k * h * (1 - h)
                } else u = f < body ? f : body
                if (u < d) d = u
            }
            return d
        }
    }
    // Per pixel line from each edge that swells, the last pixel whose centre the cluster holds (the same centre rule
    // as every body), consecutive lines with the same reach as one rect. Past `cap` a body's own rect holds it. Along
    // the straight run of a side, away from corners and joined bodies, that pixel is the band's inner line itself.
    function waveRuns(): var {
        const out = { left: [], right: [], top: [], bottom: [] }
        if (!root.waving) return out
        const wave = root.edgeWave, t = root.waveClock
        const g = { b: root.band, R: root.cornerRadius, W: Math.round(root.windowWidth), H: Math.round(root.windowHeight),
            wx: wave.x, wy: wave.y, wz: wave.z, ww: wave.w, k: root.smoothing }
        const b = g.b, W = g.W, H = g.H, inset = root.inset
        const key = W + "x" + H
        const tables = root.waveTables
        if (tables.size !== key) {
            tables.size = key
            tables.rows = root.waveTable(H, 0.011, 0.027)
            tables.columns = root.waveTable(W, 0.009, 0.023)
        }
        // alongY: 0.60 + 0.24 sin(y·0.011 + t) + 0.16 sin(y·0.027 − 1.4t); alongX: … sin(x·0.009 − t) … sin(x·0.023 + 1.2t).
        // Scratch reused from frame to frame (one allocation per size, not per frame).
        if (!tables.alongY || tables.alongY.length !== H) { tables.alongY = new Float64Array(H); tables.busyH = new Uint8Array(H); tables.stopH = new Int32Array(H) }
        if (!tables.alongX || tables.alongX.length !== W) { tables.alongX = new Float64Array(W); tables.busyW = new Uint8Array(W); tables.stopW = new Int32Array(W) }
        const alongY = tables.alongY, alongX = tables.alongX
        const ct = Math.cos(t), st = Math.sin(t), c14 = Math.cos(1.4 * t), s14 = Math.sin(1.4 * t), c12 = Math.cos(1.2 * t), s12 = Math.sin(1.2 * t)
        const rows = tables.rows, columns = tables.columns
        // A side that does not swell never reads its line's term.
        if (g.wx > 0.01 || g.wz > 0.01) for (let n = 0; n < H; n++)
            alongY[n] = 0.60 + 0.24 * (rows.s1[n] * ct + rows.c1[n] * st) + 0.16 * (rows.s2[n] * c14 - rows.c2[n] * s14)
        if (g.wy > 0.01 || g.ww > 0.01) for (let n = 0; n < W; n++)
            alongX[n] = 0.60 + 0.24 * (columns.s1[n] * ct - columns.c1[n] * st) + 0.16 * (columns.s2[n] * c12 + columns.c2[n] * s12)
        // Where a fillet can hold a pixel: a smooth union is never below min(frame, body) − k/4, and it is the frame
        // itself once the body is k further away, so a body reaches 1.25 k past its edge.
        const spread = s => Math.ceil(1.25 * Math.max(0, Number(s.fuse ?? g.k))) + 2
        const joined = []
        let k2 = 2 * g.k + 2
        for (const s of root.shapes ?? []) {
            const joins = !s.joins ? [] : Array.isArray(s.joins) ? s.joins : [s.joins]
            if (joins.includes("frame")) { joined.push(s); k2 = Math.max(k2, spread(s)) }
        }
        // The inner corner moves with the swell, so near a corner the band reaches its radius further in.
        const cap = Math.ceil(b + Math.max(g.wx, g.wy, g.wz, g.ww) + g.R + k2 + 2)
        const rest = root.hi(b - inset)
        // vertical: a left or right side, walked per row; otherwise top or bottom, per column.
        // The chassis region already holds the resting band (its hole is concentric with the frame's inner corner)
        // and each body's own rect: a run starts where the ring ends and stops before a body, so no pixel is blurred
        // twice. Where the ring's rounded hole is rasterised a pixel either way, the run takes one pixel more.
        const ringEdge = rest, ringRadius = Math.round(g.R + b - ringEdge)
        const ringEnd = (n, count) => {
            const c = n + 0.5, r = ringRadius
            const into = c < ringEdge + r ? ringEdge + r - c : c > count - ringEdge - r ? c - (count - ringEdge - r) : -1
            if (into < 0) return ringEdge
            return Math.max(ringEdge, Math.floor(ringEdge + r - Math.sqrt(Math.max(0, r * r - into * into))) - 1)
        }
        const side = (vertical, far, amp, sink, memoPrev) => {
            const count = vertical ? H : W
            // Only a body within reach of this edge moves its line; the rest are held by their own rects.
            const bodies = joined.filter(s => {
                const near = cap + spread(s)
                return vertical ? (far ? s.x + s.width > W - near : s.x < near) : (far ? s.y + s.height > H - near : s.y < near)
            })
            const distance = root.waveCluster(bodies, alongY, alongX, g, vertical, far)
            // Past the corners (the other band at its widest and the radius) the side is straight.
            const across = b + (vertical ? Math.max(g.wy, g.ww) : Math.max(g.wx, g.wz)) + g.R + 4
            // A corner line reaches the moved inner corner; a line past a body the body's fillet.
            const cornerCap = Math.min(cap, Math.ceil(b + amp + g.R + 2))
            const busy = vertical ? tables.busyH : tables.busyW
            busy.fill(0)
            for (const s of bodies) {
                const k = spread(s)
                const lo = Math.max(0, Math.floor((vertical ? s.y : s.x) - k)), hi = Math.min(count - 1, Math.ceil((vertical ? s.y + s.height : s.x + s.width) + k))
                for (let n = lo; n <= hi; n++) busy[n] = 1
            }
            const along = vertical ? alongY : alongX
            // Each line's edge from the last frame, per side.
            const memoKey = (vertical ? (far ? "right" : "left") : (far ? "bottom" : "top")) + count
            let memo = root.waveEdges[memoKey]
            if (!memo) { memo = new Int32Array(count); root.waveEdges[memoKey] = memo }
            // A line is one span [0, end] in pixels from the edge (end −1 for none), or, near a corner where the other
            // band swells, a list of spans. Consecutive lines with the same answer are one rect.
            // Pixels from this edge where a body's own rect starts, per line (the chassis holds it).
            const stop = vertical ? tables.stopH : tables.stopW
            stop.fill(1 << 20)
            for (const s of bodies) {
                const i0 = Math.max(0, root.lo((vertical ? s.y : s.x) + inset)), i1 = Math.min(count, root.hi((vertical ? s.y + s.height : s.x + s.width) - inset))
                const at = vertical ? (far ? W - root.hi(s.x + s.width - inset) : root.lo(s.x + inset))
                    : (far ? H - root.hi(s.y + s.height - inset) : root.lo(s.y + inset))
                for (let n = i0; n < i1; n++) if (at < stop[n]) stop[n] = at
            }
            const push = (a0, a1, from, len) => {
                if (a1 < a0) return
                const reach = a1 - a0 + 1
                sink.push(vertical ? { x: far ? W - a0 - reach : a0, y: from, width: reach, height: len }
                    : { x: from, y: far ? H - a0 - reach : a0, width: len, height: reach })
            }
            const same = (p, q) => {
                if (p === q) return true
                if (p === null || q === null || p.length !== q.length) return false
                for (let m = 0; m < p.length; m++) if (p[m] !== q[m]) return false
                return true
            }
            let from = 0, openEnd = -2, openFirst = 0, openList = null
            const flush = n => {
                if (openList !== null) for (let m = 0; m < openList.length; m += 2) push(openList[m], openList[m + 1], from, n - from)
                else if (openEnd >= 0) push(openFirst, openEnd, from, n - from)
            }
            // Lines on the straight run, away from corners and bodies: most of a side, so they take a loop of
            // their own with nothing but the band's inner line (QML's engine pays for every branch and call).
            const straightLo = Math.max(rest, Math.floor(across - 0.5) + 1), straightHi = Math.min(count - rest, Math.ceil(count - across - 0.5))
            const inner = b - 2 * inset
            for (let n = 0; n <= count; n++) {
                if (n >= straightLo && n < straightHi && busy[n] === 0) {
                    let end = Math.ceil(inner + amp * along[n]) - 1
                    const prev = memoPrev[n]
                    memoPrev[n] = end
                    if (prev < end) end = prev
                    if (end < ringEdge) end = -1
                    if (end === openEnd && openFirst === ringEdge && openList === null) continue
                    flush(n)
                    from = n; openEnd = end; openFirst = ringEdge; openList = null
                    continue
                }
                let end = -1, list = null, spans = null
                if (n < count && n >= rest && n < count - rest) {
                    const c = n + 0.5
                    if (c > across && c < count - across && busy[n] === 0) {
                        end = Math.ceil(b + amp * along[n] - 2 * inset) - 1
                        if (end < 0) end = -1
                    } else {
                        const inCorner = !(c > across && c < count - across)
                        // Islands only come from the other band swelling; otherwise every line is one span.
                        const corner = inCorner && (vertical ? Math.max(g.wy, g.ww) : Math.max(g.wx, g.wz)) > 0.01
                        const lineCap = inCorner ? (busy[n] === 0 ? cornerCap : cap) : cap
                        // One span from the edge (a body melts into the band; a corner is one arc unless the other
                        // band swells too): the line's edge from the last frame, moved to where it is now. The wave
                        // moves it about a pixel a frame, so this is two or three evaluations a line. Below it the
                        // frame alone is a floor a union never loses (off a corner), or the edge's own pixel.
                        let a = 0, start = -1
                        spans = []
                        if (!corner) {
                            const floor = inCorner ? 0 : Math.max(0, Math.min(lineCap, Math.ceil(b + amp * along[n] - 2 * inset) - 1))
                            let at = memo[n]
                            at = at < floor ? floor : at > lineCap ? lineCap : at
                            if (at === floor || distance(at, n) < -inset) {
                                while (at < lineCap && distance(at + 1, n) < -inset) at++
                            } else {
                                while (at - 1 > floor && !(distance(at - 1, n) < -inset)) at--
                                at--
                            }
                            memo[n] = at
                            end = at
                            a = lineCap + 1
                        }
                        // Near a corner the scan steps by distance and keeps every span.
                        // Every step moves a on by at least one pixel and lineCap bounds it: the scan always ends.
                        while (a <= lineCap) {
                            const d = distance(a, n)
                            if (d < -inset) {
                                if (start < 0) start = a
                                const jump = Math.floor((-d - inset) * 0.8)
                                if (jump > 1 && a + jump <= lineCap) { a += jump; continue }
                                if (a === lineCap || !(distance(a + 1, n) < -inset)) {
                                    spans.push(start, a); start = -1
                                    a += 2; continue
                                }
                                a++
                            } else {
                                a += Math.max(1, Math.floor((d + inset) * 0.8))
                            }
                        }
                        if (start >= 0) spans.push(start, lineCap)
                        if (corner) list = spans
                    }
                }
                // What this window adds to the chassis: past the ring, short of a body, and no further than it was a
                // frame ago, so a frame between the two windows never shows blur the field has not drawn yet.
                let first = 0
                if (n < count) {
                    const held = end
                    if (end >= 0) {
                        const prev = memoPrev[n]
                        memoPrev[n] = held
                        if (prev < end) end = prev
                        if (stop[n] - 1 < end) end = stop[n] - 1
                        const c = n + 0.5
                        first = c >= ringEdge + ringRadius && c <= count - ringEdge - ringRadius ? ringEdge : ringEnd(n, count)
                        if (end < first) end = -1
                    } else memoPrev[n] = -1
                    if (list !== null) {
                        const clipped = []
                        for (let m = 0; m < list.length; m += 2) {
                            const a0 = Math.max(list[m], ringEnd(n, count)), a1 = Math.min(list[m + 1], stop[n] - 1)
                            if (a1 >= a0) clipped.push(a0, a1)
                        }
                        list = clipped
                    }
                }
                if (end === openEnd && first === openFirst && (list === openList || same(list, openList))) continue
                flush(n)
                from = n
                openEnd = end
                openFirst = first
                openList = list
            }
        }
        const prevOf = (key, count) => {
            let m = root.waveEdges["prev" + key + count]
            if (!m) { m = new Int32Array(count).fill(-1); root.waveEdges["prev" + key + count] = m }
            return m
        }
        if (g.wx > 0.01) side(true, false, g.wx, out.left, prevOf("left", H))
        if (g.wz > 0.01) side(true, true, g.wz, out.right, prevOf("right", H))
        if (g.wy > 0.01) side(false, false, g.wy, out.top, prevOf("top", W))
        if (g.ww > 0.01) side(false, true, g.ww, out.bottom, prevOf("bottom", W))
        return out
    }
    function place(): void {
        const runs = root.waveRuns()
        leftStrip.publish(runs.left)
        rightStrip.publish(runs.right)
        topStrip.publish(runs.top)
        bottomStrip.publish(runs.bottom)
    }

    component Strip: PanelWindow {
        id: strip
        required property string edge
        readonly property bool vertical: strip.edge === "left" || strip.edge === "right"
        screen: root.screen
        // Mapped for as long as the chassis is, and before it: remapped later it would sit above the chassis and
        // blur the band the chassis paints.
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        mask: Region {}
        WlrLayershell.namespace: "quickshell:iris-wave"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            left: strip.edge !== "right"
            right: strip.edge !== "left"
            top: strip.edge !== "bottom"
            bottom: strip.edge !== "top"
        }
        implicitWidth: strip.vertical ? root.depth : 0
        implicitHeight: strip.vertical ? 0 : root.depth
        readonly property Component runComponent: Component { Region {} }
        property var pool: []
        Region { id: stripRegion }
        property bool published: false
        property bool drawn: false
        Connections {
            target: strip.contentItem?.Window.window ?? null
            enabled: !strip.drawn
            function onFrameSwapped(): void { strip.drawn = true }
        }
        // Runs arrive in output pixels; the strip sits on its edge.
        function publish(runs: var): void {
            const ox = strip.edge === "right" ? Math.round(root.windowWidth) - root.depth : 0
            const oy = strip.edge === "bottom" ? Math.round(root.windowHeight) - root.depth : 0
            const pool = strip.pool
            while (pool.length < runs.length) {
                const made = strip.runComponent.createObject(stripRegion)
                stripRegion.regions.push(made)
                pool.push(made)
            }
            const effect = strip.BackgroundEffect
            const wanted = runs.length > 0
            if (strip.published) effect.blurRegion = null
            for (let n = 0; n < pool.length; n++) {
                const q = runs[n] ?? null, r = pool[n]
                const x = q ? q.x - ox : 0, y = q ? q.y - oy : 0, width = q ? q.width : 0, height = q ? q.height : 0
                if (r.x !== x) r.x = x
                if (r.y !== y) r.y = y
                if (r.width !== width) r.width = width
                if (r.height !== height) r.height = height
            }
            if (wanted) effect.blurRegion = stripRegion
            if (wanted || strip.published) {
                // The region is double-buffered: it lands with the strip's next commit, so the strip draws one.
                const quick = strip.contentItem?.Window.window
                if (quick) quick.update()
            }
            strip.published = wanted
        }
        Component.onDestruction: strip.BackgroundEffect.blurRegion = null
    }

    Strip { id: leftStrip; edge: "left" }
    Strip { id: rightStrip; edge: "right" }
    Strip { id: topStrip; edge: "top" }
    Strip { id: bottomStrip; edge: "bottom" }
}
