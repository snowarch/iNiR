pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions

/**
 * WindowPreviewService - Window preview caching for TaskView
 * 
 * Strategy:
 * - Capture previews only when a consumer actually requests them
 * - Cache in ~/.cache/inir/window-previews/
 * - Each consumer supplies its own freshness budget
 * - Mark a window dirty when it loses focus, but defer capture until requested
 * - Clean up on window close
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    readonly property string previewDir: FileUtils.trimFileProtocol(Directories.genericCache) + "/inir/window-previews"
    readonly property string sessionMarkerPath: previewDir + "/.niri-session"
    readonly property string sessionKey: NiriService.socketPath ?? ""
    
    // Map of windowId -> { path, timestamp }
    property var previewCache: ({})
    // Window ids whose pixels may have changed since their last capture. This
    // is event-driven metadata only: marking dirty never starts a screenshot.
    property var dirtyWindowIds: ({})
    
    property bool initialized: false
    property bool sessionReady: false
    property bool captureRequestedWhileInitializing: false
    property bool capturing: false
    property bool captureAllRequested: false
    property int captureAllMaxAgeMs: previewValidityMs
    property var requestedWindowIds: []
    property var requestedWindowMaxAgeMs: ({})
    property int lastFocusedWindowId: -1
    
    // Preview validity duration (5 minutes)
    readonly property int previewValidityMs: 300000

    // Debounce: coalesce rapid capture requests (e.g. hovering across multiple dock icons)
    Timer {
        id: captureDebounceTimer
        interval: 100  // 100ms debounce — fast enough to feel instant, slow enough to coalesce
        repeat: false
        onTriggered: root._doCapture()
    }
    // Cooldown: prevent captures from firing back-to-back after one completes
    property double _lastCaptureEndTime: 0
    readonly property int _captureCooldownMs: 2000  // 2 seconds between capture cycles
    
    signal captureComplete()
    signal previewUpdated(int windowId)

    Component.onCompleted: {
        // Lazy init: only when TaskView actually requests previews.
    }
    
    function initialize(): void {
        if (initialized) return
        initialized = true
        lastFocusedWindowId = Number(NiriService.activeWindow?.id ?? -1)
        ensureDirProcess.running = true
    }

    function markPreviewDirty(windowId): void {
        const id = Number(windowId)
        if (!Number.isFinite(id) || id <= 0 || dirtyWindowIds[id] === true)
            return
        const next = Object.assign({}, dirtyWindowIds)
        next[id] = true
        dirtyWindowIds = next
    }

    function _needsCapture(windowId, cached, maxAge, now): bool {
        return dirtyWindowIds[windowId] === true
            || !cached
            || (now - cached.timestamp) > maxAge
    }

    function _resumeRequestedCapture(): void {
        if (!captureRequestedWhileInitializing)
            return
        captureRequestedWhileInitializing = false
        captureDebounceTimer.restart()
    }

    function _normalizedMaxAge(maxAgeMs): int {
        const value = Number(maxAgeMs)
        if (!Number.isFinite(value)) return previewValidityMs
        return Math.max(0, Math.min(previewValidityMs, Math.round(value)))
    }

    function _queueWindowIds(windowIds, maxAgeMs): void {
        const normalizedMaxAge = root._normalizedMaxAge(maxAgeMs)
        if (windowIds === null || windowIds === undefined) {
            captureAllRequested = true
            captureAllMaxAgeMs = Math.min(captureAllMaxAgeMs, normalizedMaxAge)
            requestedWindowIds = []
            requestedWindowMaxAgeMs = ({})
            return
        }
        if (captureAllRequested) {
            captureAllMaxAgeMs = Math.min(captureAllMaxAgeMs, normalizedMaxAge)
            return
        }
        if (!Array.isArray(windowIds))
            return
        const merged = new Set(requestedWindowIds)
        const nextMaxAge = Object.assign({}, requestedWindowMaxAgeMs)
        for (const rawId of windowIds) {
            const id = Number(rawId)
            if (Number.isFinite(id) && id > 0) {
                merged.add(id)
                const previous = nextMaxAge[id]
                nextMaxAge[id] = previous === undefined
                    ? normalizedMaxAge : Math.min(previous, normalizedMaxAge)
            }
        }
        requestedWindowIds = Array.from(merged)
        requestedWindowMaxAgeMs = nextMaxAge
    }

    function _hasPendingCaptureRequest(): bool {
        return captureAllRequested || requestedWindowIds.length > 0
    }

    function _clearCaptureRequest(): void {
        captureAllRequested = false
        captureAllMaxAgeMs = previewValidityMs
        requestedWindowIds = []
        requestedWindowMaxAgeMs = ({})
    }

    function _pendingRequestNeedsCapture(): bool {
        const now = Date.now()
        const currentIds = captureAllRequested
            ? (NiriService.windows ?? []).map(window => window.id)
            : requestedWindowIds
        for (const id of currentIds) {
            const cached = previewCache[id]
            const maxAge = captureAllRequested ? captureAllMaxAgeMs
                : (requestedWindowMaxAgeMs[id] ?? previewValidityMs)
            if (root._needsCapture(id, cached, maxAge, now))
                return true
        }
        return false
    }

    function _resetForCurrentSession(): void {
        sessionResetProcess.running = true
    }
    
    Process {
        id: ensureDirProcess
        command: ["/usr/bin/mkdir", "-p", root.previewDir]
        onExited: sessionReadProcess.running = true
    }

    Process {
        id: sessionReadProcess
        command: ["/usr/bin/cat", root.sessionMarkerPath]
        stdout: StdioCollector { id: sessionReadOutput }
        onExited: exitCode => {
            if (!root.initialized || root.sessionReady) return
            const previousKey = exitCode === 0 ? sessionReadOutput.text.trim() : ""
            if (root.sessionKey.length > 0 && previousKey === root.sessionKey)
                scanProcess.running = true
            else
                root._resetForCurrentSession()
        }
    }

    FileView {
        id: sessionFileView
        path: root.sessionMarkerPath
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Process {
        id: sessionResetProcess
        command: [
            "/usr/bin/find", root.previewDir,
            "-maxdepth", "1", "-type", "f",
            "-name", "window-*.png", "-delete"
        ]
        onExited: {
            root.previewCache = ({})
            root.dirtyWindowIds = ({})
            root.sessionReady = true
            if (root.sessionKey.length > 0)
                sessionFileView.setText(root.sessionKey + "\n")
            root.captureComplete()
            root._resumeRequestedCapture()
        }
    }
    
    Process {
        id: scanProcess
        command: [
            "/usr/bin/find", root.previewDir,
            "-maxdepth", "1", "-type", "f",
            "-name", "window-*.png",
            "-printf", "%f\\t%T@\\n"
        ]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("\t")
                const filename = parts[0] ?? ""
                const match = filename.match(/^window-(\d+)\.png$/)
                if (match) {
                    const id = parseInt(match[1])
                    const mtimeSeconds = Number(parts[1])
                    root.previewCache[id] = {
                        path: root.previewDir + "/" + filename,
                        timestamp: Number.isFinite(mtimeSeconds)
                            ? Math.round(mtimeSeconds * 1000) : 0
                    }
                }
            }
        }
        onExited: {
            _log("[WindowPreviewService] Loaded", Object.keys(root.previewCache).length, "cached previews")
            root.cleanupOrphans()
            root.previewCache = Object.assign({}, root.previewCache)
            root.sessionReady = true
            root.captureComplete()
            root._resumeRequestedCapture()
        }
    }
    
    // Remove previews for windows that no longer exist
    function cleanupOrphans(): void {
        const windows = NiriService.windows ?? []
        const windowIds = new Set(windows.map(w => w.id))
        
        const toDelete = []
        for (const id in previewCache) {
            if (!windowIds.has(parseInt(id))) {
                toDelete.push(id)
            }
        }
        
        if (toDelete.length > 0) {
            for (const id of toDelete) {
                delete previewCache[id]
                delete dirtyWindowIds[id]
            }
            previewCache = Object.assign({}, previewCache)
            dirtyWindowIds = Object.assign({}, dirtyWindowIds)
            
            // Delete files
            const cmd = ["/usr/bin/rm", "-f"]
            for (const id of toDelete) {
                cmd.push(root.previewDir + "/window-" + id + ".png")
            }
            Quickshell.execDetached(cmd)
        }
    }

    // Track if we've done initial capture this session
    property bool initialCapturesDone: false
    
    // Called when TaskView/dock preview opens - debounced to coalesce rapid hover events
    function captureForTaskView(windowIds = null, maxAgeMs = previewValidityMs): void {
        root._queueWindowIds(windowIds, maxAgeMs)
        if (!initialized) initialize()

        // Always emit captureComplete immediately so cached previews show instantly
        root.captureComplete()

        if (!sessionReady) {
            captureRequestedWhileInitializing = true
            return
        }

        if (capturing) return

        // Cooldown: don't re-capture if we just finished one
        if (Date.now() - _lastCaptureEndTime < _captureCooldownMs
                && initialCapturesDone && !root._pendingRequestNeedsCapture()) {
            root._clearCaptureRequest()
            return
        }

        captureDebounceTimer.restart()
    }

    // Internal: actual capture logic, called after debounce
    function _doCapture(): void {
        if (capturing) return
        
        const allWindows = NiriService.windows ?? []
        const requestedIds = new Set(root.requestedWindowIds)
        const requestedMaxAge = Object.assign({}, root.requestedWindowMaxAgeMs)
        const captureEverything = root.captureAllRequested
        const captureEverythingMaxAge = root.captureAllMaxAgeMs
        root._clearCaptureRequest()
        const windows = captureEverything
            ? allWindows
            : allWindows.filter(window => requestedIds.has(window.id))
        if (windows.length === 0) return
        
        const now = Date.now()
        const idsToCapture = []
        
        for (const win of windows) {
            const cached = previewCache[win.id]
            const maxAge = captureEverything ? captureEverythingMaxAge
                : (requestedMaxAge[win.id] ?? previewValidityMs)
            // Capture if: no preview or preview is stale
            const needsCapture = root._needsCapture(win.id, cached, maxAge, now)
            if (needsCapture) {
                idsToCapture.push(win.id)
            }
        }
        
        if (idsToCapture.length === 0) {
            root.captureComplete()
            return
        }
        
        _log("[WindowPreviewService] Capturing", idsToCapture.length, "windows")
        capturing = true
        GlobalStates.windowPreviewCaptureActive = true
        initialCapturesDone = true
        Cliphist.suppressRefresh = true
        
        // Build command with IDs
        const cmd = ShellExec.supportsFish()
            ? ["/usr/bin/fish", Quickshell.shellPath("scripts/capture-windows.fish")]
            : ["/usr/bin/bash", Quickshell.shellPath("scripts/capture-windows.sh")]
        for (const id of idsToCapture) {
            cmd.push(id.toString())
        }
        
        captureProcess.idsToCapture = idsToCapture
        captureProcess.command = cmd
        captureProcess.running = true
    }
    
    // Capture ALL windows (force refresh)
    function captureAllWindows(): void {
        if (capturing) return

        if (!initialized) initialize()
        
        const windows = NiriService.windows ?? []
        if (windows.length === 0) return
        
        _log("[WindowPreviewService] Force capturing all", windows.length, "windows")
        capturing = true
        GlobalStates.windowPreviewCaptureActive = true
        Cliphist.suppressRefresh = true
        
        const ids = windows.map(w => w.id)
        captureProcess.idsToCapture = ids
        captureProcess.command = ShellExec.supportsFish()
            ? ["/usr/bin/fish", Quickshell.shellPath("scripts/capture-windows.fish"), "--all"]
            : ["/usr/bin/bash", Quickshell.shellPath("scripts/capture-windows.sh"), "--all"]
        captureProcess.running = true
    }
    
    Process {
        id: captureProcess
        property var idsToCapture: []

        stdout: SplitParser {
            onRead: (line) => _log("[WindowPreviewService:capture]", line)
        }
        stderr: SplitParser {
            onRead: (line) => _log("[WindowPreviewService:capture][err]", line)
        }
        
        onExited: (exitCode, exitStatus) => {
            root.capturing = false
            GlobalStates.windowPreviewCaptureActive = false
            root._lastCaptureEndTime = Date.now()

            if (exitCode !== 0) {
                console.log("[WindowPreviewService] capture process failed", exitCode, exitStatus)
            } else {
                const timestamp = Date.now()
                for (const id of idsToCapture) {
                    const path = root.previewDir + "/window-" + id + ".png"
                    root.previewCache[id] = {
                        path: path,
                        timestamp: timestamp
                    }
                    delete root.dirtyWindowIds[id]
                    root.previewUpdated(id)
                }
                root.previewCache = Object.assign({}, root.previewCache)
                root.dirtyWindowIds = Object.assign({}, root.dirtyWindowIds)
            }
            
            idsToCapture = []
            // The capture script has already removed only its own entries and
            // conditionally restored the clipboard before returning.
            Cliphist.suppressRefresh = false
            Cliphist.refresh()
            root.captureComplete()
            if (root._hasPendingCaptureRequest())
                captureDebounceTimer.restart()
        }
    }
    
    // Clean up when window closes
    Connections {
        target: NiriService
        enabled: root.initialized  // Skip event processing until initialized
        
        function onWindowsChanged(): void {
            cleanupTimer.restart()
        }


        function onActiveWindowChanged(): void {
            const nextId = Number(NiriService.activeWindow?.id ?? -1)
            if (root.lastFocusedWindowId > 0 && root.lastFocusedWindowId !== nextId)
                root.markPreviewDirty(root.lastFocusedWindowId)
            root.lastFocusedWindowId = nextId
        }
    }
    
    Timer {
        id: cleanupTimer
        interval: 1000
        onTriggered: root.cleanupOrphans()
    }
    
    // Public API
    function getPreviewUrl(windowId: int): string {
        const cached = previewCache[windowId]
        if (!cached) return ""
        return "file://" + cached.path + "?" + cached.timestamp
    }
    
    function hasPreview(windowId: int): bool {
        return previewCache[windowId] !== undefined
    }

    function previewAgeMs(windowId: int): double {
        const cached = previewCache[windowId]
        if (dirtyWindowIds[windowId] === true
                || !cached || !Number.isFinite(cached.timestamp))
            return Number.POSITIVE_INFINITY
        return Math.max(0, Date.now() - cached.timestamp)
    }
    
    function clearPreviews(): void {
        Quickshell.execDetached(["/usr/bin/rm", "-rf", previewDir])
        previewCache = {}
    }
}
