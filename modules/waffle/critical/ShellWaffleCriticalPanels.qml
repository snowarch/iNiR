pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.backdrop as WaffleBackdropModule

Item {
    id: root

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
