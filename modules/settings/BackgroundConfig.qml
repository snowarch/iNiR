import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 3
    settingsPageName: Translation.tr("Background")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Waffle Mode")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("You're using Waffle style. Most background settings are in the Waffle Style page. Only the Backdrop section below applies to both styles.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "sync_alt"
        title: Translation.tr("Parallax")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "unfold_more_double"
                text: Translation.tr("Vertical")
                checked: Config.options.background.parallax.vertical
                onCheckedChanged: {
                    Config.options.background.parallax.vertical = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable vertical parallax movement based on mouse position")
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "counter_1"
                    text: Translation.tr("Depends on workspace")
                    checked: Config.options.background.parallax.enableWorkspace
                    onCheckedChanged: {
                        Config.options.background.parallax.enableWorkspace = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Shift wallpaper based on current workspace position")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Depends on sidebars")
                    checked: Config.options.background.parallax.enableSidebar
                    onCheckedChanged: {
                        Config.options.background.parallax.enableSidebar = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Shift wallpaper when sidebars are open")
                    }
                }
            }
            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Preferred wallpaper zoom (%)")
                value: Config.options.background.parallax.workspaceZoom * 100
                from: 100
                to: 150
                stepSize: 1
                onValueChanged: {
                    Config.options.background.parallax.workspaceZoom = value / 100;
                }
                StyledToolTip {
                    text: Translation.tr("How much to zoom the wallpaper for parallax effect")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "devices"
        title: Translation.tr("Multi-monitor")

        SettingsGroup {
            SettingsSwitch {
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
                StyledToolTip {
                    text: Translation.tr("Set a different wallpaper for each connected monitor")
                }
            }

            // Full multi-monitor management panel
            ColumnLayout {
                id: bgMultiMonPanel
                visible: Config.options?.background?.multiMonitor?.enable ?? false
                Layout.fillWidth: true
                spacing: Appearance.sizes.spacingSmall

                property string selectedMonitor: {
                    const screens = Quickshell.screens
                    if (!screens || screens.length === 0) return ""
                    return WallpaperListener.getMonitorName(screens[0]) ?? ""
                }

                readonly property var selMonData: WallpaperListener.effectivePerMonitor[selectedMonitor] ?? { path: "", isVideo: false, isGif: false, isAnimated: false, hasCustomWallpaper: false }
                readonly property string selMonPath: selMonData.path || (Config.options?.background?.wallpaperPath ?? "")
                property bool showBackdropView: false

                readonly property string backdropPath: {
                    const bd = Config.options?.background?.backdrop ?? {}
                    if (!(bd.useMainWallpaper ?? true) && bd.wallpaperPath) return bd.wallpaperPath
                    return selMonPath
                }

                // Visual monitor layout
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
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
                        anchors.margins: Appearance.sizes.spacingSmall
                        spacing: Appearance.sizes.spacingSmall
                        height: parent.height - 28

                        Repeater {
                            model: Quickshell.screens

                            Item {
                                id: bgMonDelegate
                                required property var modelData
                                required property int index

                                readonly property string monName: WallpaperListener.getMonitorName(modelData) ?? ""
                                readonly property var wpData: WallpaperListener.effectivePerMonitor[monName] ?? { path: "" }
                                readonly property string wpPath: wpData.path || (Config.options?.background?.wallpaperPath ?? "")
                                readonly property bool isSelected: monName === bgMultiMonPanel.selectedMonitor
                                readonly property real aspectRatio: modelData.width / Math.max(1, modelData.height)
                                readonly property real cardHeight: parent.height - 16
                                readonly property real cardWidth: cardHeight * aspectRatio
                                readonly property real backdropOffset: 14

                                readonly property string backdropWpPath: {
                                    const bd = Config.options?.background?.backdrop ?? {}
                                    if (!(bd.useMainWallpaper ?? true) && bd.wallpaperPath) return bd.wallpaperPath
                                    return wpPath
                                }

                                onWpPathChanged: if (WallpaperListener.isVideoPath(wpPath)) Wallpapers.ensureVideoFirstFrame(wpPath)
                                onBackdropWpPathChanged: if (WallpaperListener.isVideoPath(backdropWpPath)) Wallpapers.ensureVideoFirstFrame(backdropWpPath)

                                Layout.preferredWidth: cardWidth + backdropOffset + 4
                                Layout.preferredHeight: parent.height - 8
                                Layout.alignment: Qt.AlignVCenter

                                // --- Backdrop card (behind, offset to side) ---
                                Rectangle {
                                    id: bgBackdropCard
                                    x: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? 0 : bgMonDelegate.backdropOffset
                                    y: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? 0 : 4
                                    z: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected ? 2 : 0
                                    width: bgMonDelegate.cardWidth
                                    height: bgMonDelegate.cardHeight
                                    radius: Appearance.rounding.small
                                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                         : Appearance.colors.colLayer1
                                    border.width: bgMonDelegate.isSelected && bgMultiMonPanel.showBackdropView
                                        ? (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 2) : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 0)
                                    border.color: bgMonDelegate.isSelected && bgMultiMonPanel.showBackdropView
                                        ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary)
                                        : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent")
                                    clip: true

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: bgBackdropCard.width
                                            height: bgBackdropCard.height
                                            radius: bgBackdropCard.radius
                                        }
                                    }

                                    opacity: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? 1.0
                                        : (bgBackdropMa.containsMouse ? 0.7 : 0.5)

                                    Behavior on x { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgBackdropCard) }
                                    Behavior on y { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgBackdropCard) }
                                    Behavior on opacity { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgBackdropCard) }

                                    StyledImage {
                                        visible: !WallpaperListener.isVideoPath(bgMonDelegate.backdropWpPath) && !WallpaperListener.isGifPath(bgMonDelegate.backdropWpPath)
                                        anchors.fill: parent
                                        anchors.margins: parent.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: (!WallpaperListener.isVideoPath(bgMonDelegate.backdropWpPath) && !WallpaperListener.isGifPath(bgMonDelegate.backdropWpPath)) ? (bgMonDelegate.backdropWpPath || "") : ""
                                        sourceSize.width: 200
                                        sourceSize.height: 200
                                        cache: true
                                    }
                                    AnimatedImage {
                                        visible: WallpaperListener.isGifPath(bgMonDelegate.backdropWpPath)
                                        anchors.fill: parent
                                        anchors.margins: parent.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            if (!WallpaperListener.isGifPath(bgMonDelegate.backdropWpPath)) return ""
                                            const p = bgMonDelegate.backdropWpPath
                                            return p.startsWith("file://") ? p : "file://" + p
                                        }
                                        asynchronous: true
                                        cache: true
                                        playing: false
                                    }
                                    StyledImage {
                                        visible: WallpaperListener.isVideoPath(bgMonDelegate.backdropWpPath)
                                        anchors.fill: parent
                                        anchors.margins: parent.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            const ff = Wallpapers.videoFirstFrames[bgMonDelegate.backdropWpPath]
                                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                        }
                                        cache: true
                                        Component.onCompleted: Wallpapers.ensureVideoFirstFrame(bgMonDelegate.backdropWpPath)
                                    }

                                    // Dim overlay for back position
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: Qt.rgba(0, 0, 0, bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected ? 0 : 0.45)
                                        Behavior on color { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                    }

                                    // "Backdrop" label
                                    Rectangle {
                                        visible: !(bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected)
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottomMargin: 3
                                        width: bgBackdropLabel.implicitWidth + 8
                                        height: 16
                                        radius: 8
                                        color: Qt.rgba(0, 0, 0, 0.7)
                                        StyledText {
                                            id: bgBackdropLabel
                                            anchors.centerIn: parent
                                            text: Translation.tr("Backdrop")
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: "white"
                                        }
                                    }

                                    MouseArea {
                                        id: bgBackdropMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: {
                                            bgMultiMonPanel.selectedMonitor = bgMonDelegate.monName
                                            bgMultiMonPanel.showBackdropView = !bgMultiMonPanel.showBackdropView
                                        }
                                    }

                                    // Selection border overlay
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        visible: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        border.width: 2
                                        border.color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
                                    }
                                }

                                // --- Main wallpaper card (front) ---
                                Rectangle {
                                    id: bgMonCard
                                    x: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? bgMonDelegate.backdropOffset : 0
                                    y: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? 4 : 0
                                    z: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected ? 0 : 2
                                    width: bgMonDelegate.cardWidth
                                    height: bgMonDelegate.cardHeight
                                    radius: Appearance.rounding.small
                                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                         : Appearance.colors.colLayer1
                                    border.width: bgMonDelegate.isSelected && !bgMultiMonPanel.showBackdropView
                                        ? (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 2) : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : Appearance.inirEverywhere ? 1 : 0)
                                    border.color: bgMonDelegate.isSelected && !bgMultiMonPanel.showBackdropView
                                        ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary)
                                        : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent")
                                    clip: true

                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: bgMonCard.width
                                            height: bgMonCard.height
                                            radius: bgMonCard.radius
                                        }
                                    }

                                    opacity: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        ? (bgMonCardMa.containsMouse ? 0.7 : 0.5)
                                        : (bgMonDelegate.isSelected ? 1.0 : (bgMonCardMa.containsMouse ? 0.95 : 0.8))
                                    scale: bgMonDelegate.isSelected && !bgMultiMonPanel.showBackdropView
                                        ? 1.0 : (bgMonCardMa.containsMouse ? 0.97 : 0.93)

                                    Behavior on x { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgMonCard) }
                                    Behavior on y { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgMonCard) }
                                    Behavior on scale { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgMonCard) }
                                    Behavior on opacity { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgMonCard) }
                                    Behavior on border.width { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(bgMonCard) }

                                    MouseArea {
                                        id: bgMonCardMa
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            bgMultiMonPanel.selectedMonitor = bgMonDelegate.monName
                                            if (mouse.button === Qt.RightButton) {
                                                bgMultiMonPanel.showBackdropView = !bgMultiMonPanel.showBackdropView
                                            } else {
                                                bgMultiMonPanel.showBackdropView = false
                                            }
                                        }
                                    }

                                    StyledImage {
                                        visible: !WallpaperListener.isVideoPath(bgMonDelegate.wpPath) && !WallpaperListener.isGifPath(bgMonDelegate.wpPath)
                                        anchors.fill: parent
                                        anchors.margins: bgMonCard.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: (!WallpaperListener.isVideoPath(bgMonDelegate.wpPath) && !WallpaperListener.isGifPath(bgMonDelegate.wpPath)) ? (bgMonDelegate.wpPath || "") : ""
                                        sourceSize.width: 240
                                        sourceSize.height: 240
                                        cache: true
                                    }
                                    AnimatedImage {
                                        visible: WallpaperListener.isGifPath(bgMonDelegate.wpPath)
                                        anchors.fill: parent
                                        anchors.margins: bgMonCard.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            if (!WallpaperListener.isGifPath(bgMonDelegate.wpPath)) return ""
                                            const p = bgMonDelegate.wpPath
                                            return p.startsWith("file://") ? p : "file://" + p
                                        }
                                        asynchronous: true
                                        cache: true
                                        playing: false
                                    }
                                    StyledImage {
                                        visible: WallpaperListener.isVideoPath(bgMonDelegate.wpPath)
                                        anchors.fill: parent
                                        anchors.margins: bgMonCard.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: {
                                            const ff = Wallpapers.videoFirstFrames[bgMonDelegate.wpPath]
                                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                        }
                                        cache: true
                                        Component.onCompleted: Wallpapers.ensureVideoFirstFrame(bgMonDelegate.wpPath)
                                    }

                                    // Dim overlay when in back position
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        visible: bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected
                                        color: Qt.rgba(0, 0, 0, 0.45)
                                    }

                                    // Label gradient overlay
                                    Rectangle {
                                        visible: !(bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected)
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: Math.max(bgMonLabelCol.implicitHeight + 14, parent.height * 0.45)
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "transparent" }
                                            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.35) }
                                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                                        }

                                        ColumnLayout {
                                            id: bgMonLabelCol
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.bottomMargin: 5
                                            spacing: 1

                                            StyledText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: bgMonDelegate.monName || ("Monitor " + (bgMonDelegate.index + 1))
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                font.weight: Font.Medium
                                                color: "#ffffff"
                                            }
                                            StyledText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: bgMonDelegate.modelData.width + "×" + bgMonDelegate.modelData.height
                                                font.pixelSize: Appearance.font.pixelSize.smaller - 2
                                                color: Qt.rgba(1, 1, 1, 0.7)
                                            }
                                        }
                                    }

                                    // Media type badge
                                    Rectangle {
                                        visible: WallpaperListener.isAnimatedPath(bgMonDelegate.wpPath)
                                            && !(bgMultiMonPanel.showBackdropView && bgMonDelegate.isSelected)
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: 4
                                        width: bgMediaBadge.implicitWidth + 8
                                        height: 18
                                        radius: 9
                                        color: Qt.rgba(0, 0, 0, 0.75)
                                        Row {
                                            id: bgMediaBadge
                                            anchors.centerIn: parent
                                            spacing: 2
                                            MaterialSymbol {
                                                text: WallpaperListener.isVideoPath(bgMonDelegate.wpPath) ? "movie" : "gif"
                                                font.pixelSize: 11
                                                color: "#ffffff"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: WallpaperListener.mediaTypeLabel(bgMonDelegate.wpPath)
                                                font.pixelSize: Appearance.font.pixelSize.smaller - 2
                                                color: "#ffffff"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                    }

                                    // Selected badge
                                    Rectangle {
                                        visible: bgMonDelegate.isSelected && !bgMultiMonPanel.showBackdropView
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 5
                                        width: 20; height: 20
                                        radius: 10
                                        color: Appearance.colors.colPrimary
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "check"
                                            font.pixelSize: 13
                                            color: Appearance.colors.colOnPrimary
                                        }
                                    }

                                    // Custom wallpaper indicator dot
                                    Rectangle {
                                        visible: (bgMonDelegate.wpData.hasCustomWallpaper ?? false)
                                            && !bgMonDelegate.isSelected
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 7
                                        width: 8; height: 8
                                        radius: 4
                                        color: Appearance.colors.colTertiary
                                    }
                                }
                            }
                        }
                    }
                }

                // Unified preview + controls card
                Rectangle {
                    id: bgMonPreviewCard
                    Layout.fillWidth: true
                    implicitHeight: bgMonPreviewCol.implicitHeight
                    radius: Appearance.rounding.small
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : Appearance.colors.colLayer1
                    border.width: Appearance.angelEverywhere ? (Appearance.angel?.cardBorderWidth ?? 1) : 1
                    border.color: Appearance.angelEverywhere ? (Appearance.angel?.colCardBorder ?? Appearance.colors.colLayer1Border)
                               : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer1Border)
                               : Appearance.colors.colLayer1Border
                    clip: true

                    readonly property string _activePath: bgMultiMonPanel.showBackdropView
                        ? bgMultiMonPanel.backdropPath : bgMultiMonPanel.selMonPath
                    readonly property string wpUrl: {
                        const path = _activePath
                        if (!path) return ""
                        return path.startsWith("file://") ? path : "file://" + path
                    }
                    readonly property bool isVideo: WallpaperListener.isVideoPath(_activePath)
                    readonly property bool isGif: WallpaperListener.isGifPath(_activePath)

                    on_ActivePathChanged: if (isVideo) Wallpapers.ensureVideoFirstFrame(_activePath)

                    ColumnLayout {
                        id: bgMonPreviewCol
                        anchors { left: parent.left; right: parent.right }
                        spacing: 0

                        // Hero preview area — frozen first frame for videos/GIFs to save resources
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            clip: true

                            StyledImage {
                                id: bgMonPreviewImage
                                visible: !bgMonPreviewCard.isGif && !bgMonPreviewCard.isVideo
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: visible ? bgMonPreviewCard.wpUrl : ""
                                sourceSize.width: 600
                                sourceSize.height: 340
                                cache: false
                            }

                            AnimatedImage {
                                id: bgMonPreviewGif
                                visible: bgMonPreviewCard.isGif
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: visible ? bgMonPreviewCard.wpUrl : ""
                                asynchronous: true
                                cache: false
                                playing: false
                            }

                            StyledImage {
                                id: bgMonPreviewVideo
                                visible: bgMonPreviewCard.isVideo
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: {
                                    const ff = Wallpapers.videoFirstFrames[bgMonPreviewCard._activePath]
                                    return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                                }
                                cache: false
                                Component.onCompleted: Wallpapers.ensureVideoFirstFrame(bgMonPreviewCard._activePath)
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
                                        margins: 12; bottomMargin: 10
                                    }
                                    spacing: Appearance.sizes.spacingSmall

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        StyledText {
                                            text: bgMultiMonPanel.selectedMonitor || Translation.tr("No monitor selected")
                                            font.pixelSize: Appearance.font.pixelSize.large
                                            font.weight: Font.Medium
                                            color: "#ffffff"
                                        }
                                        StyledText {
                                            text: {
                                                if (bgMultiMonPanel.showBackdropView) return Translation.tr("Backdrop wallpaper")
                                                const custom = bgMultiMonPanel.selMonData.hasCustomWallpaper ?? false
                                                const animated = bgMultiMonPanel.selMonData.isAnimated ?? false
                                                let label = custom ? Translation.tr("Custom wallpaper") : Translation.tr("Global wallpaper")
                                                if (animated) label += " · " + WallpaperListener.mediaTypeLabel(bgMultiMonPanel.selMonPath)
                                                return label
                                            }
                                            font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                            color: Qt.rgba(1, 1, 1, 0.7)
                                        }
                                    }

                                    // View mode pill
                                    Rectangle {
                                        visible: bgMultiMonPanel.showBackdropView
                                        width: bgViewModePill.implicitWidth + 10
                                        height: 20
                                        radius: 10
                                        color: Appearance.colors.colSecondaryContainer
                                        Row {
                                            id: bgViewModePill
                                            anchors.centerIn: parent
                                            spacing: 3
                                            MaterialSymbol {
                                                text: "blur_on"
                                                font.pixelSize: 12
                                                color: Appearance.colors.colOnSecondaryContainer
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: "Backdrop"
                                                font.pixelSize: Appearance.font.pixelSize.smaller - 1
                                                color: Appearance.colors.colOnSecondaryContainer
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: bgMultiMonPanel.showBackdropView = false
                                        }
                                    }

                                    // Media type badge
                                    Rectangle {
                                        visible: !bgMultiMonPanel.showBackdropView && (bgMonPreviewCard.isVideo || bgMonPreviewCard.isGif)
                                        width: bgPreviewBadgeRow.implicitWidth + 10
                                        height: 20
                                        radius: 10
                                        color: Qt.rgba(1, 1, 1, 0.15)
                                        Row {
                                            id: bgPreviewBadgeRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            MaterialSymbol {
                                                text: WallpaperListener.mediaTypeIcon(bgMonPreviewCard._activePath)
                                                font.pixelSize: 12
                                                color: "#ffffff"
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                text: WallpaperListener.mediaTypeLabel(bgMonPreviewCard._activePath)
                                                font.pixelSize: Appearance.font.pixelSize.smaller - 1
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
                            color: Appearance.inirEverywhere
                                ? (Appearance.inir?.colBorder
                                    ?? Appearance.colors?.colLayer1Border
                                    ?? Appearance.colors?.colLayer0Border
                                    ?? Appearance.m3colors.m3outlineVariant)
                                : (Appearance.colors?.colLayer1Border
                                    ?? Appearance.colors?.colLayer0Border
                                    ?? Appearance.m3colors.m3outlineVariant)
                            opacity: 0.5
                        }

                        // Controls section
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
                                text: {
                                    const p = bgMultiMonPanel.showBackdropView
                                        ? bgMultiMonPanel.backdropPath : bgMultiMonPanel.selMonPath
                                    return p ? FileUtils.trimFileProtocol(p) : Translation.tr("No wallpaper set")
                                }
                            }

                            // Primary actions: Change + Random (wallpaper mode)
                            RowLayout {
                                visible: !bgMultiMonPanel.showBackdropView
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.spacingSmall

                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "wallpaper"
                                    mainText: Translation.tr("Change wallpaper")
                                    colBackground: Appearance.colors.colPrimaryContainer
                                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                    colRipple: Appearance.colors.colPrimaryContainerActive
                                    mainContentComponent: Component {
                                        StyledText {
                                            text: Translation.tr("Change wallpaper")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                    }
                                    onClicked: {
                                        const mon = bgMultiMonPanel.selectedMonitor
                                        if (mon) {
                                            Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
                                            Config.setNestedValue("wallpaperSelector.targetMonitor", mon)
                                            Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
                                        }
                                    }
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "shuffle"
                                    mainText: Translation.tr("Random")
                                    onClicked: {
                                        const mon = bgMultiMonPanel.selectedMonitor
                                        if (mon) {
                                            Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, mon)
                                        }
                                    }
                                    StyledToolTip {
                                        text: Translation.tr("Set a random wallpaper from the current folder for this monitor")
                                    }
                                }
                            }

                            // Primary actions: Change backdrop (backdrop mode)
                            RowLayout {
                                visible: bgMultiMonPanel.showBackdropView
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.spacingSmall

                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "blur_on"
                                    mainText: Translation.tr("Change backdrop")
                                    colBackground: Appearance.colors.colSecondaryContainer
                                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.15)
                                    colRipple: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 0.3)
                                    mainContentComponent: Component {
                                        StyledText {
                                            text: Translation.tr("Change backdrop")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                    }
                                    onClicked: {
                                        Config.setNestedValue("wallpaperSelector.selectionTarget", "backdrop")
                                        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"])
                                    }
                                }
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "arrow_back"
                                    mainText: Translation.tr("Back to wallpaper")
                                    onClicked: bgMultiMonPanel.showBackdropView = false
                                }
                            }

                            // Secondary actions: Reset + Apply all (wallpaper mode only)
                            RowLayout {
                                visible: !bgMultiMonPanel.showBackdropView
                                Layout.fillWidth: true
                                spacing: Appearance.sizes.spacingSmall

                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
                                    buttonRadius: Appearance.rounding.small
                                    materialIcon: "restart_alt"
                                    mainText: Translation.tr("Reset to global")
                                    onClicked: {
                                        const mon = bgMultiMonPanel.selectedMonitor
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
                                RippleButtonWithIcon {
                                    Layout.fillWidth: true
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
                            }

                            // Backdrop shortcut (wallpaper mode only)
                            RippleButtonWithIcon {
                                Layout.fillWidth: true
                                buttonRadius: Appearance.rounding.small
                                materialIcon: "blur_on"
                                mainText: Translation.tr("View backdrop")
                                visible: !bgMultiMonPanel.showBackdropView && (Config.options?.background?.backdrop?.enable ?? true)
                                onClicked: bgMultiMonPanel.showBackdropView = true
                                StyledToolTip {
                                    text: Translation.tr("Change the backdrop wallpaper (used for overview/blur)")
                                }
                            }

                            // Derive theme colors from backdrop
                            ConfigSwitch {
                                visible: Config.options?.background?.backdrop?.enable ?? true
                                buttonIcon: "palette"
                                text: Translation.tr("Derive theme colors from backdrop")
                                checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                                onCheckedChanged: {
                                    Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                                    // Regenerate on both ON and OFF when backdrop has a custom wallpaper
                                    if (!(Config.options?.background?.backdrop?.useMainWallpaper ?? true)) {
                                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                                    }
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
                        opacity: 0.6
                    }
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller - 1
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                        text: Translation.tr("%1 monitors detected").arg(WallpaperListener.screenCount) + "  ·  " + Translation.tr("Ctrl+Alt+T targets focused output")
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "aspect_ratio"
        title: Translation.tr("Wallpaper scaling")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Fill crops, Fit shows bars")
                ConfigSelectionArray {
                    currentValue: Config.options?.background?.fillMode ?? "fill"
                    onSelected: newValue => {
                        Config.setNestedValue("background.fillMode", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Fill"), icon: "crop", value: "fill" },
                        { displayName: Translation.tr("Fit"), icon: "fit_screen", value: "fit" },
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Tile"), icon: "grid_view", value: "tile" }
                    ]
                }
            }
            
            SettingsSwitch {
                buttonIcon: "play_circle"
                text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                checked: Config.options?.background?.enableAnimation ?? true
                onCheckedChanged: {
                    Config.setNestedValue("background.enableAnimation", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Play videos and GIFs as wallpaper. When disabled, shows a frozen frame (better performance)")
                }
            }

            SettingsSwitch {
                visible: Config.options?.background?.enableAnimation ?? true
                buttonIcon: "blur_on"
                text: Translation.tr("Blur animated wallpapers (videos/GIFs)")
                checked: Config.options?.background?.effects?.enableAnimatedBlur ?? false
                onCheckedChanged: {
                    Config.setNestedValue("background.effects.enableAnimatedBlur", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Apply blur effect to video/GIF wallpapers. Has performance impact - disable if you experience lag")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "wallpaper"
        title: Translation.tr("Wallpaper effects")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Enable wallpaper blur")
                checked: Config.options.background.effects.enableBlur
                onCheckedChanged: {
                    Config.options.background.effects.enableBlur = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Blur the wallpaper when windows are present")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_medium"
                text: Translation.tr("Blur radius")
                value: Config.options.background.effects.blurRadius
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.background.effects.blurRadius = value;
                }
                StyledToolTip {
                    text: Translation.tr("Amount of blur applied to the wallpaper")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_linear"
                text: Translation.tr("Static blur when no windows (%)")
                value: Config.options.background.effects.blurStatic
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.blurStatic = value;
                }
                StyledToolTip {
                    text: Translation.tr("Percentage of blur to keep even when no windows are open")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_circular"
                text: Translation.tr("Thumbnail blur strength (%)")
                value: Config.options.background.effects.thumbnailBlurStrength
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.thumbnailBlurStrength = value;
                }
                StyledToolTip {
                    text: Translation.tr("Blur strength for video wallpapers (percentage of full blur radius)")
                }
            }

            ConfigSpinBox {
                icon: "brightness_6"
                text: Translation.tr("Dim overlay (%)")
                value: Config.options.background.effects.dim
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.dim = value;
                }
                StyledToolTip {
                    text: Translation.tr("Adds a dark overlay over the wallpaper. 0 = no dimming, 100 = completely black")
                    // Only show when hovering the spinbox; avoid always-on tooltips
                    extraVisibleCondition: false
                    alternativeVisibleCondition: parent && parent.hovered !== undefined ? parent.hovered : false
                }
            }

            ConfigSpinBox {
                icon: "brightness_low"
                text: Translation.tr("Extra dim when windows (%)")
                value: Config.options.background.effects.dynamicDim
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.dynamicDim = value;
                }
                StyledToolTip {
                    text: Translation.tr("Additional dim applied when there are windows on the current workspace.")
                    extraVisibleCondition: false
                    alternativeVisibleCondition: parent && parent.hovered !== undefined ? parent.hovered : false
                }
            }

            ContentSubsection {
                title: Translation.tr("Backdrop (overview)")

                SettingsSwitch {
                    buttonIcon: "texture"
                    text: Translation.tr("Enable backdrop layer for overview")
                    checked: Config.options.background.backdrop.enable
                    onCheckedChanged: {
                        Config.options.background.backdrop.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a separate backdrop layer when overview is open")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "palette"
                    text: Translation.tr("Derive theme colors from backdrop")
                    checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                        // Regenerate on both ON and OFF when backdrop has a custom wallpaper
                        if (!(Config.options?.background?.backdrop?.useMainWallpaper ?? true)) {
                            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"])
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Generate theme colors from the backdrop wallpaper instead of the main wallpaper.\nRequires a custom backdrop wallpaper (not 'Use main wallpaper').")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "play_circle"
                    text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                    checked: Config.options.background.backdrop.enableAnimation
                    onCheckedChanged: {
                        Config.options.background.backdrop.enableAnimation = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable && Config.options.background.backdrop.enableAnimation
                    buttonIcon: "blur_circular"
                    text: Translation.tr("Blur animated wallpapers (videos/GIFs)")
                    checked: Config.options?.background?.backdrop?.enableAnimatedBlur ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.enableAnimatedBlur", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to animated wallpapers in backdrop. May significantly impact performance.")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "blur_on"
                    text: Translation.tr("Aurora glass effect")
                    checked: Config.options.background.backdrop.useAuroraStyle
                    onCheckedChanged: {
                        Config.options.background.backdrop.useAuroraStyle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Use glass blur effect with adaptive colors from wallpaper (same as sidebars)")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable && Config.options.background.backdrop.useAuroraStyle
                    icon: "opacity"
                    text: Translation.tr("Aurora overlay opacity (%)")
                    value: Math.round((Config.options.background.backdrop.auroraOverlayOpacity) * 100)
                    from: 0
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.backdrop.auroraOverlayOpacity = value / 100.0;
                    }
                    StyledToolTip {
                        text: Translation.tr("Transparency of the color overlay on the blurred wallpaper")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "visibility_off"
                    text: Translation.tr("Hide main wallpaper (show only backdrop)")
                    checked: Config.options.background.backdrop.hideWallpaper
                    onCheckedChanged: {
                        Config.options.background.backdrop.hideWallpaper = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Only show the backdrop, hide the main wallpaper entirely")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "link"
                    text: Translation.tr("Use main wallpaper")
                    checked: Config.options.background.backdrop.useMainWallpaper
                    onCheckedChanged: {
                        Config.options.background.backdrop.useMainWallpaper = checked;
                        if (checked) {
                            Config.options.background.backdrop.wallpaperPath = "";
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Use the same wallpaper for backdrop as the main wallpaper")
                    }
                }

                MaterialTextArea {
                    visible: Config.options.background.backdrop.enable
                             && !Config.options.background.backdrop.useMainWallpaper
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Backdrop wallpaper path (empty = use main wallpaper)")
                    text: Config.options.background.backdrop.wallpaperPath
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: {
                        Config.options.background.backdrop.wallpaperPath = text;
                    }
                }

                RippleButtonWithIcon {
                    visible: !Config.options.background.backdrop.useMainWallpaper
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Pick backdrop wallpaper")
                    onClicked: {
                        Config.setNestedValue("wallpaperSelector.selectionTarget", "backdrop")
                        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable
                    icon: "blur_on"
                    text: Translation.tr("Backdrop blur radius")
                    value: Config.options.background.backdrop.blurRadius
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.background.backdrop.blurRadius = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Amount of blur applied to the backdrop layer")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable
                    icon: "brightness_5"
                    text: Translation.tr("Backdrop dim (%)")
                    value: Config.options.background.backdrop.dim
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.backdrop.dim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Darken the backdrop layer")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "palette"
                    text: Translation.tr("Backdrop saturation")
                    value: Math.round((Config.options?.background?.backdrop?.saturation ?? 0) * 100)
                    from: -100
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.saturation", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("Increase or decrease color intensity of the backdrop")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "contrast"
                    text: Translation.tr("Backdrop contrast")
                    value: Math.round((Config.options?.background?.backdrop?.contrast ?? 0) * 100)
                    from: -100
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.contrast", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("Increase or decrease light/dark difference in the backdrop")
                    }
                }

                ConfigRow {
                    uniform: true
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    SettingsSwitch {
                        buttonIcon: "gradient"
                        text: Translation.tr("Enable vignette")
                        checked: Config.options?.background?.backdrop?.vignetteEnabled ?? false
                        onCheckedChanged: {
                            Config.setNestedValue("background.backdrop.vignetteEnabled", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Add a dark gradient around the edges of the backdrop")
                        }
                    }
                }

                ConfigSpinBox {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.vignetteEnabled ?? false)
                    icon: "blur_circular"
                    text: Translation.tr("Vignette intensity")
                    value: Math.round((Config.options?.background?.backdrop?.vignetteIntensity ?? 0.5) * 100)
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.vignetteIntensity", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("How dark the vignette effect should be")
                    }
                }

                ConfigSpinBox {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.vignetteEnabled ?? false)
                    icon: "trip_origin"
                    text: Translation.tr("Vignette radius")
                    value: Math.round((Config.options?.background?.backdrop?.vignetteRadius ?? 0.7) * 100)
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.vignetteRadius", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("How far the vignette extends from the edges")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "clock_loader_40"
        title: Translation.tr("Widget: Clock")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show the desktop clock widget")
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.clock.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock style")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.style
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "digital"
                title: Translation.tr("Digital clock settings")

                SettingsSwitch {
                    buttonIcon: "animation"
                    text: Translation.tr("Animate time change")
                    checked: Config.options.background.widgets.clock.digital.animateChange
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.animateChange = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Smoothly animate digits when time changes")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock effects")

                ConfigSpinBox {
                    icon: "brightness_6"
                    text: Translation.tr("Clock dim (%)")
                    value: Config.options.background.widgets.clock.dim
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.widgets.clock.dim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Only affects the clock widget text, independent from the global wallpaper dim.")
                    }
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Cookie clock settings")

                SettingsSwitch {
                    buttonIcon: "wand_stars"
                    text: Translation.tr("Auto styling with Gemini")
                    checked: Config.options.background.widgets.clock.cookie.aiStyling
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.aiStyling = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Uses Gemini to categorize the wallpaper then picks a preset based on it.\nYou'll need to set Gemini API key on the left sidebar first.\nImages are downscaled for performance, but just to be safe,\ndo not select wallpapers with sensitive information.")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "airwave"
                    text: Translation.tr("Use old sine wave cookie implementation")
                    checked: Config.options.background.widgets.clock.cookie.useSineCookie
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.useSineCookie = checked;
                    }
                    StyledToolTip {
                        text: "Looks a bit softer and more consistent with different number of sides,\nbut has less impressive morphing"
                    }
                }

                ConfigSpinBox {
                    icon: "add_triangle"
                    text: Translation.tr("Sides")
                    value: Config.options.background.widgets.clock.cookie.sides
                    from: 0
                    to: 40
                    stepSize: 1
                    onValueChanged: {
                        Config.options.background.widgets.clock.cookie.sides = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of sides for the polygon shape")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "autoplay"
                    text: Translation.tr("Constantly rotate")
                    checked: Config.options.background.widgets.clock.cookie.constantlyRotate
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.constantlyRotate = checked;
                    }
                    StyledToolTip {
                        text: "Makes the clock always rotate. This is extremely expensive\n(expect 50% usage on Intel UHD Graphics) and thus impractical."
                    }
                }

                ConfigRow {

                    SettingsSwitch {
                        enabled: Config.options.background.widgets.clock.style === "cookie" && Config.options.background.widgets.clock.cookie.dialNumberStyle === "dots" || Config.options.background.widgets.clock.cookie.dialNumberStyle === "full"
                        buttonIcon: "brightness_7"
                        text: Translation.tr("Hour marks")
                        checked: Config.options.background.widgets.clock.cookie.hourMarks
                        onEnabledChanged: {
                            checked = Config.options.background.widgets.clock.cookie.hourMarks;
                        }
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.hourMarks = checked;
                        }
                        StyledToolTip {
                            text: "Can only be turned on using the 'Dots' or 'Full' dial style for aesthetic reasons"
                        }
                    }

                    SettingsSwitch {
                        enabled: Config.options.background.widgets.clock.style === "cookie" && Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                        buttonIcon: "timer_10"
                        text: Translation.tr("Digits in the middle")
                        checked: Config.options.background.widgets.clock.cookie.timeIndicators
                        onEnabledChanged: {
                            checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                        }
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.timeIndicators = checked;
                        }
                        StyledToolTip {
                            text: "Can't be turned on when using 'Numbers' dial style for aesthetic reasons"
                        }
                    }
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Dial style")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dialNumberStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dialNumberStyle = newValue;
                        if (newValue !== "dots" && newValue !== "full") {
                            Config.options.background.widgets.clock.cookie.hourMarks = false;
                        }
                        if (newValue === "numbers") {
                            Config.options.background.widgets.clock.cookie.timeIndicators = false;
                        }
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "none"
                        },
                        {
                            displayName: Translation.tr("Dots"),
                            icon: "graph_6",
                            value: "dots"
                        },
                        {
                            displayName: Translation.tr("Full"),
                            icon: "history_toggle_off",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Numbers"),
                            icon: "counter_1",
                            value: "numbers"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Hour hand")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.hourHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.hourHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Hollow"),
                            icon: "circle",
                            value: "hollow"
                        },
                        {
                            displayName: Translation.tr("Fill"),
                            icon: "eraser_size_5",
                            value: "fill"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Minute hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.minuteHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.minuteHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Thin"),
                            icon: "line_end",
                            value: "thin"
                        },
                        {
                            displayName: Translation.tr("Medium"),
                            icon: "eraser_size_2",
                            value: "medium"
                        },
                        {
                            displayName: Translation.tr("Bold"),
                            icon: "eraser_size_4",
                            value: "bold"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Second hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.secondHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.secondHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Line"),
                            icon: "line_end",
                            value: "line"
                        },
                        {
                            displayName: Translation.tr("Dot"),
                            icon: "adjust",
                            value: "dot"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Date style")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dateStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dateStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Bubble"),
                            icon: "bubble_chart",
                            value: "bubble"
                        },
                        {
                            displayName: Translation.tr("Border"),
                            icon: "rotate_right",
                            value: "border"
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "rectangle",
                            value: "rect"
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Quote")

                SettingsSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.quote.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.quote.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a quote text widget below the clock")
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Quote")
                    text: Config.options.background.widgets.clock.quote.text
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.background.widgets.clock.quote.text = text;
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "cloud"
        title: Translation.tr("Widget: Weather")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                visible: !(Config.options?.bar?.weather?.enable ?? false)
                text: Translation.tr("Enable weather service first in Services → Weather")
                color: Appearance.colors.colTertiary
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ConfigRow {
                Layout.fillWidth: true
                enabled: Config.options?.bar?.weather?.enable ?? false

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.weather.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.weather.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show the desktop weather widget")
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.weather.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.weather.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "album"
        title: Translation.tr("Widget: Media Controls")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.mediaControls.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.mediaControls.enable = checked;
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.mediaControls.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.mediaControls.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }
            
            ContentSubsectionLabel {
                text: Translation.tr("Player Style")
            }
            
            ConfigRow {
                Layout.fillWidth: true
                
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options.background.widgets.mediaControls.playerPreset
                    onSelected: newValue => {
                        Config.options.background.widgets.mediaControls.playerPreset = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Full"),
                            icon: "featured_video",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Compact"),
                            icon: "view_compact",
                            value: "compact"
                        },
                        {
                            displayName: Translation.tr("Album Art"),
                            icon: "image",
                            value: "albumart"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        }
                    ]
                }
            }
        }
    }
}
