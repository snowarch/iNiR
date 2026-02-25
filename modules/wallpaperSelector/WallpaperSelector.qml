import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    // Canonical focused screen detection (same pattern as OSD, notifications, brightness)
    readonly property var focusedScreen: CompositorService.isNiri
        ? (Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0])
        : (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
    readonly property string focusedMonitorName: focusedScreen?.name ?? ""

    // Async focused output detection for Niri.
    // NiriService.currentOutput becomes stale after PanelWindow steals compositor focus.
    // Querying niri directly gives the real focused output at invocation time.
    Process {
        id: niriOutputDetector
        property string _buffer: ""
        stdout: SplitParser {
            onRead: data => {
                niriOutputDetector._buffer += data + "\n"
            }
        }
        onExited: (code, status) => {
            let monName = ""
            if (code === 0 && niriOutputDetector._buffer) {
                try {
                    const obj = JSON.parse(niriOutputDetector._buffer)
                    monName = obj.name || ""
                } catch(e) {}
            }
            niriOutputDetector._buffer = ""
            if (!monName) monName = root.focusedMonitorName
            root._openWithMonitor(monName)
        }
    }

    function _openWithMonitor(monName) {
        if (monName) {
            GlobalStates.wallpaperSelectorTargetMonitor = monName
            Config.setNestedValue("wallpaperSelector.targetMonitor", monName)
        }
        GlobalStates.wallpaperSelectorOpen = true
    }

    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen || _wsClosing

        property bool _wsClosing: false

        Connections {
            target: GlobalStates
            function onWallpaperSelectorOpenChanged() {
                if (!GlobalStates.wallpaperSelectorOpen) {
                    wallpaperSelectorLoader._wsClosing = true
                    _wsCloseTimer.restart()
                }
            }
        }

        Timer {
            id: _wsCloseTimer
            interval: 200
            onTriggered: wallpaperSelectorLoader._wsClosing = false
        }

        sourceComponent: PanelWindow {
            id: panelWindow
            // Show on the target monitor so focus stays correct after close
            screen: {
                const targetMon = GlobalStates.wallpaperSelectorTargetMonitor
                if (targetMon) {
                    const s = Quickshell.screens.find(s => s.name === targetMon)
                    if (s) return s
                }
                return root.focusedScreen
            }
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(panelWindow.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland 
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (CompositorService.isNiri ? (panelWindow.screen?.name === NiriService.currentOutput) : true)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            CompositorFocusGrab { // Click outside to close (Hyprland)
                id: grab
                windows: [ panelWindow ]
                active: CompositorService.isHyprland && wallpaperSelectorLoader.active
                onCleared: () => {
                    if (!active) GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            // Click outside to close (all compositors)
            MouseArea {
                anchors.fill: parent
                onClicked: mouse => {
                    const localPos = mapToItem(content, mouse.x, mouse.y)
                    if (localPos.x < 0 || localPos.x > content.width
                            || localPos.y < 0 || localPos.y > content.height) {
                        GlobalStates.wallpaperSelectorOpen = false;
                    }
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
                }
                implicitHeight: Appearance.sizes.wallpaperSelectorHeight
                implicitWidth: Appearance.sizes.wallpaperSelectorWidth
                // Subtle scale + fade when opening/closing the wallpaper selector
                transformOrigin: Item.Top
                scale: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.93
                opacity: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.0
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: GlobalStates.wallpaperSelectorOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: GlobalStates.wallpaperSelectorOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options?.wallpaperSelector?.useSystemFileDialog ?? false) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }

        // If already open, just close
        if (GlobalStates.wallpaperSelectorOpen) {
            GlobalStates.wallpaperSelectorOpen = false
            return
        }

        // Check if settings UI explicitly set a target (e.g. from QuickConfig "Change" button)
        const explicitMonitor = Config.options?.wallpaperSelector?.targetMonitor ?? ""
        const explicitTarget = Config.options?.wallpaperSelector?.selectionTarget ?? "main"
        const hasExplicitTarget = explicitMonitor || (explicitTarget !== "main")

        if (!hasExplicitTarget) {
            // No explicit target: auto-detect based on family
            if (Config.options?.panelFamily === "waffle") {
                const useMain = Config.options?.waffles?.background?.useMainWallpaper ?? true
                Config.setNestedValue("wallpaperSelector.selectionTarget", useMain ? "main" : "waffle")
            } else {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            }
            const multiMon = Config.options?.background?.multiMonitor?.enable ?? false
            if (multiMon) {
                // For Niri: query focused output asynchronously (NiriService.currentOutput
                // can be stale after a previous PanelWindow changed compositor focus)
                if (CompositorService.isNiri && !niriOutputDetector.running) {
                    niriOutputDetector.exec(["niri", "msg", "-j", "focused-output"])
                    return
                }
                // Hyprland or fallback: use live binding (reliable)
                _openWithMonitor(root.focusedMonitorName)
                return
            }
        } else if (explicitMonitor) {
            GlobalStates.wallpaperSelectorTargetMonitor = explicitMonitor
        }

        GlobalStates.wallpaperSelectorOpen = true
    }

    // Cleanup is handled by GlobalStates.onWallpaperSelectorOpenChanged

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function toggleOnMonitor(monitorName: string): void {
            if (monitorName && monitorName.length > 0) {
                GlobalStates.wallpaperSelectorTargetMonitor = monitorName
                Config.setNestedValue("wallpaperSelector.targetMonitor", monitorName)
            }
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "wallpaperSelectorToggle"
                description: "Toggle wallpaper selector"
                onPressed: {
                    root.toggleWallpaperSelector();
                }
            }

            GlobalShortcut {
                name: "wallpaperSelectorRandom"
                description: "Select random wallpaper in current folder"
                onPressed: {
                    Wallpapers.randomFromCurrentFolder();
                }
            }
        }
    }
}
