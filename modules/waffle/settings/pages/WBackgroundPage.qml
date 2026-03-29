pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.waffle.looks
import qs.modules.waffle.settings
import "root:modules/common/functions/parallax.js" as ParallaxMath

WSettingsPage {
    id: root
    settingsPageIndex: 3
    pageTitle: Translation.tr("Background")
    pageIcon: "image"
    pageDescription: Translation.tr("Wallpaper effects and backdrop settings for Waffle")
    
    // Shorthand for waffle background config
    readonly property var wBg: Config.options?.waffles?.background ?? {}
    readonly property var wEffects: wBg.effects ?? {}
    readonly property var wClock: wBg.widgets?.clock ?? {}
    readonly property var wBackdrop: wBg.backdrop ?? {}
    readonly property var wTransition: wBg.transition ?? {}
    readonly property var wParallax: wBg.parallax ?? {}
    readonly property bool useSharedWallpaperTransition: root.wBg.useMainWallpaper ?? true
    readonly property bool waffleTransitionsEnabled: root.wTransition.enable ?? true
    readonly property string waffleTransitionType: root.wTransition.type ?? "crossfade"
    readonly property string waffleTransitionDirection: root.wTransition.direction ?? "right"
    readonly property int waffleTransitionDuration: root.wTransition.duration ?? 800
    readonly property var directionalTransitionTypes: ["wipe", "wave"]
    readonly property string waffleParallaxPreset: ParallaxMath.detectPreset(
        root.wParallax.zoom ?? root.wParallax.workspaceZoom ?? 1.05,
        root.wParallax.workspaceShift ?? 1,
        root.wParallax.panelShift ?? root.wParallax.sidebarShift ?? 0.12,
        root.wParallax.widgetDepth ?? root.wParallax.widgetsFactor ?? 1.0
    )
    property bool backgroundBrowserPrimed: false
    property bool heavySectionsReady: false
    property string pendingBackgroundBrowserPath: ""
    property bool settingsHandlersReady: false
    property bool deferredDetailCardsReady: false

    function setNestedValueWhenReady(nestedKey, value): void {
        if (!settingsHandlersReady)
            return

        Config.setNestedValue(nestedKey, value)
    }
    
    function setWaffleTransitionType(newValue: string): void {
        Config.setNestedValue("waffles.background.transition.type", newValue)
    }
    
    function setWaffleTransitionDirection(newValue: string): void {
        Config.setNestedValue("waffles.background.transition.direction", newValue)
    }

    function setWaffleParallaxAxis(newValue: string): void {
        Config.setNestedValue("waffles.background.parallax.axis", newValue)
        Config.setNestedValue("waffles.background.parallax.autoVertical", newValue === "auto")
        Config.setNestedValue("waffles.background.parallax.vertical", newValue === "vertical")
    }

    function applyWaffleParallaxPreset(presetId: string): void {
        const preset = ParallaxMath.preset(presetId)
        Config.setNestedValue("waffles.background.parallax.enable", true)
        Config.setNestedValue("waffles.background.parallax.zoom", preset.zoom)
        Config.setNestedValue("waffles.background.parallax.workspaceZoom", preset.zoom)
        Config.setNestedValue("waffles.background.parallax.workspaceShift", preset.workspaceShift)
        Config.setNestedValue("waffles.background.parallax.panelShift", preset.panelShift)
        Config.setNestedValue("waffles.background.parallax.widgetDepth", preset.widgetDepth)
        Config.setNestedValue("waffles.background.parallax.widgetsFactor", preset.widgetDepth)
    }

    function ensureHeavySectionsReady(effectivePath: string): void {
        if (heavySectionsReady)
            return

        heavySectionsReady = true
        pendingBackgroundBrowserPath = effectivePath
        backgroundBrowserInitTimer.restart()
    }

    function primeBackgroundBrowser(effectivePath: string): void {
        if (backgroundBrowserPrimed)
            return

        backgroundBrowserPrimed = true

        if (effectivePath && effectivePath.length > 0) {
            const clean = CF.FileUtils.trimFileProtocol(String(effectivePath))
            const dir = CF.FileUtils.parentDirectory(clean)
            if (dir && dir.length > 0 && dir !== Wallpapers.effectiveDirectory) {
                Wallpapers.setDirectory(dir)
                return
            }
        }

        Wallpapers.generateThumbnail("large")
    }

    Timer {
        id: backgroundBrowserInitTimer
        interval: 50
        repeat: false
        onTriggered: root.primeBackgroundBrowser(root.pendingBackgroundBrowserPath)
    }

    Connections {
        target: Wallpapers
        function onFolderChanged() {
            if (root.backgroundBrowserPrimed && root.heavySectionsReady)
                Wallpapers.generateThumbnail("large")
        }
    }

    Component.onCompleted: Qt.callLater(() => {
        root.settingsHandlersReady = true
        root.deferredDetailCardsReady = true
    })

    WSettingsCard {
        title: Translation.tr("Wallpaper")
        icon: "image"
        
        WSettingsSwitch {
            label: Translation.tr("Use Material ii wallpaper")
            icon: "image"
            description: Translation.tr("Share wallpaper with Material ii family")
            checked: root.wBg.useMainWallpaper ?? true
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.useMainWallpaper", checked)
        }
        
        WSettingsButton {
            visible: !(root.wBg.useMainWallpaper ?? true)
            label: Translation.tr("Waffle wallpaper")
            icon: "image"
            buttonText: Translation.tr("Change")
            onButtonClicked: {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle")
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Per-monitor wallpapers")
            icon: "desktop"
            description: Translation.tr("Set different wallpapers for each monitor")
            checked: Config.options?.background?.multiMonitor?.enable ?? false
            onCheckedChanged: {
                if (!root.settingsHandlersReady)
                    return
                Config.setNestedValue("background.multiMonitor.enable", checked)
                if (!checked) {
                    const globalPath = Config.options?.background?.wallpaperPath ?? ""
                    if (globalPath) {
                        Wallpapers.apply(globalPath, Appearance.m3colors.darkmode)
                    }
                }
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Hide when fullscreen")
            icon: "desktop"
            description: Translation.tr("Hide the Waffle wallpaper layer while a fullscreen window is active")
            checked: root.wBg.hideWhenFullscreen ?? true
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.hideWhenFullscreen", checked)
        }

        WSettingsRow {
            label: Translation.tr("Wallpaper scaling")
            icon: "image"
            description: Translation.tr("Only Fill, Fit and Center are available because awww is the active wallpaper backend.")
        }
        Grid {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 8
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: Translation.tr("Fill"), value: "fill" },
                    { label: Translation.tr("Fit"), value: "fit" },
                    { label: Translation.tr("Center"), value: "center" }
                ]

                delegate: WChoiceButton {
                    required property var modelData
                    Layout.fillWidth: false
                    width: (parent.width - 12) / 3
                    text: modelData.label
                    checked: (Config.options?.background?.fillMode ?? "fill") === modelData.value
                    onClicked: Config.setNestedValue("background.fillMode", modelData.value)
                }
            }
        }

        // ─── Wallpaper folder browser ───
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 3

            // Resolve the current effective wallpaper path for folder detection
            readonly property string _effectivePath: {
                const useMain = root.wBg.useMainWallpaper ?? true
                if (useMain) return Config.options?.background?.wallpaperPath ?? ""
                return root.wBg.wallpaperPath || Config.options?.background?.wallpaperPath || ""
            }

            Component.onCompleted: {
                root.pendingBackgroundBrowserPath = _effectivePath
            }

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
                        if (!root.heavySectionsReady) return Translation.tr("Wallpapers")
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
                    visible: root.heavySectionsReady
                    text: root.heavySectionsReady ? (Wallpapers.folderModel.count + " " + Translation.tr("items")) : ""
                    font.pixelSize: Looks.font.pixelSize.tiny
                    color: Looks.colors.subfg
                    opacity: 0.5
                }
            }

            WSettingsButton {
                visible: !root.heavySectionsReady
                label: Translation.tr("Wallpaper previews")
                icon: "image"
                buttonText: Translation.tr("Load")
                onButtonClicked: root.ensureHeavySectionsReady(_effectivePath)
            }

            ListView {
                id: mainWpStrip
                visible: root.heavySectionsReady
                Layout.fillWidth: true
                Layout.preferredHeight: 74
                orientation: ListView.Horizontal
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.heavySectionsReady ? Wallpapers.folderModel : null

                delegate: Rectangle {
                    id: mainWpThumb
                    required property int index
                    required property string filePath
                    required property string fileName
                    required property bool fileIsDir
                    required property url fileUrl

                    readonly property string _currentWp: {
                        const useMain = root.wBg.useMainWallpaper ?? true
                        if (useMain) return Config.options?.background?.wallpaperPath ?? ""
                        return root.wBg.wallpaperPath || Config.options?.background?.wallpaperPath || ""
                    }
                    readonly property bool isCurrent: filePath === _currentWp
                    readonly property string thumbSource: {
                        if (fileIsDir) return ""
                        const thumb = Wallpapers.getExpectedThumbnailPath(filePath, "large")
                        if (thumb) return thumb.startsWith("file://") ? thumb : "file://" + thumb
                        return filePath.startsWith("file://") ? filePath : "file://" + filePath
                    }

                    width: fileIsDir ? 58 : 74
                    height: mainWpStrip.height
                    radius: Looks.radius.medium
                    color: fileIsDir ? Looks.colors.bg1 : "transparent"
                    border.width: isCurrent ? 2 : 0
                    border.color: isCurrent ? Looks.colors.accent : "transparent"
                    clip: true

                    scale: mainThumbMa.containsMouse ? 0.95 : 1.0
                    Behavior on scale { animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

                    FluentIcon {
                        visible: mainWpThumb.fileIsDir
                        anchors.centerIn: parent
                        icon: "folder"
                        implicitSize: 20
                        color: Looks.colors.subfg
                    }
                    WText {
                        visible: mainWpThumb.fileIsDir
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 3 }
                        text: mainWpThumb.fileName
                        font.pixelSize: Looks.font.pixelSize.tiny
                        color: Looks.colors.subfg
                        width: parent.width - 4
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Image {
                        id: mainThumbImg
                        visible: !mainWpThumb.fileIsDir && !WallpaperListener.isVideoPath(mainWpThumb.filePath)
                        anchors.fill: parent
                        anchors.margins: mainWpThumb.border.width
                        fillMode: Image.PreserveAspectCrop
                        source: visible ? mainWpThumb.thumbSource : ""
                        sourceSize.width: 140
                        sourceSize.height: 140
                        cache: true
                        asynchronous: true
                        onStatusChanged: {
                            if (status === Image.Error && mainWpThumb.filePath)
                                source = mainWpThumb.filePath.startsWith("file://") ? mainWpThumb.filePath : "file://" + mainWpThumb.filePath
                        }
                        Connections {
                            target: Wallpapers
                            function onThumbnailGenerated(directory) {
                                if (mainThumbImg.status !== Image.Ready && mainWpThumb.filePath) {
                                    mainThumbImg.source = ""
                                    mainThumbImg.source = mainWpThumb.thumbSource
                                }
                            }
                        }
                    }
                    Image {
                        visible: !mainWpThumb.fileIsDir && WallpaperListener.isVideoPath(mainWpThumb.filePath)
                        anchors.fill: parent
                        anchors.margins: mainWpThumb.border.width
                        fillMode: Image.PreserveAspectCrop
                        source: {
                            if (!visible) return ""
                            const ff = Wallpapers.videoFirstFrames[mainWpThumb.filePath]
                            return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                        }
                        cache: true
                        asynchronous: true
                        Component.onCompleted: {
                            if (root.heavySectionsReady)
                                Wallpapers.ensureVideoFirstFrame(mainWpThumb.filePath)
                        }
                    }

                    Rectangle {
                        visible: mainWpThumb.isCurrent && !mainWpThumb.fileIsDir
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
                        id: mainThumbMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            if (mainWpThumb.fileIsDir) {
                                Wallpapers.setDirectory(mainWpThumb.filePath)
                                return
                            }
                            // Apply to the correct target based on useMainWallpaper
                            const useMain = root.wBg.useMainWallpaper ?? true
                            if (useMain) {
                                Wallpapers.select(mainWpThumb.filePath, Appearance.m3colors.darkmode, "")
                            } else {
                                Wallpapers.applySelectionTarget(mainWpThumb.filePath, "waffle", Appearance.m3colors.darkmode, "")
                            }
                        }
                    }

                    WToolTip {
                        visible: mainThumbMa.containsMouse
                        text: mainWpThumb.fileName
                    }
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Wallpaper Transitions")
        icon: "arrow-sync"
        
        WSettingsRow {
            visible: root.useSharedWallpaperTransition
            label: Translation.tr("Shared with Material ii")
            icon: "desktop"
            description: Translation.tr("When 'Use Material ii wallpaper' is enabled, Waffle inherits ii's wallpaper transition backend and timing. Disable the shared wallpaper to configure Waffle-specific transitions without overlapping families.")
            enableSettingsSearch: false
        }
        
        WSettingsSwitch {
            visible: !root.useSharedWallpaperTransition
            label: Translation.tr("Enable wallpaper transitions")
            icon: "flash-on"
            description: Translation.tr("Animate wallpaper swaps only for Waffle's own wallpaper")
            checked: root.waffleTransitionsEnabled
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.transition.enable", checked)
        }
        
        WSettingsRow {
            id: transitionStyleRow
            visible: !root.useSharedWallpaperTransition && root.waffleTransitionsEnabled
            label: Translation.tr("Transition style")
            icon: "wand"
        }
        Grid {
            visible: transitionStyleRow.visible
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            columns: 4
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: Translation.tr("None"), value: "none" },
                    { label: Translation.tr("Simple"), value: "simple" },
                    { label: Translation.tr("Fade"), value: "fade" },
                    { label: Translation.tr("Left"), value: "left" },
                    { label: Translation.tr("Right"), value: "right" },
                    { label: Translation.tr("Top"), value: "top" },
                    { label: Translation.tr("Bottom"), value: "bottom" },
                    { label: Translation.tr("Wipe"), value: "wipe" },
                    { label: Translation.tr("Wave"), value: "wave" },
                    { label: Translation.tr("Grow"), value: "grow" },
                    { label: Translation.tr("Center"), value: "center" },
                    { label: Translation.tr("Any"), value: "any" },
                    { label: Translation.tr("Outer"), value: "outer" },
                    { label: Translation.tr("Random"), value: "random" }
                ]

                delegate: WChoiceButton {
                    required property var modelData
                    Layout.fillWidth: false
                    width: (transitionStyleRow.width - 16 * 2 - 6 * 3) / 4
                    text: modelData.label
                    checked: root.waffleTransitionType === modelData.value
                    onClicked: root.setWaffleTransitionType(modelData.value)
                }
            }
        }
        
        WSettingsRow {
            id: transitionDirectionRow
            visible: {
                if (root.useSharedWallpaperTransition || !root.waffleTransitionsEnabled)
                    return false
                const t = AwwwBackend.normalizedAwwwTransitionType(root.waffleTransitionType, root.waffleTransitionDirection)
                return ["wipe", "wave"].indexOf(t) >= 0
            }
            label: Translation.tr("Transition direction")
            icon: "arrow-right"
        }
        Grid {
            visible: transitionDirectionRow.visible
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            columns: 4
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: Translation.tr("Left"), value: "left" },
                    { label: Translation.tr("Right"), value: "right" },
                    { label: Translation.tr("Top"), value: "top" },
                    { label: Translation.tr("Bottom"), value: "bottom" }
                ]

                delegate: WChoiceButton {
                    required property var modelData
                    Layout.fillWidth: false
                    width: (transitionDirectionRow.width - 16 * 2 - 6 * 3) / 4
                    text: modelData.label
                    checked: root.waffleTransitionDirection === modelData.value
                    onClicked: root.setWaffleTransitionDirection(modelData.value)
                }
            }
        }
        
        WSettingsSpinBox {
            visible: {
                if (root.useSharedWallpaperTransition || !root.waffleTransitionsEnabled)
                    return false
                const t = AwwwBackend.normalizedAwwwTransitionType(
                    root.waffleTransitionType,
                    root.waffleTransitionDirection
                )
                return t !== "simple" && t !== "none"
            }
            label: Translation.tr("Transition duration")
            icon: "arrow-clockwise"
            description: Translation.tr("How long Waffle's dedicated wallpaper transition should take.")
            suffix: "ms"
            value: root.waffleTransitionDuration
            from: 200
            to: 3000
            stepSize: 100
            onValueChanged: root.setNestedValueWhenReady("waffles.background.transition.duration", value)
        }
    }

    WSettingsCard {
        title: Translation.tr("Parallax")
        icon: "image"

        WSettingsSwitch {
            label: Translation.tr("Enable parallax")
            icon: "image"
            description: Translation.tr("Move the Waffle wallpaper and background widgets with workspaces and open panels")
            checked: root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.parallax.enable", checked)
        }

        WSettingsRow {
            label: Translation.tr("Background rendering")
            icon: "desktop"
            description: Translation.tr("When parallax is active, Waffle renders the wallpaper internally so panel motion and transitions stay visually stable.")
            enableSettingsSearch: false
        }

        WSettingsRow {
            id: waffleParallaxProfileRow
            label: Translation.tr("Motion profile")
            icon: "wand"
            description: Translation.tr("Apply a tuned set of zoom, workspace travel, panel travel and widget depth values.")
        }
        Grid {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: Translation.tr("Subtle"), value: "subtle" },
                    { label: Translation.tr("Balanced"), value: "balanced" },
                    { label: Translation.tr("Immersive"), value: "immersive" }
                ]

                delegate: WChoiceButton {
                    required property var modelData
                    Layout.fillWidth: false
                    width: (waffleParallaxProfileRow.width - 16 * 2 - 6 * 2) / 3
                    text: modelData.label
                    checked: root.waffleParallaxPreset === modelData.value
                    onClicked: root.applyWaffleParallaxPreset(modelData.value)
                }
            }
        }

        WSettingsRow {
            id: waffleParallaxAxisRow
            label: Translation.tr("Axis")
            icon: "arrow-right"
        }
        Grid {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 8
            columns: 3
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: [
                    { label: Translation.tr("Horizontal"), value: "horizontal" },
                    { label: Translation.tr("Vertical"), value: "vertical" },
                    { label: Translation.tr("Auto"), value: "auto" }
                ]

                delegate: WChoiceButton {
                    required property var modelData
                    Layout.fillWidth: false
                    width: (waffleParallaxAxisRow.width - 16 * 2 - 6 * 2) / 3
                    text: modelData.label
                    checked: (root.wParallax.axis
                        ?? ((root.wParallax.autoVertical ?? true) ? "auto" : ((root.wParallax.vertical ?? false) ? "vertical" : "horizontal"))) === modelData.value
                    onClicked: root.setWaffleParallaxAxis(modelData.value)
                }
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Follow workspace")
            icon: "desktop"
            description: Translation.tr("Shift the wallpaper with the current workspace range")
            checked: root.wParallax.enableWorkspace ?? false
            enabled: root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.parallax.enableWorkspace", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Follow panels")
            icon: "apps"
            description: Translation.tr("Add lateral motion when Start, widgets, clipboard, Action Center or notifications open")
            checked: root.wParallax.enableSidebar ?? false
            enabled: root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.parallax.enableSidebar", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Wallpaper zoom")
            icon: "search"
            description: Translation.tr("Extra wallpaper scale reserved for parallax movement")
            suffix: "%"
            value: Math.round((root.wParallax.zoom ?? root.wParallax.workspaceZoom ?? 1.05) * 100)
            from: 100
            to: 140
            stepSize: 1
            onValueChanged: {
                if (!root.settingsHandlersReady)
                    return
                Config.setNestedValue("waffles.background.parallax.zoom", value / 100)
                Config.setNestedValue("waffles.background.parallax.workspaceZoom", value / 100)
            }
        }

        WSettingsSpinBox {
            label: Translation.tr("Workspace travel")
            icon: "arrow-right"
            description: Translation.tr("How far Waffle should travel across the workspace range")
            suffix: "%"
            value: Math.round((root.wParallax.workspaceShift ?? 1) * 100)
            from: 0
            to: 150
            stepSize: 5
            enabled: (root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))) && (root.wParallax.enableWorkspace ?? false)
            onValueChanged: root.setNestedValueWhenReady("waffles.background.parallax.workspaceShift", value / 100)
        }

        WSettingsSpinBox {
            label: Translation.tr("Panel travel")
            icon: "apps"
            description: Translation.tr("How much lateral offset to add for Waffle panels")
            suffix: "%"
            value: Math.round((root.wParallax.panelShift ?? root.wParallax.sidebarShift ?? 0.12) * 100)
            from: 0
            to: 30
            stepSize: 1
            enabled: (root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))) && (root.wParallax.enableSidebar ?? false)
            onValueChanged: root.setNestedValueWhenReady("waffles.background.parallax.panelShift", value / 100)
        }

        WSettingsSpinBox {
            label: Translation.tr("Widget depth")
            icon: "apps"
            description: Translation.tr("Keep Waffle background widgets slightly ahead of the wallpaper motion")
            suffix: "%"
            value: Math.round((root.wParallax.widgetDepth ?? root.wParallax.widgetsFactor ?? 1.0) * 100)
            from: 50
            to: 180
            stepSize: 5
            enabled: root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))
            onValueChanged: {
                if (!root.settingsHandlersReady)
                    return
                Config.setNestedValue("waffles.background.parallax.widgetDepth", value / 100)
                Config.setNestedValue("waffles.background.parallax.widgetsFactor", value / 100)
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Pause during wallpaper transitions")
            icon: "flash-on"
            description: Translation.tr("Freeze parallax briefly while wallpaper transitions settle")
            checked: root.wParallax.pauseDuringTransitions ?? true
            enabled: root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.parallax.pauseDuringTransitions", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Transition settle")
            icon: "arrow-clockwise"
            description: Translation.tr("Extra pause after a wallpaper change before parallax resumes")
            suffix: "ms"
            value: root.wParallax.transitionSettleMs ?? 220
            from: 0
            to: 1200
            stepSize: 20
            enabled: (root.wParallax.enable ?? ((root.wParallax.enableWorkspace ?? false) || (root.wParallax.enableSidebar ?? false))) && (root.wParallax.pauseDuringTransitions ?? true)
            onValueChanged: root.setNestedValueWhenReady("waffles.background.parallax.transitionSettleMs", value)
        }
    }
    Loader {
        active: Config.options?.background?.multiMonitor?.enable ?? false
        asynchronous: true
        Layout.fillWidth: true
        sourceComponent: multiMonCardComponent
    }

    Component {
        id: multiMonCardComponent

        WSettingsCard {
            id: multiMonCard
            width: parent?.width ?? 0
            title: Translation.tr("Monitor Wallpapers")
            icon: "desktop"

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
                        model: root.heavySectionsReady ? Quickshell.screens : []

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
                                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                            }
                            Behavior on opacity {
                                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                            }
                            Behavior on border.color {
                                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
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
                                Component.onCompleted: {
                                    if (root.heavySectionsReady)
                                        Wallpapers.ensureVideoFirstFrame(wMonitorCard.wpPath)
                                }
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

        // Unified preview + controls card
        Rectangle {
            id: wMonPreviewCard
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 4
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
                    if (root.heavySectionsReady && wMonPreviewCard.isVideo) Wallpapers.ensureVideoFirstFrame(wMonPreviewCard.displayPath)
                }
                function onBackdropPathChanged() {
                    if (root.heavySectionsReady && WallpaperListener.isVideoPath(multiMonCard.backdropPath)) Wallpapers.ensureVideoFirstFrame(multiMonCard.backdropPath)
                }
            }

            ColumnLayout {
                id: wMonPreviewCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                    // Hero preview area — frozen first frame for videos/GIFs to save resources
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 140
                        clip: true

                        Image {
                            id: wMonPreviewImage
                            visible: root.heavySectionsReady && !wMonPreviewCard.isGif && !wMonPreviewCard.isVideo
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: visible ? wMonPreviewCard.wpUrl : ""
                            asynchronous: true
                            cache: false
                        }

                        AnimatedImage {
                            id: wMonPreviewGif
                            visible: root.heavySectionsReady && wMonPreviewCard.isGif
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: visible ? wMonPreviewCard.wpUrl : ""
                            asynchronous: true
                            cache: false
                            playing: false
                        }

                        Image {
                            id: wMonPreviewVideo
                            visible: root.heavySectionsReady && wMonPreviewCard.isVideo
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: {
                                if (!root.heavySectionsReady) return ""
                                const ff = Wallpapers.videoFirstFrames[wMonPreviewCard.displayPath]
                                return ff ? (ff.startsWith("file://") ? ff : "file://" + ff) : ""
                            }
                            asynchronous: true
                            cache: false
                            Component.onCompleted: {
                                if (root.heavySectionsReady)
                                    Wallpapers.ensureVideoFirstFrame(wMonPreviewCard.displayPath)
                            }
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
                                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
                                    }
                                }
                            }
                            WButton {
                                Layout.fillWidth: true
                                text: Translation.tr("Random")
                                icon.name: "arrow-sync"
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
                                    Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
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
                            icon: "eyedropper"
                            checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                            onCheckedChanged: {
                                if (!root.settingsHandlersReady)
                                    return
                                Config.setNestedValue("appearance.wallpaperTheming.useBackdropForColors", checked)
                                if (checked && !(root.wBackdrop.useMainWallpaper ?? true)) {
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
                                        if (!root.heavySectionsReady) return Translation.tr("Wallpapers")
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
                                    visible: root.heavySectionsReady
                                    text: root.heavySectionsReady ? (Wallpapers.folderModel.count + " " + Translation.tr("items")) : ""
                                    font.pixelSize: Looks.font.pixelSize.tiny
                                    color: Looks.colors.subfg
                                    opacity: 0.5
                                }
                            }

                            ListView {
                                id: bgWpStrip
                                visible: root.heavySectionsReady
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                orientation: ListView.Horizontal
                                spacing: 3
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                model: root.heavySectionsReady ? Wallpapers.folderModel : null

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
                                    Behavior on scale { animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard } }

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
                                        id: bgThumbImg
                                        visible: !bgWpThumb.fileIsDir && !WallpaperListener.isVideoPath(bgWpThumb.filePath)
                                        anchors.fill: parent
                                        anchors.margins: bgWpThumb.border.width
                                        fillMode: Image.PreserveAspectCrop
                                        source: visible ? bgWpThumb.thumbSource : ""
                                        sourceSize.width: 140
                                        sourceSize.height: 140
                                        cache: true
                                        asynchronous: true
                                        onStatusChanged: {
                                            if (status === Image.Error && bgWpThumb.filePath)
                                                source = bgWpThumb.filePath.startsWith("file://") ? bgWpThumb.filePath : "file://" + bgWpThumb.filePath
                                        }
                                        Connections {
                                            target: Wallpapers
                                            function onThumbnailGenerated(directory) {
                                                if (bgThumbImg.status !== Image.Ready && bgWpThumb.filePath) {
                                                    bgThumbImg.source = ""
                                                    bgThumbImg.source = bgWpThumb.thumbSource
                                                }
                                            }
                                        }
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
                                            if (root.heavySectionsReady && WallpaperListener.isVideoPath(bgWpThumb.filePath))
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

                            WText {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                font.pixelSize: Looks.font.pixelSize.small - 2
                                color: Looks.colors.subfg
                                opacity: 0.6
                                text: Translation.tr("%1 monitors detected").arg(WallpaperListener.screenCount) + "  ·  " + Translation.tr("Ctrl+Alt+T targets focused output")
                            }
                        }
                    }
                }
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Desktop Clock")
        icon: "schedule"

        WSettingsSwitch {
            label: Translation.tr("Enable clock")
            icon: "schedule"
            description: Translation.tr("Show a desktop clock on the Waffle wallpaper layer")
            checked: root.wClock.enable ?? false
            onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.enable", checked)
        }

        ColumnLayout {
            visible: root.wClock.enable ?? false
            Layout.fillWidth: true
            spacing: 0

                    WSettingsRow {
                        label: Translation.tr("Placement")
                        icon: "drag_pan"
                        description: Translation.tr("Use Draggable to place it manually, or let Waffle choose the least busy region")
                    }

                    Grid {
                        id: clockPlacementGrid
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        columns: 3
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: [
                                { label: Translation.tr("Draggable"), value: "free" },
                                { label: Translation.tr("Least busy"), value: "leastBusy" },
                                { label: Translation.tr("Most busy"), value: "mostBusy" }
                            ]

                            delegate: WChoiceButton {
                                required property var modelData
                                Layout.fillWidth: false
                                width: Math.max(0, (clockPlacementGrid.width - 12) / 3)
                                text: modelData.label
                                checked: (root.wClock.placementStrategy ?? "leastBusy") === modelData.value
                                onClicked: Config.setNestedValue("waffles.background.widgets.clock.placementStrategy", modelData.value)
                            }
                        }
                    }

                    WSettingsButton {
                        visible: (root.wClock.placementStrategy ?? "leastBusy") === "free"
                        label: Translation.tr("Reset free position")
                        icon: "arrow-counterclockwise"
                        description: Translation.tr("Move the draggable clock back to its default position")
                        buttonText: Translation.tr("Center")
                        buttonIcon: "arrow-counterclockwise"
                        onButtonClicked: {
                            Config.setNestedValue("waffles.background.widgets.clock.x", 100)
                            Config.setNestedValue("waffles.background.widgets.clock.y", 100)
                        }
                    }

                    WSettingsDropdown {
                        label: Translation.tr("Clock style")
                        icon: "desktop"
                        description: Translation.tr("Choose how prominent the wallpaper clock feels")
                        currentValue: root.wClock.style ?? "hero"
                        options: [
                            { value: "hero", displayName: Translation.tr("Hero") },
                            { value: "balanced", displayName: Translation.tr("Balanced") },
                            { value: "minimal", displayName: Translation.tr("Minimal") }
                        ]
                        onSelected: newValue => Config.setNestedValue("waffles.background.widgets.clock.style", newValue)
                    }

                    WSettingsDropdown {
                        label: Translation.tr("Time format")
                        icon: "schedule"
                        description: Translation.tr("Follow the global clock format or override it for the wallpaper clock")
                        currentValue: root.wClock.timeFormat ?? "system"
                        options: [
                            { value: "system", displayName: Translation.tr("Follow system") },
                            { value: "24h", displayName: Translation.tr("24-hour") },
                            { value: "12h", displayName: Translation.tr("12-hour") }
                        ]
                        onSelected: newValue => Config.setNestedValue("waffles.background.widgets.clock.timeFormat", newValue)
                    }

                    WSettingsSwitch {
                        label: Translation.tr("Show seconds")
                        icon: "timer"
                        description: Translation.tr("Update the wallpaper clock every second")
                        checked: root.wClock.showSeconds ?? false
                        onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.showSeconds", checked)
                    }

                    WSettingsSwitch {
                        label: Translation.tr("Show date")
                        icon: "desktop"
                        description: Translation.tr("Display a second line with the current date")
                        checked: root.wClock.showDate ?? true
                        onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.showDate", checked)
                    }

                    WSettingsDropdown {
                        visible: root.wClock.showDate ?? true
                        label: Translation.tr("Date style")
                        icon: "desktop"
                        description: Translation.tr("Control how much date information is shown")
                        currentValue: root.wClock.dateStyle ?? "long"
                        options: [
                            { value: "long", displayName: Translation.tr("Long") },
                            { value: "minimal", displayName: Translation.tr("Minimal") },
                            { value: "weekday", displayName: Translation.tr("Weekday only") },
                            { value: "numeric", displayName: Translation.tr("Numeric") }
                        ]
                        onSelected: newValue => Config.setNestedValue("waffles.background.widgets.clock.dateStyle", newValue)
                    }

                    WSettingsDropdown {
                        label: Translation.tr("Color tone")
                        icon: "eyedropper"
                        description: Translation.tr("Blend with wallpaper colors or keep the text neutral")
                        currentValue: root.wClock.colorMode ?? "adaptive"
                        options: [
                            { value: "adaptive", displayName: Translation.tr("Adaptive") },
                            { value: "accent", displayName: Translation.tr("Accent") },
                            { value: "plain", displayName: Translation.tr("Plain") }
                        ]
                        onSelected: newValue => Config.setNestedValue("waffles.background.widgets.clock.colorMode", newValue)
                    }

                    WSettingsSwitch {
                        label: Translation.tr("Animate time change")
                        icon: "arrow-clockwise"
                        description: Translation.tr("Smoothly animate the clock text when time changes")
                        checked: root.wClock.digital?.animateChange ?? true
                        onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.digital.animateChange", checked)
                    }

                    WSettingsSpinBox {
                        label: Translation.tr("Clock dim")
                        icon: "dark-theme"
                        description: Translation.tr("Darken the clock text without affecting the wallpaper")
                        suffix: "%"
                        from: 0; to: 100; stepSize: 5
                        value: root.wClock.dim ?? 55
                        onValueChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.dim", value)
                    }

                    WSettingsSpinBox {
                        label: Translation.tr("Time scale")
                        icon: "auto"
                        description: Translation.tr("Scale the main time line independently")
                        suffix: "%"
                        from: 65; to: 160; stepSize: 5
                        value: root.wClock.timeScale ?? 100
                        onValueChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.timeScale", value)
                    }

                    WSettingsSpinBox {
                        visible: root.wClock.showDate ?? true
                        label: Translation.tr("Date scale")
                        icon: "auto"
                        description: Translation.tr("Scale the date line independently")
                        suffix: "%"
                        from: 65; to: 160; stepSize: 5
                        value: root.wClock.dateScale ?? 100
                        onValueChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.dateScale", value)
                    }

                    WSettingsSwitch {
                        label: Translation.tr("Show shadow")
                        icon: "dark-theme"
                        description: Translation.tr("Use a shadow behind the text for better contrast")
                        checked: root.wClock.showShadow ?? true
                        onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.showShadow", checked)
                    }

                    WSettingsSwitch {
                        label: Translation.tr("Show lock status")
                        icon: "desktop"
                        description: Translation.tr("Show the locked status row when the screen is locked")
                        checked: root.wClock.showLockStatus ?? true
                        onCheckedChanged: root.setNestedValueWhenReady("waffles.background.widgets.clock.showLockStatus", checked)
                    }

                    WSettingsRow {
                        label: Translation.tr("Clock font")
                        icon: "keyboard"
                        description: Translation.tr("Choose a more Windows-like font for the Waffle desktop clock")
                    }

                    Grid {
                        id: clockFontGrid
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.bottomMargin: 8
                        columns: 2
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: [
                                { label: Translation.tr("Waffle UI"), value: Looks.font.family.ui },
                                { label: "Segoe UI Variable Display", value: "Segoe UI Variable Display" },
                                { label: "Segoe UI Variable Text", value: "Segoe UI Variable Text" },
                                { label: "Inter", value: "Inter" },
                                { label: "Roboto Flex", value: "Roboto Flex" }
                            ]

                            delegate: WChoiceButton {
                                required property var modelData
                                Layout.fillWidth: false
                                width: Math.max(0, (clockFontGrid.width - 16 * 2 - 6) / 2)
                                text: modelData.label
                                checked: (root.wClock.fontFamily ?? "Segoe UI Variable Display") === modelData.value
                                onClicked: Config.setNestedValue("waffles.background.widgets.clock.fontFamily", modelData.value)
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
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.enableAnimation", checked)
                }

                WSettingsSwitch {
                    label: Translation.tr("Enable blur")
                    icon: "eye"
                    description: Translation.tr("Blur wallpaper when windows are open. Temporarily hides during wallpaper transitions.")
                    checked: root.wEffects.enableBlur ?? false
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.effects.enableBlur", checked)
                }

                WSettingsSwitch {
                    visible: root.wBg.enableAnimation ?? true
                    label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
                    icon: "eye"
                    description: Translation.tr("Apply blur to animated wallpapers. Independent from window blur. May significantly impact performance.")
                    checked: root.wEffects.enableAnimatedBlur ?? false
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.effects.enableAnimatedBlur", checked)
                }

                WSettingsSpinBox {
                    visible: root.wEffects.enableBlur ?? false
                    label: Translation.tr("Blur radius")
                    icon: "eye"
                    description: Translation.tr("Amount of blur applied to wallpaper")
                    from: 0; to: 100; stepSize: 5
                    value: root.wEffects.blurRadius ?? 32
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.effects.blurRadius", value)
                }

                WSettingsSpinBox {
                    visible: root.wEffects.enableAnimatedBlur ?? false
                    label: Translation.tr("Animated blur strength")
                    icon: "eye"
                    description: Translation.tr("Blur intensity for animated wallpapers (0-100%)")
                    suffix: "%"
                    from: 0; to: 100; stepSize: 5
                    value: root.wEffects.thumbnailBlurStrength ?? 70
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.effects.thumbnailBlurStrength", value)
                }

                WSettingsSpinBox {
                    label: Translation.tr("Dim overlay")
                    icon: "dark-theme"
                    description: Translation.tr("Darken the wallpaper")
                    suffix: "%"
                    from: 0; to: 100; stepSize: 5
                    value: root.wEffects.dim ?? 0
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.effects.dim", value)
                }

                WSettingsSpinBox {
                    label: Translation.tr("Extra dim with windows")
                    icon: "dark-theme"
                    description: Translation.tr("Additional dim when windows are present")
                    suffix: "%"
                    from: 0; to: 100; stepSize: 5
                    value: root.wEffects.dynamicDim ?? 0
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.effects.dynamicDim", value)
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
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.enable", checked)
                }

                WSettingsSwitch {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                    icon: "play"
                    description: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
                    checked: root.wBackdrop.enableAnimation ?? false
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.enableAnimation", checked)
                }

                WSettingsSwitch {
                    visible: (root.wBackdrop.enable ?? true) && (root.wBackdrop.enableAnimation ?? false)
                    label: Translation.tr("Blur animated wallpapers (videos/GIFs)")
                    icon: "eye"
                    description: Translation.tr("Apply blur to animated wallpapers in backdrop. May significantly impact performance.")
                    checked: root.wBackdrop.enableAnimatedBlur ?? false
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.enableAnimatedBlur", checked)
                }

                WSettingsSwitch {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Use separate wallpaper")
                    icon: "image"
                    description: Translation.tr("Use a different wallpaper for backdrop")
                    checked: !(root.wBackdrop.useMainWallpaper ?? true)
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.useMainWallpaper", !checked)
                }

                WSettingsButton {
                    visible: (root.wBackdrop.enable ?? true) && !(root.wBackdrop.useMainWallpaper ?? true)
                    label: Translation.tr("Backdrop wallpaper")
                    icon: "image"
                    buttonText: Translation.tr("Change")
                    onButtonClicked: {
                        Config.setNestedValue("wallpaperSelector.selectionTarget", "waffle-backdrop")
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "wallpaperSelector", "toggle"])
                    }
                }

                WSettingsSwitch {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Derive theme colors from backdrop")
                    icon: "eyedropper"
                    description: Translation.tr("Generate theme colors from the backdrop wallpaper instead of the main wallpaper")
                    checked: Config.options?.appearance?.wallpaperTheming?.useBackdropForColors ?? false
                    onCheckedChanged: {
                        if (!root.settingsHandlersReady)
                            return
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
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.hideWallpaper", checked)
                }

                WSettingsSpinBox {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Backdrop blur")
                    icon: "eye"
                    description: Translation.tr("Amount of blur for backdrop layer")
                    from: 0; to: 100; stepSize: 5
                    value: root.wBackdrop.blurRadius ?? 64
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.blurRadius", value)
                }

                WSettingsSpinBox {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Backdrop dim")
                    icon: "dark-theme"
                    description: Translation.tr("Darken the backdrop layer")
                    suffix: "%"
                    from: 0; to: 100; stepSize: 5
                    value: root.wBackdrop.dim ?? 20
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.dim", value)
                }

                WSettingsSpinBox {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Backdrop saturation")
                    icon: "eyedropper"
                    description: Translation.tr("Increase color intensity")
                    suffix: "%"
                    from: -100; to: 100; stepSize: 10
                    value: root.wBackdrop.saturation ?? 0
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.saturation", value)
                }

                WSettingsSpinBox {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Backdrop contrast")
                    icon: "auto"
                    description: Translation.tr("Increase light/dark difference")
                    suffix: "%"
                    from: -100; to: 100; stepSize: 10
                    value: root.wBackdrop.contrast ?? 0
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.contrast", value)
                }

                WSettingsSwitch {
                    visible: root.wBackdrop.enable ?? true
                    label: Translation.tr("Enable vignette")
                    icon: "border-outside"
                    description: Translation.tr("Add a dark gradient around the edges of the backdrop")
                    checked: root.wBackdrop.vignetteEnabled ?? false
                    onCheckedChanged: root.setNestedValueWhenReady("waffles.background.backdrop.vignetteEnabled", checked)
                }

                WSettingsSpinBox {
                    visible: (root.wBackdrop.enable ?? true) && (root.wBackdrop.vignetteEnabled ?? false)
                    label: Translation.tr("Vignette intensity")
                    icon: "border-outside"
                    description: Translation.tr("How dark the vignette effect should be")
                    suffix: "%"
                    from: 0; to: 100; stepSize: 5
                    value: Math.round((root.wBackdrop.vignetteIntensity ?? 0.5) * 100)
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.vignetteIntensity", value / 100.0)
                }

                WSettingsSpinBox {
                    visible: (root.wBackdrop.enable ?? true) && (root.wBackdrop.vignetteEnabled ?? false)
                    label: Translation.tr("Vignette radius")
                    icon: "border-outside"
                    description: Translation.tr("How far the vignette extends from the edges")
                    suffix: "%"
                    from: 10; to: 100; stepSize: 5
                    value: Math.round((root.wBackdrop.vignetteRadius ?? 0.7) * 100)
                    onValueChanged: root.setNestedValueWhenReady("waffles.background.backdrop.vignetteRadius", value / 100.0)
                }
            }
}
