import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    settingsPageIndex: 0
    settingsPageName: Translation.tr("Quick")

    Component.onCompleted: {
        Wallpapers.load()
    }

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["/usr/bin/bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
        stdout: SplitParser {
            onRead: data => {
                randomWallProc.status = data.trim();
            }
        }
    }

    // Wallpaper selection
    SettingsCardSection {
        expanded: true
        icon: "format_paint"
        title: Translation.tr("Wallpaper & Colors")
        Layout.fillWidth: true

        SettingsGroup {
            // ── Hero wallpaper preview ──
            Rectangle {
                id: heroCard
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                radius: Appearance.rounding.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer0
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                    : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                           : Appearance.inirEverywhere ? Appearance.inir.colBorder
                           : Appearance.colors.colLayer0Border
                layer.enabled: true
                layer.smooth: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: heroCard.width
                        height: heroCard.height
                        radius: heroCard.radius
                    }
                }

                StyledImage {
                    id: wallpaperPreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: Wallpapers.effectiveWallpaperUrl
                    cache: false
                    mipmap: true
                    smooth: true
                }

                // Top gradient for controls
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 60
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.45) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Bottom gradient for controls
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 80
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.25) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.65) }
                    }
                }

                // Right-side gradient for button contrast
                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: parent.width * 0.45
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.25) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
                }

                // Light/Dark toggle — top right
                ButtonGroup {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    uniformCellSizes: true
                    spacing: 0

                    SelectionGroupButton {
                        buttonIcon: "light_mode"
                        buttonText: Translation.tr("Light")
                        toggled: !Appearance.m3colors.darkmode
                        leftmost: true
                        onClicked: MaterialThemeLoader.setDarkMode(false)
                    }
                    SelectionGroupButton {
                        buttonIcon: "dark_mode"
                        buttonText: Translation.tr("Dark")
                        toggled: Appearance.m3colors.darkmode
                        rightmost: true
                        onClicked: MaterialThemeLoader.setDarkMode(true)
                    }
                }

                // Bottom left — random buttons (conditional on weeb policy)
                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 10
                    spacing: 6
                    visible: (Config.options?.policies?.weeb ?? 0) === 1

                    RippleButtonWithIcon {
                        enabled: !randomWallProc.running
                        buttonRadius: Appearance.rounding.full
                        materialIcon: "ifl"
                        mainText: randomWallProc.running ? Translation.tr("...") : Translation.tr("Konachan")
                        colBackground: Qt.rgba(0, 0, 0, 0.5)
                        colBackgroundHover: Qt.rgba(0, 0, 0, 0.65)
                        mainContentComponent: Component {
                            StyledText {
                                text: randomWallProc.running ? Translation.tr("...") : Translation.tr("Konachan")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: "white"
                            }
                        }
                        onClicked: {
                            randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`;
                            randomWallProc.running = true;
                        }
                        StyledToolTip {
                            text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/Wallpapers")
                        }
                    }
                    RippleButtonWithIcon {
                        enabled: !randomWallProc.running
                        buttonRadius: Appearance.rounding.full
                        materialIcon: "ifl"
                        mainText: randomWallProc.running ? Translation.tr("...") : Translation.tr("osu!")
                        colBackground: Qt.rgba(0, 0, 0, 0.5)
                        colBackgroundHover: Qt.rgba(0, 0, 0, 0.65)
                        mainContentComponent: Component {
                            StyledText {
                                text: randomWallProc.running ? Translation.tr("...") : Translation.tr("osu!")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: "white"
                            }
                        }
                        onClicked: {
                            randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_osu_wall.sh`;
                            randomWallProc.running = true;
                        }
                        StyledToolTip {
                            text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/Wallpapers")
                        }
                    }
                }

                // Bottom right — choose file button with keyboard shortcut
                RippleButtonWithIcon {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 10
                    buttonRadius: Appearance.rounding.full
                    materialIcon: "wallpaper"
                    colBackground: Qt.rgba(0, 0, 0, 0.5)
                    colBackgroundHover: Qt.rgba(0, 0, 0, 0.65)
                    onClicked: {
                        Quickshell.execDetached(`${Directories.wallpaperSwitchScriptPath}`);
                    }
                    mainContentComponent: Component {
                        RowLayout {
                            spacing: 8
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: Translation.tr("Choose file")
                                color: "white"
                            }
                            RowLayout {
                                spacing: 2
                                KeyboardKey { key: "Ctrl" }
                                KeyboardKey { key: "Alt" }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "+"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                                KeyboardKey { key: "T" }
                            }
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Pick wallpaper image on your system")
                    }
                }
            }

            // ── Color scheme variant chips ──
            ConfigSelectionArray {
                currentValue: Config.options?.appearance?.palette?.type ?? "auto"
                onSelected: newValue => {
                    Config.setNestedValue("appearance.palette.type", newValue)
                    if (ThemeService.isAutoTheme) {
                        Quickshell.execDetached(["/usr/bin/bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`]);
                    } else {
                        const hex = MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                        MaterialThemeLoader.applySchemeVariant(hex, newValue)
                    }
                }
                options: [
                    {
                        "value": "auto",
                        "displayName": Translation.tr("Auto")
                    },
                    {
                        "value": "scheme-content",
                        "displayName": Translation.tr("Content")
                    },
                    {
                        "value": "scheme-expressive",
                        "displayName": Translation.tr("Expressive")
                    },
                    {
                        "value": "scheme-fidelity",
                        "displayName": Translation.tr("Fidelity")
                    },
                    {
                        "value": "scheme-fruit-salad",
                        "displayName": Translation.tr("Fruit Salad")
                    },
                    {
                        "value": "scheme-monochrome",
                        "displayName": Translation.tr("Monochrome")
                    },
                    {
                        "value": "scheme-neutral",
                        "displayName": Translation.tr("Neutral")
                    },
                    {
                        "value": "scheme-rainbow",
                        "displayName": Translation.tr("Rainbow")
                    },
                    {
                        "value": "scheme-tonal-spot",
                        "displayName": Translation.tr("Tonal Spot")
                    }
                ]
            }

            ConfigSpinBox {
                icon: "palette"
                text: Translation.tr("Wallpaper color strength") + " (%)"
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.colorStrength ?? 1.0) * 100)
                from: 60
                to: 180
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.colorStrength", value / 100)
                    if (ThemeService.isAutoTheme)
                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                }

                StyledToolTip {
                    text: Translation.tr("Controls how vivid wallpaper-derived accent colors are. 100% keeps the default balance; higher values produce richer accents.")
                }
            }

            // ── Options strip ──
            SettingsSwitch {
                buttonIcon: "ev_shadow"
                text: Translation.tr("Transparency")
                checked: Config.options?.appearance?.transparency?.enable ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.transparency.enable", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Might look ass. Unsupported.")
                }
            }

            SettingsSwitch {
                buttonIcon: "palette"
                text: Translation.tr("Colors only mode")
                checked: Config.options?.appearance?.wallpaperTheming?.colorsOnlyMode ?? false
                onCheckedChanged: {
                    Config.setNestedValue("appearance.wallpaperTheming.colorsOnlyMode", checked)
                    if (!checked)
                        Config.setNestedValue("appearance.wallpaperTheming.previewSourcePath", "")
                }
                StyledToolTip {
                    text: Translation.tr("Use any thumbnail as the theme source while keeping the current wallpaper")
                }
            }

            // ── Wallpaper browser ──
            ContentSubsection {
                title: Translation.tr("Quick select")

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true

                        // Folder breadcrumb
                        RowLayout {
                            spacing: 4
                            MaterialSymbol {
                                text: "folder"
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory)
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RippleButtonWithIcon {
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "folder_open"
                            mainText: Translation.tr("Current folder")
                            onClicked: {
                                const currentPath = Config.options?.background?.wallpaperPath ?? "";
                                if (currentPath && currentPath.length) {
                                    Wallpapers.setDirectory(FileUtils.parentDirectory(currentPath));
                                } else {
                                    Wallpapers.setDirectory(Wallpapers.defaultFolder.toString());
                                }
                            }
                            StyledToolTip {
                                text: Translation.tr("Switch to the folder containing the current wallpaper")
                            }
                        }
                        RippleButtonWithIcon {
                            buttonRadius: Appearance.rounding.full
                            materialIcon: "apps"
                            mainText: Translation.tr("Selector")
                            onClicked: {
                                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
                                if (Config.options?.background?.multiMonitor?.enable && multiMonitorPanel.selectedMonitor) {
                                    Config.setNestedValue("wallpaperSelector.targetMonitor", multiMonitorPanel.selectedMonitor)
                                }
                                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"]);
                            }
                            StyledToolTip {
                                text: Translation.tr("Open the full wallpaper selector overlay")
                            }
                        }
                    }

                    // Backdrop selection mode indicator
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? bdModeRow.implicitHeight + 12 : 0
                        visible: multiMonitorPanel.visible && multiMonitorPanel.backdropViewActive
                        radius: Appearance.rounding.small
                        color: Appearance.inirEverywhere
                            ? Qt.rgba(Appearance.inir.colAccent.r, Appearance.inir.colAccent.g, Appearance.inir.colAccent.b, 0.15)
                            : Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.15)
                        border.width: 1
                        border.color: Appearance.inirEverywhere
                            ? Qt.rgba(Appearance.inir.colAccent.r, Appearance.inir.colAccent.g, Appearance.inir.colAccent.b, 0.3)
                            : Qt.rgba(Appearance.colors.colTertiary.r, Appearance.colors.colTertiary.g, Appearance.colors.colTertiary.b, 0.3)

                        RowLayout {
                            id: bdModeRow
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6
                            MaterialSymbol {
                                text: "blur_on"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colTertiary
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Selecting backdrop wallpaper")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.inirEverywhere ? Appearance.inir.colOnLayer1 : Appearance.colors.colOnLayer1
                            }
                            MaterialSymbol {
                                text: "close"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: multiMonitorPanel.backdropViewActive = false
                                }
                            }
                        }

                        Behavior on Layout.preferredHeight {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        // Dynamic height: min 120, max 400, based on content rows
                        Layout.preferredHeight: {
                            const itemCount = Wallpapers.folderModel?.count ?? 0
                            if (itemCount === 0) return 120
                            const cols = Math.max(1, Math.floor((width - 2 * Appearance.sizes.spacingSmall) / 110))
                            const rows = Math.ceil(itemCount / cols)
                            const cellH = ((width - 2 * Appearance.sizes.spacingSmall) / cols) * 0.67
                            return Math.min(280, Math.max(120, rows * cellH + 2 * Appearance.sizes.spacingSmall))
                        }
                        radius: Appearance.rounding.normal
                        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                             : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                             : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                             : Appearance.colors.colLayer0
                        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                            : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                                   : Appearance.inirEverywhere ? Appearance.inir.colBorder
                                   : Appearance.colors.colLayer0Border
                        clip: true

                        GridView {
                            id: wallpaperGrid
                            anchors.fill: parent
                            anchors.margins: Appearance.sizes.spacingSmall
                            model: Wallpapers.folderModel
                            Component.onCompleted: Wallpapers.generateThumbnail("large")

                            Connections {
                                target: Wallpapers
                                function onFolderChanged() {
                                    Wallpapers.generateThumbnail("large")
                                }
                            }

                            // Responsive cell sizing - fill available width
                            property int minCellWidth: 110
                            property int columns: Math.max(1, Math.floor(width / minCellWidth))
                            cellWidth: width / columns
                            cellHeight: cellWidth * 0.67  // 3:2 aspect ratio

                            interactive: contentHeight > height
                            boundsBehavior: Flickable.StopAtBounds
                            cacheBuffer: cellHeight * 2
                            property int currentHoverIndex: -1
                            ScrollBar.vertical: StyledScrollBar { policy: wallpaperGrid.interactive ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

                            delegate: Item {
                                id: delegateItem
                                required property int index
                                required property bool fileIsDir
                                required property string filePath
                                required property string fileName
                                required property url fileUrl

                                width: wallpaperGrid.cellWidth
                                height: wallpaperGrid.cellHeight

                                QuickWallpaperItem {
                                    anchors.fill: parent
                                    fileModelData: ({
                                        filePath: delegateItem.filePath,
                                        fileName: delegateItem.fileName,
                                        fileIsDir: delegateItem.fileIsDir,
                                        fileUrl: delegateItem.fileUrl
                                    })
                                    isSelected: {
                                        if (delegateItem.fileIsDir) return false
                                        if (multiMonitorPanel.visible && multiMonitorPanel.backdropViewActive)
                                            return delegateItem.filePath === multiMonitorPanel.backdropPath
                                        if (Config.options?.appearance?.wallpaperTheming?.colorsOnlyMode ?? false) {
                                            const previewPath = Config.options?.appearance?.wallpaperTheming?.previewSourcePath ?? ""
                                            return delegateItem.filePath === previewPath
                                        }
                                        const multiMon = (Config.options?.background?.multiMonitor?.enable ?? false) && multiMonitorPanel.selectedMonitor
                                        const currentWallpaperPath = Config.options?.background?.wallpaperPath ?? ""
                                        return delegateItem.filePath === (multiMon
                                            ? (WallpaperListener.effectivePerMonitor[multiMonitorPanel.selectedMonitor]?.path ?? currentWallpaperPath)
                                            : currentWallpaperPath)
                                    }
                                    isHovered: delegateItem.index === wallpaperGrid.currentHoverIndex

                                    onEntered: wallpaperGrid.currentHoverIndex = delegateItem.index
                                    onExited: if (wallpaperGrid.currentHoverIndex === delegateItem.index) wallpaperGrid.currentHoverIndex = -1
                                    onActivated: {
                                        if (delegateItem.fileIsDir) {
                                            Wallpapers.setDirectory(delegateItem.filePath);
                                        } else if (multiMonitorPanel.visible && multiMonitorPanel.backdropViewActive) {
                                            const multiMon = Config.options?.background?.multiMonitor?.enable ?? false
                                            if (multiMon && multiMonitorPanel.selectedMonitor) {
                                                Wallpapers.updatePerMonitorBackdropConfig(delegateItem.filePath, multiMonitorPanel.selectedMonitor)
                                            } else {
                                                Config.setNestedValue("background.backdrop.wallpaperPath", delegateItem.filePath)
                                            }
                                            Config.setNestedValue("background.backdrop.useMainWallpaper", false)
                                            Wallpapers.ensureVideoFirstFrame(delegateItem.filePath)
                                        } else if (Config.options?.appearance?.wallpaperTheming?.colorsOnlyMode) {
                                            Wallpapers.applyColorsOnly(delegateItem.filePath, Appearance.m3colors.darkmode)
                                        } else {
                                            const mon = (Config.options?.background?.multiMonitor?.enable ?? false) ? (multiMonitorPanel.selectedMonitor || "") : ""
                                            Wallpapers.select(delegateItem.filePath, Appearance.m3colors.darkmode, mon);
                                        }
                                    }
                                }
                            }
                        }

                        // Empty state
                        MaterialPlaceholderMessage {
                            anchors.centerIn: parent
                            maximumWidth: 360
                            shown: Wallpapers.folderModel.count === 0
                            icon: "image"
                            text: Translation.tr("No images found")
                            explanation: Translation.tr("Add wallpapers to this folder or choose a different location")
                            shape: MaterialShape.Shape.Bun
                        }
                    }
                }
            }
        }

        SettingsGroup {
            ConfigSwitch {
                buttonIcon: "monitor"
                text: Translation.tr("Per-monitor wallpapers")
                checked: Config.options?.background?.multiMonitor?.enable ?? false
                onCheckedChanged: {
                    Config.setNestedValue("background.multiMonitor.enable", checked)
                    if (!checked) {
                        const globalPath = Config.options?.background?.wallpaperPath ?? ""
                        if (globalPath) {
                            Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                        }
                    }
                }
            }

            // Multi-monitor management panel
            ColumnLayout {
                id: multiMonitorPanel
                visible: Config.options?.background?.multiMonitor?.enable ?? false
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                property string selectedMonitor: {
                    const primary = GlobalStates.primaryScreen
                    const primaryName = primary ? (WallpaperListener.getMonitorName(primary) ?? "") : ""
                    if (primaryName) return primaryName
                    const focused = WallpaperListener.getFocusedMonitor()
                    if (focused) return focused
                    const screens = Quickshell.screens
                    if (!screens || screens.length === 0) return ""
                    return WallpaperListener.getMonitorName(screens[0]) ?? ""
                }

                readonly property var selMonData: WallpaperListener.effectivePerMonitor[selectedMonitor] ?? { path: "", isVideo: false, isGif: false, isAnimated: false, hasCustomWallpaper: false }
                readonly property string selMonPath: selMonData.path || (Config.options?.background?.wallpaperPath ?? "")
                property bool backdropViewActive: false

                // Backdrop wallpaper data for stacked preview
                readonly property var iiBackdrop: Config.options?.background?.backdrop ?? {}
                readonly property bool backdropEnabled: iiBackdrop.enable ?? false
                readonly property string backdropPath: {
                    const useMain = iiBackdrop.useMainWallpaper ?? true;
                    if (!useMain) {
                        // Per-monitor backdrop takes priority
                        const perMonBd = selMonData.backdropPath ?? ""
                        if (perMonBd) return perMonBd
                        // Fall back to global backdrop
                        const globalBd = iiBackdrop.wallpaperPath || ""
                        if (globalBd) return globalBd
                    }
                    return selMonPath;
                }
                readonly property string backdropUrl: {
                    const p = backdropPath
                    if (!p) return ""
                    return p.startsWith("file://") ? p : "file://" + p
                }

                // Delayed color regeneration (waits for config file write before script reads)
                Timer {
                    id: colorRegenTimer
                    interval: 1000
                    onTriggered: Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                }

                // Visual monitor layout
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    radius: Appearance.rounding.normal
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : Appearance.colors.colLayer0
                    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                               : Appearance.inirEverywhere ? Appearance.inir.colBorder
                               : Appearance.colors.colLayer0Border

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Appearance.sizes.spacingSmall
                        height: parent.height - 24

                        Repeater {
                            model: Quickshell.screens

                            Item {
                                id: monitorStack
                                required property var modelData
                                required property int index

                                readonly property string monName: WallpaperListener.getMonitorName(modelData) ?? ""
                                readonly property var wpData: WallpaperListener.effectivePerMonitor[monName] ?? { path: "" }
                                readonly property string wpPath: wpData.path || (Config.options?.background?.wallpaperPath ?? "")
                                readonly property bool isSelected: monName === multiMonitorPanel.selectedMonitor
                                readonly property bool isGif: WallpaperListener.isGifPath(wpPath)
                                readonly property bool isVideo: WallpaperListener.isVideoPath(wpPath)
                                readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)
                                readonly property real cardHeight: parent.height - 16
                                property bool showingBackdrop: false

                                readonly property string backdropPath: {
                                    const bd = Config.options?.background?.backdrop ?? {}
                                    const useMain = bd.useMainWallpaper ?? true
                                    if (!useMain) {
                                        // Per-monitor backdrop takes priority
                                        const perMonBd = wpData.backdropPath ?? ""
                                        if (perMonBd) return perMonBd
                                        // Fall back to global backdrop
                                        const globalBd = bd.wallpaperPath || ""
                                        if (globalBd) return globalBd
                                    }
                                    return wpPath
                                }

                                onWpPathChanged: if (isVideo) Wallpapers.ensureVideoFirstFrame(wpPath)
                                onBackdropPathChanged: if (WallpaperListener.isVideoPath(backdropPath)) Wallpapers.ensureVideoFirstFrame(backdropPath)

                                Layout.preferredWidth: (cardHeight * aspectRatio) + (multiMonitorPanel.backdropEnabled ? 26 : 8)
                                Layout.preferredHeight: parent.height
                                Layout.alignment: Qt.AlignVCenter

                                // Backdrop card — peeks out to the RIGHT behind the main card
                                Rectangle {
                                    id: backdropPeekCard
                                    visible: multiMonitorPanel.backdropEnabled
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: monitorCard.width
                                    height: monitorCard.height
                                    radius: Appearance.rounding.small
                                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                         : Appearance.colors.colLayer1
                                    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                                        : Appearance.inirEverywhere ? 1 : (monitorStack.showingBackdrop ? 2 : 1)
                                    border.color: monitorStack.showingBackdrop
                                        ? (Appearance.angelEverywhere ? (Appearance.angel?.colPrimary ?? Appearance.colors.colPrimary) : Appearance.inirEverywhere ? (Appearance.inir?.colAccent ?? Appearance.colors.colPrimary) : Appearance.colors.colPrimary)
                                        : (Appearance.angelEverywhere ? (Appearance.angel?.colCardBorder ?? Appearance.colors.colLayer0Border) : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border) : Appearance.colors.colLayer0Border)
                                    clip: true
                                    z: monitorStack.showingBackdrop ? 2 : 0
                                    opacity: monitorStack.showingBackdrop ? 1.0 : 0.6

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: backdropPeekCard.width
                                            height: backdropPeekCard.height
                                            radius: backdropPeekCard.radius
                                        }
                                    }

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                    Behavior on z {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }

                                    StyledImage {
                                        visible: !WallpaperListener.isVideoPath(monitorStack.backdropPath) && !WallpaperListener.isGifPath(monitorStack.backdropPath)
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: (!WallpaperListener.isVideoPath(monitorStack.backdropPath) && !WallpaperListener.isGifPath(monitorStack.backdropPath)) ? (monitorStack.backdropPath || "") : ""
                                        sourceSize.width: backdropPeekCard.width * 2
                                        sourceSize.height: backdropPeekCard.height * 2
                                        cache: true
                                    }
                                    AnimatedImage {
                                        visible: WallpaperListener.isGifPath(monitorStack.backdropPath)
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: WallpaperListener.isGifPath(monitorStack.backdropPath) ? monitorStack.backdropUrl : ""
                                        asynchronous: true
                                        cache: true
                                        playing: false
                                    }
                                    StyledImage {
                                        visible: WallpaperListener.isVideoPath(monitorStack.backdropPath)
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            const ff = Wallpapers.videoFirstFrames[monitorStack.backdropPath]
                                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                        }
                                        cache: true
                                        Component.onCompleted: Wallpapers.ensureVideoFirstFrame(monitorStack.backdropPath)
                                    }

                                    // Backdrop label
                                    Rectangle {
                                        visible: monitorStack.showingBackdrop
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: Appearance.sizes.spacingSmall
                                        width: bdLabelRow.implicitWidth + Appearance.sizes.spacingSmall * 2
                                        height: bdLabelRow.implicitHeight + 4
                                        radius: height / 2
                                        color: Qt.rgba(0, 0, 0, 0.65)
                                        Row {
                                            id: bdLabelRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            MaterialSymbol {
                                                text: "blur_on"
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: Translation.tr("Backdrop")
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: {
                                            multiMonitorPanel.selectedMonitor = monitorStack.monName
                                            monitorStack.showingBackdrop = !monitorStack.showingBackdrop
                                            multiMonitorPanel.backdropViewActive = monitorStack.showingBackdrop
                                        }
                                    }

                                    // Selection border overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        visible: monitorStack.showingBackdrop && monitorStack.isSelected
                                        border.width: 2
                                        border.color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
                                    }
                                }

                                // Main wallpaper card
                                Rectangle {
                                    id: monitorCard
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: monitorStack.cardHeight * monitorStack.aspectRatio
                                    height: monitorStack.cardHeight
                                    z: monitorStack.showingBackdrop ? 0 : 1

                                    radius: Appearance.rounding.small
                                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                         : Appearance.colors.colLayer1
                                    border.width: monitorStack.isSelected && !monitorStack.showingBackdrop
                                        ? (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 2) : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 0)
                                    border.color: monitorStack.isSelected && !monitorStack.showingBackdrop
                                        ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary)
                                        : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent")
                                    clip: true

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: monitorCard.width
                                            height: monitorCard.height
                                            radius: monitorCard.radius
                                        }
                                    }

                                    scale: monitorStack.isSelected ? 1.0 : (monCardMa.containsMouse ? 0.97 : 0.93)
                                    opacity: monitorStack.isSelected ? 1.0 : (monCardMa.containsMouse ? 0.95 : 0.8)
                                    Behavior on scale {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }

                                    MouseArea {
                                        id: monCardMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            multiMonitorPanel.selectedMonitor = monitorStack.monName
                                            if (mouse.button === Qt.RightButton) {
                                                monitorStack.showingBackdrop = !monitorStack.showingBackdrop
                                                multiMonitorPanel.backdropViewActive = monitorStack.showingBackdrop
                                            } else {
                                                monitorStack.showingBackdrop = false
                                                multiMonitorPanel.backdropViewActive = false
                                            }
                                        }
                                    }

                                    // Static image
                                    StyledImage {
                                        visible: !monitorStack.isGif && !monitorStack.isVideo
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: (!monitorStack.isGif && !monitorStack.isVideo) ? (monitorStack.wpPath || "") : ""
                                        sourceSize.width: monitorCard.width * 2
                                        sourceSize.height: monitorCard.height * 2
                                        cache: true
                                    }

                                    // Video first-frame (frozen)
                                    StyledImage {
                                        visible: monitorStack.isVideo
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            const ff = Wallpapers.videoFirstFrames[monitorStack.wpPath]
                                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                        }
                                        cache: true
                                        Component.onCompleted: Wallpapers.ensureVideoFirstFrame(monitorStack.wpPath)
                                    }

                                    // GIF
                                    AnimatedImage {
                                        visible: monitorStack.isGif
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            if (!monitorStack.isGif || !monitorStack.wpPath) return ""
                                            const p = monitorStack.wpPath
                                            return p.startsWith("file://") ? p : "file://" + p
                                        }
                                        asynchronous: true
                                        cache: true
                                        playing: false
                                    }

                                    // Media type badge
                                    Rectangle {
                                        visible: monitorStack.isVideo || monitorStack.isGif
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: Appearance.sizes.spacingSmall
                                        width: mediaBadgeRow.implicitWidth + Appearance.sizes.spacingSmall * 2
                                        height: mediaBadgeRow.implicitHeight + 4
                                        radius: height / 2
                                        color: Qt.rgba(0, 0, 0, 0.65)
                                        Row {
                                            id: mediaBadgeRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            MaterialSymbol {
                                                text: monitorStack.isVideo ? "movie" : "gif"
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: WallpaperListener.mediaTypeLabel(monitorStack.wpPath)
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: "white"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

                                    // Bottom gradient with monitor name
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: Math.max(monitorLabelCol.implicitHeight + 14, parent.height * 0.45)
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.35) }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                                        }
                                        ColumnLayout {
                                            id: monitorLabelCol
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottomMargin: Appearance.sizes.spacingSmall
                                            spacing: 0
                                            StyledText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: monitorStack.monName || ("Monitor " + (monitorStack.index + 1))
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: Font.Medium
                                                color: "white"
                                            }
                                            StyledText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: monitorStack.modelData.width + "\u00d7" + monitorStack.modelData.height
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Qt.rgba(1, 1, 1, 0.6)
                                            }
                                        }
                                    }

                                    // Selected check badge
                                    Rectangle {
                                        visible: monitorStack.isSelected && !monitorStack.showingBackdrop
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: Appearance.sizes.spacingSmall
                                        width: Appearance.font.pixelSize.normal + 2
                                        height: width
                                        radius: width / 2
                                        color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "check"
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
                                        }
                                    }

                                    // Custom wallpaper dot
                                    Rectangle {
                                        visible: (monitorStack.wpData.hasCustomWallpaper ?? false) && !monitorStack.isSelected
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 8; height: 8
                                        radius: 4
                                        color: Appearance.colors.colTertiary
                                    }

                                    // Selection border overlay (on top of image)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: monitorStack.isSelected ? 2 : 0
                                        border.color: Appearance.colors.colPrimary
                                        Behavior on border.width {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Split preview showing all monitors
                Rectangle {
                    id: splitPreviewCard
                    Layout.fillWidth: true
                    implicitHeight: splitPreviewCol.implicitHeight
                    radius: Appearance.rounding.normal
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : Appearance.colors.colLayer1
                    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
                    border.color: Appearance.angelEverywhere ? (Appearance.angel?.colCardBorder ?? Appearance.colors.colLayer0Border)
                               : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border)
                               : Appearance.colors.colLayer0Border
                    clip: true

                    ColumnLayout {
                        id: splitPreviewCol
                        anchors { left: parent.left; right: parent.right }
                        spacing: 0

                        // Split preview row — all monitors side by side
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 190
                            clip: true

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Appearance.sizes.spacingSmall
                                spacing: Appearance.sizes.spacingSmall

                                Repeater {
                                    model: Quickshell.screens

                                    Rectangle {
                                        id: splitMonCard
                                        required property var modelData
                                        required property int index

                                        readonly property string monName: WallpaperListener.getMonitorName(modelData) ?? ""
                                        readonly property var wpData: WallpaperListener.effectivePerMonitor[monName] ?? { path: "" }
                                        readonly property string wpPath: wpData.path || (Config.options?.background?.wallpaperPath ?? "")
                                        readonly property bool isSelected: monName === multiMonitorPanel.selectedMonitor
                                        readonly property bool isGif: WallpaperListener.isGifPath(wpPath)
                                        readonly property bool isVideo: WallpaperListener.isVideoPath(wpPath)
                                        readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)

                                        onWpPathChanged: if (isVideo) Wallpapers.ensureVideoFirstFrame(wpPath)

                                        Layout.fillHeight: true
                                        Layout.preferredWidth: height * aspectRatio
                                        Layout.fillWidth: true

                                        radius: Appearance.rounding.small
                                        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                             : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                             : Appearance.colors.colLayer1
                                        border.width: splitMonCard.isSelected
                                            ? (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 2) : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 0)
                                        border.color: splitMonCard.isSelected
                                            ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary)
                                            : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent")
                                        clip: true

                                        scale: splitMonCard.isSelected ? 1.0 : 0.95
                                        opacity: splitMonCard.isSelected ? 1.0 : 0.75
                                        Behavior on scale {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                        Behavior on opacity {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            hoverEnabled: true
                                            onClicked: multiMonitorPanel.selectedMonitor = splitMonCard.monName
                                        }

                                        // Static image
                                        StyledImage {
                                            visible: !splitMonCard.isGif && !splitMonCard.isVideo
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: (!splitMonCard.isGif && !splitMonCard.isVideo) ? (splitMonCard.wpPath || "") : ""
                                            sourceSize.width: splitMonCard.width * 2
                                            sourceSize.height: splitMonCard.height * 2
                                            cache: true
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: splitMonCard.width
                                                    height: splitMonCard.height
                                                    radius: splitMonCard.radius
                                                }
                                            }
                                        }

                                        // GIF
                                        AnimatedImage {
                                            visible: splitMonCard.isGif
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: {
                                                if (!splitMonCard.isGif || !splitMonCard.wpPath) return ""
                                                const p = splitMonCard.wpPath
                                                return p.startsWith("file://") ? p : "file://" + p
                                            }
                                            asynchronous: true
                                            cache: true
                                            playing: false
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: splitMonCard.width
                                                    height: splitMonCard.height
                                                    radius: splitMonCard.radius
                                                }
                                            }
                                        }

                                        // Video first-frame (frozen)
                                        StyledImage {
                                            visible: splitMonCard.isVideo
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: {
                                                const ff = Wallpapers.videoFirstFrames[splitMonCard.wpPath]
                                                return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                            }
                                            cache: true
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: splitMonCard.width
                                                    height: splitMonCard.height
                                                    radius: splitMonCard.radius
                                                }
                                            }
                                            Component.onCompleted: Wallpapers.ensureVideoFirstFrame(splitMonCard.wpPath)
                                        }

                                        // Bottom gradient overlay with monitor name
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: Math.max(splitMonLabel.implicitHeight + 12, parent.height * 0.4)
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.35) }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                                            }

                                            ColumnLayout {
                                                id: splitMonLabel
                                                anchors.bottom: parent.bottom
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.bottomMargin: Appearance.sizes.spacingSmall
                                                spacing: 0
                                                StyledText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: splitMonCard.monName || ("Monitor " + (splitMonCard.index + 1))
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    font.weight: Font.Medium
                                                    color: "white"
                                                }
                                                StyledText {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: {
                                                        const custom = splitMonCard.wpData.hasCustomWallpaper ?? false
                                                        return custom ? Translation.tr("Custom") : Translation.tr("Global")
                                                    }
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: Qt.rgba(1, 1, 1, 0.6)
                                                }
                                            }
                                        }

                                        // Selected indicator
                                        Rectangle {
                                            visible: splitMonCard.isSelected
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: Appearance.sizes.spacingSmall
                                            width: Appearance.font.pixelSize.normal + 2
                                            height: width
                                            radius: width / 2
                                            color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
                                            }
                                        }

                                        // Media badge
                                        Rectangle {
                                            visible: splitMonCard.isVideo || splitMonCard.isGif
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: Appearance.sizes.spacingSmall
                                            width: splitBadgeRow.implicitWidth + Appearance.sizes.spacingSmall * 2
                                            height: splitBadgeRow.implicitHeight + 4
                                            radius: height / 2
                                            color: Qt.rgba(0, 0, 0, 0.65)
                                            Row {
                                                id: splitBadgeRow
                                                anchors.centerIn: parent
                                                spacing: 3
                                                MaterialSymbol {
                                                    text: splitMonCard.isVideo ? "movie" : "gif"
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: "white"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                                StyledText {
                                                    text: WallpaperListener.mediaTypeLabel(splitMonCard.wpPath)
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: "white"
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }
                                        }

                                        // Selection border overlay (on top of image)
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: parent.radius
                                            color: "transparent"
                                            border.width: splitMonCard.isSelected ? 2 : 0
                                            border.color: Appearance.colors.colPrimary
                                            Behavior on border.width {
                                                enabled: Appearance.animationsEnabled
                                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Controls section for selected monitor
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.margins: 12
                            Layout.topMargin: 10
                            Layout.bottomMargin: 12
                            spacing: Appearance.sizes.spacingSmall

                            // Wallpaper path
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                opacity: 0.7
                                text: multiMonitorPanel.selMonPath ? FileUtils.trimFileProtocol(multiMonitorPanel.selMonPath) : Translation.tr("No wallpaper set")
                            }

                            // Primary action row: Change (wide) + Random + Reset
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.spacingSmall

                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 3
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "wallpaper"
                                    mainText: Translation.tr("Change")
                                    colBackground: Appearance.colors.colPrimaryContainer
                                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                    colRipple: Appearance.colors.colPrimaryContainerActive
                                    mainContentComponent: Component {
                                        StyledText {
                                            text: Translation.tr("Change")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                    }
                                    onClicked: {
                                        const mon = multiMonitorPanel.selectedMonitor
                                        if (mon) {
                                            Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
                                            Config.setNestedValue("wallpaperSelector.targetMonitor", mon)
                                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
                                        }
                                    }
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 2
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "shuffle"
                                    mainText: Translation.tr("Random")
                                    onClicked: {
                                        const mon = multiMonitorPanel.selectedMonitor
                                        if (mon) {
                                            Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, mon)
                                        }
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Set a random wallpaper from the current folder for this monitor")
                                    }
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 2
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "restart_alt"
                                    mainText: Translation.tr("Reset")
                                    onClicked: {
                                        const mon = multiMonitorPanel.selectedMonitor
                                        if (!mon) return
                                        const globalPath = Config.options?.background?.wallpaperPath ?? ""
                                        if (globalPath) {
                                            Wallpapers.select(globalPath, Appearance.m3colors.darkmode, mon)
                                        }
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Reset this monitor to use the global wallpaper")
                                    }
                                }
                            }

                            // Secondary row: Apply all + Change backdrop
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.spacingSmall

                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "select_all"
                                    mainText: Translation.tr("Apply to all")
                                    onClicked: {
                                        const globalPath = Config.options?.background?.wallpaperPath ?? ""
                                        if (globalPath) {
                                            Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                                        }
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Apply the global wallpaper to all monitors")
                                    }
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "blur_on"
                                    mainText: Translation.tr("Change backdrop")
                                    visible: multiMonitorPanel.backdropEnabled
                                    onClicked: {
                                        Config.setNestedValue("wallpaperSelector.selectionTarget", "backdrop")
                                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Change the backdrop wallpaper (used for overview/blur)")
                                    }
                                }
                            }

                            // Derive theme colors from backdrop
                            ConfigSwitch {
                                visible: multiMonitorPanel.backdropEnabled
                                buttonIcon: "palette"
                                text: Translation.tr("Derive theme colors from backdrop")
                                checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                                onCheckedChanged: {
                                    Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                                    // Always regenerate — script reads useBackdropForColors from config
                                    colorRegenTimer.restart()
                                }
                            }
                        }
                    }
                }

                // Info bar
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 4

                    MaterialSymbol {
                        text: "info"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        opacity: 0.5
                    }
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller - 1
                        color: Appearance.colors.colSubtext
                        opacity: 0.5
                        text: Translation.tr("%1 monitors detected").arg(WallpaperListener.screenCount) + "  ·  " + Translation.tr("Ctrl+Alt+T targets focused output")
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "screenshot_monitor"
        title: Translation.tr("Bar & screen")

        SettingsGroup {
            ConfigRow {
                ContentSubsection {
                    title: Translation.tr("Bar position")
                    ConfigSelectionArray {
                        currentValue: ((Config.options?.bar?.bottom ?? false) ? 1 : 0) | ((Config.options?.bar?.vertical ?? false) ? 2 : 0)
                        onSelected: newValue => {
                            Config.setNestedValue("bar.bottom", (newValue & 1) !== 0)
                            Config.setNestedValue("bar.vertical", (newValue & 2) !== 0)
                        }
                        options: [
                            {
                                displayName: Translation.tr("Top"),
                                icon: "arrow_upward",
                                value: 0 // bottom: false, vertical: false
                            },
                            {
                                displayName: Translation.tr("Left"),
                                icon: "arrow_back",
                                value: 2 // bottom: false, vertical: true
                            },
                            {
                                displayName: Translation.tr("Bottom"),
                                icon: "arrow_downward",
                                value: 1 // bottom: true, vertical: false
                            },
                            {
                                displayName: Translation.tr("Right"),
                                icon: "arrow_forward",
                                value: 3 // bottom: true, vertical: true
                            }
                        ]
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Bar style")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.cornerStyle ?? 0
                        onSelected: newValue => {
                            // HUG mode (0) is incompatible with Angel style — revert to Float
                            if (newValue === 0 && Appearance.angelEverywhere) {
                                Config.setNestedValue("bar.cornerStyle", 1);
                                return;
                            }
                            Config.setNestedValue("bar.cornerStyle", newValue);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Hug"),
                                icon: "line_curve",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Float"),
                                icon: "page_header",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("Rect"),
                                icon: "toolbar",
                                value: 2
                            }
                        ]
                    }
                }
            }

            ConfigRow {
                ContentSubsection {
                    title: Translation.tr("Screen round corner")

                    ConfigSelectionArray {
                        currentValue: Config.options?.appearance?.fakeScreenRounding ?? 0
                        onSelected: newValue => {
                            Config.setNestedValue("appearance.fakeScreenRounding", newValue)
                        }
                        options: [
                            {
                                displayName: Translation.tr("No"),
                                icon: "close",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Yes"),
                                icon: "check",
                                value: 1
                            },
                            {
                                displayName: Translation.tr("When not fullscreen"),
                                icon: "fullscreen_exit",
                                value: 2
                            }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Wallpaper mode")

                    ConfigSelectionArray {
                        currentValue: Config.options?.background?.backdrop?.hideWallpaper ? 1 : 0
                        onSelected: newValue => {
                            Config.setNestedValue("background.backdrop.hideWallpaper", newValue === 1);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Normal"),
                                icon: "image",
                                value: 0
                            },
                            {
                                displayName: Translation.tr("Backdrop only"),
                                icon: "blur_on",
                                value: 1
                            }
                        ]
                    }
                }
            }
        }
    }

    // Game Mode
    SettingsCardSection {
        expanded: false
        icon: "sports_esports"
        title: Translation.tr("Game Mode")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "fullscreen"
                text: Translation.tr("Auto-detect fullscreen")
                checked: Config.options?.gameMode?.autoDetect ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.autoDetect", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Automatically enable Game Mode when apps go fullscreen")
                }
            }

            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Disable animations")
                checked: Config.options?.gameMode?.disableAnimations ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableAnimations", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off UI animations when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Disable effects")
                checked: Config.options?.gameMode?.disableEffects ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableEffects", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off blur and shadows when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Disable Niri animations")
                checked: Config.options?.gameMode?.disableNiriAnimations ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableNiriAnimations", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Turn off compositor animations when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "visibility_off"
                text: Translation.tr("Disable Discover overlay")
                checked: Config.options?.gameMode?.disableDiscoverOverlay ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableDiscoverOverlay", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Stop discover-overlay while Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "visibility_off"
                text: Translation.tr("Minimal mode")
                checked: Config.options?.gameMode?.minimalMode ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.minimalMode", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Make panels transparent and hide backgrounds for maximum performance")
                }
            }
        }
    }

    // Quick Actions
    SettingsCardSection {
        expanded: false
        icon: "bolt"
        title: Translation.tr("Quick Actions")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "refresh"
                    mainText: Translation.tr("Reload shell")
                    onClicked: Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "terminal"
                    mainText: Translation.tr("Open config")
                    onClicked: Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`)
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "keyboard"
                    mainText: Translation.tr("Shortcuts")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "cheatsheet", "toggle"])
                }
            }

            SettingsSwitch {
                buttonIcon: "notifications_active"
                text: Translation.tr("Show reload toasts")
                checked: Config.options?.reloadToasts?.enable ?? true
                onCheckedChanged: Config.setNestedValue("reloadToasts.enable", checked)
                StyledToolTip {
                    text: Translation.tr("Show toast notifications when Quickshell or Niri config reloads.\nErrors are always shown.")
                }
            }

            SettingsSwitch {
                buttonIcon: "sports_esports"
                text: Translation.tr("Hide reload toasts in Game Mode")
                checked: Config.options?.gameMode?.disableReloadToasts ?? true
                onCheckedChanged: {
                    Config.setNestedValue("gameMode.disableReloadToasts", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Automatically suppress reload toasts when Game Mode is active")
                }
            }

            SettingsSwitch {
                buttonIcon: "help"
                text: Translation.tr("Confirm before closing windows")
                checked: Config.options?.closeConfirm?.enabled ?? false
                onCheckedChanged: {
                    Config.setNestedValue("closeConfirm.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Show a confirmation dialog when closing windows with Super+Q")
                }
            }
        }
    }

    // Subtle footer
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.sizes.spacingSmall
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        opacity: 0.6
        text: Translation.tr("More options in other tabs • Config: %1").arg(FileUtils.trimFileProtocol(Directories.shellConfigPath))
    }
}
