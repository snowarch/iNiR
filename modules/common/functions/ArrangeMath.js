.pragma library

// Arranging desktop widgets: pure maths on plain numbers in desktop px, free of QML so node can
// test it. A rect is { id, x, y, w, h }; a room is the canvas
// { w, h } plus the work area the widgets may rest in { left, top, right, bottom }.
//
// `others` may hold the shell's own bodies resting on the screen (`fixed`: the Island, the Dock, a bar): widgets
// line up with them and never rest under them, like with any neighbour.
//
// A widget has three lines per axis (left/centre/right, top/centre/bottom). Edges pair with edges,
// centres with centres, and one gutter beside a neighbour pairs with the edge that faces it.

var PULL_WIDGET = 10
var PULL_GRID = 7
var TOL = 1.0
var OVERHANG = 22

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v))
}

function bounds(room, axis, size) {
    var lo = axis === "x" ? room.left : room.top
    var hi = axis === "x" ? room.right : room.bottom
    return { lo: lo, hi: Math.max(lo, hi - size) }
}

// Every line a rect moving on `axis` may be pulled onto. `lead` pairs with the rect's start edge,
// `tail` with its end edge (gutters face one way), `edges` with either, `centres` with its middle.
function targets(axis, others, room, gap) {
    var size = axis === "x" ? room.w : room.h
    var lo = axis === "x" ? room.left : room.top
    var hi = axis === "x" ? room.right : room.bottom
    // The room's own sides pull twice: flush, and one gutter in.
    var t = { edges: [0, size, lo, hi], centres: [size / 2], lead: gap > 0 ? [lo + gap] : [], tail: gap > 0 ? [hi - gap] : [] }
    for (var i = 0; i < others.length; i++) {
        var o = others[i]
        var p = axis === "x" ? o.x : o.y
        var s = axis === "x" ? o.w : o.h
        t.edges.push(p, p + s)
        t.centres.push(p + s / 2)
        if (gap > 0) {
            t.lead.push(p + s + gap)
            t.tail.push(p - gap)
        }
    }
    return t
}

function pull(pos, size, t, grid, lo, hi) {
    var best = null
    function take(d) {
        if (Math.abs(d) <= PULL_WIDGET && (best === null || Math.abs(d) < Math.abs(best)))
            best = d
    }
    var i
    for (i = 0; i < t.edges.length; i++) {
        take(t.edges[i] - pos)
        take(t.edges[i] - (pos + size))
    }
    for (i = 0; i < t.centres.length; i++)
        take(t.centres[i] - (pos + size / 2))
    for (i = 0; i < t.lead.length; i++)
        take(t.lead[i] - pos)
    for (i = 0; i < t.tail.length; i++)
        take(t.tail[i] - (pos + size))
    if (best !== null)
        return { pos: clamp(pos + best, lo, hi), kind: "widget" }
    if (grid > 0) {
        var edges = [pos - lo, pos + size - lo]
        for (i = 0; i < edges.length; i++) {
            var d = Math.round(edges[i] / grid) * grid - edges[i]
            if (Math.abs(d) <= PULL_GRID && (best === null || Math.abs(d) < Math.abs(best)))
                best = d
        }
        if (best !== null)
            return { pos: clamp(pos + best, lo, hi), kind: "grid" }
    }
    return { pos: clamp(pos, lo, hi), kind: "" }
}

// Pulls again until nothing pulls further, so snapping a snapped place changes nothing.
function snapAxis(pos, size, t, grid, lo, hi) {
    var cur = pos
    var kind = ""
    for (var i = 0; i < 4; i++) {
        var r = pull(cur, size, t, grid, lo, hi)
        if (r.kind === "" || Math.abs(r.pos - cur) < 1e-9) {
            if (kind === "")
                kind = r.kind
            cur = r.pos
            break
        }
        kind = r.kind
        cur = r.pos
    }
    return { pos: Math.round(cur), kind: kind }
}

// A frame that cuts the room's corners at 45° (`room.corners`: [tl, tr, br, bl], each the least sum of the
// two gaps a rect keeps there) holds a rect off the cut: it steps out along the diagonal, half on each axis.
function cornered(x, y, w, h, room) {
    var keep = room.corners
    if (!keep)
        return { x: x, y: y }
    var l = x - room.left, t = y - room.top, r = room.right - x - w, b = room.bottom - y - h
    var gaps = [[l, t, 1, 1], [r, t, -1, 1], [r, b, -1, -1], [l, b, 1, -1]]
    for (var i = 0; i < 4; i++) {
        var need = (keep[i] || 0) - gaps[i][0] - gaps[i][1]
        if (need > 0) {
            x += gaps[i][2] * need / 2
            y += gaps[i][3] * need / 2
        }
    }
    var bx = bounds(room, "x", w)
    var by = bounds(room, "y", h)
    return { x: Math.round(clamp(x, bx.lo, bx.hi)), y: Math.round(clamp(y, by.lo, by.hi)) }
}

// Where a carried rect goes. `grid` 0 turns the lattice off (neighbours and the screen still pull).
function snap(rect, others, room, grid, gap) {
    var bx = bounds(room, "x", rect.w)
    var by = bounds(room, "y", rect.h)
    var sx = snapAxis(rect.x, rect.w, targets("x", others, room, gap), grid, bx.lo, bx.hi)
    var sy = snapAxis(rect.y, rect.h, targets("y", others, room, gap), grid, by.lo, by.hi)
    var c = cornered(sx.pos, sy.pos, rect.w, rect.h, room)
    return { x: c.x, y: c.y, kindX: c.x === sx.pos ? sx.kind : "", kindY: c.y === sy.pos ? sy.kind : "" }
}

function near(a, b) {
    return Math.abs(a - b) <= TOL
}

// What a rect lines up with right now: one line per shared line (edge, centre, gutter), running over
// every widget it joins (the screen's centre: all of it), and the widgets of the same size.
function relations(rect, others, room, gap) {
    var lines = []
    var axes = ["x", "y"]
    for (var ai = 0; ai < axes.length; ai++) {
        var vertical = axes[ai] === "x"
        var mp = vertical ? rect.x : rect.y
        var ms = vertical ? rect.w : rect.h
        var span = vertical ? room.h : room.w
        var mine = [
            { side: vertical ? "L" : "T", v: mp, centre: false },
            { side: "C", v: mp + ms / 2, centre: true },
            { side: vertical ? "R" : "B", v: mp + ms, centre: false }
        ]
        for (var mi = 0; mi < mine.length; mi++) {
            var m = mine[mi]
            var group = []
            var same = false
            for (var oi = 0; oi < others.length; oi++) {
                var o = others[oi]
                var op = vertical ? o.x : o.y
                var os = vertical ? o.w : o.h
                if (m.centre) {
                    if (near(m.v, op + os / 2))
                        group.push(o)
                } else if (near(m.v, op) || near(m.v, op + os)) {
                    group.push(o)
                    if ((m.side === "L" || m.side === "T") ? near(m.v, op) : near(m.v, op + os))
                        same = true
                }
            }
            var screen = m.centre && near(m.v, (vertical ? room.w : room.h) / 2)
            var lo = vertical ? room.left : room.top
            var hi = vertical ? room.right : room.bottom
            var side = !m.centre && ((m.side === "L" || m.side === "T") ? near(m.v, lo) : near(m.v, hi))
            if (group.length === 0 && !screen && !side)
                continue
            var from = vertical ? rect.y : rect.x
            var to = from + (vertical ? rect.h : rect.w)
            var ids = []
            for (var gi = 0; gi < group.length; gi++) {
                var g = group[gi]
                ids.push(g.id)
                var gf = vertical ? g.y : g.x
                from = Math.min(from, gf)
                to = Math.max(to, gf + (vertical ? g.h : g.w))
            }
            if (screen || (side && group.length === 0)) {
                from = 0
                to = span
            } else {
                from = Math.max(0, from - OVERHANG)
                to = Math.min(span, to + OVERHANG)
            }
            lines.push({
                key: (vertical ? "v" : "h") + ":" + m.side + ":" + Math.round(m.v * 10),
                vertical: vertical, at: m.v, from: from, to: to,
                kind: m.centre ? (screen && group.length === 0 ? "screen" : "centre")
                    : group.length === 0 ? "room" : (same ? "edge" : "flush"),
                side: m.side, ids: ids
            })
        }
    }
    // A gutter kept to a neighbour: a short tick across the gap.
    if (gap > 0) {
        for (var k = 0; k < others.length; k++) {
            var n = others[k]
            var overlapY = Math.min(rect.y + rect.h, n.y + n.h) - Math.max(rect.y, n.y)
            var overlapX = Math.min(rect.x + rect.w, n.x + n.w) - Math.max(rect.x, n.x)
            if (overlapY > 0 && (near(rect.x, n.x + n.w + gap) || near(rect.x + rect.w + gap, n.x))) {
                var gx0 = near(rect.x, n.x + n.w + gap) ? n.x + n.w : rect.x + rect.w
                lines.push({ key: "g:x:" + n.id, vertical: false, at: Math.max(rect.y, n.y) + overlapY / 2,
                    from: gx0, to: gx0 + gap, kind: "gutter", side: "G", ids: [n.id] })
            }
            if (overlapX > 0 && (near(rect.y, n.y + n.h + gap) || near(rect.y + rect.h + gap, n.y))) {
                var gy0 = near(rect.y, n.y + n.h + gap) ? n.y + n.h : rect.y + rect.h
                lines.push({ key: "g:y:" + n.id, vertical: true, at: Math.max(rect.x, n.x) + overlapX / 2,
                    from: gy0, to: gy0 + gap, kind: "gutter", side: "G", ids: [n.id] })
            }
        }
    }
    // One gutter in from a side of the room: the same tick.
    if (gap > 0) {
        var my = rect.y + rect.h / 2
        var mx = rect.x + rect.w / 2
        if (near(rect.x, room.left + gap))
            lines.push({ key: "g:x:L", vertical: false, at: my, from: room.left, to: room.left + gap, kind: "gutter", side: "G", ids: [] })
        if (near(rect.x + rect.w, room.right - gap))
            lines.push({ key: "g:x:R", vertical: false, at: my, from: room.right - gap, to: room.right, kind: "gutter", side: "G", ids: [] })
        if (near(rect.y, room.top + gap))
            lines.push({ key: "g:y:T", vertical: true, at: mx, from: room.top, to: room.top + gap, kind: "gutter", side: "G", ids: [] })
        if (near(rect.y + rect.h, room.bottom - gap))
            lines.push({ key: "g:y:B", vertical: true, at: mx, from: room.bottom - gap, to: room.bottom, kind: "gutter", side: "G", ids: [] })
    }
    var sizes = []
    var wIds = []
    var hIds = []
    for (var z = 0; z < others.length; z++) {
        // The shell's own bodies (the Island, the Dock) are no size to match.
        if (others[z].fixed) continue
        if (near(others[z].w, rect.w)) wIds.push(others[z].id)
        if (near(others[z].h, rect.h)) hIds.push(others[z].id)
    }
    if (wIds.length > 0) sizes.push({ axis: "w", ids: wIds })
    if (hIds.length > 0) sizes.push({ axis: "h", ids: hIds })
    return { lines: lines, sizes: sizes }
}

// Fixed slots so whatever draws a line keeps drawing the same one while it stays.
function assignSlots(prev, lines, n) {
    var next = []
    var byKey = {}
    var used = {}
    var i
    for (i = 0; i < n; i++) next.push(null)
    for (i = 0; i < lines.length; i++) byKey[lines[i].key] = lines[i]
    for (i = 0; i < n; i++) {
        if (prev && prev[i] && byKey[prev[i].key]) {
            next[i] = byKey[prev[i].key]
            used[prev[i].key] = true
        }
    }
    var j = 0
    for (i = 0; i < lines.length; i++) {
        if (used[lines[i].key]) continue
        while (j < n && next[j] !== null) j++
        if (j < n) next[j] = lines[i]
    }
    return next
}

function sig(lines) {
    var s = []
    for (var i = 0; i < lines.length; i++)
        s.push(lines[i].key + "@" + Math.round(lines[i].from) + "-" + Math.round(lines[i].to))
    return s.join("|")
}

function overlaps(a, b, gap) {
    return a.x < b.x + b.w + gap && a.x + a.w + gap > b.x && a.y < b.y + b.h + gap && a.y + a.h + gap > b.y
}

function free(rect, others, gap) {
    for (var i = 0; i < others.length; i++)
        if (overlaps(rect, others[i], gap))
            return false
    return true
}

// Where a rect may rest: where it is when nothing is under it, else the nearest free spot, tried
// beside each neighbour first (one gutter away, lined up with it or with where it was let go), so it
// sits with what is there. Only at the drop: O(n^2) on a handful of widgets.
function settle(rect, others, room, gap) {
    var bx = bounds(room, "x", rect.w)
    var by = bounds(room, "y", rect.h)
    var cx = clamp(rect.x, bx.lo, bx.hi), cy = clamp(rect.y, by.lo, by.hi)
    var at = cornered(cx, cy, rect.w, rect.h, room)
    var here = { x: at.x, y: at.y, w: rect.w, h: rect.h }
    var stepped = Math.round(cx) !== at.x || Math.round(cy) !== at.y
    // Touching counts as free; a hair less than the gutter is what a placed pair keeps.
    var test = Math.max(0, gap - 1)
    var blocking = []
    for (var b = 0; b < others.length; b++)
        if (overlaps(here, others[b], 0)) blocking.push(others[b])
    if (blocking.length === 0)
        return { x: Math.round(here.x), y: Math.round(here.y), moved: stepped }
    var best = null
    var bestD = Infinity
    function consider(x, y) {
        var p = cornered(clamp(x, bx.lo, bx.hi), clamp(y, by.lo, by.hi), rect.w, rect.h, room)
        var c = { x: p.x, y: p.y, w: rect.w, h: rect.h }
        if (!free(c, others, test))
            return
        var d = (c.x - here.x) * (c.x - here.x) + (c.y - here.y) * (c.y - here.y)
        if (d < bestD) {
            bestD = d
            best = c
        }
    }
    for (var i = 0; i < others.length; i++) {
        var n = others[i]
        var xs = [n.x + n.w + gap, n.x - rect.w - gap]
        var ys = [n.y + n.h + gap, n.y - rect.h - gap]
        for (var a = 0; a < 2; a++) {
            consider(xs[a], here.y)
            consider(xs[a], n.y)
            consider(xs[a], n.y + n.h - rect.h)
            consider(here.x, ys[a])
            consider(n.x, ys[a])
            consider(n.x + n.w - rect.w, ys[a])
        }
    }
    if (best === null) {
        // Crowded: a coarse lattice, then wherever it was let go.
        var step = Math.max(48, Math.round(Math.min(rect.w, rect.h) / 2))
        for (var y = by.lo; y <= by.hi; y += step)
            for (var x = bx.lo; x <= bx.hi; x += step)
                consider(x, y)
    }
    if (best === null)
        return { x: Math.round(here.x), y: Math.round(here.y), moved: false }
    return { x: Math.round(best.x), y: Math.round(best.y), moved: true }
}
