pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.common
import qs.services

// The active family's WidgetLook, or the plain one; and the look of a family whose faces it lends (a face design's
// `family` in widgetDesign), for the widgets that wear them.
Singleton {
    id: root
    FamilyPartLoader { id: provider; part: "widgetLook" }
    WidgetLook { id: plain }
    readonly property var look: provider.item ?? plain
    readonly property string lender: DesktopWidgetDesign.faceDesigns.map(entry => String(entry.family ?? ""))
        .find(family => family.length > 0 && family !== Plugins.active) ?? ""
    FamilyPartLoader { id: lent; part: "widgetLook"; family: root.lender }
    function lookOf(family: string): var { return family.length > 0 && family !== Plugins.active ? lent.item ?? plain : root.look }
    // Whether a widget holding `held` (its own `look`) may draw what its family lays over it (a face, a plate): that
    // look asks things only the family's answers, so it must be the family's, or the family has none. Asked of the
    // widget's own copy, never of this singleton: a notice from here reached the face's loader before the widget's
    // copy moved, and every face read the plain look and threw on a reload.
    function holds(held: var, family: string): bool {
        if (family.length > 0 && family !== Plugins.active) return held !== plain && held === lent.item
        return Plugins.ready && (held !== plain || Plugins.part(Plugins.active, "widgetLook").length === 0)
    }
}
