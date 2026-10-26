pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.backdrop as WaffleBackdropModule

Item {
    id: root

    WaffleVerbs {}

    // Here and not in the deferred panels, so the commands answer from the first frame.
    IpcHandler {
        target: "wactionCenter"
        function toggle(): void { GlobalStates.waffleActionCenterOpen = !GlobalStates.waffleActionCenterOpen }
        function close(): void { GlobalStates.waffleActionCenterOpen = false }
        function open(): void { GlobalStates.waffleActionCenterOpen = true }
    }

    IpcHandler {
        target: "wnotificationCenter"
        function toggle(): void { GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen }
        function close(): void { GlobalStates.waffleNotificationCenterOpen = false }
        function open(): void { GlobalStates.waffleNotificationCenterOpen = true }
    }

    IpcHandler {
        target: "wwidgets"
        function toggle(): void { GlobalStates.waffleWidgetsOpen = !GlobalStates.waffleWidgetsOpen }
        function close(): void { GlobalStates.waffleWidgetsOpen = false }
        function open(): void { GlobalStates.waffleWidgetsOpen = true }
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
