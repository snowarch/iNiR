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
    signal switchToSkewRequested()

    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property bool hasItems: totalCount > 0
    readonly property string currentFolderPath: String(folderModel?.folder ?? "")
    readonly property string currentFolderName: FileUtils.folderNameForPath(currentFolderPath)
    readonly property bool canGoBack: (folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (folderModel?.currentFolderHistoryIndex ?? 0) < ((folderModel?.folderHistory?.length ?? 0) - 1)
    readonly property real pageMargin: Math.max(22, Math.round(width * 0.022))
    readonly property real topInset: Math.max(72, Math.round(height * 0.12))
    readonly property real bottomInset: Math.max(132, Math.round(height * 0.22))
    readonly property real heroWidth: Math.min(width * 0.44, 860)
    readonly property real heroHeight: Math.round(heroWidth * 0.60)
    readonly property real sideCardWidth: Math.max(180, Math.min(heroWidth * 0.42, 340))
    readonly property real sideCardHeight: Math.round(sideCardWidth * 0.64)
    readonly property real filmstripHeight: Math.max(112, Math.min(height * 0.18, 164))
    readonly property real panelRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
        : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
        : Appearance.rounding.large
    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color elevatedColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer2
    readonly property color baseColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer0
    readonly property color textColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color subtleTextColor: Appearance.angelEverywhere ? Appearance.angel.colTextMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextMuted
        : Appearance.colors.colSubtext
    readonly property color borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.55)
    readonly property string helperText: searchField.activeFocus
        ? Translation.tr("Type to filter this folder")
        : previewMode
            ? Translation.tr("Preview mode")
            : Translation.tr("Arrows, wheel or click to navigate")

    property string _lastThumbnailSizeName: "x-large"
    readonly property string _filmstripThumbnailSizeName: Images.thumbnailSizeNameForDimensions(
        Math.round((root.previewMode ? 108 : 132) * root._dpr * 1.2),
        Math.round(root.filmstripHeight * root._dpr * 1.2)
    )
    property int currentIndex: 0
    property bool previewMode: false
    property bool showKeyboardGuide: true
    property bool _initialized: false
    property int _hoveredIndex: -1
    property int _wheelAccum: 0
    property real _focusPulse: 0
    property int _activeColorReloadToken: 0
    property int _activePreviewReloadToken: 0

    readonly property string activePath: hasItems ? _filePath(currentIndex) : ""
    readonly property string activeName: hasItems ? _fileName(currentIndex) : ""
    readonly property bool activeIsDir: hasItems ? _fileIsDir(currentIndex) : false
    readonly property string normalizedCurrentWallpaperPath: FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
    readonly property bool activeMatchesCurrentWallpaper: activePath.length > 0 && FileUtils.trimFileProtocol(activePath) === normalizedCurrentWallpaperPath
    readonly property string activeDisplayName: !hasItems ? ""
        : activeIsDir ? FileUtils.folderNameForPath(activePath) : FileUtils.fileNameForPath(activePath)
    readonly property string activeKind: _mediaKind(activeName, activeIsDir)
    readonly property string activePreviewSource: {
        if (!hasItems || activePath.length === 0 || activeIsDir)
            return ""
        const thumbPath = Wallpapers.getExpectedThumbnailPath(activePath, _lastThumbnailSizeName)
        if (thumbPath.length === 0)
            return ""
        const thumbUrl = thumbPath.startsWith("file://") ? thumbPath : ("file://" + thumbPath)
        return thumbUrl + (thumbUrl.indexOf("?") >= 0 ? "&" : "?")
            + "hero=" + encodeURIComponent(activePath)
            + "&index=" + currentIndex
            + "&reload=" + _activePreviewReloadToken
    }
    readonly property string activeColorSource: {
        if (!hasItems || activePath.length === 0 || activeIsDir)
            return ""
        if (activeKind === "video" || activeKind === "gif") {
            const thumbPath = Wallpapers.getExpectedThumbnailPath(activePath, _lastThumbnailSizeName)
            if (thumbPath.length > 0)
                return thumbPath.startsWith("file://") ? thumbPath : ("file://" + thumbPath)
        }
        return activePath.startsWith("file://") ? activePath : ("file://" + activePath)
    }
    readonly property string activeQuantizerSource: {
        const base = activeColorSource
        if (!hasItems || activePath.length === 0 || activeIsDir || base.length === 0)
            return ""
        return base + (base.indexOf("?") >= 0 ? "&" : "?")
            + "coverflowQuant=" + encodeURIComponent(activePath)
            + "&index=" + currentIndex
            + "&size=" + _lastThumbnailSizeName
            + "&reload=" + _activeColorReloadToken
    }
    readonly property string activeSubtitle: {
        if (!hasItems) return Translation.tr("No wallpapers in this folder")
        if (activeIsDir) return Translation.tr("Open folder")
        if (activeMatchesCurrentWallpaper) return Translation.tr("Current wallpaper")
        if (activeKind === "gif") return Translation.tr("Animated image")
        if (activeKind === "video") return Translation.tr("Video wallpaper")
        return Translation.tr("Ready to apply")
    }

    function _filePath(index) {
        return (index >= 0 && index < totalCount) ? String(folderModel.get(index, "filePath") ?? "") : ""
    }

    function _fileName(index) {
        return (index >= 0 && index < totalCount) ? String(folderModel.get(index, "fileName") ?? "") : ""
    }

    function _fileIsDir(index) {
        return (index >= 0 && index < totalCount) ? Boolean(folderModel.get(index, "fileIsDir") ?? false) : false
    }

    function _fileUrl(index) {
        return (index >= 0 && index < totalCount) ? (folderModel.get(index, "fileUrl") ?? "") : ""
    }

    function _mediaKind(fileName, isDir) {
        if (isDir) return "folder"
        const lower = String(fileName ?? "").toLowerCase()
        if (lower.endsWith(".gif")) return "gif"
        if (lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov"))
            return "video"
        return "image"
    }

    function _indexKind(index) {
        return _mediaKind(_fileName(index), _fileIsDir(index))
    }

    function _kindLabel(kind, isDir) {
        if (isDir) return Translation.tr("Folder")
        if (kind === "gif") return Translation.tr("GIF")
        if (kind === "video") return Translation.tr("Video")
        return Translation.tr("Wallpaper")
    }

    function _kindIcon(kind, isDir) {
        if (isDir) return "folder"
        if (kind === "gif") return "gif_box"
        if (kind === "video") return "play_circle"
        return "image"
    }

    function _kindColor(kind, isDir) {
        if (isDir) return Appearance.colors.colSecondary
        if (kind === "gif") return Appearance.colors.colTertiary
        if (kind === "video") return Appearance.colors.colError
        return root._accent
    }

    function updateThumbnails() {
        const width = Math.round(heroWidth * _dpr * 2)
        const height = Math.round(heroHeight * _dpr * 2)
        let sizeName = Images.thumbnailSizeNameForDimensions(width, height)
        if (sizeName === "normal" || sizeName === "large")
            sizeName = "x-large"
        _lastThumbnailSizeName = sizeName
        Wallpapers.generateThumbnail(_lastThumbnailSizeName)
        _prefetchAroundIndex(currentIndex)
    }

    function _prefetchAroundIndex(centerIndex) {
        if (!hasItems)
            return
        const radius = previewMode ? 4 : 8
        for (let offset = 0; offset <= radius; offset++) {
            const leftIndex = centerIndex - offset
            const rightIndex = offset === 0 ? -1 : centerIndex + offset
            if (leftIndex >= 0)
                _prefetchIndex(leftIndex)
            if (rightIndex >= 0 && rightIndex < totalCount)
                _prefetchIndex(rightIndex)
        }
    }

    function _prefetchIndex(index) {
        if (index < 0 || index >= totalCount)
            return
        if (_fileIsDir(index))
            return
        const filePath = _filePath(index)
        if (!filePath || filePath.length === 0)
            return
        Wallpapers.ensureThumbnailForPath(filePath, _lastThumbnailSizeName)
    }


    function _syncToCurrentWallpaper(forceReset = false) {
        if (!hasItems) {
            currentIndex = 0
            _initialized = true
            return
        }
        if (_initialized && !forceReset) return
        const targetPath = FileUtils.trimFileProtocol(String(currentWallpaperPath ?? ""))
        for (let i = 0; i < totalCount; i++) {
            if (FileUtils.trimFileProtocol(_filePath(i)) === targetPath) {
                currentIndex = i
                // Explicit position for initial layout
                if (filmstripView)
                    filmstripView.positionViewAtIndex(i, ListView.Center)
                _initialized = true
                return
            }
        }
        currentIndex = Math.max(0, Math.min(currentIndex, totalCount - 1))
        _initialized = true
    }

    function _goToIndex(index) {
        if (!hasItems) return
        const bounded = Math.max(0, Math.min(totalCount - 1, index))
        if (bounded === currentIndex) return
        currentIndex = bounded
        showKeyboardGuide = false
        _prefetchAroundIndex(currentIndex)
        if (Appearance.animationsEnabled)
            focusPulseAnim.restart()
    }

    function moveSelection(delta) {
        _goToIndex(currentIndex + delta)
    }

    function activateCurrent() {
        if (!hasItems) return
        const path = _filePath(currentIndex)
        if (!path || path.length === 0) return
        showKeyboardGuide = false
        if (_fileIsDir(currentIndex))
            directorySelected(path)
        else
            wallpaperSelected(path)
    }

    Timer {
        id: thumbnailDebounce
        interval: 180
        repeat: false
        onTriggered: root.updateThumbnails()
    }

    SequentialAnimation {
        id: focusPulseAnim
        running: false
        NumberAnimation {
            target: root
            property: "_focusPulse"
            to: 1
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.45)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
        NumberAnimation {
            target: root
            property: "_focusPulse"
            to: 0
            duration: Math.max(1, Appearance.animation.clickBounce.duration * 0.8)
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    property string _debouncedQuantizerSource: ""
    Timer {
        id: quantizerDebounce
        interval: 280
        onTriggered: root._debouncedQuantizerSource = root.activeQuantizerSource
    }
    onActiveQuantizerSourceChanged: quantizerDebounce.restart()

    ColorQuantizer {
        id: quantizer
        source: root._debouncedQuantizerSource
        depth: 0
        rescaleSize: 10
    }

    readonly property color dominantColor: quantizer?.colors?.[0] ?? Appearance.colors.colPrimary
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.dominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
    }
    readonly property color accentColor: {
        if (activeIsDir || activePath.length === 0)
            return Appearance.colors.colPrimary
        return blendedColors?.colPrimary ?? dominantColor
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

    Component.onCompleted: {
        _syncToCurrentWallpaper()
        updateThumbnails()
    }

    onCurrentIndexChanged: _prefetchAroundIndex(currentIndex)

    onCurrentWallpaperPathChanged: {
        _initialized = false
        _syncToCurrentWallpaper(true)
    }
    // filmstrip auto-centers via StrictlyEnforceRange — no manual positioning needed
    onHeroWidthChanged: thumbnailDebounce.restart()
    onHeroHeightChanged: thumbnailDebounce.restart()

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            root.previewMode = false
            root.showKeyboardGuide = true
            thumbnailDebounce.restart()
        }
        function onThumbnailGeneratedFile(filePath) {
            if (FileUtils.trimFileProtocol(String(filePath ?? "")) === FileUtils.trimFileProtocol(root.activePath)) {
                root._activePreviewReloadToken += 1
                root._activeColorReloadToken += 1
            }
        }
    }

    Connections {
        target: root.folderModel
        function onCountChanged() {
            root._initialized = false
            root._syncToCurrentWallpaper(true)
            // Defensive: re-trigger hero crossfade after model reload
            // (activePreviewSource might not emit changed if the value is the same)
            if (heroClipContent && root.activePreviewSource.length > 0)
                heroClipContent._crossfadeTo(root.activePreviewSource)
        }
        function onFolderChanged() {
            root._initialized = false
            root.currentIndex = 0
            root._syncToCurrentWallpaper(true)
            thumbnailDebounce.restart()
        }
    }

    Keys.onPressed: event => {
        const alt = (event.modifiers & Qt.AltModifier) !== 0
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0

        if (event.key === Qt.Key_Space && !searchField.activeFocus) {
            root.previewMode = !root.previewMode
            root.showKeyboardGuide = false
            event.accepted = true
            return
        }

        if (!searchField.activeFocus && (event.key === Qt.Key_Slash || (ctrl && event.key === Qt.Key_F))) {
            root.showKeyboardGuide = false
            searchField.forceActiveFocus()
            event.accepted = true
            return
        }

        if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
                if ((Wallpapers.searchQuery ?? "").length > 0)
                    Wallpapers.searchQuery = ""
                else {
                    searchField.focus = false
                    root.forceActiveFocus()
                }
                event.accepted = true
            }
            return
        }

        switch (event.key) {
        case Qt.Key_Escape:
            if (root.previewMode)
                root.previewMode = false
            else
                root.closeRequested()
            break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 5 : 1))
            break
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 5 : 1)
            break
        case Qt.Key_Up:
            if (alt || ctrl) Wallpapers.navigateUp()
            else root.moveSelection(-4)
            break
        case Qt.Key_Down:
            root.moveSelection(4)
            break
        case Qt.Key_PageUp:
            root.moveSelection(-8)
            break
        case Qt.Key_PageDown:
            root.moveSelection(8)
            break
        case Qt.Key_Home:
            root._goToIndex(0)
            break
        case Qt.Key_End:
            root._goToIndex(root.totalCount - 1)
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.activateCurrent()
            break
        case Qt.Key_Backspace:
            if (alt || ctrl) Wallpapers.navigateUp()
            else event.accepted = false
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
            root.showKeyboardGuide = false
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            root._wheelAccum += delta
            const steps = root._wheelAccum >= 0 ? Math.floor(root._wheelAccum / 120) : Math.ceil(root._wheelAccum / 120)
            if (steps !== 0) {
                root._wheelAccum -= steps * 120
                root.moveSelection(-steps)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton
        z: -1
        onClicked: {
            if (root.previewMode)
                root.previewMode = false
            else
                root.closeRequested()
        }
        onPressed: event => {
            if (event.button === Qt.BackButton)
                Wallpapers.navigateBack()
            else if (event.button === Qt.ForwardButton)
                Wallpapers.navigateForward()
            else
                event.accepted = false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.applyAlpha(root.baseColor, root.previewMode ? 0.05 : 0.14)
    }

    GE.RadialGradient {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(root._accent, root.previewMode ? 0.09 : 0.14) }
            GradientStop { position: 0.45; color: ColorUtils.applyAlpha(root._accent, 0.045) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: root.previewMode ? 0.25 : 0.48
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.10) }
            GradientStop { position: 0.5; color: "transparent" }
            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.24) }
        }
    }

    GlassBackground {
        id: topPill
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: root.pageMargin
        }
        width: Math.min(parent.width * 0.38, Math.max(260, topRow.implicitWidth + 24))
        height: topRow.implicitHeight + 18
        visible: !root.previewMode
        opacity: visible ? 1.0 : 0.0
        screenX: { const p = topPill.mapToGlobal(0, 0); return p.x }
        screenY: { const p = topPill.mapToGlobal(0, 0); return p.y }
        radius: Appearance.rounding.full
        fallbackColor: root.surfaceColor
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
        border.color: root.borderColor
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        RowLayout {
            id: topRow
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {
                implicitWidth: mediaPillLabel.implicitWidth + 28
                implicitHeight: mediaPillLabel.implicitHeight + 10
                radius: height / 2
                color: ColorUtils.applyAlpha(root._kindColor(root.activeKind, root.activeIsDir), 0.18)
                border.width: 1
                border.color: ColorUtils.applyAlpha(root._kindColor(root.activeKind, root.activeIsDir), 0.45)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: root._kindIcon(root.activeKind, root.activeIsDir)
                        iconSize: Appearance.font.pixelSize.smaller
                        color: root._kindColor(root.activeKind, root.activeIsDir)
                    }

                    StyledText {
                        id: mediaPillLabel
                        text: root._kindLabel(root.activeKind, root.activeIsDir)
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }
                }
            }

            StyledText {
                text: root.hasItems ? "%1 / %2".arg(root.currentIndex + 1).arg(root.totalCount) : "0 / 0"
                color: root.subtleTextColor
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.monospace
            }

            StyledText {
                text: root.currentFolderName
                color: root.subtleTextColor
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }

    Item {
        id: stageArea
        anchors {
            top: parent.top
            topMargin: root.topInset
            left: parent.left
            right: parent.right
            bottom: filmstripPanel.top
            bottomMargin: root.pageMargin
            leftMargin: root.pageMargin
            rightMargin: root.pageMargin
        }

        GlassBackground {
            id: leftInfoPanel
            anchors {
                left: parent.left
                top: parent.top
            }
            width: 0
            height: 0
            visible: false
            opacity: 0.0
            screenX: { const p = leftInfoPanel.mapToGlobal(0, 0); return p.x }
            screenY: { const p = leftInfoPanel.mapToGlobal(0, 0); return p.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor
            Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

            ColumnLayout {
                id: infoColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                StyledText {
                    text: Translation.tr("Selection")
                    color: root.textColor
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.borderColor; opacity: 0.35 }

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeDisplayName.length > 0 ? root.activeDisplayName : Translation.tr("Choose a wallpaper")
                    color: root.textColor
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideMiddle
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeSubtitle
                    color: root.subtleTextColor
                    font.pixelSize: Appearance.font.pixelSize.small
                    wrapMode: Text.Wrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 6

                    StyledText { text: Translation.tr("Folder"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentFolderName.length > 0 ? root.currentFolderName : root.currentFolderPath
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                    }

                    StyledText { text: Translation.tr("Mode"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.useDarkMode ? Translation.tr("Dark") : Translation.tr("Light")
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        horizontalAlignment: Text.AlignRight
                    }

                    StyledText { text: Translation.tr("Items"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                    StyledText {
                        Layout.fillWidth: true
                        text: String(root.totalCount)
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        GlassBackground {
            id: rightActionsPanel
            anchors {
                right: parent.right
                top: parent.top
            }
            width: 0
            height: 0
            visible: false
            opacity: 0.0
            screenX: { const p = rightActionsPanel.mapToGlobal(0, 0); return p.x }
            screenY: { const p = rightActionsPanel.mapToGlobal(0, 0); return p.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor
            Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

            ColumnLayout {
                id: actionsColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                StyledText {
                    text: Translation.tr("Quick actions")
                    color: root.textColor
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.borderColor; opacity: 0.35 }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    buttonRadius: root.panelRadius
                    colBackground: ColorUtils.applyAlpha(root._accent, 0.18)
                    colBackgroundHover: ColorUtils.applyAlpha(root._accent, 0.28)
                    onClicked: root.activateCurrent()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: root.activeIsDir ? "folder_open" : "check_circle"; iconSize: Appearance.font.pixelSize.small; color: root.textColor }
                        StyledText {
                            text: root.activeIsDir ? Translation.tr("Open folder") : Translation.tr("Apply selected")
                            color: root.textColor
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    buttonRadius: root.panelRadius
                    colBackground: ColorUtils.applyAlpha(root.surfaceColor, 0.5)
                    colBackgroundHover: ColorUtils.applyAlpha(root.elevatedColor, 0.72)
                    onClicked: root.previewMode = !root.previewMode

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: root.previewMode ? "close_fullscreen" : "open_in_full"; iconSize: Appearance.font.pixelSize.small; color: root.textColor }
                        StyledText {
                            text: root.previewMode ? Translation.tr("Exit preview") : Translation.tr("Preview")
                            color: root.textColor
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    buttonRadius: root.panelRadius
                    colBackground: ColorUtils.applyAlpha(root.surfaceColor, 0.5)
                    colBackgroundHover: ColorUtils.applyAlpha(root.elevatedColor, 0.72)
                    onClicked: Wallpapers.randomFromCurrentFolder(root.useDarkMode)

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol { text: "shuffle"; iconSize: Appearance.font.pixelSize.small; color: root.textColor }
                        StyledText {
                            text: Translation.tr("Random")
                            color: root.textColor
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }

        Item {
            id: heroStage
            anchors.centerIn: parent
            width: root.previewMode ? Math.min(parent.width * 0.92, root.heroWidth * 1.25) : root.heroWidth
            height: root.previewMode ? Math.min(parent.height * 0.88, root.heroHeight * 1.32) : root.heroHeight

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

            StyledRectangularShadow {
                target: heroCard
                visible: !Appearance.auroraEverywhere
                radius: heroCard.radius
                opacity: root.previewMode ? 0.28 : 0.18
            }

            Rectangle {
                id: heroCard
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"

                Item {
                    id: heroClipContent
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: heroClipContent.width
                            height: heroClipContent.height
                            radius: heroCard.radius
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: heroCard.radius
                        color: root.surfaceColor
                    }

                    Loader {
                        anchors.fill: parent
                        active: root.hasItems && root.activeIsDir
                        sourceComponent: DirectoryIcon {
                            fileModelData: ({
                                filePath: root.activePath,
                                fileName: root.activeName,
                                fileIsDir: root.activeIsDir,
                                fileUrl: root._fileUrl(root.currentIndex)
                            })
                            sourceSize.width: heroCard.width
                            sourceSize.height: heroCard.height
                        }
                    }

                    // ─── Hero crossfade: two images alternate for smooth transitions ───
                    Image {
                        id: heroA
                        anchors.fill: parent
                        visible: opacity > 0.001
                        cache: true
                        asynchronous: true
                        retainWhileLoading: true
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        sourceSize.width: Math.round(heroCard.width * root._dpr)
                        sourceSize.height: Math.round(heroCard.height * root._dpr)
                        property string requestedSource: ""
                        onStatusChanged: heroClipContent._promoteReadySlot(heroA)
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.calcEffectiveDuration(280); easing.type: Easing.OutCubic }
                        }
                    }
                    Image {
                        id: heroB
                        anchors.fill: parent
                        visible: opacity > 0.001
                        cache: true
                        asynchronous: true
                        retainWhileLoading: true
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        sourceSize.width: Math.round(heroCard.width * root._dpr)
                        sourceSize.height: Math.round(heroCard.height * root._dpr)
                        property string requestedSource: ""
                        onStatusChanged: heroClipContent._promoteReadySlot(heroB)
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.calcEffectiveDuration(280); easing.type: Easing.OutCubic }
                        }
                    }

                    // Crossfade controller
                    property bool _heroSlotA: true
                    property string _heroPendingSource: ""
                    readonly property bool _heroShouldShow: root.hasItems && !root.activeIsDir && root.activePreviewSource.length > 0 && Images.isValidMediaByName(root.activeName)

                    function _crossfadeTo(src) {
                        if (!_heroShouldShow) {
                            _heroPendingSource = ""
                            heroA.opacity = 0; heroB.opacity = 0
                            return
                        }
                        _heroPendingSource = src
                        const target = _heroSlotA ? heroB : heroA
                        if (target.requestedSource === src && target.status === Image.Ready) {
                            _showSlot(target)
                            return
                        }
                        target.requestedSource = src
                        target.source = src
                    }

                    function _showSlot(target) {
                        if (target === heroA) {
                            heroA.opacity = 1.0
                            heroB.opacity = 0.0
                            _heroSlotA = true
                        } else {
                            heroB.opacity = 1.0
                            heroA.opacity = 0.0
                            _heroSlotA = false
                        }
                    }

                    function _promoteReadySlot(target) {
                        if (target.status !== Image.Ready)
                            return
                        if (target.requestedSource !== _heroPendingSource)
                            return
                        _showSlot(target)
                    }

                    Connections {
                        target: root
                        function onActivePreviewSourceChanged() {
                            heroClipContent._crossfadeTo(root.activePreviewSource)
                        }
                    }

                    Component.onCompleted: {
                        if (root.activePreviewSource.length > 0)
                            _crossfadeTo(root.activePreviewSource)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: root.baseColor
                        opacity: root.hasItems && root.activeIsDir ? 0.06 : 0
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: heroInfo.implicitHeight + 32
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.38; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.28) }
                            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.82) }
                        }

                        ColumnLayout {
                            id: heroInfo
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                                margins: 16
                            }
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    implicitWidth: kindLabel.implicitWidth + 14
                                    implicitHeight: kindLabel.implicitHeight + 6
                                    radius: height / 2
                                    color: ColorUtils.applyAlpha(root._kindColor(root.activeKind, root.activeIsDir), 0.25)
                                    border.width: 1
                                    border.color: ColorUtils.applyAlpha(root._kindColor(root.activeKind, root.activeIsDir), 0.50)

                                    StyledText {
                                        id: kindLabel
                                        anchors.centerIn: parent
                                        text: root._kindLabel(root.activeKind, root.activeIsDir)
                                        color: Appearance.colors.colOnLayer0
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    visible: root.activeMatchesCurrentWallpaper && !root.activeIsDir
                                    implicitWidth: activeBadge.implicitWidth + 14
                                    implicitHeight: activeBadge.implicitHeight + 6
                                    radius: height / 2
                                    color: ColorUtils.applyAlpha(root._accent, 0.92)

                                    StyledText {
                                        id: activeBadge
                                        anchors.centerIn: parent
                                        text: Translation.tr("Active")
                                        color: ColorUtils.contrastColor(root._accent)
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        layer.enabled: true
                                        layer.effect: GE.DropShadow {
                                            verticalOffset: 1
                                            horizontalOffset: 0
                                            radius: 6
                                            samples: 16
                                            color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.55)
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.activeSubtitle
                                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.88)
                                font.pixelSize: Appearance.font.pixelSize.small
                                maximumLineCount: 1
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    id: heroBorderOverlay
                    anchors.fill: parent
                    radius: heroCard.radius
                    color: "transparent"
                    border.width: 2.5 + root._focusPulse * 0.5
                    border.color: root._accent
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showKeyboardGuide = false
                        root.activateCurrent()
                    }
                }
            }
        }

        Repeater {
            model: 0
            delegate: Item {
                required property int index
                readonly property bool isLeft: index === 0
                readonly property int itemIndex: root.currentIndex + (isLeft ? -1 : 1)
                readonly property bool hasData: itemIndex >= 0 && itemIndex < root.totalCount
                readonly property string filePath: hasData ? root._filePath(itemIndex) : ""
                readonly property string fileName: hasData ? root._fileName(itemIndex) : ""
                readonly property bool fileIsDir: hasData ? root._fileIsDir(itemIndex) : false

                visible: hasData && !root.previewMode
                width: root.sideCardWidth
                height: root.sideCardHeight
                anchors.verticalCenter: heroStage.verticalCenter
                x: isLeft ? Math.max(leftInfoPanel.width + 22, heroStage.x - width * 0.78) : Math.min(parent.width - rightActionsPanel.width - width - 22, heroStage.x + heroStage.width - width * 0.22)
                opacity: 0.74
                scale: 0.94

                Behavior on x { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }
                Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                Behavior on scale { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }

                StyledRectangularShadow {
                    target: sideCard
                    visible: !Appearance.auroraEverywhere
                    radius: sideCard.radius
                    opacity: 0.12
                }

                Rectangle {
                    id: sideCard
                    anchors.fill: parent
                    radius: root.panelRadius
                    color: root.surfaceColor
                    clip: true
                    border.width: 1
                    border.color: root.borderColor

                    Loader {
                        anchors.fill: parent
                        active: fileIsDir
                        sourceComponent: DirectoryIcon {
                            fileModelData: ({
                                filePath: filePath,
                                fileName: fileName,
                                fileIsDir: fileIsDir,
                                fileUrl: root._fileUrl(itemIndex)
                            })
                            sourceSize.width: sideCard.width
                            sourceSize.height: sideCard.height
                        }
                    }

                    ThumbnailImage {
                        anchors.fill: parent
                        visible: !fileIsDir && filePath.length > 0 && Images.isValidMediaByName(fileName)
                        generateThumbnail: true
                        sourcePath: filePath
                        thumbnailSizeName: root._lastThumbnailSizeName
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        clip: true
                        sourceSize.width: Math.round(sideCard.width * root._dpr)
                        sourceSize.height: Math.round(sideCard.height * root._dpr)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: ColorUtils.applyAlpha(root.baseColor, 0.18)
                    }

                    StyledText {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                            margins: 12
                        }
                        text: fileName
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._goToIndex(itemIndex)
                    }
                }
            }
        }
    }

    GlassBackground {
        id: filmstripPanel
        anchors {
            left: parent.left
            right: parent.right
            bottom: toolbarArea.top
            leftMargin: root.pageMargin
            rightMargin: root.pageMargin
            bottomMargin: root.pageMargin
        }
        height: root.previewMode ? Math.max(86, root.filmstripHeight * 0.72) : Math.max(104, root.filmstripHeight * 0.88)
        visible: root.hasItems
        opacity: visible ? 1.0 : 0.0
        screenX: { const p = filmstripPanel.mapToGlobal(0, 0); return p.x }
        screenY: { const p = filmstripPanel.mapToGlobal(0, 0); return p.y }
        radius: root.panelRadius
        fallbackColor: root.surfaceColor
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
        border.color: root.borderColor
        Behavior on height { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }

        ListView {
            id: filmstripView
            anchors.fill: parent
            anchors.margins: Math.round(filmstripPanel.height * 0.08)
            orientation: Qt.Horizontal
            spacing: 10
            clip: true
            model: root.totalCount
            cacheBuffer: 800
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: root.currentIndex

            // ─── Fluid navigation (same pattern as SkewView) ───
            readonly property real _delegateWidth: root.previewMode ? 108 : 132
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width / 2) - (_delegateWidth / 2)
            preferredHighlightEnd: (width / 2) + (_delegateWidth / 2)
            highlightMoveDuration: root._initialized ? Appearance.calcEffectiveDuration(300) : 0
            highlightFollowsCurrentItem: true

            onCurrentIndexChanged: {
                if (currentIndex !== root.currentIndex)
                    root.currentIndex = currentIndex
            }

            delegate: Item {
                required property int index
                readonly property string filePath: root._filePath(index)
                readonly property string fileName: root._fileName(index)
                readonly property bool fileIsDir: root._fileIsDir(index)
                readonly property string mediaKind: root._mediaKind(fileName, fileIsDir)
                readonly property bool isCurrent: ListView.isCurrentItem
                readonly property bool isActive: filePath.length > 0 && FileUtils.trimFileProtocol(filePath) === root.normalizedCurrentWallpaperPath

                // Discrete distance — only changes when currentIndex changes, not per-frame
                readonly property int absDist: Math.abs(index - root.currentIndex)

                width: root.previewMode ? 108 : 132
                height: filmstripView.height
                opacity: isCurrent ? 1.0 : absDist === 1 ? 0.78 : Math.max(0.42, 0.78 - (absDist - 1) * 0.09)

                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                Item {
                    id: thumbCard
                    width: parent.width
                    height: parent.height
                    anchors.centerIn: parent

                    Item {
                        id: thumbClipContent
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: GE.OpacityMask {
                            maskSource: Rectangle {
                                width: thumbClipContent.width
                                height: thumbClipContent.height
                                radius: root.panelRadius
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root.panelRadius
                            color: isCurrent ? root.elevatedColor : root.surfaceColor
                        }

                        Loader {
                            anchors.fill: parent
                            active: fileIsDir
                            sourceComponent: DirectoryIcon {
                                fileModelData: ({
                                    filePath: filePath,
                                    fileName: fileName,
                                    fileIsDir: fileIsDir,
                                    fileUrl: root._fileUrl(index)
                                })
                                sourceSize.width: thumbCard.width
                                sourceSize.height: thumbCard.height
                            }
                        }

                        ThumbnailImage {
                            id: stripThumb
                            anchors.fill: parent
                            visible: !fileIsDir && filePath.length > 0 && Images.isValidMediaByName(fileName)
                            generateThumbnail: true
                            sourcePath: filePath
                            thumbnailSizeName: root._filmstripThumbnailSizeName
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            asynchronous: true
                            retainWhileLoading: true
                            sourceSize.width: Math.round(thumbCard.width * root._dpr)
                            sourceSize.height: Math.round(thumbCard.height * root._dpr)
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: ColorUtils.applyAlpha(root.baseColor, fileIsDir ? 0.08 : 0.02)
                        }

                        Rectangle {
                            visible: isActive && !fileIsDir
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                margins: 6
                            }
                            implicitWidth: currentBadge.implicitWidth + 10
                            implicitHeight: currentBadge.implicitHeight + 5
                            radius: height / 2
                            color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.78)

                            StyledText {
                                id: currentBadge
                                anchors.centerIn: parent
                                text: Translation.tr("Current")
                                color: Appearance.colors.colOnLayer0
                                font.pixelSize: Appearance.font.pixelSize.smaller - 2
                                font.weight: Font.DemiBold
                            }
                        }

                        MaterialSymbol {
                            visible: fileIsDir || mediaKind === "video" || mediaKind === "gif"
                            anchors {
                                left: parent.left
                                top: parent.top
                                margins: 6
                            }
                            text: root._kindIcon(mediaKind, fileIsDir)
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer0
                            layer.enabled: true
                            layer.effect: GE.DropShadow {
                                verticalOffset: 1
                                horizontalOffset: 0
                                radius: 4
                                color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.65)
                            }
                        }
                    }

                    // Border overlay (sits above clip)
                    Rectangle {
                        anchors.fill: parent
                        radius: root.panelRadius
                        color: "transparent"
                        border.width: isCurrent ? 2.0 : isActive ? 1.2 : 0.5
                        border.color: isCurrent ? root._accent : isActive ? ColorUtils.applyAlpha(root._accent, 0.70) : root.borderColor
                        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root._hoveredIndex = index
                        onExited: {
                            if (root._hoveredIndex === index)
                                root._hoveredIndex = -1
                        }
                        onClicked: {
                            root.showKeyboardGuide = false
                            if (root.currentIndex === index)
                                root.activateCurrent()
                            else
                                root._goToIndex(index)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        anchors {
            bottom: toolbarArea.top
            bottomMargin: 12
            horizontalCenter: parent.horizontalCenter
        }
        visible: root.previewMode || root.showKeyboardGuide
        opacity: visible ? 1.0 : 0.0
        z: 220
        radius: height / 2
        color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.72)
        width: hintText.implicitWidth + 24
        height: hintText.implicitHeight + 10
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        StyledText {
            id: hintText
            anchors.centerIn: parent
            text: root.previewMode
                ? Translation.tr("Space to exit preview  ·  Enter to apply")
                : Translation.tr("/ Search  ·  Space Preview  ·  Enter Apply  ·  Esc Close")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
        }
    }

    Toolbar {
        id: toolbarArea
        anchors {
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            bottomMargin: 22
        }
        screenX: { const p = toolbarArea.mapToGlobal(0, 0); return p.x }
        screenY: { const p = toolbarArea.mapToGlobal(0, 0); return p.y }
        opacity: root.previewMode ? 0.0 : 1.0
        scale: root.previewMode ? 0.96 : 1.0
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on scale { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve } }

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
            Layout.maximumWidth: Math.min(root.width * 0.16, 220)
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.textColor
            text: root.currentFolderName
            elide: Text.ElideMiddle
            maximumLineCount: 1
        }

        Rectangle {
            implicitWidth: 1
            implicitHeight: 16
            color: root.borderColor
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
            onClicked: {
                root.showKeyboardGuide = false
                root.previewMode = !root.previewMode
            }
            text: root.previewMode ? "close_fullscreen" : "open_in_full"
            StyledToolTip { text: Translation.tr("Preview (Space)") }
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

        Rectangle {
            implicitWidth: 1
            implicitHeight: 16
            color: root.borderColor
            opacity: 0.2
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToSkewRequested()
            text: "view_array"
            StyledToolTip { text: Translation.tr("Skew view") }
        }
        IconToolbarButton {
            implicitWidth: height
            onClicked: root.switchToGridRequested()
            text: "grid_view"
            StyledToolTip { text: Translation.tr("Switch to grid view") }
        }

        IconToolbarButton {
            implicitWidth: height
            onClicked: root.closeRequested()
            text: "close"
            StyledToolTip { text: Translation.tr("Close") }
        }
    }
}
