pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// Self-healing memory management for JSGCHeap accumulation (#164).
// Qt's V4 JS engine creates memfd mappings that persist as "(deleted)" after
// Loader teardown. This service monitors that accumulation and schedules
// soft reloads when the shell is idle to reclaim memory without user disruption.
Singleton {
    id: root

    // ── Config ────────────────────────────────────────────────────────────
    readonly property bool enabled: Config.options?.performance?.autoMemoryManagement ?? true
    readonly property int deletedMappingsThreshold: Config.options?.performance?.jsgcThreshold ?? 300
    readonly property int idleDelayMs: 60000  // 60s idle before restart
    readonly property int checkIntervalMs: 120000  // check every 2 min

    // ── State ─────────────────────────────────────────────────────────────
    property int currentDeletedMappings: 0
    property int currentTotalMappings: 0
    property int lastReloadTimestamp: 0
    property bool reloadScheduled: false

    // ── Public API ────────────────────────────────────────────────────────
    function forceGc(): void {
        gc()
        _log("gc() forced")
    }

    function scheduleReload(): void {
        if (root.reloadScheduled) return
        root.reloadScheduled = true
        _idleReloadTimer.restart()
        _log("soft reload scheduled in", root.idleDelayMs, "ms")
    }

    function cancelReload(): void {
        root.reloadScheduled = false
        _idleReloadTimer.stop()
    }

    function getStats(): string {
        return JSON.stringify({
            deletedMappings: root.currentDeletedMappings,
            totalMappings: root.currentTotalMappings,
            threshold: root.deletedMappingsThreshold,
            reloadScheduled: root.reloadScheduled,
            lastReload: root.lastReloadTimestamp,
            enabled: root.enabled
        })
    }

    // ── Internal ──────────────────────────────────────────────────────────
    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1")
            console.log("[MemoryPressure]", ...args)
    }

    function _checkMemoryPressure(): void {
        if (!root.enabled) return
        _mapsReader.running = true
    }

    function _performReload(): void {
        root.reloadScheduled = false
        root.lastReloadTimestamp = Date.now()
        _log("performing restart, deleted mappings:", root.currentDeletedMappings)
        
        // Full restart via systemd - only way to release JSGCHeap memfd mappings
        // Soft reload doesn't help because the process stays alive
        Quickshell.execDetached(["systemctl", "--user", "restart", "inir.service"])
    }

    // ── Timers ────────────────────────────────────────────────────────────
    Timer {
        id: _checkTimer
        interval: root.checkIntervalMs
        repeat: true
        running: root.enabled
        onTriggered: root._checkMemoryPressure()
    }

    Timer {
        id: _idleReloadTimer
        interval: root.idleDelayMs
        repeat: false
        onTriggered: {
            // Only reload if still over threshold
            if (root.currentDeletedMappings >= root.deletedMappingsThreshold) {
                root._performReload()
            } else {
                root.reloadScheduled = false
                _log("reload cancelled - below threshold now")
            }
        }
    }

    // ── Maps reader ───────────────────────────────────────────────────────
    Process {
        id: _mapsReader
        command: ["sh", "-c", "grep -c 'JSGCHeap.*deleted' /proc/self/maps 2>/dev/null || echo 0; grep -c JSGCHeap /proc/self/maps 2>/dev/null || echo 0"]
        stdout: SplitParser {
            property int lineNum: 0
            onRead: line => {
                const val = parseInt(line.trim()) || 0
                if (lineNum === 0) {
                    root.currentDeletedMappings = val
                } else {
                    root.currentTotalMappings = val
                }
                lineNum++
            }
        }
        onExited: (code, status) => {
            _mapsReader.stdout.lineNum = 0
            
            if (root.currentDeletedMappings >= root.deletedMappingsThreshold && !root.reloadScheduled) {
                _log("threshold exceeded:", root.currentDeletedMappings, ">=", root.deletedMappingsThreshold)
                root.scheduleReload()
            }
        }
    }

    // ── IPC ───────────────────────────────────────────────────────────────
    IpcHandler {
        target: "memory"
        function collect(): string { root.forceGc(); return "gc() called" }
        function stats(): string { return root.getStats() }
        function reload(): string { root.scheduleReload(); return "reload scheduled" }
        function cancel(): string { root.cancelReload(); return "reload cancelled" }
    }

    Component.onCompleted: {
        if (!root.enabled) return
        // Initial check after 10s
        Qt.callLater(() => {
            _checkTimer.start()
            root._checkMemoryPressure()
        })
    }
}
