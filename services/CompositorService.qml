pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Singleton {
    id: root

    // Which compositor the session runs: "niri", "umbriel", "hyprland" or "" (none iNiR drives).
    property string compositor: ""
    property bool isHyprland: false
    // The window, workspace and output model every surface reads (NiriService) is live: Niri itself, or Umbriel,
    // whose IPC NiriService speaks too (services/UmbrielModel.js turns its snapshots into Niri's shapes).
    property bool isNiri: false
    property bool isUmbriel: false
    // Niri itself runs: its binary, `niri msg` and its KDL config are there. Gate those on this, never on isNiri.
    readonly property bool niriNative: compositor === "niri"
    // ext-background-effect-v1 blur regions: Niri 26.04 takes them; Umbriel blurs by its layer rules instead (iNiR
    // writes the one compositor glass asks for), so a surface leaves its region unset there.
    readonly property bool blurRegions: niriNative
    // Live window pictures (qs-rs). A runtime with toplevel-image-copy asks the compositor (its image-copy globals, or
    // niri's ScreenCast); an older one streams niri windows only. Umbriel's windows go by its own ids
    // (NiriService.umbrielWindowKey), which only the newer runtime takes.
    readonly property bool windowCapture: SystemInfo.runtimeHas(["toplevel-image-copy"])
        ? (niriNative || isUmbriel) && ToplevelManager.canCaptureWindows
        : niriNative && SystemInfo.runtimeHas(["niri-window-capture"])

    readonly property string hyprlandSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property string niriSocket: Quickshell.env("NIRI_SOCKET")
    // Umbriel exports it to everything it starts; its documented fallback covers a shell started some other way.
    readonly property string umbrielSocket: {
        const set = Quickshell.env("UMBRIEL_SOCKET")
        if (set && set.length > 0) return set
        const runtime = Quickshell.env("XDG_RUNTIME_DIR"), display = Quickshell.env("WAYLAND_DISPLAY")
        return root._desktopIs("umbriel") && runtime && display ? `${runtime}/umbriel-${display}.sock` : ""
    }

    function _desktopIs(name: string): bool {
        return String(Quickshell.env("XDG_CURRENT_DESKTOP") ?? "").toLowerCase().split(":").includes(name)
    }

    property var sortedToplevels: []

    property var _sortingConsumers: ({})
    property int _sortingConsumersCount: 0
    // Who holds it, not how many: across a reload the old holder's release reached the new instance and dropped the
    // new holder's claim (ResourceUsage froze every reading that way).
    property var _sortingHolders: []
    property int _anonymousSortingHolders: 0
    readonly property int _sortingLeaseCount: root._sortingHolders.length + root._anonymousSortingHolders
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

    function acquireSortingConsumer(holder: var): void {
        const wasActive = root.sortingActive
        if (!holder) root._anonymousSortingHolders++
        else if (!root._sortingHolders.includes(holder)) root._sortingHolders = root._sortingHolders.concat([holder])
        root._handleSortingDemandChanged(wasActive)
    }

    function releaseSortingConsumer(holder: var): void {
        const wasActive = root.sortingActive
        if (!holder) root._anonymousSortingHolders = Math.max(0, root._anonymousSortingHolders - 1)
        else root._sortingHolders = root._sortingHolders.filter(other => other !== holder)
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
        // Only the reordering waits for the timer: a window that closed leaves the list at once, since anything built
        // from the list in those 100 ms (a dock icon) kept a toplevel that was already gone.
        // Niri's list holds enriched copies: each is matched by the handle it came from, or every window that
        // opened emptied the list for those 100 ms and the dock dropped every open app and grew them back.
        function onValuesChanged() {
            const live = Array.from(ToplevelManager.toplevels.values ?? [])
            const alive = toplevel => live.includes(toplevel?._sourceToplevel ?? toplevel)
            if (root.sortedToplevels.some(toplevel => !alive(toplevel)))
                root.sortedToplevels = root.sortedToplevels.filter(alive)
            root.scheduleSort()
        }
    }
    Connections {
        target: root.isHyprland ? Hyprland.toplevels : null
        enabled: root.isHyprland && root.sortingActive
        function onValuesChanged() {
            root.scheduleSort()
        }
    }
    Connections {
        target: root.isHyprland ? Hyprland.workspaces : null
        enabled: root.isHyprland && root.sortingActive
        function onValuesChanged() { root.scheduleSort() }
    }
    Connections {
        target: root.isHyprland ? Hyprland : null
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
        // A compositor started inside another inherits the outer one's socket too: the desktop it names wins.
        const umbriel = root.umbrielSocket.length > 0
        const niri = !!niriSocket && niriSocket.length > 0
        if (umbriel && (!niri || !root._desktopIs("niri"))) {
            compositor = "umbriel"
            isUmbriel = true
            isNiri = true
            isHyprland = false
            console.info("CompositorService: Detected Umbriel with socket:", root.umbrielSocket)
            return
        }

        if (hyprlandSignature && hyprlandSignature.length > 0) {
            compositor = "hyprland"
            isHyprland = true
            isNiri = false
            console.info("CompositorService: Detected Hyprland")
            try {
                Hyprland.refreshToplevels()
            } catch(e) {}
            return
        }

        if (niri) {
            compositor = "niri"
            isNiri = true
            isHyprland = false
            console.info("CompositorService: Detected Niri with socket:", niriSocket)
            return
        }

        compositor = ""
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
