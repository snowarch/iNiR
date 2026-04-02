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
                if (typeFilter === 0
                    || (typeFilter === 1 && kind === "image")
                    || (typeFilter === 2 && kind === "video")
                    || (typeFilter === 3 && kind === "gif")) {
                    imgMap.push(i)
                }
            }
        }
        _imageIndexMap = imgMap
        _folderItems = folders
    }

    onTypeFilterChanged: {
        _snapDone = false
        currentImageIndex = 0
        _rebuildIndexMaps()
        _scheduleInitialScroll()
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
    property bool _snapDone: false
    property int _wheelAccum: 0
    property bool _contentVisible: false
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

    // ─── Fade-in on open (skwd pattern: 50ms delay → opacity 0→1, 400ms OutCubic) ───
    Timer {
        id: contentShowTimer
        interval: 50
        onTriggered: root._contentVisible = true
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
        onTriggered: root._rebuildIndexMaps()
    }

    Component.onCompleted: {
        _rebuildIndexMaps()
        if (totalCount > 0)
            _scheduleInitialScroll()
        updateThumbnails()
        contentShowTimer.restart()
        forceActiveFocus()
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._snapDone = false
            root.currentImageIndex = 0
            root._rebuildIndexMaps()
            root._scheduleInitialScroll()
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
            } else if (folderPanel.expanded) {
                folderPanel.expanded = false
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
                    folderPanel.expanded = !folderPanel.expanded
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
            NumberAnimation { duration: 300 }
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
        highlightMoveDuration: root._snapDone
            ? (root._rapidNavigation ? 150 : 350)
            : 0
        highlightFollowsCurrentItem: true
        header: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }
        footer: Item { width: (skewView.width - root.expandedCardWidth) / 2; height: 1 }

        boundsBehavior: Flickable.StopAtBounds
        model: root.imageCount
        currentIndex: root.currentImageIndex

        // Fade-in animation (skwd: 400ms OutCubic)
        opacity: root._contentVisible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        onCurrentIndexChanged: {
            if (currentIndex !== root.currentImageIndex)
                root.currentImageIndex = currentIndex
        }

        onCountChanged: {
            // skwd pattern: snap on first model population (more reliable than timer alone)
            if (count > 0 && !root._snapDone) {
                const idx = root._findCurrentWallpaperImageIndex()
                if (idx >= 0) {
                    root.currentImageIndex = idx
                    positionViewAtIndex(idx, ListView.Center)
                }
                root._snapDone = true
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

            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }

            // Edge-fade: cards far from center fade out (skwd style)
            readonly property real viewX: x - skewView.contentX
            readonly property real fadeZone: root.sliceWidth * 1.5
            readonly property real edgeOpacity: {
                if (isCurrent) return 1.0
                if (fadeZone <= 0) return 1.0
                const center = viewX + width * 0.5
                const leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
                const rightFade = Math.min(1.0, Math.max(0.0, (skewView.width - center) / fadeZone))
                return Math.min(leftFade, rightFade)
            }
            opacity: edgeOpacity

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

            // ── Shadow (current card only) ──
            Canvas {
                z: -1
                anchors.fill: parent
                anchors.margins: -10
                visible: delegateItem.isCurrent
                property real shadowAlpha: 0.6
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
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
                    sourceSize.width: delegateItem.isCurrent
                        ? Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.sliceWidth * 1.5 * root._dpr)
                    sourceSize.height: delegateItem.isCurrent
                        ? Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.cardHeight * 0.7 * root._dpr)
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
                    sourceSize.width: delegateItem.isCurrent
                        ? Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.sliceWidth * 1.5 * root._dpr)
                    sourceSize.height: delegateItem.isCurrent
                        ? Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                        : Math.round(root.cardHeight * 0.7 * root._dpr)
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
                        ColorAnimation { duration: 200 }
                    }
                }

                // Parallelogram mask — high-quality anti-aliasing (skwd: samples: 8)
                layer.enabled: true
                layer.smooth: true
                layer.samples: 4
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: ShaderEffectSource {
                        sourceItem: Item {
                            width: imageContainer.width
                            height: imageContainer.height
                            layer.enabled: true
                            layer.smooth: true
                            layer.samples: 8

                            Shape {
                                anchors.fill: parent
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
                        ColorAnimation { duration: 200 }
                    }
                    strokeWidth: delegateItem.isCurrent ? 3 : 1
                    startX: root.skewExtent; startY: 0
                    PathLine { x: delegateItem.width;               y: 0 }
                    PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                    PathLine { x: 0;                               y: delegateItem.height }
                    PathLine { x: root.skewExtent;                 y: 0 }
                }
            }

            // ── Mouse interaction (skwd style) ──
            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.showKeyboardGuide = false
                    if (root.currentImageIndex === delegateItem.index)
                        root.activateCurrent()
                    else
                        root._goToImageIndex(delegateItem.index)
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
            verticalCenterOffset: -(root.bottomChromeInset - root.topChromeLead) / 2
        }
        visible: root.hasFolders
        z: 200

        property bool expanded: false

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
            border.color: ColorUtils.applyAlpha(root.accentColor, 0.4)

            Row {
                id: collapsedPill
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "folder"
                    iconSize: 15
                    color: root.accentColor
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
                        color: root.accentColor
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

            Rectangle {
                anchors { top: panelHeader.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
                height: 1
                color: ColorUtils.applyAlpha(root.borderColor, 0.5)
            }

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
                                    ? ColorUtils.applyAlpha(root.accentColor, 0.14)
                                    : "transparent"
                                border.width: folderItemDelegate._hovered ? 1 : 0
                                border.color: ColorUtils.applyAlpha(root.accentColor, 0.25)
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
                                    color: root.accentColor
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
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
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
            onClicked: root.toggleAnimatedPreview()
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
