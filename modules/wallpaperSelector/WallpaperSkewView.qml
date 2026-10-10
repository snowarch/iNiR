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
import Quickshell

// Skew wallpaper selector — parallelogram slice deck (ported from skwd) over a
// full-screen live preview of the focused wallpaper. The chrome is one toolbar:
// folder, search on "/", and the switch to the other pickers.
Item {
    id: root
    readonly property bool editorial: Appearance.editorialEverywhere

    required property var folderModel
    required property string currentWallpaperPath
    readonly property bool useDarkMode: Appearance.m3colors.darkmode

    signal wallpaperSelected(string filePath)
    signal directorySelected(string dirPath)
    signal closeRequested()
    signal switchToGridRequested()
    signal switchToGalleryRequested()

    // ═══════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property string currentFolderPath: String(folderModel?.folder ?? "")
    readonly property string currentFolderName: FileUtils.folderNameForPath(currentFolderPath)
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1

    // Model indices of the wallpapers (newest first) and the subfolders
    property var _imageIndexMap: []
    property var _folderItems: []

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
            if (folderModel.get(i, "fileIsDir") ?? false)
                folders.push({ name: folderModel.get(i, "fileName") ?? "", path: folderModel.get(i, "filePath") ?? "" })
            else
                imgMap.push(i)
        }
        // FolderListModel.Time yields oldest-first: newest wallpapers lead the deck
        imgMap.reverse()
        _imageIndexMap = imgMap
        _folderItems = folders
    }

    readonly property int imageCount: _imageIndexMap.length
    readonly property bool hasImages: imageCount > 0
    readonly property int folderCount: _folderItems.length
    readonly property bool hasFolders: folderCount > 0

    property int currentImageIndex: 0

    function _imgFilePath(imgIdx: int): string {
        if (imgIdx < 0 || imgIdx >= _imageIndexMap.length) return ""
        return folderModel.get(_imageIndexMap[imgIdx], "filePath") ?? ""
    }
    function _imgFileName(imgIdx: int): string {
        if (imgIdx < 0 || imgIdx >= _imageIndexMap.length) return ""
        return folderModel.get(_imageIndexMap[imgIdx], "fileName") ?? ""
    }

    readonly property string activePath: hasImages ? _imgFilePath(currentImageIndex) : ""

    property bool _initialized: false
    // When true, suppress highlight move animation (snap position instantly)
    property bool _suppressHighlightAnim: true
    property int _wheelAccum: 0
    property bool _contentVisible: false
    // Bound by parent (WallpaperCoverflow) to its _contentReady — drives close animation.
    property bool contentReady: false
    property bool _searchOpen: false

    onCurrentWallpaperPathChanged: {
        _initialized = false
        _syncToCurrentWallpaper(true)
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

    // ─── Content visibility (drives enter + exit) ───
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
        // The ListView layout is complete once content shows: re-enforce the target position
        if (_contentVisible && _initialized && hasImages)
            root._positionAtIndex(currentImageIndex)
    }

    // ─── Deck geometry (skwd proportions, scaled from the card height) ───
    readonly property real thumbnailDecodeScale: 1.2
    readonly property int baseSliceWidth: 135
    readonly property int baseExpandedCardWidth: 924
    readonly property int baseCardHeight: 520
    readonly property int baseSkewExtent: 35
    readonly property int baseSliceSpacing: -22
    readonly property int visibleSliceCount: 12
    // The preview owns the screen; the deck sits in the lower third as the chooser
    readonly property real skewScale: Math.max(0.45, Math.min(0.9,
        root.height * 0.34 / baseCardHeight,
        (root.width - 96) / baseExpandedCardWidth))
    readonly property int sliceWidth: Math.round(baseSliceWidth * skewScale)
    readonly property int expandedCardWidth: Math.round(baseExpandedCardWidth * skewScale)
    readonly property int cardHeight: Math.round(baseCardHeight * skewScale)
    readonly property int skewExtent: Math.round(baseSkewExtent * skewScale)
    readonly property int sliceSpacing: Math.round(baseSliceSpacing * skewScale)
    readonly property int deckWidth: Math.min(root.width,
        Math.round(expandedCardWidth + (visibleSliceCount - 1) * (sliceWidth + sliceSpacing)))
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
    readonly property color textColor: root.editorial ? Appearance.editorial.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color borderColor: root.editorial ? Appearance.editorial.rule
        : Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.45)
    readonly property real cardRadius: root.editorial ? Appearance.editorial.radius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.small
    readonly property color badgeSurfaceColor: root.editorial ? Appearance.editorial.ink
        : ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.90)
    readonly property color badgeTextColor: root.editorial ? Appearance.editorial.paperOnInk
        : Appearance.colors.colOnLayer2
    readonly property color accentColor: root.editorial ? Appearance.editorial.accent : Appearance.colors.colPrimary
    readonly property color separatorColor: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : ColorUtils.applyAlpha(Appearance.colors.colOnSurfaceVariant, 0.2)

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
    }

    function moveSelection(delta: int): void {
        _goToImageIndex(currentImageIndex + delta)
    }

    function activateCurrent(): void {
        const path = _imgFilePath(currentImageIndex)
        if (path.length > 0)
            wallpaperSelected(path)
    }

    function navigateUpDirectory(): void {
        Wallpapers.navigateUp()
    }

    function navigateIntoFolder(path: string): void {
        if (path && path.length > 0)
            directorySelected(path)
    }

    function _closeSearch(): void {
        Wallpapers.searchQuery = ""
        searchField.text = ""
        root._searchOpen = false
        root.forceActiveFocus()
    }

    function _wheelStep(angleDelta: point): void {
        const d = angleDelta.y !== 0 ? angleDelta.y : angleDelta.x
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

    function _findCurrentWallpaperImageIndex(): int {
        const target = FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
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

    function _positionAtIndex(index: int): void {
        if (!skewView || skewView.width <= 0 || index < 0 || index >= root.imageCount)
            return
        skewView.positionViewAtIndex(index, ListView.Center)
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

        _suppressHighlightAnim = true
        currentImageIndex = target

        if (skewView && skewView.width > 0) {
            root._positionAtIndex(target)
            // Again once delegates exist; an owned timer dies with the view (Qt.callLater outlived it)
            _repositionTimer.restart()
        } else {
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
                root._positionAtIndex(root.currentImageIndex)
                _repositionTimer.restart()
                _retries = 0
            } else if (_retries < 10) {
                _retries++
                _syncRetryTimer.restart()
            } else {
                _retries = 0
            }
        }
    }

    Timer {
        id: _repositionTimer
        interval: 0
        onTriggered: root._positionAtIndex(root.currentImageIndex)
    }

    // ═══════════════════════════════════════════════════
    // LIFECYCLE
    // ═══════════════════════════════════════════════════
    function updateThumbnails(): void {
        for (let i = 0; i < Math.min(imageCount, 30); i++) {
            const fp = _imgFilePath(i)
            if (fp.length === 0) continue
            Wallpapers.ensureThumbnailForPath(fp, root._thumbSizeName)
            if (_mediaKind(_imgFileName(i)) === "video")
                Wallpapers.ensureVideoFirstFrame(fp)
        }
    }

    onTotalCountChanged: {
        _rebuildIndexMaps()
        _initialized = false
        if (totalCount > 0)
            _syncToCurrentWallpaper(true)
        else
            currentImageIndex = 0
    }

    Component.onCompleted: {
        _rebuildIndexMaps()
        _syncToCurrentWallpaper(true)
        updateThumbnails()
        backdrop.show(root.activePath)
        contentShowTimer.restart()
        forceActiveFocus()
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._rebuildIndexMaps()
            root._initialized = false
            root._syncToCurrentWallpaper(true)
        }
    }

    // `inir wallpaperSelector move <n>` drives the deck like the arrow keys
    Connections {
        target: GlobalStates
        function onWallpaperSelectorMoveRequested(step: int): void { root.moveSelection(step) }
    }

    // ═══════════════════════════════════════════════════
    // INPUT
    // ═══════════════════════════════════════════════════
    Keys.onPressed: event => {
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        if (!searchField.activeFocus && (ctrl && event.key === Qt.Key_F || event.key === Qt.Key_Slash)) {
            root._searchOpen = true
            searchField.forceActiveFocus(); event.accepted = true; return
        }


        switch (event.key) {
        case Qt.Key_Escape:
            if ((Wallpapers.searchQuery ?? "").length > 0) root._closeSearch()
            else root.closeRequested()
            break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 3 : 1))
            break
        case Qt.Key_H:
            if (alt || ctrl) { event.accepted = false; return }
            root.moveSelection(-(shift ? 3 : 1)); break
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 3 : 1)
            break
        case Qt.Key_L:
            if (alt || ctrl) { event.accepted = false; return }
            root.moveSelection(shift ? 3 : 1); break
        case Qt.Key_Up:
            if (alt || ctrl) root.navigateUpDirectory()
            else root.moveSelection(-(shift ? 8 : 4))
            break
        case Qt.Key_K:
            root.moveSelection(-(shift ? 8 : 4)); break
        case Qt.Key_Down:
            if (alt || ctrl) { if (root.hasFolders) root.navigateIntoFolder(root._folderItems[0].path) }
            else root.moveSelection(shift ? 8 : 4)
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
        onWheel: event => root._wheelStep(event.angleDelta)
    }

    // ═══════════════════════════════════════════════════
    // LIVE PREVIEW — the focused wallpaper, full screen
    // ═══════════════════════════════════════════════════
    // Painted inside the picker (the desktop wallpaper is untouched until apply) so
    // windows never show through. Two slots crossfade; each decodes at screen size.
    Item {
        id: backdrop
        anchors.fill: parent
        z: -1
        opacity: root._contentVisible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        property Image front: slotA
        property string pendingUrl: ""
        readonly property int decodeWidth: Math.round(width * root._dpr)
        readonly property int decodeHeight: Math.round(height * root._dpr)

        function urlFor(path: string): string {
            const p = root._normalizedFilePath(path)
            if (p.length === 0) return ""
            if (root._mediaKind(p) !== "video") return "file://" + p
            // A video previews by its first frame
            const ff = Wallpapers.videoFirstFrames[p] ?? Wallpapers.videoFirstFrames[path] ?? ""
            if (!ff) {
                Wallpapers.ensureVideoFirstFrame(p)
                return ""
            }
            return ff.startsWith("file://") ? ff : "file://" + ff
        }

        function show(path: string): void {
            const url = urlFor(path)
            if (url.length === 0 || String(front.source) === url) return
            pendingUrl = url
            const back = front === slotA ? slotB : slotA
            if (String(back.source) === url && back.status === Image.Ready)
                front = back
            else
                back.source = url
        }

        function adopt(slot: Image): void {
            if (slot.status === Image.Ready && String(slot.source) === pendingUrl)
                front = slot
        }

        // Settles before decoding, so holding an arrow does not decode every wallpaper it passes
        Timer {
            id: previewSettle
            interval: root._rapidNavigation ? 160 : 40
            onTriggered: backdrop.show(root.activePath)
        }

        Connections {
            target: root
            function onActivePathChanged() { previewSettle.restart() }
        }

        Connections {
            target: Wallpapers
            function onVideoFirstFramesChanged() {
                if (root._mediaKind(root.activePath) === "video") previewSettle.restart()
            }
        }

        // Black base: no window shows through while the first decode lands
        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colScrim
        }

        Image {
            id: slotA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: backdrop.decodeWidth
            sourceSize.height: backdrop.decodeHeight
            opacity: backdrop.front === slotA ? 1 : 0
            onStatusChanged: backdrop.adopt(slotA)
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        Image {
            id: slotB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: backdrop.decodeWidth
            sourceSize.height: backdrop.decodeHeight
            opacity: backdrop.front === slotB ? 1 : 0
            onStatusChanged: backdrop.adopt(slotB)
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        // Shade only under the deck and the toolbar; the top of the preview stays clean
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.round(parent.height * 0.62)
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0) }
                GradientStop { position: 0.45; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.32) }
                GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.62) }
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // DECK — skwd-style parallelogram slices
    // ═══════════════════════════════════════════════════
    ListView {
        id: skewView
        anchors {
            bottom: chrome.top
            bottomMargin: Math.round(root.height * 0.04)
            horizontalCenter: parent.horizontalCenter
        }
        // Room for the current card's shadow
        height: root.cardHeight + 24

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
        currentIndex: root.imageCount > 0
            ? Math.max(0, Math.min(root.currentImageIndex, root.imageCount - 1))
            : -1

        opacity: root._contentVisible ? 1 : 0
        transform: Translate {
            y: root._contentVisible ? 0 : 24
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

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== root.currentImageIndex)
                root.currentImageIndex = currentIndex
        }

        onCountChanged: {
            if (count > 0 && !root._initialized)
                root._syncToCurrentWallpaper(true)
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
                if (isCurrent) {
                    _sourceW = Math.round(root.skewFrameWidth * root.thumbnailDecodeScale * root._dpr)
                    _sourceH = Math.round(root.cardHeight * root.thumbnailDecodeScale * root._dpr)
                }
            }

            Behavior on width {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            // Slices fade out toward the deck's ends, quantized to 5% steps to spare scene graph updates
            readonly property real fadeZone: root.sliceWidth * 1.5
            readonly property real _rawEdgeOpacity: {
                if (isCurrent || fadeZone <= 0) return 1.0
                const center = (x - skewView.contentX) + width * 0.5
                const leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
                const rightFade = Math.min(1.0, Math.max(0.0, (skewView.width - center) / fadeZone))
                return Math.min(leftFade, rightFade)
            }
            opacity: Math.round(_rawEdgeOpacity * 20) / 20

            // Hit-test only inside the parallelogram
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
                // Debounce repaint — no per-frame redraws during the width animation
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
                        { dx: 4, dy: 10, alpha: 0.3 },
                        { dx: 2.4, dy: 6, alpha: 0.18 },
                        { dx: 5.6, dy: 14, alpha: 0.12 }
                    ]
                    for (let i = 0; i < layers.length; i++) {
                        const l = layers[i]
                        ctx.globalAlpha = l.alpha
                        ctx.fillStyle = Appearance.colors.colScrim
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

            // ── Image — masked to the parallelogram ──
            Item {
                id: imageContainer
                anchors.fill: parent

                ThumbnailImage {
                    visible: delegateItem.filePath.length > 0 && delegateItem.mediaKind !== "video"
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    generateThumbnail: true
                    sourcePath: delegateItem.filePath
                    thumbnailSizeName: root._thumbSizeName
                    cache: true
                    asynchronous: true
                    retainWhileLoading: true
                    smooth: true
                    // Fixed from creation: flipping mipmap on an uploaded texture warns (QSGPlainTexture) and is ignored
                    mipmap: true
                    sourceSize.width: delegateItem._sourceW
                    sourceSize.height: delegateItem._sourceH
                }

                // Video first frame
                Image {
                    visible: delegateItem.mediaKind === "video"
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
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

                // Slices recede behind the current card
                Rectangle {
                    anchors.fill: parent
                    color: ColorUtils.applyAlpha(Appearance.colors.colScrim,
                        delegateItem.isCurrent ? 0 : delegateItem.isHovered ? 0.12 : 0.42)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }

                // Parallelogram mask: a smooth mask never cuts the AA'd edge
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
                                PathLine { x: delegateItem.width;                   y: 0 }
                                PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                                PathLine { x: 0;                                    y: delegateItem.height }
                                PathLine { x: root.skewExtent;                      y: 0 }
                            }
                        }
                    }
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }
            }

            // ── Video/GIF badge ──
            Rectangle {
                visible: delegateItem.isCurrent && delegateItem.mediaKind !== "image"
                anchors {
                    top: parent.top; right: parent.right
                    topMargin: 10; rightMargin: root.skewExtent + 10
                }
                width: mediaTypeRow.implicitWidth + 12
                height: 24
                radius: root.editorial ? Appearance.rounding.small : height / 2
                color: root.badgeSurfaceColor

                Row {
                    id: mediaTypeRow
                    anchors.centerIn: parent
                    spacing: 3

                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: delegateItem.mediaKind === "video" ? "play_arrow" : "gif"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.badgeTextColor
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: delegateItem.mediaKind === "video" ? Translation.tr("Video") : "GIF"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: root.badgeTextColor
                    }
                }
            }

            // ── The wallpaper in use: a check on its corner ──
            Rectangle {
                visible: delegateItem.isActive
                anchors {
                    bottom: parent.bottom; right: parent.right
                    // Clear of the slanted right edge, which reaches the bottom at width - skewExtent
                    bottomMargin: delegateItem.isCurrent ? 10 : 8
                    rightMargin: delegateItem.isCurrent ? root.skewExtent + 10
                        : Math.round((parent.width + root.skewExtent - width) / 2)
                }
                width: 24; height: 24
                radius: root.editorial ? Appearance.rounding.small : height / 2
                color: root.accentColor

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "check"
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 1
                    color: root.editorial ? Appearance.editorial.accentInk : ColorUtils.contrastColor(root.accentColor)
                }
                StyledToolTip { text: Translation.tr("Current wallpaper") }
            }

            // ── Edge: accent on the current card, a hairline between slices ──
            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: delegateItem.isCurrent
                        ? root.accentColor
                        : delegateItem.isHovered
                            ? ColorUtils.applyAlpha(root.accentColor, 0.5)
                            : ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.5)
                    Behavior on strokeColor {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    strokeWidth: delegateItem.isCurrent ? 2 : 1
                    startX: root.skewExtent; startY: 0
                    PathLine { x: delegateItem.width;                   y: 0 }
                    PathLine { x: delegateItem.width - root.skewExtent; y: delegateItem.height }
                    PathLine { x: 0;                                    y: delegateItem.height }
                    PathLine { x: root.skewExtent;                      y: 0 }
                }
            }

            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.currentImageIndex === delegateItem.index)
                        root.activateCurrent()
                    else
                        root._goToImageIndex(delegateItem.index)
                }
            }
        }
    }

    // ─── Empty folder: a card where the deck would be, pointing at the folders below ───
    Item {
        id: emptyCard
        readonly property bool searching: (Wallpapers.searchQuery ?? "").length > 0
        visible: !root.hasImages
        opacity: root._contentVisible ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration }
        }
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: skewView.verticalCenter }
        width: Math.round(root.expandedCardWidth * 0.62)
        height: Math.round(root.cardHeight * 0.5)

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.badgeSurfaceColor
                strokeColor: "transparent"
                startX: root.skewExtent; startY: 0
                PathLine { x: emptyCard.width;                   y: 0 }
                PathLine { x: emptyCard.width - root.skewExtent; y: emptyCard.height }
                PathLine { x: 0;                                 y: emptyCard.height }
                PathLine { x: root.skewExtent;                   y: 0 }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: emptyCard.searching ? "search_off" : "hide_image"
                iconSize: Appearance.font.pixelSize.huge
                color: root.badgeTextColor
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: emptyCard.searching ? Translation.tr("No wallpapers match")
                    : Translation.tr("No wallpapers in this folder")
                color: root.badgeTextColor
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: emptyCard.searching ? Translation.tr("Esc clears the search")
                    : root.hasFolders ? Translation.tr("Open one of its folders below")
                    : Translation.tr("Go back to a folder below")
                color: root.badgeTextColor
                opacity: 0.75
                font.pixelSize: Appearance.font.pixelSize.small
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // CHROME — slanted plates in the deck's own language:
    // where you are (crumbs), where you can go (subfolders), search, picker switch
    // ═══════════════════════════════════════════════════
    readonly property string _wallpapersDir: `${Directories.picturesPath}/Wallpapers`
    readonly property string _folderPathClean: root._normalizedFilePath(root.currentFolderPath).replace(/\/+$/, "") || "/"

    // Home (or /), at most the last three folders, the current one last
    readonly property var _crumbs: {
        const p = root._folderPathClean
        const home = Directories.homePath.replace(/\/+$/, "")
        const underHome = p === home || p.startsWith(home + "/")
        const base = underHome ? home : ""
        const parts = p.substring(base.length).split("/").filter(s => s.length > 0)
        const out = [{ name: "", icon: underHome ? "home" : "hard_drive", path: base || "/" }]
        const start = Math.max(0, parts.length - 3)
        let acc = base
        for (let i = 0; i < parts.length; i++) {
            acc += "/" + parts[i]
            if (i === start - 1)
                out.push({ name: "…", icon: "", path: acc })
            else if (i >= start)
                out.push({ name: parts[i], icon: "", path: acc })
        }
        return out
    }

    Item {
        id: chrome
        anchors { bottom: parent.bottom; bottomMargin: 28; horizontalCenter: parent.horizontalCenter }
        width: Math.min(root.width - 64, Math.max(root.expandedCardWidth + root.sliceWidth * 2, root.deckWidth - root.sliceWidth * 3))
        height: 36

        opacity: root._contentVisible ? 1 : 0
        transform: Translate {
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

        // ─ Where you are ─
        Row {
            id: crumbRow
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 4

            WallpaperSkewChip {
                visible: root._folderPathClean !== root._wallpapersDir
                icon: "wallpaper"
                onClicked: Wallpapers.setDirectory(root._wallpapersDir)
                StyledToolTip { text: Translation.tr("Wallpapers folder") }
            }

            Repeater {
                model: root._crumbs
                delegate: WallpaperSkewChip {
                    required property var modelData
                    required property int index
                    label: modelData.name
                    icon: modelData.icon
                    active: index === root._crumbs.length - 1
                    onClicked: if (!active) Wallpapers.setDirectory(modelData.path)
                }
            }
        }

        // ─ Where you can go: the subfolders, scrolled sideways ─
        MaterialSymbol {
            id: subfolderMark
            visible: root.hasFolders
            anchors { left: crumbRow.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
            text: "subdirectory_arrow_right"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurface
            opacity: 0.7
        }

        ListView {
            id: subfolderList
            visible: root.hasFolders
            anchors {
                left: subfolderMark.right; leftMargin: 6
                right: rightRow.left; rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            height: parent.height
            orientation: ListView.Horizontal
            spacing: 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root._folderItems
            delegate: WallpaperSkewChip {
                required property var modelData
                muted: true
                icon: "folder"
                label: modelData.name
                onClicked: root.navigateIntoFolder(modelData.path)
            }

            // Sideways scroll here; the deck keeps the wheel everywhere else
            MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: event => {
                    const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    subfolderList.contentX = Math.max(0, Math.min(subfolderList.contentWidth - subfolderList.width,
                        subfolderList.contentX - d))
                }
            }
        }

        // ─ Search and the picker switch ─
        Row {
            id: rightRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 4

            WallpaperSkewChip {
                id: searchChip
                readonly property bool open: root._searchOpen || (Wallpapers.searchQuery ?? "").length > 0
                readonly property int closedWidth: 36 + slant
                readonly property int openWidth: 280
                // 0 → 1 as the plate grows: the glyph slides left and the field fades in behind it
                readonly property real reveal: Math.max(0, Math.min(1, (width - closedWidth) / (openWidth - closedWidth)))
                active: (Wallpapers.searchQuery ?? "").length > 0 && !searchField.activeFocus
                implicitWidth: open ? openWidth : closedWidth
                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                onClicked: {
                    root._searchOpen = true
                    searchField.forceActiveFocus()
                }
                StyledToolTip {
                    text: Translation.tr("Search (/)")
                    extraVisibleCondition: !searchChip.open
                }

                // Own glyph: centred while closed, at the start of the field while open
                MaterialSymbol {
                    id: searchGlyph
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round((parent.width - width) / 2 * (1 - searchChip.reveal)
                        + (searchChip.slant + 12) * searchChip.reveal)
                    text: "search"
                    iconSize: Appearance.font.pixelSize.larger
                    color: searchChip.ink
                }

                TextInput {
                    id: searchField
                    visible: searchChip.reveal > 0
                    opacity: searchChip.reveal
                    anchors {
                        left: searchGlyph.right; leftMargin: 8
                        right: parent.right; rightMargin: searchChip.slant + 12
                        verticalCenter: parent.verticalCenter
                    }
                    clip: true
                    color: searchChip.ink
                    selectionColor: Appearance.colors.colPrimary
                    selectedTextColor: Appearance.colors.colOnPrimary
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    text: Wallpapers.searchQuery
                    onTextChanged: Wallpapers.searchQuery = text
                    onActiveFocusChanged: if (!activeFocus && text.length === 0) root._searchOpen = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root._closeSearch()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            // Back to the deck with the results; the query stays
                            root.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    StyledText {
                        visible: searchField.text.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Search wallpapers")
                        color: searchChip.ink
                        opacity: 0.6
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }

            Item { width: 12; height: 1 }

            Repeater {
                model: [
                    { name: Translation.tr("Skew"), icon: "view_week", view: "skew" },
                    { name: Translation.tr("Gallery"), icon: "view_carousel", view: "gallery" },
                    { name: Translation.tr("Grid"), icon: "grid_view", view: "grid" }
                ]
                delegate: WallpaperSkewChip {
                    required property var modelData
                    icon: modelData.icon
                    label: modelData.name
                    active: modelData.view === "skew"
                    onClicked: {
                        if (modelData.view === "gallery") root.switchToGalleryRequested()
                        else if (modelData.view === "grid") root.switchToGridRequested()
                    }
                }
            }
        }
    }
}
