import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.bar
import Quickshell

AppButton {
    id: root

    required property var appEntry
    property var tasksParent: null  // Reference to Tasks for closing other menus
    readonly property bool isSeparator: appEntry.appId === "SEPARATOR"
    readonly property var desktopEntry: DesktopEntries.heuristicLookup(appEntry.appId)
    property bool active: root.appEntry.toplevels.some(t => t.activated)
    property bool hasWindows: appEntry.toplevels.length > 0

    // Focused window index for smart indicator (Niri)
    property int focusedWindowIndex: {
        if (!root.active || appEntry.toplevels.length <= 1) return 0;
        const focusedToplevel = appEntry.toplevels.find(t => t.activated === true);
        if (!focusedToplevel) return 0;
        
        if (CompositorService.isNiri && focusedToplevel.niriWindowId) {
            const niriWindows = NiriService.windows;
            const windowPositions = [];
            for (let i = 0; i < appEntry.toplevels.length; i++) {
                const tl = appEntry.toplevels[i];
                let col = 999999;
                if (tl.niriWindowId) {
                    const niriWin = niriWindows.find(w => w.id === tl.niriWindowId);
                    if (niriWin?.layout?.pos_in_scrolling_layout) {
                        col = niriWin.layout.pos_in_scrolling_layout[0];
                    }
                }
                windowPositions.push({ idx: i, col: col, activated: tl.activated });
            }
            windowPositions.sort((a, b) => a.col - b.col);
            for (let i = 0; i < windowPositions.length; i++) {
                if (windowPositions[i].activated) return i;
            }
        }
        
        for (let i = 0; i < appEntry.toplevels.length; i++) {
            if (appEntry.toplevels[i].activated) return i;
        }
        return 0;
    }

    signal hoverPreviewRequested()
    signal hoverPreviewDismissed()

    multiple: appEntry.toplevels.length > 1
    checked: active
    iconName: AppSearch.guessIcon(appEntry.appId)
    tryCustomIcon: false
    
    onHoverTimedOut: {
        root.hoverPreviewRequested()
    }

    // Count of minimized windows for this app
    readonly property int minimizedCount: MinimizedWindows.countMinimizedForApp(appEntry.appId)
    readonly property bool hasMinimized: minimizedCount > 0

    // Helper to find Niri windows for this app
    function findAppWindows() {
        const appId = root.appEntry.appId.toLowerCase();
        return NiriService.windows.filter(w => {
            const wAppId = (w.app_id ?? "").toLowerCase();
            return wAppId === appId || wAppId.includes(appId) || appId.includes(wAppId);
        });
    }

    // Track if this app was active (focused) - use the toplevel activated state
    // which is more reliable than checking NiriService during click
    readonly property bool wasActive: root.active

    onClicked: {
        root.hoverTimer.stop()
        
        const appWindows = findAppWindows();
        const isAppFocused = root.wasActive;
        
        // Case 1: App is focused -> minimize it (move down)
        if (isAppFocused && appWindows.length > 0) {
            const windowToMinimize = appWindows.find(w => w.is_focused) || appWindows[0];
            MinimizedWindows.minimize(windowToMinimize.id);
            return;
        }
        
        // Case 2: App has minimized windows -> restore the latest
        if (root.hasMinimized) {
            MinimizedWindows.restoreLatestForApp(root.appEntry.appId);
            return;
        }
        
        // Case 3: App has visible windows but not focused -> focus it
        if (appWindows.length > 0) {
            NiriService.focusWindow(appWindows[0].id);
            return;
        }
        
        // Case 4: App not running -> launch it
        if (root.desktopEntry) {
            root.desktopEntry.execute()
        }
    }

    middleClickAction: () => {
        if (root.desktopEntry) {
            desktopEntry.execute()
        }
    }

    altAction: () => {
        root.hoverPreviewDismissed()
        root.hoverTimer.stop()
        // Close other context menus first
        if (tasksParent) tasksParent.closeAllContextMenus()
        contextMenu.active = true;
    }
    
    Connections {
        target: root.tasksParent
        enabled: root.tasksParent !== null
        function onCloseAllContextMenus() {
            if (contextMenu.active && contextMenu.item) {
                contextMenu.item.close();
            }
        }
    }

    // Smart indicator: W11 style pills showing window count and which is focused
    Row {
        id: indicatorRow
        visible: root.hasWindows || root.hasMinimized
        anchors {
            horizontalCenter: root.background.horizontalCenter
            bottom: root.background.bottom
            bottomMargin: 1
        }
        spacing: 2

        // Active windows
        Repeater {
            model: Math.min(appEntry.toplevels.length, 5)
            delegate: Rectangle {
                required property int index
                property bool isFocused: root.active && index === root.focusedWindowIndex

                implicitWidth: isFocused ? 16 : 4
                implicitHeight: 3
                radius: height / 2
                color: isFocused ? Looks.colors.accent : Looks.colors.accentUnfocused

                Behavior on implicitWidth {
                    animation: Looks.transition.enter.createObject(this)
                }
                Behavior on color {
                    animation: Looks.transition.color.createObject(this)
                }
            }
        }
        
        // Minimized windows (dimmed indicator)
        Repeater {
            model: Math.min(root.minimizedCount, 3)
            delegate: Rectangle {
                implicitWidth: 4
                implicitHeight: 3
                radius: height / 2
                color: Looks.colors.fg1
                opacity: 0.5
            }
        }

        Behavior on opacity {
            animation: Looks.transition.opacity.createObject(this)
        }
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip && !root.hasWindows
        text: desktopEntry ? desktopEntry.name : appEntry.appId
    }

    BarMenu {
        id: contextMenu
        anchorHovered: root.hovered
        noSmoothClosing: false // On the real thing this is always smooth

        model: [
            ...((root.desktopEntry?.actions.length > 0) ? root.desktopEntry.actions.map(action =>({
                iconName: action.icon,
                text: action.name,
                action: () => {
                    action.execute()
                }
            })).concat({ type: "separator" }) : []),
            {
                iconName: root.iconName,
                text: root.desktopEntry ? root.desktopEntry.name : StringUtils.toTitleCase(appEntry.appId),
                monochromeIcon: false,
                action: () => {
                    if (root.desktopEntry) {
                        root.desktopEntry.execute()
                    }
                }
            },
            {
                iconName: root.appEntry.pinned ? "pin-off" : "pin",
                text: root.appEntry.pinned ? Translation.tr("Unpin from taskbar") : Translation.tr("Pin to taskbar"),
                action: () => {
                    TaskbarApps.togglePin(root.appEntry.appId);
                }
            },
            // Move down option (only for running apps)
            ...(root.appEntry.toplevels.length > 0 ? [
                {
                    iconName: "caret-down",
                    text: root.multiple ? Translation.tr("Move all down") : Translation.tr("Move down"),
                    action: () => {
                        // Find Niri windows matching this app
                        const appId = root.appEntry.appId.toLowerCase();
                        const niriWindows = NiriService.windows.filter(w => {
                            const wAppId = (w.app_id ?? "").toLowerCase();
                            return wAppId === appId || wAppId.includes(appId) || appId.includes(wAppId);
                        });
                        
                        for (const niriWin of niriWindows) {
                            MinimizedWindows.minimize(niriWin.id);
                        }
                    }
                },
                {
                    iconName: "dismiss",
                    text: root.multiple ? Translation.tr("Close all windows") : Translation.tr("Close window"),
                    action: () => {
                        for (let toplevel of root.appEntry.toplevels) {
                            toplevel.close();
                        }
                    }
                }
            ] : []),
        ]
    }
}
