pragma ComponentBehavior: Bound
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
    readonly property string currentWpUrl: {
        if (!currentWallpaperPath) return ""
        return currentWallpaperPath.startsWith("file://") ? currentWallpaperPath : "file://" + currentWallpaperPath
    }
    readonly property bool wpIsVideo: WallpaperListener.isVideoPath(currentWallpaperPath)
    readonly property bool wpIsGif: WallpaperListener.isGifPath(currentWallpaperPath)

    // ─── Hero section: wallpaper preview + thumbnail grid (Win11 style) ───
    Item {
        Layout.fillWidth: true
        implicitHeight: heroRow.implicitHeight

        RowLayout {
            id: heroRow
            anchors { left: parent.left; right: parent.right }
            spacing: 16

            // LEFT: Current wallpaper preview in monitor frame
            Rectangle {
                id: monitorFrame
                Layout.preferredWidth: Math.min(280, (heroRow.width - 16) * 0.42)
                Layout.preferredHeight: Layout.preferredWidth * 0.64
                radius: Looks.radius.large
                color: Looks.colors.bg0
                border.width: 6
                border.color: Looks.colors.bg2Base
                clip: true

                // Shadow beneath the frame
                WRectangularShadow {
                    target: monitorFrame
                    opacity: 0.5
                }

                // Wallpaper image
                Image {
                    id: heroImg
                    visible: !root.wpIsGif && !root.wpIsVideo
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    fillMode: Image.PreserveAspectCrop
                    source: visible ? root.currentWpUrl : ""
                    asynchronous: true
                    cache: false
                    sourceSize.width: 400
                    sourceSize.height: 260
                }
                AnimatedImage {
                    visible: root.wpIsGif
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    fillMode: Image.PreserveAspectCrop
                    source: visible ? root.currentWpUrl : ""
                    asynchronous: true
                    cache: false
                    playing: visible
                }
                Image {
                    visible: root.wpIsVideo
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    fillMode: Image.PreserveAspectCrop
                    source: {
                        const ff = Wallpapers.videoFirstFrames[root.currentWallpaperPath]
                        return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                    }
                    asynchronous: true
                    cache: false
                    Component.onCompleted: Wallpapers.ensureVideoFirstFrame(root.currentWallpaperPath)
                }

                // Monitor stand
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: -1
                    width: 30
                    height: 8
                    color: Looks.colors.bg2Base
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    width: 50
                    height: 4
                    radius: 2
                    color: Looks.colors.bg2Base
                }

                // Action overlay buttons (bottom-right)
                Row {
                    anchors { bottom: parent.bottom; right: parent.right; margins: 10 }
                    spacing: 6

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: heroRandomMa.containsMouse ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0, 0, 0, 0.5)
                        FluentIcon {
                            anchors.centerIn: parent
                            icon: "arrow-shuffle"
                            implicitSize: 14
                            color: "white"
                        }
                        MouseArea {
                            id: heroRandomMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: {
                                const mon = root.multiMonitorEnabled ? root.targetMonitor : ""
                                Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, mon)
                            }
                        }
                        WToolTip { visible: heroRandomMa.containsMouse; text: Translation.tr("Random") }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: heroDarkMa.containsMouse ? Qt.rgba(0, 0, 0, 0.7) : Qt.rgba(0, 0, 0, 0.5)
                        FluentIcon {
                            anchors.centerIn: parent
                            icon: Appearance.m3colors.darkmode ? "weather-moon" : "weather-sunny"
                            implicitSize: 14
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
            }

            // RIGHT: Wallpaper thumbnail grid
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                WText {
                    text: Translation.tr("Select a wallpaper")
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.regular
                    color: Looks.colors.subfg
                }

                // Thumbnail grid
                GridView {
                    id: wpGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: cellHeight * 2 + 6
                    Layout.maximumHeight: cellHeight * 2 + 6
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 100)))
                    cellHeight: 68
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Wallpapers.folderModel

                    delegate: Item {
                        id: gridThumb
                        required property int index
                        required property string filePath
                        required property string fileName
                        required property bool fileIsDir
                        required property url fileUrl

                        readonly property bool isCurrent: filePath === root.currentWallpaperPath
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
                            Behavior on scale { animation: Looks.transition.hover.createObject(this) }

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
                                visible: !gridThumb.fileIsDir && !WallpaperListener.isVideoPath(gridThumb.filePath)
                                anchors.fill: parent
                                anchors.margins: thumbRect.border.width
                                fillMode: Image.PreserveAspectCrop
                                source: visible ? gridThumb.thumbSource : ""
                                sourceSize.width: 160
                                sourceSize.height: 110
                                cache: true
                                asynchronous: true
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
                                width: 16; height: 16; radius: 8
                                color: Looks.colors.accent
                                FluentIcon { anchors.centerIn: parent; icon: "checkmark"; implicitSize: 9; color: Looks.colors.accentFg }
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
                                    const mon = root.multiMonitorEnabled ? root.targetMonitor : ""
                                    Wallpapers.select(gridThumb.filePath, Appearance.m3colors.darkmode, mon)
                                }
                            }

                            WToolTip { visible: gridMa.containsMouse; text: gridThumb.fileName }
                        }
                    }
                }

                // Open full selector link
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
                        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
                    }
                }
            }
        }
    }

    // ─── Settings cards below the hero ───
    WSettingsCard {
        title: Translation.tr("Wallpaper & Colors")
        icon: "image-filled"

        // Per-monitor toggle
        WSettingsSwitch {
            label: Translation.tr("Per-monitor wallpapers")
            icon: "monitor"
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

                        Behavior on color { animation: Looks.transition.color.createObject(this) }

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
                ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`)
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
                onClicked: Quickshell.execDetached(["/usr/bin/setsid", "/usr/bin/fish", "-c", "qs kill -c ii; sleep 0.3; qs -c ii"])
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
                onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "cheatsheet", "toggle"])
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
