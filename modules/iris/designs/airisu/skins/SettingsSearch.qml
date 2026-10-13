import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's search in Settings: the box of a form to write in, a sheet of the page's paper cut by the die and ruled in the
// third ink (a slot sunk into glass read as a grey smear on a bright wallpaper); the pointer and the keyboard ink the
// rule, focused the keyboard's flag inks its uncut corner, and what you select is printed on the seal. The engine keeps
// the input, its keys and its focus; this answers the box and the inks the engine reads.
Item {
    id: root
    property Item host
    readonly property bool focused: root.host?.focused ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property color glyphColour: root.focused ? Airisu.ink : Airisu.inkSecond
    readonly property color placeholderColour: Airisu.inkThird
    readonly property color selectionColour: Airisu.seal
    readonly property color selectedTextColour: Airisu.inkOnSeal

    ADie {
        anchors.fill: parent
        kind: "chamfer"
        cut: Airisu.cutFor(root.height)
        fill: Airisu.sheet
        stroke: root.focused || root.hovered ? Airisu.ink : Airisu.inkThird
        strokeWidth: Airisu.hair
    }
    AKey {
        anchors.fill: parent
        lacquer: "transparent"
        available: false
        keyed: root.focused
    }
}
