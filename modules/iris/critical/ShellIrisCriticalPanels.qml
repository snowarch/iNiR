pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.iris.background
import qs.modules.iris.bar
import qs.modules.iris.frame

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
        identifier: "irisBackground"
        extraCondition: !(Config.options?.iris?.modules?.desktopWidgets ?? true)
        component: IrisBackground {}
    }

    LazyLoader {
        active: Config.ready
        component: IrisReservations {}
    }

    CriticalPanelLoader {
        identifier: "irisBar"
        component: IrisBar {}
    }
}
