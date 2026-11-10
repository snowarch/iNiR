pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.common
import qs.services

// The active family's WidgetLook, or the plain one.
Singleton {
    id: root
    FamilyPartLoader { id: provider; part: "widgetLook" }
    WidgetLook { id: plain }
    readonly property var look: provider.item ?? plain
    // Whether a widget holding `held` (its own `look`) may draw what its family lays over it (a face, a plate): that
    // look asks things only the family's answers, so it must be the family's, or the family has none. Asked of the
    // widget's own copy, never of this singleton: a notice from here reached the face's loader before the widget's
    // copy moved, and every face read the plain look and threw on a reload.
    function holds(held: var): bool {
        return Plugins.ready && (held !== plain || Plugins.part(Plugins.active, "widgetLook").length === 0)
    }
}
