import QtQuick
import "../components"

// AIRISU's keycap on the on-screen keyboard: a key (AKey) cut by the die, a step of ink over the keyboard's body, its
// legend the engine's. A modifier that holds (shift, caps) is lacquered in the seal while it holds, the one live key.
// The pointer lifts it a rung, a press drops it in register. The engine keeps the typing.
Item {
    id: root
    property Item host
    readonly property bool empty: (root.host?.shape ?? "") === "empty"
    readonly property bool held: root.host?.toggled ?? false

    AKey {
        visible: !root.empty
        anchors.fill: parent
        anchors.margins: Math.max(1, Math.round(Airisu.d))
        cut: Airisu.cutFor(height)
        lacquer: root.held ? Airisu.chosen : Airisu.cell
        hovered: root.host?.hovered ?? false
        pressed: root.host?.down ?? false
    }
}
