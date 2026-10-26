import QtQuick
import qs
import qs.modules.common
import qs.services
import qs.services.deferred
import qs.modules.waffle.state

// How Waffle answers the shell's shared verbs: Task View, its own clipboard and the Start search for the overview,
// its dev destinations; Orbit stays Material's. Cleared when Waffle goes.
QtObject {
    id: root

    function _search(prefix: string): void {
        LauncherSearch.ensurePrefix(prefix)
        GlobalStates.searchOpen = true
    }

    readonly property var verbs: ({
        owner: "waffle",
        // Leaving Waffle closes its panels, so they don't come back open with it.
        family: {
            leave: () => {
                WaffleState.actionCenterOpen = false
                WaffleState.notificationCenterOpen = false
                WaffleState.widgetsOpen = false
                WaffleState.altSwitcherOpen = false
                WaffleState.clipboardOpen = false
                WaffleState.taskViewOpen = false
            }
        },
        taskview: {
            toggle: () => { WaffleState.taskViewOpen = !WaffleState.taskViewOpen },
            open: () => { WaffleState.taskViewOpen = true },
            close: () => { WaffleState.taskViewOpen = false }
        },
        overview: {
            toggle: () => { GlobalStates.searchOpen = !GlobalStates.searchOpen },
            open: () => { GlobalStates.searchOpen = true },
            close: () => { GlobalStates.searchOpen = false },
            clipboardToggle: () => root._search(Config.options?.search?.prefix?.clipboard ?? ";"),
            actionOpen: () => root._search(Config.options?.search?.prefix?.action ?? "/")
        },
        dev: {
            open: surface => {
                switch (surface) {
                case "waffle-action-center": WaffleState.actionCenterOpen = true; return true
                case "waffle-notification-center": WaffleState.notificationCenterOpen = true; return true
                case "waffle-widgets": WaffleState.widgetsOpen = true; return true
                case "waffle-taskview": WaffleState.taskViewOpen = true; return true
                }
                return false
            },
            close: () => {
                WaffleState.actionCenterOpen = false
                WaffleState.notificationCenterOpen = false
                WaffleState.widgetsOpen = false
                WaffleState.taskViewOpen = false
            }
        },
        clipboard: {
            open: () => { WaffleState.clipboardOpen = true },
            close: () => { WaffleState.clipboardOpen = false },
            toggle: () => { WaffleState.clipboardOpen = !WaffleState.clipboardOpen }
        }
    })

    Component.onCompleted: GlobalStates.familyVerbs = root.verbs
    Component.onDestruction: if (GlobalStates.familyVerbs === root.verbs) GlobalStates.familyVerbs = ({})
}
