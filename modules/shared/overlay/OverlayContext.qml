pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.services

Singleton {
    id: root

    // Every tool in the strip's order; a new group starts after a hairline.
    readonly property list<var> availableWidgets: [
        { identifier: "recorder", materialSymbol: "screen_record", title: "Recorder", group: 0 },
        { identifier: "volumeMixer", materialSymbol: "volume_up", title: "Volume mixer", group: 0 },
        { identifier: "discord", materialSymbol: "forum", title: "Discord", group: 0 },
        { identifier: "gamePerformance", materialSymbol: "monitor_heart", title: "Game performance", group: 1 },
        { identifier: "resources", materialSymbol: "browse_activity", title: "Resources", group: 1 },
        { identifier: "fpsLimiter", materialSymbol: "speed", title: "FPS limiter", group: 1 },
        { identifier: "crosshair", materialSymbol: "point_scan", title: "Crosshair", group: 1 },
        { identifier: "notes", materialSymbol: "note_stack", title: "Notes", group: 2 },
        { identifier: "floatingImage", materialSymbol: "imagesmode", title: "Floating image", group: 2 },
        { identifier: "notifications", materialSymbol: "notifications", title: "Notifications", group: 2 },
    ]

    function info(identifier: string): var {
        return root.availableWidgets.find(w => w.identifier === identifier) ?? null
    }

    readonly property list<string> openIds: Persistent.states?.overlay?.open ?? []
    function isOpen(identifier: string): bool { return root.openIds.includes(identifier) }
    function setOpen(identifier: string, open: bool): void {
        const state = Persistent.states.overlay
        const has = state.open.includes(identifier)
        if (open && !has) {
            state.open = state.open.concat([identifier])
            root.raise(identifier)
        } else if (!open && has) {
            state.open = state.open.filter(id => id !== identifier)
        }
    }
    // From the strip: a live tool leaves with its exit, a closed one comes in.
    function toggle(identifier: string): void {
        const tool = root.tools[identifier]
        if (tool && root.isOpen(identifier))
            tool.dismiss()
        else
            root.setOpen(identifier, !root.isOpen(identifier))
    }

    // Pinned tools stay on screen after the bench closes. Read from the saved state, so the layer comes back with
    // them after a restart instead of waiting for the first Super+G.
    readonly property bool hasSavedPins: {
        const state = Persistent.states?.overlay
        if (!state) return false
        return root.openIds.some(id => state[id]?.pinned === true)
    }
    readonly property bool hasPinnedWidgets: root.pinnedWidgetIdentifiers.length > 0
    readonly property bool nativeDialogOpen: Object.keys(root._nativeDialogs).length > 0
    // What keeps the layer loaded: the bench, a pinned tool, a file picker one of them opened.
    readonly property bool wanted: GlobalStates.overlayOpen || root.closing || root.hasSavedPins || root.hasPinnedWidgets || root.nativeDialogOpen

    // The bench stays on screen while it recedes.
    property bool closing: false
    property real openedAt: 0
    function justOpened(): bool { return Date.now() - root.openedAt < 400 }
    readonly property bool benchOpen: GlobalStates.overlayOpen
    onBenchOpenChanged: {
        if (root.benchOpen) {
            root.openedAt = Date.now()
            root.closing = false
            closeTimer.stop()
        } else {
            root.closing = true
            closeTimer.restart()
        }
    }
    Timer {
        id: closeTimer
        interval: OverlayLook.closeDuration + 40
        onTriggered: {
            root.closing = false
            if (root._pending.length > 0) {
                Quickshell.execDetached(root._pending)
                root._pending = []
                if (root._check) RecorderStatus.scheduleQuickCheck()
            }
        }
    }

    property list<string> pinnedWidgetIdentifiers: []
    property list<var> clickableWidgets: []
    property var _nativeDialogs: ({})

    function setNativeDialogVisible(dialogKey: string, visible: bool): void {
        const key = String(dialogKey ?? "").trim()
        if (!key) return
        const next = Object.assign({}, root._nativeDialogs)
        if (visible)
            next[key] = true
        else
            delete next[key]
        root._nativeDialogs = next
    }

    function pin(identifier: string, pin = true) {
        if (pin) {
            if (!root.pinnedWidgetIdentifiers.includes(identifier))
                root.pinnedWidgetIdentifiers = root.pinnedWidgetIdentifiers.concat([identifier])
        } else {
            root.pinnedWidgetIdentifiers = root.pinnedWidgetIdentifiers.filter(id => id !== identifier)
        }
    }

    function registerClickableWidget(widget: var, clickable = true) {
        if (clickable) {
            if (!root.clickableWidgets.includes(widget))
                root.clickableWidgets = root.clickableWidgets.concat([widget])
        } else {
            root.clickableWidgets = root.clickableWidgets.filter(w => w !== widget)
        }
    }

    // Stacking: the tool touched last sits on top.
    property var stack: ({})
    property int _top: 1
    function raise(identifier: string): void {
        if (root.stack[identifier] === root._top) return
        root._top += 1
        const next = Object.assign({}, root.stack)
        next[identifier] = root._top
        root.stack = next
    }

    // Live tools by id, so a drag can snap to its neighbours and Arrange can lay them out.
    property var tools: ({})
    function registerTool(identifier: string, item: var): void {
        const next = Object.assign({}, root.tools)
        next[identifier] = item
        root.tools = next
    }
    function unregisterTool(identifier: string, item: var): bool {
        if (root.tools[identifier] !== item) return false
        const next = Object.assign({}, root.tools)
        delete next[identifier]
        root.tools = next
        return true
    }
    // Every other tool's plate on the bench, in canvas pixels.
    function plates(except: string): var {
        const out = []
        for (const id of Object.keys(root.tools)) {
            const t = root.tools[id]
            if (id === except || !t || !t.visible || t.dismissing) continue
            out.push({ x: t.plateX, y: t.plateY, w: t.plateW, h: t.plateH })
        }
        return out
    }

    // Snap guides drawn while a tool is dragged, in canvas pixels (-1: none).
    property real guideX: -1
    property real guideY: -1
    // Where the desk starts under the strip.
    property real deskTop: 96

    // The first free place for a w x h plate: columns from the screen's edges inwards, left before right, top down.
    // A full desk gives the place it covers least, beside a neighbour, so every header stays in reach.
    function findSpot(w: real, h: real, taken: var, spanW: real, spanH: real): var {
        const edge = 24
        const gap = 16
        const top = Math.max(edge, root.deskTop)
        const hits = (x, y) => taken.find(r => x < r.x + r.w + gap && x + w + gap > r.x && y < r.y + r.h + gap && y + h + gap > r.y)
        for (let k = 0; k * 8 <= spanW / 2; k++) {
            const columns = [edge + k * 8, spanW - edge - w - k * 8]
            for (const x of columns) {
                if (x < 0 || x + w > spanW) continue
                let y = top
                while (y + h <= spanH - edge) {
                    const r = hits(x, y)
                    if (!r) return { x: Math.round(x), y: Math.round(y) }
                    y = r.y + r.h + gap
                }
            }
        }
        const maxX = Math.max(0, spanW - edge - w)
        const maxY = Math.max(top, spanH - edge - h)
        const xs = [edge, maxX].concat(taken.map(r => r.x + r.w + gap), taken.map(r => r.x - gap - w))
        const ys = [top, maxY].concat(taken.map(r => r.y + r.h + gap), taken.map(r => r.y - gap - h))
        const covered = (x, y) => taken.reduce((sum, r) => sum
            + Math.max(0, Math.min(x + w, r.x + r.w) - Math.max(x, r.x)) * Math.max(0, Math.min(y + h, r.y + r.h) - Math.max(y, r.y)), 0)
        let best = null
        for (const x0 of xs) {
            const x = Math.max(edge, Math.min(x0, maxX))
            for (const y0 of ys) {
                const y = Math.max(top, Math.min(y0, maxY))
                const c = covered(x, y)
                if (!best || c < best.c || (c === best.c && y < best.y)) best = { x: x, y: y, c: c }
            }
        }
        return best ? { x: Math.round(best.x), y: Math.round(best.y) }
            : { x: Math.round(Math.max(0, (spanW - w) / 2)), y: Math.round(Math.max(0, (spanH - h) / 2)) }
    }

    // Arrange: every open tool laid out again, the largest first so the rest fill around them; a crosshair goes back
    // to the middle.
    function arrange(): void {
        const taken = []
        const live = root.availableWidgets.map(info => root.tools[info.identifier]).filter(t => t && !t.dismissing)
        for (const t of live.filter(t => t.showCenterButton)) {
            t.center()
            taken.push({ x: t.canvasW / 2 - t.padding - t.contentW / 2, y: t.canvasH / 2 - t.headerHeight - t.contentH / 2, w: t.plateW, h: t.plateH })
        }
        const rest = live.filter(t => !t.showCenterButton).sort((a, b) => b.plateW * b.plateH - a.plateW * a.plateH)
        for (const t of rest) {
            const spot = root.findSpot(t.plateW, t.plateH, taken, t.canvasW, t.canvasH)
            t.placeAt(spot)
            taken.push({ x: spot.x, y: spot.y, w: t.plateW, h: t.plateH })
        }
    }

    // A recording's time: m:ss, h:mm:ss past an hour.
    function elapsed(total: int): string {
        const s = Math.max(0, total)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = String(s % 60).padStart(2, "0")
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`
    }

    // Capture from the bench: it closes first, so nothing of it lands in the picture.
    property list<string> _pending: []
    property bool _check: false
    // `check`: the recorder's state is read again right after (a recording starts or stops).
    function afterClose(command: list<string>, check: bool): void {
        if (GlobalStates.overlayOpen) {
            root._pending = command
            root._check = check
            GlobalStates.overlayOpen = false
        } else {
            Quickshell.execDetached(command)
            if (check) RecorderStatus.scheduleQuickCheck()
        }
    }
    function screenshotRegion(): void { root.afterClose([Quickshell.shellPath("scripts/inir"), "region", "screenshot"], false) }
    function copyScreen(): void { root.afterClose(["bash", "-c", "grim - | wl-copy"], false) }
    function recordRegion(): void { root.afterClose([Quickshell.shellPath("scripts/inir"), "region", "recordWithSound"], true) }
    function recordScreen(): void { root.afterClose([Directories.recordScriptPath, "--fullscreen", "--sound"], true) }
    function stopRecording(): void {
        Quickshell.execDetached([Directories.recordScriptPath, "--stop"])
        RecorderStatus.scheduleQuickCheck()
    }
}
