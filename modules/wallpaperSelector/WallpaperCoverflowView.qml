pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

/**
 * Coverflow wallpaper browser — fullscreen gallery with scaled card layout.
 *
 * Design philosophy:
 *   • NO 3D rotation (QML has no depth buffer — Y-axis rotation looks broken)
 *   • Depth conveyed purely through scale + overlap + opacity + dim
 *   • Center card is dominant (~38% screen width, 16:10 landscape)
 *   • Side cards peek from behind, progressively smaller and dimmer
 *   • Clean gaps — cards breathe, no tight packing
 *   • All 5 styles supported (material/cards/aurora/inir/angel)
 */
Item {
    id: root

    // ═══════════════════════════════════════════════════
    // PUBLIC API
    // ═══════════════════════════════════════════════════
    required property var folderModel
    required property string currentWallpaperPath
    property bool useDarkMode: Appearance.m3colors.darkmode

    signal wallpaperSelected(string filePath)
    signal directorySelected(string dirPath)
    signal closeRequested()
    signal switchToGridRequested()

    // ═══════════════════════════════════════════════════
    // THUMBNAIL MANAGEMENT
    // ═══════════════════════════════════════════════════
    property string _lastThumbnailSizeName: "x-large"
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1
    readonly property int totalCount: folderModel?.count ?? 0
    readonly property bool hasItems: totalCount > 0
    readonly property real stageMargin: Math.max(24, Math.round(width * 0.025))
    readonly property real panelWidth: Math.min(width * 0.24, 360)
    readonly property real sidePeekWidth: Math.min(width * 0.2, 240)
    readonly property real stageWidth: Math.max(320, width - panelWidth - sidePeekWidth * 2 - stageMargin * 4)
    readonly property real cardW: Math.min(stageWidth * 0.58, 720)
    readonly property real cardH: Math.round(cardW * 0.625)
    readonly property int visiblePerSide: Math.max(2, Math.min(4, Math.floor((stageWidth - cardW * 0.75) / Math.max(1, cardW * 0.24))))
    readonly property int slotCount: hasItems ? (1 + visiblePerSide * 2) : 0
    readonly property string currentFolderPath: String(root.folderModel?.folder ?? "")
    readonly property string currentFolderName: FileUtils.folderNameForPath(currentFolderPath)
    readonly property string activePath: hasItems ? _filePath(currentIndex) : ""
    readonly property string activeName: hasItems ? _fileName(currentIndex) : ""
    readonly property bool activeIsDir: hasItems ? _fileIsDir(currentIndex) : false
    readonly property url activeUrl: hasItems ? _fileUrl(currentIndex) : ""
    readonly property string activeQuantizerSource: {
        if (!hasItems || activeIsDir || activePath.length === 0) return ""
        const lower = activeName.toLowerCase()
        const isVideo = lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov")
        const isGif = lower.endsWith(".gif")
        // Always prefer the thumbnail for color quantization — loading the full
        // source image just for accent extraction wastes memory and decode time.
        const thumbPath = Wallpapers.getExpectedThumbnailPath(activePath, root._lastThumbnailSizeName)
        if (thumbPath.length > 0) return "file://" + thumbPath
        // Fall back to the full image only when no thumbnail is available yet.
        if (isVideo || isGif) return ""
        return "file://" + activePath
    }
    readonly property string activeDisplayName: !hasItems ? ""
        : activeIsDir
            ? FileUtils.folderNameForPath(activePath)
            : FileUtils.fileNameForPath(activePath)
    readonly property int imageCount: _countByType(false)
    readonly property int folderCount: _countByType(true)
    readonly property bool canGoBack: (root.folderModel?.currentFolderHistoryIndex ?? 0) > 0
    readonly property bool canGoForward: (root.folderModel?.currentFolderHistoryIndex ?? 0) < ((root.folderModel?.folderHistory?.length ?? 0) - 1)
    readonly property string helperText: searchField.activeFocus
        ? Translation.tr("Type to filter this folder")
        : previewMode
            ? Translation.tr("Preview mode")
            : Translation.tr("Arrows, wheel or click to navigate")
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
        : ColorUtils.applyAlpha(Appearance.colors.colOutlineVariant, 0.45)
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
        : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
        : Appearance.rounding.large
    readonly property real panelRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal

    readonly property string _sideThumbnailSizeName: Images.thumbnailSizeNameForDimensions(
        Math.round(root.cardW * root._dpr * 0.9),
        Math.round(root.cardH * root._dpr * 0.9)
    )

    function updateThumbnails() {
        const w = Math.round(root.cardW * root._dpr * 2)
        const h = Math.round(root.cardH * root._dpr * 2)
        let sizeName = Images.thumbnailSizeNameForDimensions(w, h)
        if (sizeName === "normal" || sizeName === "large") sizeName = "x-large"
        root._lastThumbnailSizeName = sizeName
        Wallpapers.generateThumbnail(sizeName)
    }

    Timer {
        id: thumbnailDebounce
        interval: 150
        onTriggered: {
            if (root.totalCount <= 0 || root.cardW <= 8 || root.cardH <= 8) return
            root.updateThumbnails()
        }
    }

    function scaleAt(d) {
        if (d === 0) return 1.0 + root._focusPulse * 0.02
        const a = Math.abs(d)
        return Math.max(0.2, 0.72 * Math.pow(0.78, a - 1))
    }

    function opacityAt(d) {
        if (d === 0) return 1.0
        const a = Math.abs(d)
        return Math.max(0.06, 0.76 * Math.pow(0.7, a - 1))
    }

    function zAt(d) { return 500 - Math.abs(d) * 10 }

    function xOffsetAt(d) {
        if (d === 0) return 0
        const sign = d > 0 ? 1 : -1
        const a = Math.abs(d)
        const baseGap = root.cardW * 0.44
        let offset = baseGap
        for (let i = 2; i <= a; i++) {
            offset += baseGap * scaleAt(i - 1) * 0.78
        }
        return sign * offset
    }

    property int currentIndex: 0
    property bool _initialized: false
    property bool previewMode: false
    property int _hoveredSlot: -999
    property bool showKeyboardGuide: true

    property real _focusPulse: 0
    property int _wheelAccum: 0

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

    ColorQuantizer {
        id: quantizer
        source: root.activeQuantizerSource
        depth: 0
        rescaleSize: 10
    }

    readonly property color accentColor: {
        const c = quantizer?.colors?.[0]
        if (!c || root.activeIsDir || root.activePath.length === 0)
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

    function _filePath(i)  { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "filePath") ?? "")  : "" }
    function _fileName(i)  { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileName") ?? "")  : "" }
    function _fileIsDir(i) { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileIsDir") ?? false) : false }
    function _fileUrl(i)   { return (i >= 0 && i < totalCount) ? (folderModel.get(i, "fileUrl") ?? "")   : "" }
    function _countByType(wantDirs) {
        let count = 0
        for (let i = 0; i < totalCount; i++) {
            if (_fileIsDir(i) === wantDirs) count++
        }
        return count
    }
    function _activeSubtitle() {
        if (!root.hasItems) return Translation.tr("No items in this location")
        if (root.activeIsDir) return Translation.tr("Open folder")
        if (root.activePath === root.currentWallpaperPath) return Translation.tr("Current wallpaper")
        const lower = root.activeName.toLowerCase()
        if (lower.endsWith(".gif")) return Translation.tr("Animated image")
        if (lower.endsWith(".mp4") || lower.endsWith(".webm") || lower.endsWith(".mkv") || lower.endsWith(".avi") || lower.endsWith(".mov"))
            return Translation.tr("Video wallpaper")
        return Translation.tr("Ready to apply")
    }
    function _goToIndex(index) {
        if (!hasItems) return
        const next = Math.max(0, Math.min(totalCount - 1, index))
        if (next === currentIndex) return
        currentIndex = next
        showKeyboardGuide = false
        if (Appearance.animationsEnabled) focusPulseAnim.restart()
    }

    function moveSelection(delta) {
        _goToIndex(currentIndex + delta)
    }

    function activateCurrent() {
        if (totalCount === 0) return
        const fp = _filePath(currentIndex)
        const isDir = _fileIsDir(currentIndex)
        showKeyboardGuide = false
        if (isDir) directorySelected(fp)
        else wallpaperSelected(fp)
    }

    function _scrollToCurrentWallpaper() {
        if (_initialized || totalCount === 0) return
        for (let i = 0; i < totalCount; i++) {
            if (_filePath(i) === currentWallpaperPath) {
                currentIndex = i
                _initialized = true
                return
            }
        }
        _initialized = true
    }

    onTotalCountChanged: _scrollToCurrentWallpaper()
    Component.onCompleted: {
        _scrollToCurrentWallpaper()
        updateThumbnails()
    }
    onCardWChanged: thumbnailDebounce.restart()
    onCardHChanged: thumbnailDebounce.restart()

    Connections {
        target: Wallpapers
        function onDirectoryChanged() {
            previewMode = false
            thumbnailDebounce.restart()
        }
    }
    Connections {
        target: root.folderModel
        function onCountChanged() {}
    }
    Connections {
        target: root.folderModel
        function onFolderChanged() {
            root._initialized = false
            root.currentIndex = 0
            root._scrollToCurrentWallpaper()
            if (Appearance.animationsEnabled) focusPulseAnim.restart()
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
            event.accepted = true; return
        }

        if (root.previewMode) {
            if (event.key === Qt.Key_Escape) { root.previewMode = false; event.accepted = true; return }
            if (event.key === Qt.Key_Left)   { root.moveSelection(-(shift ? 3 : 1)); event.accepted = true; return }
            if (event.key === Qt.Key_Right)  { root.moveSelection(shift ? 3 : 1); event.accepted = true; return }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateCurrent(); root.previewMode = false; event.accepted = true; return
            }
            return
        }

        if (!searchField.activeFocus && (ctrl && event.key === Qt.Key_F || event.key === Qt.Key_Slash)) {
            root.showKeyboardGuide = false
            searchField.forceActiveFocus(); event.accepted = true; return
        }

        if (searchField.activeFocus) {
            if (event.key === Qt.Key_Escape) {
                if (searchField.text.length > 0) Wallpapers.searchQuery = ""
                else { searchField.focus = false; root.forceActiveFocus() }
                event.accepted = true
            }
            return
        }

        switch (event.key) {
        case Qt.Key_Escape:
            root.closeRequested(); break
        case Qt.Key_Left:
            if (alt || ctrl) Wallpapers.navigateBack()
            else root.moveSelection(-(shift ? 3 : 1))
            break
        case Qt.Key_Right:
            if (alt || ctrl) Wallpapers.navigateForward()
            else root.moveSelection(shift ? 3 : 1)
            break
        case Qt.Key_Up:
            if (alt || ctrl) Wallpapers.navigateUp()
            else root.moveSelection(-root.visiblePerSide)
            break
        case Qt.Key_Down:
            root.moveSelection(root.visiblePerSide); break
        case Qt.Key_PageUp:
            root.moveSelection(-root.visiblePerSide); break
        case Qt.Key_PageDown:
            root.moveSelection(root.visiblePerSide); break
        case Qt.Key_Home:
            root.currentIndex = 0
            if (Appearance.animationsEnabled) focusPulseAnim.restart()
            break
        case Qt.Key_End:
            root.currentIndex = Math.max(0, root.totalCount - 1)
            if (Appearance.animationsEnabled) focusPulseAnim.restart()
            break
        case Qt.Key_Return: case Qt.Key_Enter:
            root.activateCurrent(); break
        case Qt.Key_Backspace:
            if (alt || ctrl) Wallpapers.navigateUp()
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
            const steps = root._wheelAccum >= 0
                ? Math.floor(root._wheelAccum / 120)
                : Math.ceil(root._wheelAccum / 120)
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
            if (root.previewMode) root.previewMode = false
            else root.closeRequested()
        }
        onPressed: event => {
            if (event.button === Qt.BackButton) Wallpapers.navigateBack()
            else if (event.button === Qt.ForwardButton) Wallpapers.navigateForward()
            else event.accepted = false
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.applyAlpha(root.baseColor, root.previewMode ? 0.03 : 0.1)
    }

    GE.RadialGradient {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(root._accent, 0.1) }
            GradientStop { position: 0.42; color: ColorUtils.applyAlpha(root._accent, 0.035) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: root.previewMode ? 0.08 : 0.42
    }

    Item {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: toolbarArea.top
            margins: root.stageMargin
            bottomMargin: root.stageMargin * 0.6
        }

        Item {
            id: headerArea
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: headerColumn.implicitHeight
            opacity: root.previewMode ? 0.0 : 1.0
            Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

            ColumnLayout {
                id: headerColumn
                width: parent.width
                spacing: 10

                GlassBackground {
                    id: headerChip
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: headerRow.implicitHeight + 18
                    Layout.preferredWidth: Math.min(parent.width, Math.max(360, headerRow.implicitWidth + 22))
                    screenX: { const m = headerChip.mapToGlobal(0, 0); return m.x }
                    screenY: { const m = headerChip.mapToGlobal(0, 0); return m.y }
                    radius: Appearance.rounding.full
                    fallbackColor: root.surfaceColor
                    inirColor: Appearance.inir.colLayer1
                    auroraTransparency: Appearance.aurora.popupTransparentize
                    border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
                    border.color: root.borderColor

                    RowLayout {
                        id: headerRow
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        MaterialSymbol {
                            text: root.activeIsDir ? "folder" : "image"
                            iconSize: Appearance.font.pixelSize.small
                            color: root._accent
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activeDisplayName.length > 0 ? root.activeDisplayName : Translation.tr("No wallpapers found")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: root.textColor
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                        }

                        StyledText {
                            text: root.hasItems ? "%1 / %2".arg(root.currentIndex + 1).arg(root.totalCount) : "0 / 0"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.monospace
                            color: root.subtleTextColor
                        }
                    }
                }

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(root.cardW * 0.78, 320)
                    Layout.preferredHeight: 3
                    visible: root.totalCount > 1

                    Rectangle {
                        anchors.fill: parent
                        radius: 1.5
                        color: root.borderColor
                        opacity: 0.2
                    }

                    Rectangle {
                        height: parent.height
                        radius: 1.5
                        color: root._accent
                        width: root.totalCount > 1 ? Math.max(10, parent.width / root.totalCount) : parent.width
                        x: root.totalCount > 1 ? (parent.width - width) * (root.currentIndex / (root.totalCount - 1)) : 0
                        Behavior on x {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveEnter.duration
                                easing.type: Appearance.animation.elementMoveEnter.type
                                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: cardArea
            anchors {
                top: headerArea.bottom
                topMargin: 12
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            Repeater {
                model: root.slotCount

                delegate: Item {
                    id: slot
                    required property int index

                    readonly property int offset: index - root.visiblePerSide
                    readonly property int modelIdx: root.currentIndex + offset
                    readonly property bool hasData: modelIdx >= 0 && modelIdx < root.totalCount
                    readonly property string filePath: hasData ? root._filePath(modelIdx) : ""
                    readonly property string fileName: hasData ? root._fileName(modelIdx) : ""
                    readonly property bool fileIsDir: hasData ? root._fileIsDir(modelIdx) : false
                    readonly property url fileUrl: hasData ? root._fileUrl(modelIdx) : ""
                    readonly property bool isCurrent: offset === 0
                    readonly property bool isActive: filePath.length > 0 && filePath === root.currentWallpaperPath
                    readonly property bool isHovered: root._hoveredSlot === offset && !isCurrent
                    readonly property real previewScaleFactor: root.previewMode && isCurrent
                        ? Math.min((root.width * 0.9) / root.cardW, (root.height * 0.84) / root.cardH)
                        : 1.0

                    visible: hasData
                    width: root.cardW
                    height: root.cardH
                    x: cardArea.width / 2 - width / 2 + root.xOffsetAt(offset)
                    y: (cardArea.height - height) / 2 - root._focusPulse * (isCurrent ? 8 : 0)
                    z: root.zAt(offset) + (isHovered ? 5 : 0)
                    scale: root.scaleAt(offset) * (isHovered ? 1.03 : 1.0) * previewScaleFactor
                    opacity: isCurrent ? 1.0 : root.previewMode ? 0.0 : root.opacityAt(offset)

                    Behavior on x {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                    Behavior on y {
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
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    StyledRectangularShadow {
                        target: card
                        visible: !Appearance.auroraEverywhere
                        radius: card.radius
                        opacity: slot.isCurrent ? 0.32 : 0.1
                    }

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: root.cardRadius
                        color: root.surfaceColor
                        clip: true
                        border.width: slot.isCurrent ? 2 : slot.isActive ? 1.5 : slot.isHovered ? 1 : 0.5
                        border.color: slot.isCurrent ? root._accent
                            : slot.isActive ? Appearance.colors.colPrimary
                            : slot.isHovered ? root.borderColor
                            : ColorUtils.applyAlpha(root.borderColor, 0.65)

                        Behavior on border.color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }

                        AngelPartialBorder {
                            targetRadius: card.radius
                            coverage: slot.isCurrent ? 0.62 : slot.isHovered ? 0.45 : 0.3
                            borderColor: slot.isCurrent ? root._accent : slot.isHovered ? Appearance.angel.colBorderHover : Appearance.angel.colBorderSubtle
                        }

                        ThumbnailImage {
                            id: thumb
                            anchors.fill: parent
                            readonly property bool shouldShow: slot.hasData && !slot.fileIsDir && slot.filePath.length > 0 && Images.isValidMediaByName(slot.fileName)
                            visible: shouldShow
                            generateThumbnail: shouldShow
                            sourcePath: shouldShow ? slot.filePath : ""
                            thumbnailSizeName: slot.isCurrent ? root._lastThumbnailSizeName : root._sideThumbnailSizeName
                            cache: true
                            asynchronous: true
                            retainWhileLoading: true
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            mipmap: true
                            sourceSize.width: Math.round(root.cardW * root._dpr * (slot.isCurrent ? 1.5 : 0.8))
                            sourceSize.height: Math.round(root.cardH * root._dpr * (slot.isCurrent ? 1.5 : 0.8))

                            Connections {
                                target: Wallpapers
                                function onThumbnailGenerated(directory) {
                                    if (thumb.status !== Image.Error) return
                                    if (!thumb.sourcePath || thumb.sourcePath.length === 0) return
                                    if (FileUtils.parentDirectory(thumb.sourcePath) !== directory) return
                                    thumb.source = ""
                                    thumb.source = thumb.thumbnailPath
                                }
                                function onThumbnailGeneratedFile(filePath) {
                                    if (thumb.status !== Image.Error) return
                                    if (!thumb.sourcePath || thumb.sourcePath.length === 0) return
                                    if (Qt.resolvedUrl(thumb.sourcePath) !== Qt.resolvedUrl(filePath)) return
                                    thumb.source = ""
                                    thumb.source = thumb.thumbnailPath
                                }
                            }

                            layer.enabled: true
                            layer.effect: GE.OpacityMask {
                                maskSource: Rectangle {
                                    width: thumb.width
                                    height: thumb.height
                                    radius: card.radius
                                }
                            }
                        }

                        Loader {
                            active: slot.hasData && slot.fileIsDir
                            anchors.fill: parent
                            anchors.margins: 1
                            sourceComponent: DirectoryIcon {
                                fileModelData: ({
                                    filePath: slot.filePath,
                                    fileName: slot.fileName,
                                    fileIsDir: slot.fileIsDir,
                                    fileUrl: slot.fileUrl
                                })
                                sourceSize.width: root.cardW
                                sourceSize.height: root.cardH
                            }
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: Math.round(parent.height * 0.34)
                            visible: slot.isCurrent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.28) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: card.radius
                            color: root.baseColor
                            opacity: slot.isCurrent ? 0.0 : slot.isHovered ? 0.04 : Math.min(0.44, 0.1 + Math.abs(slot.offset) * 0.075)
                        }

                        Rectangle {
                            anchors {
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            height: infoStrip.implicitHeight + 20
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.52; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, slot.isCurrent ? 0.2 : 0.5) }
                                GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, slot.isCurrent ? 0.74 : 0.84) }
                            }

                            ColumnLayout {
                                id: infoStrip
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    bottom: parent.bottom
                                    margins: 12
                                }
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: typeLabel.implicitWidth + 12
                                        implicitHeight: typeLabel.implicitHeight + 6
                                        radius: height / 2
                                        color: ColorUtils.applyAlpha(root._accent, 0.18)
                                        border.width: 1
                                        border.color: ColorUtils.applyAlpha(root._accent, 0.38)

                                        StyledText {
                                            id: typeLabel
                                            anchors.centerIn: parent
                                            text: slot.fileIsDir ? Translation.tr("Folder") : Translation.tr("Wallpaper")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnLayer0
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        visible: slot.isActive
                                        implicitWidth: activeBadgeText.implicitWidth + 14
                                        implicitHeight: activeBadgeText.implicitHeight + 6
                                        radius: height / 2
                                        color: ColorUtils.applyAlpha(root._accent, 0.9)

                                        StyledText {
                                            id: activeBadgeText
                                            anchors.centerIn: parent
                                            text: Translation.tr("Active")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.weight: Font.DemiBold
                                            color: ColorUtils.contrastColor(root._accent)
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
                                    text: slot.fileName
                                    font.pixelSize: slot.isCurrent ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                                    font.weight: slot.isCurrent ? Font.DemiBold : Font.Medium
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    visible: slot.isCurrent
                                    text: root._activeSubtitle()
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.84)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: root._hoveredSlot = slot.offset
                            onExited: {
                                if (root._hoveredSlot === slot.offset) root._hoveredSlot = -999
                            }

                            onClicked: {
                                root.showKeyboardGuide = false
                                if (slot.isCurrent) {
                                    if (slot.fileIsDir) root.directorySelected(slot.filePath)
                                    else root.wallpaperSelected(slot.filePath)
                                } else {
                                    root._goToIndex(slot.modelIdx)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(root.stageWidth * 0.74, 520)
                height: emptyColumn.implicitHeight + 28
                radius: root.cardRadius
                color: ColorUtils.applyAlpha(root.surfaceColor, 0.92)
                border.width: 1
                border.color: root.borderColor
                visible: !root.hasItems

                ColumnLayout {
                    id: emptyColumn
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "imagesmode"
                        iconSize: 36
                        color: root._accent
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("No wallpapers found here")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        color: root.textColor
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Try another folder, go up one level, or clear the current search.")
                        font.pixelSize: Appearance.font.pixelSize.small
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        color: root.subtleTextColor
                    }
                }
            }

            Repeater {
                model: 2

                delegate: RippleButton {
                    required property int index
                    readonly property bool isLeft: index === 0

                    anchors {
                        left: isLeft ? parent.left : undefined
                        right: isLeft ? undefined : parent.right
                        leftMargin: 12
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    implicitWidth: 52
                    implicitHeight: 52
                    buttonRadius: 26
                    visible: root.totalCount > 1 && !root.previewMode && (isLeft ? root.currentIndex > 0 : root.currentIndex < root.totalCount - 1)
                    opacity: visible ? 0.9 : 0.0
                    z: 100
                    colBackground: root.surfaceColor
                    colBackgroundHover: root.elevatedColor

                    onClicked: root.moveSelection(isLeft ? -1 : 1)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: isLeft ? "chevron_left" : "chevron_right"
                        iconSize: 26
                        color: root.textColor
                    }

                    StyledRectangularShadow {
                        target: parent
                        visible: !Appearance.auroraEverywhere
                        radius: 26
                        opacity: 0.14
                    }
                }
            }
        }

        GlassBackground {
            id: infoOverlay
            anchors {
                top: headerArea.bottom
                topMargin: 18
                left: parent.left
            }
            width: Math.min(root.width * 0.28, 320)
            height: infoOverlayColumn.implicitHeight + 26
            visible: !root.previewMode
            opacity: visible ? 1.0 : 0.0
            z: 120
            screenX: { const m = infoOverlay.mapToGlobal(0, 0); return m.x }
            screenY: { const m = infoOverlay.mapToGlobal(0, 0); return m.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor

            ColumnLayout {
                id: infoOverlayColumn
                anchors.fill: parent
                anchors.margins: 13
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: root.activeIsDir ? "folder" : "wallpaper"
                        iconSize: Appearance.font.pixelSize.small
                        color: root._accent
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Selection")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.textColor
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.borderColor
                    opacity: 0.35
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.activeDisplayName.length > 0 ? root.activeDisplayName : Translation.tr("Select a wallpaper")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: root.textColor
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideMiddle
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root._activeSubtitle()
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.subtleTextColor
                    wrapMode: Text.Wrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 4

                    StyledText { text: Translation.tr("Folder"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentFolderName.length > 0 ? root.currentFolderName : root.currentFolderPath
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignRight
                    }
                    StyledText { text: Translation.tr("Position"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.hasItems ? "%1 / %2".arg(root.currentIndex + 1).arg(root.totalCount) : "0 / 0"
                        color: root.textColor
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        GlassBackground {
            id: actionsOverlay
            anchors {
                top: headerArea.bottom
                topMargin: 18
                right: parent.right
            }
            width: Math.min(root.width * 0.18, 220)
            height: actionsColumn.implicitHeight + 26
            visible: !root.previewMode
            opacity: visible ? 1.0 : 0.0
            z: 120
            screenX: { const m = actionsOverlay.mapToGlobal(0, 0); return m.x }
            screenY: { const m = actionsOverlay.mapToGlobal(0, 0); return m.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor

            ColumnLayout {
                id: actionsColumn
                anchors.fill: parent
                anchors.margins: 13
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "bolt"
                        iconSize: Appearance.font.pixelSize.small
                        color: root._accent
                    }

                    StyledText {
                        text: Translation.tr("Quick actions")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.textColor
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.borderColor
                    opacity: 0.35
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    buttonRadius: root.panelRadius
                    colBackground: ColorUtils.applyAlpha(root._accent, 0.18)
                    colBackgroundHover: ColorUtils.applyAlpha(root._accent, 0.26)
                    onClicked: root.activateCurrent()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: root.activeIsDir ? "folder_open" : "check_circle"
                            iconSize: Appearance.font.pixelSize.small
                            color: root.textColor
                        }

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

                        MaterialSymbol {
                            text: root.previewMode ? "close_fullscreen" : "open_in_full"
                            iconSize: Appearance.font.pixelSize.small
                            color: root.textColor
                        }

                        StyledText {
                            text: root.previewMode ? Translation.tr("Exit preview") : Translation.tr("Preview")
                            color: root.textColor
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }
            }
        }

        GlassBackground {
            id: guideOverlay
            anchors {
                left: parent.left
                bottom: parent.bottom
                bottomMargin: 10
            }
            width: Math.min(root.width * 0.24, 280)
            height: guideColumn.implicitHeight + 24
            visible: !root.previewMode && root.showKeyboardGuide
            opacity: visible ? 1.0 : 0.0
            z: 120
            screenX: { const m = guideOverlay.mapToGlobal(0, 0); return m.x }
            screenY: { const m = guideOverlay.mapToGlobal(0, 0); return m.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor

            ColumnLayout {
                id: guideColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                StyledText {
                    text: Translation.tr("How to use")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.textColor
                }

                StyledText { text: Translation.tr("Arrows / wheel: navigate"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                StyledText { text: Translation.tr("Enter: apply or open folder"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                StyledText { text: Translation.tr("Space: preview"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
                StyledText { text: Translation.tr("/ or Ctrl+F: search"); color: root.subtleTextColor; font.pixelSize: Appearance.font.pixelSize.smaller }
            }
        }

        GlassBackground {
            id: statusOverlay
            anchors {
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 10
            }
            width: Math.min(root.width * 0.22, 250)
            height: statusColumn.implicitHeight + 24
            visible: !root.previewMode
            opacity: visible ? 1.0 : 0.0
            z: 120
            screenX: { const m = statusOverlay.mapToGlobal(0, 0); return m.x }
            screenY: { const m = statusOverlay.mapToGlobal(0, 0); return m.y }
            radius: root.panelRadius
            fallbackColor: root.surfaceColor
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            border.width: Appearance.inirEverywhere || Appearance.angelEverywhere ? 1 : 0
            border.color: root.borderColor

            ColumnLayout {
                id: statusColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "query_stats"
                        iconSize: Appearance.font.pixelSize.small
                        color: root._accent
                    }

                    StyledText {
                        text: Translation.tr("Selection details")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: root.textColor
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.borderColor
                    opacity: 0.35
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Mode") + ": " + (root.useDarkMode ? Translation.tr("Dark") : Translation.tr("Light"))
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.subtleTextColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Items") + ": " + root.totalCount
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.subtleTextColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Wallpapers.thumbnailGenerationRunning ? Translation.tr("Generating thumbnails…") : Translation.tr("Thumbnails ready")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.subtleTextColor
                    wrapMode: Text.Wrap
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    visible: Wallpapers.thumbnailGenerationRunning && Wallpapers.thumbnailGenerationProgress > 0
                    value: Wallpapers.thumbnailGenerationProgress
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
        width: previewHint.implicitWidth + 24
        height: previewHint.implicitHeight + 10
        Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

        StyledText {
            id: previewHint
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
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 24 }
        screenX: { const m = toolbarArea.mapToGlobal(0, 0); return m.x }
        screenY: { const m = toolbarArea.mapToGlobal(0, 0); return m.y }

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
            onClicked: {
                root.showKeyboardGuide = false
                root.previewMode = !root.previewMode
            }
            text: root.previewMode ? "close_fullscreen" : "open_in_full"
            StyledToolTip { text: Translation.tr("Preview (Space)") }
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
            onActiveFocusChanged: {
                if (activeFocus) root.showKeyboardGuide = false
            }
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
