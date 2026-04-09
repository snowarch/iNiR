pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.services
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 0
    pageTitle: Translation.tr("Quick Settings")
    pageIcon: "flash-on"
    pageDescription: Translation.tr("Fast access to the settings you tweak most")

    readonly property bool multiMonitorEnabled: Config.options?.background?.multiMonitor?.enable ?? false
    readonly property bool colorsOnlyMode: Config.options?.appearance?.wallpaperTheming?.colorsOnlyMode ?? false
    readonly property string previewWallpaperPath: Config.options?.appearance?.wallpaperTheming?.previewSourcePath ?? ""
    readonly property string currentWallpaperPath: Wallpapers.currentWallpaperPathForTarget("waffle", multiMonitorEnabled ? targetMonitor : "")
    readonly property string selectedWallpaperPath: (colorsOnlyMode && previewWallpaperPath.length > 0)
        ? previewWallpaperPath
        : currentWallpaperPath
    readonly property string displayWallpaperPath: selectedWallpaperPath.length > 0
        ? selectedWallpaperPath
        : currentWallpaperPath
    readonly property string currentWpUrl: {
        if (!displayWallpaperPath)
            return ""

        return displayWallpaperPath.startsWith("file://") ? displayWallpaperPath : "file://" + displayWallpaperPath
    }
    readonly property bool wpIsVideo: WallpaperListener.isVideoPath(displayWallpaperPath)
    readonly property bool wpIsGif: WallpaperListener.isGifPath(displayWallpaperPath)
    readonly property string wallpaperModeSummary: {
        if (root.colorsOnlyMode)
            return root.previewWallpaperPath.length > 0
                ? Translation.tr("Theme source only")
                : Translation.tr("Colors only")

        if (root.multiMonitorEnabled)
            return Translation.tr("Per-monitor background")

        return (Config.options?.waffles?.background?.useMainWallpaper ?? true)
            ? Translation.tr("Shared with Material ii")
            : Translation.tr("Waffle background")
    }
    readonly property var activeThemePreset: ThemePresets.getPreset(ThemeService.currentTheme)
    readonly property string activeThemeName: activeThemePreset?.name ?? Translation.tr("Auto")
    readonly property string activeThemeDescription: activeThemePreset?.description ?? Translation.tr("Wallpaper-reactive")
    readonly property string backgroundShortcutSummary: {
        const blur = Config.options?.waffles?.background?.effects?.enableBlur ?? false
        const transitions = Config.options?.waffles?.background?.transition?.enable ?? true
        if (blur && transitions)
            return Translation.tr("Blur + transitions enabled")
        if (blur)
            return Translation.tr("Blur enabled")
        if (transitions)
            return Translation.tr("Transitions enabled")
        return Translation.tr("Static background")
    }
    readonly property string waffleStyleSummary: {
        const palette = Looks.useMaterial
            ? Translation.tr("Material colors")
            : Translation.tr("Native Waffle colors")
        const chrome = Looks.glassActive
            ? Translation.tr("glass chrome")
            : Translation.tr("solid chrome")
        return palette + " · " + chrome
    }
    readonly property string currentScheme: Config.options?.appearance?.palette?.type ?? "auto"

    property string targetMonitor: {
        if (!root.multiMonitorEnabled)
            return ""

        const primary = GlobalStates.primaryScreen
        const primaryName = primary ? (WallpaperListener.getMonitorName(primary) ?? "") : ""
        if (primaryName)
            return primaryName

        const focused = WallpaperListener.getFocusedMonitor()
        if (focused)
            return focused

        const screens = Quickshell.screens
        if (!screens || screens.length === 0)
            return ""

        return WallpaperListener.getMonitorName(screens[0]) ?? ""
    }

    // Folder navigation state
    property string rootWallpaperDir: ""

    readonly property bool isInSubfolder: {
        const current = FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
        return root.rootWallpaperDir.length > 0 && current !== root.rootWallpaperDir
    }

    readonly property string currentFolderName: {
        const dir = FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
        if (!dir)
            return ""

        const parts = dir.replace(/\/+$/, "").split("/")
        return parts[parts.length - 1] || ""
    }

    Component.onCompleted: Wallpapers.load()

    Connections {
        target: Wallpapers
        function onFolderChanged() {
            Wallpapers.generateThumbnail("large")
            if (root.rootWallpaperDir.length === 0)
                root.rootWallpaperDir = FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
        }
    }

    function quickApplyTarget(): string {
        if (root.multiMonitorEnabled && root.targetMonitor.length > 0)
            return "main"

        return (Config.options?.waffles?.background?.useMainWallpaper ?? true) ? "main" : "waffle"
    }

    function applyQuickWallpaper(path: string): void {
        if (!path || path.length === 0)
            return

        if (root.colorsOnlyMode) {
            Wallpapers.applyColorsOnly(path, Appearance.m3colors.darkmode)
            return
        }

        const mon = root.multiMonitorEnabled ? root.targetMonitor : ""
        Wallpapers.applySelectionTarget(path, root.quickApplyTarget(), Appearance.m3colors.darkmode, mon)
    }

    function applyRandomQuickWallpaper(): void {
        const model = Wallpapers.folderModel
        const candidates = []
        const count = model?.count ?? 0

        for (let i = 0; i < count; ++i) {
            if (model.get(i, "fileIsDir"))
                continue

            const filePath = model.get(i, "filePath")
            if (filePath && filePath.length > 0)
                candidates.push(filePath)
        }

        if (candidates.length === 0)
            return

        root.applyQuickWallpaper(candidates[Math.floor(Math.random() * candidates.length)])
    }

    function openWallpaperBrowser(): void {
        const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
        if (root.multiMonitorEnabled && root.targetMonitor) {
            Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            Config.setNestedValue("wallpaperSelector.targetMonitor", root.targetMonitor)
        } else {
            Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
        }

        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
    }

    function navigateToParentFolder(): void {
        const dir = FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
        if (!dir)
            return

        const clean = dir.replace(/\/+$/, "")
        const lastSlash = clean.lastIndexOf("/")
        if (lastSlash > 0)
            Wallpapers.setDirectory(clean.substring(0, lastSlash))
    }

    // ── Hero wallpaper card ────────────────────────────────────────────
    Rectangle {
        id: heroCard
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        radius: Looks.radius.large
        color: Looks.colors.bg1Base
        clip: true

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: heroCard.width
                height: heroCard.height
                radius: heroCard.radius
            }
        }

        // Wallpaper image
        Image {
            id: heroImage
            visible: !root.wpIsGif && !root.wpIsVideo
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: visible ? root.currentWpUrl : ""
            asynchronous: true
            cache: false
            sourceSize.width: heroCard.width * 2
            sourceSize.height: heroCard.height * 2
        }

        AnimatedImage {
            visible: root.wpIsGif
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: visible ? root.currentWpUrl : ""
            asynchronous: true
            cache: false
            playing: visible
        }

        Image {
            visible: root.wpIsVideo
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: {
                const frame = Wallpapers.videoFirstFrames[root.displayWallpaperPath]
                return frame ? (frame.startsWith("file://") ? frame : "file://" + frame) : ""
            }
            asynchronous: true
            cache: false
            Component.onCompleted: Wallpapers.ensureVideoFirstFrame(root.displayWallpaperPath)
        }

        // Top gradient — fades from dark to transparent for upper controls
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.50) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Bottom gradient — heavier, for lower controls
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 80
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.25) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
            }
        }

        // Right-side lateral gradient — contrast for dark mode toggle
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: parent.width * 0.40
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.20) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.50) }
            }
        }

        // ── Top-right: Light / Dark toggle group ───
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 0

            Repeater {
                model: [
                    { icon: "weather-sunny", label: Translation.tr("Light"), dark: false },
                    { icon: "weather-moon", label: Translation.tr("Dark"), dark: true }
                ]

                Rectangle {
                    id: modeBtn
                    required property var modelData
                    required property int index

                    readonly property bool toggled: Appearance.m3colors.darkmode === modelData.dark

                    width: modeBtnRow.implicitWidth + 16
                    height: 30
                    radius: index === 0 ? Looks.radius.medium : 0
                    topRightRadius: index === 1 ? Looks.radius.medium : (index === 0 ? Looks.radius.medium : 0)
                    bottomRightRadius: index === 1 ? Looks.radius.medium : 0
                    topLeftRadius: index === 0 ? Looks.radius.medium : 0
                    bottomLeftRadius: index === 0 ? Looks.radius.medium : 0
                    color: modeBtn.toggled
                        ? Qt.rgba(1, 1, 1, 0.25)
                        : modeBtnMa.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.12)
                            : Qt.rgba(0, 0, 0, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, modeBtn.toggled ? 0.35 : 0.10)

                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                    }

                    Row {
                        id: modeBtnRow
                        anchors.centerIn: parent
                        spacing: 5

                        FluentIcon {
                            icon: modeBtn.modelData.icon
                            implicitSize: 14
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        WText {
                            text: modeBtn.modelData.label
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: modeBtn.toggled ? Looks.font.weight.strong : Looks.font.weight.regular
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: modeBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --mode ${modeBtn.modelData.dark ? "dark" : "light"} --noswitch`)
                    }
                }
            }
        }

        // ── Bottom-left: mode pill badge ───
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 12
            width: modeBadgeRow.implicitWidth + 16
            height: 26
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)

            Row {
                id: modeBadgeRow
                anchors.centerIn: parent
                spacing: 5

                FluentIcon {
                    icon: root.colorsOnlyMode ? "eyedropper" : (root.multiMonitorEnabled ? "desktop" : "image")
                    implicitSize: 11
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                WText {
                    text: root.wallpaperModeSummary
                    font.pixelSize: Looks.font.pixelSize.tiny
                    font.weight: Looks.font.weight.strong
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Bottom-right: shuffle + browse buttons ───
        Row {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: 10
            spacing: 6

            // Shuffle button
            Rectangle {
                id: shuffleBtn
                width: shuffleBtnRow.implicitWidth + 14
                height: 30
                radius: height / 2
                color: shuffleBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                }

                Row {
                    id: shuffleBtnRow
                    anchors.centerIn: parent
                    spacing: 5

                    FluentIcon {
                        icon: "arrow-sync"
                        implicitSize: 13
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    WText {
                        text: Translation.tr("Shuffle")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: shuffleBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.applyRandomQuickWallpaper()
                }
            }

            // Browse button
            Rectangle {
                id: browseBtn
                width: browseBtnRow.implicitWidth + 14
                height: 30
                radius: height / 2
                color: browseBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.45)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.15)

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                }

                Row {
                    id: browseBtnRow
                    anchors.centerIn: parent
                    spacing: 5

                    FluentIcon {
                        icon: "folder"
                        implicitSize: 13
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    WText {
                        text: Translation.tr("Browse")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: browseBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWallpaperBrowser()
                }
            }
        }

        // Video/GIF badge — top-left
        Rectangle {
            visible: root.wpIsVideo || root.wpIsGif
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 10
            width: mediaBadgeRow.implicitWidth + 12
            height: 22
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.60)

            Row {
                id: mediaBadgeRow
                anchors.centerIn: parent
                spacing: 4

                FluentIcon {
                    icon: root.wpIsVideo ? "video" : "image"
                    implicitSize: 11
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }

                WText {
                    text: root.wpIsVideo ? "VIDEO" : "GIF"
                    font.pixelSize: Looks.font.pixelSize.tiny
                    font.weight: Looks.font.weight.strong
                    color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // ── Wallpaper grid ─────────────────────────────────────────────────
    Rectangle {
        id: gridCard
        Layout.fillWidth: true
        Layout.preferredHeight: {
            const itemCount = Wallpapers.folderModel?.count ?? 0
            const navH = root.isInSubfolder ? 36 : 0
            if (itemCount === 0)
                return Math.max(160, navH + 80)

            const cols = Math.max(1, Math.floor((width - 12) / 140))
            const rows = Math.ceil(itemCount / cols)
            const cellH = ((width - 12) / cols) * 0.625
            return Math.min(380, Math.max(160, rows * cellH + 12 + navH))
        }
        radius: Looks.radius.large
        color: Looks.colors.bg1Base
        border.width: 1
        border.color: Looks.colors.bg1Border
        clip: true

        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: gridCard.width
                height: gridCard.height
                radius: gridCard.radius
            }
        }

        // Folder navigation header — visible only inside subfolders
        Item {
            id: folderNavHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.isInSubfolder ? 36 : 0
            visible: root.isInSubfolder

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 8
                spacing: 4

                Rectangle {
                    width: 28; height: 28
                    radius: Looks.radius.medium
                    color: folderBackMa.containsMouse ? Looks.colors.bg1Hover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                    }

                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "chevron-left"
                        implicitSize: 14
                        color: folderBackMa.containsMouse ? Looks.colors.accent : Looks.colors.subfg

                        Behavior on color {
                            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                        }
                    }

                    MouseArea {
                        id: folderBackMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigateToParentFolder()
                    }
                }

                WText {
                    text: root.currentFolderName
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.strong
                    color: Looks.colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Subtle bottom separator
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                height: 1
                color: Looks.colors.bg1Border
            }
        }

        GridView {
            id: wallpaperGrid
            clip: true
            anchors.top: folderNavHeader.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            anchors.bottomMargin: 6
            anchors.topMargin: root.isInSubfolder ? 2 : 6
            model: Wallpapers.folderModel
            Component.onCompleted: Wallpapers.generateThumbnail("large")

            property int minCellWidth: 140
            property int columns: Math.max(1, Math.floor(width / minCellWidth))
            cellWidth: width / columns
            cellHeight: cellWidth * 0.625

            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: cellHeight * 2
            property int currentHoverIndex: -1

            ScrollBar.vertical: ScrollBar {
                policy: wallpaperGrid.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            delegate: Item {
                id: wpDelegateItem
                required property int index
                required property bool fileIsDir
                required property string filePath
                required property string fileName
                required property url fileUrl

                width: wallpaperGrid.cellWidth
                height: wallpaperGrid.cellHeight

                Rectangle {
                    id: wpThumb
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Looks.radius.medium
                    color: Looks.colors.bg2Base
                    clip: true
                    border.width: wpThumbSelected ? 2 : (wpDelegateItem.index === wallpaperGrid.currentHoverIndex ? 1 : 0)
                    border.color: wpThumbSelected ? Looks.colors.accent : Looks.colors.bg2Border

                    Behavior on border.width {
                        animation: NumberAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                    }
                    Behavior on border.color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                    }

                    readonly property bool wpThumbSelected: {
                        if (wpDelegateItem.fileIsDir) return false
                        if (root.colorsOnlyMode) {
                            return wpDelegateItem.filePath === root.previewWallpaperPath
                        }
                        return wpDelegateItem.filePath === root.displayWallpaperPath
                    }

                    Image {
                        visible: !WallpaperListener.isVideoPath(wpDelegateItem.filePath) && !WallpaperListener.isGifPath(wpDelegateItem.filePath) && !wpDelegateItem.fileIsDir
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        fillMode: Image.PreserveAspectCrop
                        source: visible ? (wpDelegateItem.filePath.startsWith("file://") ? wpDelegateItem.filePath : "file://" + wpDelegateItem.filePath) : ""
                        asynchronous: true
                        cache: true
                        sourceSize.width: wallpaperGrid.cellWidth * 2
                        sourceSize.height: wallpaperGrid.cellHeight * 2
                    }

                    AnimatedImage {
                        visible: WallpaperListener.isGifPath(wpDelegateItem.filePath)
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        fillMode: Image.PreserveAspectCrop
                        source: visible ? (wpDelegateItem.filePath.startsWith("file://") ? wpDelegateItem.filePath : "file://" + wpDelegateItem.filePath) : ""
                        asynchronous: true
                        cache: true
                        playing: false
                    }

                    Image {
                        visible: WallpaperListener.isVideoPath(wpDelegateItem.filePath)
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        fillMode: Image.PreserveAspectCrop
                        source: {
                            const ff = Wallpapers.videoFirstFrames[wpDelegateItem.filePath]
                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                        }
                        asynchronous: true
                        cache: true
                        Component.onCompleted: Wallpapers.ensureVideoFirstFrame(wpDelegateItem.filePath)
                    }

                    // Folder overlay
                    Rectangle {
                        visible: wpDelegateItem.fileIsDir
                        anchors.fill: parent
                        color: Looks.colors.bg2Base
                        radius: parent.radius

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            FluentIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "folder"
                                implicitSize: 28
                                color: Looks.colors.accent
                            }

                            WText {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: wpThumb.width - 12
                                text: wpDelegateItem.fileName
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.subfg
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Selected checkmark
                    Rectangle {
                        visible: wpThumb.wpThumbSelected
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 5
                        width: 20; height: 20
                        radius: 10
                        color: Looks.colors.accent

                        FluentIcon {
                            anchors.centerIn: parent
                            icon: "checkmark"
                            implicitSize: 12
                            color: Looks.colors.accentFg
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: wallpaperGrid.currentHoverIndex = wpDelegateItem.index
                        onExited: if (wallpaperGrid.currentHoverIndex === wpDelegateItem.index) wallpaperGrid.currentHoverIndex = -1
                        onClicked: {
                            if (wpDelegateItem.fileIsDir) {
                                Wallpapers.setDirectory(wpDelegateItem.filePath)
                            } else if (root.colorsOnlyMode) {
                                Wallpapers.applyColorsOnly(wpDelegateItem.filePath, Appearance.m3colors.darkmode)
                            } else {
                                root.applyQuickWallpaper(wpDelegateItem.filePath)
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        ColumnLayout {
            anchors.centerIn: parent
            visible: (Wallpapers.folderModel?.count ?? 0) === 0
            spacing: 6

            FluentIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "image"
                implicitSize: 32
                color: Looks.colors.accent
                opacity: 0.4
            }

            WText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No images found")
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                opacity: 0.7
            }
        }
    }

    // ── Color scheme chip strip ────────────────────────────────────────
    Flow {
        id: schemeChipStrip
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { value: "auto", name: Translation.tr("Auto") },
                { value: "scheme-content", name: Translation.tr("Content") },
                { value: "scheme-expressive", name: Translation.tr("Expressive") },
                { value: "scheme-fidelity", name: Translation.tr("Fidelity") },
                { value: "scheme-fruit-salad", name: Translation.tr("Fruit Salad") },
                { value: "scheme-monochrome", name: Translation.tr("Monochrome") },
                { value: "scheme-neutral", name: Translation.tr("Neutral") },
                { value: "scheme-rainbow", name: Translation.tr("Rainbow") },
                { value: "scheme-tonal-spot", name: Translation.tr("Tonal Spot") }
            ]

            Rectangle {
                id: schemeChip
                required property var modelData
                required property int index

                readonly property bool selected: root.currentScheme === modelData.value

                width: schemeChipText.implicitWidth + 20
                height: 28
                radius: height / 2
                color: schemeChip.selected
                    ? Looks.colors.accent
                    : schemeChipMa.containsMouse
                        ? Looks.colors.bg2Hover
                        : Looks.colors.bg1Base
                border.width: schemeChip.selected ? 0 : 1
                border.color: Looks.colors.bg1Border

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                }

                WText {
                    id: schemeChipText
                    anchors.centerIn: parent
                    text: schemeChip.modelData.name
                    font.pixelSize: Looks.font.pixelSize.small
                    font.weight: schemeChip.selected ? Looks.font.weight.strong : Looks.font.weight.regular
                    color: schemeChip.selected ? Looks.colors.accentFg : Looks.colors.fg
                }

                MouseArea {
                    id: schemeChipMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const val = schemeChip.modelData.value
                        Config.setNestedValue("appearance.palette.type", val)
                        if (ThemeService.isAutoTheme) {
                            ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch --type ${val}`)
                        } else {
                            const primary = Appearance.m3colors.m3primary
                            const hex = "#" + ((1 << 24)
                                | (Math.round(primary.r * 255) << 16)
                                | (Math.round(primary.g * 255) << 8)
                                | Math.round(primary.b * 255)).toString(16).slice(1)
                            MaterialThemeLoader.applySchemeVariant(hex, val)
                        }
                    }
                }
            }
        }
    }

    // ── Wallpaper & options ────────────────────────────────────────────
    WSettingsCard {
        title: Translation.tr("Wallpaper & Colors")
        icon: "image-filled"

        // Per-monitor wallpapers
        WSettingsSwitch {
            label: Translation.tr("Per-monitor wallpapers")
            icon: "desktop"
            description: Translation.tr("Set different wallpapers for each monitor")
            checked: root.multiMonitorEnabled

            onCheckedChanged: {
                Config.setNestedValue("background.multiMonitor.enable", checked)
                if (!checked) {
                    const globalPath = Config.options?.background?.wallpaperPath ?? ""
                    if (globalPath)
                        Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                }
            }
        }

        // Monitor selector strip — only when multi-monitor is on
        Item {
            visible: root.multiMonitorEnabled
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            implicitHeight: 44

            Row {
                anchors.centerIn: parent
                spacing: 6
                height: parent.height

                Repeater {
                    model: Quickshell.screens

                    Rectangle {
                        id: monitorCard
                        required property var modelData
                        required property int index

                        readonly property string monitorName: WallpaperListener.getMonitorName(modelData) ?? ""
                        readonly property bool selected: monitorName === root.targetMonitor
                        readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)

                        width: parent.height * aspectRatio
                        height: parent.height
                        radius: Looks.radius.medium
                        color: selected
                            ? Looks.colors.accent
                            : monitorMouse.containsMouse
                                ? Looks.colors.bg2Hover
                                : Looks.colors.bg2Base
                        border.width: 1
                        border.color: selected ? Looks.colors.accent : Looks.colors.bg2Border

                        Behavior on color {
                            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                        }

                        WText {
                            anchors.centerIn: parent
                            text: monitorCard.monitorName || Translation.tr("Monitor %1").arg(String(monitorCard.index + 1))
                            font.pixelSize: Looks.font.pixelSize.tiny
                            font.weight: Font.Medium
                            color: monitorCard.selected ? Looks.colors.accentFg : Looks.colors.fg
                        }

                        MouseArea {
                            id: monitorMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.targetMonitor = monitorCard.monitorName
                        }
                    }
                }
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Colors only mode")
            icon: "eyedropper"
            description: Translation.tr("Use a wallpaper as a palette source without replacing the background")
            checked: root.colorsOnlyMode

            onCheckedChanged: {
                Config.setNestedValue("appearance.wallpaperTheming.colorsOnlyMode", checked)
                if (!checked)
                    Config.setNestedValue("appearance.wallpaperTheming.previewSourcePath", "")
            }
        }

        WSettingsSpinBox {
            id: colorStrengthSpinBox
            label: Translation.tr("Color strength")
            icon: "eyedropper"
            description: Translation.tr("Controls how vivid wallpaper-derived accent colors are")
            suffix: "%"
            from: 60
            to: 180
            stepSize: 5
            value: Math.round((Config.options?.appearance?.wallpaperTheming?.colorStrength ?? 1.0) * 100)
            property bool ready: false
            Component.onCompleted: ready = true

            onValueChanged: {
                if (!ready)
                    return

                Config.setNestedValue("appearance.wallpaperTheming.colorStrength", value / 100)
                if (ThemeService.isAutoTheme)
                    ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch`)
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Transparency")
            icon: "auto"
            description: Translation.tr("Enable transparent surfaces across the shell")
            checked: Config.options?.appearance?.transparency?.enable ?? false
            onCheckedChanged: Config.setNestedValue("appearance.transparency.enable", checked)
        }
    }

    // ── Related settings ───────────────────────────────────────────────
    WSettingsSection {
        title: Translation.tr("Related settings")
    }

    WSettingsCard {
        WSettingsRow {
            label: Translation.tr("Themes")
            icon: "dark-theme"
            description: root.activeThemeName + " · " + root.activeThemeDescription
            clickable: true
            showChevron: true
            onClicked: root.navigateRequested(4)
        }

        WSettingsRow {
            label: Translation.tr("Background")
            icon: "image"
            description: root.backgroundShortcutSummary
            clickable: true
            showChevron: true
            onClicked: root.navigateRequested(3)
        }

        WSettingsRow {
            label: Translation.tr("Taskbar")
            icon: "desktop"
            description: Translation.tr("Layout, tray, clock, and peek options")
            clickable: true
            showChevron: true
            onClicked: root.navigateRequested(2)
        }

        WSettingsRow {
            label: Translation.tr("Waffle Style")
            icon: "wand"
            description: root.waffleStyleSummary
            clickable: true
            showChevron: true
            onClicked: root.navigateRequested(8)
        }
    }

    // ── Quick actions ──────────────────────────────────────────────────
    WSettingsSection {
        title: Translation.tr("Quick actions")
    }

    // Action buttons row — compact, horizontal, icon-heavy
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [
                { icon: "arrow-sync", label: Translation.tr("Reload"), action: "reload" },
                { icon: "settings", label: Translation.tr("Config"), action: "config" },
                { icon: "keyboard", label: Translation.tr("Shortcuts"), action: "shortcuts" }
            ]

            Rectangle {
                id: actionBtn
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Looks.radius.large
                color: actionBtnMa.containsMouse ? Looks.colors.bg1Hover : Looks.colors.bg1Base
                border.width: 1
                border.color: Looks.colors.bg1Border

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    FluentIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: actionBtn.modelData.icon
                        implicitSize: 18
                        color: Looks.colors.accent
                    }

                    WText {
                        Layout.alignment: Qt.AlignHCenter
                        text: actionBtn.modelData.label
                        font.pixelSize: Looks.font.pixelSize.small
                        font.weight: Looks.font.weight.regular
                        color: Looks.colors.fg
                    }
                }

                MouseArea {
                    id: actionBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (actionBtn.modelData.action) {
                        case "reload":
                            Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
                            break
                        case "config":
                            Qt.openUrlExternally(Directories.shellConfigPath)
                            break
                        case "shortcuts":
                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "cheatsheet", "toggle"])
                            break
                        }
                    }
                }
            }
        }
    }

    WSettingsCard {
        WSettingsSwitch {
            label: Translation.tr("Show reload notifications")
            icon: "alert"
            description: Translation.tr("Toast when Quickshell or Niri config reloads")
            checked: Config.options?.reloadToasts?.enable ?? true
            onCheckedChanged: Config.setNestedValue("reloadToasts.enable", checked)
        }
    }
}
