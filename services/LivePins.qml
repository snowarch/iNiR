pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Live snips: a rectangle of one window kept on screen, streamed at display rate (qs-rs on niri and Umbriel). A pin is
// remembered by app id and crop, not by window id: ids die with the window, so a pin finds its app again when it
// reopens and waits quietly while it is closed.
Singleton {
    id: root

    readonly property string filePath: `${Directories.stateUserPath}/live-pins.json`
    // The crop (`sourceRect`) exists only on qs-rs; elsewhere nothing offers or draws a pin.
    readonly property bool supported: CompositorService.windowCapture && SystemInfo.runtimeHas(["screencopy-source-rect"])
    readonly property int minWidth: 120
    readonly property int maxWidth: 960

    property bool ready: false
    // The framer is open: pick a window, drag over the part to keep (LivePinFramer).
    property bool framing: false
    function frame(): void { if (root.supported) root.framing = true }
    property var pins: []
    // Pins whose window is open right now, by pin id: { id: window }.
    readonly property var bound: {
        const out = {}
        const wins = NiriService.windows ?? []
        const taken = new Set()
        // A pin keeps the window it was made on while that one lives; then the same app's window with the same
        // title, then the one used last.
        for (const pin of root.pins) {
            const same = wins.find(w => w.id === pin.windowId && (w.app_id ?? "") === pin.appId)
            if (same) { out[pin.id] = same; taken.add(same.id) }
        }
        for (const pin of root.pins) {
            if (out[pin.id]) continue
            const ofApp = wins.filter(w => (w.app_id ?? "") === pin.appId && !taken.has(w.id))
            if (ofApp.length === 0) continue
            const titled = ofApp.find(w => (w.title ?? "") === pin.title)
            const pick = titled ?? ofApp.slice().sort((a, b) => root._focusedAt(b) - root._focusedAt(a))[0]
            out[pin.id] = pick
            taken.add(pick.id)
        }
        return out
    }
    function _focusedAt(w): real {
        const t = w?.focus_timestamp
        return t ? Number(t.secs ?? 0) * 1e3 + Number(t.nanos ?? 0) / 1e6 : 0
    }
    function windowOf(pinId: string): var { return root.bound[pinId] ?? null }
    function find(pinId: string): var { return root.pins.find(pin => pin.id === pinId) ?? null }

    // A rectangle of window `windowId` in logical pixels of that window, shown at (x, y) of `output` `width` wide.
    function pinWindow(windowId: int, crop: rect, output: string, x: real, y: real, width: real): var {
        const win = (NiriService.windows ?? []).find(w => w.id === windowId)
        if (!win || crop.width < 8 || crop.height < 8) return null
        const size = win.layout?.window_size ?? [crop.x + crop.width, crop.y + crop.height]
        const pin = {
            // Two made in one millisecond (a script) still differ.
            id: "pin-" + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            appId: String(win.app_id ?? ""),
            title: String(win.title ?? ""),
            windowId: windowId,
            crop: [Math.round(crop.x), Math.round(crop.y), Math.round(crop.width), Math.round(crop.height)],
            base: [Math.round(Number(size[0])), Math.round(Number(size[1]))],
            // Above the windows, as a picture in picture: a snip is for watching while working elsewhere.
            onTop: true,
            output: output,
            x: Math.round(x),
            y: Math.round(y),
            width: Math.round(Math.max(root.minWidth, Math.min(root.maxWidth, width))),
            created: Date.now()
        }
        root.pins = root.pins.concat([pin])
        root._save()
        return pin
    }
    function update(pinId: string, fields: var): void {
        let changed = false
        root.pins = root.pins.map(pin => {
            if (pin.id !== pinId) return pin
            changed = true
            return Object.assign({}, pin, fields)
        })
        if (changed) root._save()
    }
    function remove(pinId: string): void {
        const before = root.pins.length
        root.pins = root.pins.filter(pin => pin.id !== pinId)
        if (root.pins.length !== before) root._save()
    }
    // Click: to the window wherever it is; a closed app opens again and its pin finds it.
    function activate(pinId: string): bool {
        const win = root.windowOf(pinId)
        if (win) { NiriService.focusWindow(win.id); return true }
        const pin = root.find(pinId)
        const entry = pin ? AppSearch.lookupDesktopEntry(pin.appId) : null
        return entry ? AppSearch.launchEntry(entry) : false
    }

    // A window that comes back under a new id: the pin follows it, written once it settles.
    onBoundChanged: rebind.restart()
    Timer {
        id: rebind
        interval: 1500
        onTriggered: {
            let changed = false
            const next = root.pins.map(pin => {
                const win = root.bound[pin.id]
                if (!win || win.id === pin.windowId) return pin
                changed = true
                return Object.assign({}, pin, { windowId: win.id })
            })
            if (changed) { root.pins = next; root._save() }
        }
    }

    function _save(): void { saveTimer.restart() }
    Timer {
        id: saveTimer
        interval: 250
        onTriggered: store.setText(JSON.stringify({ version: 1, pins: root.pins }, null, 1))
    }
    FileView {
        id: store
        path: Qt.resolvedUrl(root.filePath)
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const doc = JSON.parse(store.text())
                root.pins = (Array.isArray(doc?.pins) ? doc.pins : []).filter(pin => pin && pin.id && pin.appId
                    && Array.isArray(pin.crop) && pin.crop.length === 4 && Array.isArray(pin.base) && pin.base.length === 2)
            } catch (e) {
                root.pins = []
            }
            root.ready = true
        }
        onLoadFailed: root.ready = true
    }

    /// Live snips: a part of a window kept on screen, streamed, even when the window is on another workspace (qs-rs
    /// on niri and Umbriel).
    IpcHandler {
        target: "livePins"
        /// Every pin as JSON, with `live` when its window is open
        function list(): string { return JSON.stringify(root.pins.map(pin => Object.assign({}, pin, { live: root.windowOf(pin.id) !== null }))) }
        /// Whether this shell can stream windows
        function supported(): bool { return root.supported }
        // Opens the framer: pick a window, drag over the part to keep.
        /// Pick a window and drag over the part to keep
        function frame(): void { root.frame() }
        // Window `windowId`, rectangle x y w h in its logical pixels; returns the new pin's id or "".
        /// Pin that rectangle of the window (its logical pixels); prints the pin's id
        function pin(windowId: int, x: int, y: int, w: int, h: int): string {
            if (!root.supported) return ""
            const win = (NiriService.windows ?? []).find(item => item.id === windowId)
            const ws = win ? NiriService.workspaces?.[win.workspace_id] : null
            const made = root.pinWindow(windowId, Qt.rect(x, y, w, h), String(ws?.output ?? ""), 80, 120, w)
            return made?.id ?? ""
        }
        /// Remove a pin
        function remove(id: string): void { root.remove(id) }
        /// Remove every pin
        function clear(): void { root.pins = []; root._save() }
        /// Above the windows, or on the desktop
        function onTop(id: string, on: bool): bool { root.update(id, { onTop: on }); return on }
        /// Move a pin
        function move(id: string, x: int, y: int): void { root.update(id, { x: x, y: y }) }
        /// Resize a pin; its height follows the crop
        function resize(id: string, width: int): void { root.update(id, { width: Math.max(root.minWidth, Math.min(root.maxWidth, width)) }) }
        /// Go to its window, or open the app again
        function activate(id: string): bool { return root.activate(id) }
    }
}
