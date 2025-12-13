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
 * - Cache in ~/.cache/ii-niri/window-previews/
 * - Only capture windows that don't have a recent preview
 * - Clean up on window close
 */
Singleton {
    id: root

    readonly property string previewDir: FileUtils.trimFileProtocol(Directories.genericCache) + "/ii-niri/window-previews"
    
    // Map of windowId -> { path, timestamp }
    property var previewCache: ({})
    
    property bool initialized: false
    property bool capturing: false
    
    // Preview validity duration (5 minutes)
    readonly property int previewValidityMs: 300000
    
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
            console.log("[WindowPreviewService] Loaded", Object.keys(root.previewCache).length, "cached previews")
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
    
    // Called when TaskView opens - capture windows that need it
    function captureForTaskView(): void {
        if (capturing) return

        if (!initialized) initialize()
        
        const windows = NiriService.windows ?? []
        if (windows.length === 0) return
        
        const now = Date.now()
        const idsToCapture = []
        
        for (const win of windows) {
            const cached = previewCache[win.id]
            // Capture if: no preview, preview is stale, or first open this session
            const needsCapture = !cached || 
                                 (now - cached.timestamp) > previewValidityMs ||
                                 !initialCapturesDone
            if (needsCapture) {
                idsToCapture.push(win.id)
            }
        }
        
        if (idsToCapture.length === 0) {
            captureComplete()
            return
        }
        
        console.log("[WindowPreviewService] Capturing", idsToCapture.length, "windows")
        capturing = true
        initialCapturesDone = true
        
        // Build command with IDs
        const cmd = ["/usr/bin/fish", Quickshell.shellPath("scripts/capture-windows.fish")]
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
        
        console.log("[WindowPreviewService] Force capturing all", windows.length, "windows")
        capturing = true
        
        const ids = windows.map(w => w.id)
        captureProcess.idsToCapture = ids
        captureProcess.command = [
            "/usr/bin/fish",
            Quickshell.shellPath("scripts/capture-windows.fish"),
            "--all"
        ]
        captureProcess.running = true
    }
    
    Process {
        id: captureProcess
        property var idsToCapture: []

        stdout: SplitParser {
            onRead: (line) => console.log("[WindowPreviewService:capture]", line)
        }
        stderr: SplitParser {
            onRead: (line) => console.log("[WindowPreviewService:capture][err]", line)
        }
        
        onExited: (exitCode, exitStatus) => {
            root.capturing = false

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
            root.captureComplete()
        }
    }
    
    // Clean up when window closes
    Connections {
        target: NiriService
        
        function onWindowsChanged(): void {
            if (!root.initialized) return
            cleanupTimer.restart()
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
