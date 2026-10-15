pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell

// Gallery wallpaper selector: the focused wallpaper as a hero card over a soft,
// full-screen copy of itself, a filmstrip below, and the pickers' row of controls.
// Space (or the hero's expand button) clears everything for a sharp full-screen preview.
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
    signal switchToSkewRequested()

    // ═══════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property string currentFolderPath: String(folderModel?.folder ?? "")

    // Model indices of the wallpapers (newest first, as the model lists them) and the subfolders
    property var _imageIndexMap: []
    property var _folderItems: []

    function _rebuildIndexMaps(): void {
        const imgMap = []
        const folders = []
        for (let i = 0; i < totalCount; i++) {
            if (folderModel.get(i, "fileIsDir") ?? false)
                folders.push({ name: folderModel.get(i, "fileName") ?? "", path: folderModel.get(i, "filePath") ?? "" })
            else
                imgMap.push(i)
        }
        _imageIndexMap = imgMap
        _folderItems = folders
    }

    readonly property int imageCount: _imageIndexMap.length
    readonly property bool hasImages: imageCount > 0
    readonly property bool hasFolders: _folderItems.length > 0

    function _filePath(imgIdx: int): string {
        if (imgIdx < 0 || imgIdx >= _imageIndexMap.length) return ""
        return String(folderModel.get(_imageIndexMap[imgIdx], "filePath") ?? "")
    }
    function _fileName(imgIdx: int): string {
        if (imgIdx < 0 || imgIdx >= _imageIndexMap.length) return ""
        return String(folderModel.get(_imageIndexMap[imgIdx], "fileName") ?? "")
    }
    function _mediaKind(name: string): string {
        const l = String(name ?? "").toLowerCase()
        if (l.endsWith(".gif")) return "gif"
        if (l.endsWith(".mp4") || l.endsWith(".webm") || l.endsWith(".mkv") || l.endsWith(".avi") || l.endsWith(".mov")) return "video"
        return "image"
    }

    property int currentIndex: 0
    property bool previewMode: false
    property bool _initialized: false
    property int _wheelAccum: 0

    readonly property string activePath: hasImages ? _filePath(currentIndex) : ""
    readonly property string activeKind: _mediaKind(_fileName(currentIndex))
    readonly property string normalizedCurrentWallpaperPath: FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
    readonly property bool activeIsCurrent: activePath.length > 0
        && FileUtils.trimFileProtocol(activePath) === normalizedCurrentWallpaperPath

    // ─── Rapid-navigation tracking: the previews wait while an arrow is held ───
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

    // ─── Geometry ───
    readonly property real pageMargin: Math.max(24, Math.round(width * 0.025))
    readonly property int thumbHeight: Math.round(Math.max(84, Math.min(height * 0.11, 128)))
    readonly property int thumbWidth: Math.round(thumbHeight * 1.6)
    readonly property int stripWidth: Math.round(Math.min(width - pageMargin * 2, Math.max(heroWidth * 1.5, 1100)))
    readonly property real _heroAreaHeight: Math.max(200, height - pageMargin * 2 - 36 - 28 - thumbHeight * 1.15 - 72)
    readonly property int heroWidth: Math.round(Math.min(width * 0.52, 1000, _heroAreaHeight * 16 / 9))
    readonly property int heroHeight: Math.round(heroWidth * 9 / 16)
    readonly property string _thumbSizeName: Images.thumbnailSizeNameForDimensions(
        Math.round(root.thumbWidth * 1.15 * root._dpr), Math.round(root.thumbHeight * 1.15 * root._dpr))

    // ─── Tokens ───
    readonly property real cardRadius: root.editorial ? Appearance.editorial.radius
        : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
        : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
        : Appearance.rounding.large
    readonly property real thumbRadius: root.editorial ? Appearance.rounding.small
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    readonly property color accentColor: root.editorial ? Appearance.editorial.accent : Appearance.colors.colPrimary
    readonly property color accentInk: root.editorial ? Appearance.editorial.accentInk : Appearance.colors.colOnPrimary
    readonly property color badgeSurfaceColor: root.editorial ? Appearance.editorial.ink
        : ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.9)
    readonly property color badgeTextColor: root.editorial ? Appearance.editorial.paperOnInk
        : Appearance.colors.colOnLayer2

    // ═══════════════════════════════════════════════════
    // NAVIGATION
    // ═══════════════════════════════════════════════════
    function updateThumbnails(): void {
        for (let offset = -10; offset <= 10; offset++) {
            const fp = _filePath(currentIndex + offset)
            if (fp.length === 0) continue
            Wallpapers.ensureThumbnailForPath(fp, root._thumbSizeName)
            if (_mediaKind(fp) === "video")
                Wallpapers.ensureVideoFirstFrame(fp)
        }
    }

    function _syncToCurrentWallpaper(): void {
        if (!hasImages) {
            currentIndex = 0
            _initialized = true
            return
        }
        let target = -1
        for (let i = 0; i < imageCount; i++) {
            if (FileUtils.trimFileProtocol(_filePath(i)) === normalizedCurrentWallpaperPath) {
                target = i
                break
            }
        }
        _initialized = false
        currentIndex = target >= 0 ? target : Math.max(0, Math.min(currentIndex, imageCount - 1))
        filmstripView.positionViewAtIndex(currentIndex, ListView.Center)
        _initialized = true
    }

    function _goToIndex(index: int): void {
        if (!hasImages) return
        const bounded = Math.max(0, Math.min(imageCount - 1, index))
        if (bounded === currentIndex) return
        _rapidNavSteps++
        if (_rapidNavSteps >= 3) _rapidNavigation = true
        rapidNavCooldown.restart()
        currentIndex = bounded
    }

    function moveSelection(delta: int): void {
        _goToIndex(currentIndex + delta)
    }

    function activateCurrent(): void {
        if (activePath.length > 0)
            wallpaperSelected(activePath)
    }

    onCurrentIndexChanged: thumbnailDebounce.restart()
    onTotalCountChanged: {
        _rebuildIndexMaps()
        _syncToCurrentWallpaper()
        thumbnailDebounce.restart()
    }
    onCurrentWallpaperPathChanged: _syncToCurrentWallpaper()

    Timer {
        id: thumbnailDebounce
        interval: 120
        onTriggered: root.updateThumbnails()
    }

    Component.onCompleted: {
        _rebuildIndexMaps()
        _syncToCurrentWallpaper()
        updateThumbnails()
        forceActiveFocus()
    }

    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root.previewMode = false
            root.currentIndex = 0
            root._rebuildIndexMaps()
            root._syncToCurrentWallpaper()
        }
    }

    // `inir wallpaperSelector move <n>` drives the filmstrip like the arrow keys
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

        if (event.key === Qt.Key_Slash || (ctrl && event.key === Qt.Key_F)) {
            root.previewMode = false
            chrome.openSearch()
            event.accepted = true
            return
        }

        switch (event.key) {
        case Qt.Key_Space:
            if (root.hasImages) root.previewMode = !root.previewMode
            break
        case Qt.Key_Escape:
            if (root.previewMode) root.previewMode = false
            else if (chrome.searching) chrome.closeSearch()
            else root.closeRequested()
            break
        case Qt.Key_Left: case Qt.Key_H:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 5 : 1))
            break
        case Qt.Key_Right: case Qt.Key_L:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 5 : 1)
            break
        case Qt.Key_Up:
            if (alt || ctrl) Wallpapers.navigateUp()
            else root.moveSelection(-5)
            break
        case Qt.Key_Down:
            if (alt || ctrl) { if (root.hasFolders) root.directorySelected(root._folderItems[0].path) }
            else root.moveSelection(5)
            break
        case Qt.Key_PageUp:
            root.moveSelection(-8); break
        case Qt.Key_PageDown:
            root.moveSelection(8); break
        case Qt.Key_Home:
            root._goToIndex(0); break
        case Qt.Key_End:
            root._goToIndex(root.imageCount - 1); break
        case Qt.Key_Return: case Qt.Key_Enter:
            root.activateCurrent(); break
        case Qt.Key_Backspace:
            if (alt || ctrl) Wallpapers.navigateUp()
            else { event.accepted = false; return }
            break
        default:
            event.accepted = false
            return
        }
        event.accepted = true
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            root._wheelAccum += d
            const threshold = Math.abs(d) < 60 ? 40 : 120
            const steps = root._wheelAccum >= 0 ? Math.floor(root._wheelAccum / threshold) : Math.ceil(root._wheelAccum / threshold)
            if (steps !== 0) {
                root._wheelAccum -= steps * threshold
                root.moveSelection(-steps)
            }
        }
    }

    // A click on the empty preview leaves preview mode, or closes the picker
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
        onPressed: event => {
            if (event.button === Qt.BackButton) Wallpapers.navigateBack()
            else if (event.button === Qt.ForwardButton) Wallpapers.navigateForward()
        }
        onClicked: event => {
            if (event.button !== Qt.LeftButton) return
            if (root.previewMode) root.previewMode = false
            else root.closeRequested()
        }
    }

    // ═══════════════════════════════════════════════════
    // BACKDROP — the focused wallpaper: soft behind the hero, sharp in preview
    // ═══════════════════════════════════════════════════
    WallpaperPickerBackdrop {
        anchors.fill: parent
        z: -1
        path: root.activePath
        rapid: root._rapidNavigation
        blurAmount: root.previewMode ? 0 : 1
        bottomShade: root.previewMode ? 0 : 0.62
        Behavior on blurAmount {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // HERO
    // ═══════════════════════════════════════════════════
    Item {
        id: hero
        visible: root.hasImages && opacity > 0
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.top
            // Centred between the top margin and the filmstrip
            verticalCenterOffset: Math.round((root.pageMargin + filmstripView.y) / 2)
        }
        width: root.heroWidth
        height: root.heroHeight
        opacity: root.previewMode ? 0 : 1
        scale: root.previewMode ? 1.04 : 1
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        StyledRectangularShadow {
            target: heroImage
            visible: !root.editorial && !Appearance.auroraEverywhere
            radius: root.cardRadius
        }

        // The same crossfading preview, at hero size, rounded by a smooth mask
        WallpaperPickerBackdrop {
            id: heroImage
            anchors.fill: parent
            path: root.activePath
            rapid: root._rapidNavigation
            bottomShade: 0
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: heroMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
        }

        Rectangle {
            id: heroMask
            anchors.fill: parent
            radius: root.cardRadius
            visible: false
            layer.enabled: true
        }

        // Edge: the accent, as on the strip's current thumbnail
        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: "transparent"
            border.width: 2
            border.color: root.accentColor
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activateCurrent()
        }

        // ── Video/GIF ──
        Rectangle {
            visible: root.activeKind !== "image"
            anchors { top: parent.top; right: parent.right; margins: 14 }
            width: kindRow.implicitWidth + 16
            height: 28
            radius: root.editorial ? Appearance.rounding.small : height / 2
            color: root.badgeSurfaceColor
            Row {
                id: kindRow
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.activeKind === "video" ? "play_arrow" : "gif"
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.badgeTextColor
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.activeKind === "video" ? Translation.tr("Video") : "GIF"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: root.badgeTextColor
                }
            }
        }

        // ── Full-screen preview ──
        RippleButton {
            anchors { top: parent.top; left: parent.left; margins: 14 }
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: root.editorial ? Appearance.rounding.small : height / 2
            colBackground: root.badgeSurfaceColor
            onClicked: root.previewMode = true
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "open_in_full"
                iconSize: Appearance.font.pixelSize.larger
                color: root.badgeTextColor
            }
            StyledToolTip { text: Translation.tr("Preview full screen (Space)") }
        }

        // ── The wallpaper in use ──
        Rectangle {
            visible: root.activeIsCurrent
            anchors { bottom: parent.bottom; right: parent.right; margins: 14 }
            width: 28; height: 28
            radius: root.editorial ? Appearance.rounding.small : height / 2
            color: root.accentColor
            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: Appearance.font.pixelSize.larger
                color: root.accentInk
            }
        }
    }

    // ─── Empty folder ───
    Rectangle {
        id: emptyCard
        readonly property bool searching: (Wallpapers.searchQuery ?? "").length > 0
        visible: !root.hasImages
        anchors.centerIn: parent
        width: Math.round(root.heroWidth * 0.62)
        height: Math.round(root.heroHeight * 0.45)
        radius: root.cardRadius
        color: root.badgeSurfaceColor

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
    // FILMSTRIP
    // ═══════════════════════════════════════════════════
    ListView {
        id: filmstripView
        anchors {
            bottom: chrome.top
            bottomMargin: 28
            horizontalCenter: parent.horizontalCenter
        }
        width: root.stripWidth
        height: Math.round(root.thumbHeight * 1.15)
        orientation: ListView.Horizontal
        spacing: 12
        clip: false
        model: root.imageCount
        cacheBuffer: root.thumbWidth * 6
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.imageCount > 0 ? Math.max(0, Math.min(root.currentIndex, root.imageCount - 1)) : -1

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - root.thumbWidth) / 2
        preferredHighlightEnd: (width + root.thumbWidth) / 2
        highlightMoveDuration: !root._initialized ? 0
            : root._rapidNavigation ? Appearance.animation.elementMoveFast.duration
            : Appearance.animation.elementResize.duration
        highlightFollowsCurrentItem: true
        header: Item { width: (filmstripView.width - root.thumbWidth) / 2; height: 1 }
        footer: Item { width: (filmstripView.width - root.thumbWidth) / 2; height: 1 }

        opacity: root.previewMode ? 0 : 1
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== root.currentIndex)
                root.currentIndex = currentIndex
        }

        delegate: Item {
            id: thumb
            required property int index
            readonly property string filePath: root._filePath(index)
            readonly property string mediaKind: root._mediaKind(root._fileName(index))
            readonly property bool isCurrent: ListView.isCurrentItem
            readonly property bool isActive: filePath.length > 0
                && FileUtils.trimFileProtocol(filePath) === root.normalizedCurrentWallpaperPath
            readonly property bool hovered: thumbMouse.containsMouse

            width: root.thumbWidth
            height: filmstripView.height

            // Thumbnails fade toward the strip's ends
            readonly property real _center: x - filmstripView.contentX + width / 2
            readonly property real _edge: Math.min(_center, filmstripView.width - _center) / (root.thumbWidth * 1.5)
            opacity: isCurrent ? 1 : Math.round(Math.max(0, Math.min(1, _edge)) * 20) / 20 * (hovered ? 1 : 0.8)

            Item {
                id: thumbFace
                anchors.centerIn: parent
                width: root.thumbWidth
                height: root.thumbHeight
                scale: thumb.isCurrent ? 1.12 : thumb.hovered ? 1.04 : 1
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                Item {
                    id: thumbClip
                    anchors.fill: parent
                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: thumbMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Appearance.colors.colLayer2
                    }

                    ThumbnailImage {
                        visible: thumb.mediaKind !== "video"
                        anchors.fill: parent
                        generateThumbnail: true
                        sourcePath: thumb.filePath
                        thumbnailSizeName: root._thumbSizeName
                        cache: true
                        asynchronous: true
                        retainWhileLoading: true
                        fillMode: Image.PreserveAspectCrop
                        mipmap: true
                        sourceSize.width: Math.round(root.thumbWidth * 1.15 * root._dpr)
                        sourceSize.height: Math.round(root.thumbHeight * 1.15 * root._dpr)
                    }

                    Image {
                        visible: thumb.mediaKind === "video"
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        mipmap: true
                        sourceSize.width: Math.round(root.thumbWidth * 1.15 * root._dpr)
                        sourceSize.height: Math.round(root.thumbHeight * 1.15 * root._dpr)
                        source: {
                            if (!visible) return ""
                            const ff = Wallpapers.videoFirstFrames[thumb.filePath]
                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                        }
                    }
                }

                Rectangle {
                    id: thumbMask
                    anchors.fill: parent
                    radius: root.thumbRadius
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: root.thumbRadius
                    color: "transparent"
                    border.width: thumb.isCurrent ? 2 : 0
                    border.color: root.accentColor
                }

            }

            // Glyphs outside the scaled face (text under a resting scale goes soft), on its scaled bounds
            Item {
                anchors.centerIn: parent
                width: Math.round(root.thumbWidth * thumbFace.scale)
                height: Math.round(root.thumbHeight * thumbFace.scale)

                MaterialSymbol {
                    visible: thumb.mediaKind !== "image"
                    anchors { left: parent.left; top: parent.top; margins: 6 }
                    text: thumb.mediaKind === "video" ? "play_circle" : "gif_box"
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 1
                    color: Appearance.colors.colOnLayer0
                }

                Rectangle {
                    visible: thumb.isActive
                    anchors { right: parent.right; bottom: parent.bottom; margins: 6 }
                    width: 22; height: 22
                    radius: root.editorial ? Appearance.rounding.small : height / 2
                    color: root.accentColor
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "check"
                        iconSize: Appearance.font.pixelSize.normal
                        color: root.accentInk
                    }
                }
            }

            MouseArea {
                id: thumbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (thumb.isCurrent) root.activateCurrent()
                    else root._goToIndex(thumb.index)
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════
    // CHROME — the pickers' row, rounded for the gallery
    // ═══════════════════════════════════════════════════
    WallpaperPickerChrome {
        id: chrome
        anchors { bottom: parent.bottom; bottomMargin: 28; horizontalCenter: parent.horizontalCenter }
        width: Math.min(root.width - root.pageMargin * 2, root.stripWidth)
        slanted: false
        currentView: "gallery"
        folderPath: root.currentFolderPath
        folderItems: root._folderItems
        onFolderRequested: path => Wallpapers.setDirectory(path)
        onFocusReturned: root.forceActiveFocus()
        onViewRequested: view => {
            if (view === "skew") root.switchToSkewRequested()
            else if (view === "grid") root.switchToGridRequested()
        }

        opacity: root.previewMode ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
    }
}
