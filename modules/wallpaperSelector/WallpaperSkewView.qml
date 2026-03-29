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
import Qt5Compat.GraphicalEffects as GE
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import Quickshell

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
    // _imageIndexMap[i] = original model index of the i-th image/video item
    // _folderItems = array of { name, path } for all folders in current dir
    property var _imageIndexMap: []
    property var _folderItems: []
    property var _imageDominantColors: ({})
    property var _pendingDominantColorIndices: []
    property int _dominantProbeImageIndex: -1
    property string _dominantProbeSource: ""

    // 0=all, 1=image, 2=video, 3=gif
    property int typeFilter: 0
    // -1=all, 0..themeSwatches.length-1 = selected generated palette family
    property int paletteFilterIndex: -1

    function _mediaKind(name: string): string {
        const l = name.toLowerCase()
        if (l.endsWith(".mp4") || l.endsWith(".webm") || l.endsWith(".mkv") || l.endsWith(".avi") || l.endsWith(".mov")) return "video"
        if (l.endsWith(".gif")) return "gif"
        return "image"
    }

    function _normalizedFilePath(path: string): string {
        return FileUtils.trimFileProtocol(String(path ?? ""))
    }

    function _paletteDistance(colorA: color, colorB: color): real {
        const dr = colorA.r - colorB.r
        const dg = colorA.g - colorB.g
        const db = colorA.b - colorB.b
        const dl = colorA.hslLightness - colorB.hslLightness
        return dr * dr + dg * dg + db * db + dl * dl * 0.35
    }

    function _dominantSwatchIndexForColor(col: color): int {
        let bestIndex = -1
        let bestDistance = Number.POSITIVE_INFINITY
        for (let i = 0; i < themeSwatches.length; i++) {
            const dist = _paletteDistance(col, themeSwatches[i])
            if (dist < bestDistance) {
                bestDistance = dist
                bestIndex = i
            }
        }
        return bestIndex
    }

    function _dominantColorForImageIndex(imgIdx: int): color {
        const path = _normalizedFilePath(_imgFilePath(imgIdx))
        return _imageDominantColors[path]
    }

    function _itemQuantizerSource(imgIdx: int): string {
        const path = _normalizedFilePath(_imgFilePath(imgIdx))
        if (path.length === 0) return ""
        const lower = _imgFileName(imgIdx).toLowerCase()
        const isVideo = lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
        const isGif = lower.endsWith(".gif")
        if (isVideo || isGif) {
            Wallpapers.ensureThumbnailForPath(path, root._thumbSizeName)
            if (isVideo)
                Wallpapers.ensureVideoFirstFrame(path)
            const thumbPath = Wallpapers.getExpectedThumbnailPath(path, root._thumbSizeName)
            return thumbPath.length > 0 ? ("file://" + thumbPath) : ""
        }
        return "file://" + path
    }

    function _modelQuantizerSource(modelIdx: int): string {
        if (modelIdx < 0 || modelIdx >= totalCount)
            return ""
        const path = _normalizedFilePath(folderModel.get(modelIdx, "filePath") ?? "")
        if (path.length === 0)
            return ""
        const lower = String(folderModel.get(modelIdx, "fileName") ?? "").toLowerCase()
        const isVideo = lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
        const isGif = lower.endsWith(".gif")
        if (isVideo || isGif) {
            Wallpapers.ensureThumbnailForPath(path, root._thumbSizeName)
            if (isVideo)
                Wallpapers.ensureVideoFirstFrame(path)
            const thumbPath = Wallpapers.getExpectedThumbnailPath(path, root._thumbSizeName)
            return thumbPath.length > 0 ? ("file://" + thumbPath) : ""
        }
        return "file://" + path
    }

    function _matchesPaletteFilter(filePath: string): bool {
        if (paletteFilterIndex < 0)
            return true
        const dominant = _imageDominantColors[_normalizedFilePath(filePath)]
        if (!dominant)
            return false
        return _dominantSwatchIndexForColor(dominant) === paletteFilterIndex
    }

    function _scheduleDominantColorScan(reset = false): void {
        if (reset) {
            _pendingDominantColorIndices = []
            _dominantProbeImageIndex = -1
            _dominantProbeSource = ""
        }

        // Only scan when palette filtering is active or about to be used
        // Prioritize items near the current view position
        const pending = []
        const viewCenter = root.currentImageIndex
        const nearRange = 20 // probe nearby items first
        const addIfNeeded = (i) => {
            const isDir = folderModel.get(i, "fileIsDir") ?? false
            if (isDir) return
            const path = _normalizedFilePath(folderModel.get(i, "filePath") ?? "")
            if (path.length === 0 || _imageDominantColors[path]) return
            pending.push(i)
        }

        // Near items first (sorted by distance from current view)
        for (let d = 0; d < nearRange && d < totalCount; d++) {
            const before = viewCenter - d
            const after = viewCenter + d
            if (before >= 0 && before < totalCount) addIfNeeded(before)
            if (d > 0 && after >= 0 && after < totalCount) addIfNeeded(after)
        }
        // Then the rest
        for (let i = 0; i < totalCount; i++) {
            if (i >= viewCenter - nearRange && i <= viewCenter + nearRange) continue
            addIfNeeded(i)
        }

        if (pending.length > 0) {
            _pendingDominantColorIndices = pending
            dominantColorProbeTimer.restart()
        }
    }

    function _startNextDominantColorProbe(): void {
        if (_pendingDominantColorIndices.length === 0) {
            _dominantProbeImageIndex = -1
            _dominantProbeSource = ""
            dominantColorProbeTimeout.stop()
            return
        }

        const next = _pendingDominantColorIndices[0]
        _pendingDominantColorIndices = _pendingDominantColorIndices.slice(1)
        _dominantProbeImageIndex = next
        _dominantProbeSource = _modelQuantizerSource(next)

        if (_dominantProbeSource.length === 0) {
            Qt.callLater(_startNextDominantColorProbe)
            return
        }

        dominantColorProbeTimeout.restart()
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
                const filePath = folderModel.get(i, "filePath") ?? ""
                const kind = _mediaKind(fname)
                if ((typeFilter === 0
                    || (typeFilter === 1 && kind === "image")
                    || (typeFilter === 2 && kind === "video")
                    || (typeFilter === 3 && kind === "gif"))
                    && _matchesPaletteFilter(filePath)) {
                    imgMap.push(i)
                }
            }
        }
        _imageIndexMap = imgMap
        _folderItems = folders
    }

    // When typeFilter changes, rebuild index maps and reset position
    onTypeFilterChanged: {
        _snapDone = false
        currentImageIndex = 0
        _rebuildIndexMaps()
        _scheduleInitialScroll()
    }
    onPaletteFilterIndexChanged: {
        _snapDone = false
        currentImageIndex = 0
        _rebuildIndexMaps()
        _scheduleInitialScroll()
        _scheduleDominantColorScan()
    }

    // ─── Image-only derived counts ───
    readonly property int imageCount: _imageIndexMap.length
    readonly property bool hasImages: imageCount > 0
    readonly property int folderCount: _folderItems.length
    readonly property bool hasFolders: folderCount > 0

    // ─── Active item (image-only index space) ───
    property int currentImageIndex: 0

    // Map image-space index → model index
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
    readonly property string activeQuantizerSource: {
        if (!hasImages || activePath.length === 0) return ""
        const lower = activeName.toLowerCase()
        const isVideo = lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
        const isGif = lower.endsWith(".gif")
        if (isVideo || isGif) {
            const thumbPath = Wallpapers.getExpectedThumbnailPath(activePath, "x-large")
            return thumbPath.length > 0 ? ("file://" + thumbPath) : ""
        }
        return "file://" + activePath
    }

    property bool showKeyboardGuide: true
    property bool animatePreview: false
    property bool _snapDone: false
    property real _focusPulse: 0
    property int _wheelAccum: 0

    // ─── Rapid-navigation velocity tracking ───
    // When the user presses arrow keys (or wheel) quickly in succession,
    // reduce highlightMoveDuration so animations don't queue up.
    // Threshold is 3 steps so casual browsing stays at the normal pace.
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

    // ─── Skew / layout parameters (matching skwd geometry) ───
    readonly property real thumbnailDecodeScale: 1.2
    readonly property int baseSliceWidth: 135
    readonly property int baseExpandedCardWidth: 924
    readonly property int baseCardHeight: 520
    readonly property int baseSkewExtent: 35
    readonly property int baseSliceSpacing: -22
    readonly property int visibleSliceCount: 12
    // Top chrome inset references filterBar
    readonly property real topChromeLead: isTopBar ? 10 : isVerticalBar ? 12 : 14
    readonly property real topChromeGap: 8
    readonly property real topChromeInset: topChromeLead + filterBar.height + topChromeGap
    readonly property real bottomChromeInset: toolbarArea.height + (hintBar.visible ? hintBar.height + 26 : 24) + 18
    readonly property real availableStageHeight: Math.max(220, root.height - topChromeInset - bottomChromeInset)
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
    // skewFrameWidth for the expanded card (used for thumbnail decode budget)
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
    readonly property color filterBarColor: Appearance.angelEverywhere ? ColorUtils.applyAlpha(Appearance.angel.colGlassCard, 0.92)
        : Appearance.inirEverywhere ? ColorUtils.applyAlpha(Appearance.inir.colLayer1, 0.94)
        : Appearance.auroraEverywhere ? ColorUtils.applyAlpha(Appearance.aurora.colSubSurface, 0.94)
        : ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.94)
    readonly property color filterBarHoverColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.colors.colLayer1Hover
    readonly property color chipSelectedColor: Appearance.colors.colPrimaryContainer
    readonly property color chipSelectedTextColor: Appearance.colors.colOnPrimaryContainer
    readonly property color badgeSurfaceColor: ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.90)
    readonly property color badgeTextColor: Appearance.colors.colOnLayer2
    readonly property var themeSwatches: [
        Appearance.m3colors.m3primary,
        Appearance.m3colors.m3secondary,
        Appearance.m3colors.m3tertiary,
        Appearance.m3colors.m3surfaceContainerHigh
    ]

    // ═══════════════════════════════════════════════════
    // ACCENT COLOR
    // ═══════════════════════════════════════════════════
    property string _debouncedQuantizerSource: ""
    Timer {
        id: quantizerDebounce
        interval: 280
        onTriggered: root._debouncedQuantizerSource = root.activeQuantizerSource
    }
    onActiveQuantizerSourceChanged: quantizerDebounce.restart()

    Timer {
        id: dominantColorProbeTimer
        interval: 50
        onTriggered: root._startNextDominantColorProbe()
    }

    Timer {
        id: dominantColorProbeTimeout
        interval: 220
        onTriggered: root._startNextDominantColorProbe()
    }

    Timer {
        id: paletteRebuildDebounce
        interval: 60
        onTriggered: {
            const previousPath = root.activePath
            root._rebuildIndexMaps()
            if (root.imageCount <= 0) {
                root.currentImageIndex = 0
                return
            }
            let nextIndex = 0
            for (let i = 0; i < root.imageCount; i++) {
                if (root._imgFilePath(i) === previousPath) {
                    nextIndex = i
                    break
                }
            }
            root.currentImageIndex = Math.max(0, Math.min(root.imageCount - 1, nextIndex))
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root._debouncedQuantizerSource
        depth: 0
        rescaleSize: 10
    }

    ColorQuantizer {
        id: dominantProbeQuantizer
        source: root._dominantProbeSource
        depth: 0
        rescaleSize: 8
        onColorsChanged: {
            if (root._dominantProbeImageIndex < 0)
                return
            const dominant = colors?.[0]
            if (dominant) {
                const path = root._normalizedFilePath(root.folderModel.get(root._dominantProbeImageIndex, "filePath") ?? "")
                if (path.length > 0) {
                    const copy = Object.assign({}, root._imageDominantColors)
                    copy[path] = dominant
                    root._imageDominantColors = copy
                    if (root.paletteFilterIndex >= 0)
                        paletteRebuildDebounce.restart()
                }
            }
            dominantColorProbeTimeout.stop()
            Qt.callLater(root._startNextDominantColorProbe)
        }
    }

    readonly property color accentColor: {
        const c = quantizer?.colors?.[0]
        if (!c || root.activePath.length === 0)
            return Appearance.colors.colPrimary
        return ColorUtils.mix(c, Appearance.colors.colPrimary, 0.45)
    }

    property color _accent: accentColor
    Behavior on _accent {
        enabled: Appearance.animationsEnabled
        ColorAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    // ═══════════════════════════════════════════════════
    // FOCUS PULSE
    // ═══════════════════════════════════════════════════
    SequentialAnimation {
        id: focusPulseAnim
        running: false
        NumberAnimation {
            target: root; property: "_focusPulse"; to: 1
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.5)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
        NumberAnimation {
            target: root; property: "_focusPulse"; to: 0
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.8)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    // ═══════════════════════════════════════════════════
    // NAVIGATION
    // ═══════════════════════════════════════════════════
    function _goToImageIndex(index: int): void {
        if (!hasImages) return
        const next = Math.max(0, Math.min(imageCount - 1, index))
        if (next === currentImageIndex) return
        _trackNavStep()
        currentImageIndex = next
        showKeyboardGuide = false
        if (_snapDone) focusPulseAnim.restart()
    }

    function moveSelection(delta: int): void {
        _goToImageIndex(currentImageIndex + delta)
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

    // Find current wallpaper in image-only index space
    function _findCurrentWallpaperImageIndex(): int {
        const target = FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
        if (target.length === 0 || imageCount === 0) return -1
        for (let i = 0; i < imageCount; i++) {
            if (FileUtils.trimFileProtocol(_imgFilePath(i)) === target)
                return i
        }
        return -1
    }

    function _scheduleInitialScroll(): void {
        if (_snapDone) return
        initialSnapTimer.restart()
    }

    Timer {
        id: initialSnapTimer
        interval: 80
        property int _retries: 0
        onTriggered: {
            if (skewView.width <= 0) {
                if (_retries < 10) {
                    _retries++
                    initialSnapTimer.restart()
                }
                return
            }
            const idx = root._findCurrentWallpaperImageIndex()
            if (idx >= 0) {
                root.currentImageIndex = idx
                skewView.positionViewAtIndex(idx, ListView.Center)
            }
            root._snapDone = true
            _retries = 0
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
        indexMapRebuildDebounce.restart()
        if (!_snapDone && totalCount > 0)
            _scheduleInitialScroll()
    }

    Timer {
        id: indexMapRebuildDebounce
        interval: 30
        onTriggered: {
            root._rebuildIndexMaps()
            root._scheduleDominantColorScan()
        }
    }

    Component.onCompleted: {
        _rebuildIndexMaps()
        if (totalCount > 0)
            _scheduleInitialScroll()
        updateThumbnails()
        _scheduleDominantColorScan(true)
        forceActiveFocus()
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._snapDone = false
            root.currentImageIndex = 0
            root._imageDominantColors = ({})
            root._rebuildIndexMaps()
            root._scheduleInitialScroll()
            root._scheduleDominantColorScan(true)
        }
    }

    Connections {
        target: Wallpapers
        function onThumbnailGeneratedFile() {
            // Only probe dominant colors when palette filtering is active;
            // scanning the full folder on every thumbnail generation is expensive.
            if (root.paletteFilterIndex >= 0)
                root._scheduleDominantColorScan()
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
            // Layered dismiss: search → animated preview → folder panel → close
            if ((Wallpapers.searchQuery ?? "").length > 0) {
                Wallpapers.searchQuery = ""
                searchField.text = ""
            } else if (root.animatePreview) {
                root.animatePreview = false
            } else if (folderPanel.expanded) {
                folderPanel.expanded = false
            } else {
                root.closeRequested()
            }
            break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 3 : 1))
            break
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 3 : 1)
            break
        case Qt.Key_Up:
            root.navigateUpDirectory(); break
        case Qt.Key_Down:
            if (root.folderCount === 1)
                root.navigateIntoFolder(root._folderItems[0].path)
            else if (root.folderCount > 1)
                folderPanel.expanded = !folderPanel.expanded
            break
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

            // High-resolution trackpads send small deltas (< 120).
            // Use a smaller threshold so scrolling feels responsive.
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
    // MAIN SKEW LISTVIEW — asymmetric widths (skwd style)
    // ═══════════════════════════════════════════════════
    ListView {
        id: skewView
        anchors {
            top: parent.top
            topMargin: root.topChromeInset
            bottom: parent.bottom
            bottomMargin: root.bottomChromeInset
            horizontalCenter: parent.horizontalCenter
        }

        width: root.deckWidth
        orientation: ListView.Horizontal
        spacing: root.sliceSpacing
        clip: false
        cacheBuffer: 1400
        focus: false

        // Snap the *current* (expanded) card to horizontal center.
        // Because delegate widths are asymmetric, we use the expanded card half-width.
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.expandedCardWidth) / 2
        preferredHighlightEnd: (width + root.expandedCardWidth) / 2
        highlightMoveDuration: root._snapDone
            ? Appearance.calcEffectiveDuration(root._rapidNavigation ? 180 : 320)
            : 0
        highlightFollowsCurrentItem: true
        header: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }
        footer: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }

        boundsBehavior: Flickable.StopAtBounds
        model: root.imageCount
        currentIndex: root.currentImageIndex

        onCurrentIndexChanged: {
            if (currentIndex !== root.currentImageIndex)
                root.currentImageIndex = currentIndex
        }

        delegate: Item {
            id: delegateRoot
            required property int index
            readonly property string filePath: root._imgFilePath(index)
            readonly property string fileName: root._imgFileName(index)
            readonly property string mediaKind: root._mediaKind(fileName)
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isActive: filePath.length > 0 && filePath === root.currentWallpaperPath

            // skwd-style: expanded center, narrow slices for non-current
            width: isCurrent ? root.expandedCardWidth : root.sliceWidth
            height: root.cardHeight
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            z: isCurrent ? 10 : 1

            // Smooth width transition — faster during flick to avoid fighting momentum
            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: skewView.moving
                        ? Appearance.calcEffectiveDuration(120)
                        : Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }

            // Edge-fade: cards far from center fade out
            readonly property real _distFromCenter: {
                const midX = skewView.contentX + skewView.width / 2
                const itemMidX = x + width / 2
                return Math.abs(midX - itemMidX)
            }
            readonly property real _edgeOpacity: isCurrent ? 1.0
                : Math.max(0.25, 1.0 - (_distFromCenter / (skewView.width * 0.55)) * 0.65)

            opacity: _edgeOpacity
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.showKeyboardGuide = false
                    if (root.currentImageIndex === index)
                        root.activateCurrent()
                    else
                        root._goToImageIndex(index)
                }
            }

            // ── Card visual (skewed parallelogram via Shape/MultiEffect masking) ──

            // Shadow (current delegate only — one extra effect for the whole view)
            Item {
                visible: delegateRoot.isCurrent
                anchors.fill: parent
                anchors.margins: -24
                layer.enabled: visible
                layer.smooth: true
                opacity: 0.45

                Shape {
                    x: 24 + 3
                    y: 24 + 8
                    width: delegateRoot.width
                    height: delegateRoot.height
                    antialiasing: true

                    ShapePath {
                        fillColor: Appearance.colors.colShadow
                        strokeColor: "transparent"
                        startX: root.skewExtent; startY: 0
                        PathLine { x: delegateRoot.width;               y: 0 }
                        PathLine { x: delegateRoot.width - root.skewExtent; y: delegateRoot.height }
                        PathLine { x: 0;                               y: delegateRoot.height }
                        PathLine { x: root.skewExtent;                 y: 0 }
                    }
                }

                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.5
                    blurMax: 24
                }
            }

            // Image container — masked to parallelogram by MultiEffect
            Item {
                id: cardImageContainer
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.samples: 2
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Item {
                            width: cardImageContainer.width
                            height: cardImageContainer.height
                            layer.enabled: true
                            layer.smooth: true
                            layer.samples: 4

                            Shape {
                                anchors.fill: parent
                                antialiasing: true
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: "white"
                                    strokeColor: "transparent"
                                    startX: root.skewExtent; startY: 0
                                    PathLine { x: delegateRoot.width;               y: 0 }
                                    PathLine { x: delegateRoot.width - root.skewExtent; y: delegateRoot.height }
                                    PathLine { x: 0;                               y: delegateRoot.height }
                                    PathLine { x: root.skewExtent;                 y: 0 }
                                }
                            }
                        }
                    }
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3
                }

                // Background fill
                Rectangle {
                    anchors.fill: parent
                    color: root.baseColor
                }

                // ── Thumbnail (image / gif) ──
                ThumbnailImage {
                    visible: delegateRoot.filePath.length > 0 && delegateRoot.mediaKind !== "video"
                        && !(delegateRoot.isCurrent && root.animatePreview && delegateRoot.mediaKind === "gif")
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    generateThumbnail: true
                    sourcePath: delegateRoot.filePath
                    thumbnailSizeName: root._thumbSizeName
                    cache: true
                    asynchronous: true
                    retainWhileLoading: true
                    mipmap: delegateRoot.isCurrent
                    sourceSize.width: delegateRoot.isCurrent
                        ? Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.sliceWidth * 1.5 * root._dpr)
                    sourceSize.height: delegateRoot.isCurrent
                        ? Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.cardHeight * 0.7 * root._dpr)
                }

                // ── Animated GIF preview (current delegate only) ──
                AnimatedImage {
                    visible: delegateRoot.isCurrent && root.animatePreview && delegateRoot.mediaKind === "gif"
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: visible ? ("file://" + delegateRoot.filePath) : ""
                    playing: visible
                    asynchronous: true
                    cache: true
                }

                // ── Video first-frame preview ──
                Image {
                    visible: delegateRoot.mediaKind === "video"
                        && !(delegateRoot.isCurrent && root.animatePreview)
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: delegateRoot.isCurrent
                    sourceSize.width: delegateRoot.isCurrent
                        ? Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.sliceWidth * 1.5 * root._dpr)
                    sourceSize.height: delegateRoot.isCurrent
                        ? Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.cardHeight * 0.7 * root._dpr)
                    source: {
                        if (!visible) return ""
                        const ff = Wallpapers.videoFirstFrames[delegateRoot.filePath]
                        return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                    }
                    Component.onCompleted: {
                        if (delegateRoot.mediaKind === "video")
                            Wallpapers.ensureVideoFirstFrame(delegateRoot.filePath)
                    }
                }

                // ── Video playback preview (current delegate only) ──
                VideoOutput {
                    id: videoPreviewOutput
                    visible: delegateRoot.isCurrent && root.animatePreview && delegateRoot.mediaKind === "video"
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop

                    property bool _shouldPlay: visible && delegateRoot.filePath.length > 0

                    MediaPlayer {
                        id: videoPreviewPlayer
                        source: videoPreviewOutput._shouldPlay
                            ? ("file://" + delegateRoot.filePath) : ""
                        videoOutput: videoPreviewOutput
                        loops: MediaPlayer.Infinite
                        onSourceChanged: {
                            if (source.toString().length > 0)
                                play()
                        }
                    }
                }

                // Darkening overlay for non-current cards
                Rectangle {
                    anchors.fill: parent
                    color: root.baseColor
                    opacity: delegateRoot.isCurrent ? 0.0 : 0.20
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                }

                // ── Video/GIF type badge (top-right, offset inward from skew edge) ──
                Rectangle {
                    visible: delegateRoot.mediaKind === "video" || delegateRoot.mediaKind === "gif"
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
                            text: delegateRoot.mediaKind === "video" ? "play_arrow" : "gif"
                            iconSize: 14
                            color: root.badgeTextColor
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: delegateRoot.mediaKind === "video" ? "VID" : "GIF"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: root.badgeTextColor
                        }
                    }
                }

                // ── "Active" badge (bottom-right, inset from skew edge) ──
                Rectangle {
                    visible: delegateRoot.isActive
                    anchors {
                        bottom: parent.bottom; right: parent.right
                        bottomMargin: 12; rightMargin: root.skewExtent + 10
                    }
                    implicitWidth: activeLabel.implicitWidth + 14
                    implicitHeight: activeLabel.implicitHeight + 6
                    radius: height / 2
                    color: ColorUtils.applyAlpha(root._accent, 0.92)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    StyledText {
                        id: activeLabel
                        anchors.centerIn: parent
                        text: Translation.tr("Active")
                        color: ColorUtils.contrastColor(root._accent)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Glow border — only rendered on current and active cards
            // Non-current cards rely on the mask clip edge for separation
            Shape {
                id: glowBorder
                anchors.fill: parent
                visible: delegateRoot.isCurrent || delegateRoot.isActive
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: delegateRoot.isCurrent ? root._accent
                        : delegateRoot.isActive ? Appearance.colors.colPrimary
                        : root.borderColor
                    Behavior on strokeColor {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                    strokeWidth: delegateRoot.isCurrent ? 2.5 : delegateRoot.isActive ? 2.0 : 1.0
                    startX: root.skewExtent; startY: 0
                    PathLine { x: delegateRoot.width;               y: 0 }
                    PathLine { x: delegateRoot.width - root.skewExtent; y: delegateRoot.height }
                    PathLine { x: 0;                               y: delegateRoot.height }
                    PathLine { x: root.skewExtent;                 y: 0 }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // FOLDER NAVIGATION PANEL (right side, floating)
    // ═══════════════════════════════════════════════════
    Item {
        id: folderPanel
        anchors {
            right: parent.right
            rightMargin: 20
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: -(root.bottomChromeInset - root.topChromeInset) / 2
        }
        visible: root.hasFolders
        z: 200

        property bool expanded: false

        // Size: collapsed = pill, expanded = list panel
        width: expanded ? folderPanelRect.implicitWidth : collapsedPill.implicitWidth + 24
        height: expanded
            ? Math.min(folderPanelRect.implicitHeight, root.availableStageHeight * 0.8)
            : collapsedPill.implicitHeight + 16

        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        // ── Collapsed pill ──
        Rectangle {
            id: collapsedPillBg
            anchors.fill: parent
            visible: !folderPanel.expanded
            radius: height / 2
            color: ColorUtils.applyAlpha(root.baseColor, 0.88)
            border.width: 1
            border.color: ColorUtils.applyAlpha(root._accent, 0.4)

            Row {
                id: collapsedPill
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "folder"
                    iconSize: 15
                    color: root._accent
                    opacity: 0.9
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.folderCount.toString()
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.Medium
                    color: root.textColor
                    opacity: 0.85
                }
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "expand_more"
                    iconSize: 14
                    color: root.textColor
                    opacity: 0.5
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: folderPanel.expanded = true
            }
        }

        // ── Expanded panel ──
        Rectangle {
            id: folderPanelRect
            anchors.fill: parent
            visible: folderPanel.expanded
            radius: root.cardRadius
            color: ColorUtils.applyAlpha(root.baseColor, 0.96)
            border.width: 1
            border.color: ColorUtils.applyAlpha(root.borderColor, 0.7)
            clip: true

            implicitWidth: 220
            implicitHeight: panelHeader.implicitHeight + folderScroll.contentHeight + 24

            // Header row
            Item {
                id: panelHeader
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                implicitHeight: 36
                height: 36

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "folder_open"
                        iconSize: 15
                        color: root._accent
                        opacity: 0.8
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Folders")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.textColor
                        opacity: 0.65
                    }
                }

                // Close button
                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 24; height: 24; radius: 12
                    color: closeHover.containsMouse
                        ? ColorUtils.applyAlpha(root.textColor, 0.12)
                        : "transparent"
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 14
                        color: root.textColor
                        opacity: 0.55
                    }

                    MouseArea {
                        id: closeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: folderPanel.expanded = false
                    }
                }
            }

            // Thin divider
            Rectangle {
                anchors { top: panelHeader.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                height: 1
                color: ColorUtils.applyAlpha(root.borderColor, 0.5)
            }

            // Scrollable folder list
            Flickable {
                id: folderScroll
                anchors {
                    top: panelHeader.bottom
                    topMargin: 8
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: 8
                    rightMargin: 8
                    bottomMargin: 8
                }
                clip: true
                contentHeight: folderListColumn.implicitHeight
                contentWidth: width
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: folderListColumn
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root._folderItems

                        delegate: Item {
                            id: folderItemDelegate
                            required property int index
                            required property var modelData
                            width: folderListColumn.width
                            height: 36

                            property bool _hovered: false

                            Rectangle {
                                anchors.fill: parent
                                radius: root.cardRadius * 0.6
                                color: folderItemDelegate._hovered
                                    ? ColorUtils.applyAlpha(root._accent, 0.14)
                                    : "transparent"
                                border.width: folderItemDelegate._hovered ? 1 : 0
                                border.color: ColorUtils.applyAlpha(root._accent, 0.25)
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "folder"
                                    iconSize: 15
                                    color: root._accent
                                    opacity: 0.85
                                }
                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 23 - parent.spacing
                                    text: folderItemDelegate.modelData.name
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
                                onEntered: folderItemDelegate._hovered = true
                                onExited: folderItemDelegate._hovered = false
                                onClicked: {
                                    folderPanel.expanded = false
                                    root.navigateIntoFolder(folderItemDelegate.modelData.path)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // TOP CHROME — skwd-style unified filter bar
    // ═══════════════════════════════════════════════════
    Rectangle {
        id: filterBar
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.topChromeLead
        }
        z: 220
        visible: root.hasImages

        // Pill shape, auto-sized to content
        implicitWidth: filterBarRow.implicitWidth + 28
        implicitHeight: filterBarRow.implicitHeight + 14
        width: implicitWidth
        height: implicitHeight

        radius: height / 2
        color: root.filterBarColor
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.borderColor, 0.55)

        // ── Filter bar content ──
        Row {
            id: filterBarRow
            anchors.centerIn: parent
            spacing: 0

            // ─ Up directory button ─
            Rectangle {
                width: upBtn.implicitWidth + 14
                height: filterBarRow.implicitHeight
                color: upBtnHover.containsMouse
                    ? root.filterBarHoverColor
                    : "transparent"
                radius: height / 2
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                Row {
                    id: upBtn
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "arrow_upward"
                        iconSize: 13
                        color: root.textColor
                        opacity: 0.78
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Up")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.textColor
                        opacity: 0.78
                    }
                }
                MouseArea {
                    id: upBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navigateUpDirectory()
                }
            }

            // ─ Divider ─
            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(root.textColor, 0.20)
            }

            // ─ Type filter chips ─
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                leftPadding: 6
                rightPadding: 6

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
                        width: typeChipRow.implicitWidth + 12
                        height: 24
                        radius: height / 2

                        color: isSelected
                            ? root.chipSelectedColor
                            : typeChipHover.containsMouse
                                ? root.filterBarHoverColor
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
                                    ? root.chipSelectedTextColor
                                    : root.textColor
                                opacity: typeChip.isSelected ? 1.0 : 0.70
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: typeChip.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: typeChip.isSelected ? Font.DemiBold : Font.Normal
                                color: typeChip.isSelected
                                    ? root.chipSelectedTextColor
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
            }

            // ─ Divider ─
            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(root.textColor, 0.20)
            }

            // ─ Theme swatches (generated palette, styled like settings UI) ─
            Row {
                id: hueDotsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                leftPadding: 8
                rightPadding: 8

                Repeater {
                    model: root.themeSwatches

                    delegate: Rectangle {
                        required property int index
                        required property color modelData
                        readonly property bool isSelected: root.paletteFilterIndex === index

                        width: 14
                        height: 14
                        radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData
                        border.width: isSelected ? 2 : 1
                        border.color: isSelected
                            ? Appearance.colors.colOnPrimaryContainer
                            : ColorUtils.applyAlpha(root.borderColor, 0.65)
                        z: 4 - index

                        x: index > 0 ? -index * 4 : 0

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.paletteFilterIndex = parent.isSelected ? -1 : index
                        }
                    }
                }
            }

            // ─ Divider ─
            Rectangle {
                width: 1; height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: ColorUtils.applyAlpha(root.textColor, 0.20)
            }

            // ─ Counter ─
            Item {
                width: counterInner.implicitWidth + 14
                height: filterBarRow.implicitHeight
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: counterInner
                    anchors.centerIn: parent
                    spacing: 4

                    // Folder badge (if folders exist)
                    Item {
                        visible: root.hasFolders
                        width: folderBadgeRow.implicitWidth
                        height: folderBadgeRow.implicitHeight

                        Row {
                            id: folderBadgeRow
                            spacing: 3

                            MaterialSymbol {
                                text: "folder"
                                iconSize: 11
                                color: root._accent
                                opacity: 0.85
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: root.folderCount.toString()
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.monospace
                                color: root.textColor
                                opacity: 0.75
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: root.hasFolders ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (root.hasFolders) folderPanel.expanded = true
                        }
                    }

                    StyledText {
                        visible: root.hasFolders
                        text: "·"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.textColor
                        opacity: 0.35
                    }

                    StyledText {
                        text: (root.currentImageIndex + 1) + " / " + root.imageCount
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.monospace
                        color: root.textColor
                        opacity: 0.82
                    }
                }
            }
        }
    }

    // ─── Keyboard hint ───
    Rectangle {
        id: hintBar
        anchors {
            bottom: toolbarArea.top
            bottomMargin: 12
            horizontalCenter: parent.horizontalCenter
        }
        visible: root.showKeyboardGuide
        opacity: visible ? 1.0 : 0.0
        z: 220
        radius: height / 2
        color: ColorUtils.applyAlpha(root.baseColor, 0.88)
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.borderColor, 0.45)
        width: hintText.implicitWidth + 24
        height: hintText.implicitHeight + 10
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: root.hasFolders
                ? Translation.tr("← → Browse  ·  ↑ Parent  ·  ↓ Folders  ·  / Search")
                : Translation.tr("← → Browse  ·  ↑ Parent  ·  / Search")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.textColor
            opacity: 0.75
        }
    }

    // ─── Toolbar ───
    Toolbar {
        id: toolbarArea
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 22 }
        screenX: { const p = toolbarArea.mapToGlobal(0, 0); return p.x }
        screenY: { const p = toolbarArea.mapToGlobal(0, 0); return p.y }

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

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: Math.min(root.width * 0.16, 200)
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.textColor
            text: root.currentFolderName
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        Rectangle {
            implicitWidth: 1; implicitHeight: 16
            color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                 : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                 : Appearance.colors.colOnSurfaceVariant
            opacity: 0.2
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
            onClicked: root.animatePreview = !root.animatePreview
            text: root.animatePreview ? "motion_photos_on" : "motion_photos_off"
            StyledToolTip { text: root.animatePreview ? Translation.tr("Disable animated preview") : Translation.tr("Enable animated preview") }
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
