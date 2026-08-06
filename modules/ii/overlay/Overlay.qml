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

    // Check persistent state directly to bootstrap the Loader before widgets register
    readonly property bool _hasPersistentPins: {
        const overlay = Persistent.states.overlay;
        const openWidgets = overlay.open;
        if (!openWidgets || openWidgets.length === 0) return false;
        for (let i = 0; i < openWidgets.length; i++) {
            const entry = overlay[openWidgets[i]];
            if (entry && entry.pinned) return true;
        }
        return false;
    }

    // Capture target screen when opening (don't follow focus while open)
    property var targetScreen: null

    // Ready flag to ensure screen is set before window becomes visible
    property bool _readyToShow: false

    Component.onCompleted: {
        if (GlobalStates.overlayOpen) {
            root._everOpened = true
            const outputName = NiriService.currentOutput
            root.targetScreen = Quickshell.screens.find(s => s.name === outputName) ?? GlobalStates.primaryScreen ?? null
            root._readyToShow = true
        }
    }

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
                root.targetScreen = Quickshell.screens.find(s => s.name === outputName) ?? GlobalStates.primaryScreen ?? null
                if (Quickshell.env("QS_DEBUG") === "1") console.log("[Overlay] Opening on output:", outputName, "targetScreen:", root.targetScreen?.name)
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
        // Also activate if persistent state has pinned widgets (bootstraps before widgets register)
        active: root._everOpened || root._hasPersistentPins
        sourceComponent: PanelWindow {
            id: overlayWindow
            // Visible when overlay is open OR when there are pinned widgets to show
            visible: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:overlay"
            // Native dialogs are ordinary toplevel windows. Yield the layer-shell
            // overlay while one is visible so the picker is not buried behind it.
            WlrLayershell.layer: OverlayContext.nativeDialogOpen
                ? WlrLayer.Bottom : WlrLayer.Overlay
            // Exclusive focus when open; OnDemand for pinned clickable widgets when closed;
            // None otherwise (avoids input capture during GameMode)
            WlrLayershell.keyboardFocus: OverlayContext.nativeDialogOpen
                ? WlrKeyboardFocus.None
                : GlobalStates.overlayOpen
                ? WlrKeyboardFocus.Exclusive
                : (OverlayContext.clickableWidgets.length > 0
                    ? WlrKeyboardFocus.OnDemand
                    : WlrKeyboardFocus.None)
            color: "transparent"

            // Zero-size item ensures an explicit empty input region instead of
            // ambiguous null (which compositors may treat as "full surface input").
            // Critical: this is a full-screen overlay surface — a stale null mask
            // would capture ALL input on the entire screen during gamemode.
            Item { id: emptyMask; width: 0; height: 0 }

            // Tracks the region objects the mask below created, so the previous batch can be
            // destroyed instead of leaked on every pin/clickthrough toggle. Rebuilt imperatively
            // (not via a `regions:` binding) because reading+writing the same tracking property
            // inside that binding's own evaluation is a binding loop.
            property var _activeClickableRegions: []
            function _rebuildClickableRegions() {
                for (const region of overlayWindow._activeClickableRegions) region.destroy();
                overlayWindow._activeClickableRegions = OverlayContext.clickableWidgets.map((widget) => regionComponent.createObject(overlayWindow, {
                    item: widget
                }));
                clickableRegionMask.regions = overlayWindow._activeClickableRegions;
            }
            Component.onCompleted: overlayWindow._rebuildClickableRegions()
            Connections {
                target: OverlayContext
                function onClickableWidgetsChanged() { overlayWindow._rebuildClickableRegions(); }
            }
            mask: Region {
                id: clickableRegionMask
                item: GlobalStates.overlayOpen && !OverlayContext.nativeDialogOpen
                    ? overlayContent : emptyMask
                regions: []
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
                    if (!active && !OverlayContext.nativeDialogOpen)
                        GlobalStates.overlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onOverlayOpenChanged() {
                    delayedGrabTimer.restart()
                }
            }

            Connections {
                target: OverlayContext
                function onNativeDialogOpenChanged() {
                    if (OverlayContext.nativeDialogOpen)
                        grab.active = false
                    else
                        delayedGrabTimer.restart()
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: Appearance.calcEffectiveDuration(
                    Config.options.overlay.animationDurationMs ?? Appearance.animation.elementMoveFast.duration)
                onTriggered: {
                    grab.active = GlobalStates.overlayOpen
                        && !OverlayContext.nativeDialogOpen;
                }
            }

            OverlayContent {
                id: overlayContent
                anchors.fill: parent
            }
        }
    }

}
