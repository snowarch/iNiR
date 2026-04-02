pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 0
    pageTitle: Translation.tr("Quick Settings")
    pageIcon: "flash-on"
    pageDescription: Translation.tr("Frequently used settings and quick actions")
    
    // Multi-monitor state
    readonly property bool multiMonitorEnabled: Config.options?.background?.multiMonitor?.enable ?? false

    // Target monitor for wallpaper operations
    property string targetMonitor: {
        if (!multiMonitorEnabled) return ""
        const primary = GlobalStates.primaryScreen
        const primaryName = primary ? (WallpaperListener.getMonitorName(primary) ?? "") : ""
        if (primaryName) return primaryName
        const focused = WallpaperListener.getFocusedMonitor()
        if (focused) return focused
        const screens = Quickshell.screens
        if (!screens || screens.length === 0) return ""
        return WallpaperListener.getMonitorName(screens[0]) ?? ""
    }

    // Current wallpaper path helper
    readonly property string currentWallpaperPath: {
        if (multiMonitorEnabled && targetMonitor) {
            const data = WallpaperListener.effectivePerMonitor[targetMonitor] ?? {}
            return data.path || (Config.options?.background?.wallpaperPath ?? "")
        }
        const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
        if (useMain) return Config.options?.background?.wallpaperPath ?? ""
        return Config.options?.waffles?.background?.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? ""
    }
    readonly property string displayWallpaperPath: root.selectedWallpaperPath.length > 0
        ? root.selectedWallpaperPath
        : root.currentWallpaperPath
    readonly property string currentWpUrl: {
        if (!displayWallpaperPath) return ""
        return displayWallpaperPath.startsWith("file://") ? displayWallpaperPath : "file://" + displayWallpaperPath
    }
    readonly property bool wpIsVideo: WallpaperListener.isVideoPath(displayWallpaperPath)
    readonly property bool wpIsGif: WallpaperListener.isGifPath(displayWallpaperPath)
    readonly property bool colorsOnlyMode: Config.options?.appearance?.wallpaperTheming?.colorsOnlyMode ?? false
    readonly property string previewWallpaperPath: Config.options?.appearance?.wallpaperTheming?.previewSourcePath ?? ""
    readonly property string selectedWallpaperPath: (root.colorsOnlyMode && root.previewWallpaperPath.length > 0)
        ? root.previewWallpaperPath
        : root.currentWallpaperPath

    function quickApplyTarget(): string {
        if (root.multiMonitorEnabled && root.targetMonitor.length > 0) return "main"
        return (Config.options?.waffles?.background?.useMainWallpaper ?? true) ? "main" : "waffle"
    }

    function applyQuickWallpaper(path: string): void {
        if (!path || path.length === 0) return
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
        for (let i = 0; i < count; i++) {
            if (model.get(i, "fileIsDir")) continue
            const filePath = model.get(i, "filePath")
            if (filePath && filePath.length > 0) candidates.push(filePath)
        }
        if (candidates.length === 0) return
        root.applyQuickWallpaper(candidates[Math.floor(Math.random() * candidates.length)])
    }

    // ─── Wallpaper preview (clean full-width design, like Material ii) ───
    Rectangle {
        id: wallpaperPreview
        Layout.fillWidth: true
        implicitHeight: 240
        radius: Looks.radius.large
        color: Looks.colors.bg1
        clip: true

        // Wallpaper image
        Image {
            id: heroImg
            visible: !root.wpIsGif && !root.wpIsVideo
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            source: visible ? root.currentWpUrl : ""
            asynchronous: true
            cache: false
            sourceSize.width: 600
            sourceSize.height: 340
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
                const ff = Wallpapers.videoFirstFrames[root.displayWallpaperPath]
                return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
            }
            asynchronous: true
            cache: false
            Component.onCompleted: Wallpapers.ensureVideoFirstFrame(root.displayWallpaperPath)
        }

        // Bottom gradient for overlay buttons
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 56
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
            }
        }

        // Action overlay buttons (bottom-right)
        Row {
            anchors { bottom: parent.bottom; right: parent.right; margins: 12 }
            spacing: 8

            Rectangle {
                width: 32; height: 32; radius: 16
                color: heroRandomMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { animation: ColorAnimation { duration: 100 } }
                FluentIcon {
                    anchors.centerIn: parent
                    icon: "arrow-sync"
                    implicitSize: 16
                    color: "white"
                }
                MouseArea {
                    id: heroRandomMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.applyRandomQuickWallpaper()
                }
                WToolTip { visible: heroRandomMa.containsMouse; text: Translation.tr("Random") }
            }

            Rectangle {
                width: 32; height: 32; radius: 16
                color: heroDarkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12)
                Behavior on color { animation: ColorAnimation { duration: 100 } }
                FluentIcon {
                    anchors.centerIn: parent
                    icon: Appearance.m3colors.darkmode ? "weather-moon" : "weather-sunny"
                    implicitSize: 16
                    color: "white"
                }
                MouseArea {
                    id: heroDarkMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        const dark = !Appearance.m3colors.darkmode
                        ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`)
                    }
                }
                WToolTip { visible: heroDarkMa.containsMouse; text: Appearance.m3colors.darkmode ? Translation.tr("Light mode") : Translation.tr("Dark mode") }
            }
        }

        // Colors-only mode indicator (bottom-left)
        Rectangle {
            visible: root.colorsOnlyMode
            anchors { left: parent.left; bottom: parent.bottom; margins: 10 }
            height: 24; radius: 12
            width: colorsOnlyLabel.implicitWidth + 20
            color: Qt.rgba(0, 0, 0, 0.55)
            WText {
                id: colorsOnlyLabel
                anchors.centerIn: parent
                text: root.previewWallpaperPath.length > 0 ? Translation.tr("Theme source") : Translation.tr("Colors only")
                font.pixelSize: Looks.font.pixelSize.tiny
                color: "white"
                font.weight: Font.Medium
            }
        }
    }

    // ─── Thumbnail grid ───
    WText {
        text: Translation.tr("Select a wallpaper")
        font.pixelSize: Looks.font.pixelSize.normal
        font.weight: Looks.font.weight.regular
        color: Looks.colors.subfg
        Layout.topMargin: 4
    }

    GridView {
        id: wpGrid
        Layout.fillWidth: true
        Layout.preferredHeight: cellHeight * 2 + 6
        cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 110)))
        cellHeight: 74
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Wallpapers.folderModel
        Component.onCompleted: Wallpapers.generateThumbnail("large")

        Connections {
            target: Wallpapers
            function onFolderChanged() {
                Wallpapers.generateThumbnail("large")
            }
        }

        delegate: Item {
            id: gridThumb
            required property int index
            required property string filePath
            required property string fileName
            required property bool fileIsDir

            readonly property bool isCurrent: filePath === root.selectedWallpaperPath
            readonly property string thumbSource: {
                if (fileIsDir) return ""
                const thumb = Wallpapers.getExpectedThumbnailPath(filePath, "large")
                if (thumb) return thumb.startsWith("file://") ? thumb : "file://" + thumb
                return filePath.startsWith("file://") ? filePath : "file://" + filePath
            }

            width: wpGrid.cellWidth
            height: wpGrid.cellHeight

            Rectangle {
                id: thumbRect
                anchors.fill: parent
                anchors.margins: 3
                radius: Looks.radius.medium
                color: gridThumb.fileIsDir ? Looks.colors.bg2Base : Looks.colors.bg1
                border.width: gridThumb.isCurrent ? 2 : (gridMa.containsMouse ? 1 : 0)
                border.color: gridThumb.isCurrent ? Looks.colors.accent : Looks.colors.bg2Border
                clip: true

                scale: gridMa.containsMouse ? 0.95 : 1.0
                Behavior on scale { animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.chromeHover : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.smooth } }

                // Folder
                ColumnLayout {
                    visible: gridThumb.fileIsDir
                    anchors.centerIn: parent
                    spacing: 2
                    FluentIcon { Layout.alignment: Qt.AlignHCenter; icon: "folder"; implicitSize: 20; color: Looks.colors.subfg }
                    WText {
                        Layout.alignment: Qt.AlignHCenter
                        text: gridThumb.fileName
                        font.pixelSize: Looks.font.pixelSize.tiny
                        color: Looks.colors.subfg
                        Layout.maximumWidth: thumbRect.width - 8
                        elide: Text.ElideRight
                    }
                }

                // Image thumb
                Image {
                    id: wpGridThumbImg
                    visible: !gridThumb.fileIsDir && !WallpaperListener.isVideoPath(gridThumb.filePath)
                    anchors.fill: parent
                    anchors.margins: thumbRect.border.width
                    fillMode: Image.PreserveAspectCrop
                    source: visible ? gridThumb.thumbSource : ""
                    sourceSize.width: 180
                    sourceSize.height: 120
                    cache: true
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Error && gridThumb.filePath)
                            source = gridThumb.filePath.startsWith("file://") ? gridThumb.filePath : "file://" + gridThumb.filePath
                    }
                    Connections {
                        target: Wallpapers
                        function onThumbnailGenerated(directory) {
                            if (wpGridThumbImg.status !== Image.Ready && gridThumb.filePath) {
                                wpGridThumbImg.source = ""
                                wpGridThumbImg.source = gridThumb.thumbSource
                            }
                        }
                    }
                }
                Image {
                    visible: !gridThumb.fileIsDir && WallpaperListener.isVideoPath(gridThumb.filePath)
                    anchors.fill: parent
                    anchors.margins: thumbRect.border.width
                    fillMode: Image.PreserveAspectCrop
                    source: {
                        if (!visible) return ""
                        const ff = Wallpapers.videoFirstFrames[gridThumb.filePath]
                        return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                    }
                    cache: true
                    asynchronous: true
                    Component.onCompleted: {
                        if (WallpaperListener.isVideoPath(gridThumb.filePath))
                            Wallpapers.ensureVideoFirstFrame(gridThumb.filePath)
                    }
                }

                // Check badge
                Rectangle {
                    visible: gridThumb.isCurrent && !gridThumb.fileIsDir
                    anchors { bottom: parent.bottom; right: parent.right; margins: 4 }
                    width: 18; height: 18; radius: 9
                    color: Looks.colors.accent
                    FluentIcon { anchors.centerIn: parent; icon: "checkmark"; implicitSize: 10; color: Looks.colors.accentFg }
                }

                MouseArea {
                    id: gridMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (gridThumb.fileIsDir) {
                            Wallpapers.setDirectory(gridThumb.filePath)
                            return
                        }
                        root.applyQuickWallpaper(gridThumb.filePath)
                    }
                }

                WToolTip { visible: gridMa.containsMouse; text: gridThumb.fileName }
            }
        }
    }

    // Browse all wallpapers button
    WButton {
        Layout.fillWidth: true
        text: Translation.tr("Browse all wallpapers")
        icon.name: "image"
        colBackground: Looks.colors.accent
        colBackgroundHover: Looks.colors.accentHover
        colBackgroundActive: Looks.colors.accentActive
        colForeground: Looks.colors.accentFg
        onClicked: {
            const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
            if (root.multiMonitorEnabled && root.targetMonitor) {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
                Config.setNestedValue("wallpaperSelector.targetMonitor", root.targetMonitor)
            } else {
                Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
            }
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
        }
    }

    // ─── Settings cards below the hero ───
    WSettingsCard {
        title: Translation.tr("Wallpaper & Colors")
        icon: "image-filled"

        // Per-monitor toggle
        WSettingsSwitch {
            label: Translation.tr("Per-monitor wallpapers")
            icon: "desktop"
            description: Translation.tr("Set different wallpapers for each monitor")
            checked: root.multiMonitorEnabled
            onCheckedChanged: {
                Config.setNestedValue("background.multiMonitor.enable", checked)
                if (!checked) {
                    const globalPath = Config.options?.background?.wallpaperPath ?? ""
                    if (globalPath) Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                }
            }
        }

        // Monitor selector (visible when per-monitor ON)
        Item {
            visible: root.multiMonitorEnabled
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 6
            implicitHeight: 50

            Row {
                anchors.centerIn: parent
                spacing: 8
                height: parent.height

                Repeater {
                    model: Quickshell.screens

                    Rectangle {
                        id: qkMonCard
                        required property var modelData
                        required property int index

                        readonly property string monName: WallpaperListener.getMonitorName(modelData) ?? ""
                        readonly property bool isSelected: monName === root.targetMonitor
                        readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)

                        width: parent.height * aspectRatio
                        height: parent.height
                        radius: Looks.radius.medium
                        color: isSelected ? Looks.colors.accent : (qkMonMa.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg2Base)
                        border.width: 1
                        border.color: isSelected ? Looks.colors.accent : Looks.colors.bg2Border

                        Behavior on color { animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                        WText {
                            anchors.centerIn: parent
                            text: qkMonCard.monName || ("Monitor " + (qkMonCard.index + 1))
                            font.pixelSize: Looks.font.pixelSize.tiny
                            font.weight: Font.Medium
                            color: qkMonCard.isSelected ? Looks.colors.accentFg : Looks.colors.fg
                        }

                        MouseArea {
                            id: qkMonMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: root.targetMonitor = qkMonCard.monName
                        }
                    }
                }
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Colors only mode")
            icon: "eyedropper"
            description: Translation.tr("Click thumbnails to apply only colors, without changing wallpaper")
            checked: root.colorsOnlyMode
            onCheckedChanged: {
                Config.setNestedValue("appearance.wallpaperTheming.colorsOnlyMode", checked)
                if (!checked)
                    Config.setNestedValue("appearance.wallpaperTheming.previewSourcePath", "")
            }
        }

        WSettingsDropdown {
            label: Translation.tr("Color scheme")
            icon: "dark-theme"
            description: Translation.tr("How colors are generated from wallpaper")
            currentValue: Config.options?.appearance?.palette?.type ?? "auto"
            options: [
                { value: "auto", displayName: Translation.tr("Auto") },
                { value: "scheme-content", displayName: Translation.tr("Content") },
                { value: "scheme-expressive", displayName: Translation.tr("Expressive") },
                { value: "scheme-fidelity", displayName: Translation.tr("Fidelity") },
                { value: "scheme-fruit-salad", displayName: Translation.tr("Fruit Salad") },
                { value: "scheme-monochrome", displayName: Translation.tr("Monochrome") },
                { value: "scheme-neutral", displayName: Translation.tr("Neutral") },
                { value: "scheme-rainbow", displayName: Translation.tr("Rainbow") },
                { value: "scheme-tonal-spot", displayName: Translation.tr("Tonal Spot") }
            ]
            onSelected: newValue => {
                Config.setNestedValue("appearance.palette.type", newValue)
                if (ThemeService.isAutoTheme) {
                    ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`)
                } else {
                    const primary = Appearance.m3colors.m3primary
                    const hex = "#" + ((1 << 24) | (Math.round(primary.r * 255) << 16) | (Math.round(primary.g * 255) << 8) | Math.round(primary.b * 255)).toString(16).slice(1)
                    MaterialThemeLoader.applySchemeVariant(hex, newValue)
                }
            }
        }

        WSettingsSpinBox {
            label: Translation.tr("Wallpaper color strength")
            icon: "eyedropper"
            description: Translation.tr("Controls how vivid wallpaper-derived accent colors are. 100% keeps the default balance; higher values produce richer accents.")
            suffix: "%"
            from: 60; to: 180; stepSize: 5
            value: Math.round((Config.options?.appearance?.wallpaperTheming?.colorStrength ?? 1.0) * 100)
            property bool _ready: false
            Component.onCompleted: _ready = true
            onValueChanged: {
                if (!_ready) return
                Config.setNestedValue("appearance.wallpaperTheming.colorStrength", value / 100)
                if (ThemeService.isAutoTheme)
                    ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch`)
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Transparency")
            icon: "auto"
            description: Translation.tr("Enable transparent UI elements")
            checked: Config.options?.appearance?.transparency?.enable ?? false
            onCheckedChanged: Config.setNestedValue("appearance.transparency.enable", checked)
        }
    }
    
    // Taskbar section (waffle-specific)
    WSettingsCard {
        title: Translation.tr("Taskbar")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Left-align apps")
            icon: "chevron-left"
            description: Translation.tr("Align taskbar apps to the left instead of center")
            checked: Config.options?.waffles?.bar?.leftAlignApps ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.leftAlignApps", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Tint app icons")
            icon: "dark-theme"
            description: Translation.tr("Apply accent color to taskbar icons")
            checked: Config.options?.waffles?.bar?.monochromeIcons ?? false
            onCheckedChanged: Config.setNestedValue("waffles.bar.monochromeIcons", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Taskbar icon size")
            icon: "desktop"
            suffix: "px"
            from: 20; to: 40; stepSize: 1
            value: Config.options?.waffles?.bar?.iconSize ?? 26
            onValueChanged: Config.setNestedValue("waffles.bar.iconSize", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Search app icon size")
            icon: "search"
            suffix: "px"
            from: 16; to: 40; stepSize: 1
            value: Config.options?.waffles?.bar?.searchIconSize ?? 24
            onValueChanged: Config.setNestedValue("waffles.bar.searchIconSize", value)
        }
        
        WSettingsDropdown {
            label: Translation.tr("Screen rounding")
            icon: "desktop"
            description: Translation.tr("Fake rounded corners for flat screens")
            currentValue: Config.options?.appearance?.fakeScreenRounding ?? 0
            options: [
                { value: 0, displayName: Translation.tr("None") },
                { value: 1, displayName: Translation.tr("Always") },
                { value: 2, displayName: Translation.tr("When not fullscreen") }
            ]
            onSelected: newValue => Config.setNestedValue("appearance.fakeScreenRounding", newValue)
        }
    }
    
    // Quick Actions section
    WSettingsCard {
        title: Translation.tr("Quick Actions")
        icon: "flash-on"
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Reload shell")
                icon.name: "arrow-sync"
                onClicked: Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
            }
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Open config")
                icon.name: "settings"
                onClicked: Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`)
            }
            
            WButton {
                Layout.fillWidth: true
                text: Translation.tr("Shortcuts")
                icon.name: "keyboard"
                onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "cheatsheet", "toggle"])
            }
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show reload notifications")
            icon: "alert"
            description: Translation.tr("Toast when Quickshell or Niri config reloads")
            checked: Config.options?.reloadToasts?.enable ?? true
            onCheckedChanged: Config.setNestedValue("reloadToasts.enable", checked)
        }
    }
}
