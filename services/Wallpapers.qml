pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.services
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "root:"
import "root:modules/common/functions/md5.js" as MD5

Singleton {
    id: root

    // Wallpaper path resolution for aurora/backdrop
    readonly property bool isWaffleFamily: (Config.options?.panelFamily ?? "ii") === "waffle"
    readonly property bool useBackdropWallpaper: isWaffleFamily
        ? (Config.options?.waffles?.background?.backdrop?.hideWallpaper ?? false)
        : (Config.options?.background?.backdrop?.hideWallpaper ?? false)

    // Resolve the "main" wallpaper path — multi-monitor aware
    // When multi-monitor is enabled, uses the focused monitor's wallpaper
    // so Aurora blur/glass on all panels matches what's actually on screen.
    readonly property string _resolvedMainWallpaperPath: {
        if (WallpaperListener.multiMonitorEnabled) {
            const focused = WallpaperListener.getFocusedMonitor()
            if (focused) {
                const data = WallpaperListener.effectivePerMonitor[focused]
                if (data && data.path) return data.path
            }
        }
        return Config.options?.background?.wallpaperPath ?? ""
    }

    readonly property bool useBackdropForColors: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false

    readonly property string effectiveWallpaperPath: {
        if (useBackdropWallpaper || useBackdropForColors) {
            if (isWaffleFamily) {
                const wBackdrop = Config.options?.waffles?.background?.backdrop ?? {}
                const useBackdropOwn = !(wBackdrop.useMainWallpaper ?? true)
                if (useBackdropOwn && wBackdrop.wallpaperPath) return wBackdrop.wallpaperPath
                const wBg = Config.options?.waffles?.background ?? {}
                const useMainForWaffle = wBg.useMainWallpaper ?? true
                return useMainForWaffle ? _resolvedMainWallpaperPath : (wBg.wallpaperPath || _resolvedMainWallpaperPath)
            }
            const iiBackdrop = Config.options?.background?.backdrop ?? {}
            const useMain = iiBackdrop.useMainWallpaper ?? true
            const mainPath = _resolvedMainWallpaperPath
            return useMain ? mainPath : (iiBackdrop.wallpaperPath || mainPath)
        }
        if (isWaffleFamily) {
            const wBg = Config.options?.waffles?.background ?? {}
            const useMain = wBg.useMainWallpaper ?? true
            if (useMain) return _resolvedMainWallpaperPath
            return wBg.wallpaperPath || _resolvedMainWallpaperPath
        }
        return _resolvedMainWallpaperPath
    }

    readonly property string effectiveWallpaperUrl: {
        const path = root.effectiveWallpaperPath
        if (!path || path.length === 0) return ""
        // For videos, return image-safe URL (all consumers are Image/ColorQuantizer)
        if (root.isVideoFile(path)) {
            const _dep = root.videoFirstFrames // reactive binding
            const ff = root.videoFirstFrames[path]
            if (ff) return ff.startsWith("file://") ? ff : "file://" + ff
            const thumb = Config.options?.background?.thumbnailPath ?? ""
            if (thumb) return thumb.startsWith("file://") ? thumb : "file://" + thumb
            root.ensureVideoFirstFrame(path)
            return ""
        }
        return path.startsWith("file://") ? path : ("file://" + path)
    }

    // ── Video first-frame system ──────────────────────────────────────────
    // Generates and caches first-frame JPGs for video wallpapers (same dir as switchwall.sh)
    readonly property string _videoThumbDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
        return xdg + "/hypr/custom/scripts/mpvpaper_thumbnails"
    }

    property var videoFirstFrames: ({})

    function isVideoFile(path: string): bool {
        if (!path) return false
        const lp = path.toLowerCase()
        return lp.endsWith(".mp4") || lp.endsWith(".webm") || lp.endsWith(".mkv") || lp.endsWith(".avi") || lp.endsWith(".mov")
    }

    function getVideoFirstFramePath(videoPath: string): string {
        if (!videoPath) return ""
        return root.videoFirstFrames[videoPath] ?? ""
    }

    property var _ffPending: ({})

    function ensureVideoFirstFrame(videoPath: string) {
        if (!videoPath || !isVideoFile(videoPath)) return
        if (root.videoFirstFrames[videoPath]) return
        if (root._ffPending[videoPath]) return

        // Check config thumbnailPath (global wallpaper match)
        const configWp = Config.options?.background?.wallpaperPath ?? ""
        const configThumb = Config.options?.background?.thumbnailPath ?? ""
        if (configWp === videoPath && configThumb) {
            _cacheFirstFrame(videoPath, configThumb)
            return
        }

        // Queue async check → generate (with dedup)
        root._ffPending[videoPath] = true
        const basename = videoPath.split("/").pop()
        const expectedPath = root._videoThumbDir + "/" + basename + ".jpg"
        root._ffQueue.push({ videoPath: videoPath, outputPath: expectedPath })
        if (!_ffCheckProc.running && !_ffGenProc.running) _processNextFF()
    }

    function _cacheFirstFrame(videoPath: string, imagePath: string) {
        const copy = Object.assign({}, root.videoFirstFrames)
        copy[videoPath] = imagePath
        root.videoFirstFrames = copy
    }

    property var _ffQueue: []

    function _processNextFF() {
        if (root._ffQueue.length === 0) return
        const item = root._ffQueue.shift()
        _ffCheckProc._videoPath = item.videoPath
        _ffCheckProc._outputPath = item.outputPath
        _ffCheckProc.command = ["test", "-f", item.outputPath]
        _ffCheckProc.running = true
    }

    Process {
        id: _ffCheckProc
        property string _videoPath
        property string _outputPath
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root._cacheFirstFrame(_ffCheckProc._videoPath, _ffCheckProc._outputPath)
                root._processNextFF()
            } else {
                _ffGenProc._videoPath = _ffCheckProc._videoPath
                _ffGenProc._outputPath = _ffCheckProc._outputPath
                _ffGenProc.command = ["bash", "-c",
                    "mkdir -p " + JSON.stringify(root._videoThumbDir) +
                    " && ffmpeg -y -i " + JSON.stringify(_ffCheckProc._videoPath) +
                    " -vframes 1 -q:v 2 " + JSON.stringify(_ffCheckProc._outputPath)]
                _ffGenProc.running = true
            }
        }
    }

    Process {
        id: _ffGenProc
        property string _videoPath
        property string _outputPath
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root._cacheFirstFrame(_ffGenProc._videoPath, _ffGenProc._outputPath)
            }
            root._processNextFF()
        }
    }
    // ── End video first-frame system ──────────────────────────────────────

    property string thumbgenScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/thumbgen-venv.sh`
    property string generateThumbnailsMagickScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/generate-thumbnails-magick.sh`
    
    // Calculate standard Freedesktop thumbnail path
    // size: "normal" (128), "large" (256), "x-large" (512), "xx-large" (1024)
    function getExpectedThumbnailPath(filePath: string, size = "large"): string {
        if (!filePath) return ""
        // Ensure path is absolute and clean
        let cleanPath = FileUtils.trimFileProtocol(filePath)
        if (!cleanPath.startsWith("/")) cleanPath = Quickshell.env("PWD") + "/" + cleanPath
        
        // Encode URI path segments (similar to python urllib.parse.quote(p, safe=""))
        // JS encodeURIComponent encodes everything except A-Za-z0-9-_.!~*'()
        // We need to match Python's behavior for strict path encoding
        const parts = cleanPath.split("/")
        const encodedParts = parts.map(p => {
            // Manual encoding for characters that encodeURIComponent misses or handles differently if needed
            // But standard encodeURIComponent is usually close enough for file paths
            return encodeURIComponent(p).replace(/[!'()*]/g, function(c) {
                return '%' + c.charCodeAt(0).toString(16);
            });
        })
        const url = "file://" + encodedParts.join("/")
        
        const md5Hash = MD5.hash(url)
        const cacheDir = Quickshell.env("HOME") + "/.cache/thumbnails/" + size
        return cacheDir + "/" + md5Hash + ".png"
    }

    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: Qt.resolvedUrl(`${Directories.pictures}/Wallpapers`)
    property alias folderModel: folderModel
    property string searchQuery: ""
    readonly property list<string> extensions: ["jpg", "jpeg", "png", "webp", "avif", "bmp", "svg", "gif", "mp4", "webm", "mkv", "avi", "mov"]
    property list<string> wallpapers: []
    readonly property bool thumbnailGenerationRunning: thumbgenProc.running
    property real thumbnailGenerationProgress: 0

    signal changed()
    signal folderChanged()
    signal thumbnailGenerated(directory: string)
    signal thumbnailGeneratedFile(filePath: string)

    function load() {}
    function refresh() {} // Compatibility - FolderListModel auto-refreshes

    Process { id: applyProc }
    
    function openFallbackPicker(darkMode = Appearance.m3colors.darkmode) {
        applyProc.exec([Directories.wallpaperSwitchScriptPath, "--mode", (darkMode ? "dark" : "light")])
    }

    function apply(path, darkMode = Appearance.m3colors.darkmode, monitorName = "") {
        if (!path || path.length === 0) return

        if (monitorName !== "") {
            // Per-monitor: update config directly in QML to avoid race condition
            // (switchwall.sh and QML both write config.json — the 50ms write timer causes data loss)
            updatePerMonitorConfig(path, monitorName)
            root.changed()
            return
        }

        // Global wallpaper: use switchwall.sh for color generation + system theming
        applyProc.exec([
            Directories.wallpaperSwitchScriptPath,
            "--image", path,
            "--mode", (darkMode ? "dark" : "light")
        ])
        root.changed()
    }

    function updatePerMonitorConfig(path: string, monitorName: string) {
        const currentArray = Config.options?.background?.wallpapersByMonitor ?? []
        const newArray = []
        for (const entry of currentArray) {
            if (entry && entry.monitor !== monitorName) {
                newArray.push(entry)
            }
        }

        let wsFirst = 1, wsLast = 10
        if (CompositorService.isNiri) {
            const range = detectNiriWorkspaceRange(monitorName)
            if (range) { wsFirst = range.first; wsLast = range.last }
        }

        newArray.push({
            monitor: monitorName,
            path: path,
            workspaceFirst: wsFirst,
            workspaceLast: wsLast
        })

        Config.setNestedValue("background.wallpapersByMonitor", newArray)
    }

    function updatePerMonitorBackdropConfig(backdropPath: string, monitorName: string) {
        const currentArray = Config.options?.background?.wallpapersByMonitor ?? []
        const newArray = []
        let found = false
        for (const entry of currentArray) {
            if (!entry) continue
            if (entry.monitor === monitorName) {
                found = true
                newArray.push(Object.assign({}, entry, { backdropPath: backdropPath }))
            } else {
                newArray.push(entry)
            }
        }
        if (!found) {
            // Monitor not in array yet — create entry with global wallpaper as main path
            let wsFirst = 1, wsLast = 10
            if (CompositorService.isNiri) {
                const range = detectNiriWorkspaceRange(monitorName)
                if (range) { wsFirst = range.first; wsLast = range.last }
            }
            newArray.push({
                monitor: monitorName,
                path: Config.options?.background?.wallpaperPath ?? "",
                workspaceFirst: wsFirst,
                workspaceLast: wsLast,
                backdropPath: backdropPath
            })
        }
        Config.setNestedValue("background.wallpapersByMonitor", newArray)
    }

    Process {
        id: selectProc
        property string filePath: ""
        property bool darkMode: Appearance.m3colors.darkmode
        property string monitorName: ""
        function select(filePath, darkMode = Appearance.m3colors.darkmode, monitorName = "") {
            selectProc.filePath = filePath
            selectProc.darkMode = darkMode
            selectProc.monitorName = monitorName
            selectProc.exec(["test", "-d", FileUtils.trimFileProtocol(filePath)])
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                setDirectory(selectProc.filePath)
                return
            }
            root.apply(selectProc.filePath, selectProc.darkMode, selectProc.monitorName)
        }
    }

    function select(filePath, darkMode = Appearance.m3colors.darkmode, monitorName = "") {
        selectProc.select(filePath, darkMode, monitorName)
    }

    function randomFromCurrentFolder(darkMode = Appearance.m3colors.darkmode, monitorName = "") {
        if (folderModel.count === 0) return
        const randomIndex = Math.floor(Math.random() * folderModel.count)
        const filePath = folderModel.get(randomIndex, "filePath")
        root.select(filePath, darkMode, monitorName)
    }

    // Detect workspace range for a monitor (Niri-specific)
    function detectNiriWorkspaceRange(monitorName: string): var {
        if (!CompositorService.isNiri) return null

        const workspaces = NiriService.workspaces ?? {}
        const outputWorkspaces = []

        for (const wsId in workspaces) {
            const ws = workspaces[wsId]
            if (ws && ws.output === monitorName) {
                outputWorkspaces.push(ws.idx)
            }
        }

        if (outputWorkspaces.length === 0) return null

        outputWorkspaces.sort((a, b) => a - b)
        return {
            first: outputWorkspaces[0],
            last: outputWorkspaces[outputWorkspaces.length - 1]
        }
    }

    Process {
        id: validateDirProc
        property string nicePath: ""
        property bool _pendingFileCheck: false
        function setDirectoryIfValid(path) {
            validateDirProc.nicePath = FileUtils.trimFileProtocol(path).replace(/\/+$/, "")
            if (/^\/*$/.test(validateDirProc.nicePath)) validateDirProc.nicePath = "/"
            validateDirProc._pendingFileCheck = false
            validateDirProc.exec(["test", "-d", validateDirProc.nicePath])
        }
        onExited: (exitCode, exitStatus) => {
            if (!validateDirProc._pendingFileCheck) {
                if (exitCode === 0) {
                    root.directory = Qt.resolvedUrl(validateDirProc.nicePath)
                    return
                }
                validateDirProc._pendingFileCheck = true
                validateDirProc.exec(["test", "-f", validateDirProc.nicePath])
                return
            }
            if (exitCode === 0) {
                root.directory = Qt.resolvedUrl(FileUtils.parentDirectory(validateDirProc.nicePath))
            }
        }
    }

    function setDirectory(path) {
        validateDirProc.setDirectoryIfValid(path)
    }
    function navigateUp() {
        folderModel.navigateUp()
    }
    function navigateBack() {
        folderModel.navigateBack()
    }
    function navigateForward() {
        folderModel.navigateForward()
    }

    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(root.defaultFolder)
        caseSensitive: false
        nameFilters: {
            const query = root.searchQuery.trim().toLowerCase()
            // Check if query is an extension filter (e.g., ".gif", ".mp4")
            if (query.startsWith(".")) {
                const ext = query.slice(1)
                if (root.extensions.includes(ext)) return [`*.${ext}`]
            }
            // Normal search: apply query to all extensions
            const searchParts = query.split(" ").filter(s => s.length > 0).map(s => `*${s}*`).join("")
            return root.extensions.map(ext => `*${searchParts}*.${ext}`)
        }
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Time
        sortReversed: false
        onCountChanged: {
            root.wallpapers = []
            for (let i = 0; i < folderModel.count; i++) {
                const path = folderModel.get(i, "filePath") || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL"))
                if (path && path.length) root.wallpapers.push(path)
            }
        }
        onFolderChanged: root.folderChanged()
    }

    property string _pendingThumbnailSize: ""
    property string _pendingThumbnailDir: ""
    
    function generateThumbnail(size: string) {
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) throw new Error("Invalid thumbnail size")
        root._pendingThumbnailSize = size
        root._pendingThumbnailDir = FileUtils.trimFileProtocol(root.directory)
        thumbgenDebounce.restart()
    }
    
    Timer {
        id: thumbgenDebounce
        interval: 300
        onTriggered: {
            if (thumbgenProc.running) return
            thumbgenProc.directory = root._pendingThumbnailDir
            thumbgenProc._size = root._pendingThumbnailSize
            thumbgenProc.command = [thumbgenScriptPath, "--size", root._pendingThumbnailSize, "--machine_progress", "-d", root._pendingThumbnailDir]
            root.thumbnailGenerationProgress = 0
            thumbgenProc.running = true
        }
    }

    Process {
        id: thumbgenProc
        property string directory
        property string _size: ""
        environment: ({
            "ILLOGICAL_IMPULSE_VIRTUAL_ENV": Quickshell.env("HOME") + "/.local/state/quickshell/.venv"
        })
        stdout: SplitParser {
            onRead: data => {
                let match = data.match(/PROGRESS (\d+)\/(\d+)/)
                if (match) root.thumbnailGenerationProgress = parseInt(match[1]) / parseInt(match[2])
                match = data.match(/FILE (.+)/)
                if (match) root.thumbnailGeneratedFile(match[1])
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                thumbgenFallbackProc.command = [generateThumbnailsMagickScriptPath, "--size", thumbgenProc._size, "-d", FileUtils.trimFileProtocol(thumbgenProc.directory)]
                thumbgenFallbackProc.running = true
                return
            }
            root.thumbnailGenerated(thumbgenProc.directory)
        }
    }

    Process {
        id: thumbgenFallbackProc
        onExited: root.thumbnailGenerated(thumbgenProc.directory)
    }
}
