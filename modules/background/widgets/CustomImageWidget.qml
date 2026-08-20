pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtMultimedia
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.background.widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        sourceMode: "file",
        path: "",
        folder: "",
        mediaFilter: "all",
        intervalSeconds: 30,
        order: "sequential",
        transitionDuration: 450,
        shape: "Cookie4Sided",
        fitMode: "cover",
        size: 220,
        dim: 0,
        widgetScale: 100,
        widgetOpacity: 100,
        x: 120,
        y: 320
    })
    resizableAxes: ({ uniform: "size" })

    readonly property string sourceMode: root._readConfigKey("sourceMode") === "folder" ? "folder" : "file"
    readonly property string mediaPath: String(root._readConfigKey("path") ?? "")
    readonly property string folderPath: String(root._readConfigKey("folder") ?? "")
    readonly property string mediaFilter: {
        const value = String(root._readConfigKey("mediaFilter") ?? "all")
        return ["images", "gifs", "videos"].includes(value) ? value : "all"
    }
    readonly property int intervalSeconds: Math.max(3, Math.min(3600,
        Number(root._readConfigKey("intervalSeconds") ?? 30)))
    readonly property string rotationOrder:
        root._readConfigKey("order") === "random" ? "random" : "sequential"
    readonly property int transitionDuration: Math.max(0, Math.min(2000,
        Number(root._readConfigKey("transitionDuration") ?? 450)))
    readonly property string shapeName: String(root._readConfigKey("shape") ?? "Cookie4Sided")
    readonly property string fitMode:
        root._readConfigKey("fitMode") === "contain" ? "contain" : "cover"
    readonly property real logicalSize: Math.max(80, Number(root._readConfigKey("size") ?? 220))
    readonly property real renderedSize: Math.round(root.logicalSize * root.scaleFactor)
    readonly property int effectiveTransitionDuration: root.animationsActive
        ? Appearance.calcEffectiveDuration(root.transitionDuration) : 0
    property var mediaPaths: []
    property var folderAllPaths: []
    property var folderImagePaths: []
    property var folderGifPaths: []
    property var folderVideoPaths: []
    property int currentIndex: -1
    property bool rotationPaused: false
    property bool mediaPlaybackPaused: false
    property int activeSlot: 0
    property string _pendingSource: ""
    property string currentPath: ""
    readonly property bool currentIsVideo: Images.isValidVideoByName(root.currentPath)
    readonly property bool currentIsAnimatedImage:
        root.currentPath.toLowerCase().endsWith(".gif")
    readonly property int mediaCount: root.sourceMode === "folder"
        ? root.mediaPaths.length : (Images.isValidMediaByName(root.mediaPath) ? 1 : 0)
    readonly property int folderMediaCount: root.folderAllPaths.length
    readonly property int folderImageCount: root.folderImagePaths.length
    readonly property int folderGifCount: root.folderGifPaths.length
    readonly property int folderVideoCount: root.folderVideoPaths.length
    readonly property string currentName: FileUtils.fileNameForPath(root.currentPath)
    readonly property bool activeFailed: root.activeSlot === 0 ? mediaSlotA.failed : mediaSlotB.failed
    readonly property int shapeEnum: root.shapeForName(root.shapeName)
    readonly property string activeSourceChoice:
        root.sourceMode === "file" ? "file" : root.mediaFilter

    property bool dropHover: false

    implicitWidth: root.renderedSize
    implicitHeight: root.renderedSize

    function fileUrl(path: string): string {
        const value = String(path ?? "")
        if (!value) return ""
        return value.startsWith("file:") ? value : "file://" + value
    }

    function activeSlotItem(): var {
        return root.activeSlot === 0 ? mediaSlotA : mediaSlotB
    }

    function inactiveSlotItem(): var {
        return root.activeSlot === 0 ? mediaSlotB : mediaSlotA
    }

    function rebuildMediaPaths(): void {
        const previousPath = root.currentPath
        const all = []
        const images = []
        const gifs = []
        const videos = []
        if (root.folderPath.length > 0 && folderModel.status === FolderListModel.Ready) {
            for (let i = 0; i < folderModel.count; ++i) {
                const path = String(folderModel.get(i, "filePath")
                    || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL")) || "")
                if (!path || !Images.isValidMediaByName(path)) continue
                all.push(path)
                if (Images.isValidVideoByName(path)) {
                    videos.push(path)
                } else if (Images.isValidImageByName(path)) {
                    if (path.toLowerCase().endsWith(".gif")) gifs.push(path)
                    else images.push(path)
                }
            }
        }

        root.folderAllPaths = all
        root.folderImagePaths = images
        root.folderGifPaths = gifs
        root.folderVideoPaths = videos

        let next = all
        if (root.mediaFilter === "images") next = images
        else if (root.mediaFilter === "gifs") next = gifs
        else if (root.mediaFilter === "videos") next = videos

        // Fall back only after the complete folder inventory is ready.
        if (root.sourceMode === "folder" && next.length === 0 && all.length > 0
                && root.mediaFilter !== "all") {
            Qt.callLater(() => Config.setNestedValue(root._configPath + ".mediaFilter", "all"))
            next = all
        }

        root.mediaPaths = next
        if (next.length === 0) {
            root.currentIndex = -1
            if (root.sourceMode === "folder") root.currentPath = ""
            return
        }
        const previousIndex = next.indexOf(previousPath)
        root.currentIndex = previousIndex >= 0
            ? previousIndex
            : (root.rotationOrder === "random" ? Math.floor(Math.random() * next.length) : 0)
        if (root.sourceMode === "folder")
            root.currentPath = String(next[root.currentIndex] ?? "")
    }

    function refreshSelection(): void {
        if (root.sourceMode === "file") {
            root.currentIndex = -1
            root.currentPath = Images.isValidMediaByName(root.mediaPath)
                ? root.mediaPath : ""
            return
        }
        root.rebuildMediaPaths()
    }

    function displayPath(path: string): void {
        const next = String(path ?? "")
        if (!next || !Images.isValidMediaByName(next)) {
            // Keep the previous frame while the new folder is still scanning.
            if (root.sourceMode === "folder" && root.folderPath.length > 0
                    && folderModel.status !== FolderListModel.Ready)
                return
            root._pendingSource = ""
            mediaSlotA.sourcePath = ""
            mediaSlotB.sourcePath = ""
            return
        }

        const active = root.activeSlotItem()
        if (active.sourcePath === next) {
            root._pendingSource = ""
            return
        }

        root._pendingSource = next
        if (!active.sourcePath || root.effectiveTransitionDuration <= 0) {
            const inactive = root.inactiveSlotItem()
            inactive.sourcePath = ""
            active.sourcePath = next
            return
        }

        root.inactiveSlotItem().sourcePath = next
    }

    function slotReady(slotIndex: int, path: string): void {
        if (!root._pendingSource || path !== root._pendingSource) return
        root._pendingSource = ""
        if (slotIndex !== root.activeSlot) {
            root.activeSlot = slotIndex
            staleSlotCleanup.restart()
        }
    }

    function advance(direction: int, randomPick: bool): void {
        const count = root.mediaPaths.length
        if (root.sourceMode !== "folder" || count === 0) return
        if (count === 1) {
            root.currentIndex = 0
            return
        }
        if (randomPick) {
            let next = root.currentIndex
            while (next === root.currentIndex)
                next = Math.floor(Math.random() * count)
            root.currentIndex = next
        } else {
            const current = root.currentIndex >= 0 ? root.currentIndex : 0
            root.currentIndex = (current + direction + count) % count
        }
        root.currentPath = String(root.mediaPaths[root.currentIndex] ?? "")
        rotationTimer.restart()
    }

    function activateSourceChoice(choice: string): void {
        const updates = {}
        if (choice === "file") {
            if (!Images.isValidMediaByName(root.mediaPath)) return
            updates[root._configPath + ".sourceMode"] = "file"
        } else {
            const count = choice === "images" ? root.folderImageCount
                : choice === "gifs" ? root.folderGifCount
                : choice === "videos" ? root.folderVideoCount
                : root.folderMediaCount
            if (count === 0) return
            updates[root._configPath + ".sourceMode"] = "folder"
            updates[root._configPath + ".mediaFilter"] = choice
        }
        root.rotationPaused = false
        root.mediaPlaybackPaused = false
        Config.setNestedValues(updates)
        Qt.callLater(rotationTimer.restart)
    }

    function setInterval(seconds: int): void {
        Config.setNestedValue(root._configPath + ".intervalSeconds",
            Math.max(3, Math.min(3600, seconds)))
        rotationTimer.restart()
    }

    function shapeForName(name: string): int {
        switch (name) {
        case "Circle": return MaterialShape.Shape.Circle;
        case "Square": return MaterialShape.Shape.Square;
        case "Slanted": return MaterialShape.Shape.Slanted;
        case "Arch": return MaterialShape.Shape.Arch;
        case "Fan": return MaterialShape.Shape.Fan;
        case "Arrow": return MaterialShape.Shape.Arrow;
        case "SemiCircle": return MaterialShape.Shape.SemiCircle;
        case "Oval": return MaterialShape.Shape.Oval;
        case "Pill": return MaterialShape.Shape.Pill;
        case "Triangle": return MaterialShape.Shape.Triangle;
        case "Diamond": return MaterialShape.Shape.Diamond;
        case "ClamShell": return MaterialShape.Shape.ClamShell;
        case "Pentagon": return MaterialShape.Shape.Pentagon;
        case "Gem": return MaterialShape.Shape.Gem;
        case "Sunny": return MaterialShape.Shape.Sunny;
        case "VerySunny": return MaterialShape.Shape.VerySunny;
        case "Cookie6Sided": return MaterialShape.Shape.Cookie6Sided;
        case "Cookie7Sided": return MaterialShape.Shape.Cookie7Sided;
        case "Cookie9Sided": return MaterialShape.Shape.Cookie9Sided;
        case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided;
        case "Ghostish": return MaterialShape.Shape.Ghostish;
        case "Clover4Leaf": return MaterialShape.Shape.Clover4Leaf;
        case "Clover8Leaf": return MaterialShape.Shape.Clover8Leaf;
        case "Burst": return MaterialShape.Shape.Burst;
        case "SoftBurst": return MaterialShape.Shape.SoftBurst;
        case "Boom": return MaterialShape.Shape.Boom;
        case "SoftBoom": return MaterialShape.Shape.SoftBoom;
        case "Flower": return MaterialShape.Shape.Flower;
        case "Puffy": return MaterialShape.Shape.Puffy;
        case "PuffyDiamond": return MaterialShape.Shape.PuffyDiamond;
        case "PixelCircle": return MaterialShape.Shape.PixelCircle;
        case "PixelTriangle": return MaterialShape.Shape.PixelTriangle;
        case "Bun": return MaterialShape.Shape.Bun;
        case "Heart": return MaterialShape.Shape.Heart;
        case "Cookie4Sided":
        default: return MaterialShape.Shape.Cookie4Sided;
        }
    }

    function pathFromDropUrl(value: var): string {
        const raw = String(value ?? "");
        try {
            return FileUtils.trimFileProtocol(decodeURIComponent(raw));
        } catch (error) {
            return FileUtils.trimFileProtocol(raw);
        }
    }

    function setMediaPath(path: string): void {
        if (!path || !Images.isValidMediaByName(path))
            return
        const updates = {}
        updates[root._configPath + ".path"] = path
        updates[root._configPath + ".sourceMode"] = "file"
        Config.setNestedValues(updates)
    }

    onCurrentPathChanged: {
        root.displayPath(root.currentPath)
    }
    onMediaFilterChanged: selectionRefreshTimer.restart()
    onSourceModeChanged: selectionRefreshTimer.restart()
    onMediaPathChanged: if (root.sourceMode === "file") selectionRefreshTimer.restart()
    onFolderPathChanged: selectionRefreshTimer.restart()
    Component.onCompleted: selectionRefreshTimer.restart()

    Timer {
        id: selectionRefreshTimer
        interval: 0
        onTriggered: root.refreshSelection()
    }

    FolderListModel {
        id: folderModel
        folder: root.folderPath.length > 0
            ? root.fileUrl(root.folderPath) : ""
        nameFilters: Images.validImageExtensions.concat(Images.validVideoExtensions)
            .map(ext => "*." + ext)
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        sortReversed: false
        onCountChanged: root.rebuildMediaPaths()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildMediaPaths()
        onFolderChanged: Qt.callLater(root.rebuildMediaPaths)
    }

    Timer {
        id: rotationTimer
        interval: root.intervalSeconds * 1000
        repeat: true
        running: root.sourceMode === "folder" && root.mediaPaths.length > 1
            && !root.rotationPaused && root.powerActive && root.visible
        onTriggered: root.advance(1, root.rotationOrder === "random")
    }

    Timer {
        id: staleSlotCleanup
        interval: Math.max(1, root.effectiveTransitionDuration) + 80
        onTriggered: {
            const stale = root.inactiveSlotItem()
            if (root._pendingSource && stale.sourcePath === root._pendingSource) return
            stale.sourcePath = ""
        }
    }

    component MediaSlot: Item {
        id: slot
        required property int slotIndex
        property string sourcePath: ""
        property bool shouldPlay: true
        property bool videoHasFrame: false
        readonly property bool isVideo: Images.isValidVideoByName(slot.sourcePath)
        readonly property bool isAnimatedImage: !slot.isVideo
            && slot.sourcePath.toLowerCase().endsWith(".gif")
        readonly property bool isStaticImage: slot.sourcePath.length > 0
            && !slot.isVideo && !slot.isAnimatedImage
        readonly property bool ready: slot.sourcePath.length > 0
            && (slot.isVideo
                ? slot.videoHasFrame
                : slot.isAnimatedImage
                    ? animatedImage.status === AnimatedImage.Ready
                    : staticImage.status === Image.Ready)
        readonly property bool failed: slot.sourcePath.length > 0
            && (slot.isAnimatedImage
                ? animatedImage.status === AnimatedImage.Error
                : slot.isStaticImage && staticImage.status === Image.Error)

        function syncVideoPlayback(): void {
            if (!slot.isVideo || slot.sourcePath.length === 0) return
            if (slot.shouldPlay && root.powerActive && root.visible) {
                videoPlayer.play()
            } else if (slot.videoHasFrame) {
                videoPlayer.pause()
            } else {
                // Decode one frame before pausing to avoid a black surface.
                videoPlayer.play()
            }
        }

        onSourcePathChanged: {
            slot.videoHasFrame = false
            Qt.callLater(slot.syncVideoPlayback)
        }
        onShouldPlayChanged: slot.syncVideoPlayback()
        onReadyChanged: if (slot.ready) root.slotReady(slot.slotIndex, slot.sourcePath)

        Connections {
            target: root
            function onPowerActiveChanged(): void { slot.syncVideoPlayback() }
            function onVisibleChanged(): void { slot.syncVideoPlayback() }
        }

        StyledImage {
            id: staticImage
            anchors.fill: parent
            visible: slot.isStaticImage
            source: visible ? root.fileUrl(slot.sourcePath) : ""
            fillMode: root.fitMode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            cache: false
            sourceSize.width: Math.max(1, Math.round(width * 2))
            sourceSize.height: Math.max(1, Math.round(height * 2))
        }

        AnimatedImage {
            id: animatedImage
            anchors.fill: parent
            visible: slot.isAnimatedImage
            source: visible ? root.fileUrl(slot.sourcePath) : ""
            fillMode: root.fitMode === "contain" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: slot.shouldPlay && root.powerActive && root.visible
                && Appearance.animationsEnabled
            smooth: true
        }

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            visible: slot.isVideo
            fillMode: root.fitMode === "contain"
                ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
        }

        Connections {
            target: videoOutput.videoSink
            enabled: slot.isVideo && !slot.videoHasFrame
            function onVideoFrameChanged(): void {
                const size = videoOutput.videoSink.videoSize
                if (size.width <= 0 || size.height <= 0) return
                slot.videoHasFrame = true
                if (!slot.shouldPlay || !root.powerActive || !root.visible)
                    slot.syncVideoPlayback()
            }
        }

        MediaPlayer {
            id: videoPlayer
            source: slot.isVideo ? root.fileUrl(slot.sourcePath) : ""
            videoOutput: videoOutput
            loops: MediaPlayer.Infinite
            onSourceChanged: {
                slot.videoHasFrame = false
                Qt.callLater(slot.syncVideoPlayback)
            }
        }
    }

    editPopoverContent: Component {
        Item {
            id: mediaQuickControlsHost
            implicitWidth: Math.max(300,
                Math.min(420, root.scaledScreenWidth - 48))
            implicitHeight: mediaQuickControls.implicitHeight

            ColumnLayout {
                id: mediaQuickControls
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                spacing: 6
                readonly property var sourceChoices: [
                { label: Translation.tr("File"), icon: "draft", value: "file",
                    available: Images.isValidMediaByName(root.mediaPath) },
                { label: Translation.tr("All") + " " + root.folderMediaCount,
                    icon: "perm_media", value: "all", available: root.folderMediaCount > 0 },
                { label: Translation.tr("Images") + " " + root.folderImageCount,
                    icon: "image", value: "images", available: root.folderImageCount > 0 },
                { label: "GIF " + root.folderGifCount,
                    icon: "motion_photos_on", value: "gifs", available: root.folderGifCount > 0 },
                { label: Translation.tr("Videos") + " " + root.folderVideoCount,
                    icon: "movie", value: "videos", available: root.folderVideoCount > 0 }
                ].filter(choice => choice.available)

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: root.currentIsVideo ? "movie" : "photo_library"
                    iconSize: 30
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: 238
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentName.length > 0
                            ? root.currentName : Translation.tr("No media selected")
                        color: Appearance.colors.colOnLayer2
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                        maximumLineCount: 1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.sourceMode === "folder"
                            ? Translation.tr("%1 of %2").arg(Math.max(0, root.currentIndex + 1)).arg(root.mediaCount)
                                + " · " + root.folderImageCount + " " + Translation.tr("Images")
                                + " · " + root.folderGifCount + " GIF"
                                + " · " + root.folderVideoCount + " " + Translation.tr("Videos")
                            : Translation.tr("Single file")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Row {
                    visible: root.sourceMode === "folder" && root.mediaCount > 1
                    spacing: 2
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6; verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "chevron_left"
                        onClicked: root.advance(-1, false)
                        StyledToolTip { text: Translation.tr("Previous") }
                    }
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6; verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "casino"
                        onClicked: root.advance(1, true)
                        StyledToolTip { text: Translation.tr("Shuffle") }
                    }
                    SelectionGroupButton {
                        width: 32; height: 32
                        horizontalPadding: 6; verticalPadding: 5
                        leftmost: true; rightmost: true
                        buttonIcon: "chevron_right"
                        onClicked: root.advance(1, false)
                        StyledToolTip { text: Translation.tr("Next") }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: Math.max(1, mediaQuickControls.sourceChoices.length)
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: mediaQuickControls.sourceChoices
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        toggled: root.activeSourceChoice === modelData.value
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        onClicked: root.activateSourceChoice(modelData.value)
                    }
                }
            }

            RowLayout {
                visible: root.sourceMode === "folder" && root.mediaCount > 1
                Layout.fillWidth: true
                spacing: 4

                SelectionGroupButton {
                    Layout.fillWidth: true
                    leftmost: true; rightmost: true
                    toggled: root.rotationPaused
                    buttonIcon: root.rotationPaused ? "play_arrow" : "pause"
                    buttonText: root.rotationPaused ? Translation.tr("Resume") : Translation.tr("Pause")
                    onClicked: root.rotationPaused = !root.rotationPaused
                }
                StyledSpinBox {
                    from: 3; to: 3600; stepSize: 1
                    value: root.intervalSeconds
                    onValueModified: root.setInterval(value)
                    StyledToolTip { text: Translation.tr("Seconds between changes") }
                }
                SelectionGroupButton {
                    Layout.fillWidth: true
                    leftmost: true; rightmost: true
                    toggled: root.rotationOrder === "random"
                    buttonIcon: root.rotationOrder === "random" ? "shuffle" : "format_list_numbered"
                    buttonText: root.rotationOrder === "random" ? Translation.tr("Random") : Translation.tr("Sequential")
                    onClicked: Config.setNestedValue(root._configPath + ".order",
                        root.rotationOrder === "random" ? "sequential" : "random")
                }
            }

            RowLayout {
                visible: root.sourceMode === "folder" && root.mediaCount > 1
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Speed")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }

                Repeater {
                    model: [10, 30, 60, 180]
                    SelectionGroupButton {
                        required property int modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        toggled: root.intervalSeconds === modelData
                        buttonText: modelData + "s"
                        onClicked: root.setInterval(modelData)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Circle"), value: "Circle", shape: MaterialShape.Shape.Circle },
                        { label: Translation.tr("Square"), value: "Square", shape: MaterialShape.Shape.Square },
                        { label: Translation.tr("Cookie"), value: "Cookie4Sided", shape: MaterialShape.Shape.Cookie4Sided },
                        { label: Translation.tr("Heart"), value: "Heart", shape: MaterialShape.Shape.Heart }
                    ]
                    Rectangle {
                        id: quickShape
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: Appearance.rounding.small
                        color: root.shapeName === modelData.value
                            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                            : quickShapeHover.hovered
                                ? Appearance.colors.colLayer2Hover : "transparent"
                        border.width: root.shapeName === modelData.value ? 1.5 : 1
                        border.color: root.shapeName === modelData.value
                            ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                        MaterialShape {
                            anchors.centerIn: parent
                            implicitSize: 23
                            shape: quickShape.modelData.shape
                            color: root.shapeName === quickShape.modelData.value
                                ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                        }
                        HoverHandler { id: quickShapeHover }
                        TapHandler {
                            onTapped: Config.setNestedValue(root._configPath + ".shape", quickShape.modelData.value)
                        }
                        StyledToolTip { text: quickShape.modelData.label }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                SelectionGroupButton {
                    Layout.fillWidth: true
                    leftmost: true; rightmost: false
                    toggled: root.fitMode === "cover"
                    buttonIcon: "crop_free"
                    buttonText: Translation.tr("Fill")
                    onClicked: Config.setNestedValue(root._configPath + ".fitMode", "cover")
                }
                SelectionGroupButton {
                    Layout.fillWidth: true
                    leftmost: false; rightmost: true
                    toggled: root.fitMode === "contain"
                    buttonIcon: "fit_screen"
                    buttonText: Translation.tr("Fit")
                    onClicked: Config.setNestedValue(root._configPath + ".fitMode", "contain")
                }
                SelectionGroupButton {
                    visible: root.currentIsVideo || root.currentIsAnimatedImage
                    width: 36
                    leftmost: true; rightmost: true
                    toggled: root.mediaPlaybackPaused
                    buttonIcon: root.mediaPlaybackPaused ? "play_arrow" : "pause_circle"
                    onClicked: root.mediaPlaybackPaused = !root.mediaPlaybackPaused
                    StyledToolTip {
                        text: root.mediaPlaybackPaused
                            ? Translation.tr("Play media") : Translation.tr("Pause media")
                    }
                }
            }

            }
        }
    }

    MaterialShape {
        id: shadowShape
        anchors.fill: parent
        shape: root.shapeEnum
        color: root.widgetSemanticContainer(root.widgetPrimaryRole)
        visible: false
    }

    StyledDropShadow {
        target: shadowShape
        visible: root.currentPath.length > 0
    }

    Item {
        id: maskedContent
        anchors.fill: parent
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: MaterialShape {
                width: maskedContent.width
                height: maskedContent.height
                shape: root.shapeEnum
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.widgetSemanticContainer(root.widgetPrimaryRole)
        }

        MediaSlot {
            id: mediaSlotA
            slotIndex: 0
            anchors.fill: parent
            opacity: root.activeSlot === 0 ? 1 : 0
            shouldPlay: !root.mediaPlaybackPaused
            Behavior on opacity {
                NumberAnimation {
                    duration: root.effectiveTransitionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standard
                }
            }
        }

        MediaSlot {
            id: mediaSlotB
            slotIndex: 1
            anchors.fill: parent
            opacity: root.activeSlot === 1 ? 1 : 0
            shouldPlay: !root.mediaPlaybackPaused
            Behavior on opacity {
                NumberAnimation {
                    duration: root.effectiveTransitionDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standard
                }
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: root.currentPath.length === 0 || root.activeFailed
            text: root.activeFailed ? "broken_image" : (root.dropHover ? "download" : "perm_media")
            fill: root.dropHover ? 1 : 0
            iconSize: Math.max(28, Math.round(root.renderedSize * 0.24))
            color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
        }

        MaterialShape {
            anchors.fill: parent
            visible: root.dropHover
            shape: root.shapeEnum
            color: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.22)
        }
    }

    DropArea {
        anchors.fill: parent
        enabled: !GlobalStates.widgetEditMode
        keys: ["text/uri-list"]

        onEntered: drag => {
            drag.accept(Qt.CopyAction);
            root.dropHover = true;
        }
        onExited: root.dropHover = false
        onDropped: drop => {
            root.dropHover = false;
            if (!drop.hasUrls || drop.urls.length === 0) {
                drop.accepted = false;
                return;
            }

            const path = root.pathFromDropUrl(drop.urls[0]);
            if (!path || !Images.isValidMediaByName(path)) {
                drop.accepted = false;
                return;
            }

            root.setMediaPath(path);
            drop.accept(Qt.CopyAction);
        }
    }
}
