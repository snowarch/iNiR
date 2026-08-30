pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.barM3 as BarM3
import qs.modules.dock
import qs.modules.pill
import qs.modules.verticalBar
import qs.modules.common

Item {
    id: root

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool barPill: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"
    readonly property bool barM3: (Config.options?.bar?.appearanceStyle ?? "classic") === "m3"
    readonly property bool barStock: !root.barPill && !root.barM3

    component CriticalPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
    }

    CriticalPanelLoader { identifier: "iiBackground"; component: Background {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical && root.barStock; component: Bar {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical && root.barPill; component: PillBar {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical && root.barM3; component: BarM3.M3Bar {} }
    CriticalPanelLoader { identifier: "iiVerticalBar"; extraCondition: root.barVertical; component: VerticalBar {} }
    CriticalPanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
}
