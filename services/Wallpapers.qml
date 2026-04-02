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

    readonly property bool _debugWallpaperUrls: (Quickshell.env("INIR_DEBUG_WALLPAPER_URLS") ?? "") === "1"

    // Suppression flag: prevents ThemeService from firing a duplicate
    // switchwall.sh run while a direct apply() is already in progress.
    property bool _applyInProgress: false
    property string _queuedApplyPath: ""
    property bool _queuedApplyDarkMode: Appearance.m3colors.darkmode
    property bool _queuedApplyNoSwitch: false
    readonly property string backendProvider: "awww"
    readonly property bool awwwBackendEnabled: true

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

    function currentThemingWallpaperPath(monitorName = ""): string {
        const targetMonitor = monitorName || (WallpaperListener.multiMonitorEnabled ? WallpaperListener.getFocusedMonitor() : "")
        const mainPath = currentMainWallpaperPath(targetMonitor)

        if (root.useBackdropWallpaper || root.useBackdropForColors) {
            if (root.isWaffleFamily) {
                const waffleBackdrop = Config.options?.waffles?.background?.backdrop ?? {}
                const waffleBackground = Config.options?.waffles?.background ?? {}
                const waffleMain = (waffleBackground.useMainWallpaper ?? true) ? mainPath : (waffleBackground.wallpaperPath || mainPath)
                return (waffleBackdrop.useMainWallpaper ?? true) ? waffleMain : (waffleBackdrop.wallpaperPath || waffleMain)
            }

            const iiBackdrop = Config.options?.background?.backdrop ?? {}
            if (iiBackdrop.useMainWallpaper ?? true)
                return mainPath
            if (WallpaperListener.multiMonitorEnabled && targetMonitor) {
                const monitorData = WallpaperListener.effectivePerMonitor[targetMonitor] ?? null
                if (monitorData && monitorData.backdropPath)
                    return monitorData.backdropPath
            }
            return iiBackdrop.wallpaperPath || mainPath
        }

        if (root.isWaffleFamily) {
            const waffleBackground = Config.options?.waffles?.background ?? {}
            return (waffleBackground.useMainWallpaper ?? true) ? mainPath : (waffleBackground.wallpaperPath || mainPath)
        }

        return mainPath
    }

    readonly property string effectiveWallpaperPath: {
        return root.currentThemingWallpaperPath()
    }

    readonly property string effectiveWallpaperUrl: {
        const path = root.effectiveWallpaperPath
        if (!path || path.length === 0) return ""
        // For videos, return image-safe URL (all consumers are Image/ColorQuantizer)
        if (root.isVideoFile(path)) {
            const _dep = root.videoFirstFrames // reactive binding
            const ff = root.videoFirstFrames[path]
            // Cache-bust so Image(cache:true) surfaces reload when the first frame appears.
            if (ff) return (ff.startsWith("file://") ? ff : "file://" + ff) + "?ff=1"
            const expected = root._videoThumbDir + "/" + MD5.hash(path) + ".jpg"
            root.ensureVideoFirstFrame(path)
            return "file://" + expected + "?ff=0"
        }
        return path.startsWith("file://") ? path : ("file://" + path)
    }

    onEffectiveWallpaperUrlChanged: {
        if (root._debugWallpaperUrls) {
            console.log("[Wallpapers] effectiveWallpaperPath=", root.effectiveWallpaperPath)
            console.log("[Wallpapers] effectiveWallpaperUrl=", root.effectiveWallpaperUrl)
        }
        // Schedule a deferred GC pass to reclaim orphaned pixmaps/textures
        // from the previous wallpaper.  The delay gives the scene graph one
        // frame to drop references before we collect.
        _gcTimer.restart()
    }

    Timer {
        id: _gcTimer
        interval: 2000
        onTriggered: gc()
    }

    // ── Video first-frame system ──────────────────────────────────────────
    // Generates and caches first-frame JPGs for video wallpapers
    readonly property string _videoThumbDir: {
        const xdgCache = Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
        return xdgCache + "/quickshell/video_thumbnails"
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
            const expected = root._videoThumbDir + "/" + MD5.hash(videoPath) + ".jpg"
            const thumbPath = FileUtils.trimFileProtocol(configThumb)
            if (thumbPath === expected) {
                _cacheFirstFrame(videoPath, expected)
                return
            }
        }

        // Queue async check → generate (with dedup)
        root._ffPending[videoPath] = true
        // Use md5 hash of full path to match switchwall.sh and avoid basename collisions
        const hash = MD5.hash(videoPath)
        const expectedPath = root._videoThumbDir + "/" + hash + ".jpg"
        root._ffQueue.push({ videoPath: videoPath, outputPath: expectedPath })
        if (!_ffCheckProc.running && !_ffGenProc.running) _processNextFF()
    }

    function _cacheFirstFrame(videoPath: string, imagePath: string) {
        const copy = Object.assign({}, root.videoFirstFrames)
        copy[videoPath] = imagePath
        root.videoFirstFrames = copy

        if (root._debugWallpaperUrls) {
            console.log("[Wallpapers] Cached first-frame:", videoPath, "->", imagePath)
        }
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
    property int _wallpaperCacheIndex: 0
    readonly property bool thumbnailGenerationRunning: thumbgenProc.running
    property real thumbnailGenerationProgress: 0

    signal changed()
    signal folderChanged()
    signal thumbnailGenerated(directory: string)
    signal thumbnailGeneratedFile(filePath: string)

    function load() {}
    function refresh() {} // Compatibility - FolderListModel auto-refreshes

    function rebuildWallpapersCache(): void {
        root.wallpapers = []
        root._wallpaperCacheIndex = 0
        wallpaperCacheTimer.restart()
    }

    function appendWallpapersCacheBatch(): void {
        const nextBatch = root.wallpapers.slice()
        const batchEnd = Math.min(folderModel.count, root._wallpaperCacheIndex + 64)
        for (let i = root._wallpaperCacheIndex; i < batchEnd; i++) {
            const path = folderModel.get(i, "filePath") || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL"))
            if (path && path.length)
                nextBatch.push(path)
        }
        root.wallpapers = nextBatch
        root._wallpaperCacheIndex = batchEnd
        if (root._wallpaperCacheIndex < folderModel.count)
            wallpaperCacheTimer.restart()
    }

    function currentMainWallpaperPath(monitorName = ""): string {
        const targetMonitor = monitorName || (WallpaperListener.multiMonitorEnabled ? WallpaperListener.getFocusedMonitor() : "")
        if (WallpaperListener.multiMonitorEnabled && targetMonitor) {
            const data = WallpaperListener.effectivePerMonitor[targetMonitor] ?? null
            if (data && data.path)
                return data.path
        }
        return Config.options?.background?.wallpaperPath ?? ""
    }

    function currentWallpaperPathForTarget(target = "main", monitorName = ""): string {
        const normalizedTarget = target && target.length > 0 ? target : "main"
        const mainPath = currentMainWallpaperPath(monitorName)

        switch (normalizedTarget) {
        case "backdrop": {
            const iiBackdrop = Config.options?.background?.backdrop ?? {}
            const useMainWallpaper = iiBackdrop.useMainWallpaper ?? true
            if (useMainWallpaper)
                return mainPath
            if (WallpaperListener.multiMonitorEnabled && monitorName) {
                const monitorData = WallpaperListener.effectivePerMonitor[monitorName] ?? null
                if (monitorData && monitorData.backdropPath)
                    return monitorData.backdropPath
            }
            return iiBackdrop.wallpaperPath || mainPath
        }
        case "waffle": {
            const waffleBackground = Config.options?.waffles?.background ?? {}
            return (waffleBackground.useMainWallpaper ?? true) ? mainPath : (waffleBackground.wallpaperPath || mainPath)
        }
        case "waffle-backdrop": {
            const waffleBackdrop = Config.options?.waffles?.background?.backdrop ?? {}
            const waffleBackground = Config.options?.waffles?.background ?? {}
            const waffleMain = (waffleBackground.useMainWallpaper ?? true) ? mainPath : (waffleBackground.wallpaperPath || mainPath)
            return (waffleBackdrop.useMainWallpaper ?? true) ? waffleMain : (waffleBackdrop.wallpaperPath || waffleMain)
        }
        default:
            return mainPath
        }
    }

    function isCurrentWallpaperPath(path: string, target = "main", monitorName = ""): bool {
        const currentPath = FileUtils.trimFileProtocol(String(currentWallpaperPathForTarget(target, monitorName) ?? ""))
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        return currentPath.length > 0 && currentPath === normalizedPath
    }

    function _applyRequestKey(path: string, darkMode: bool, noSwitch: bool): string {
        return [noSwitch ? "noswitch" : "switch", FileUtils.trimFileProtocol(String(path ?? "")), darkMode ? "dark" : "light"].join("|")
    }

    function _runWallpaperScript(path: string, darkMode: bool, noSwitch: bool): void {
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!normalizedPath || normalizedPath.length === 0)
            return

        root._applyInProgress = true
        _applySuppressTimer.restart()
        applyProc.activeRequestKey = root._applyRequestKey(normalizedPath, darkMode, noSwitch)
        const command = [
            Directories.wallpaperSwitchScriptPath,
            "--image", normalizedPath,
            "--mode", (darkMode ? "dark" : "light"),
            "--skip-config-write"
        ]
        if (noSwitch)
            command.splice(command.length - 1, 0, "--noswitch")
        applyProc.exec(command)
    }

    function _queueWallpaperScript(path: string, darkMode: bool, noSwitch: bool): void {
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!normalizedPath || normalizedPath.length === 0)
            return

        const requestKey = root._applyRequestKey(normalizedPath, darkMode, noSwitch)
        if (applyProc.running) {
            if (applyProc.activeRequestKey === requestKey || applyProc.pendingRequestKey === requestKey)
                return

            root._queuedApplyPath = normalizedPath
            root._queuedApplyDarkMode = darkMode
            root._queuedApplyNoSwitch = noSwitch
            applyProc.pendingRequestKey = requestKey
            root._applyInProgress = true
            _applySuppressTimer.restart()
            return
        }

        root._queuedApplyPath = ""
        applyProc.pendingRequestKey = ""
        root._runWallpaperScript(normalizedPath, darkMode, noSwitch)
    }

    Process {
        id: applyProc
        property string activeRequestKey: ""
        property string pendingRequestKey: ""

        onExited: {
            const nextKey = pendingRequestKey
            const nextPath = root._queuedApplyPath
            const nextDarkMode = root._queuedApplyDarkMode
            const nextNoSwitch = root._queuedApplyNoSwitch

            activeRequestKey = ""
            pendingRequestKey = ""
            root._queuedApplyPath = ""

            if (nextKey !== "" && nextPath !== "") {
                root._runWallpaperScript(nextPath, nextDarkMode, nextNoSwitch)
                return
            }

            root._applyInProgress = false
        }
    }

    // Clears _applyInProgress after switchwall.sh has had time to start.
    // 3 seconds is enough for the script to begin; ThemeService debounce is 260ms.
    Timer {
        id: _applySuppressTimer
        interval: 3000
        onTriggered: {
            if (!applyProc.running && applyProc.pendingRequestKey === "")
                root._applyInProgress = false
        }
    }

    function openFallbackPicker(darkMode = Appearance.m3colors.darkmode) {
        applyProc.exec([Directories.wallpaperSwitchScriptPath, "--mode", (darkMode ? "dark" : "light")])
    }

    function applySelectionTarget(path, target = "main", darkMode = Appearance.m3colors.darkmode, monitorName = "") {
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!normalizedPath || normalizedPath.length === 0) return

        const normalizedTarget = target && target.length > 0 ? target : "main"
        const lowerPath = normalizedPath.toLowerCase()
        const isVideo = lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv")
            || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov")
        const isGif = lowerPath.endsWith(".gif")
        const needsThumbnail = isVideo || isGif
        const thumbnailPath = needsThumbnail ? root.getExpectedThumbnailPath(normalizedPath, "large") : ""

        switch (normalizedTarget) {
        case "backdrop":
            Config.setNestedValue("background.backdrop.useMainWallpaper", false)
            Config.setNestedValue("background.backdrop.wallpaperPath", normalizedPath)
            Config.setNestedValue("background.backdrop.thumbnailPath", thumbnailPath)
            if (needsThumbnail)
                root.ensureThumbnailForPath(normalizedPath, "large")
            if (Config.options?.appearance?.wallpaperTheming?.useBackdropForColors)
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
            root.changed()
            return
        case "waffle":
            Config.setNestedValue("waffles.background.useMainWallpaper", false)
            Config.setNestedValue("waffles.background.wallpaperPath", normalizedPath)
            Config.setNestedValue("waffles.background.thumbnailPath", thumbnailPath)
            if (needsThumbnail)
                root.ensureThumbnailForPath(normalizedPath, "large")
            root.changed()
            return
        case "waffle-backdrop":
            Config.setNestedValue("waffles.background.backdrop.useMainWallpaper", false)
            Config.setNestedValue("waffles.background.backdrop.wallpaperPath", normalizedPath)
            Config.setNestedValue("waffles.background.backdrop.thumbnailPath", thumbnailPath)
            if (needsThumbnail)
                root.ensureThumbnailForPath(normalizedPath, "large")
            root.changed()
            return
        default:
            root.select(normalizedPath, darkMode, monitorName)
            return
        }
    }

    function apply(path, darkMode = Appearance.m3colors.darkmode, monitorName = "") {
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!normalizedPath || normalizedPath.length === 0) return

        if (monitorName !== "") {
            // Per-monitor: update config directly in QML to avoid race condition
            // (switchwall.sh and QML both write config.json — the 50ms write timer causes data loss)
            updatePerMonitorConfig(normalizedPath, monitorName)
            root.changed()
            return
        }

        // Suppress ThemeService duplicate regeneration while switchwall.sh runs
        root._applyInProgress = true
        _applySuppressTimer.restart()

        if (root.awwwBackendEnabled && AwwwBackend.supportsMainWallpaper(normalizedPath)) {
            Config.setNestedValue("background.wallpaperPath", normalizedPath)
            Config.setNestedValue("background.thumbnailPath", "")
            root._queueWallpaperScript(normalizedPath, darkMode, false)
            root.changed()
            return
        }

        // Always set wallpaper path from QML to avoid race condition with Config write timer
        Config.setNestedValue("background.wallpaperPath", normalizedPath)
        Config.setNestedValue("background.thumbnailPath", "")
        root._queueWallpaperScript(normalizedPath, darkMode, false)
        root.changed()
    }

    // Apply only the color scheme from an image without changing the active wallpaper
    function applyColorsOnly(imagePath, darkMode = Appearance.m3colors.darkmode) {
        const normalizedPath = FileUtils.trimFileProtocol(String(imagePath ?? ""))
        if (!normalizedPath || normalizedPath.length === 0) return

        Config.setNestedValue("appearance.wallpaperTheming.previewSourcePath", normalizedPath)

        root._applyInProgress = true
        _applySuppressTimer.restart()

        root._queueWallpaperScript(normalizedPath, darkMode, true)
    }

    function updatePerMonitorConfig(path: string, monitorName: string) {
        const currentArray = Config.options?.background?.wallpapersByMonitor ?? []
        const newArray = []
        let currentEntry = null
        for (const entry of currentArray) {
            if (entry && entry.monitor === monitorName) {
                currentEntry = entry
            } else if (entry) {
                newArray.push(entry)
            }
        }

        let wsFirst = 1, wsLast = 10
        if (CompositorService.isNiri) {
            const range = detectNiriWorkspaceRange(monitorName)
            if (range) { wsFirst = range.first; wsLast = range.last }
        }

        newArray.push(Object.assign({}, currentEntry ?? {}, {
            monitor: monitorName,
            path: path,
            workspaceFirst: wsFirst,
            workspaceLast: wsLast
        }))

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
        property string target: ""
        function select(filePath, darkMode = Appearance.m3colors.darkmode, monitorName = "", target = "") {
            selectProc.filePath = filePath
            selectProc.darkMode = darkMode
            selectProc.monitorName = monitorName
            selectProc.target = target
            selectProc.exec(["test", "-d", FileUtils.trimFileProtocol(filePath)])
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                setDirectory(selectProc.filePath)
                return
            }
            const target = root.resolveSelectionTarget(selectProc.target, selectProc.monitorName)
            if (target !== "main") {
                root.applySelectionTarget(selectProc.filePath, target, selectProc.darkMode, selectProc.monitorName)
                return
            }
            root.apply(selectProc.filePath, selectProc.darkMode, selectProc.monitorName)
        }
    }

    function resolveSelectionTarget(target = "", monitorName = ""): string {
        const normalizedTarget = String(target ?? "")
        if (normalizedTarget.length > 0)
            return normalizedTarget
        if (monitorName && monitorName.length > 0)
            return "main"
        return currentSelectionTarget()
    }

    function currentSelectionTarget(): string {
        const configTarget = Config.options?.wallpaperSelector?.selectionTarget ?? "main"
        if (configTarget && configTarget !== "main")
            return configTarget

        const globalTarget = GlobalStates.wallpaperSelectionTarget ?? "main"
        if (globalTarget && globalTarget !== "main")
            return globalTarget

        if ((Config.options?.panelFamily ?? "ii") === "waffle")
            return (Config.options?.waffles?.background?.useMainWallpaper ?? true) ? "main" : "waffle"

        return "main"
    }

    function select(filePath, darkMode = Appearance.m3colors.darkmode, monitorName = "", target = "") {
        selectProc.select(filePath, darkMode, monitorName, target)
    }

    function randomFromCurrentFolder(darkMode = Appearance.m3colors.darkmode, monitorName = "", target = "") {
        if (folderModel.count === 0) return
        const randomIndex = Math.floor(Math.random() * folderModel.count)
        const filePath = folderModel.get(randomIndex, "filePath")
        root.select(filePath, darkMode, monitorName, target)
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
        onCountChanged: root.rebuildWallpapersCache()
        onFolderChanged: root.folderChanged()
    }

    Timer {
        id: wallpaperCacheTimer
        interval: 0
        repeat: false
        onTriggered: root.appendWallpapersCacheBatch()
    }

    property string _pendingThumbnailSize: ""
    property string _pendingThumbnailDir: ""
    property var _singleThumbPending: ({})
    property var _singleThumbQueue: []
    
    function generateThumbnail(size: string) {
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) throw new Error("Invalid thumbnail size")
        root._pendingThumbnailSize = size
        root._pendingThumbnailDir = FileUtils.trimFileProtocol(root.directory)
        thumbgenDebounce.restart()
    }

    function ensureThumbnailForPath(filePath: string, size = "large") {
        const normalizedPath = FileUtils.trimFileProtocol(String(filePath ?? ""))
        if (!normalizedPath || normalizedPath.length === 0) return
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) return

        const outputPath = root.getExpectedThumbnailPath(normalizedPath, size)
        if (!outputPath || outputPath.length === 0) return

        const key = `${size}:${normalizedPath}`
        if (root._singleThumbPending[key]) return

        const pending = Object.assign({}, root._singleThumbPending)
        pending[key] = true
        root._singleThumbPending = pending
        root._singleThumbQueue.push({ key: key, filePath: normalizedPath, size: size, outputPath: outputPath })

        if (!_singleThumbProc.running)
            _processNextSingleThumb()
    }

    function _processNextSingleThumb() {
        if (root._singleThumbQueue.length === 0) return

        const item = root._singleThumbQueue.shift()
        const maxSize = Images.thumbnailSizes[item.size] ?? 256
        const outputDir = FileUtils.parentDirectory(item.outputPath)
        const commandBody = root.isVideoFile(item.filePath)
            ? "mkdir -p " + JSON.stringify(outputDir)
                + " && [ -f " + JSON.stringify(item.outputPath) + " ] && exit 0 || { ffmpeg -y -i " + JSON.stringify(item.filePath)
                + " -vframes 1 -vf " + JSON.stringify(`scale='min(${maxSize},iw)':'min(${maxSize},ih)':force_original_aspect_ratio=decrease`)
                + " " + JSON.stringify(item.outputPath) + " >/dev/null 2>&1 && exit 1; }"
            : "mkdir -p " + JSON.stringify(outputDir)
                + " && [ -f " + JSON.stringify(item.outputPath) + " ] && exit 0 || { magick " + JSON.stringify(item.filePath + "[0]")
                + " -resize " + `${maxSize}x${maxSize}` + " " + JSON.stringify(item.outputPath) + " >/dev/null 2>&1 && exit 1; }"

        _singleThumbProc._key = item.key
        _singleThumbProc._filePath = item.filePath
        _singleThumbProc.command = ["bash", "-c", commandBody]
        _singleThumbProc.running = true
    }

    function _finishSingleThumb(key: string) {
        const pending = Object.assign({}, root._singleThumbPending)
        delete pending[key]
        root._singleThumbPending = pending
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
            "INIR_VENV": Quickshell.env("INIR_VENV") || Quickshell.env("HOME") + "/.local/state/quickshell/.venv",
            "ILLOGICAL_IMPULSE_VIRTUAL_ENV": Quickshell.env("INIR_VENV") || Quickshell.env("HOME") + "/.local/state/quickshell/.venv"
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

    Process {
        id: _singleThumbProc
        property string _key: ""
        property string _filePath: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1)
                root.thumbnailGeneratedFile(_singleThumbProc._filePath)
            root._finishSingleThumb(_singleThumbProc._key)
            root._processNextSingleThumb()
        }
    }

    // ── Auto wallpaper cycling ──────────────────────────────────────────
    readonly property bool autoWallpaperEnabled: Config.options?.background?.autoWallpaper?.enable ?? false
    readonly property int autoWallpaperInterval: Config.options?.background?.autoWallpaper?.intervalMinutes ?? 30
    readonly property bool autoWallpaperGenerateColors: Config.options?.background?.autoWallpaper?.generateColors ?? true
    readonly property string autoWallpaperFolder: Config.options?.background?.autoWallpaper?.folder ?? ""

    Timer {
        id: autoWallpaperTimer
        interval: root.autoWallpaperInterval * 60 * 1000
        running: root.autoWallpaperEnabled && !GlobalStates.screenLocked
        repeat: true
        onTriggered: root._cycleAutoWallpaper()
    }

    function _cycleAutoWallpaper() {
        // Use custom folder or current folder
        const customFolder = root.autoWallpaperFolder
        if (customFolder && customFolder.length > 0) {
            // Switch to custom folder temporarily, pick random, then switch back
            const previousFolder = root.effectiveDirectory
            _autoPickProc._previousFolder = previousFolder
            _autoPickProc._targetFolder = customFolder
            _autoPickProc.command = ["test", "-d", customFolder]
            _autoPickProc.running = true
            return
        }
        // Use current folder
        if (folderModel.count === 0) return
        _pickRandomAndApply()
    }

    function _pickRandomAndApply() {
        if (folderModel.count === 0) return
        const currentPath = Config.options?.background?.wallpaperPath ?? ""
        let attempts = 0
        let randomIndex, filePath
        // Try to pick a different wallpaper than the current one
        do {
            randomIndex = Math.floor(Math.random() * folderModel.count)
            filePath = folderModel.get(randomIndex, "filePath")
            attempts++
        } while (filePath === currentPath && attempts < 5 && folderModel.count > 1)

        if (!filePath) return

        if (root.autoWallpaperGenerateColors) {
            root.apply(filePath, Appearance.m3colors.darkmode)
        } else {
            // Just change wallpaper path without running color generation
            Config.setNestedValue("background.wallpaperPath", filePath)
        }
    }

    Process {
        id: _autoPickProc
        property string _previousFolder: ""
        property string _targetFolder: ""
        onExited: (exitCode) => {
            if (exitCode === 0) {
                // Folder exists, temporarily set it and pick random
                root.directory = Qt.resolvedUrl(_autoPickProc._targetFolder)
                // Wait for folder model to update before picking
                _autoPickFolderDelay.restart()
            }
        }
    }

    Timer {
        id: _autoPickFolderDelay
        interval: 500
        onTriggered: root._pickRandomAndApply()
    }
    // ── End auto wallpaper cycling ──────────────────────────────────────
}
