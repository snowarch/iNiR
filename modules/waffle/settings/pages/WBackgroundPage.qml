pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 3
    pageTitle: Translation.tr("Background")
    pageIcon: "image"
    pageDescription: Translation.tr("Wallpaper effects and backdrop settings for Waffle")
    
    // Shorthand for waffle background config
    readonly property var wBg: Config.options?.waffles?.background ?? {}
    readonly property var wEffects: wBg.effects ?? {}
    readonly property var wBackdrop: wBg.backdrop ?? {}
    
    WSettingsCard {
        title: Translation.tr("Wallpaper")
        icon: "image"
        
        WSettingsSwitch {
            label: Translation.tr("Use Material inir wallpaper")
            icon: "image"
            description: Translation.tr("Share wallpaper with Material inir family")
            checked: root.wBg.useMainWallpaper ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.useMainWallpaper", checked)
        }
        
        WSettingsButton {
            visible: !(root.wBg.useMainWallpaper ?? true)
            label: Translation.tr("Waffle wallpaper")
            icon: "image"
            buttonText: Translation.tr("Change")
            onButtonClicked: {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle")
                Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "wallpaperSelector", "toggle"])
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Per-monitor wallpapers")
            icon: "monitor"
            description: Translation.tr("Set different wallpapers for each monitor")
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
    }

    // Multi-monitor management card
    WSettingsCard {
        id: multiMonCard
        visible: Config.options?.background?.multiMonitor?.enable ?? false
        title: Translation.tr("Monitor Wallpapers")
        icon: "desktop"

        property string selectedMonitor: {
            const screens = Quickshell.screens
            if (!screens || screens.length === 0) return ""
            return WallpaperListener.getMonitorName(screens[0]) ?? ""
        }

        readonly property var selMonData: WallpaperListener.effectivePerMonitor[selectedMonitor] ?? { path: "", isVideo: false, isGif: false, isAnimated: false, hasCustomWallpaper: false }
        readonly property string selMonPath: selMonData.path || (Config.options?.background?.wallpaperPath ?? "")
        property bool showBackdropView: false

        readonly property string backdropPath: {
            const bd = Config.options?.waffles?.background?.backdrop ?? {}
            if (!(bd.useMainWallpaper ?? true) && bd.wallpaperPath) return bd.wallpaperPath
            return selMonPath
        }

        // Visual monitor layout
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 4
            implicitHeight: 140

            Rectangle {
                anchors.fill: parent
                radius: Looks.radius.small
                color: Looks.colors.bg1
                border.width: 1
                border.color: Looks.colors.bg2Border

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    height: parent.height - 12

                    Repeater {
                        model: Quickshell.screens

                        Rectangle {
                            id: wMonitorCard
                            required property var modelData
                            required property int index

                            readonly property string monName: WallpaperListener.getMonitorName(modelData) ?? ""
                            readonly property var wpData: WallpaperListener.effectivePerMonitor[monName] ?? { path: "" }
                            readonly property string wpPath: wpData.path || (Config.options?.background?.wallpaperPath ?? "")
                            readonly property bool isSelected: monName === multiMonCard.selectedMonitor
                            readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)

                            onWpPathChanged: if (WallpaperListener.isVideoPath(wpPath)) Wallpapers.ensureVideoFirstFrame(wpPath)

                            width: (parent.height) * aspectRatio
                            height: parent.height
                            radius: Looks.radius.small
                            color: "transparent"
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Looks.colors.accent : Looks.colors.bg2Border
                            clip: true

                            scale: isSelected ? 1.0 : (wMonCardMa.containsMouse ? 0.97 : 0.93)
                            opacity: isSelected ? 1.0 : (wMonCardMa.containsMouse ? 0.95 : 0.8)
                            Behavior on scale {
                                animation: Looks.transition.hover.createObject(this)
                            }
                            Behavior on opacity {
                                animation: Looks.transition.hover.createObject(this)
                            }
                            Behavior on border.color {
                                animation: Looks.transition.color.createObject(this)
                            }

                            MouseArea {
                                id: wMonCardMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: multiMonCard.selectedMonitor = wMonitorCard.monName
                            }

                            Image {
                                visible: !WallpaperListener.isVideoPath(wMonitorCard.wpPath) && !WallpaperListener.isGifPath(wMonitorCard.wpPath)
                                anchors.fill: parent
                                anchors.margins: wMonitorCard.border.width
                                fillMode: Image.PreserveAspectCrop
                                source: (!WallpaperListener.isVideoPath(wMonitorCard.wpPath) && !WallpaperListener.isGifPath(wMonitorCard.wpPath)) ? (wMonitorCard.wpPath || "") : ""
                                sourceSize.width: 200
                                sourceSize.height: 200
                                cache: true
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: wMonitorCard.width - wMonitorCard.border.width * 2
                                        height: wMonitorCard.height - wMonitorCard.border.width * 2
                                        radius: Math.max(0, Looks.radius.small - wMonitorCard.border.width)
                                    }
                                }
                            }
                            AnimatedImage {
                                visible: WallpaperListener.isGifPath(wMonitorCard.wpPath)
                                anchors.fill: parent
                                anchors.margins: wMonitorCard.border.width
                                fillMode: Image.PreserveAspectCrop
                                source: {
                                    if (!WallpaperListener.isGifPath(wMonitorCard.wpPath)) return ""
                                    const p = wMonitorCard.wpPath
                                    return p.startsWith("file://") ? p : "file://" + p
                                }
                                asynchronous: true
                                cache: true
                                playing: false
                            }
                            Image {
                                visible: WallpaperListener.isVideoPath(wMonitorCard.wpPath)
                                anchors.fill: parent
                                anchors.margins: wMonitorCard.border.width
                                fillMode: Image.PreserveAspectCrop
                                source: {
                                    const ff = Wallpapers.videoFirstFrames[wMonitorCard.wpPath]
                                    return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                }
                                cache: true
                                asynchronous: true
                                Component.onCompleted: Wallpapers.ensureVideoFirstFrame(wMonitorCard.wpPath)
                            }

                            // Media type badge (video/gif)
                            Rectangle {
                                visible: WallpaperListener.isAnimatedPath(wMonitorCard.wpPath)
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 4
                                width: wMediaBadgeRow.implicitWidth + 8
                                height: wMediaBadgeRow.implicitHeight + 4
                                radius: height / 2
                                color: Qt.rgba(0, 0, 0, 0.65)
                                Row {
                                    id: wMediaBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    FluentIcon {
                                        icon: WallpaperListener.isVideoPath(wMonitorCard.wpPath) ? "video" : "gif"
                                        implicitSize: Looks.font.pixelSize.small - 2
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    WText {
                                        text: WallpaperListener.mediaTypeLabel(wMonitorCard.wpPath)
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: "white"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Bottom label gradient overlay
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: Math.max(wMonLabelCol.implicitHeight + 12, parent.height * 0.45)
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.35) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                                }
                                ColumnLayout {
                                    id: wMonLabelCol
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: 4
                                    spacing: 0
                                    WText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: wMonitorCard.monName || ("Monitor " + (wMonitorCard.index + 1))
                                        font.pixelSize: Looks.font.pixelSize.small
                                        font.weight: Font.Medium
                                        color: "white"
                                    }
                                    WText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: wMonitorCard.modelData.width + "×" + wMonitorCard.modelData.height
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                    }
                                }
                            }

                            // Selected check badge
                            Rectangle {
                                visible: wMonitorCard.isSelected
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                width: 16; height: 16
                                radius: 8
                                color: Looks.colors.accent
                                FluentIcon {
                                    anchors.centerIn: parent
                                    icon: "checkmark"
                                    implicitSize: 10
                                    color: Looks.colors.accentFg
                                }
                            }

                            // Custom wallpaper indicator dot
                            Rectangle {
                                visible: (wMonitorCard.wpData.hasCustomWallpaper ?? false) && !wMonitorCard.isSelected
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 7; height: 7
                                radius: 4
                                color: Looks.colors.accent
                                opacity: 0.8
                            }
                        }
                    }
                }
            }
        }

        // Unified preview + controls card
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 4
            implicitHeight: wMonPreviewCard.implicitHeight

            Rectangle {
                id: wMonPreviewCard
                anchors.fill: parent
                implicitHeight: wMonPreviewCol.implicitHeight
                radius: Looks.radius.large
                color: Looks.colors.bg2Base
                border.width: 1
                border.color: Looks.colors.bg2Border
                clip: true

                readonly property string displayPath: multiMonCard.showBackdropView ? multiMonCard.backdropPath : multiMonCard.selMonPath
                readonly property string wpUrl: {
                    const path = displayPath
                    if (!path) return ""
                    return path.startsWith("file://") ? path : "file://" + path
                }
                readonly property bool isVideo: WallpaperListener.isVideoPath(displayPath)
                readonly property bool isGif: WallpaperListener.isGifPath(displayPath)

                Connections {
                    target: multiMonCard
                    function onSelMonPathChanged() {
                        if (wMonPreviewCard.isVideo) Wallpapers.ensureVideoFirstFrame(wMonPreviewCard.displayPath)
                    }
                    function onBackdropPathChanged() {
                        if (WallpaperListener.isVideoPath(multiMonCard.backdropPath)) Wallpapers.ensureVideoFirstFrame(multiMonCard.backdropPath)
                    }
                }

                ColumnLayout {
                    id: wMonPreviewCol
                    anchors { left: parent.left; right: parent.right }
                    spacing: 0

                    // Hero preview area — frozen first frame for videos/GIFs to save resources
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        clip: true

                        Image {
                            id: wMonPreviewImage
                            visible: !wMonPreviewCard.isGif && !wMonPreviewCard.isVideo
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: visible ? wMonPreviewCard.wpUrl : ""
                            asynchronous: true
                            cache: false
                        }

                        AnimatedImage {
                            id: wMonPreviewGif
                            visible: wMonPreviewCard.isGif
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: visible ? wMonPreviewCard.wpUrl : ""
                            asynchronous: true
                            cache: false
                            playing: false
                        }

                        Image {
                            id: wMonPreviewVideo
                            visible: wMonPreviewCard.isVideo
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: {
                                const ff = Wallpapers.videoFirstFrames[wMonPreviewCard.displayPath]
                                return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                            }
                            asynchronous: true
                            cache: false
                            Component.onCompleted: Wallpapers.ensureVideoFirstFrame(wMonPreviewCard.displayPath)
                        }

                        // Bottom gradient overlay with monitor info
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: parent.height * 0.55
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.4) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                            }

                            RowLayout {
                                anchors {
                                    bottom: parent.bottom; left: parent.left; right: parent.right
                                    margins: 10; bottomMargin: 8
                                }
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    WText {
                                        text: multiMonCard.selectedMonitor || Translation.tr("No monitor selected")
                                        font.pixelSize: Looks.font.pixelSize.large
                                        font.weight: Font.DemiBold
                                        color: "#ffffff"
                                    }
                                    WText {
                                        text: {
                                            if (multiMonCard.showBackdropView) return Translation.tr("Backdrop")
                                            const custom = multiMonCard.selMonData.hasCustomWallpaper ?? false
                                            const animated = multiMonCard.selMonData.isAnimated ?? false
                                            let label = custom ? Translation.tr("Custom wallpaper") : Translation.tr("Global wallpaper")
                                            if (animated) label += " · " + WallpaperListener.mediaTypeLabel(multiMonCard.selMonPath)
                                            return label
                                        }
                                        font.pixelSize: Looks.font.pixelSize.small - 1
                                        color: Qt.rgba(1, 1, 1, 0.7)
                                    }
                                }

                                // Media type badge
                                Rectangle {
                                    visible: wMonPreviewCard.isVideo || wMonPreviewCard.isGif
                                    width: wPreviewBadgeRow.implicitWidth + 8
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                    Row {
                                        id: wPreviewBadgeRow
                                        anchors.centerIn: parent
                                        spacing: 3
                                        FluentIcon {
                                            icon: WallpaperListener.isVideoPath(wMonPreviewCard.displayPath) ? "video" : "gif"
                                            implicitSize: 8
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        WText {
                                            text: WallpaperListener.mediaTypeLabel(wMonPreviewCard.displayPath)
                                            font.pixelSize: Looks.font.pixelSize.small - 2
                                            color: "#ffffff"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Looks.colors.bg2Border
                        opacity: 0.5
                    }

                    // Controls section
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        Layout.topMargin: 10
                        Layout.bottomMargin: 12
                        spacing: 8

                        // Wallpaper path
                        WText {
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                            opacity: 0.7
                            text: {
                                const path = multiMonCard.showBackdropView ? multiMonCard.backdropPath : multiMonCard.selMonPath
                                return path ? String(path).replace(/^file:\/\//, "") : Translation.tr("No wallpaper set")
                            }
                        }

                        // Primary actions: Change + Random (wallpaper mode)
                        RowLayout {
                            visible: !multiMonCard.showBackdropView
                            Layout.fillWidth: true
                            spacing: 6
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Change")
                                icon.name: "image"
                                colBackground: Looks.colors.accent
                                colBackgroundHover: Looks.colors.accentHover
                                colBackgroundActive: Looks.colors.accentActive
                                colForeground: Looks.colors.accentFg
                                onClicked: {
                                    const mon = multiMonCard.selectedMonitor
                                    if (mon) {
                                        Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
                                        Config.setNestedValue("wallpaperSelector.targetMonitor", mon)
                                        Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "wallpaperSelector", "toggle"])
                                    }
                                }
                            }
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Random")
                                icon.name: "arrow-shuffle"
                                colBackground: Looks.colors.bg2
                                colBackgroundHover: Looks.colors.bg2Hover
                                colBackgroundActive: Looks.colors.bg2Active
                                colForeground: Looks.colors.fg
                                onClicked: {
                                    const mon = multiMonCard.selectedMonitor
                                    if (mon) {
                                        Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, mon)
                                    }
                                }
                            }
                        }

                        // Primary actions: Change backdrop + Back (backdrop mode)
                        RowLayout {
                            visible: multiMonCard.showBackdropView
                            Layout.fillWidth: true
                            spacing: 6
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Change backdrop")
                                icon.name: "image"
                                colBackground: Looks.colors.accent
                                colBackgroundHover: Looks.colors.accentHover
                                colBackgroundActive: Looks.colors.accentActive
                                colForeground: Looks.colors.accentFg
                                onClicked: {
                                    Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle-backdrop")
                                    Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "wallpaperSelector", "toggle"])
                                }
                            }
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Back to wallpaper")
                                icon.name: "arrow-left"
                                colBackground: Looks.colors.bg2
                                colBackgroundHover: Looks.colors.bg2Hover
                                colBackgroundActive: Looks.colors.bg2Active
                                colForeground: Looks.colors.fg
                                onClicked: multiMonCard.showBackdropView = false
                            }
                        }

                        // Secondary actions: Reset + Apply all (wallpaper mode only)
                        RowLayout {
                            visible: !multiMonCard.showBackdropView
                            Layout.fillWidth: true
                            spacing: 6
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Reset to global")
                                icon.name: "arrow-reset"
                                colBackground: Looks.colors.bg2
                                colBackgroundHover: Looks.colors.bg2Hover
                                colBackgroundActive: Looks.colors.bg2Active
                                colForeground: Looks.colors.fg
                                onClicked: {
                                    const mon = multiMonCard.selectedMonitor
                                    if (!mon) return
                                    const globalPath = Config.options?.background?.wallpaperPath ?? ""
                                    if (globalPath) {
                                        Wallpapers.select(globalPath, Appearance.m3colors.darkmode, mon)
                                    }
                                }
                            }
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Apply to all")
                                icon.name: "select-all-on"
                                colBackground: Looks.colors.bg2
                                colBackgroundHover: Looks.colors.bg2Hover
                                colBackgroundActive: Looks.colors.bg2Active
                                colForeground: Looks.colors.fg
                                onClicked: {
                                    const globalPath = Config.options?.background?.wallpaperPath ?? ""
                                    if (globalPath) {
                                        Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                                    }
                                }
                            }
                        }

                        // View backdrop shortcut (wallpaper mode only)
                        WButton {
                            visible: !multiMonCard.showBackdropView && (root.wBackdrop.enable ?? true)
                            Layout.fillWidth: true
                            text: Translation.tr("View backdrop")
                            icon.name: "eye"
                            colBackground: Looks.colors.bg2
                            colBackgroundHover: Looks.colors.bg2Hover
                            colBackgroundActive: Looks.colors.bg2Active
                            colForeground: Looks.colors.fg
                            onClicked: multiMonCard.showBackdropView = true
                            WToolTip {
                                visible: parent.hovered
                                text: Translation.tr("Change the backdrop wallpaper (used for overview/blur)")
                            }
                        }

                        // Derive theme colors from backdrop
                        WSettingsSwitch {
                            visible: root.wBackdrop.enable ?? true
                            label: Translation.tr("Derive theme colors from backdrop")
                            icon: "color"
                            checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                            onCheckedChanged: {
                                Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                                if (!(root.wBackdrop.useMainWallpaper ?? true)) {
                                    Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                                }
                            }
                        }

                        // Inline wallpaper browser
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                FluentIcon {
                                    icon: "folder"
                                    implicitSize: 11
                                    color: Looks.colors.subfg
                                    opacity: 0.6
                                }
                                WText {
                                    Layout.fillWidth: true
                                    text: {
                                        const dir = Wallpapers.effectiveDirectory
                                        if (!dir) return Translation.tr("Wallpapers")
                                        const parts = dir.split("/")
                                        return parts[parts.length - 1] || parts[parts.length - 2] || Translation.tr("Wallpapers")
                                    }
                                    font.pixelSize: Looks.font.pixelSize.tiny
                                    color: Looks.colors.subfg
                                    opacity: 0.6
                                    elide: Text.ElideMiddle
                                }
                                WText {
                                    text: Wallpapers.folderModel.count + " " + Translation.tr("items")
                                    font.pixelSize: Looks.font.pixelSize.tiny
                                    color: Looks.colors.subfg
                                    opacity: 0.5
                                }
                            }

                            ListView {
                                id: bgWpStrip
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                orientation: ListView.Horizontal
                                spacing: 3
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: Wallpapers.folderModel

                                delegate: Rectangle {
                                    id: bgWpThumb
                                    required property int index
                                    required property string filePath
                                    required property string fileName
                                    required property bool fileIsDir
                                    required property url fileUrl

                                    readonly property bool isCurrent: filePath === multiMonCard.selMonPath
                                    readonly property string thumbSource: {
                                        if (fileIsDir) return ""
                                        const thumb = Wallpapers.getExpectedThumbnailPath(filePath, "large")
                                        if (thumb) return thumb.startsWith("file://") ? thumb : "file://" + thumb
                                        return filePath.startsWith("file://") ? filePath : "file://" + filePath
                                    }

                                    width: fileIsDir ? 56 : 70
                                    height: bgWpStrip.height
                                    radius: Looks.radius.medium
                                    color: fileIsDir ? Looks.colors.bg1 : "transparent"
                                    border.width: isCurrent ? 2 : 0
                                    border.color: isCurrent ? Looks.colors.accent : "transparent"
                                    clip: true

                                    scale: bgThumbMa.containsMouse ? 0.95 : 1.0
                                    Behavior on scale { animation: Looks.transition.hover.createObject(this) }

                                    FluentIcon {
                                        visible: bgWpThumb.fileIsDir
                                        anchors.centerIn: parent
                                        icon: "folder"
                                        implicitSize: 20
                                        color: Looks.colors.subfg
                                    }
                                    WText {
                                        visible: bgWpThumb.fileIsDir
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 3 }
                                        text: bgWpThumb.fileName
                                        font.pixelSize: Looks.font.pixelSize.tiny
                                        color: Looks.colors.subfg
                                        width: parent.width - 4
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Image {
                                        visible: !bgWpThumb.fileIsDir && !WallpaperListener.isVideoPath(bgWpThumb.filePath)
                                        anchors.fill: parent
                                        anchors.margins: bgWpThumb.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: visible ? bgWpThumb.thumbSource : ""
                                        sourceSize.width: 140
                                        sourceSize.height: 140
                                        cache: true
                                        asynchronous: true
                                    }
                                    Image {
                                        visible: !bgWpThumb.fileIsDir && WallpaperListener.isVideoPath(bgWpThumb.filePath)
                                        anchors.fill: parent
                                        anchors.margins: bgWpThumb.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            if (!visible) return ""
                                            const ff = Wallpapers.videoFirstFrames[bgWpThumb.filePath]
                                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                        }
                                        cache: true
                                        asynchronous: true
                                        Component.onCompleted: {
                                            if (WallpaperListener.isVideoPath(bgWpThumb.filePath))
                                                Wallpapers.ensureVideoFirstFrame(bgWpThumb.filePath)
                                        }
                                    }

                                    Rectangle {
                                        visible: bgWpThumb.isCurrent && !bgWpThumb.fileIsDir
                                        anchors { top: parent.top; right: parent.right; margins: 2 }
                                        width: 11; height: 11; radius: 6
                                        color: Looks.colors.accent
                                        FluentIcon {
                                            anchors.centerIn: parent
                                            icon: "checkmark"
                                            implicitSize: 6
                                            color: Looks.colors.accentFg
                                        }
                                    }

                                    MouseArea {
                                        id: bgThumbMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        onClicked: {
                                            if (bgWpThumb.fileIsDir) {
                                                Wallpapers.setDirectory(bgWpThumb.filePath)
                                                return
                                            }
                                            if (multiMonCard.showBackdropView) {
                                                Wallpapers.updatePerMonitorBackdropConfig(bgWpThumb.filePath, multiMonCard.selectedMonitor)
                                            } else {
                                                Wallpapers.select(bgWpThumb.filePath, Appearance.m3colors.darkmode, multiMonCard.selectedMonitor)
                                            }
                                        }
                                    }

                                    WToolTip {
                                        visible: bgThumbMa.containsMouse
                                        text: bgWpThumb.fileName
                                    }
                                }
                            }
                        }

                        // Info bar
                        WText {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            font.pixelSize: Looks.font.pixelSize.small - 2
                            color: Looks.colors.subfg
                            opacity: 0.6
                            text: Translation.tr("%1 monitors detected").arg(WallpaperListener.screenCount) + "  ·  " + Translation.tr("Ctrl+Alt+T targets focused output")
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Wallpaper Effects")
        icon: "image"

        WSettingsSwitch {
            label: Translation.tr("Enable animated wallpapers (videos/GIFs)")
            icon: "play"
            description: Translation.tr("Play videos and GIFs as wallpaper. When disabled, shows a frozen frame")
            checked: root.wBg.enableAnimation ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.enableAnimation", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Enable blur")
            icon: "eye"
            description: Translation.tr("Blur wallpaper when windows are open")
            checked: root.wEffects.enableBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.effects.enableBlur", checked)
        }

        WSettingsSwitch {
            visible: root.wBg.enableAnimation ?? true
            label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
            icon: "eye"
            description: Translation.tr("Apply blur to animated wallpapers. Independent from window blur. May significantly impact performance.")
            checked: root.wEffects.enableAnimatedBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.effects.enableAnimatedBlur", checked)
        }

        WSettingsSpinBox {
            visible: root.wEffects.enableBlur ?? false
            label: Translation.tr("Blur radius")
            icon: "eye"
            description: Translation.tr("Amount of blur applied to wallpaper")
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.blurRadius ?? 32
            onValueChanged: Config.setNestedValue("waffles.background.effects.blurRadius", value)
        }

        WSettingsSpinBox {
            visible: root.wEffects.enableAnimatedBlur ?? false
            label: Translation.tr("Animated blur strength")
            icon: "eye"
            description: Translation.tr("Blur intensity for animated wallpapers (0-100%)")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.thumbnailBlurStrength ?? 70
            onValueChanged: Config.setNestedValue("waffles.background.effects.thumbnailBlurStrength", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Dim overlay")
            icon: "dark-theme"
            description: Translation.tr("Darken the wallpaper")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.dim ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.effects.dim", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Extra dim with windows")
            icon: "dark-theme"
            description: Translation.tr("Additional dim when windows are present")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wEffects.dynamicDim ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.effects.dynamicDim", value)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Backdrop (Overview)")
        icon: "desktop"
        
        WSettingsSwitch {
            label: Translation.tr("Enable backdrop")
            icon: "desktop"
            description: Translation.tr("Show backdrop layer for overview")
            checked: root.wBackdrop.enable ?? true
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enable", checked)
        }
        
        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Enable animated wallpapers (videos/GIFs)")
            icon: "play"
            description: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
            checked: root.wBackdrop.enableAnimation ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enableAnimation", checked)
        }

        WSettingsSwitch {
            visible: (root.wBackdrop.enable ?? true) && (root.wBackdrop.enableAnimation ?? false)
            label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
            icon: "eye"
            description: Translation.tr("Apply blur to animated wallpapers in backdrop. May significantly impact performance.")
            checked: root.wBackdrop.enableAnimatedBlur ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.enableAnimatedBlur", checked)
        }

        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Use separate wallpaper")
            icon: "image"
            description: Translation.tr("Use a different wallpaper for backdrop")
            checked: !(root.wBackdrop.useMainWallpaper ?? true)
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.useMainWallpaper", !checked)
        }
        
        WSettingsButton {
            visible: (root.wBackdrop.enable ?? true) && !(root.wBackdrop.useMainWallpaper ?? true)
            label: Translation.tr("Backdrop wallpaper")
            icon: "image"
            buttonText: Translation.tr("Change")
            onButtonClicked: {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle-backdrop")
                Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "wallpaperSelector", "toggle"])
            }
        }

        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Derive theme colors from backdrop")
            icon: "color"
            description: Translation.tr("Generate theme colors from the backdrop wallpaper instead of the main wallpaper")
            checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
            onCheckedChanged: {
                Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                if (checked && !(root.wBackdrop.useMainWallpaper ?? true)) {
                    Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                }
            }
        }
        
        WSettingsSwitch {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Hide main wallpaper")
            icon: "eye-off"
            description: Translation.tr("Show only backdrop, hide main wallpaper")
            checked: root.wBackdrop.hideWallpaper ?? false
            onCheckedChanged: Config.setNestedValue("waffles.background.backdrop.hideWallpaper", checked)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop blur")
            icon: "eye"
            description: Translation.tr("Amount of blur for backdrop layer")
            from: 0; to: 100; stepSize: 5
            value: root.wBackdrop.blurRadius ?? 64
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.blurRadius", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop dim")
            icon: "dark-theme"
            description: Translation.tr("Darken the backdrop layer")
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            value: root.wBackdrop.dim ?? 20
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.dim", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop saturation")
            icon: "eyedropper"
            description: Translation.tr("Increase color intensity")
            suffix: "%"
            from: -100; to: 100; stepSize: 10
            value: root.wBackdrop.saturation ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.saturation", value)
        }
        
        WSettingsSpinBox {
            visible: root.wBackdrop.enable ?? true
            label: Translation.tr("Backdrop contrast")
            icon: "auto"
            description: Translation.tr("Increase light/dark difference")
            suffix: "%"
            from: -100; to: 100; stepSize: 10
            value: root.wBackdrop.contrast ?? 0
            onValueChanged: Config.setNestedValue("waffles.background.backdrop.contrast", value)
        }
    }
}
