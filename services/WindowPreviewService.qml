pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions

/**
 * WindowPreviewService - Window preview caching for TaskView
 * 
 * Strategy:
 * - Capture previews ONLY when TaskView opens
 * - Cache in ~/.cache/inir/window-previews/
 * - Only capture windows that don't have a recent preview
 * - Clean up on window close
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    readonly property string previewDir: FileUtils.trimFileProtocol(Directories.genericCache) + "/inir/window-previews"
    
    // Map of windowId -> { path, timestamp }
    property var previewCache: ({})
    
    property bool initialized: false
    property bool capturing: false
    
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
    
    // Clipboard save/restore: the script does its own save/restore but there's a race
    // with async niri screenshot-window IPC. We do a SECOND restore from QML after 
    // the cliphistRestoreTimer fires, guaranteeing the clipboard is clean.
    property string _savedClipMime: ""
    property string _savedClipFile: ""

    Process {
        id: clipboardSaveProcess
        property bool saveOk: false
        // Dynamically set command before running
        onExited: (exitCode) => {
            clipboardSaveProcess.saveOk = (exitCode === 0)
            if (exitCode !== 0) {
                root._savedClipMime = ""
                root._savedClipFile = ""
            }
        }
    }

    Process {
        id: clipboardRestoreProcess
        onExited: {
            // Cleanup temp file
            if (root._savedClipFile.length > 0) {
                Quickshell.execDetached(["/usr/bin/rm", "-f", root._savedClipFile])
                root._savedClipFile = ""
                root._savedClipMime = ""
            }
            // Clipboard restored — now safe to unsuppress and refresh cliphist
            Cliphist.suppressRefresh = false
            Cliphist.refresh()
        }
    }

    function _saveClipboard(): void {
        const tmpFile = "/tmp/inir-clipboard-qml-" + Date.now() + ".tmp"
        root._savedClipFile = tmpFile
        // Detect MIME and save in one shot
        clipboardSaveProcess.command = ["/usr/bin/bash", "-c",
            `mime=$(/usr/bin/wl-paste -l 2>/dev/null | head -1); ` +
            `[ -z "$mime" ] && exit 1; ` +
            `echo "$mime" > '${tmpFile}.mime'; ` +
            `/usr/bin/wl-paste --type "$mime" > '${tmpFile}' 2>/dev/null`
        ]
        clipboardSaveProcess.running = true
    }

    function _restoreClipboard(): void {
        if (root._savedClipFile.length === 0) return
        const tmpFile = root._savedClipFile
        clipboardRestoreProcess.command = ["/usr/bin/bash", "-c",
            `[ -f '${tmpFile}.mime' ] && [ -f '${tmpFile}' ] || exit 1; ` +
            `mime=$(cat '${tmpFile}.mime'); ` +
            `/usr/bin/wl-copy --type "$mime" < '${tmpFile}' 2>/dev/null; ` +
            `rm -f '${tmpFile}' '${tmpFile}.mime' 2>/dev/null`
        ]
        clipboardRestoreProcess.running = true
    }

    signal captureComplete()
    signal previewUpdated(int windowId)

    Component.onCompleted: {
        // Lazy init: only when TaskView actually requests previews.
    }
    
    function initialize(): void {
        if (initialized) return
        initialized = true
        ensureDirProcess.running = true
    }
    
    Process {
        id: ensureDirProcess
        command: ["/usr/bin/mkdir", "-p", root.previewDir]
        onExited: scanProcess.running = true
    }
    
    Process {
        id: scanProcess
        command: ["/usr/bin/ls", "-1", root.previewDir]
        stdout: SplitParser {
            onRead: data => {
                const filename = data.trim()
                const match = filename.match(/^window-(\d+)\.png$/)
                if (match) {
                    const id = parseInt(match[1])
                    root.previewCache[id] = {
                        path: root.previewDir + "/" + filename,
                        timestamp: Date.now()
                    }
                }
            }
        }
        onExited: {
            _log("[WindowPreviewService] Loaded", Object.keys(root.previewCache).length, "cached previews")
            root.cleanupOrphans()
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
            }
            previewCache = Object.assign({}, previewCache)
            
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
    function captureForTaskView(): void {
        if (!initialized) initialize()

        // Always emit captureComplete immediately so cached previews show instantly
        root.captureComplete()

        if (capturing) return

        // Cooldown: don't re-capture if we just finished one
        if (Date.now() - _lastCaptureEndTime < _captureCooldownMs && initialCapturesDone) {
            return
        }

        captureDebounceTimer.restart()
    }

    // Internal: actual capture logic, called after debounce
    function _doCapture(): void {
        if (capturing) return
        
        const windows = NiriService.windows ?? []
        if (windows.length === 0) return
        
        const now = Date.now()
        const idsToCapture = []
        
        for (const win of windows) {
            const cached = previewCache[win.id]
            // Capture if: no preview or preview is stale
            const needsCapture = !cached || 
                                 (now - cached.timestamp) > previewValidityMs
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
        initialCapturesDone = true
        Cliphist.suppressRefresh = true
        root._saveClipboard()
        
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
        Cliphist.suppressRefresh = true
        root._saveClipboard()
        
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
                    root.previewUpdated(id)
                }
                root.previewCache = Object.assign({}, root.previewCache)
            }
            
            idsToCapture = []
            // Restore clipboard refresh after script cleanup has finished
            cliphistRestoreTimer.restart()
            root.captureComplete()
        }
    }
    
    // Clean up when window closes
    Connections {
        target: NiriService
        enabled: root.initialized  // Skip event processing until initialized
        
        function onWindowsChanged(): void {
            cleanupTimer.restart()
        }
    }
    
    Timer {
        id: cliphistRestoreTimer
        interval: 1500
        onTriggered: {
            if (root._savedClipFile.length === 0) {
                // Nothing to restore — just unsuppress and refresh
                Cliphist.suppressRefresh = false
                Cliphist.refresh()
            } else {
                // Restore clipboard first; unsuppress+refresh happens in
                // clipboardRestoreProcess.onExited after wl-copy finishes.
                root._restoreClipboard()
            }
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
    
    function clearPreviews(): void {
        Quickshell.execDetached(["/usr/bin/rm", "-rf", previewDir])
        previewCache = {}
    }
}
