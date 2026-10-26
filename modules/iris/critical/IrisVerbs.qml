import QtQuick
import qs
import qs.modules.common
import qs.services
import qs.services.deferred
import qs.modules.iris.state

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

    function _musicOn(mode: string): bool {
        const edge = Config.options?.background?.edgeWidgets?.organic ?? ({})
        return Boolean(edge.enable) && String(Config.options?.iris?.surround?.music ?? "widget") === mode
    }
    function _toggleMusic(mode: string): void {
        if (root._musicOn(mode)) {
            Config.setNestedValue("background.edgeWidgets.organic.enable", false)
            return
        }
        const updates = { "iris.surround.music": mode, "background.edgeWidgets.organic.enable": true }
        if (mode === "frame") updates["iris.surround.enable"] = true
        Config.setNestedValues(updates)
    }
    readonly property var _actions: [
        {
            id: "frame-music",
            name: Translation.tr("Frame Music"),
            description: Translation.tr("Toggle music on the iRiS frame"),
            icon: "graphic_eq",
            category: "appearance",
            keywords: ["iris", "frame", "chassis", "music", "visualizer"],
            isOn: () => root._musicOn("frame"),
            execute: () => root._toggleMusic("frame")
        },
        {
            id: "edge-music",
            name: Translation.tr("Edge Music"),
            description: Translation.tr("Toggle the Organic Edge music wave"),
            icon: "waves",
            category: "appearance",
            keywords: ["iris", "edge", "music", "wave", "visualizer"],
            isOn: () => root._musicOn("widget"),
            execute: () => root._toggleMusic("widget")
        }
    ]

    readonly property var verbs: ({
        owner: "iris",
        actions: {
            list: () => root._actions
        },
        media: {
            cover: player => AnimeWatch.ownsPlayer(player) ? AnimeWatch.playingCover : ""
        },
        family: {
            leave: () => IrisState.endEditing()
        },
        dev: {
            open: surface => {
                switch (surface) {
                case "iris-palette": GlobalStates.searchOpen = true; return true
                case "iris-controls": GlobalStates.controlPanelOpen = true; return true
                case "iris-session": GlobalStates.sessionOpen = true; return true
                }
                return false
            }
        },
        sidebar: {
            opens: side => Config.options?.iris?.sidebars?.[side]?.enable ?? true
        },
        taskview: {
            toggle: () => { if (root._orbitOn()) IrisState.orbitOpen = !IrisState.orbitOpen; else GlobalStates.searchOpen = !GlobalStates.searchOpen },
            open: () => { if (root._orbitOn()) IrisState.orbitOpen = true; else GlobalStates.searchOpen = true },
            close: () => { IrisState.orbitOpen = false; GlobalStates.searchOpen = false }
        },
        orbit: {
            toggle: () => { IrisState.orbitOpen = !IrisState.orbitOpen },
            open: () => { IrisState.orbitOpen = true },
            close: () => { IrisState.orbitOpen = false },
            pocket: () => { IrisState.orbitOpen = true },
            studio: () => {},
            stage: () => {},
            orbital: () => {},
            toggleView: () => {},
            find: query => { IrisState.orbitQuery = query; IrisState.orbitOpen = true },
            next: () => NiriService.focusWorkspaceDown(),
            previous: () => NiriService.focusWorkspaceUp(),
            status: () => JSON.stringify({ family: "iris", open: IrisState.orbitOpen, enabled: root._orbitOn(),
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
