import QtQuick
import Quickshell
import qs
import qs.modules.common
import qs.modules.waffle.looks

WPopupToolTip {
    id: root

    anchorEdges: (Config.options?.waffles?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom

    readonly property bool _anyPanelOpen: GlobalStates.searchOpen
        || GlobalStates.waffleActionCenterOpen
        || GlobalStates.waffleNotificationCenterOpen
        || GlobalStates.waffleWidgetsOpen
        || GlobalStates.waffleAltSwitcherOpen
        || GlobalStates.waffleClipboardOpen
        || GlobalStates.waffleTaskViewOpen

    property bool barExtraVisibleCondition: true
    extraVisibleCondition: root.barExtraVisibleCondition && !root._anyPanelOpen
}
