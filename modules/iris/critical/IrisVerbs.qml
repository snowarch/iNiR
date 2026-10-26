import QtQuick
import qs
import qs.modules.common
import qs.services
import qs.services.deferred

// How iRiS answers the shell's shared verbs: its own Orbit, a Place in the chassis with one layout and no Studio,
// and Spotlight for task view, the overview and the clipboard. Cleared when iRiS goes, so Material's come back.
QtObject {
    id: root

    function _orbitOn(): bool { return Config.options?.iris?.orbit?.enable ?? false }
    function _spotlight(prefix: string): void {
        LauncherSearch.ensurePrefix(prefix)
        GlobalStates.searchOpen = true
    }
    readonly property string _clipboardPrefix: Config.options?.search?.prefix?.clipboard ?? ";"

    readonly property var verbs: ({
        taskview: {
            toggle: () => { if (root._orbitOn()) GlobalStates.irisOrbitOpen = !GlobalStates.irisOrbitOpen; else GlobalStates.searchOpen = !GlobalStates.searchOpen },
            open: () => { if (root._orbitOn()) GlobalStates.irisOrbitOpen = true; else GlobalStates.searchOpen = true },
            close: () => { GlobalStates.irisOrbitOpen = false; GlobalStates.searchOpen = false }
        },
        orbit: {
            toggle: () => { GlobalStates.irisOrbitOpen = !GlobalStates.irisOrbitOpen },
            open: () => { GlobalStates.irisOrbitOpen = true },
            close: () => { GlobalStates.irisOrbitOpen = false },
            pocket: () => { GlobalStates.irisOrbitOpen = true },
            studio: () => {},
            stage: () => {},
            orbital: () => {},
            toggleView: () => {},
            find: query => { GlobalStates.irisOrbitQuery = query; GlobalStates.irisOrbitOpen = true },
            next: () => NiriService.focusWorkspaceDown(),
            previous: () => NiriService.focusWorkspaceUp(),
            status: () => JSON.stringify({ family: "iris", open: GlobalStates.irisOrbitOpen, enabled: root._orbitOn(),
                output: GlobalStates.focusedScreen?.name ?? "" })
        },
        overview: {
            toggle: () => { GlobalStates.searchOpen = !GlobalStates.searchOpen },
            open: () => { GlobalStates.searchOpen = true },
            close: () => { GlobalStates.searchOpen = false },
            clipboardToggle: () => root._spotlight(root._clipboardPrefix),
            actionOpen: () => root._spotlight(Config.options?.search?.prefix?.action ?? "/")
        },
        clipboard: {
            open: () => root._spotlight(root._clipboardPrefix),
            close: () => { GlobalStates.searchOpen = false },
            toggle: () => { if (GlobalStates.searchOpen) GlobalStates.searchOpen = false; else root._spotlight(root._clipboardPrefix) }
        }
    })

    Component.onCompleted: GlobalStates.familyVerbs = root.verbs
    Component.onDestruction: if (GlobalStates.familyVerbs === root.verbs) GlobalStates.familyVerbs = ({})
}
