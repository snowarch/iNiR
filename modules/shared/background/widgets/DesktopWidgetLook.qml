pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.common
import qs.services

// The active family's WidgetLook, or the plain one.
Singleton {
    FamilyPartLoader { id: provider; part: "widgetLook" }
    WidgetLook { id: plain }
    readonly property var look: provider.item ?? plain
    // The family's own look is in, or the family has none. What a family draws over a widget (its faces, its plate)
    // asks that look things only it answers: drawn before it, every face read the plain one and threw at start.
    // Read from Plugins itself, never through the loader's bindings, so a face can't see it a step early.
    readonly property bool ready: Plugins.ready && (provider.item !== null || Plugins.part(Plugins.active, "widgetLook").length === 0)
}
