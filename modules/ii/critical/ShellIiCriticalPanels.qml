pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.shared.background
import qs.modules.ii.bar
import qs.modules.ii.barM3 as BarM3
import qs.modules.ii.dock
import qs.modules.ii.pill
import qs.modules.ii.verticalBar
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
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical && root.barPill && !GlobalStates.widgetEditMode; component: PillBar {} }
    CriticalPanelLoader { identifier: "iiBar"; extraCondition: !root.barVertical && root.barM3 && !GlobalStates.widgetEditMode; component: BarM3.M3Bar {} }
    CriticalPanelLoader { identifier: "iiVerticalBar"; extraCondition: root.barVertical; component: VerticalBar {} }
    CriticalPanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
}
