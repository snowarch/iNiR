pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.services

// Waffle's own panels, open or not. It travels with Waffle; the base sees only what it publishes below.
Singleton {
    id: root

    property bool actionCenterOpen: false
    property bool notificationCenterOpen: false
    property bool widgetsOpen: false
    property bool altSwitcherOpen: false
    property bool clipboardOpen: false
    property bool taskViewOpen: false

    // Close other waffle popups when one opens (unless allowMultiplePanels is enabled)
    readonly property bool _allowMultiple: Config.options?.waffles?.behavior?.allowMultiplePanels ?? false
    onActionCenterOpenChanged: {
        if (actionCenterOpen && !_allowMultiple) {
            GlobalStates.searchOpen = false
            notificationCenterOpen = false
            widgetsOpen = false
            clipboardOpen = false
        }
    }
    onNotificationCenterOpenChanged: {
        if (notificationCenterOpen) {
            if (!_allowMultiple) {
                GlobalStates.searchOpen = false
                actionCenterOpen = false
                widgetsOpen = false
                clipboardOpen = false
            }
            // Mark notifications as read when opening notification center
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }
    onWidgetsOpenChanged: {
        if (widgetsOpen && !_allowMultiple) {
            GlobalStates.searchOpen = false
            actionCenterOpen = false
            notificationCenterOpen = false
            clipboardOpen = false
        }
    }
    onClipboardOpenChanged: {
        if (clipboardOpen && !_allowMultiple) {
            GlobalStates.searchOpen = false
            actionCenterOpen = false
            notificationCenterOpen = false
            widgetsOpen = false
            taskViewOpen = false
        }
    }
    onTaskViewOpenChanged: {
        if (taskViewOpen && !_allowMultiple) {
            GlobalStates.searchOpen = false
            actionCenterOpen = false
            notificationCenterOpen = false
            widgetsOpen = false
            clipboardOpen = false
        }
    }
    Connections {
        target: GlobalStates
        function onSearchOpenChanged(): void {
            if (GlobalStates.searchOpen && !root._allowMultiple) {
                root.actionCenterOpen = false
                root.notificationCenterOpen = false
                root.widgetsOpen = false
                root.clipboardOpen = false
            }
        }
    }

    // What the base reads while Waffle is the family: which of its panels are up (bits in this order), whether its
    // quick settings and its notification list are on screen.
    readonly property bool _active: Plugins.active === "waffle"
    Binding {
        target: GlobalStates
        property: "familyPanelsOpen"
        when: root._active
        value: (root.actionCenterOpen ? 1 : 0) | (root.notificationCenterOpen ? 2 : 0) | (root.widgetsOpen ? 4 : 0)
            | (root.clipboardOpen ? 8 : 0) | (root.taskViewOpen ? 16 : 0) | (root.altSwitcherOpen ? 32 : 0)
    }
    Binding {
        target: GlobalStates
        property: "familyQuickSettingsOpen"
        when: root._active
        value: root.actionCenterOpen
    }
    Binding {
        target: GlobalStates
        property: "familyNotificationsOpen"
        when: root._active
        value: root.notificationCenterOpen
    }
}
