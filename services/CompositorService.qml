pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
    id: root

    property bool isHyprland: false
    property bool isNiri: false

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")

    property var sortedToplevels: []

    property var _sortingConsumers: ({})
    property int _sortingConsumersCount: 0
    property int _sortingLeaseCount: 0
    readonly property bool sortingActive:
        root._sortingConsumersCount + root._sortingLeaseCount > 0

    property bool _sortScheduled: false
    property bool _refreshScheduled: false

    property var _coordCache: ({})

    Timer {
        id: refreshTimer
        interval: 40
        repeat: false
        onTriggered: {
            try {
                Hyprland.refreshToplevels()
            } catch(e) {}
            _refreshScheduled = false
            scheduleSort()
        }
    }

    Timer {
        id: sortTimer
        interval: 100 // Limit updates to 10 FPS to prevent lag spikes
        repeat: false
        onTriggered: {
            _sortScheduled = false
            sortedToplevels = computeSortedToplevels()
        }
    }

    function scheduleSort() {
        if (!root.sortingActive) return
        if (_sortScheduled) return
        _sortScheduled = true
        sortTimer.restart()
    }

    function scheduleRefresh() {
        if (!root.sortingActive) return
        if (!isHyprland) return
        if (_refreshScheduled) return
        _refreshScheduled = true
        refreshTimer.restart()
    }

    function setSortingConsumer(name: string, active: bool): void {
        if (!name || name.length === 0)
            return;
        const prev = !!root._sortingConsumers[name]
        if (prev === active)
            return;
        const wasActive = root.sortingActive
        root._sortingConsumers[name] = active

        let count = 0
        for (const k in root._sortingConsumers) {
            if (root._sortingConsumers[k]) count++
        }
        root._sortingConsumersCount = count
        root._handleSortingDemandChanged(wasActive)
    }

    function acquireSortingConsumer(): void {
        const wasActive = root.sortingActive
        root._sortingLeaseCount++
        root._handleSortingDemandChanged(wasActive)
    }

    function releaseSortingConsumer(): void {
        if (root._sortingLeaseCount <= 0)
            return
        const wasActive = root.sortingActive
        root._sortingLeaseCount--
        root._handleSortingDemandChanged(wasActive)
    }

    function _handleSortingDemandChanged(wasActive: bool): void {
        if (!wasActive && root.sortingActive) {
            root.scheduleSort()
        } else if (wasActive && !root.sortingActive) {
            sortTimer.stop()
            root._sortScheduled = false
            root.sortedToplevels = []
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        enabled: root.sortingActive
        function onValuesChanged() { root.scheduleSort() }
    }
    Connections {
        target: Hyprland.toplevels
        enabled: root.isHyprland && root.sortingActive
        function onValuesChanged() {
            root.scheduleSort()
        }
    }
    Connections {
        target: Hyprland.workspaces
        enabled: root.isHyprland && root.sortingActive
        function onValuesChanged() { root.scheduleSort() }
    }
    Connections {
        target: Hyprland
        enabled: root.isHyprland && root.sortingActive
        function onFocusedWorkspaceChanged() { root.scheduleSort() }
    }
    Connections {
        target: NiriService
        enabled: root.isNiri && root.sortingActive
        function onWindowOrderChanged() { root.scheduleSort() }
        function onActiveWindowChanged() { root.scheduleSort() }
    }
    Component.onCompleted: {
        detectCompositor()
    }

    function computeSortedToplevels() {
        if (!ToplevelManager.toplevels || !ToplevelManager.toplevels.values)
            return []

        if (isNiri)
            return NiriService.sortToplevels(ToplevelManager.toplevels.values)

        if (isHyprland)
            return sortHyprlandToplevelsSafe()

        return Array.from(ToplevelManager.toplevels.values)
    }

    function _get(o, path, fallback) {
        try {
            let v = o
            for (let i = 0; i < path.length; i++) {
                if (v === null || v === undefined) return fallback
                v = v[path[i]]
            }
            return (v === undefined || v === null) ? fallback : v
        } catch (e) { return fallback }
    }

    function sortHyprlandToplevelsSafe() {
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return []
        if (_refreshScheduled) return sortedToplevels

        const items = Array.from(Hyprland.toplevels.values)

        function _get(o, path, fb) {
            try {
                let v = o
                for (let k of path) { if (v == null) return fb; v = v[k] }
                return (v == null) ? fb : v
            } catch(e) { return fb }
        }

        let snap = []
        let missingAnyPosition = false
        let hasNewWindow = false
        for (let i = 0; i < items.length; i++) {
            const t = items[i]
            if (!t) continue

            const addr = t.address || ""
            const li = t.lastIpcObject || null

            const monName = _get(li, ["monitor"], null) ?? _get(t, ["monitor", "name"], "")
            const monX = _get(t, ["monitor", "x"], Number.MAX_SAFE_INTEGER)
            const monY = _get(t, ["monitor", "y"], Number.MAX_SAFE_INTEGER)

            const wsId = _get(li, ["workspace", "id"], null) ?? _get(t, ["workspace", "id"], Number.MAX_SAFE_INTEGER)

            const at = _get(li, ["at"], null)
            let atX = (at !== null && at !== undefined && typeof at[0] === "number") ? at[0] : NaN
            let atY = (at !== null && at !== undefined && typeof at[1] === "number") ? at[1] : NaN

            if (!(atX === atX) || !(atY === atY)) {
                const cached = _coordCache[addr]
                if (cached) {
                    atX = cached.x
                    atY = cached.y
                } else {
                    if (addr) hasNewWindow = true
                    missingAnyPosition = true
                    atX = 1e9
                    atY = 1e9
                }
            } else if (addr) {
                _coordCache[addr] = { x: atX, y: atY }
            }

            const relX = Number.isFinite(monX) ? (atX - monX) : atX
            const relY = Number.isFinite(monY) ? (atY - monY) : atY

            snap.push({
                monKey: String(monName),
                monOrderX: Number.isFinite(monX) ? monX : Number.MAX_SAFE_INTEGER,
                monOrderY: Number.isFinite(monY) ? monY : Number.MAX_SAFE_INTEGER,
                wsId: (typeof wsId === "number") ? wsId : Number.MAX_SAFE_INTEGER,
                x: relX,
                y: relY,
                title: t.title || "",
                address: addr,
                wayland: t.wayland
            })
        }

        if (missingAnyPosition && hasNewWindow) {
            scheduleRefresh()
        }

        const groups = new Map()
        for (const it of snap) {
            const key = it.monKey + "::" + it.wsId
            if (!groups.has(key)) groups.set(key, [])
            groups.get(key).push(it)
        }

        let groupList = []
        for (const [key, arr] of groups) {
            const repr = arr[0]
            groupList.push({
                key,
                monKey: repr.monKey,
                monOrderX: repr.monOrderX,
                monOrderY: repr.monOrderY,
                wsId: repr.wsId,
                items: arr
            })
        }

        groupList.sort((a, b) => {
            if (a.monOrderX !== b.monOrderX) return a.monOrderX - b.monOrderX
            if (a.monOrderY !== b.monOrderY) return a.monOrderY - b.monOrderY
            if (a.monKey !== b.monKey) return a.monKey.localeCompare(b.monKey)
            if (a.wsId !== b.wsId) return a.wsId - b.wsId
            return 0
        })

        const COLUMN_THRESHOLD = 48
        const JITTER_Y = 6

        let ordered = []
        for (const g of groupList) {
            const arr = g.items

            const xs = arr.map(it => it.x).filter(x => Number.isFinite(x)).sort((a, b) => a - b)
            let colCenters = []
            if (xs.length > 0) {
                for (const x of xs) {
                    if (colCenters.length === 0) {
                        colCenters.push(x)
                    } else {
                        const last = colCenters[colCenters.length - 1]
                        if (x - last >= COLUMN_THRESHOLD) {
                            colCenters.push(x)
                        }
                    }
                }
            } else {
                colCenters = [0]
            }

            for (const it of arr) {
                let bestCol = 0
                let bestDist = Number.POSITIVE_INFINITY
                for (let ci = 0; ci < colCenters.length; ci++) {
                    const d = Math.abs(it.x - colCenters[ci])
                    if (d < bestDist) {
                        bestDist = d
                        bestCol = ci
                    }
                }
                it._col = bestCol
            }

            arr.sort((a, b) => {
                if (a._col !== b._col) return a._col - b._col

                const dy = a.y - b.y
                if (Math.abs(dy) > JITTER_Y) return dy

                if (a.title !== b.title) return a.title.localeCompare(b.title)
                if (a.address !== b.address) return a.address.localeCompare(b.address)
                return 0
            })

            ordered.push.apply(ordered, arr)
        }

        return ordered.map(x => x.wayland).filter(w => w !== null && w !== undefined)
    }

    function filterCurrentWorkspace(toplevels, screen) {
        if (isNiri)
            return NiriService.filterCurrentWorkspace(toplevels, screen)
        if (isHyprland)
            return filterHyprlandCurrentWorkspaceSafe(toplevels, screen)
        return toplevels
    }

    function filterHyprlandCurrentWorkspaceSafe(toplevels, screenName) {
        if (!toplevels || toplevels.length === 0 || !Hyprland.toplevels)
            return toplevels

        let currentWorkspaceId = null
        try {
            const hy = Array.from(Hyprland.toplevels.values)
            for (const toplevel of hy) {
                const monitor = _get(toplevel, ["monitor", "name"], "")
                const workspaceId = _get(toplevel, ["workspace", "id"], null)
                const active = !!_get(toplevel, ["activated"], false)
                if (monitor === screenName && workspaceId !== null) {
                    if (active) {
                        currentWorkspaceId = workspaceId
                        break
                    }
                    if (currentWorkspaceId === null)
                        currentWorkspaceId = workspaceId
                }
            }

            if (currentWorkspaceId === null && Hyprland.workspaces) {
                const workspaces = Array.from(Hyprland.workspaces.values)
                const focusedId = _get(Hyprland, ["focusedWorkspace", "id"], null)
                for (const workspace of workspaces) {
                    const monitor = _get(workspace, ["monitor"], "")
                    const workspaceId = _get(workspace, ["id"], null)
                    if (monitor === screenName && workspaceId !== null) {
                        if (focusedId !== null && workspaceId === focusedId) {
                            currentWorkspaceId = workspaceId
                            break
                        }
                        if (currentWorkspaceId === null)
                            currentWorkspaceId = workspaceId
                    }
                }
            }
        } catch (e) {
            console.warn("CompositorService: workspace snapshot failed:", e)
        }

        if (currentWorkspaceId === null)
            return toplevels

        const workspaceByToplevel = new Map()
        try {
            const hy = Array.from(Hyprland.toplevels.values)
            for (const toplevel of hy) {
                const workspaceId = _get(toplevel, ["workspace", "id"], null)
                if (toplevel?.wayland && workspaceId !== null)
                    workspaceByToplevel.set(toplevel.wayland, workspaceId)
            }
        } catch (e) {}

        return toplevels.filter(toplevel =>
            workspaceByToplevel.get(toplevel) === currentWorkspaceId)
    }

    function detectCompositor() {
        if (hyprlandSignature && hyprlandSignature.length > 0) {
            isHyprland = true
            isNiri = false
            console.info("CompositorService: Detected Hyprland")
            try {
                Hyprland.refreshToplevels()
            } catch(e) {}
            return
        }

        if (niriSocket && niriSocket.length > 0) {
            isNiri = true
            isHyprland = false
            console.info("CompositorService: Detected Niri with socket:", niriSocket)
            return
        }

        isHyprland = false
        isNiri = false
    }

    function powerOffMonitors() {
        if (isNiri)
            return NiriService.powerOffMonitors()
        if (isHyprland)
            return Hyprland.dispatch("dpms off")
        console.warn("CompositorService: Cannot power off monitors, unknown compositor")
    }

    function powerOnMonitors() {
        if (isNiri)
            return NiriService.powerOnMonitors()
        if (isHyprland)
            return Hyprland.dispatch("dpms on")
        console.warn("CompositorService: Cannot power on monitors, unknown compositor")
    }
}
