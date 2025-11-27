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

    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(panelWindow.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland 
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (CompositorService.isNiri ? (panelWindow.screen?.name === NiriService.currentOutput) : true)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            CompositorFocusGrab { // Click outside to close
                id: grab
                windows: [ panelWindow ]
                active: wallpaperSelectorLoader.active
                onCleared: () => {
                    if (!active) GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    fill: parent
                }
                // Subtle scale + fade when opening the wallpaper selector
                transformOrigin: Item.Top
                scale: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.97
                opacity: GlobalStates.wallpaperSelectorOpen ? 1.0 : 0.0
                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
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
