import qs
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "root:modules/common/functions/parallax.js" as ParallaxMath

ContentPage {
    id: root
    settingsPageIndex: 3
    settingsPageName: Translation.tr("Background")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"
    readonly property var iiParallax: Config.options?.background?.parallax ?? {}
    readonly property string iiParallaxPreset: ParallaxMath.detectPreset(
        iiParallax.zoom ?? iiParallax.workspaceZoom ?? 1.0,
        iiParallax.workspaceShift ?? 1,
        iiParallax.panelShift ?? iiParallax.sidebarShift ?? 0.15,
        iiParallax.widgetDepth ?? iiParallax.widgetsFactor ?? 1.2
    )

    function setIiParallaxAxis(value: string): void {
        Config.setNestedValue("background.parallax.axis", value)
        Config.setNestedValue("background.parallax.autoVertical", value === "auto")
        Config.setNestedValue("background.parallax.vertical", value === "vertical")
    }

    function applyIiParallaxPreset(presetId: string): void {
        const preset = ParallaxMath.preset(presetId)
        Config.setNestedValue("background.parallax.enable", true)
        Config.setNestedValue("background.parallax.zoom", preset.zoom)
        Config.setNestedValue("background.parallax.workspaceZoom", preset.zoom)
        Config.setNestedValue("background.parallax.workspaceShift", preset.workspaceShift)
        Config.setNestedValue("background.parallax.panelShift", preset.panelShift)
        Config.setNestedValue("background.parallax.widgetDepth", preset.widgetDepth)
        Config.setNestedValue("background.parallax.widgetsFactor", preset.widgetDepth)
    }

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
                buttonIcon: "image"
                text: Translation.tr("Enable parallax")
                checked: root.iiParallax.enable ?? ((root.iiParallax.enableWorkspace ?? false) || (root.iiParallax.enableSidebar ?? false))
                onCheckedChanged: Config.setNestedValue("background.parallax.enable", checked)
                StyledToolTip {
                    text: Translation.tr("Move the wallpaper and background widgets with workspaces and panels")
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("When parallax is active, ii renders the wallpaper internally so workspace motion, widget depth and wallpaper transitions stay synchronized.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ContentSubsection {
                title: Translation.tr("Motion profile")

                ConfigSelectionArray {
                    currentValue: root.iiParallaxPreset === "custom" ? null : root.iiParallaxPreset
                    options: [
                        { displayName: Translation.tr("Subtle"), icon: "bedtime", value: "subtle" },
                        { displayName: Translation.tr("Balanced"), icon: "tune", value: "balanced" },
                        { displayName: Translation.tr("Immersive"), icon: "movie", value: "immersive" }
                    ]
                    onSelected: newValue => root.applyIiParallaxPreset(newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Axis")

                ConfigSelectionArray {
                    currentValue: root.iiParallax.axis
                        ?? ((root.iiParallax.autoVertical ?? false) ? "auto" : ((root.iiParallax.vertical ?? false) ? "vertical" : "horizontal"))
                    options: [
                        { displayName: Translation.tr("Horizontal"), icon: "east", value: "horizontal" },
                        { displayName: Translation.tr("Vertical"), icon: "north", value: "vertical" },
                        { displayName: Translation.tr("Auto"), icon: "sync_alt", value: "auto" }
                    ]
                    onSelected: newValue => root.setIiParallaxAxis(newValue)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "counter_1"
                    text: Translation.tr("Follow workspace")
                    checked: root.iiParallax.enableWorkspace ?? false
                    enabled: root.iiParallax.enable ?? true
                    onCheckedChanged: Config.setNestedValue("background.parallax.enableWorkspace", checked)
                    StyledToolTip {
                        text: Translation.tr("Use the current workspace range to shift the wallpaper")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Follow sidebars")
                    checked: root.iiParallax.enableSidebar ?? false
                    enabled: root.iiParallax.enable ?? true
                    onCheckedChanged: Config.setNestedValue("background.parallax.enableSidebar", checked)
                    StyledToolTip {
                        text: Translation.tr("Add lateral offset when left or right sidebar is open")
                    }
                }
            }

            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Wallpaper zoom (%)")
                value: Math.round((root.iiParallax.zoom ?? root.iiParallax.workspaceZoom ?? 1.0) * 100)
                from: 10
                to: 200
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("background.parallax.zoom", value / 100)
                    Config.setNestedValue("background.parallax.workspaceZoom", value / 100)
                }
                StyledToolTip {
                    text: Translation.tr("Extra wallpaper zoom after fit-to-cover. 100% keeps the default parallax headroom; lower values zoom out, higher values zoom in.")
                }
            }

            ConfigSpinBox {
                icon: "north"
                text: Translation.tr("Workspace travel (%)")
                value: Math.round((root.iiParallax.workspaceShift ?? 1) * 100)
                from: 0
                to: 150
                stepSize: 5
                enabled: (root.iiParallax.enable ?? true) && (root.iiParallax.enableWorkspace ?? false)
                onValueChanged: Config.setNestedValue("background.parallax.workspaceShift", value / 100)
            }

            ConfigSpinBox {
                icon: "left_panel_open"
                text: Translation.tr("Sidebar travel (%)")
                value: Math.round((root.iiParallax.panelShift ?? root.iiParallax.sidebarShift ?? 0.15) * 100)
                from: 0
                to: 30
                stepSize: 1
                enabled: (root.iiParallax.enable ?? true) && (root.iiParallax.enableSidebar ?? false)
                onValueChanged: Config.setNestedValue("background.parallax.panelShift", value / 100)
            }

            ConfigSpinBox {
                icon: "layers"
                text: Translation.tr("Widget depth (%)")
                value: Math.round((root.iiParallax.widgetDepth ?? root.iiParallax.widgetsFactor ?? 1.2) * 100)
                from: 50
                to: 180
                stepSize: 5
                enabled: root.iiParallax.enable ?? true
                onValueChanged: {
                    Config.setNestedValue("background.parallax.widgetDepth", value / 100)
                    Config.setNestedValue("background.parallax.widgetsFactor", value / 100)
                }
            }

            SettingsSwitch {
                buttonIcon: "transition_fade"
                text: Translation.tr("Pause during wallpaper transitions")
                checked: root.iiParallax.pauseDuringTransitions ?? true
                enabled: root.iiParallax.enable ?? true
                onCheckedChanged: Config.setNestedValue("background.parallax.pauseDuringTransitions", checked)
            }

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Transition settle (ms)")
                value: root.iiParallax.transitionSettleMs ?? 220
                from: 0
                to: 1200
                stepSize: 20
                enabled: (root.iiParallax.enable ?? true) && (root.iiParallax.pauseDuringTransitions ?? true)
                onValueChanged: Config.setNestedValue("background.parallax.transitionSettleMs", value)
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

                                    Behavior on x { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on y { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

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
                                        Behavior on color { enabled: Appearance.animationsEnabled; animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
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

                                    Behavior on x { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on y { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on scale { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on opacity { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                    Behavior on border.width { enabled: Appearance.animationsEnabled; animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

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
                    border.color: Appearance.angelEverywhere ? (Appearance.angel?.colCardBorder ?? Appearance.colors.colLayer0Border)
                               : Appearance.inirEverywhere ? (Appearance.inir?.colBorder ?? Appearance.colors.colLayer0Border)
                               : Appearance.colors.colLayer0Border
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
                                    ?? Appearance.colors?.colLayer0Border
                                    ?? Appearance.colors?.colLayer0Border
                                    ?? Appearance.m3colors.m3outlineVariant)
                                : (Appearance.colors?.colLayer0Border
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
                                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
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
                                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
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
        expanded: false
        icon: "wallpaper"
        title: Translation.tr("Wallpaper backend (awww)")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: AwwwBackend.available
                    ? Translation.tr("awww is active. Static wallpapers are rendered externally with awww-native transitions, while GIF/video and backdrop layers use the internal fallback renderer automatically.")
                    : Translation.tr("awww is the default backend, but the `awww` / `awww-daemon` binaries were not found in PATH. Install them to enable hardware-accelerated wallpaper rendering and transitions. The internal renderer is used as fallback until then.")
                color: !AwwwBackend.available
                    ? Appearance.colors.colError
                    : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
                opacity: 0.9
            }

            ConfigSpinBox {
                visible: AwwwBackend.available
                icon: "speed"
                text: Translation.tr("awww transition FPS")
                value: Config.options?.background?.backend?.awww?.transitionFps ?? 60
                from: 10
                to: 240
                stepSize: 5
                onValueChanged: Config.setNestedValue("background.backend.awww.transitionFps", value)
            }

            ConfigRow {
                visible: AwwwBackend.available
                uniform: true

                ConfigSpinBox {
                    icon: "blur_on"
                    text: Translation.tr("Simple step")
                    value: Config.options?.background?.backend?.awww?.simpleStep ?? 5
                    from: 1
                    to: 64
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("background.backend.awww.simpleStep", value)
                }

                ConfigSpinBox {
                    icon: "swipe"
                    text: Translation.tr("Spatial step")
                    value: Config.options?.background?.backend?.awww?.spatialStep ?? 30
                    from: 1
                    to: 128
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("background.backend.awww.spatialStep", value)
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "transition_fade"
        title: Translation.tr("Wallpaper transitions")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "animation"
                text: Translation.tr("Enable wallpaper transitions")
                checked: Config.options?.background?.transition?.enable ?? true
                onCheckedChanged: {
                    Config.setNestedValue("background.transition.enable", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Smoothly transition between wallpapers when changing them")
                }
            }

            ContentSubsection {
                visible: Config.options?.background?.transition?.enable ?? true
                title: Translation.tr("Transition style")

                StyledText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: {
                        const raw = Config.options?.background?.transition?.type ?? "crossfade"
                        const t = AwwwBackend.normalizedAwwwTransitionType(raw, Config.options?.background?.transition?.direction ?? "right")
                        switch (t) {
                        case "none":   return Translation.tr("Instant switch — no visible transition.")
                        case "simple": return Translation.tr("Classic step-based dissolve. Fast, simple and lightweight.")
                        case "fade":   return Translation.tr("Smooth fade using a bezier curve for the transition progression.")
                        case "left":   return Translation.tr("Directional sweep from left to right.")
                        case "right":  return Translation.tr("Directional sweep from right to left.")
                        case "top":    return Translation.tr("Directional sweep from top to bottom.")
                        case "bottom": return Translation.tr("Directional sweep from bottom to top.")
                        case "wipe":   return Translation.tr("Wipe with configurable angle derived from the chosen direction.")
                        case "wave":   return Translation.tr("Wave transition with the same directional angle controls as wipe.")
                        case "grow":   return Translation.tr("Circular grow from a chosen origin point.")
                        case "center": return Translation.tr("Grow centered on screen.")
                        case "any":    return Translation.tr("Grow from a random point on the screen.")
                        case "outer":  return Translation.tr("The circle shrinks instead of growing.")
                        case "random": return Translation.tr("Randomly chooses one of the available transition effects.")
                        default:       return ""
                        }
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.8
                    wrapMode: Text.WordWrap
                }

                ConfigSelectionArray {
                    currentValue: AwwwBackend.normalizedAwwwTransitionType(
                        Config.options?.background?.transition?.type ?? "crossfade",
                        Config.options?.background?.transition?.direction ?? "right"
                    )
                    onSelected: newValue => {
                        Config.setNestedValue("background.transition.type", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("None"), icon: "block", value: "none" },
                        { displayName: Translation.tr("Simple"), icon: "transition_fade", value: "simple" },
                        { displayName: Translation.tr("Fade"), icon: "motion_photos_on", value: "fade" },
                        { displayName: Translation.tr("From left"), icon: "west", value: "left" },
                        { displayName: Translation.tr("From right"), icon: "east", value: "right" },
                        { displayName: Translation.tr("From top"), icon: "north", value: "top" },
                        { displayName: Translation.tr("From bottom"), icon: "south", value: "bottom" },
                        { displayName: Translation.tr("Wipe"), icon: "left_panel_open", value: "wipe" },
                        { displayName: Translation.tr("Wave"), icon: "water", value: "wave" },
                        { displayName: Translation.tr("Grow"), icon: "filter_center_focus", value: "grow" },
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Any"), icon: "shuffle", value: "any" },
                        { displayName: Translation.tr("Outer"), icon: "blur_circular", value: "outer" },
                        { displayName: Translation.tr("Random"), icon: "casino", value: "random" }
                    ]
                }
            }

            ContentSubsection {
                visible: {
                    if (!(Config.options?.background?.transition?.enable ?? true))
                        return false
                    const t = AwwwBackend.normalizedAwwwTransitionType(
                        Config.options?.background?.transition?.type ?? "crossfade",
                        Config.options?.background?.transition?.direction ?? "right"
                    )
                    return ["wipe", "wave"].indexOf(t) >= 0
                }
                title: Translation.tr("Transition direction")

                StyledText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    text: Translation.tr("Choose where the movement or reveal comes from. Vertical directions work well for tall wallpapers and horizontal directions feel more cinematic on wide monitors.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    opacity: 0.8
                    wrapMode: Text.WordWrap
                }

                ConfigSelectionArray {
                    currentValue: Config.options?.background?.transition?.direction ?? "right"
                    onSelected: newValue => {
                        Config.setNestedValue("background.transition.direction", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("From left"), icon: "west", value: "left" },
                        { displayName: Translation.tr("From right"), icon: "east", value: "right" },
                        { displayName: Translation.tr("From top"), icon: "north", value: "top" },
                        { displayName: Translation.tr("From bottom"), icon: "south", value: "bottom" }
                    ]
                }
            }

            ConfigSpinBox {
                visible: {
                    if (!(Config.options?.background?.transition?.enable ?? true))
                        return false
                    const t = AwwwBackend.normalizedAwwwTransitionType(
                        Config.options?.background?.transition?.type ?? "crossfade",
                        Config.options?.background?.transition?.direction ?? "right"
                    )
                    return t !== "simple" && t !== "none"
                }
                icon: "timer"
                text: Translation.tr("Transition duration (ms)")
                value: Config.options?.background?.transition?.duration ?? 800
                from: 200
                to: 3000
                stepSize: 100
                onValueChanged: {
                    Config.setNestedValue("background.transition.duration", value);
                }
                StyledToolTip {
                    text: Translation.tr("How long the transition takes in milliseconds. Ignored for 'Simple' and 'None' modes.")
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
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" }
                    ]
                }
            }

            // Pan + Zoom card
            Rectangle {
                id: panCard
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: (Config.options?.background?.fillMode ?? "fill") === "fill"

                readonly property var _screen: GlobalStates.primaryScreen ?? Quickshell.screens[0] ?? null
                readonly property real screenAspect: _screen ? (_screen.width / Math.max(1, _screen.height)) : (16 / 9)
                readonly property real currentPanX: Config.options?.background?.pan?.x ?? 0.0
                readonly property real currentPanY: Config.options?.background?.pan?.y ?? 0.0
                readonly property real currentPanZoom: Math.max(1.0, Math.min(3.0, Config.options?.background?.pan?.zoom ?? 1.0))
                readonly property bool hasPan: currentPanX !== 0.0 || currentPanY !== 0.0 || currentPanZoom !== 1.0

                implicitHeight: panCardContent.implicitHeight + 16
                radius: SettingsMaterialPreset.cardRadius
                color: SettingsMaterialPreset.cardColor
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
                border.color: SettingsMaterialPreset.cardBorderColor

                ColumnLayout {
                    id: panCardContent
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "open_with"
                            iconSize: 16
                            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
                                 : Appearance.colors.colPrimary
                        }

                        StyledText {
                            text: Translation.tr("Wallpaper position")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: Appearance.inirEverywhere ? Appearance.inir.colText
                                 : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface
                                 : Appearance.colors.colOnLayer1
                        }

                        MaterialSymbol {
                            text: "info"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colSubtext
                            MouseArea {
                                id: panInfoMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.WhatsThisCursor
                                StyledToolTip {
                                    extraVisibleCondition: false
                                    alternativeVisibleCondition: panInfoMouseArea.containsMouse
                                    text: Translation.tr("Drag to reposition, scroll to zoom.\nWhen repositioned or zoomed, the shell renders the wallpaper internally.")
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            visible: panCard.hasPan
                            implicitWidth: 26
                            implicitHeight: 26
                            buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                : Appearance.colors.colLayer2Hover
                            onClicked: {
                                Config.setNestedValue("background.pan.x", 0)
                                Config.setNestedValue("background.pan.y", 0)
                                Config.setNestedValue("background.pan.zoom", 1.0)
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "restart_alt"
                                iconSize: 14
                                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                                     : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                                     : Appearance.colors.colSubtext
                            }
                            StyledToolTip { text: Translation.tr("Reset position and zoom") }
                        }
                    }

                    // Wallpaper preview viewport — fills full card width
                    Rectangle {
                        id: panViewport
                        Layout.fillWidth: true
                        implicitHeight: Math.max(140, Math.round(Math.max(1, panCardContent.width) / panCard.screenAspect))
                        Layout.preferredHeight: implicitHeight
                        radius: SettingsMaterialPreset.groupRadius
                        color: Appearance.colors.colLayer0
                        clip: true
                        border.width: panDragArea.drag.active ? 2 : 0
                        border.color: Appearance.m3colors.m3primary

                        Behavior on border.width {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: 120 }
                        }

                        // Wallpaper image — Image.Stretch so zoom actually scales pixels
                        StyledImage {
                            id: panWallpaperImage
                            readonly property string wpPath: {
                                if (WallpaperListener.multiMonitorEnabled && panCard._screen) {
                                    const _monName = WallpaperListener.getMonitorName(panCard._screen)
                                    const _monData = WallpaperListener.effectivePerMonitor[_monName]
                                    if (_monData && _monData.path) return _monData.path
                                }
                                return Config.options?.background?.wallpaperPath ?? ""
                            }
                            source: wpPath ? (wpPath.startsWith("file://") ? wpPath : "file://" + wpPath) : ""
                            sourceSize.width: 1200
                            cache: false
                            fillMode: Image.Stretch
                            visible: status === Image.Ready

                            readonly property real imgNatW: implicitWidth > 0 ? implicitWidth : 1
                            readonly property real imgNatH: implicitHeight > 0 ? implicitHeight : 1
                            readonly property real scaleToFill: Math.max(
                                panViewport.width / imgNatW,
                                panViewport.height / imgNatH
                            ) * panCard.currentPanZoom
                            readonly property real scaledW: imgNatW * scaleToFill
                            readonly property real scaledH: imgNatH * scaleToFill
                            readonly property real excessX: Math.max(0, scaledW - panViewport.width)
                            readonly property real excessY: Math.max(0, scaledH - panViewport.height)

                            width: scaledW
                            height: scaledH

                            readonly property real restX: -(excessX / 2) + (panCard.currentPanX * excessX / 2)
                            readonly property real restY: -(excessY / 2) + (panCard.currentPanY * excessY / 2)

                            x: panDragArea.drag.active ? x : restX
                            y: panDragArea.drag.active ? y : restY

                            Behavior on x {
                                enabled: Appearance.animationsEnabled && !panDragArea.drag.active
                                animation: NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Behavior on y {
                                enabled: Appearance.animationsEnabled && !panDragArea.drag.active
                                animation: NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                            Behavior on width {
                                enabled: Appearance.animationsEnabled && !panDragArea.drag.active
                                animation: NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                            Behavior on height {
                                enabled: Appearance.animationsEnabled && !panDragArea.drag.active
                                animation: NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            visible: !panWallpaperImage.visible
                            text: Translation.tr("No wallpaper")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }

                        MouseArea {
                            id: panDragArea
                            anchors.fill: parent
                            drag.target: panWallpaperImage
                            drag.axis: Drag.XAndYAxis
                            drag.minimumX: -(panWallpaperImage.excessX)
                            drag.maximumX: 0
                            drag.minimumY: -(panWallpaperImage.excessY)
                            drag.maximumY: 0
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            enabled: panWallpaperImage.visible
                            scrollGestureEnabled: false

                            onReleased: {
                                if (!panWallpaperImage.visible) return
                                const ex = panWallpaperImage.excessX
                                const ey = panWallpaperImage.excessY
                                const newPanX = ex > 0 ? Math.max(-1, Math.min(1, (panWallpaperImage.x + ex / 2) / (ex / 2))) : 0
                                const newPanY = ey > 0 ? Math.max(-1, Math.min(1, (panWallpaperImage.y + ey / 2) / (ey / 2))) : 0
                                Config.setNestedValue("background.pan.x", Math.round(newPanX * 100) / 100)
                                Config.setNestedValue("background.pan.y", Math.round(newPanY * 100) / 100)
                            }

                            onWheel: wheel => {
                                const delta = wheel.angleDelta.y / 120
                                const newZoom = Math.max(1.0, Math.min(3.0, Math.round((panCard.currentPanZoom + delta * 0.1) * 100) / 100))
                                Config.setNestedValue("background.pan.zoom", newZoom)
                            }
                        }

                        // Zoom badge (top-right corner)
                        Rectangle {
                            anchors { top: parent.top; right: parent.right; margins: 8 }
                            width: zoomBadgeLabel.implicitWidth + 12
                            height: zoomBadgeLabel.implicitHeight + 6
                            radius: SettingsMaterialPreset.groupRadius
                            color: Qt.rgba(0, 0, 0, 0.6)
                            visible: panCard.currentPanZoom !== 1.0

                            StyledText {
                                id: zoomBadgeLabel
                                anchors.centerIn: parent
                                text: panCard.currentPanZoom.toFixed(1) + "×"
                                color: "white"
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                            }
                        }

                        // Crosshairs (visible while dragging)
                        Rectangle {
                            anchors.centerIn: parent
                            width: 1; height: parent.height
                            color: Qt.rgba(1, 1, 1, 0.25)
                            visible: panDragArea.drag.active
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width; height: 1
                            color: Qt.rgba(1, 1, 1, 0.25)
                            visible: panDragArea.drag.active
                        }
                    }

                    // Zoom slider row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingSmall

                        MaterialSymbol {
                            text: "zoom_out"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }

                        StyledSlider {
                            id: panZoomSlider
                            Layout.fillWidth: true
                            from: 1.0
                            to: 3.0
                            stepSize: 0.1
                            stopIndicatorValues: []
                            value: panCard.currentPanZoom
                            tooltipContent: panCard.currentPanZoom.toFixed(1) + "×"
                            enableSettingsSearch: false

                            onMoved: {
                                Config.setNestedValue("background.pan.zoom", Math.round(value * 10) / 10)
                            }
                        }

                        MaterialSymbol {
                            text: "zoom_in"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colSubtext
                        }
                    }

                    // Status text
                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (!panCard.hasPan) return Translation.tr("Centered, no zoom")
                            const parts = []
                            const x = Math.round(panCard.currentPanX * 100)
                            const y = Math.round(panCard.currentPanY * 100)
                            if (panCard.currentPanX !== 0.0 || panCard.currentPanY !== 0.0)
                                parts.push(Translation.tr("%1%, %2%").arg(x).arg(y))
                            if (panCard.currentPanZoom !== 1.0)
                                parts.push(panCard.currentPanZoom.toFixed(1) + "×")
                            return parts.join(" · ")
                        }
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
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
                checked: Config.options?.background?.effects?.enableBlur ?? false
                onCheckedChanged: {
                    Config.setNestedValue("background.effects.enableBlur", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Blur the wallpaper when windows are present")
                }
            }

            ConfigSpinBox {
                visible: Config.options?.background?.effects?.enableBlur ?? false
                icon: "blur_medium"
                text: Translation.tr("Blur radius")
                value: Config.options?.background?.effects?.blurRadius ?? 32
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.setNestedValue("background.effects.blurRadius", value);
                }
                StyledToolTip {
                    text: Translation.tr("Amount of blur applied to the wallpaper")
                }
            }

            ConfigSpinBox {
                visible: Config.options?.background?.effects?.enableBlur ?? false
                icon: "blur_circular"
                text: Translation.tr("Thumbnail blur strength (%)")
                value: Config.options?.background?.effects?.thumbnailBlurStrength ?? 50
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("background.effects.thumbnailBlurStrength", value);
                }
                StyledToolTip {
                    text: Translation.tr("Blur strength for video wallpapers (percentage of full blur radius)")
                }
            }

            ConfigSpinBox {
                icon: "brightness_6"
                text: Translation.tr("Dim overlay (%)")
                value: Config.options?.background?.effects?.dim ?? 0
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("background.effects.dim", value);
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
                value: Config.options?.background?.effects?.dynamicDim ?? 0
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("background.effects.dynamicDim", value);
                }
                StyledToolTip {
                    text: Translation.tr("Additional dim applied when there are windows on the current workspace.")
                    extraVisibleCondition: false
                    alternativeVisibleCondition: parent && parent.hovered !== undefined ? parent.hovered : false
                }
            }

            ContentSubsection {
                title: Translation.tr("Fluid Ripple (AOSP Port)")

                SettingsSwitch {
                    buttonIcon: "check_circle"
                    text: Translation.tr("Enable all ripples")
                    checked: Config.options?.background?.effects?.ripple?.enable ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.effects.ripple.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Authentic Android sparkle-style ripples.\nLicensed under Apache 2.0 (AOSP).")
                    }
                }

                SettingsGroup {
                    visible: Config.options?.background?.effects?.ripple?.enable ?? false

                    SettingsSwitch {
                        buttonIcon: "bolt"
                        text: Translation.tr("On charging")
                        checked: Config.options?.background?.effects?.ripple?.charging ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.charging", checked);
                        }
                    }

                    SettingsSwitch {
                        buttonIcon: "grid_view"
                        text: Translation.tr("On Niri overview open")
                        checked: Config.options?.background?.effects?.ripple?.overview ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.overview", checked);
                        }
                    }

                    SettingsSwitch {
                        buttonIcon: "near_me"
                        text: Translation.tr("On hotcorner activation")
                        checked: Config.options?.background?.effects?.ripple?.hotcorners ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.hotcorners", checked);
                        }
                    }

                    SettingsSwitch {
                        buttonIcon: "refresh"
                        text: Translation.tr("On shell reload")
                        checked: Config.options?.background?.effects?.ripple?.reload ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.reload", checked);
                        }
                    }

                    SettingsSwitch {
                        buttonIcon: "lock"
                        text: Translation.tr("On screen lock")
                        checked: Config.options?.background?.effects?.ripple?.lock ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.lock", checked);
                        }
                    }

                    SettingsSwitch {
                        buttonIcon: "logout"
                        text: Translation.tr("On session screen open")
                        checked: Config.options?.background?.effects?.ripple?.session ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("background.effects.ripple.session", checked);
                        }
                    }

                    SettingsDivider {}

                    ConfigSpinBox {
                        icon: "schedule"
                        text: Translation.tr("Animation duration (ms)")
                        value: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000
                        from: 500
                        to: 10000
                        stepSize: 250
                        onValueChanged: {
                            Config.setNestedValue("background.effects.ripple.rippleDuration", value);
                        }
                        StyledToolTip {
                            text: Translation.tr("How long the ripple lasts. Higher = slower expansion.")
                        }
                    }

                    SettingsDivider {}

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Visual tuning")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    ConfigSpinBox {
                        icon: "auto_awesome"
                        text: Translation.tr("Sparkle intensity")
                        value: Math.round((Config.options?.background?.effects?.ripple?.sparkleIntensity ?? 1.0) * 100)
                        from: 0
                        to: 200
                        stepSize: 10
                        onValueChanged: {
                            Config.setNestedValue("background.effects.ripple.sparkleIntensity", value / 100);
                        }
                        StyledToolTip {
                            text: Translation.tr("Controls the shimmer/sparkle particles. 0 = none, 100 = default, 200 = intense.")
                        }
                    }

                    ConfigSpinBox {
                        icon: "flare"
                        text: Translation.tr("Glow intensity")
                        value: Math.round((Config.options?.background?.effects?.ripple?.glowIntensity ?? 1.0) * 100)
                        from: 0
                        to: 200
                        stepSize: 10
                        onValueChanged: {
                            Config.setNestedValue("background.effects.ripple.glowIntensity", value / 100);
                        }
                        StyledToolTip {
                            text: Translation.tr("Controls the soft glow behind the ring. 0 = none, 100 = default, 200 = strong.")
                        }
                    }

                    ConfigSpinBox {
                        icon: "radio_button_checked"
                        text: Translation.tr("Ring width")
                        value: Math.round((Config.options?.background?.effects?.ripple?.ringWidth ?? 0.15) * 100)
                        from: 5
                        to: 50
                        stepSize: 1
                        onValueChanged: {
                            Config.setNestedValue("background.effects.ripple.ringWidth", value / 100);
                        }
                        StyledToolTip {
                            text: Translation.tr("Thickness of the expanding ring. 5 = thin laser, 15 = default, 50 = wide wash.")
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Backdrop (overview)")

                SettingsSwitch {
                    buttonIcon: "texture"
                    text: Translation.tr("Enable backdrop layer for overview")
                    checked: Config.options?.background?.backdrop?.enable ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.enable", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a separate backdrop layer when overview is open")
                    }
                }

                SettingsSwitch {
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
                    StyledToolTip {
                        text: Translation.tr("Generate theme colors from the backdrop wallpaper instead of the main wallpaper.\nRequires a custom backdrop wallpaper (not 'Use main wallpaper').")
                    }
                }

                SettingsSwitch {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    buttonIcon: "play_circle"
                    text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                    checked: Config.options?.background?.backdrop?.enableAnimation ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.enableAnimation", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
                    }
                }

                SettingsSwitch {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.enableAnimation ?? true)
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
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    buttonIcon: "blur_on"
                    text: Translation.tr("Aurora glass effect")
                    checked: Config.options?.background?.backdrop?.useAuroraStyle ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.useAuroraStyle", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Use glass blur effect with adaptive colors from wallpaper (same as sidebars)")
                    }
                }

                ConfigSpinBox {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.useAuroraStyle ?? false)
                    icon: "opacity"
                    text: Translation.tr("Aurora overlay opacity (%)")
                    value: Math.round((Config.options?.background?.backdrop?.auroraOverlayOpacity ?? 0.5) * 100)
                    from: 0
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.auroraOverlayOpacity", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("Transparency of the color overlay on the blurred wallpaper")
                    }
                }

                SettingsSwitch {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    buttonIcon: "visibility_off"
                    text: Translation.tr("Hide main wallpaper (show only backdrop)")
                    checked: Config.options?.background?.backdrop?.hideWallpaper ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.hideWallpaper", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Only show the backdrop, hide the main wallpaper entirely")
                    }
                }

                SettingsSwitch {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && !(Config.options?.background?.backdrop?.hideWallpaper ?? false)
                    buttonIcon: "image"
                    text: Translation.tr("Use main wallpaper")
                    checked: Config.options?.background?.backdrop?.useMainWallpaper ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.useMainWallpaper", checked);
                        if (checked) {
                            Config.setNestedValue("background.backdrop.wallpaperPath", "");
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Use the same wallpaper for backdrop as the main wallpaper")
                    }
                }

                TextEdit {
                    visible: (Config.options?.background?.backdrop?.enable ?? true)
                             && !(Config.options?.background?.backdrop?.useMainWallpaper ?? true)
                    Layout.fillWidth: true
                    text: Config.options?.background?.backdrop?.wallpaperPath ?? ""
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: {
                        Config.setNestedValue("background.backdrop.wallpaperPath", text);
                    }
                }

                RippleButtonWithIcon {
                    visible: !(Config.options?.background?.backdrop?.useMainWallpaper ?? true)
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Pick backdrop wallpaper")
                    onClicked: {
                        Config.setNestedValue("wallpaperSelector.selectionTarget", "backdrop")
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"]);
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "blur_on"
                    text: Translation.tr("Backdrop blur radius")
                    value: Config.options?.background?.backdrop?.blurRadius ?? 64
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.blurRadius", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Amount of blur applied to the backdrop layer")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "brightness_5"
                    text: Translation.tr("Backdrop dim (%)")
                    value: Config.options?.background?.backdrop?.dim ?? 20
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.dim", value);
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
        icon: "schedule"
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
                        Config.setNestedValue("background.widgets.clock.enable", checked);
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
                        Config.setNestedValue("background.widgets.clock.placementStrategy", newValue);
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
                        Config.setNestedValue("background.widgets.clock.style", newValue);
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer",
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
                        Config.setNestedValue("background.widgets.clock.digital.animateChange", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Smoothly animate digits when time changes")
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Time format")
                    ConfigSelectionArray {
                        currentValue: Config.options?.background?.widgets?.clock?.timeFormat ?? "system"
                        onSelected: newValue => {
                            Config.setNestedValue("background.widgets.clock.timeFormat", newValue);
                        }
                        options: [
                            {
                                displayName: Translation.tr("System"),
                                icon: "settings",
                                value: "system"
                            },
                            {
                                displayName: Translation.tr("24h"),
                                icon: "schedule",
                                value: "24h"
                            },
                            {
                                displayName: Translation.tr("12h"),
                                icon: "nest_clock_farsight_analog",
                                value: "12h"
                            }
                        ]
                    }
                }

                SettingsSwitch {
                    buttonIcon: "timer"
                    text: Translation.tr("Show seconds")
                    checked: Config.options?.background?.widgets?.clock?.showSeconds ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.widgets.clock.showSeconds", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Display seconds in the time string")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "calendar_today"
                    text: Translation.tr("Show date")
                    checked: Config.options?.background?.widgets?.clock?.showDate ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("background.widgets.clock.showDate", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a date line below the time")
                    }
                }

                ContentSubsection {
                    visible: Config.options?.background?.widgets?.clock?.showDate ?? true
                    title: Translation.tr("Date style")
                    ConfigSelectionArray {
                        currentValue: Config.options?.background?.widgets?.clock?.dateStyle ?? "long"
                        onSelected: newValue => {
                            Config.setNestedValue("background.widgets.clock.dateStyle", newValue);
                        }
                        options: [
                            {
                                displayName: Translation.tr("Long"),
                                icon: "calendar_month",
                                value: "long"
                            },
                            {
                                displayName: Translation.tr("Minimal"),
                                icon: "event_note",
                                value: "minimal"
                            },
                            {
                                displayName: Translation.tr("Weekday"),
                                icon: "today",
                                value: "weekday"
                            },
                            {
                                displayName: Translation.tr("Numeric"),
                                icon: "123",
                                value: "numeric"
                            }
                        ]
                    }
                }

                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Time scale (%)")
                    value: Config.options?.background?.widgets?.clock?.timeScale ?? 100
                    from: 50
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.widgets.clock.timeScale", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Scale the time text size")
                    }
                }

                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Date scale (%)")
                    value: Config.options?.background?.widgets?.clock?.dateScale ?? 100
                    from: 50
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.widgets.clock.dateScale", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Scale the date text size")
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
                        Config.setNestedValue("background.widgets.clock.dim", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Only affects the clock widget text, independent from the global wallpaper dim.")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock appearance")

                FontSelector {
                    id: clockFontSelector
                    label: Translation.tr("Clock font")
                    icon: "font_download"
                    selectedFont: Config.options?.background?.widgets?.clock?.fontFamily ?? "Space Grotesk"
                    onSelectedFontChanged: {
                        if (Config.options?.background?.widgets?.clock)
                            Config.setNestedValue("background.widgets.clock.fontFamily", selectedFont);
                    }
                    Connections {
                        target: Config.options?.background?.widgets?.clock ?? null
                        function onFontFamilyChanged() { clockFontSelector.selectedFont = Config.options.background.widgets.clock.fontFamily }
                    }
                }

                SettingsSwitch {
                    buttonIcon: "shadow"
                    text: Translation.tr("Show text shadow")
                    checked: Config.options?.background?.widgets?.clock?.showShadow ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("background.widgets.clock.showShadow", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Draw a subtle shadow behind clock text for better readability")
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
                        Config.setNestedValue("background.widgets.clock.cookie.aiStyling", checked);
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
                        Config.setNestedValue("background.widgets.clock.cookie.useSineCookie", checked);
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
                        Config.setNestedValue("background.widgets.clock.cookie.sides", value);
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
                        Config.setNestedValue("background.widgets.clock.cookie.constantlyRotate", checked);
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
                            Config.setNestedValue("background.widgets.clock.cookie.hourMarks", checked);
                        }
                        StyledToolTip {
                            text: "Can only be turned on using the 'Dots' or 'Full' dial style for aesthetic reasons"
                        }
                    }

                    SettingsSwitch {
                        enabled: Config.options.background.widgets.clock.style === "cookie" && Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                        buttonIcon: "123"
                        text: Translation.tr("Digits in the middle")
                        checked: Config.options.background.widgets.clock.cookie.timeIndicators
                        onEnabledChanged: {
                            checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                        }
                        onCheckedChanged: {
                            Config.setNestedValue("background.widgets.clock.cookie.timeIndicators", checked);
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
                        Config.setNestedValue("background.widgets.clock.cookie.dialNumberStyle", newValue);
                        if (newValue !== "dots" && newValue !== "full") {
                            Config.setNestedValue("background.widgets.clock.cookie.hourMarks", false);
                        }
                        if (newValue === "numbers") {
                            Config.setNestedValue("background.widgets.clock.cookie.timeIndicators", false);
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
                        Config.setNestedValue("background.widgets.clock.cookie.hourHandStyle", newValue);
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
                        Config.setNestedValue("background.widgets.clock.cookie.minuteHandStyle", newValue);
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
                        Config.setNestedValue("background.widgets.clock.cookie.secondHandStyle", newValue);
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
                        Config.setNestedValue("background.widgets.clock.cookie.dateStyle", newValue);
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
                        Config.setNestedValue("background.widgets.clock.quote.enable", checked);
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
                        Config.setNestedValue("background.widgets.clock.quote.text", text);
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Reset")

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: {
                        Config.setNestedValue("background.widgets.clock.fontFamily", "Space Grotesk");
                        Config.setNestedValue("background.widgets.clock.timeFormat", "system");
                        Config.setNestedValue("background.widgets.clock.showSeconds", false);
                        Config.setNestedValue("background.widgets.clock.showDate", true);
                        Config.setNestedValue("background.widgets.clock.dateStyle", "long");
                        Config.setNestedValue("background.widgets.clock.timeScale", 100);
                        Config.setNestedValue("background.widgets.clock.dateScale", 100);
                        Config.setNestedValue("background.widgets.clock.showShadow", true);
                        Config.setNestedValue("background.widgets.clock.dim", 70);
                        Config.setNestedValue("background.widgets.clock.digital.animateChange", true);
                    }
                    contentItem: RowLayout {
                        spacing: 6
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: 15
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Translation.tr("Reset clock settings to defaults")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
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
                        Config.setNestedValue("background.widgets.weather.enable", checked);
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
                        Config.setNestedValue("background.widgets.weather.placementStrategy", newValue);
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
                        Config.setNestedValue("background.widgets.mediaControls.enable", checked);
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.mediaControls.placementStrategy
                    onSelected: newValue => {
                        Config.setNestedValue("background.widgets.mediaControls.placementStrategy", newValue);
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
                        Config.setNestedValue("background.widgets.mediaControls.playerPreset", newValue);
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

    SettingsCardSection {
        expanded: false
        icon: "notifications"
        title: Translation.tr("Notifications")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "hide_image"
                text: Translation.tr("Hide wallpaper upscale notification")
                checked: Config.options?.background?.hideUpscaleNotification ?? false
                onCheckedChanged: Config.setNestedValue("background.hideUpscaleNotification", checked)
                StyledToolTip {
                    text: Translation.tr("Suppress the notification that appears when a wallpaper has lower resolution than your monitor")
                }
            }
        }
    }
}
