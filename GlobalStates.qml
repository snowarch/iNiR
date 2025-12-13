pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool osdMediaOpen: false
    property string osdMediaAction: "play" // "play", "pause", "next", "previous"
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property bool altSwitcherOpen: false
    property bool clipboardOpen: false
    property bool regionSelectorOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    // Selection targets: "main", "backdrop", "waffle", "waffle-backdrop"
    property string wallpaperSelectionTarget: "main"
    onWallpaperSelectorOpenChanged: {
        // Reset selection target when selector closes without selection
        if (!wallpaperSelectorOpen) {
            wallpaperSelectionTarget = "main";
            // Also reset Config target if it was set
            if (Config.options?.wallpaperSelector?.selectionTarget && 
                Config.options.wallpaperSelector.selectionTarget !== "main") {
                Config.options.wallpaperSelector.selectionTarget = "main";
            }
        }
    }
    property bool cheatsheetOpen: false
    property bool workspaceShowNumbers: false
    property var activeBooruImageMenu: null  // Track which BooruImage has its menu open
    property var activeTaskViewMenu: null  // Track which WindowThumbnail has its menu open
    // Waffle-specific states
    property bool searchOpen: false
    property bool waffleActionCenterOpen: false
    property bool waffleNotificationCenterOpen: false
    property bool waffleWidgetsOpen: false
    property bool waffleAltSwitcherOpen: false
    property bool waffleClipboardOpen: false
    property bool waffleTaskViewOpen: false

    // Panel family transition animation state
    property bool familyTransitionActive: false
    property string familyTransitionDirection: "left" // "left" = current exits left, new enters from right

    // Close other waffle popups when one opens (unless allowMultiplePanels is enabled)
    property bool _allowMultiple: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false
    onSearchOpenChanged: {
        if (searchOpen && !_allowMultiple) {
            waffleActionCenterOpen = false
            waffleNotificationCenterOpen = false
            waffleWidgetsOpen = false
            waffleClipboardOpen = false
        }
    }
    onWaffleActionCenterOpenChanged: {
        if (waffleActionCenterOpen && !_allowMultiple) {
            searchOpen = false
            waffleNotificationCenterOpen = false
            waffleWidgetsOpen = false
            waffleClipboardOpen = false
        }
    }
    onWaffleNotificationCenterOpenChanged: {
        if (waffleNotificationCenterOpen) {
            if (!_allowMultiple) {
                searchOpen = false
                waffleActionCenterOpen = false
                waffleWidgetsOpen = false
                waffleClipboardOpen = false
            }
            // Mark notifications as read when opening notification center
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }
    onWaffleWidgetsOpenChanged: {
        if (waffleWidgetsOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleNotificationCenterOpen = false
            waffleClipboardOpen = false
        }
    }
    onWaffleClipboardOpenChanged: {
        if (waffleClipboardOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleNotificationCenterOpen = false
            waffleWidgetsOpen = false
            waffleTaskViewOpen = false
        }
    }
    onWaffleTaskViewOpenChanged: {
        if (waffleTaskViewOpen && !_allowMultiple) {
            searchOpen = false
            waffleActionCenterOpen = false
            waffleNotificationCenterOpen = false
            waffleWidgetsOpen = false
            waffleClipboardOpen = false
        }
    }

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    property real screenZoom: 1
    onScreenZoomChanged: {
        // Niri doesn't have native zoom support like Hyprland's cursor:zoom_factor
        // The IPC handler still works but zoom is Hyprland-only for now
        if (!CompositorService.isHyprland)
            return;
        Quickshell.execDetached(["hyprctl", "keyword", "cursor:zoom_factor", root.screenZoom.toString()]);
    }
    Behavior on screenZoom {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "workspaceNumber"
            description: "Hold to show workspace numbers, release to show icons"

            onPressed: {
                root.superDown = true
            }
            onReleased: {
                root.superDown = false
            }
        }
    }

    IpcHandler {
		target: "zoom"

		function zoomIn(): void {
            screenZoom = Math.min(screenZoom + 0.4, 3.0)
        }

        function zoomOut(): void {
            screenZoom = Math.max(screenZoom - 0.4, 1)
        } 
	}
}
