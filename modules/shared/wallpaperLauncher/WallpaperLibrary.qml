pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property list<var> staticEntries: []
    property list<var> animatedEntries: []
    property bool scanning: false
    property string directory: ""
    property string _scanSignature: ""
    property var _pendingRefresh: null

    signal refreshed()

    function refresh(path: string, extraPaths = [], force = false): void {
        const cleanPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!cleanPath) return

        // Scan the configured root plus every other folder the user is actually
        // working in. Deriving roots from one source made the list unstable:
        // videos appeared only while a wallpaper from their folder happened to
        // be applied.
        const roots = [cleanPath]
        for (const rawExtra of (extraPaths ?? [])) {
            const extra = FileUtils.trimFileProtocol(String(rawExtra ?? ""))
            if (!extra) continue
            // Skip anything already covered by, or covering, an accepted root.
            const redundant = roots.some(existing => {
                const existingPrefix = existing.endsWith("/") ? existing : existing + "/"
                const extraPrefix = extra.endsWith("/") ? extra : extra + "/"
                return extra === existing || extra.startsWith(existingPrefix)
                    || existing.startsWith(extraPrefix)
            })
            if (!redundant) roots.push(extra)
        }

        const signature = JSON.stringify(roots)
        if (!force && signature === root._scanSignature
                && (root.staticEntries.length > 0 || root.animatedEntries.length > 0))
            return

        if (scanProcess.running) {
            root._pendingRefresh = ({ path: cleanPath, extraPaths, force })
            return
        }

        root.directory = cleanPath
        root._scanSignature = signature
        root.scanning = true
        scanProcess.exec([
            "find", ...roots, "-type", "f", "(",
            "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o",
            "-iname", "*.png", "-o", "-iname", "*.webp", "-o",
            "-iname", "*.avif", "-o", "-iname", "*.bmp", "-o",
            "-iname", "*.svg", "-o", "-iname", "*.gif", "-o",
            "-iname", "*.mp4", "-o", "-iname", "*.webm", "-o",
            "-iname", "*.mkv", "-o", "-iname", "*.avi", "-o",
            "-iname", "*.mov", ")", "-print"
        ])
    }

    function consume(rawOutput: string): void {
        const staticItems = []
        const animatedItems = []
        const prefix = root.directory.endsWith("/") ? root.directory : root.directory + "/"
        // Scan roots can overlap (the current wallpaper's folder may contain the
        // configured root), so the same file can be printed twice.
        const seen = ({})
        for (const rawLine of String(rawOutput ?? "").split("\n")) {
            const path = rawLine.trim()
            if (!path || seen[path]) continue
            seen[path] = true
            const lower = path.toLowerCase()
            const isVideo = [".mp4", ".webm", ".mkv", ".avi", ".mov"]
                .some(extension => lower.endsWith(extension))
            const isGif = lower.endsWith(".gif")
            const entry = {
                path: path,
                name: FileUtils.fileNameForPath(path),
                relativePath: path.startsWith(prefix) ? path.slice(prefix.length) : path,
                kind: isVideo ? "video" : isGif ? "gif" : "static"
            }
            // Animated = anything that moves, wherever it lives. A video outside a
            // conventional folder must not vanish from both lists.
            if (isVideo || isGif)
                animatedItems.push(entry)
            else
                staticItems.push(entry)
        }
        const byName = (left, right) => left.relativePath.localeCompare(right.relativePath)
        staticItems.sort(byName)
        animatedItems.sort(byName)
        root.staticEntries = staticItems
        root.animatedEntries = animatedItems
        root.refreshed()
    }

    Process {
        id: scanProcess
        stdout: StdioCollector {
            onStreamFinished: root.consume(text)
        }
        onExited: (exitCode, exitStatus) => {
            root.scanning = false
            // One unreadable root makes find exit nonzero even though the other
            // roots produced results — only report empty when nothing was found.
            if (exitCode !== 0 && root.staticEntries.length === 0
                    && root.animatedEntries.length === 0)
                root.refreshed()

            const pending = root._pendingRefresh
            root._pendingRefresh = null
            if (pending)
                Qt.callLater(() => root.refresh(pending.path,
                    pending.extraPaths, pending.force))
        }
    }
}
