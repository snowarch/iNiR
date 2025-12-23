pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * Provides a list of wallpapers and an "apply" action that calls the existing
 * switchwall.sh script. Pretty much a limited file browsing service.
 */
Singleton {
    id: root

    readonly property bool isWaffleFamily: (Config.options?.panelFamily ?? "ii") === "waffle"
    readonly property bool useBackdropWallpaper: isWaffleFamily
        ? (Config.options?.waffles?.background?.backdrop?.hideWallpaper ?? false)
        : (Config.options?.background?.backdrop?.hideWallpaper ?? false)

    readonly property string effectiveWallpaperPath: {
        function isVideoFile(path: string): bool {
            return path.endsWith(".mp4") || path.endsWith(".webm") || path.endsWith(".mkv") || path.endsWith(".avi") || path.endsWith(".mov")
        }

        if (useBackdropWallpaper) {
            if (isWaffleFamily) {
                const wBackdrop = Config.options?.waffles?.background?.backdrop ?? {}
                const useBackdropOwn = !(wBackdrop.useMainWallpaper ?? true)
                if (useBackdropOwn && wBackdrop.wallpaperPath)
                    return wBackdrop.wallpaperPath

                const wBg = Config.options?.waffles?.background ?? {}
                const useMainForWaffle = wBg.useMainWallpaper ?? true
                const base = useMainForWaffle ? (Config.options?.background?.wallpaperPath ?? "") : (wBg.wallpaperPath || (Config.options?.background?.wallpaperPath ?? ""))
                return base
            }

            const iiBackdrop = Config.options?.background?.backdrop ?? {}
            const useMain = iiBackdrop.useMainWallpaper ?? true
            const mainPath = Config.options?.background?.wallpaperPath ?? ""
            const backdropPath = iiBackdrop.wallpaperPath || ""
            return useMain ? mainPath : (backdropPath || mainPath)
        }

        if (isWaffleFamily) {
            const wBg = Config.options?.waffles?.background ?? {}
            const useMain = wBg.useMainWallpaper ?? true
            if (useMain) {
                const mainWp = Config.options?.background?.wallpaperPath ?? ""
                return isVideoFile(mainWp) ? (Config.options?.background?.thumbnailPath ?? mainWp) : mainWp
            }
            return wBg.wallpaperPath || (Config.options?.background?.wallpaperPath ?? "")
        }

        const mainWp = Config.options?.background?.wallpaperPath ?? ""
        return isVideoFile(mainWp) ? (Config.options?.background?.thumbnailPath ?? mainWp) : mainWp
    }

    readonly property string effectiveWallpaperUrl: {
        const path = root.effectiveWallpaperPath
        if (!path || path.length === 0) return ""
        return path.startsWith("file://") ? path : ("file://" + path)
    }

    property string thumbgenScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/thumbgen-venv.sh`
    property string generateThumbnailsMagickScriptPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/thumbnails/generate-thumbnails-magick.sh`
    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: Qt.resolvedUrl(`${Directories.pictures}/Wallpapers`)
    property alias folderModel: folderModel // Expose for direct binding when needed
    property string searchQuery: ""
    readonly property list<string> extensions: [ // TODO: add videos
        "jpg", "jpeg", "png", "webp", "avif", "bmp", "svg"
    ]
    property list<string> wallpapers: [] // List of absolute file paths (without file://)
    readonly property bool thumbnailGenerationRunning: thumbgenProc.running
    property real thumbnailGenerationProgress: 0
    property string _thumbgenPendingSize: ""
    property url _thumbgenPendingDirectory: ""
    property string _thumbgenLastRequestedKey: ""

    signal changed()
    signal thumbnailGenerated(directory: string)
    signal thumbnailGeneratedFile(filePath: string)

    function load () {} // For forcing initialization

    // Executions
    Process {
        id: applyProc
    }
    
    function openFallbackPicker(darkMode = Appearance.m3colors.darkmode) {
        applyProc.exec([
            Directories.wallpaperSwitchScriptPath,
            "--mode", (darkMode ? "dark" : "light")
        ])
    }

    function apply(path, darkMode = Appearance.m3colors.darkmode) {
        const normalizedPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!normalizedPath || normalizedPath.length === 0) return
        applyProc.exec([
            Directories.wallpaperSwitchScriptPath,
            "--image", normalizedPath,
            "--mode", (darkMode ? "dark" : "light")
        ])
        root.changed()
    }

    Process {
        id: selectProc
        property string filePath: ""
        property bool darkMode: Appearance.m3colors.darkmode
        function select(filePath, darkMode = Appearance.m3colors.darkmode) {
            selectProc.filePath = FileUtils.trimFileProtocol(String(filePath ?? ""))
            selectProc.darkMode = darkMode
            selectProc.exec(["/usr/bin/test", "-d", FileUtils.trimFileProtocol(selectProc.filePath)])
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                setDirectory(selectProc.filePath);
                return;
            }
            root.apply(selectProc.filePath, selectProc.darkMode);
        }
    }

    function select(filePath, darkMode = Appearance.m3colors.darkmode) {
        selectProc.select(filePath, darkMode);
    }

    function randomFromCurrentFolder(darkMode = Appearance.m3colors.darkmode) {
        if (folderModel.count === 0) return;
        const randomIndex = Math.floor(Math.random() * folderModel.count);
        const filePath = folderModel.get(randomIndex, "filePath");
        print("Randomly selected wallpaper:", filePath);
        root.select(filePath, darkMode);
    }

    Process {
        id: validateDirProc
        property string nicePath: ""
        property bool _pendingFileCheck: false
        function setDirectoryIfValid(path) {
            validateDirProc.nicePath = FileUtils.trimFileProtocol(path).replace(/\/+$/, "")
            if (/^\/*$/.test(validateDirProc.nicePath)) validateDirProc.nicePath = "/";
            validateDirProc._pendingFileCheck = false
            validateDirProc.exec(["/usr/bin/test", "-d", validateDirProc.nicePath])
        }
        onExited: (exitCode, exitStatus) => {
            if (!validateDirProc._pendingFileCheck) {
                if (exitCode === 0) {
                    root.directory = Qt.resolvedUrl(validateDirProc.nicePath)
                    return
                }
                validateDirProc._pendingFileCheck = true
                validateDirProc.exec(["/usr/bin/test", "-f", validateDirProc.nicePath])
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

    // Folder model
    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(root.defaultFolder)
        caseSensitive: false
        nameFilters: {
            const q = (root.searchQuery ?? "").trim();
            if (q.length === 0) return [];
            const parts = q.split(/\s+/).filter(s => s.length > 0).map(s => `*${s}*`).join("");
            return root.extensions.map(ext => `*${parts}*.${ext}`);
        }
        // FolderListModel applies nameFilters to dirs too; when searching, hide dirs to avoid "everything disappeared".
        showDirs: (root.searchQuery ?? "").trim().length === 0
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
    }

    // Thumbnail generation
    function generateThumbnail(size: string) {
        // console.log("[Wallpapers] Updating thumbnails")
        if (!["normal", "large", "x-large", "xx-large"].includes(size)) throw new Error("Invalid thumbnail size");
        root._thumbgenPendingSize = size
        root._thumbgenPendingDirectory = root.directory
        thumbgenDebounce.restart()
    }

    Timer {
        id: thumbgenDebounce
        interval: 250
        repeat: false
        onTriggered: {
            const dir = root._thumbgenPendingDirectory
            const size = root._thumbgenPendingSize
            const key = `${FileUtils.trimFileProtocol(dir)}|${size}`
            if (key === root._thumbgenLastRequestedKey && root.thumbnailGenerationRunning) return
            root._thumbgenLastRequestedKey = key

            thumbgenProc.directory = dir
            thumbgenProc._size = size
            thumbgenProc.running = false
            thumbgenFallbackProc.running = false
            thumbgenProc.command = [
                "/usr/bin/bash",
                thumbgenScriptPath,
                "--size", size,
                "--machine_progress",
                "--only_images",
                "-d", FileUtils.trimFileProtocol(dir)
            ]
            root.thumbnailGenerationProgress = 0
            thumbgenProc.running = true
        }
    }
    Process {
        id: thumbgenProc
        property string directory
        property string _size: ""
        stdout: SplitParser {
            onRead: data => {
                // print("thumb gen proc:", data)
                let match = data.match(/PROGRESS (\d+)\/(\d+)/)
                if (match) {
                    const completed = parseInt(match[1])
                    const total = parseInt(match[2])
                    root.thumbnailGenerationProgress = completed / total
                }
                match = data.match(/FILE (.+)/)
                if (match) {
                    const filePath = match[1]
                    root.thumbnailGeneratedFile(filePath)
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                thumbgenFallbackProc.command = [
                    "/usr/bin/bash",
                    generateThumbnailsMagickScriptPath,
                    "--size", thumbgenProc._size,
                    "-d", FileUtils.trimFileProtocol(thumbgenProc.directory)
                ]
                thumbgenFallbackProc.running = true
                return
            }
            root.thumbnailGenerated(thumbgenProc.directory)
        }
    }

    Process {
        id: thumbgenFallbackProc
        onExited: (exitCode, exitStatus) => {
            root.thumbnailGenerated(thumbgenProc.directory)
        }
    }
}
