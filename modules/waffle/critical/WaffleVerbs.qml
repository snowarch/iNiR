import QtQuick
import qs
import qs.modules.common
import qs.services
import qs.services.deferred

// How Waffle answers the shell's shared verbs: Task View, its own clipboard and the Start search for the overview;
// Orbit stays Material's. Cleared when Waffle goes.
QtObject {
    id: root

    function _search(prefix: string): void {
        LauncherSearch.ensurePrefix(prefix)
        GlobalStates.searchOpen = true
    }

    readonly property var verbs: ({
        taskview: {
            toggle: () => { GlobalStates.waffleTaskViewOpen = !GlobalStates.waffleTaskViewOpen },
            open: () => { GlobalStates.waffleTaskViewOpen = true },
            close: () => { GlobalStates.waffleTaskViewOpen = false }
        },
        overview: {
            toggle: () => { GlobalStates.searchOpen = !GlobalStates.searchOpen },
            open: () => { GlobalStates.searchOpen = true },
            close: () => { GlobalStates.searchOpen = false },
            clipboardToggle: () => root._search(Config.options?.search?.prefix?.clipboard ?? ";"),
            actionOpen: () => root._search(Config.options?.search?.prefix?.action ?? "/")
        },
        clipboard: {
            open: () => { GlobalStates.waffleClipboardOpen = true },
            close: () => { GlobalStates.waffleClipboardOpen = false },
            toggle: () => { GlobalStates.waffleClipboardOpen = !GlobalStates.waffleClipboardOpen }
        }
    })

    Component.onCompleted: GlobalStates.familyVerbs = root.verbs
    Component.onDestruction: if (GlobalStates.familyVerbs === root.verbs) GlobalStates.familyVerbs = ({})
}
