import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property Component regionComponent: Component {
        Region {}
    }

    // Keep PanelWindow alive after first open for instant subsequent toggles.
    // The Loader stays active once created; visibility is driven by GlobalStates.overlayOpen.
    property bool _everOpened: false

    // Capture target screen when opening (don't follow focus while open)
    property var targetScreen: null

    // Ready flag to ensure screen is set before window becomes visible
    property bool _readyToShow: false

    Connections {
        target: GlobalStates
        function onOverlayOpenChanged() {
            if (GlobalStates.overlayOpen) {
                // Hide first to ensure screen updates before showing
                root._readyToShow = false
                // Mark as opened so the Loader stays active forever
                root._everOpened = true
                // Set target screen when opening
                const outputName = NiriService.currentOutput
                root.targetScreen = Quickshell.screens.find(s => s.name === outputName) ?? Quickshell.screens[0] ?? null
                console.log("[Overlay] Opening on output:", outputName, "targetScreen:", root.targetScreen?.name)
                // Now ready to show on correct screen
                root._readyToShow = true
            } else {
                root._readyToShow = false
            }
        }
    }

    Loader {
        id: overlayLoader
        // Once opened, keep alive — no more destroy/recreate on every toggle
        active: root._everOpened
        sourceComponent: PanelWindow {
            id: overlayWindow
            // Visible only when overlay is open
            visible: GlobalStates.overlayOpen
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            // Exclusive focus when open; OnDemand for pinned clickable widgets when closed;
            // None otherwise (avoids input capture during GameMode)
            WlrLayershell.keyboardFocus: GlobalStates.overlayOpen
                ? WlrKeyboardFocus.Exclusive
                : (OverlayContext.clickableWidgets.length > 0 && !GameMode.active
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None)
            color: "transparent"

            mask: Region {
                item: GlobalStates.overlayOpen ? overlayContent : null
                regions: OverlayContext.clickableWidgets.map((widget) => regionComponent.createObject(this, {
                    item: widget
                }));
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            CompositorFocusGrab {
                id: grab
                windows: [overlayWindow]
                active: false
                onCleared: () => {
                    if (!active) GlobalStates.overlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverlayOpenChanged() {
                    delayedGrabTimer.restart()
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Config.options.overlay.animationDurationMs ?? Appearance.animation.elementMoveFast.duration
                onTriggered: {
                    grab.active = GlobalStates.overlayOpen;
                }
            }

            OverlayContent {
                id: overlayContent
                anchors.fill: parent
            }
        }
    }

    IpcHandler {
        target: "overlay"

        function toggle(): void {
            GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "overlayToggle"
                description: "Toggles overlay on press"

                onPressed: {
                    GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
                }
            }
        }
    }
}
