pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import "root:modules/common/functions/ArrangeMath.js" as AM

// Arranging the desktop: the state every widget and each output's guides share. Widgets report where they are
// (plain writes, no bindings re-read the map), a carried one asks `snap()` on every move (neighbours, the screen's
// centre, the grid: O(n)) and `end()` on release, which settles it beside its neighbours when it was let go on top of
// one. The maths is ArrangeMath.js. The guides tell the story by `phase`:
//   drag     the grid shows, the carried widget is pulled onto lines, what it lines up with is drawn lightly
//   confirm  released: the lines it met run across the screen, named; the widgets it lined up with flare
//   fade     everything eases out, then idle
Singleton {
    id: root

    readonly property int slotCount: 6
    readonly property int holdMs: 900
    readonly property int fadeMs: 320
    readonly property int gap: 16
    readonly property int grid: Config.getNestedValue("background.widgets.editGrid.snap", true)
        ? Math.max(4, Number(Config.getNestedValue("background.widgets.editGrid.size", 32))) : 0

    property string phase: "idle"
    property string dragOutput: ""
    property string dragKey: ""
    property var slots: [null, null, null, null, null, null]
    // The released rect (desktop px) and who lined up with it, for the rails and the flare.
    property var dropRect: null
    property var matched: ({})
    property int confirmSerial: 0

    // output -> key -> rect, and output -> room ({ w, h, left, top, right, bottom }).
    property var _rects: ({})
    property var rooms: ({})

    function setRoom(output: string, room: var): void {
        const next = Object.assign({}, root.rooms)
        if (room) next[output] = room
        else delete next[output]
        root.rooms = next
    }
    // `stack`: the pages of one stack move together and never pull each other.
    function report(output: string, key: string, x: real, y: real, w: real, h: real, present: bool, stack: string): void {
        if (output.length === 0 || key.length === 0)
            return
        const rects = root._rects[output] ?? (root._rects[output] = {})
        if (!present || w < 2 || h < 2) delete rects[key]
        else rects[key] = { id: key, x: x, y: y, w: w, h: h, stack: stack }
    }
    function rectOf(output: string, key: string): var { return root._rects[output]?.[key] ?? null }
    function othersOf(output: string, key: string, stack: string): var {
        const out = root.bodiesOf(output)
        const rects = root._rects[output] ?? {}
        for (const k in rects)
            if (k !== key && !(stack.length > 0 && rects[k].stack === stack)) out.push(rects[k])
        return out
    }

    // The shell's own bodies resting on each output, screen px: output -> owner -> [{ id, name, x, y, w, h, radius, joins, fuse }]
    // (`joins`: the screen edge a body is welded to, with a fillet of `fuse`).
    // Families write them at rest and never while arranging (their surfaces step aside or become the edit head then),
    // so the card shows and the maths keeps clear of where they live, not of where they went for the edit.
    property var bodies: ({})
    function setBodies(output: string, owner: string, list: var): void {
        if (output.length === 0 || owner.length === 0)
            return
        const now = root.bodies[output]?.[owner] ?? []
        const next = (list ?? []).filter(b => b && b.w >= 2 && b.h >= 2)
        if (JSON.stringify(now) === JSON.stringify(next))
            return
        const all = Object.assign({}, root.bodies)
        const mine = Object.assign({}, all[output] ?? {})
        if (next.length > 0) mine[owner] = next
        else delete mine[owner]
        all[output] = mine
        root.bodies = all
    }
    // Flat, with an id no widget key can take ("@island") and `fixed` so ArrangeMath matches no size to them.
    function bodiesOf(output: string): var {
        const out = []
        const owners = root.bodies[output] ?? {}
        for (const owner in owners)
            for (const b of owners[owner])
                out.push({ id: "@" + b.id, name: b.name ?? "", x: b.x, y: b.y, w: b.w, h: b.h, radius: b.radius ?? 0,
                    joins: b.joins ?? "", fuse: b.fuse ?? 0, fixed: true })
        return out
    }
    // Where a widget asked to go to x,y rests, and what it lines up with there; changes nothing on screen.
    function plan(output: string, key: string, x: real, y: real, w: real, h: real, stack: string): var {
        const room = root.roomOf(output)
        const others = root.othersOf(output, key, stack)
        const s = root.grid >= 0 ? AM.snap({ id: key, x: x, y: y, w: w, h: h }, others, room, root.grid, root.gap) : { x: x, y: y }
        const spot = AM.settle({ id: key, x: s.x, y: s.y, w: w, h: h }, others, room, root.gap)
        const rel = AM.relations({ id: key, x: spot.x, y: spot.y, w: w, h: h }, others, room, root.gap)
        const met = {}
        for (const line of rel.lines)
            for (const id of line.ids) met[id] = true
        return { x: spot.x, y: spot.y, guides: rel.lines, neighbours: Object.keys(met) }
    }
    function roomOf(output: string): var {
        return root.rooms[output] ?? { w: 1920, h: 1080, left: 0, top: 0, right: 1920, bottom: 1080 }
    }

    // ── A carry ──
    function begin(output: string, key: string): void {
        holdTimer.stop()
        fadeTimer.stop()
        root.dragOutput = output
        root.dragKey = key
        root.dropRect = null
        root.matched = ({})
        root._liveSig = ""
        root.slots = [null, null, null, null, null, null]
        root.phase = "drag"
    }
    property string _liveSig: ""
    function _show(rect: var, others: var, room: var): var {
        const rel = AM.relations(rect, others, room, root.gap)
        const sig = AM.sig(rel.lines)
        if (sig !== root._liveSig) {
            root._liveSig = sig
            root.slots = AM.assignSlots(root.slots, rel.lines, root.slotCount)
        }
        return rel
    }
    // Where a widget carried to x,y goes now; `free` (Alt) only shows nothing and keeps the place.
    function snap(output: string, key: string, x: real, y: real, w: real, h: real, free: bool, stack: string): point {
        const room = root.roomOf(output)
        const others = root.othersOf(output, key, stack)
        const s = free ? { x: x, y: y } : AM.snap({ id: key, x: x, y: y, w: w, h: h }, others, room, root.grid, root.gap)
        if (root.phase === "drag" && root.dragKey === key && root.dragOutput === output) {
            if (free) {
                if (root._liveSig !== "") { root._liveSig = ""; root.slots = [null, null, null, null, null, null] }
            } else {
                root._show({ id: key, x: s.x, y: s.y, w: w, h: h }, others, room)
            }
        }
        return Qt.point(s.x, s.y)
    }
    // Released at x,y: where it rests (beside a neighbour when it was let go on one), and the confirmation.
    function end(output: string, key: string, x: real, y: real, w: real, h: real, free: bool, stack: string): var {
        const room = root.roomOf(output)
        const others = root.othersOf(output, key, stack)
        const spot = free ? { x: Math.round(x), y: Math.round(y), moved: false } : AM.settle({ id: key, x: x, y: y, w: w, h: h }, others, room, root.gap)
        if (root.dragKey !== key || root.dragOutput !== output)
            return spot
        const rect = { id: key, x: spot.x, y: spot.y, w: w, h: h }
        const rel = root._show(rect, others, room)
        const met = {}
        for (const line of rel.lines)
            for (const id of line.ids) met[id] = true
        for (const size of rel.sizes)
            for (const id of size.ids) met[id] = true
        root.matched = met
        root.dropRect = rect
        root.phase = "confirm"
        root.confirmSerial = root.confirmSerial + 1
        holdTimer.restart()
        return spot
    }
    function cancel(): void {
        holdTimer.stop()
        fadeTimer.stop()
        root.phase = "idle"
        root.dragKey = ""
        root.dragOutput = ""
        root.dropRect = null
        root.matched = ({})
        root._liveSig = ""
        root.slots = [null, null, null, null, null, null]
    }
    // "That one": the shelf points at a widget already out, and it flares where it sits.
    signal pinged(string output, string key)
    function ping(output: string, key: string): void { root.pinged(output, key) }

    Timer { id: holdTimer; interval: root.holdMs; onTriggered: { root.phase = "fade"; fadeTimer.restart() } }
    Timer { id: fadeTimer; interval: root.fadeMs + 40; onTriggered: root.cancel() }

    // Leaving edit mode wipes it all.
    readonly property bool _editing: GlobalStates.widgetEditMode
    on_EditingChanged: if (!root._editing) { root.cancel(); root._rects = ({}) }
}
