pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import Quickshell.Io

// Skew wallpaper selector — parallelogram slice layout ported from skwd.
// Key design: expanded center card + narrow skewed slices, clean masking,
// no ambient backdrop bleed-through, no dominant color probing bloat.
Item {
    id: root

    required property var folderModel
    required property string currentWallpaperPath
    property bool useDarkMode: Appearance.m3colors.darkmode

    signal wallpaperSelected(string filePath)
    signal directorySelected(string dirPath)
    signal closeRequested()
    signal switchToGridRequested()
    signal switchToGalleryRequested()

    // ═══════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property bool hasItems: totalCount > 0
    readonly property string currentFolderPath: String(folderModel?.folder ?? "")
    readonly property string currentFolderName: FileUtils.folderNameForPath(currentFolderPath)
    readonly property bool canGoBack: (folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (folderModel?.currentFolderHistoryIndex ?? 0) < ((folderModel?.folderHistory?.length ?? 0) - 1)
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1

    // ─── Filtered index maps ───
    property var _imageIndexMap: []
    property var _folderItems: []

    // 0=all, 1=image, 2=video, 3=gif
    property int typeFilter: 0

    // ─── Color hue filter (skwd: 12 hue buckets + achromatic) ───
    // -1=no filter, 0-11=hue bucket, 99=achromatic
    property int colorFilter: -1
    property var _colorsDb: ({})
    property bool _colorsLoaded: false
    readonly property string _colorsCachePath: `${FileUtils.trimFileProtocol(Directories.stateUserPath)}/wallpaper-selector/colors.json`

    // ─── Favourites ───
    property var _favouritesDb: ({})
    property bool _favouritesLoaded: false
    property bool favouriteFilterActive: false
    readonly property string _favouritesCachePath: `${FileUtils.trimFileProtocol(Directories.stateUserPath)}/wallpaper-selector/favourites.json`

    // ─── Sort mode ───
    // "date" = by mtime descending, "color" = by hue bucket then saturation
    property string sortMode: "date"

    // ─── Flip card (skwd: right-click flips current card) ───
    property int _flippedImageIndex: -1

    function _isFavourite(fileName: string): bool {
        return !!_favouritesDb[fileName]
    }

    function _toggleFavourite(fileName: string): void {
        let db = _favouritesDb
        if (db[fileName])
            delete db[fileName]
        else
            db[fileName] = true
        _favouritesDb = undefined  // force change signal
        _favouritesDb = db
        _saveFavouritesDebounce.restart()
        if (favouriteFilterActive)
            _rebuildIndexMaps()
    }

    function _getHueBucket(fileName: string): int {
        const entry = _colorsDb[fileName]
        return entry ? (entry.hue ?? -1) : -1
    }

    function _getSaturation(fileName: string): real {
        const entry = _colorsDb[fileName]
        return entry ? (entry.sat ?? 0) : 0
    }

    // (mtime sort uses model-index reversal, not per-file mtime lookup)

    onColorFilterChanged: {
        _flippedImageIndex = -1
        _rebuildAndSync()
    }
    onFavouriteFilterActiveChanged: {
        _flippedImageIndex = -1
        _rebuildAndSync()
    }
    onSortModeChanged: {
        _flippedImageIndex = -1
        _rebuildAndSync()
    }
    onCurrentWallpaperPathChanged: {
        _initialized = false
        _syncToCurrentWallpaper(true)
    }

    function _mediaKind(name: string): string {
        const l = name.toLowerCase()
        if (l.endsWith(".mp4") || l.endsWith(".webm") || l.endsWith(".mkv") || l.endsWith(".avi") || l.endsWith(".mov")) return "video"
        if (l.endsWith(".gif")) return "gif"
        return "image"
    }

    function _normalizedFilePath(path: string): string {
        return FileUtils.trimFileProtocol(String(path ?? ""))
    }

    function _rebuildIndexMaps(): void {
        const imgMap = []
        const folders = []
        for (let i = 0; i < totalCount; i++) {
            const isDir = folderModel.get(i, "fileIsDir") ?? false
            if (isDir) {
                folders.push({
                    name: folderModel.get(i, "fileName") ?? "",
                    path: folderModel.get(i, "filePath") ?? ""
                })
            } else {
                const fname = folderModel.get(i, "fileName") ?? ""
                const kind = _mediaKind(fname)
                // Type filter
                if (typeFilter !== 0
                    && !(typeFilter === 1 && kind === "image")
                    && !(typeFilter === 2 && kind === "video")
                    && !(typeFilter === 3 && kind === "gif"))
                    continue
                // Color filter
                if (colorFilter !== -1) {
                    const hue = _getHueBucket(fname)
                    if (hue !== colorFilter) continue
                }
                // Favourites filter
                if (favouriteFilterActive && !_isFavourite(fname))
                    continue
                imgMap.push(i)
            }
        }

        // Sort
        if (sortMode === "color" && _colorsLoaded) {
            imgMap.sort((a, b) => {
                const fnA = folderModel.get(a, "fileName") ?? ""
                const fnB = folderModel.get(b, "fileName") ?? ""
                const hueA = _getHueBucket(fnA)
                const hueB = _getHueBucket(fnB)
                // Achromatic (99) sorts last
                const sortA = hueA === 99 ? 100 : (hueA < 0 ? 101 : hueA)
                const sortB = hueB === 99 ? 100 : (hueB < 0 ? 101 : hueB)
                if (sortA !== sortB) return sortA - sortB
                return _getSaturation(fnB) - _getSaturation(fnA)
            })
        } else {
            // Date sort: FolderListModel.Time with sortReversed=false yields oldest-first.
            // Reverse so newest wallpapers appear first (leftmost in the skew view).
            imgMap.reverse()
        }

        _imageIndexMap = imgMap
        _folderItems = folders
    }

    onTypeFilterChanged: {
        _rebuildAndSync()
    }

    // ─── Image-only derived counts ───
    readonly property int imageCount: _imageIndexMap.length
    readonly property bool hasImages: imageCount > 0
    readonly property int folderCount: _folderItems.length
    readonly property bool hasFolders: folderCount > 0

    // ─── Active item (image-only index space) ───
    property int currentImageIndex: 0

    function _imgModelIndex(imgIdx: int): int {
        if (imgIdx < 0 || imgIdx >= _imageIndexMap.length) return -1
        return _imageIndexMap[imgIdx]
    }

    function _imgFilePath(imgIdx: int): string {
        const mi = _imgModelIndex(imgIdx)
        return mi >= 0 ? (folderModel.get(mi, "filePath") ?? "") : ""
    }
    function _imgFileName(imgIdx: int): string {
        const mi = _imgModelIndex(imgIdx)
        return mi >= 0 ? (folderModel.get(mi, "fileName") ?? "") : ""
    }

    readonly property string activePath: hasImages ? _imgFilePath(currentImageIndex) : ""
    readonly property string activeName: hasImages ? _imgFileName(currentImageIndex) : ""

    property bool showKeyboardGuide: false
    property bool animatePreview: Config.options?.wallpaperSelector?.animatePreview ?? false
    property bool _initialized: false
    // When true, suppress highlight move animation (snap position instantly)
    property bool _suppressHighlightAnim: true
    property int _wheelAccum: 0
    property bool _contentVisible: false
    // Bound by parent (WallpaperCoverflow) to its _contentReady — drives close animation.
    property bool contentReady: false
    readonly property string activeDisplayName: activePath.length > 0 ? FileUtils.fileNameForPath(activePath) : ""
    readonly property string activeStatusText: {
        if (!hasImages)
            return Translation.tr("No wallpapers in this folder")
        if (FileUtils.trimFileProtocol(String(currentWallpaperPath ?? "")) === FileUtils.trimFileProtocol(activePath))
            return Translation.tr("Current wallpaper")
        if (activeName.toLowerCase().endsWith(".gif"))
            return Translation.tr("Animated image")
        if (_mediaKind(activeName) === "video")
            return Translation.tr("Video wallpaper")
        return Translation.tr("Ready to apply")
    }

    // ─── Rapid-navigation velocity tracking ───
    property bool _rapidNavigation: false
    property int _rapidNavSteps: 0

    Timer {
        id: rapidNavCooldown
        interval: 350
        onTriggered: {
            root._rapidNavigation = false
            root._rapidNavSteps = 0
        }
    }

    function _trackNavStep(): void {
        _rapidNavSteps++
        if (_rapidNavSteps >= 3)
            _rapidNavigation = true
        rapidNavCooldown.restart()
    }

    // ─── Content visibility (drives staggered enter + exit) ───
    // Enter: contentShowTimer fires 50ms after onCompleted → _contentVisible = true
    // Exit:  parent sets contentReady = false → _contentVisible = false (reverse animation)
    Timer {
        id: contentShowTimer
        interval: 50
        onTriggered: root._contentVisible = true
    }

    onContentReadyChanged: {
        if (!contentReady)
            root._contentVisible = false
    }

    on_ContentVisibleChanged: {
        // Defensive re-position: when content becomes visible the ListView layout
        // is guaranteed to be complete, so re-enforce the target position.
        if (_contentVisible && _initialized && hasImages && skewView && skewView.width > 0)
            skewView.positionViewAtIndex(currentImageIndex, ListView.Center)
    }

    // ─── Skew / layout parameters (matching skwd geometry) ───
    readonly property real thumbnailDecodeScale: 1.2
    readonly property int baseSliceWidth: 135
    readonly property int baseExpandedCardWidth: 924
    readonly property int baseCardHeight: 520
    readonly property int baseSkewExtent: 35
    readonly property int baseSliceSpacing: -22
    readonly property int visibleSliceCount: 12
    readonly property real topChromeLead: isTopBar ? 10 : isVerticalBar ? 12 : 14
    // Filter bar overlays the slices (skwd style) — no top inset needed for the ListView.
    // Only the bottom chrome (toolbar) eats vertical space.
    readonly property real bottomChromeInset: toolbarArea.height + 28 + 20
    readonly property real availableStageHeight: Math.max(220, root.height - topChromeLead - bottomChromeInset)
    readonly property real skewScale: Math.max(
        0.58,
        Math.min(
            1.0,
            availableStageHeight / baseCardHeight,
            (root.width - 96) / baseExpandedCardWidth
        )
    )
    readonly property int sliceWidth: Math.round(baseSliceWidth * skewScale)
    readonly property int expandedCardWidth: Math.round(baseExpandedCardWidth * skewScale)
    readonly property int cardHeight: Math.round(baseCardHeight * skewScale)
    readonly property int skewExtent: Math.round(baseSkewExtent * skewScale)
    readonly property int sliceSpacing: Math.round(baseSliceSpacing * skewScale)
    readonly property int deckWidth: Math.round(expandedCardWidth + (visibleSliceCount - 1) * (sliceWidth + sliceSpacing))
    readonly property int skewFrameWidth: expandedCardWidth + skewExtent

    readonly property string _thumbSizeName: {
        const w = Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
        const h = Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
        let s = Images.thumbnailSizeNameForDimensions(w, h)
        if (s === "normal" || s === "large") s = "x-large"
        return s
    }
    // ═══════════════════════════════════════════════════
    // STYLE TOKENS
    // ═══════════════════════════════════════════════════
    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color baseColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer0
    readonly property color textColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.45)
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.small
    readonly property bool isVerticalBar: Config.options?.bar?.vertical ?? false
    readonly property bool isTopBar: !isVerticalBar && !(Config.options?.bar?.bottom ?? false)
    readonly property color badgeSurfaceColor: ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.90)
    readonly property color badgeTextColor: Appearance.colors.colOnLayer2

    // Accent: simple primary color, no quantizer bloat
    readonly property color accentColor: Appearance.colors.colPrimary

    // ═══════════════════════════════════════════════════
    // NAVIGATION
    // ═══════════════════════════════════════════════════
    function _goToImageIndex(index: int): void {
        if (!hasImages) return
        const next = Math.max(0, Math.min(imageCount - 1, index))
        if (next === currentImageIndex) return
        _trackNavStep()
        _suppressHighlightAnim = false
        currentImageIndex = next
        showKeyboardGuide = false
    }

    function moveSelection(delta: int): void {
        _goToImageIndex(currentImageIndex + delta)
    }

    function toggleAnimatedPreview(): void {
        if (!hasImages) return
        showKeyboardGuide = false
        animatePreview = !animatePreview
        Config.setNestedValue("wallpaperSelector.animatePreview", animatePreview)
    }

    function activateCurrent(): void {
        if (!hasImages) return
        const path = _imgFilePath(currentImageIndex)
        if (!path || path.length === 0) return
        showKeyboardGuide = false
        wallpaperSelected(path)
    }

    function navigateUpDirectory(): void {
        showKeyboardGuide = false
        Wallpapers.navigateUp()
    }

    function navigateIntoFolder(path: string): void {
        if (!path || path.length === 0) return
        showKeyboardGuide = false
        directorySelected(path)
    }

    function _findCurrentWallpaperImageIndex(): int {
        const raw = String(currentWallpaperPath ?? "")
        const target = FileUtils.trimFileProtocol(raw)
        if (target.length === 0 || imageCount === 0) return -1
        const targetName = FileUtils.fileNameForPath(target)
        let nameMatchIdx = -1
        for (let i = 0; i < imageCount; i++) {
            const fp = FileUtils.trimFileProtocol(_imgFilePath(i))
            if (fp === target) return i
            if (nameMatchIdx < 0 && targetName.length > 0 && FileUtils.fileNameForPath(fp) === targetName)
                nameMatchIdx = i
        }
        return nameMatchIdx
    }

    // Rebuild index map + sync to current wallpaper in one shot.
    // Used by filter/sort changes that invalidate the map.
    function _rebuildAndSync(): void {
        _rebuildIndexMaps()
        _initialized = false
        _syncToCurrentWallpaper(true)
    }

    function _syncToCurrentWallpaper(forceReset = false): void {
        if (!hasImages) {
            currentImageIndex = 0
            _initialized = true
            return
        }
        if (_initialized && !forceReset)
            return

        const idx = _findCurrentWallpaperImageIndex()
        const target = idx >= 0 ? idx : Math.max(0, Math.min(currentImageIndex, imageCount - 1))

        // Suppress highlight animation for programmatic positioning
        _suppressHighlightAnim = true
        currentImageIndex = target

        // Position immediately if layout is ready
        if (skewView && skewView.width > 0) {
            skewView.positionViewAtIndex(target, ListView.Center)
            // Deferred re-position: one extra frame so delegates are created
            Qt.callLater(() => {
                if (skewView && skewView.width > 0)
                    skewView.positionViewAtIndex(target, ListView.Center)
            })
        } else {
            // Layout not ready — retry once after a short delay
            _syncRetryTimer.restart()
        }
        _initialized = true
    }

    Timer {
        id: _syncRetryTimer
        interval: 60
        property int _retries: 0
        onTriggered: {
            if (skewView && skewView.width > 0) {
                skewView.positionViewAtIndex(root.currentImageIndex, ListView.Center)
                Qt.callLater(() => {
                    if (skewView && skewView.width > 0)
                        skewView.positionViewAtIndex(root.currentImageIndex, ListView.Center)
                })
                _retries = 0
            } else if (_retries < 10) {
                _retries++
                _syncRetryTimer.restart()
            } else {
                _retries = 0
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // PERSISTENCE — color cache + favourites
    // ═══════════════════════════════════════════════════

    // ─── Favourites persistence ───
    FileView {
        id: favouritesFileView
        path: Qt.resolvedUrl("file://" + root._favouritesCachePath)
        watchChanges: false
        onLoaded: {
            try {
                const text = favouritesFileView.text()
                if (text && text.trim().length > 0) {
                    root._favouritesDb = JSON.parse(text)
                }
            } catch (e) {
                console.warn("[SkewView] Failed to parse favourites:", e)
            }
            root._favouritesLoaded = true
        }
        onLoadFailed: {
            root._favouritesLoaded = true
        }
    }

    Timer {
        id: _saveFavouritesDebounce
        interval: 300
        onTriggered: _saveFavouritesProc.running = true
    }

    Process {
        id: _saveFavouritesProc
        command: ["bash", "-c",
            "printf '%s' " + JSON.stringify(JSON.stringify(root._favouritesDb)) +
            " > " + JSON.stringify(root._favouritesCachePath)]
    }

    // ─── Color cache persistence ───
    FileView {
        id: colorsFileView
        path: Qt.resolvedUrl("file://" + root._colorsCachePath)
        watchChanges: false
        onLoaded: {
            try {
                const text = colorsFileView.text()
                if (text && text.trim().length > 0) {
                    root._colorsDb = JSON.parse(text)
                }
            } catch (e) {
                console.warn("[SkewView] Failed to parse colors cache:", e)
            }
            root._colorsLoaded = true
            root._analyzeUncachedColors()
        }
        onLoadFailed: {
            root._colorsLoaded = true
            root._analyzeUncachedColors()
        }
    }

    Timer {
        id: _saveColorsDebounce
        interval: 500
        onTriggered: _saveColorsProc.running = true
    }

    Process {
        id: _saveColorsProc
        command: ["bash", "-c",
            "printf '%s' " + JSON.stringify(JSON.stringify(root._colorsDb)) +
            " > " + JSON.stringify(root._colorsCachePath)]
    }

    // ─── File deletion ───
    Process {
        id: _deleteFileProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Trigger folder refresh by re-navigating to the same folder
                root.folderModel.folder = root.folderModel.folder
            }
        }
    }

    // ─── Color analysis via ImageMagick (batched) ───
    property var _colorAnalysisQueue: []
    property bool _colorAnalysisRunning: false
    readonly property int _colorBatchSize: 20

    function _analyzeUncachedColors(): void {
        if (!_colorsLoaded || totalCount === 0) return
        const queue = []
        for (let i = 0; i < totalCount; i++) {
            const isDir = folderModel.get(i, "fileIsDir") ?? false
            if (isDir) continue
            const fname = folderModel.get(i, "fileName") ?? ""
            if (_mediaKind(fname) === "video") continue // Skip videos for color analysis
            if (_colorsDb[fname]) continue // Already cached
            const fpath = FileUtils.trimFileProtocol(folderModel.get(i, "filePath") ?? "")
            if (fpath.length > 0) queue.push({ name: fname, path: fpath })
        }
        if (queue.length === 0) return
        _colorAnalysisQueue = queue
        _runNextColorBatch()
    }

    function _runNextColorBatch(): void {
        if (_colorAnalysisQueue.length === 0) {
            _colorAnalysisRunning = false
            _saveColorsDebounce.restart()
            _rebuildIndexMaps()
            return
        }
        _colorAnalysisRunning = true
        const batch = _colorAnalysisQueue.splice(0, _colorBatchSize)
        _colorAnalysisProc._batchNames = batch.map(b => b.name)
        _colorAnalysisProc._resultLines = []
        // Single bash process for the whole batch
        let script = ""
        for (const item of batch) {
            // Output: name<TAB>hue sat lightness (or name<TAB>ERR)
            script += "printf '%s\\t' " + JSON.stringify(item.name) + "; "
            script += "convert " + JSON.stringify(item.path) +
                " -resize 1x1\\! -colorspace HSL -format '%[fx:hue*360] %[fx:saturation] %[fx:lightness]' info: 2>/dev/null || printf 'ERR'; "
            script += "printf '\\n'; "
        }
        _colorAnalysisProc.command = ["bash", "-c", script]
        _colorAnalysisProc.running = true
    }

    Process {
        id: _colorAnalysisProc
        property var _batchNames: []
        property var _resultLines: []
        stdout: SplitParser {
            onRead: line => { _colorAnalysisProc._resultLines.push(line.trim()) }
        }
        onExited: (exitCode, exitStatus) => {
            const db = JSON.parse(JSON.stringify(root._colorsDb))
            let changed = false
            for (const line of _resultLines) {
                const tabIdx = line.indexOf('\t')
                if (tabIdx < 0) continue
                const name = line.substring(0, tabIdx)
                const data = line.substring(tabIdx + 1).trim()
                if (data === "ERR" || data.length === 0) continue
                const parts = data.split(" ")
                if (parts.length < 3) continue
                const hDeg = parseFloat(parts[0])
                const sat = parseFloat(parts[1])
                const lit = parseFloat(parts[2])
                let bucket = 99
                if (sat > 0.12 && lit > 0.08 && lit < 0.92) {
                    bucket = Math.floor(hDeg / 30) % 12
                }
                db[name] = { hue: bucket, sat: Math.round(sat * 100) / 100 }
                changed = true
            }
            if (changed) root._colorsDb = db
            root._runNextColorBatch()
        }
    }

    // ═══════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════
    function updateThumbnails(): void {
        for (let i = 0; i < Math.min(imageCount, 30); i++) {
            const fp = _imgFilePath(i)
            const fn = _imgFileName(i)
            if (fp && fp.length > 0) {
                Wallpapers.ensureThumbnailForPath(fp, root._thumbSizeName)
                if (_mediaKind(fn) === "video")
                    Wallpapers.ensureVideoFirstFrame(fp)
            }
        }
    }

    onTotalCountChanged: {
        _rebuildIndexMaps()
        if (totalCount > 0) {
            _initialized = false
            _syncToCurrentWallpaper(true)
        } else {
            _initialized = false
            currentImageIndex = 0
        }
        if (totalCount > 0 && _colorsLoaded)
            Qt.callLater(_analyzeUncachedColors)
    }

    Component.onCompleted: {
        // Ensure persistence directory exists
        Quickshell.execDetached(["/usr/bin/mkdir", "-p",
            FileUtils.trimFileProtocol(Directories.stateUserPath) + "/wallpaper-selector"])
        _rebuildIndexMaps()
        _syncToCurrentWallpaper(true)
        updateThumbnails()
        contentShowTimer.restart()
        forceActiveFocus()
        Qt.callLater(_analyzeUncachedColors)
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._flippedImageIndex = -1
            root._rebuildIndexMaps()
            root._initialized = false
            root._syncToCurrentWallpaper(true)
            Qt.callLater(root._analyzeUncachedColors)
        }
    }

    // ═══════════════════════════════════════════════════
    // INPUT
    // ═══════════════════════════════════════════════════
    Keys.onPressed: event => {
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        if (!searchField.activeFocus && (ctrl && event.key === Qt.Key_F || event.key === Qt.Key_Slash)) {
            root.showKeyboardGuide = false
            searchField.forceActiveFocus(); event.accepted = true; return
        }

        if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
                if (searchField.text.length > 0) { Wallpapers.searchQuery = ""; searchField.text = "" }
                else { searchField.focus = false; root.forceActiveFocus() }
                event.accepted = true
            }
            return
        }

        switch (event.key) {
        case Qt.Key_Escape:
            if ((Wallpapers.searchQuery ?? "").length > 0) {
                Wallpapers.searchQuery = ""
                searchField.text = ""
            } else if (root.animatePreview) {
                root.animatePreview = false
            } else if (folderDropdown.visible) {
                folderDropdown.close()
            } else {
                root.closeRequested()
            }
            break
        case Qt.Key_Space:
            root.toggleAnimatedPreview(); break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 3 : 1))
            break
        case Qt.Key_H:
            if (!alt && !ctrl) {
                root.moveSelection(-(shift ? 3 : 1))
                break
            }
            event.accepted = false; return
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 3 : 1)
            break
        case Qt.Key_L:
            if (!alt && !ctrl) {
                root.moveSelection(shift ? 3 : 1)
                break
            }
            event.accepted = false; return
        case Qt.Key_Up:
            if (alt || ctrl) root.navigateUpDirectory()
            else root.moveSelection(-(shift ? 8 : 4))
            break
        case Qt.Key_K:
            root.moveSelection(-(shift ? 8 : 4)); break
        case Qt.Key_Down:
            if (alt || ctrl) {
                if (root.folderCount === 1)
                    root.navigateIntoFolder(root._folderItems[0].path)
                else if (root.folderCount > 1)
                    folderDropdown.visible = !folderDropdown.visible
            } else {
                root.moveSelection(shift ? 8 : 4)
            }
            break
        case Qt.Key_J:
            root.moveSelection(shift ? 8 : 4); break
        case Qt.Key_PageUp:
            root.moveSelection(-6); break
        case Qt.Key_PageDown:
            root.moveSelection(6); break
        case Qt.Key_Home:
            root._goToImageIndex(0); break
        case Qt.Key_End:
            root._goToImageIndex(root.imageCount - 1); break
        case Qt.Key_Return: case Qt.Key_Enter:
            root.activateCurrent(); break
        case Qt.Key_F:
            if (!alt && !ctrl) {
                // Toggle flip on current card
                root._flippedImageIndex = root._flippedImageIndex === root.currentImageIndex
                    ? -1 : root.currentImageIndex
                break
            }
            event.accepted = false; return
        case Qt.Key_S:
            if (!alt && !ctrl && root.hasImages) {
                root._toggleFavourite(root.activeName)
                break
            }
            event.accepted = false; return
        case Qt.Key_Backspace:
            if (alt || ctrl) root.navigateUpDirectory()
            break
        default:
            event.accepted = false; return
        }
        event.accepted = true
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.showKeyboardGuide = false
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            root._wheelAccum += d
            const threshold = Math.abs(d) < 60 ? 40 : 120
            const steps = root._wheelAccum >= 0
                ? Math.floor(root._wheelAccum / threshold)
                : Math.ceil(root._wheelAccum / threshold)
            if (steps !== 0) {
                root._wheelAccum -= steps * threshold
                root.moveSelection(-steps)
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // BACKGROUND — simple scrim, no ambient backdrop bleed
    // ═══════════════════════════════════════════════════
    Rectangle {
        anchors.fill: parent
        visible: root.hasImages
        z: -1
        color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.25)
        opacity: root._contentVisible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // MAIN SKEW LISTVIEW — skwd-style parallelogram slices
    // ═══════════════════════════════════════════════════
    ListView {
        id: skewView
        anchors {
            top: parent.top
            topMargin: root.topChromeLead
            bottom: parent.bottom
            bottomMargin: root.bottomChromeInset
            horizontalCenter: parent.horizontalCenter
        }

        width: root.deckWidth
        orientation: ListView.Horizontal
        spacing: root.sliceSpacing
        clip: false
        cacheBuffer: root.expandedCardWidth * 4
        focus: false

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.expandedCardWidth) / 2
        preferredHighlightEnd: (width + root.expandedCardWidth) / 2
        highlightMoveDuration: root._suppressHighlightAnim ? 0
            : (root._rapidNavigation ? Appearance.animation.elementMoveFast.duration
                                     : Appearance.animation.elementResize.duration)
        highlightFollowsCurrentItem: true
        header: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }
        footer: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }

        boundsBehavior: Flickable.StopAtBounds
        model: root.imageCount
        currentIndex: root.currentImageIndex

        // Fade-in + scale entrance (skwd: 400ms OutCubic → M3 enter token)
        opacity: root._contentVisible ? 1 : 0
        scale: root._contentVisible ? 1 : 0.96
        transformOrigin: Item.Center
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        onCurrentIndexChanged: {
            if (currentIndex !== root.currentImageIndex)
                root.currentImageIndex = currentIndex
        }

        onCountChanged: {
            if (count > 0 && !root._initialized) {
                root._syncToCurrentWallpaper(true)
            }
        }

        delegate: Item {
            id: delegateItem
            required property int index
            readonly property string filePath: root._imgFilePath(index)
            readonly property string fileName: root._imgFileName(index)
            readonly property string mediaKind: root._mediaKind(fileName)
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isHovered: itemMouseArea.containsMouse
            readonly property bool isActive: filePath.length > 0
                && root._normalizedFilePath(filePath) === root._normalizedFilePath(root.currentWallpaperPath)

            width: isCurrent ? root.expandedCardWidth : root.sliceWidth
            height: root.cardHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            z: isCurrent ? 100 : (isHovered ? 90 : 50 - Math.min(Math.abs(index - skewView.currentIndex), 50))

            // sourceSize latch: only upscale, never re-decode downward when leaving current
            property int _sourceW: Math.round(root.sliceWidth * 1.5 * root._dpr)
            property int _sourceH: Math.round(root.cardHeight * 0.7 * root._dpr)
            onIsCurrentChanged: {
                // sourceSize latch: upscale when becoming current
                if (isCurrent) {
                    _sourceW = Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                    _sourceH = Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                }
                // Reset flip when leaving current
                if (!isCurrent && root._flippedImageIndex === index)
                    root._flippedImageIndex = -1
            }

            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            // Edge-fade: cards far from center fade out (skwd style)
            // Quantized to 5% steps to reduce scene graph updates during scroll
            readonly property real fadeZone: root.sliceWidth * 1.5
            readonly property real _rawEdgeOpacity: {
                if (isCurrent) return 1.0
                if (fadeZone <= 0) return 1.0
                const center = (x - skewView.contentX) + width * 0.5
                const leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
                const rightFade = Math.min(1.0, Math.max(0.0, (skewView.width - center) / fadeZone))
                return Math.min(leftFade, rightFade)
            }
            opacity: Math.round(_rawEdgeOpacity * 20) / 20

            // Hit-test mask: only accept clicks inside the parallelogram shape
            containmentMask: Item {
                function contains(point: point): bool {
                    const w = delegateItem.width
                    const h = delegateItem.height
                    const sk = root.skewExtent
                    if (h <= 0 || w <= 0) return false
                    const leftX = sk * (1.0 - point.y / h)
                    const rightX = w - sk * (point.y / h)
                    return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h
                }
            }

            // ═══ Flip container (Y-axis rotation for card flip) ═══
            readonly property bool isFlipped: root._flippedImageIndex === delegateItem.index

            Item {
                id: flipContainer
                anchors.fill: parent
                transform: Rotation {
                    id: flipRotation
                    origin.x: flipContainer.width / 2
                    origin.y: flipContainer.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: delegateItem.isFlipped ? 180 : 0
                    Behavior on angle {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.clickBounce.duration
                            easing.type: Appearance.animation.clickBounce.type
                            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
                        }
                    }
                }

                // ════════ FRONT FACE ════════
                Item {
                    id: frontFace
                    anchors.fill: parent
                    visible: flipRotation.angle < 90

            // ── Shadow (current card only) ──
            Canvas {
                z: -1
                anchors.fill: parent
                anchors.margins: -10
                visible: delegateItem.isCurrent
                property real shadowAlpha: 0.6
                // Debounce repaint — avoid per-frame redraws during width animation
                Timer {
                    id: shadowRepaintDebounce
                    interval: 50
                    onTriggered: parent.requestPaint()
                }
                onWidthChanged: shadowRepaintDebounce.restart()
                onHeightChanged: shadowRepaintDebounce.restart()
                onVisibleChanged: if (visible) shadowRepaintDebounce.restart()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const ox = 10
                    const oy = 10
                    const w = delegateItem.width
                    const h = delegateItem.height
                    const sk = root.skewExtent
                    const layers = [
                        { dx: 4, dy: 10, alpha: shadowAlpha * 0.5 },
                        { dx: 2.4, dy: 6, alpha: shadowAlpha * 0.3 },
                        { dx: 5.6, dy: 14, alpha: shadowAlpha * 0.2 }
                    ]
                    for (let i = 0; i < layers.length; i++) {
                        const l = layers[i]
                        ctx.globalAlpha = l.alpha
                        ctx.fillStyle = "#000000"
                        ctx.beginPath()
                        ctx.moveTo(ox + sk + l.dx, oy + l.dy)
                        ctx.lineTo(ox + w + l.dx, oy + l.dy)
                        ctx.lineTo(ox + w - sk + l.dx, oy + h + l.dy)
                        ctx.lineTo(ox + l.dx, oy + h + l.dy)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
            }

            // ── Image container — masked to parallelogram ──
            Item {
                id: imageContainer
                anchors.fill: parent

                // Thumbnail (image / gif)
                ThumbnailImage {
                    visible: delegateItem.filePath.length > 0 && delegateItem.mediaKind !== "video"
                        && !(delegateItem.isCurrent && root.animatePreview && delegateItem.mediaKind === "gif")
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    generateThumbnail: true
                    sourcePath: delegateItem.filePath
                    thumbnailSizeName: root._thumbSizeName
                    cache: true
                    asynchronous: true
                    retainWhileLoading: true
                    smooth: true
                    mipmap: delegateItem.isCurrent
                    sourceSize.width: delegateItem._sourceW
                    sourceSize.height: delegateItem._sourceH
                }

                // Animated GIF preview (current only)
                AnimatedImage {
                    visible: delegateItem.isCurrent && root.animatePreview && delegateItem.mediaKind === "gif"
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: visible ? ("file://" + delegateItem.filePath) : ""
                    playing: visible
                    asynchronous: true
                    cache: true
                }

                // Video first-frame preview
                Image {
                    visible: delegateItem.mediaKind === "video"
                        && !(delegateItem.isCurrent && root.animatePreview)
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: delegateItem.isCurrent
                    sourceSize.width: delegateItem._sourceW
                    sourceSize.height: delegateItem._sourceH
                    source: {
                        if (!visible) return ""
                        const ff = Wallpapers.videoFirstFrames[delegateItem.filePath]
                        return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                    }
                    Component.onCompleted: {
                        if (delegateItem.mediaKind === "video")
                            Wallpapers.ensureVideoFirstFrame(delegateItem.filePath)
                    }
                }

                // Video playback preview (current only)
                VideoOutput {
                    id: videoPreviewOutput
                    visible: delegateItem.isCurrent && root.animatePreview && delegateItem.mediaKind === "video"
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop

                    property bool _shouldPlay: visible && delegateItem.filePath.length > 0

                    MediaPlayer {
                        id: videoPreviewPlayer
                        source: videoPreviewOutput._shouldPlay
                            ? ("file://" + delegateItem.filePath) : ""
                        videoOutput: videoPreviewOutput
                        loops: MediaPlayer.Infinite
                        onSourceChanged: {
                            if (source.toString().length > 0)
                                play()
                        }
                    }
                }

                // Darkening overlay for non-current cards (skwd style)
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0,
                        delegateItem.isCurrent ? 0 :
                        delegateItem.isHovered ? 0.15 : 0.4)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                // Parallelogram mask — CurveRenderer provides AA, no MSAA layers needed
                layer.enabled: true
                layer.smooth: delegateItem.isCurrent
                layer.samples: delegateItem.isCurrent ? 4 : 0
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Shape {
                            width: imageContainer.width
                            height: imageContainer.height
                            antialiasing: true
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "white"
                                strokeColor: "transparent"
                                startX: root.skewExtent; startY: 0
                                PathLine { x: delegateItem.width;               y: 0 }
                                PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                                PathLine { x: 0;                               y: delegateItem.height }
                                PathLine { x: root.skewExtent;                 y: 0 }
                            }
                        }
                    }
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3
                }
            }

            // ── Video/GIF type badge ──
            Rectangle {
                visible: delegateItem.mediaKind === "video" || delegateItem.mediaKind === "gif"
                anchors {
                    top: parent.top; right: parent.right
                    topMargin: 10; rightMargin: root.skewExtent + 10
                }
                width: mediaTypeRow.implicitWidth + 10
                height: 26
                radius: 6
                color: root.badgeSurfaceColor

                Row {
                    id: mediaTypeRow
                    anchors.centerIn: parent
                    spacing: 3

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: delegateItem.mediaKind === "video" ? "play_arrow" : "gif"
                        iconSize: 14
                        color: root.badgeTextColor
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: delegateItem.mediaKind === "video" ? "VID" : "GIF"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: root.badgeTextColor
                    }
                }
            }

            // ── "Active" badge ──
            Rectangle {
                visible: delegateItem.isActive
                anchors {
                    bottom: parent.bottom; right: parent.right
                    bottomMargin: 12; rightMargin: root.skewExtent + 10
                }
                implicitWidth: activeLabel.implicitWidth + 14
                implicitHeight: activeLabel.implicitHeight + 6
                radius: height / 2
                color: ColorUtils.applyAlpha(root.accentColor, 0.92)

                StyledText {
                    id: activeLabel
                    anchors.centerIn: parent
                    text: Translation.tr("Active")
                    color: ColorUtils.contrastColor(root.accentColor)
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }
            }

            // ── Favourite badge (front face — small heart on current card) ──
            Rectangle {
                visible: delegateItem.isCurrent && root._isFavourite(delegateItem.fileName)
                anchors {
                    bottom: parent.bottom; left: parent.left
                    bottomMargin: 12; leftMargin: root.skewExtent + 10
                }
                width: 28; height: 28
                radius: height / 2
                color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.85)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "favorite"
                    iconSize: 16
                    color: Appearance.colors.colOnError
                }
            }

            // ── Glow border (skwd style — rendered on all cards) ──
            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: delegateItem.isCurrent
                        ? root.accentColor
                        : delegateItem.isHovered
                            ? ColorUtils.applyAlpha(root.accentColor, 0.4)
                            : Qt.rgba(0, 0, 0, 0.6)
                    Behavior on strokeColor {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    strokeWidth: delegateItem.isCurrent ? 3 : 1
                    startX: root.skewExtent; startY: 0
                    PathLine { x: delegateItem.width;               y: 0 }
                    PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                    PathLine { x: 0;                               y: delegateItem.height }
                    PathLine { x: root.skewExtent;                 y: 0 }
                }
            }

                } // END frontFace

                // ════════ BACK FACE ════════
                Item {
                    id: backFace
                    anchors.fill: parent
                    visible: flipRotation.angle >= 90
                    // Un-mirror: the flip rotation mirrors text, so rotate back
                    transform: Rotation {
                        origin.x: backFace.width / 2
                        origin.y: backFace.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 180
                    }

                    Item {
                        id: backClip
                        anchors.fill: parent

                        // Surface background
                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.m3colors.m3surfaceContainer
                        }

                        // Faded thumbnail behind
                        ThumbnailImage {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            generateThumbnail: true
                            sourcePath: delegateItem.filePath
                            thumbnailSizeName: root._thumbSizeName
                            cache: true
                            asynchronous: true
                            opacity: 0.12
                            sourceSize.width: Math.round(root.expandedCardWidth * 0.3 * root._dpr)
                            sourceSize.height: Math.round(root.cardHeight * 0.3 * root._dpr)
                        }

                        // Action buttons column
                        Column {
                            anchors.centerIn: parent
                            spacing: 12
                            width: Math.min(parent.width * 0.45, 280)

                            // Wallpaper name
                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: delegateItem.fileName.replace(/\.[^/.]+$/, "").toUpperCase()
                                color: Appearance.colors.colTertiary
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            // Divider
                            Rectangle {
                                width: parent.width; height: 1
                                color: ColorUtils.applyAlpha(root.textColor, 0.1)
                            }

                            // Favourite toggle row
                            Item {
                                width: parent.width; height: 36

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Translation.tr("FAVOURITE")
                                    color: Appearance.colors.colTertiary
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                }

                                // Parallelogram toggle switch (skwd style)
                                Item {
                                    id: favToggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 48; height: 24

                                    readonly property bool checked: root._isFavourite(delegateItem.fileName)

                                    // Track
                                    Canvas {
                                        anchors.fill: parent
                                        property bool isOn: favToggle.checked
                                        property color fillColor: isOn
                                            ? root.accentColor
                                            : ColorUtils.applyAlpha(root.textColor, 0.15)
                                        onFillColorChanged: requestPaint()
                                        onIsOnChanged: requestPaint()
                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            const sk = 8
                                            ctx.fillStyle = fillColor
                                            ctx.beginPath()
                                            ctx.moveTo(sk, 0)
                                            ctx.lineTo(width, 0)
                                            ctx.lineTo(width - sk, height)
                                            ctx.lineTo(0, height)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }

                                    // Knob
                                    Canvas {
                                        width: 22; height: 18; y: 3
                                        x: favToggle.checked ? parent.width - width - 4 : 4
                                        Behavior on x {
                                            enabled: Appearance.animationsEnabled
                                            NumberAnimation {
                                                duration: Appearance.animation.elementMoveFast.duration
                                                easing.type: Appearance.animation.elementMoveFast.type
                                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                            }
                                        }
                                        property color knobColor: favToggle.checked
                                            ? ColorUtils.contrastColor(root.accentColor)
                                            : root.textColor
                                        onKnobColorChanged: requestPaint()
                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            const sk = 5
                                            ctx.fillStyle = knobColor
                                            ctx.beginPath()
                                            ctx.moveTo(sk, 0)
                                            ctx.lineTo(width, 0)
                                            ctx.lineTo(width - sk, height)
                                            ctx.lineTo(0, height)
                                            ctx.closePath()
                                            ctx.fill()
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root._toggleFavourite(delegateItem.fileName)
                                    }
                                }
                            }

                            // Divider
                            Rectangle {
                                width: parent.width; height: 1
                                color: ColorUtils.applyAlpha(root.textColor, 0.1)
                            }

                            // Apply button
                            Rectangle {
                                width: parent.width; height: 42; radius: 8
                                color: backApplyMouse.containsMouse
                                    ? ColorUtils.applyAlpha(root.accentColor, 0.25)
                                    : ColorUtils.applyAlpha(root.textColor, 0.06)
                                border.width: 1
                                border.color: backApplyMouse.containsMouse
                                    ? ColorUtils.applyAlpha(root.accentColor, 0.4)
                                    : ColorUtils.applyAlpha(root.textColor, 0.08)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("APPLY")
                                    color: backApplyMouse.containsMouse
                                        ? root.accentColor
                                        : Appearance.colors.colTertiary
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                MouseArea {
                                    id: backApplyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.wallpaperSelected(delegateItem.filePath)
                                        root._flippedImageIndex = -1
                                    }
                                }
                            }

                            // Delete button
                            Rectangle {
                                id: deleteBtn
                                width: parent.width; height: 42; radius: 8
                                property bool confirmMode: false
                                color: backDeleteMouse.containsMouse
                                    ? (confirmMode ? Qt.rgba(1, 0.2, 0.2, 0.35) : Qt.rgba(1, 0.3, 0.3, 0.25))
                                    : ColorUtils.applyAlpha(root.textColor, 0.06)
                                border.width: 1
                                border.color: backDeleteMouse.containsMouse
                                    ? Qt.rgba(1, 0.3, 0.3, 0.4)
                                    : ColorUtils.applyAlpha(root.textColor, 0.08)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: deleteBtn.confirmMode
                                        ? Translation.tr("CONFIRM DELETE")
                                        : Translation.tr("DELETE")
                                    color: backDeleteMouse.containsMouse ? "#ff6b6b"
                                        : Appearance.colors.colTertiary
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                Timer {
                                    id: deleteConfirmTimeout
                                    interval: 3000
                                    onTriggered: deleteBtn.confirmMode = false
                                }

                                MouseArea {
                                    id: backDeleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!deleteBtn.confirmMode) {
                                            deleteBtn.confirmMode = true
                                            deleteConfirmTimeout.restart()
                                        } else {
                                            deleteConfirmTimeout.stop()
                                            deleteBtn.confirmMode = false
                                            // Delete the file
                                            _deleteFileProc.command = ["rm", "-f",
                                                FileUtils.trimFileProtocol(delegateItem.filePath)]
                                            _deleteFileProc.running = true
                                            root._flippedImageIndex = -1
                                        }
                                    }
                                }
                            }

                            // Open folder button
                            Rectangle {
                                width: parent.width; height: 42; radius: 8
                                color: backOpenMouse.containsMouse
                                    ? ColorUtils.applyAlpha(root.accentColor, 0.25)
                                    : ColorUtils.applyAlpha(root.textColor, 0.06)
                                border.width: 1
                                border.color: backOpenMouse.containsMouse
                                    ? ColorUtils.applyAlpha(root.accentColor, 0.4)
                                    : ColorUtils.applyAlpha(root.textColor, 0.08)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Appearance.animation.elementMoveFast.type
                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: Translation.tr("OPEN FOLDER")
                                    color: backOpenMouse.containsMouse
                                        ? root.accentColor
                                        : Appearance.colors.colTertiary
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation {
                                            duration: Appearance.animation.elementMoveFast.duration
                                            easing.type: Appearance.animation.elementMoveFast.type
                                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                        }
                                    }
                                }

                                MouseArea {
                                    id: backOpenMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const dir = delegateItem.filePath.substring(0, delegateItem.filePath.lastIndexOf("/"))
                                        Qt.openUrlExternally("file://" + dir)
                                        root._flippedImageIndex = -1
                                    }
                                }
                            }
                        }

                        // Click anywhere on back to dismiss (also handles right-click)
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root._flippedImageIndex = -1
                        }

                        // Parallelogram mask for back face — only allocated when flipped
                        layer.enabled: delegateItem.isFlipped
                        layer.smooth: true
                        layer.samples: 4
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Shape {
                                    width: backClip.width
                                    height: backClip.height
                                    antialiasing: true
                                    preferredRendererType: Shape.CurveRenderer
                                    ShapePath {
                                        fillColor: "white"
                                        strokeColor: "transparent"
                                        startX: root.skewExtent; startY: 0
                                        PathLine { x: delegateItem.width;               y: 0 }
                                        PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                                        PathLine { x: 0;                               y: delegateItem.height }
                                        PathLine { x: root.skewExtent;                 y: 0 }
                                    }
                                }
                            }
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }
                    }

                    // Back face glow border
                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: root.accentColor
                            strokeWidth: 2
                            startX: root.skewExtent; startY: 0
                            PathLine { x: delegateItem.width;               y: 0 }
                            PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                            PathLine { x: 0;                               y: delegateItem.height }
                            PathLine { x: root.skewExtent;                 y: 0 }
                        }
                    }
                } // END backFace

            } // END flipContainer

            // ── Mouse interaction (skwd style — right-click flips current) ──
            // Disabled when card is flipped so back face buttons receive clicks
            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: !delegateItem.isFlipped
                enabled: !delegateItem.isFlipped
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    root.showKeyboardGuide = false
                    if (mouse.button === Qt.RightButton) {
                        // Right-click: flip current card
                        if (root.currentImageIndex === delegateItem.index) {
                            root._flippedImageIndex = root._flippedImageIndex === delegateItem.index
                                ? -1 : delegateItem.index
                        } else {
                            root._goToImageIndex(delegateItem.index)
                        }
                    } else {
                        if (root.currentImageIndex === delegateItem.index) {
                            root.activateCurrent()
                        } else {
                            root._goToImageIndex(delegateItem.index)
                        }
                    }
                }
            }
        }
    }

    // Folder dropdown popup is anchored to the toolbar folder button (folderDropdownBtn).
    // Defined here at root level so it can overlay all content.

    // ═══════════════════════════════════════════════════
    // TOP CHROME — compact filter pill (Toolbar-style glass)
    // ═══════════════════════════════════════════════════
    Item {
        id: filterBar
        anchors {
            top: skewView.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 10
        }
        z: 220
        visible: root.hasImages

        implicitWidth: filterBarGlass.implicitWidth
        implicitHeight: filterBarGlass.implicitHeight
        width: implicitWidth
        height: implicitHeight

        // Fade-in with content
        opacity: root._contentVisible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        // Shadow (matching Toolbar)
        Loader {
            active: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
            anchors.fill: filterBarGlass
            sourceComponent: StyledRectangularShadow {
                target: filterBarGlass
                anchors.fill: undefined
            }
        }

        GlassBackground {
            id: filterBarGlass
            anchors.fill: parent
            fallbackColor: Appearance.m3colors.m3surfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.overlayTransparentize
            screenX: { const p = filterBar.mapToGlobal(0, 0); return p.x }
            screenY: { const p = filterBar.mapToGlobal(0, 0); return p.y }
            screenWidth: Quickshell.screens[0]?.width ?? 1920
            screenHeight: Quickshell.screens[0]?.height ?? 1080
            border.width: (Appearance.angelEverywhere || Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder
                : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
            implicitHeight: 40
            implicitWidth: filterBarRow.implicitWidth + 20
            radius: height / 2
        }

        Row {
            id: filterBarRow
            anchors.centerIn: parent
            spacing: 2

            Repeater {
                model: [
                    { label: Translation.tr("All"), icon: "filter_list", filter: 0 },
                    { label: "IMG", icon: "image", filter: 1 },
                    { label: "VID", icon: "play_arrow", filter: 2 },
                    { label: "GIF", icon: "gif", filter: 3 }
                ]

                delegate: Rectangle {
                    id: typeChip
                    required property int index
                    required property var modelData
                    readonly property bool isSelected: root.typeFilter === modelData.filter

                    anchors.verticalCenter: parent.verticalCenter
                    width: typeChipRow.implicitWidth + 14
                    height: 24
                    radius: height / 2

                    color: isSelected
                        ? Appearance.colors.colPrimaryContainer
                        : typeChipHover.containsMouse
                            ? ColorUtils.applyAlpha(Appearance.colors.colOnSurface, 0.08)
                            : "transparent"

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    Row {
                        id: typeChipRow
                        anchors.centerIn: parent
                        spacing: 3

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: typeChip.modelData.icon
                            iconSize: 12
                            color: typeChip.isSelected
                                ? Appearance.colors.colOnPrimaryContainer
                                : root.textColor
                            opacity: typeChip.isSelected ? 1.0 : 0.70
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: typeChip.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: typeChip.isSelected ? Font.DemiBold : Font.Normal
                            color: typeChip.isSelected
                                ? Appearance.colors.colOnPrimaryContainer
                                : root.textColor
                            opacity: typeChip.isSelected ? 1.0 : 0.72
                        }
                    }

                    MouseArea {
                        id: typeChipHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.typeFilter = typeChip.modelData.filter
                    }
                }
            }

            // ─ Divider ─
            Rectangle {
                width: 1; height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(root.textColor, 0.18)
            }

            // ─ Counter ─
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: 6
                rightPadding: 4
                text: (root.currentImageIndex + 1) + " / " + root.imageCount
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: root.textColor
                opacity: 0.78
            }

            // ─ Color hue dots divider ─
            Rectangle {
                width: 1; height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(root.textColor, 0.18)
                visible: root._colorsLoaded
            }

            // ─ Color hue filter dots (M3-style circles: 0-11 hue + achromatic) ─
            Repeater {
                model: root._colorsLoaded ? 13 : 0

                Rectangle {
                    id: colorDot
                    required property int index
                    readonly property int filterValue: index < 12 ? index : 99
                    readonly property bool isSelected: root.colorFilter === filterValue
                    readonly property bool isDark: Appearance.m3colors.darkmode

                    // M3 tonal colors: moderate saturation, adjusted lightness for dark/light
                    readonly property color dotColor: index === 12
                        ? (isDark ? Qt.hsla(0, 0, 0.55, 1.0) : Qt.hsla(0, 0, 0.45, 1.0))
                        : Qt.hsla(index / 12.0,
                            isDark ? 0.55 : 0.50,
                            isDark ? 0.52 : 0.48, 1.0)

                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    radius: 8

                    color: dotColor
                    opacity: isSelected ? 1.0 : (colorDotHover.containsMouse ? 0.85 : 0.55)
                    border.width: isSelected ? 2.5 : 0
                    border.color: isSelected ? Appearance.colors.colOnSurface : "transparent"
                    scale: isSelected ? 1.15 : (colorDotHover.containsMouse ? 1.08 : 1.0)

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Behavior on border.width {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    MouseArea {
                        id: colorDotHover
                        anchors.fill: parent
                        anchors.margins: -2
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.colorFilter = colorDot.isSelected ? -1 : colorDot.filterValue
                    }
                }
            }
        }
    }

    // ─── Toolbar ───
    Toolbar {
        id: toolbarArea
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 22 }
        screenX: { const p = toolbarArea.mapToGlobal(0, 0); return p.x }
        screenY: { const p = toolbarArea.mapToGlobal(0, 0); return p.y }

        // Slide-up entrance
        opacity: root._contentVisible ? 1 : 0
        transform: Translate {
            id: toolbarEntrance
            y: root._contentVisible ? 0 : 20
            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        IconToolbarButton {
            implicitWidth: height
            enabled: root.canGoBack
            onClicked: Wallpapers.navigateBack()
            text: "arrow_back"
            StyledToolTip { text: Translation.tr("Back") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: Wallpapers.navigateUp()
            text: "arrow_upward"
            StyledToolTip { text: Translation.tr("Up") }
        }
        IconToolbarButton {
            implicitWidth: height
            enabled: root.canGoForward
            onClicked: Wallpapers.navigateForward()
            text: "arrow_forward"
            StyledToolTip { text: Translation.tr("Forward") }
        }

        // ─ Folder name + dropdown trigger ─
        Item {
            id: folderDropdownBtn
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.min(root.width * 0.20, 240)
            implicitWidth: folderBtnRow.implicitWidth + 12
            implicitHeight: 38

            property bool hovered: folderBtnMa.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: folderDropdownBtn.hovered
                    ? ColorUtils.applyAlpha(root.accentColor, 0.10)
                    : folderDropdown.visible
                        ? ColorUtils.applyAlpha(root.accentColor, 0.14)
                        : "transparent"
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }
            }

            Row {
                id: folderBtnRow
                anchors.centerIn: parent
                spacing: 4

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.currentFolderName
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.textColor
                    elide: Text.ElideMiddle
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, folderDropdownBtn.Layout.maximumWidth - folderChevron.width - 20)
                }
                MaterialSymbol {
                    id: folderChevron
                    anchors.verticalCenter: parent.verticalCenter
                    text: folderDropdown.visible ? "expand_less" : "expand_more"
                    iconSize: 16
                    color: root.textColor
                    opacity: root.hasFolders ? 0.7 : 0.3
                    rotation: folderDropdown.visible ? 0 : 0
                }
            }

            MouseArea {
                id: folderBtnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.hasFolders ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!root.hasFolders) return
                    if (root.folderCount === 1) {
                        root.navigateIntoFolder(root._folderItems[0].path)
                    } else {
                        folderDropdown.visible = !folderDropdown.visible
                    }
                }
            }

            StyledToolTip {
                text: root.hasFolders
                    ? Translation.tr("Browse subfolders (%1)").arg(root.folderCount)
                    : root.currentFolderPath
            }

            // ── Folder dropdown popup ──
            Popup {
                id: folderDropdown
                y: -folderDropdown.height - 8
                x: (folderDropdownBtn.width - width) / 2
                width: Math.max(200, folderDropdownBtn.width)
                height: Math.min(
                    folderDropdownContent.implicitHeight + 16,
                    root.height * 0.5
                )
                padding: 0
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle {
                    radius: root.cardRadius
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                        : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
                        : Appearance.m3colors.m3surfaceContainer
                    border.width: 1
                    border.color: root.borderColor
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: ColorUtils.applyAlpha("#000000", 0.25)
                        shadowVerticalOffset: 4
                        shadowBlur: 0.4
                    }
                }

                enter: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1
                        duration: Appearance.calcEffectiveDuration(150); easing.type: Easing.OutCubic }
                    NumberAnimation { property: "scale"; from: 0.92; to: 1
                        duration: Appearance.calcEffectiveDuration(150); easing.type: Easing.OutCubic }
                }
                exit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0
                        duration: Appearance.calcEffectiveDuration(100); easing.type: Easing.InCubic }
                    NumberAnimation { property: "scale"; from: 1; to: 0.95
                        duration: Appearance.calcEffectiveDuration(100); easing.type: Easing.InCubic }
                }

                contentItem: Flickable {
                    clip: true
                    contentHeight: folderDropdownContent.implicitHeight
                    contentWidth: width
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    Column {
                        id: folderDropdownContent
                        width: parent.width
                        topPadding: 8
                        bottomPadding: 8

                        Repeater {
                            model: root._folderItems

                            delegate: Item {
                                id: dropFolderDelegate
                                required property int index
                                required property var modelData
                                width: folderDropdownContent.width
                                height: 36

                                property bool _hovered: false

                                Rectangle {
                                    anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
                                    radius: root.cardRadius * 0.6
                                    color: dropFolderDelegate._hovered
                                        ? ColorUtils.applyAlpha(root.accentColor, 0.14)
                                        : "transparent"
                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }
                                }

                                Row {
                                    anchors {
                                        verticalCenter: parent.verticalCenter
                                        left: parent.left; right: parent.right
                                        leftMargin: 12; rightMargin: 12
                                    }
                                    spacing: 8

                                    MaterialSymbol {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "folder"
                                        iconSize: 16
                                        color: root.accentColor
                                        opacity: 0.85
                                    }
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 24 - parent.spacing
                                        text: dropFolderDelegate.modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: root.textColor
                                        elide: Text.ElideMiddle
                                        maximumLineCount: 1
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: dropFolderDelegate._hovered = true
                                    onExited: dropFolderDelegate._hovered = false
                                    onClicked: {
                                        folderDropdown.close()
                                        root.navigateIntoFolder(dropFolderDelegate.modelData.path)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        // ─ Skip to first / last ─
        IconToolbarButton {
            implicitWidth: height
            enabled: root.hasImages && root.currentImageIndex > 0
            onClicked: root._goToImageIndex(0)
            text: "first_page"
            StyledToolTip { text: Translation.tr("First wallpaper (Home)") }
        }
        IconToolbarButton {
            implicitWidth: height
            enabled: root.hasImages && root.currentImageIndex < root.imageCount - 1
            onClicked: root._goToImageIndex(root.imageCount - 1)
            text: "last_page"
            StyledToolTip { text: Translation.tr("Last wallpaper (End)") }
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: {
                root.showKeyboardGuide = false
                root.useDarkMode = !root.useDarkMode
                MaterialThemeLoader.setDarkMode(root.useDarkMode)
            }
            text: root.useDarkMode ? "dark_mode" : "light_mode"
            StyledToolTip { text: Translation.tr("Toggle light/dark mode") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: Wallpapers.randomFromCurrentFolder(root.useDarkMode)
            text: "shuffle"
            StyledToolTip { text: Translation.tr("Random wallpaper") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.toggleAnimatedPreview()
            text: root.animatePreview ? "motion_photos_on" : "motion_photos_off"
            StyledToolTip { text: root.animatePreview ? Translation.tr("Disable animated preview") : Translation.tr("Enable animated preview") }
        }

        // ─ Sort mode ─
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.sortMode = root.sortMode === "date" ? "color" : "date"
            text: root.sortMode === "date" ? "schedule" : "palette"
            opacity: root.sortMode === "color" ? 1.0 : 0.6
            StyledToolTip { text: root.sortMode === "date" ? Translation.tr("Sort by date") : Translation.tr("Sort by color") }
        }

        // ─ Favourites filter ─
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.favouriteFilterActive = !root.favouriteFilterActive
            text: root.favouriteFilterActive ? "favorite" : "favorite_border"
            opacity: root.favouriteFilterActive ? 1.0 : 0.6
            StyledToolTip { text: root.favouriteFilterActive ? Translation.tr("Show all") : Translation.tr("Show favourites only") }
        }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        Item { Layout.fillWidth: true }

        ToolbarTextField {
            id: searchField
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.min(root.width * 0.22, 340)
            implicitHeight: 38
            placeholderText: activeFocus ? Translation.tr("Search wallpapers") : Translation.tr("Hit \"/\" to search")
            text: Wallpapers.searchQuery
            onTextChanged: Wallpapers.searchQuery = text
            onActiveFocusChanged: if (activeFocus) root.showKeyboardGuide = false
        }

        IconToolbarButton {
            implicitWidth: height
            enabled: (Wallpapers.searchQuery ?? "").length > 0
            onClicked: Wallpapers.searchQuery = ""
            text: "backspace"
            StyledToolTip { text: Translation.tr("Clear search") }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToGalleryRequested()
            text: "view_carousel"
            StyledToolTip { text: Translation.tr("Gallery view") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToGridRequested()
            text: "grid_view"
            StyledToolTip { text: Translation.tr("Grid view") }
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.closeRequested()
            text: "close"
            StyledToolTip { text: Translation.tr("Close") }
        }
    }
}
