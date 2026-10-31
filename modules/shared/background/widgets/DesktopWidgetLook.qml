pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.common

// The active family's WidgetLook, or the plain one.
Singleton {
    FamilyPartLoader { id: provider; part: "widgetLook" }
    WidgetLook { id: plain }
    readonly property var look: provider.item ?? plain
}
