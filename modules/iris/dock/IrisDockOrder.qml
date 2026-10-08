pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// The order of the iRiS Dock, shared by every output and by Spotlight's suggestions: pinned apps keep dock.pinnedApps' order,
// open apps keep the order they were opened in (Niri's window ids only grow), never the strip's layout.
Singleton {
    id: root

    readonly property string arrange: String(Config.options?.iris?.dock?.arrange ?? "pinned")
    readonly property bool groupOpen: root.arrange === "opened"
    property var openOrder: []

    function firstWindow(app): real {
        let first = Infinity
        for (const t of app?.toplevels ?? [])
            if (t?.niriWindowId !== undefined && t.niriWindowId < first) first = t.niriWindowId
        return first
    }

    readonly property var apps: (TaskbarApps.apps ?? []).filter(app => app && app.appId !== "SEPARATOR")
    readonly property var running: root.apps.filter(app => (app.toplevels?.length ?? 0) > 0)
    readonly property var liveOrder: {
        const known = root.openOrder.filter(id => root.running.some(app => app.appId === id))
        const fresh = root.running.filter(app => !known.includes(app.appId))
            .sort((a, b) => root.firstWindow(a) - root.firstWindow(b))
            .map(app => app.appId)
        return known.concat(fresh)
    }
    onLiveOrderChanged: if (JSON.stringify(root.liveOrder) !== JSON.stringify(root.openOrder)) orderSync.restart()
    Timer { id: orderSync; interval: 0; onTriggered: root.openOrder = root.liveOrder }

    readonly property var entries: {
        const order = root.liveOrder
        const pinned = root.apps.filter(app => app.pinned && (!root.groupOpen || (app.toplevels?.length ?? 0) === 0))
        const open = root.running.filter(app => root.groupOpen || !app.pinned)
            .sort((a, b) => order.indexOf(a.appId) - order.indexOf(b.appId))
        return pinned.length > 0 && open.length > 0 ? pinned.concat([{ appId: "SEPARATOR" }], open) : pinned.concat(open)
    }

    function isPinned(appId: string): bool {
        const lower = appId.toLowerCase()
        return (Config.options?.dock?.pinnedApps ?? []).some(p => String(p).toLowerCase() === lower)
    }

    function drop(appId: string, ids: var): bool {
        const at = ids.indexOf(appId)
        if (at < 0) return false
        const split = ids.indexOf("SEPARATOR")
        const app = root.entries.find(e => e.appId === appId)
        const running = (app?.toplevels?.length ?? 0) > 0
        const wasPinned = root.isPinned(appId)
        const toPinned = split >= 0 ? at < split : (wasPinned && (!root.groupOpen || !running))

        if (toPinned) {
            const pinned = Array.from(Config.options?.dock?.pinnedApps ?? [])
            const own = pinned.find(p => String(p).toLowerCase() === appId) ?? (AppSearch.lookupDesktopEntry(appId)?.id || appId)
            const rest = pinned.filter(p => String(p).toLowerCase() !== appId)
            rest.splice(root.insertAt(rest.map(p => String(p).toLowerCase()), ids.slice(0, split >= 0 ? split : ids.length), at), 0, own)
            if (JSON.stringify(rest) !== JSON.stringify(pinned)) Config.setNestedValue(["dock", "pinnedApps"], rest)
            return true
        }
        if (!running) return false
        if (wasPinned && !root.groupOpen) TaskbarApps.togglePin(appId)
        const rest = root.openOrder.filter(id => id !== appId)
        const side = split >= 0 ? split + 1 : 0
        rest.splice(root.insertAt(rest, ids.slice(side), at - side), 0, appId)
        root.openOrder = rest
        return true
    }
    function insertAt(list: var, ids: var, at: int): int {
        for (let i = at - 1; i >= 0; i--) {
            const k = list.indexOf(ids[i])
            if (k >= 0) return k + 1
        }
        for (let i = at + 1; i < ids.length; i++) {
            const k = list.indexOf(ids[i])
            if (k >= 0) return k
        }
        return list.length
    }
}
