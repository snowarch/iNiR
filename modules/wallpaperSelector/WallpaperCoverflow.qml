pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Fullscreen coverflow wallpaper selector — alternative to the grid WallpaperSelector.
 * Activated when Config wallpaperSelector.style === "coverflow", or directly via IPC.
 *
 * Full-featured: supports selectionTarget (main/backdrop/waffle/waffle-backdrop),
 * multi-monitor, dark mode toggle, folder navigation, search, and runtime switch to grid.
 */
Scope {
    id: root

    // ─── Monitor resolution ───
    readonly property var focusedScreen: CompositorService.isNiri
        ? (Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen)
        : (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen)
    readonly property var defaultScreen: GlobalStates.primaryScreen ?? focusedScreen

    readonly property var targetScreen: {
        const targetMon = Config.options?.wallpaperSelector?.targetMonitor ?? ""
        if (targetMon && targetMon.length > 0) {
            const s = Quickshell.screens.find(scr => scr.name === targetMon)
            if (s) return s
        }
        return root.defaultScreen
    }

    // ─── View mode: "gallery" or "skew" ───
    property string _viewMode: Config.options?.wallpaperSelector?.coverflowView ?? "gallery"

    // ─── Selected monitor (for per-monitor wallpaper) ───
    readonly property bool multiMonitorActive: Config.options?.background?.multiMonitor?.enable ?? false
    readonly property string selectedMonitor: {
        if (!multiMonitorActive) return ""
        const gsTarget = GlobalStates.wallpaperSelectorTargetMonitor ?? ""
        if (gsTarget && gsTarget.length > 0) return gsTarget
        const configTarget = Config.options?.wallpaperSelector?.targetMonitor ?? ""
        return configTarget ?? ""
    }
    readonly property string currentSelectionTarget: Wallpapers.currentSelectionTarget()
    readonly property string currentSelectionPath: Wallpapers.currentWallpaperPathForTarget(currentSelectionTarget, selectedMonitor)

    // ─── Selection logic (mirrors WallpaperSelectorContent.selectWallpaperPath) ───
    function selectWallpaperPath(filePath, useDarkMode) {
        if (!filePath || filePath.length === 0) return

        const normalizedPath = FileUtils.trimFileProtocol(String(filePath))
        Wallpapers.applySelectionTarget(normalizedPath, root.currentSelectionTarget, useDarkMode, root.selectedMonitor)

        Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
        Config.setNestedValue("wallpaperSelector.targetMonitor", "")
        GlobalStates.wallpaperSelectionTarget = "main"
        GlobalStates.wallpaperSelectorTargetMonitor = ""
        GlobalStates.coverflowSelectorOpen = false
    }

    // ─── Switch to grid mode ───
    function switchToGrid() {
        GlobalStates.coverflowSelectorOpen = false
        // Small delay so the coverflow panel closes before grid opens
        switchTimer.start()
    }

    Timer {
        id: switchTimer
        interval: 80
        repeat: false
        onTriggered: {
            Config.setNestedValue("wallpaperSelector.style", "grid")
            GlobalStates.wallpaperSelectorOpen = true
        }
    }

    // ─── Panel ───
    Loader {
        id: coverflowLoader
        active: GlobalStates.coverflowSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: root.targetScreen

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:coverflowSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // ─── Staggered entry state ───
            property bool _entryReady: false
            property bool _contentReady: false

            Timer {
                id: contentEntryTimer
                interval: Appearance.animationsEnabled ? 80 : 0
                repeat: false
                onTriggered: panelWindow._contentReady = true
            }

            Component.onCompleted: {
                // Auto-detect selection target based on active family
                // (mirrors WallpaperSelector.qml's family-aware target logic)
                const explicitTarget = Config.options?.wallpaperSelector?.selectionTarget ?? "main"
                if (explicitTarget === "main") {
                    if (Config.options?.panelFamily === "waffle") {
                        const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
                        Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
                    }
                }

                // Sync directory to current wallpaper's folder on open
                // (The Connections handler below can't catch the initial signal
                //  because the Loader creates us AFTER coverflowSelectorOpen changed)
                const wp = root.currentSelectionPath
                const wpDir = FileUtils.parentDirectory(FileUtils.trimFileProtocol(String(wp)))
                if (wpDir && wpDir.length > 0)
                    Wallpapers.setDirectory(wpDir)
                Wallpapers.searchQuery = ""
                // Update thumbnails on the active view
                const activeView = viewLoader.item
                if (activeView && typeof activeView.updateThumbnails === "function")
                    activeView.updateThumbnails()

                if (Appearance.animationsEnabled) {
                    // Kick off staggered entry: scrim first, content after delay
                    Qt.callLater(() => { panelWindow._entryReady = true })
                    contentEntryTimer.start()
                } else {
                    panelWindow._entryReady = true
                    panelWindow._contentReady = true
                }
            }

            // Scrim (dark overlay behind cards)
            Rectangle {
                id: scrim
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: panelWindow._entryReady ? 1.0 : 0.0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.calcEffectiveDuration(320)
                        easing.type: Easing.OutCubic
                    }
                }

                GE.RadialGradient {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: ColorUtils.transparentize(Appearance.colors.colScrim, 1) }
                        GradientStop { position: 0.55; color: ColorUtils.transparentize(Appearance.colors.colScrim, 1) }
                        GradientStop { position: 1.0; color: Appearance.colors.colScrim }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.3) }
                        GradientStop { position: 0.5; color: "transparent" }
                        GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.3) }
                    }
                    opacity: 0.85
                }
            }

            // ─── View: Gallery or Skew ───
            Loader {
                id: viewLoader
                anchors.fill: parent
                focus: true
                sourceComponent: root._viewMode === "skew" ? skewViewComponent : galleryViewComponent
            }

            Component {
                id: galleryViewComponent
                WallpaperCoverflowGallery {
                    id: coverflowContent
                    focus: true
                    folderModel: Wallpapers.folderModel
                    currentWallpaperPath: root.currentSelectionPath

                    // Staggered entry animation — content comes in after scrim
                    transformOrigin: Item.Center
                    scale: panelWindow._contentReady ? 1.0 : 0.92
                    opacity: panelWindow._contentReady ? 1.0 : 0.0
                    y: panelWindow._contentReady ? 0 : 18
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(420)
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(300)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(380)
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }

                    onWallpaperSelected: filePath => {
                        root.selectWallpaperPath(filePath, coverflowContent.useDarkMode)
                    }
                    onDirectorySelected: dirPath => {
                        Wallpapers.setDirectory(dirPath)
                    }
                    onCloseRequested: {
                        GlobalStates.coverflowSelectorOpen = false
                    }
                    onSwitchToGridRequested: {
                        root.switchToGrid()
                    }
                    onSwitchToSkewRequested: {
                        root._viewMode = "skew"
                        Config.setNestedValue("wallpaperSelector.coverflowView", "skew")
                    }

                    Component.onCompleted: updateThumbnails()
                }
            }

            Component {
                id: skewViewComponent
                WallpaperSkewView {
                    id: skewContent
                    focus: true
                    folderModel: Wallpapers.folderModel
                    currentWallpaperPath: root.currentSelectionPath

                    // Staggered entry animation
                    transformOrigin: Item.Center
                    scale: panelWindow._contentReady ? 1.0 : 0.92
                    opacity: panelWindow._contentReady ? 1.0 : 0.0
                    y: panelWindow._contentReady ? 0 : 18
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(420)
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(300)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.calcEffectiveDuration(380)
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }

                    onWallpaperSelected: filePath => {
                        root.selectWallpaperPath(filePath, skewContent.useDarkMode)
                    }
                    onDirectorySelected: dirPath => {
                        Wallpapers.setDirectory(dirPath)
                    }
                    onCloseRequested: {
                        GlobalStates.coverflowSelectorOpen = false
                    }
                    onSwitchToGridRequested: {
                        root.switchToGrid()
                    }
                    onSwitchToGalleryRequested: {
                        root._viewMode = "gallery"
                        Config.setNestedValue("wallpaperSelector.coverflowView", "gallery")
                    }

                    Component.onCompleted: updateThumbnails()
                }
            }

            // Sync directory on re-open (Loader stays active if not destroyed)
            // Primary sync happens in Component.onCompleted above
            Connections {
                target: GlobalStates
                function onCoverflowSelectorOpenChanged() {
                    if (GlobalStates.coverflowSelectorOpen && panelWindow._contentReady) {
                        const wp = root.currentSelectionPath
                        const wpDir = FileUtils.parentDirectory(FileUtils.trimFileProtocol(String(wp)))
                        if (wpDir && wpDir.length > 0)
                            Wallpapers.setDirectory(wpDir)
                        Wallpapers.searchQuery = ""
                        // Update thumbnails on the active view
                        const activeView = viewLoader.item
                        if (activeView && typeof activeView.updateThumbnails === "function")
                            activeView.updateThumbnails()
                    }
                }
            }

            // Click outside to close (Hyprland)
            CompositorFocusGrab {
                id: grab
                windows: [ panelWindow ]
                active: CompositorService.isHyprland && coverflowLoader.active
                onCleared: () => {
                    if (!active) {
                        GlobalStates.coverflowSelectorOpen = false
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "coverflowSelector"

        function toggle(): void {
            GlobalStates.coverflowSelectorOpen = !GlobalStates.coverflowSelectorOpen
        }

        function open(): void {
            GlobalStates.coverflowSelectorOpen = true
        }

        function close(): void {
            GlobalStates.coverflowSelectorOpen = false
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "coverflowSelectorToggle"
                description: "Toggle coverflow wallpaper selector"
                onPressed: {
                    GlobalStates.coverflowSelectorOpen = !GlobalStates.coverflowSelectorOpen
                }
            }
        }
    }
}
