pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.state

Item {
    id: root

    WaffleVerbs {}

    // Here and not in the deferred panels, so the commands answer from the first frame.
    IpcHandler {
        target: "wactionCenter"
        function toggle(): void { WaffleState.actionCenterOpen = !WaffleState.actionCenterOpen }
        function close(): void { WaffleState.actionCenterOpen = false }
        function open(): void { WaffleState.actionCenterOpen = true }
    }

    IpcHandler {
        target: "wnotificationCenter"
        function toggle(): void { WaffleState.notificationCenterOpen = !WaffleState.notificationCenterOpen }
        function close(): void { WaffleState.notificationCenterOpen = false }
        function open(): void { WaffleState.notificationCenterOpen = true }
    }

    IpcHandler {
        target: "wwidgets"
        function toggle(): void { WaffleState.widgetsOpen = !WaffleState.widgetsOpen }
        function close(): void { WaffleState.widgetsOpen = false }
        function open(): void { WaffleState.widgetsOpen = true }
    }

    component CriticalPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
    }

    CriticalPanelLoader {
        identifier: "wBar"
        component: WaffleBarModule.WaffleBar {}
    }

    CriticalPanelLoader {
        identifier: "wBackground"
        component: WaffleBackgroundModule.WaffleBackground {}
    }

    CriticalPanelLoader {
        identifier: "wBackdrop"
        extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true
        component: WaffleBackdropModule.WaffleBackdrop {}
    }
}
