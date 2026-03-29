import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root

    property var itemSnapshot: []
    property var iconCache: ({})  // Cache de iconos resueltos
    property bool _warmedUp: false
    property bool overviewOpenedByAltSwitcher: false
    property int currentIndex: 0
    property bool quickSwitchDone: false  // Track if quick switch already happened this session
    property var noUiSnapshot: []
    property int noUiIndex: 0

    property bool cardVisible: false

    // Config getters
    function cfg() { return Config.options?.waffles?.altSwitcher ?? {} }
    function getPreset() { return cfg().preset ?? "thumbnails" }
    function getNoVisualUi() {
        const preset = getPreset()
        return preset === "none" || ((cfg().noVisualUi ?? false) && preset !== "skew")
    }
    function getScrimOpacity() { return cfg().scrimOpacity ?? 0.4 }
    function getAutoHide() { return cfg().autoHide ?? true }
    function getCloseOnFocus() { return cfg().closeOnFocus ?? true }
    function getQuickSwitch() { return cfg().quickSwitch ?? false }
    function getShowOverview() { return cfg().showOverviewWhileSwitching ?? false }
    function getUseMostRecentFirst() { return cfg().useMostRecentFirst ?? true }
    function getAutoHideDelayMs() { return cfg().autoHideDelayMs ?? 500 }

    // Resuelve y cachea el icono
    function getCachedIcon(appId, appName, title) {
        const key = appId || appName || title || ""
        if (iconCache[key] !== undefined) return iconCache[key]
        const icon = AppSearch.getIconSource(key)
        iconCache[key] = icon
        return icon
    }

    function toTitleCase(name) {
        if (!name) return ""
        let s = name.replace(/[._-]+/g, " ")
        const parts = s.split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            const p = parts[i]
            if (!p) continue
            parts[i] = p.charAt(0).toUpperCase() + p.slice(1)
        }
        return parts.join(" ")
    }

    function buildItemsFrom(windows, workspaces, mruIds) {
        if (!windows || !windows.length) return []

        const items = []
        const itemsById = {}

        for (let i = 0; i < windows.length; i++) {
            const w = windows[i]
            const appId = w.app_id || ""
            let appName = appId
            if (appName && appName.indexOf(".") !== -1) {
                const parts = appName.split(".")
                appName = parts[parts.length - 1]
            }
            if (!appName && w.title) appName = w.title
            appName = toTitleCase(appName)

            const ws = workspaces[w.workspace_id]
            const wsIdx = ws && ws.idx !== undefined ? ws.idx : 0

            items.push({
                id: w.id,
                appId: appId,
                appName: appName,
                title: w.title || "",
                workspaceId: w.workspace_id,
                workspaceIdx: wsIdx,
                isFocused: w.is_focused ?? false,
                isFloating: w.is_floating ?? false,
                icon: root.getCachedIcon(appId, appName, w.title)
            })
            itemsById[w.id] = items[items.length - 1]
        }

        // Sort by workspace then app name
        items.sort((a, b) => {
            const ia = workspaces[a.workspaceId]?.idx ?? 0
            const ib = workspaces[b.workspaceId]?.idx ?? 0
            if (ia !== ib) return ia - ib
            const cmp = (a.appName || a.title || "").localeCompare(b.appName || b.title || "")
            if (cmp !== 0) return cmp
            return a.id - b.id
        })

        // MRU ordering
        if (root.getUseMostRecentFirst() && mruIds?.length > 0) {
            const ordered = []
            const used = {}
            for (const id of mruIds) {
                if (itemsById[id]) {
                    ordered.push(itemsById[id])
                    used[id] = true
                }
            }
            for (const it of items) {
                if (!used[it.id]) ordered.push(it)
            }
            return ordered
        }
        return items
    }

    function rebuildSnapshot() {
        itemSnapshot = buildItemsFrom(
            NiriService.windows || [],
            NiriService.workspaces || {},
            NiriService.mruWindowIds || []
        )
        currentIndex = 0
        _warmedUp = true
    }

    function rebuildNoUiSnapshot() {
        root.noUiSnapshot = buildItemsFrom(
            NiriService.windows || [],
            NiriService.workspaces || {},
            NiriService.mruWindowIds || []
        )
        root.noUiIndex = 0
    }

    function focusNoUiIndex() {
        const len = root.noUiSnapshot?.length ?? 0
        if (len <= 0)
            return
        const idx = Math.max(0, Math.min(len - 1, root.noUiIndex))
        const id = root.noUiSnapshot[idx]?.id
        if (id !== undefined)
            NiriService.focusWindow(id)
    }

    // Pre-warm al inicio
    Timer {
        id: warmUpTimer
        interval: 2000
        running: !root._warmedUp && (NiriService.windows?.length ?? 0) > 0
        onTriggered: {
            root.rebuildSnapshot()
            Qt.callLater(function() {
                if (!GlobalStates.waffleAltSwitcherOpen)
                    root.itemSnapshot = []
            })
        }
    }

    function maybeOpenOverview() {
        if (!CompositorService.isNiri || !root.getShowOverview()) return
        if (!NiriService.inOverview) {
            overviewOpenedByAltSwitcher = true
            NiriService.toggleOverview()
        }
    }

    function maybeCloseOverview() {
        if (!CompositorService.isNiri || !root.getShowOverview()) return
        if (overviewOpenedByAltSwitcher && NiriService.inOverview) {
            NiriService.toggleOverview()
        }
        overviewOpenedByAltSwitcher = false
    }

    function openSwitcher() {
        // Don't rebuild if we already have a snapshot from quick switch
        if (!quickSwitchDone) {
            rebuildSnapshot()
        }
        quickSwitchResetTimer.stop()  // Cancel reset timer since we're opening UI
        if (itemSnapshot.length === 0) return
        if (root.getPreset() === "skew")
            currentIndex = itemSnapshot.length > 1 ? 1 : 0
        GlobalStates.waffleAltSwitcherOpen = true
        if (root.getPreset() === "skew") {
            root.cardVisible = false
            cardShowTimer.restart()
        } else {
            root.cardVisible = true
        }
        maybeOpenOverview()
        if (CompositorService.isNiri && root.getPreset() === "skew") {
            Qt.callLater(() => WindowPreviewService.captureForTaskView())
        }
        if (root.getAutoHide() && root.getPreset() !== "skew")
            autoHideTimer.restart()
    }

    function closeSwitcher() {
        autoHideTimer.stop()
        GlobalStates.waffleAltSwitcherOpen = false
        root.cardVisible = false
        quickSwitchDone = false  // Reset for next session
        maybeCloseOverview()
    }

    Timer {
        id: cardShowTimer
        interval: 30
        repeat: false
        onTriggered: root.cardVisible = GlobalStates.waffleAltSwitcherOpen && root.getPreset() === "skew"
    }

    Timer {
        id: focusTimer
        interval: 30
        running: GlobalStates.waffleAltSwitcherOpen
        repeat: true
        onTriggered: {
            if (GlobalStates.waffleAltSwitcherOpen)
                keyHandler.forceActiveFocus()
        }
    }

    function nextItem() {
        if (itemSnapshot.length === 0) return
        currentIndex = (currentIndex + 1) % itemSnapshot.length
        if (root.getAutoHide() && root.getPreset() !== "skew")
            autoHideTimer.restart()
    }

    function previousItem() {
        if (itemSnapshot.length === 0) return
        currentIndex = (currentIndex - 1 + itemSnapshot.length) % itemSnapshot.length
        if (root.getAutoHide() && root.getPreset() !== "skew")
            autoHideTimer.restart()
    }

    function activateCurrent() {
        const item = itemSnapshot[currentIndex]
        if (item?.id !== undefined) {
            NiriService.focusWindow(item.id)
        }
    }

    function confirmCurrent() {
        root.activateCurrent()
        root.closeSwitcher()
    }

    function activateAndClose(windowId) {
        NiriService.focusWindow(windowId)
        if (root.getCloseOnFocus()) {
            closeSwitcher()
        } else if (root.getAutoHide()) {
            autoHideTimer.restart()
        }
    }

    Timer {
        id: autoHideTimer
        interval: root.getAutoHideDelayMs()
        repeat: false
        onTriggered: root.closeSwitcher()
    }

    // Reset quick switch state after a short delay if user doesn't continue switching
    Timer {
        id: quickSwitchResetTimer
        interval: 800  // Reset after 800ms of inactivity
        repeat: false
        onTriggered: {
            if (!GlobalStates.waffleAltSwitcherOpen) {
                root.quickSwitchDone = false
                root.noUiSnapshot = []
                root.noUiIndex = 0
            }
        }
    }

    // Window list sync
    Connections {
        target: NiriService
        function onWindowsChanged() {
            if (!GlobalStates.waffleAltSwitcherOpen || !root.itemSnapshot.length) return

            const wins = NiriService.windows || []
            if (!wins.length) {
                root.closeSwitcher()
                return
            }

            const alive = {}
            for (const w of wins) alive[w.id] = true

            const filtered = root.itemSnapshot.filter(it => alive[it.id])
            if (!filtered.length) {
                root.closeSwitcher()
                return
            }
            root.itemSnapshot = filtered
            if (root.currentIndex >= filtered.length) {
                root.currentIndex = filtered.length - 1
            }
        }
    }


    // Scrim overlay on all screens
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: GlobalStates.waffleAltSwitcherOpen && !root.getShowOverview()
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.namespace: "quickshell:wAltSwitcherScrim"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, root.getScrimOpacity())
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeSwitcher()
            }
        }
    }

    // Main panel window
    PanelWindow {
        id: panelWindow
        visible: GlobalStates.waffleAltSwitcherOpen
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:wAltSwitcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        FocusScope {
            id: keyHandler
            anchors.fill: parent
            focus: GlobalStates.waffleAltSwitcherOpen

            Keys.onReleased: event => {
                if (root.getPreset() === "skew" && event.key === Qt.Key_Alt) {
                    root.confirmCurrent()
                    event.accepted = true
                }
            }

            // Keyboard handling
            Keys.onPressed: event => {
                switch (event.key) {
                    case Qt.Key_Escape:
                        root.closeSwitcher()
                        event.accepted = true
                        break
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        if (root.getPreset() === "skew")
                            root.confirmCurrent()
                        else {
                            root.activateCurrent()
                            if (root.getCloseOnFocus()) root.closeSwitcher()
                        }
                        event.accepted = true
                        break
                    case Qt.Key_Tab:
                        if (event.modifiers & Qt.ShiftModifier)
                            root.previousItem()
                        else
                            root.nextItem()
                        event.accepted = true
                        break
                    case Qt.Key_Right:
                    case Qt.Key_Down:
                    case Qt.Key_J:
                        root.nextItem()
                        event.accepted = true
                        break
                    case Qt.Key_Left:
                    case Qt.Key_Up:
                    case Qt.Key_K:
                        root.previousItem()
                        event.accepted = true
                        break
                }
            }
        }

        // Click outside to close
        MouseArea {
            anchors.fill: parent
            onClicked: root.closeSwitcher()
        }

        // Content centered in window
        WaffleAltSwitcherContent {
            id: content
            anchors.centerIn: parent
            availableWidth: parent.width
            availableHeight: parent.height
            cardVisible: root.cardVisible
            itemSnapshot: root.itemSnapshot
            selectedIndex: root.currentIndex
            onSelectedIndexChanged: root.currentIndex = selectedIndex
            onActivateWindow: windowId => root.activateAndClose(windowId)
            onClosed: root.closeSwitcher()
        }
    }

    // IPC handler reached via the global altSwitcher router in AltSwitcher.qml
    IpcHandler {
        target: "waffleAltSwitcher"

        function open(): void {
            if (!GlobalStates.waffleAltSwitcherOpen) {
                root.openSwitcher()
            }
        }

        function close(): void {
            root.closeSwitcher()
        }

        function toggle(): void {
            if (GlobalStates.waffleAltSwitcherOpen) {
                root.closeSwitcher()
            } else {
                root.openSwitcher()
            }
        }

        function next(): void {
            if (root.getNoVisualUi()) {
                autoHideTimer.stop()
                root.closeSwitcher()

                const len = root.noUiSnapshot?.length ?? 0
                if (!root.quickSwitchDone || len === 0) {
                    root.rebuildNoUiSnapshot()
                }

                const newLen = root.noUiSnapshot?.length ?? 0
                if (newLen === 0)
                    return

                if (!root.quickSwitchDone) {
                    root.quickSwitchDone = true
                    root.noUiIndex = newLen > 1 ? 1 : 0
                } else {
                    root.noUiIndex = (root.noUiIndex + 1) % newLen
                }

                root.focusNoUiIndex()
                quickSwitchResetTimer.restart()
                return
            }

            if (root.getPreset() === "skew") {
                if (!GlobalStates.waffleAltSwitcherOpen) {
                    root.openSwitcher()
                    return
                }
                root.nextItem()
                return
            }

            if (!GlobalStates.waffleAltSwitcherOpen) {
                root.rebuildSnapshot()
                if (root.itemSnapshot.length === 0) return
                
                // Quick switch: first Alt+Tab switches to previous window without UI
                // Second Alt+Tab opens the switcher UI
                if (root.getQuickSwitch() && root.itemSnapshot.length > 1 && !root.quickSwitchDone) {
                    root.quickSwitchDone = true
                    root.currentIndex = 1
                    NiriService.focusWindow(root.itemSnapshot[1].id)
                    // Start a timer to reset quickSwitchDone if user doesn't press again
                    quickSwitchResetTimer.restart()
                    return
                }
                root.openSwitcher()
            }
            root.nextItem()
            root.activateCurrent()
        }

        function previous(): void {
            if (root.getNoVisualUi()) {
                autoHideTimer.stop()
                root.closeSwitcher()

                const len = root.noUiSnapshot?.length ?? 0
                if (!root.quickSwitchDone || len === 0) {
                    root.rebuildNoUiSnapshot()
                }

                const newLen = root.noUiSnapshot?.length ?? 0
                if (newLen === 0)
                    return

                if (!root.quickSwitchDone) {
                    root.quickSwitchDone = true
                    root.noUiIndex = newLen > 1 ? (newLen - 1) : 0
                } else {
                    root.noUiIndex = (root.noUiIndex - 1 + newLen) % newLen
                }

                root.focusNoUiIndex()
                quickSwitchResetTimer.restart()
                return
            }

            if (root.getPreset() === "skew") {
                if (!GlobalStates.waffleAltSwitcherOpen) {
                    root.openSwitcher()
                    return
                }
                root.previousItem()
                return
            }

            if (!GlobalStates.waffleAltSwitcherOpen) {
                root.openSwitcher()
            }
            root.previousItem()
            root.activateCurrent()
        }
    }
}
