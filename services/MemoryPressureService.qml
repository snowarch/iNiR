pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Memory pressure monitoring for JSGCHeap accumulation (#164).
// Qt's V4 JS engine creates memfd mappings that persist as "(deleted)" after
// Loader teardown. This service monitors that accumulation and notifies the
// user when a restart would help reclaim memory.
Singleton {
    id: root

    // ── Config ────────────────────────────────────────────────────────────
    readonly property bool enabled: Config.options?.performance?.memoryMonitoring ?? true
    readonly property bool notifyEnabled: Config.options?.performance?.memoryWarningNotification ?? false
    readonly property int deletedMappingsThreshold: Config.options?.performance?.jsgcThreshold ?? 300
    readonly property int checkIntervalMs: 300000  // check every 5 min

    // ── State ─────────────────────────────────────────────────────────────
    property int currentDeletedMappings: 0
    property int currentTotalMappings: 0
    property bool notificationShown: false
    property bool userDismissed: false

    // ── Public API ────────────────────────────────────────────────────────
    function forceGc(): void {
        gc()
        _log("gc() forced")
    }

    function restart(): void {
        _log("user requested restart")
        Quickshell.execDetached([
            "notify-send",
            "iNiR",
            Translation.tr("Restarting shell..."),
            "-a", "Shell",
            "--hint=int:transient:1",
        ])
        // Small delay so notification shows
        Qt.callLater(() => {
            ShellExec.inir(["service", "restart"])
        })
    }

    function dismiss(): void {
        root.userDismissed = true
        root.notificationShown = false
        _log("user dismissed memory warning")
    }

    function reset(): void {
        root.userDismissed = false
        root.notificationShown = false
        _log("reset state")
    }

    function getStats(): string {
        return JSON.stringify({
            deletedMappings: root.currentDeletedMappings,
            totalMappings: root.currentTotalMappings,
            threshold: root.deletedMappingsThreshold,
            notificationShown: root.notificationShown,
            userDismissed: root.userDismissed,
            residentMb: root.residentMb,
            availableMb: root.availableMb,
            floorMb: root.floorMb,
            over: root.over,
            enabled: root.enabled,
            notifyEnabled: root.notifyEnabled
        })
    }

    // ── Internal ──────────────────────────────────────────────────────────
    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1")
            console.log("[MemoryPressure]", ...args)
    }

    function _checkMemoryPressure(): void {
        if (!root.enabled) return
        // With preload off, text() starts the read; onLoaded counts.
        _maps.reload()
        _maps.text()
    }

    function _notifyUser(): void {
        if (!root.notifyEnabled) { _log("threshold hit, notification disabled"); return }
        if (root.notificationShown || root.userDismissed) return
        
        root.notificationShown = true
        const mbEstimate = Math.round(root.currentDeletedMappings * 0.5)  // ~0.5 MB per mapping

        Quickshell.execDetached([
            "notify-send",
            "iNiR",
            Translation.tr("Memory usage is high (~%1 MB accumulated). A restart would free it. Run: inir memory restart").arg(mbEstimate),
            "-u", "critical",
            "-a", "Shell",
        ])
        _log("notified user, estimated leak:", mbEstimate, "MB")
    }

    // ── Timers ────────────────────────────────────────────────────────────
    Timer {
        id: _checkTimer
        interval: root.checkIntervalMs
        repeat: true
        running: root.enabled
        onTriggered: root._checkMemoryPressure()
    }

    // ── Maps reader ───────────────────────────────────────────────────────
    // The shell's own maps, read in process: a grep in an sh child ran a shell every check.
    FileView {
        id: _maps
        path: "/proc/self/maps"
        preload: false
        onLoaded: {
            const lines = _maps.text().split("\n").filter(l => l.includes("JSGCHeap"))
            root.currentTotalMappings = lines.length
            root.currentDeletedMappings = lines.filter(l => l.includes("deleted")).length
            if (root.currentDeletedMappings >= root.deletedMappingsThreshold) {
                _log("threshold exceeded:", root.currentDeletedMappings, ">=", root.deletedMappingsThreshold)
                root._notifyUser()
            }
        }
    }

    // ── Pressure ──────────────────────────────────────────────────────────
    // What the system has left, read every 15 s. Short of it, what is kept built after its close (Settings, the
    // gallery, Spotlight, Orbit: KeepWarm and the families' panel keeps) lets go at once. The pressure is the system's,
    // never the shell's own size: a fixed budget on the shell (480 MB until 11-28) sat under what a desktop with
    // widgets uses, so Settings was dropped at every close and rebuilt, slowly, at every open.
    property int residentMb: 0
    property int availableMb: -1
    property int totalMb: 0
    readonly property int floorMb: Math.max(768, Math.round(root.totalMb * 0.1))
    readonly property bool over: root.availableMb >= 0 && root.availableMb < root.floorMb
    function kib(text: string, key: string): int {
        return Math.round(Number(text.match(new RegExp(key + ":\\s*(\\d+)"))?.[1] ?? 0) / 1024)
    }
    FileView {
        id: status
        path: "/proc/self/status"
        onLoaded: root.residentMb = root.kib(status.text(), "VmRSS")
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const text = meminfo.text()
            root.totalMb = root.kib(text, "MemTotal")
            root.availableMb = root.kib(text, "MemAvailable")
        }
    }
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            status.reload()
            meminfo.reload()
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    /// Memory pressure monitoring for JSGCHeap accumulation (Qt V4 memfd leak). Notifies user when memory is high,
    /// lets them decide when to restart.
    IpcHandler {
        target: "memory"
        /// Force JavaScript garbage collection
        function collect(): string { root.forceGc(); return "gc() called" }
        /// Return JSON with deleted mappings count, threshold, and state
        function stats(): string { return root.getStats() }
        /// Restart the shell to free accumulated memory
        function restart(): string { root.restart(); return "restarting..." }
        /// Dismiss the memory warning notification
        function dismiss(): string { root.dismiss(); return "dismissed" }
        /// Reset notification state (re-enables warnings)
        function reset(): string { root.reset(); return "reset" }
    }

    Component.onCompleted: {
        if (!root.enabled) return
        Qt.callLater(() => {
            _checkTimer.start()
            // Prime it once: the timer's first tick is a full interval away, so
            // without this the service reports 0 mappings for the first 5 minutes
            // after every restart.
            root._checkMemoryPressure()
        })
    }
}
