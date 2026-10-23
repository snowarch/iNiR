pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

// Arranging widgets as a place of its own: the desktop recedes into a card between what a family puts above and below
// it, and the windows of that workspace wait on an empty one until Done. A family that wants the card writes each
// output's stage (its own spring and the room its head and shelf take); with nobody writing, the desktop stays full
// size and arranging happens in place, as before.
Singleton {
    id: root

    // output -> { progress, top, bottom }: progress 0 is the desktop, 1 the card; top/bottom are screen px.
    property var stages: ({})
    readonly property real gap: 22

    function setStage(output: string, progress: real, top: real, bottom: real): void {
        const now = root.stages[output]
        if (now && now.progress === progress && now.top === top && now.bottom === bottom)
            return
        const next = Object.assign({}, root.stages)
        if (progress <= 0)
            delete next[output]
        else
            next[output] = { progress: progress, top: top, bottom: bottom }
        root.stages = next
    }

    // Where the desktop of a w x h output sits right now: offset and scale about its top-left corner. The card keeps
    // the screen's proportions and is the biggest copy that fits between the reserves.
    function cardFor(output: string, w: real, h: real): var {
        const stage = root.stages[output]
        if (!stage || w <= 0 || h <= 0)
            return { x: 0, y: 0, s: 1, p: 0 }
        const top = stage.top + root.gap
        const bottom = h - stage.bottom - root.gap
        const s = Math.max(0.2, Math.min((w - 4 * root.gap) / w, (bottom - top) / h))
        const p = stage.progress
        const x = (w - w * s) / 2
        const y = top + Math.max(0, (bottom - top - h * s) / 2)
        return { x: x * p, y: y * p, s: 1 + (s - 1) * p, p: p }
    }

    // ── Windows wait on an empty workspace while the desktop is arranged ──
    property int parkedFrom: -1
    property int parkedOn: -1
    property string parkedOutput: ""

    function park(output: string): void {
        if (!CompositorService.isNiri || root.parkedFrom >= 0)
            return
        const spaces = Object.values(NiriService.workspaces ?? {}).filter(ws => ws?.output === output)
        const active = spaces.find(ws => ws.is_active)
        if (!active || !NiriService.hasWindowsOnActiveWorkspace(output))
            return
        const windows = Array.isArray(NiriService.windows) ? NiriService.windows : []
        const empty = spaces.filter(ws => !windows.some(win => win?.workspace_id === ws.id))
            .sort((a, b) => b.idx - a.idx)[0]
        if (!empty)
            return
        root.parkedFrom = active.id
        root.parkedOn = empty.id
        root.parkedOutput = output
        NiriService.switchToWorkspaceById(empty.id)
    }

    // Back where the person was, unless they went somewhere else meanwhile.
    function unpark(): void {
        const from = root.parkedFrom
        const on = root.parkedOn
        const output = root.parkedOutput
        root.parkedFrom = -1
        root.parkedOn = -1
        root.parkedOutput = ""
        if (from < 0)
            return
        const active = Object.values(NiriService.workspaces ?? {}).find(ws => ws?.is_active && ws.output === output)
        if (active && active.id === on)
            NiriService.switchToWorkspaceById(from)
    }
}
