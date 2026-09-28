import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
    id: root

    // Upstream hardcoded 23/28 against its own fixed 40px bar. iNiR's bar
    // height is user-configurable (bar.height), so at anything but 40 the
    // icons floated as small chips in a taller bar. Scale off the real bar
    // size and let bar.m3.dockToPanel.* override with an explicit px value.
    readonly property real slotSize: root.vertical
        ? Appearance.sizes.baseVerticalBarWidth
        : Appearance.sizes.baseBarHeight
    readonly property real cfgIconSize: Config.options?.bar?.m3?.dockToPanel?.iconSize ?? 0
    readonly property real cfgBtnSize: Config.options?.bar?.m3?.dockToPanel?.buttonSize ?? 0
    readonly property real naturalIconSize: Math.round(root.slotSize * 0.68)
    readonly property real naturalButtonSize: Math.round(root.slotSize * 0.86)
    readonly property real requestedIconSize: root.cfgIconSize > 0
        ? Math.max(12, root.cfgIconSize)
        : root.naturalIconSize
    readonly property real requestedButtonSize: root.cfgBtnSize > 0
        ? Math.max(18, root.cfgBtnSize)
        : root.naturalButtonSize
    property real btnSize: Math.max(root.requestedButtonSize, root.requestedIconSize + 6)
    property real iconSize: Math.min(root.requestedIconSize, root.btnSize - 6)
    property real btnSpacing: Math.max(0, Config.options?.bar?.m3?.dockToPanel?.buttonSpacing ?? 2)
    property real buttonPadding: Math.max(3, Math.round(root.btnSize * 0.1))
    property bool vertical:    Config.options.bar.vertical
    property bool isMaterial:  Config.options.bar.m3.cornerStyle === 3
    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property var activeUnpinned: TaskbarApps.apps.filter(
        a => !a.pinned && a.appId !== "SEPARATOR" && a.toplevels.length > 0
    )
    property bool showSeparator: _workOrder.length > 0 && activeUnpinned.length > 0
    property var  _workOrder:            pinnedApps.slice()
    property int  activeDragVisualIndex: -1
    property bool _dragging:             false
    readonly property var focusedWindow: CompositorService.isNiri
        ? (NiriService.windows?.find(window => window.is_focused)
            ?? NiriService.activeWindow
            ?? null)
        : null
    readonly property int focusedWindowId:
        Number(root.focusedWindow?.id ?? -1)

    function toplevelIsActive(toplevel): bool {
        if (!toplevel)
            return false
        if (CompositorService.isNiri) {
            if (root.focusedWindowId < 0)
                return false
            if (Number(toplevel.niriWindowId ?? -1) === root.focusedWindowId)
                return true
            const focusedAppId = String(root.focusedWindow?.app_id ?? "").toLowerCase()
            const toplevelAppId = String(toplevel.appId ?? "").toLowerCase()
            if (focusedAppId.length === 0 || toplevelAppId !== focusedAppId)
                return false
            return String(toplevel.title ?? "")
                === String(root.focusedWindow?.title ?? "")
        }
        return toplevel.activated ?? false
    }

    function indicatorIsActive(toplevels, index: int): bool {
        if (!toplevels || index < 0 || index >= toplevels.length)
            return false
        if (index === 2 && toplevels.length > 3)
            return toplevels.slice(2).some(toplevel => root.toplevelIsActive(toplevel))
        return root.toplevelIsActive(toplevels[index])
    }

    Component.onCompleted:
        CompositorService.setSortingConsumer("m3DockToPanel", true)
    Component.onDestruction:
        CompositorService.setSortingConsumer("m3DockToPanel", false)

    onPinnedAppsChanged: {
        if (!_dragging)
            _workOrder = pinnedApps.slice()
    }

    implicitWidth:  vertical
        ? (isMaterial ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth - 10)
        : pill.implicitWidth
    implicitHeight: vertical
        ? pill.implicitHeight
        : Appearance.sizes.barHeight

    function swapSlots(from, to) {
        if (from === to) return
        if (from < 0 || from >= _workOrder.length) return
        if (to   < 0 || to   >= _workOrder.length) return
        let arr = _workOrder.slice()
        let tmp = arr[from]; arr[from] = arr[to]; arr[to] = tmp
        _workOrder = arr
    }

    function commitOrder() {
        // Upstream assigned the list directly, which under iNiR's Config is
        // session-only: the new order was lost on the next restart.
        Config.setNestedValue("dock.pinnedApps", _workOrder.slice())
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full

        implicitWidth: root.isMaterial && !root.vertical
            ? flow.implicitWidth + Math.round(root.btnSize * 0.36)
            : root.vertical
                ? (root.isMaterial ? root.btnSize + 6 : Appearance.sizes.verticalBarWidth - 10)
                : flow.implicitWidth + 4

        implicitHeight: root.isMaterial && root.vertical
            ? flow.implicitHeight + Math.round(root.btnSize * 0.36)
            : root.isMaterial
                ? root.btnSize + 6
                : root.vertical
                    ? flow.implicitHeight + 4
                    : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow:    root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: root.btnSpacing

            // ── 1. PINNED APPS ───────────────────────────────────────────
            Repeater {
                id: pinnedRepeater
                model: root._workOrder.length

                delegate: Item {
                    id: slotItem
                    required property int index

                    property string appId:        root._workOrder[index] ?? ""
                    property var    appEntry:     TaskbarApps.apps.find(
                        app => String(app.appId ?? "").toLowerCase() === appId.toLowerCase()) ?? null
                    property var    deskEntry:    AppSearch.lookupDesktopEntry(appId)
                    property int    _lastFocused: -1

                    Connections {
                        target: DesktopEntries
                        function onApplicationsChanged() {
                            slotItem.deskEntry = AppSearch.lookupDesktopEntry(slotItem.appId)
                        }
                    }

                    width:  root.btnSize
                    height: root.btnSize

                    opacity: 1
                    Behavior on opacity { NumberAnimation { duration: 110 } }

                    RippleButton {
                        id: pinnedButton
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            const entry = slotItem.appEntry
                            if (!entry || entry.toplevels.length === 0) {
                                AppSearch.launchEntry(slotItem.deskEntry)
                                return
                            }
                            const next = (slotItem._lastFocused + 1) % entry.toplevels.length
                            slotItem._lastFocused = next
                            entry.toplevels[next].activate()
                        }
                        middleClickAction: () => { AppSearch.launchEntry(slotItem.deskEntry) }
                        // Upstream unpinned the app on right click, so a stray
                        // right click silently destroyed the layout. Right click
                        // opens the menu, exactly like iNiR's own dock.
                        altAction: () => { pinnedMenu.requestOpen() }

                        ContextMenu {
                            id: pinnedMenu
                            anchorItem: pinnedButton
                            anchorHovered: pinnedButton.hovered
                            popupAbove: Config.options?.bar?.bottom ?? false
                            popupSide: root.vertical
                                ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                                : 0
                            closeOnHoverLost: false
                            model: [
                                {
                                    iconName: "open_in_new",
                                    text: Translation.tr("New window"),
                                    monochromeIcon: true,
                                    action: () => AppSearch.launchEntry(slotItem.deskEntry)
                                },
                                ...((slotItem.deskEntry?.actions?.length ?? 0) > 0
                                    ? slotItem.deskEntry.actions.map(action => ({
                                        iconName: action.icon ?? "",
                                        text: action.name,
                                        action: () => AppSearch.launchDesktopAction(slotItem.deskEntry, action)
                                    })).concat({ type: "separator" })
                                    : []),
                                {
                                    iconName: "keep_off",
                                    text: Translation.tr("Unpin from dock"),
                                    monochromeIcon: true,
                                    action: () => TaskbarApps.togglePin(slotItem.appId)
                                },
                                ...((slotItem.appEntry?.toplevels?.length ?? 0) > 0 ? [
                                    { type: "separator" },
                                    {
                                        iconName: "close",
                                        text: slotItem.appEntry.toplevels.length > 1
                                            ? Translation.tr("Close all windows")
                                            : Translation.tr("Close window"),
                                        monochromeIcon: true,
                                        action: () => slotItem.appEntry.toplevels.forEach(toplevel => toplevel.close())
                                    }
                                ] : [])
                            ]
                        }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: pinnedIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(slotItem.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: pinnedIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat; visible: false
                                        anchors.fill: parent
                                        source: pinnedIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat; source: desat
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? pinnedIcon.right    : undefined
                                    top:    root.vertical ? undefined            : pinnedIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(slotItem.appEntry?.toplevels?.length ?? 0, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        radius: Appearance.rounding.full
                                        implicitWidth:  root.vertical
                                            ? 2
                                            : (slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2
                                        implicitHeight: root.vertical
                                            ? ((slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2)
                                            : 2
                                        color: root.indicatorIsActive(
                                            slotItem.appEntry?.toplevels, index)
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            if (active) {
                                root._dragging = true
                                root.activeDragVisualIndex = index
                                return
                            }
                            root.activeDragVisualIndex = -1
                            root._dragging = false
                            root.commitOrder()
                        }

                        onCentroidChanged: {
                            if (!active) return
                            const currentIdx = root.activeDragVisualIndex
                            if (currentIdx < 0) return

                            const dragPos = root.vertical
                                ? dragHandler.centroid.scenePosition.y
                                : dragHandler.centroid.scenePosition.x

                            let minDist = Infinity, nearest = currentIdx

                            for (let i = 0; i < pinnedRepeater.count; i++) {
                                if (i === currentIdx) continue
                                const child = pinnedRepeater.itemAt(i)
                                if (!child) continue
                                const cc = child.mapToItem(null, child.width / 2, child.height / 2)
                                const ccPos = root.vertical ? cc.y : cc.x
                                const dist  = Math.abs(dragPos - ccPos)
                                if (dist < minDist) { minDist = dist; nearest = i }
                            }

                            if (nearest !== currentIdx) {
                                const nb = pinnedRepeater.itemAt(nearest)
                                if (!nb) return
                                const nc = nb.mapToItem(null, nb.width / 2, nb.height / 2)
                                const ncPos = root.vertical ? nc.y : nc.x
                                const shouldSwap = (nearest > currentIdx)
                                    ? (dragPos >= ncPos)
                                    : (dragPos <= ncPos)
                                if (shouldSwap) {
                                    root.swapSlots(currentIdx, nearest)
                                    root.activeDragVisualIndex = nearest
                                }
                            }
                        }
                    }
                }
            }

            // ── 2. SEPARATOR ─────────────────────────────────────────────
            Item {
                width:   root.vertical ? root.btnSize          : (root.showSeparator ? (1 + root.btnSpacing * 3) : 0)
                height:  root.vertical ? (root.showSeparator ? (1 + root.btnSpacing * 3) : 0) : root.btnSize
                visible: root.showSeparator

                Rectangle {
                    anchors.centerIn: parent
                    width:  root.vertical ? Math.round(root.btnSize * 0.6) : 1
                    height: root.vertical ? 1 : Math.round(root.btnSize * 0.6)
                    color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }

            // ── 3. ACTIVE UNPINNED APPS ───────────────────────────────────
            Repeater {
                id: activeRepeater
                model: ScriptModel { values: root.activeUnpinned }

                delegate: Item {
                    id: activeSlot
                    required property var modelData

                    property int  _lastFocused: -1
                    property var deskEntry: AppSearch.lookupDesktopEntry(activeSlot.modelData.appId)

                    Connections {
                        target: DesktopEntries
                        function onApplicationsChanged() {
                            activeSlot.deskEntry = AppSearch.lookupDesktopEntry(activeSlot.modelData.appId)
                        }
                    }

                    width:  root.btnSize
                    height: root.btnSize

                    RippleButton {
                        id: activeButton
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            if (activeSlot.modelData.toplevels.length === 0) return
                            const next = (activeSlot._lastFocused + 1) % activeSlot.modelData.toplevels.length
                            activeSlot._lastFocused = next
                            activeSlot.modelData.toplevels[next].activate()
                        }
                        middleClickAction: () => {
                            AppSearch.launchEntry(activeSlot.deskEntry)
                        }
                        altAction: () => { activeMenu.requestOpen() }

                        ContextMenu {
                            id: activeMenu
                            anchorItem: activeButton
                            anchorHovered: activeButton.hovered
                            popupAbove: Config.options?.bar?.bottom ?? false
                            popupSide: root.vertical
                                ? ((Config.options?.bar?.bottom ?? false) ? Edges.Left : Edges.Right)
                                : 0
                            closeOnHoverLost: false
                            model: [
                                {
                                    iconName: "open_in_new",
                                    text: Translation.tr("New window"),
                                    monochromeIcon: true,
                                    action: () => AppSearch.launchEntry(activeSlot.deskEntry)
                                },
                                ...((activeSlot.deskEntry?.actions?.length ?? 0) > 0
                                    ? activeSlot.deskEntry.actions.map(action => ({
                                        iconName: action.icon ?? "",
                                        text: action.name,
                                        action: () => AppSearch.launchDesktopAction(activeSlot.deskEntry, action)
                                    })).concat({ type: "separator" })
                                    : []),
                                {
                                    iconName: "keep",
                                    text: Translation.tr("Pin to dock"),
                                    monochromeIcon: true,
                                    action: () => TaskbarApps.togglePin(activeSlot.modelData.appId)
                                },
                                { type: "separator" },
                                {
                                    iconName: "close",
                                    text: activeSlot.modelData.toplevels.length > 1
                                        ? Translation.tr("Close all windows")
                                        : Translation.tr("Close window"),
                                    monochromeIcon: true,
                                    action: () => activeSlot.modelData.toplevels.forEach(toplevel => toplevel.close())
                                }
                            ]
                        }

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: activeIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(
                                    AppSearch.guessIcon(activeSlot.modelData.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: activeIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat2; visible: false
                                        anchors.fill: parent
                                        source: activeIcon; desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat2; source: desat2
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left:   root.vertical ? activeIcon.right    : undefined
                                    top:    root.vertical ? undefined            : activeIcon.bottom
                                    leftMargin:  root.vertical ? 1 : 0
                                    topMargin:   root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter:   root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(activeSlot.modelData.toplevels.length, 3)
                                    delegate: Rectangle {
                                        required property int index
                                        radius: Appearance.rounding.full
                                        implicitWidth:  root.vertical
                                            ? 2
                                            : activeSlot.modelData.toplevels.length <= 3 ? 4 : 2
                                        implicitHeight: root.vertical
                                            ? (activeSlot.modelData.toplevels.length <= 3 ? 4 : 2)
                                            : 2
                                        color: root.indicatorIsActive(
                                            activeSlot.modelData.toplevels, index)
                                            ? Appearance.colors.colPrimary
                                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
