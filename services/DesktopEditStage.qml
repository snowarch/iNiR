pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

// Arranging widgets as a place of its own: the desktop recedes into a card between what a family puts above and below
// it, and the windows of that workspace wait on an empty one until Done. A family that wants the card writes each
// output's stage (its own spring and the room its head and shelf take); with nobody writing, the desktop stays full
// size and arranging happens in place, as before.
Singleton {
    id: root

    // output -> { progress, top, bottom }: progress 0 is the desktop, 1 the card; top/bottom are screen px.
    property var stages: ({})
    // Settings › Widgets: off, the desktop stays full size and widgets are arranged in place
    readonly property bool card: Config.options?.background?.widgets?.editCard ?? true
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
        if (!stage || w <= 0 || h <= 0 || !root.card)
            return { x: 0, y: 0, s: 1, p: 0 }
        const top = stage.top + root.gap
        const bottom = h - stage.bottom - root.gap
        const fit = Math.max(0.2, Math.min((w - 4 * root.gap) / w, (bottom - top) / h))
        // At rest the card is whole pixels from its corner to its size, so its picture lands texel on pixel.
        const s = Math.round(w * fit) / w
        const p = stage.progress
        const x = Math.round((w - w * s) / 2)
        const y = Math.round(top + Math.max(0, (bottom - top - h * s) / 2))
        return { x: x * p, y: y * p, s: 1 + (s - 1) * p, p: p }
    }

    // ── Who arranges each output ──
    // A family that hosts arranging on an output (its own shelf and head) says so; the shared editor (toolbar, library)
    // stays out of that output.
    property var hosts: ({})
    function setHost(output: string, on: bool): void {
        if (Boolean(root.hosts[output]) === on)
            return
        const next = Object.assign({}, root.hosts)
        if (on) next[output] = true
        else delete next[output]
        root.hosts = next
    }
    function hosted(output: string): bool { return Boolean(root.hosts[output]) }

    // ── A chosen widget's controls ──
    // A family that draws them at true size beside the card (iRiS's edit window) says so per output; the widget then
    // keeps its own sheet closed and hands itself over while its controls are open.
    property var sheetHosts: ({})
    function setSheetHost(output: string, on: bool): void {
        if (Boolean(root.sheetHosts[output]) === on)
            return
        const next = Object.assign({}, root.sheetHosts)
        if (on) next[output] = true
        else delete next[output]
        root.sheetHosts = next
    }
    function hostsSheet(output: string): bool { return Boolean(root.sheetHosts[output]) }
    // The chosen widget and the one under the pointer ({ output, widget } or null): their outfit (ring, name, keys)
    // is drawn by the host at true size over the card.
    property var chosen: null
    property var pointed: null
    function choose(output: string, widget: var, on: bool): void {
        if (on) root.chosen = { output: output, widget: widget }
        else if (root.chosen?.widget === widget) root.chosen = null
    }
    function point(output: string, widget: var, on: bool): void {
        if (on) root.pointed = { output: output, widget: widget }
        else if (root.pointed?.widget === widget) root.pointed = null
    }
    // { output, widget }: the widget whose controls are open, or null.
    property var inspected: null
    function inspect(output: string, widget: var, open: bool): void {
        if (open) root.inspected = { output: output, widget: widget }
        else if (root.inspected?.widget === widget) root.inspected = null
    }

    // ── Pictures of widgets, for the shelf ──
    // Each widget on the desktop takes its own picture when arranging starts and after it changes size (key -> { url,
    // width, height } in logical px), and leaves it on disk so the shelf shows a widget that is not out with its last look.
    // `look` names the look a family is wearing (scheme, Design): a picture from another look is not shown.
    // One at a time, a beat apart: every widget grabbing and writing its PNG on the same turn hitched the mode just after
    // it opened (11-02).
    property var _pictureQueue: []
    function askPicture(taker: var): void {
        if (!taker || root._pictureQueue.includes(taker)) return
        root._pictureQueue = root._pictureQueue.concat([taker])
        if (!pictureBeat.running) pictureBeat.start()
    }
    function forgetPicture(taker: var): void {
        root._pictureQueue = root._pictureQueue.filter(entry => entry !== taker)
    }
    Timer {
        id: pictureBeat
        interval: 90
        repeat: true
        onTriggered: {
            const next = root._pictureQueue[0]
            root._pictureQueue = root._pictureQueue.slice(1)
            if (next) next.takePicture()
            if (root._pictureQueue.length === 0) pictureBeat.stop()
        }
    }
    property string look: "default"
    property var pictures: ({})
    readonly property string pictureDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/inir/widget-pictures"
    // An empty url drops the live picture (its grab is gone); the shelf falls back to the one on disk.
    function setPicture(key: string, url: string, width: real, height: real): void {
        const next = Object.assign({}, root.pictures)
        if (url.length === 0) delete next[key]
        else next[key] = { url: url, width: width, height: height }
        root.pictures = next
    }
    function savedPicture(key: string): string {
        return root.pictureDir + "/" + key.replace(/[^A-Za-z0-9._-]/g, "_") + "-" + root.look + ".png"
    }

    // ── Pulling a widget off the shelf ──
    // The family carrying a picture over the card writes where it will land ({ output, key, width, height, plan }, desktop
    // px; DesktopArrange snaps it); each output's desktop draws the spot.
    property var carry: null

    // ── Adding and taking away from the shelf ──
    // A widget taken from the shelf lands where it was dropped (`at`, desktop px, its centre) or on a free spot, and
    // grows out of the picture it was (`from`, screen px). One taken back shrinks into its picture before it goes.
    // key -> rect (screen px) of its picture on the shelf, published by the family that draws one.
    property var tiles: ({})
    property var arrivals: ({})
    property var departures: ({})
    // `at` with `exact` is a plan: the widget takes that spot as it is. `glide`: the widget was out already and slides.
    function arrive(output: string, key: string, at: var, from: var, glide: bool): void {
        const next = Object.assign({}, root.arrivals)
        next[output + "::" + key] = { at: at, from: from, glide: Boolean(glide) }
        root.arrivals = next
        DesktopWidgetLayout.setGloballyEnabled(key, true)
    }
    function arrival(output: string, key: string): var { return root.arrivals[output + "::" + key] ?? null }
    function arrived(output: string, key: string): void {
        const next = Object.assign({}, root.arrivals)
        delete next[output + "::" + key]
        root.arrivals = next
    }
    function depart(output: string, key: string, to: var): void {
        const next = Object.assign({}, root.departures)
        next[output + "::" + key] = { to: to }
        root.departures = next
        departTimer.restart()
    }
    function departure(output: string, key: string): var { return root.departures[output + "::" + key] ?? null }
    readonly property int departDuration: 240
    Timer {
        id: departTimer
        interval: root.departDuration
        onTriggered: {
            const gone = Object.keys(root.departures)
            root.departures = ({})
            for (const id of gone)
                DesktopWidgetLayout.setGloballyEnabled(id.slice(id.indexOf("::") + 2), false)
        }
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
