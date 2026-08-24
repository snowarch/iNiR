pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

// Stable Alt+Tab IPC router plus lightweight no-visual controller. Visual ii
// commands are delivered internally to AltSwitcher.qml; visual Waffle commands
// stay family-local. No-UI modes preserve MRU cycling without constructing the
// full switcher windows, preview delegates, shaders or icon cache.
Scope {
    id: root

    property bool quickSwitchDone: false
    property var snapshot: []
    property int currentIndex: 0

    readonly property bool waffleFamilyActive:
        (Config.options?.panelFamily ?? "ii") === "waffle"
    readonly property string iiPreset:
        Config.options?.altSwitcher?.preset ?? "default"
    readonly property bool iiNoVisual:
        (Config.options?.altSwitcher?.noVisualUi ?? false)
        && root.iiPreset !== "skew"
    readonly property bool routeToVisualIi:
        !root.waffleFamilyActive && !root.iiNoVisual
    readonly property var waffleOptions:
        Config.options?.waffles?.altSwitcher ?? ({})
    readonly property string wafflePreset: waffleOptions.preset ?? "thumbnails"
    readonly property bool waffleNoVisual:
        wafflePreset === "none"
        || ((waffleOptions.noVisualUi ?? false) && wafflePreset !== "skew")
    readonly property bool routeToVisualWaffle:
        waffleFamilyActive && !waffleNoVisual
    readonly property bool useMostRecentFirst: waffleFamilyActive
        ? (waffleOptions.useMostRecentFirst ?? true)
        : (Config.options?.altSwitcher?.useMostRecentFirst ?? true)

    Timer {
        id: resetTimer
        interval: 800
        repeat: false
        onTriggered: root.resetSession()
    }

    function resetSession(): void {
        quickSwitchDone = false
        snapshot = []
        currentIndex = 0
        GlobalStates.altSwitcherOpen = false
    }

    function forwardToVisualIi(functionName: string): void {
        GlobalStates.altSwitcherCommand(functionName)
    }

    function routeToWaffle(functionName: string): void {
        Quickshell.execDetached([
            Quickshell.shellPath("scripts/inir"),
            "waffleAltSwitcher",
            functionName
        ])
    }

    function buildSnapshot(): var {
        const windows = NiriService.windows ?? []
        const workspaces = NiriService.workspaces ?? ({})
        const mruIds = NiriService.mruWindowIds ?? []
        if (windows.length === 0)
            return []

        const items = []
        const itemsById = ({})
        for (let i = 0; i < windows.length; ++i) {
            const window = windows[i]
            const appId = AppSearch.resolveWindowIdentity(window)
            const item = {
                id: window.id,
                appId: appId,
                title: window.title ?? "",
                workspaceId: window.workspace_id,
                workspaceIndex: workspaces[window.workspace_id]?.idx ?? 0
            }
            items.push(item)
            itemsById[item.id] = item
        }

        items.sort((left, right) => {
            if (left.workspaceIndex !== right.workspaceIndex)
                return left.workspaceIndex - right.workspaceIndex
            const leftName = left.appId || left.title
            const rightName = right.appId || right.title
            const nameOrder = leftName.localeCompare(rightName)
            return nameOrder !== 0 ? nameOrder : left.id - right.id
        })

        if (!root.useMostRecentFirst || mruIds.length === 0)
            return items

        const ordered = []
        const used = ({})
        for (let i = 0; i < mruIds.length; ++i) {
            const id = mruIds[i]
            if (itemsById[id] !== undefined) {
                ordered.push(itemsById[id])
                used[id] = true
            }
        }
        for (let i = 0; i < items.length; ++i) {
            const item = items[i]
            if (!used[item.id])
                ordered.push(item)
        }
        return ordered
    }

    function focusCurrent(): void {
        const length = snapshot?.length ?? 0
        if (length === 0)
            return
        const index = Math.max(0, Math.min(length - 1, currentIndex))
        const windowId = snapshot[index]?.id
        if (windowId !== undefined)
            NiriService.focusWindow(windowId)
    }

    function step(direction: int): void {
        GlobalStates.altSwitcherOpen = false

        if (!quickSwitchDone || (snapshot?.length ?? 0) === 0)
            snapshot = buildSnapshot()

        const length = snapshot?.length ?? 0
        if (length === 0) {
            resetSession()
            return
        }

        if (!quickSwitchDone) {
            quickSwitchDone = true
            currentIndex = length > 1
                ? (direction > 0 ? 1 : length - 1)
                : 0
        } else {
            currentIndex = (currentIndex + direction + length) % length
        }

        focusCurrent()
        resetTimer.restart()
    }

    Component.onCompleted: GlobalStates.altSwitcherOpen = false
    onRouteToVisualIiChanged: root.resetSession()
    onRouteToVisualWaffleChanged: root.resetSession()

    IpcHandler {
        target: "altSwitcher"

        function open(): void {
            if (root.routeToVisualWaffle) {
                root.routeToWaffle("open")
                return
            }
            if (root.routeToVisualIi) {
                root.forwardToVisualIi("open")
                return
            }
            root.step(1)
        }

        function close(): void {
            if (root.routeToVisualWaffle) {
                root.routeToWaffle("close")
                return
            }
            if (root.routeToVisualIi) {
                root.forwardToVisualIi("close")
                return
            }
            root.resetSession()
        }

        function toggle(): void {
            if (root.routeToVisualWaffle) {
                root.routeToWaffle("toggle")
                return
            }
            if (root.routeToVisualIi) {
                root.forwardToVisualIi("toggle")
                return
            }
            root.step(1)
        }

        function next(): void {
            if (root.routeToVisualWaffle) {
                root.routeToWaffle("next")
                return
            }
            if (root.routeToVisualIi) {
                root.forwardToVisualIi("next")
                return
            }
            root.step(1)
        }

        function previous(): void {
            if (root.routeToVisualWaffle) {
                root.routeToWaffle("previous")
                return
            }
            if (root.routeToVisualIi) {
                root.forwardToVisualIi("previous")
                return
            }
            root.step(-1)
        }
    }
}
