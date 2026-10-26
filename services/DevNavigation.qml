pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.services.deferred
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var baseDestinations: [
        { id: "sidebar-left/widgets", family: "shared", surface: "sidebar-left", view: "widgets", safe: true, settleMs: 350 },
        { id: "sidebar-left/ai", family: "shared", surface: "sidebar-left", view: "ai", safe: true, settleMs: 500 },
        { id: "sidebar-left/translator", family: "shared", surface: "sidebar-left", view: "translator", safe: true, settleMs: 350 },
        { id: "sidebar-left/anime", family: "shared", surface: "sidebar-left", view: "anime", safe: true, settleMs: 450 },
        { id: "sidebar-left/anime-schedule", family: "shared", surface: "sidebar-left", view: "anime-schedule", safe: true, settleMs: 500 },
        { id: "sidebar-left/wallhaven", family: "shared", surface: "sidebar-left", view: "wallhaven", safe: true, settleMs: 450 },
        { id: "sidebar-left/news", family: "shared", surface: "sidebar-left", view: "news", safe: true, settleMs: 500 },
        { id: "sidebar-left/ytmusic", family: "shared", surface: "sidebar-left", view: "ytmusic", safe: true, settleMs: 450 },
        { id: "sidebar-left/tools", family: "shared", surface: "sidebar-left", view: "tools", safe: true, settleMs: 350 },
        { id: "sidebar-left/software", family: "shared", surface: "sidebar-left", view: "software", safe: true, settleMs: 450 },
        { id: "sidebar-right/controls", family: "shared", surface: "sidebar-right", view: "controls", safe: true, settleMs: 350 },
        { id: "sidebar-right/notifications", family: "shared", surface: "sidebar-right", view: "notifications", safe: true, settleMs: 350 },
        { id: "sidebar-right/calendar", family: "shared", surface: "sidebar-right", view: "calendar", safe: true, settleMs: 350 },
        { id: "sidebar-right/events", family: "shared", surface: "sidebar-right", view: "events", safe: true, settleMs: 350 },
        { id: "sidebar-right/todo", family: "shared", surface: "sidebar-right", view: "todo", safe: true, settleMs: 350 },
        { id: "sidebar-right/notepad", family: "shared", surface: "sidebar-right", view: "notepad", safe: true, settleMs: 350 },
        { id: "sidebar-right/calculator", family: "shared", surface: "sidebar-right", view: "calculator", safe: true, settleMs: 350 },
        { id: "sidebar-right/sysmon", family: "shared", surface: "sidebar-right", view: "sysmon", safe: true, settleMs: 350 },
        { id: "sidebar-right/weather", family: "shared", surface: "sidebar-right", view: "weather", safe: true, settleMs: 450 },
        { id: "sidebar-right/timer", family: "shared", surface: "sidebar-right", view: "timer", safe: true, settleMs: 350 },
        { id: "sidebar-right/screentime", family: "shared", surface: "sidebar-right", view: "screentime", safe: true, settleMs: 350 },
        { id: "control-panel", family: "ii", surface: "control-panel", view: "", safe: true, settleMs: 350 },
        { id: "dashboard", family: "ii", surface: "dashboard", view: "", safe: true, settleMs: 450 },
        { id: "media-controls", family: "shared", surface: "media-controls", view: "", safe: true, settleMs: 350 },
        { id: "clipboard", family: "shared", surface: "clipboard", view: "", safe: true, settleMs: 350 },
        { id: "cheatsheet", family: "shared", surface: "cheatsheet", view: "", safe: true, settleMs: 350 },
        { id: "overview", family: "shared", surface: "overview", view: "", safe: true, settleMs: 450 },
        { id: "overview/actions", family: "shared", surface: "overview", view: "actions", safe: true, settleMs: 450 },
        { id: "overview/clipboard", family: "shared", surface: "overview", view: "clipboard", safe: true, settleMs: 450 },
        { id: "wallpaper/grid", family: "ii", surface: "wallpaper-grid", view: "", safe: true, settleMs: 500 },
        { id: "wallpaper/coverflow", family: "ii", surface: "wallpaper-coverflow", view: "", safe: true, settleMs: 500 },
        { id: "tiling/picker", family: "shared", surface: "tiling", view: "picker", safe: true, settleMs: 350 },
        { id: "tiling/osd", family: "shared", surface: "tiling", view: "osd", safe: true, settleMs: 350 }
    ]
    property var settingsDestinations: []
    readonly property var destinations: baseDestinations.concat(Plugins.devDestinations, settingsDestinations)
    property string currentDestination: ""
    // The view a family's own surface opens on, read by that surface (`view` of its dev destination).
    property string requestedView: ""

    function registerSettingsPages(pages): void {
        const out = []
        const list = pages ?? []
        for (let index = 0; index < list.length; index++) {
            const page = list[index]
            const key = String(page?.key ?? "")
            if (key.length === 0) continue
            out.push({ id: "settings/" + key, family: "shared", surface: "settings", view: key, pageIndex: index, safe: true, settleMs: 300 })
        }
        settingsDestinations = out
    }

    function entryFor(destination: string): var {
        return destinations.find(entry => entry.id === destination) ?? null
    }

    function closeAll(): void {
        GlobalStates.sidebarLeftOpen = false
        GlobalStates.sidebarRightOpen = false
        GlobalStates.controlPanelOpen = false
        GlobalStates.dashboardOpen = false
        GlobalStates.sessionOpen = false
        GlobalStates.mediaControlsOpen = false
        GlobalStates.clipboardOpen = false
        GlobalStates.cheatsheetOpen = false
        GlobalStates.overviewOpen = false
        GlobalStates.wallpaperSelectorOpen = false
        GlobalStates.coverflowSelectorOpen = false
        GlobalStates.tilingOverlayPickerOpen = false
        GlobalStates.tilingOverlayOsdOpen = false
        GlobalStates.settingsOverlayOpen = false
        GlobalStates.searchOpen = false
        const familyClose = GlobalStates.familyVerb("dev", "close")
        if (familyClose) familyClose()
        GlobalStates.sidebarRightRequestedWidget = ""
        requestedView = ""
        LauncherSearch.query = ""
        currentDestination = ""
    }

    function request(destination: string): string {
        const entry = entryFor(destination)
        if (!entry) return "error:unknown-destination"
        const family = Config.options?.panelFamily ?? "ii"
        if (entry.family !== "shared" && entry.family !== family)
            return "error:requires-family-" + entry.family

        closeAll()
        currentDestination = destination
        switch (entry.surface) {
        case "sidebar-left": GlobalStates.openSidebarLeft(""); break
        case "sidebar-right":
            GlobalStates.sidebarRightRequestedWidget = entry.view
            GlobalStates.openSidebarRight("")
            break
        case "control-panel": GlobalStates.controlPanelOpen = true; break
        case "dashboard": GlobalStates.dashboardOpen = true; break
        case "media-controls": GlobalStates.mediaControlsOpen = true; break
        case "clipboard": GlobalStates.clipboardOpen = true; break
        case "cheatsheet": GlobalStates.cheatsheetOpen = true; break
        case "overview":
            GlobalStates.overviewSearchPrefix = entry.view === "actions"
                ? (Config.options?.search?.prefix?.action ?? "/")
                : entry.view === "clipboard" ? (Config.options?.search?.prefix?.clipboard ?? ";") : ""
            GlobalStates.openOverview("")
            break
        case "wallpaper-grid": GlobalStates.wallpaperSelectorOpen = true; break
        case "wallpaper-coverflow": GlobalStates.coverflowSelectorOpen = true; break
        case "tiling":
            GlobalStates.tilingOverlayPickerOpen = entry.view === "picker"
            GlobalStates.tilingOverlayOsdOpen = entry.view === "osd"
            break
        case "settings":
            // The pages are the settings host's: a family wearing no such Settings has none to open.
            if (Plugins.part(Plugins.settingsFamily, "settingsHost").length === 0) {
                currentDestination = ""
                return "error:settings-page-unavailable"
            }
            GlobalStates.openSettingsPage(entry.pageIndex ?? -1)
            break
        default: {
            // A family's own surface: its verb `dev.open` opens it and says so.
            requestedView = entry.view ?? ""
            const familyOpen = GlobalStates.familyVerb("dev", "open")
            if (!familyOpen || familyOpen(entry.surface) !== true) { currentDestination = ""; return "error:unsupported-surface" }
        }
        }
        return "ok:" + destination
    }

    property var meterGaps: []
    property real meterUntil: 0
    property var meterResult: ({ state: "idle" })
    function meterStats(): var {
        const gaps = root.meterGaps.slice(1)
        if (gaps.length === 0) return { state: "empty" }
        const sorted = gaps.slice().sort((a, b) => a - b)
        const round = value => Math.round(value * 10) / 10
        return { state: "done", frames: gaps.length, mean: round(gaps.reduce((a, b) => a + b, 0) / gaps.length),
            p95: round(sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))]), worst: round(sorted[sorted.length - 1]),
            over20: gaps.filter(v => v > 20).length, over50: gaps.filter(v => v > 50).length,
            // How long the GUI thread was held at once: frame gaps also count drawing (a llvmpipe nest draws in 40 ms),
            // this counts only work that blocks animations and input, whatever renders the frame.
            busy: round(Math.max(0, ...root.meterBeats.slice(1)) - 4), busy16: root.meterBeats.slice(1).filter(v => v > 20).length }
    }
    property var meterBeats: []
    property real meterBeat: 0
    Timer {
        interval: 4
        repeat: true
        running: meter.running
        onRunningChanged: if (running) { root.meterBeats = []; root.meterBeat = Date.now() }
        onTriggered: {
            const now = Date.now()
            root.meterBeats.push(now - root.meterBeat)
            root.meterBeat = now
        }
    }
    FrameAnimation {
        id: meter
        running: false
        onTriggered: {
            root.meterGaps.push(frameTime * 1000)
            if (Date.now() >= root.meterUntil) { meter.stop(); root.meterResult = root.meterStats() }
        }
    }

    // Installs restart on update and carry no Makefile: the watcher is for checkouts only, not a python all day.
    property bool checkout: false
    FileView {
        path: Quickshell.shellPath("Makefile")
        printErrors: false
        onLoaded: root.checkout = true
    }
    Process {
        running: Quickshell.watchFiles && root.checkout
        command: ["python3", Quickshell.shellPath("scripts/daemon/dev_hot_reload.py"), Quickshell.shellDir,
            String(Quickshell.processId)]
    }

    IpcHandler {
        target: "dev"
        function list(): string { return JSON.stringify(root.destinations) }
        function open(destination: string): string { return root.request(destination) }
        function close(): void { root.closeAll() }
        function reload(): string { Qt.callLater(() => Quickshell.reload(false)); return "reloading" }
        function current(): string { return root.currentDestination.length > 0 ? root.currentDestination : "closed" }
        function meter(ms: string): string {
            const span = Math.max(250, Math.min(20000, Number(ms) || 2500))
            root.meterGaps = []
            root.meterUntil = Date.now() + span
            root.meterResult = { state: "running" }
            meter.restart()
            return "measuring:" + span
        }
        function metered(): string { return JSON.stringify(root.meterResult) }
    }
}
