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
    property bool _presentedOpen: false
    Component.onCompleted: {
        if (GlobalStates.wallpaperSelectorOpen)
            Qt.callLater(() => { root._presentedOpen = GlobalStates.wallpaperSelectorOpen })
    }

    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen || _wsClosing

        property bool _wsClosing: false

        Connections {
            target: GlobalStates
            function onWallpaperSelectorOpenChanged() {
                if (GlobalStates.wallpaperSelectorOpen) {
                    Qt.callLater(() => { root._presentedOpen = GlobalStates.wallpaperSelectorOpen })
                } else {
                    root._presentedOpen = false
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
                return GlobalStates.focusedScreen ?? GlobalStates.primaryScreen
            }
            readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(panelWindow.screen) : null
            property bool monitorIsFocused: CompositorService.isHyprland 
                ? (Hyprland.focusedMonitor?.id == monitor?.id)
                : (CompositorService.isNiri ? (panelWindow.screen?.name === NiriService.currentOutput) : true)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.wallpaperSelectorOpen && !GlobalStates.regionSelectorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                    topMargin: (Config.options?.bar?.vertical ?? false) ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
                }
                implicitHeight: Appearance.sizes.wallpaperSelectorHeight
                implicitWidth: Appearance.sizes.wallpaperSelectorWidth
                // Subtle scale + fade when opening/closing the wallpaper selector
                transformOrigin: Item.Top
                scale: root._presentedOpen ? 1.0 : 0.93
                opacity: root._presentedOpen ? 1.0 : 0.0
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: root._presentedOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: root._presentedOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

}
