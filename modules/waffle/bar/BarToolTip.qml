import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.state

WPopupToolTip {
    id: root

    anchorEdges: (Config.options?.waffles?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom

    readonly property bool _anyPanelOpen: GlobalStates.searchOpen
        || WaffleState.actionCenterOpen
        || WaffleState.notificationCenterOpen
        || WaffleState.widgetsOpen
        || WaffleState.altSwitcherOpen
        || WaffleState.clipboardOpen
        || WaffleState.taskViewOpen

    property bool barExtraVisibleCondition: true
    extraVisibleCondition: root.barExtraVisibleCondition && !root._anyPanelOpen
}
