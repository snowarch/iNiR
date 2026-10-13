import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's switch: a lever in a slot, both cut by the die. Off, the slot is sunk into what it is cut in and the lever is
// the body's next coat resting at the start; on, the slot is lacquered in the seal (what is live) and the lever stands at
// the far end in the seal's ink, so on and off read at a glance with no word. The lever stops in its place (a detent),
// it does not spring. The pointer steps the lever's coat, a press carries it a hair, keyboard focus flags the corner,
// and a switch that cannot be taken sinks into the stock. On a chosen row's plate it takes that plate's inks. The host
// keeps the toggle, the keys and the name.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property bool hovered: root.host?.hovered ?? false
    readonly property bool pressed: root.host?.pressed ?? false
    readonly property bool available: root.host?.enabled ?? true
    readonly property bool keyed: root.host?.keyed ?? false
    readonly property bool reversed: root.host?.reversed ?? false
    readonly property int inset: Math.max(2, Math.round(3 * Airisu.d))
    readonly property int run: root.pressed && root.available ? Airisu.hair : 0
    readonly property color slot: !root.available ? Airisu.dim
        : !root.on ? Airisu.slot : root.reversed ? IrisStyle.selectionLabel : Airisu.seal
    readonly property color restingLever: root.reversed ? IrisStyle.selectionDetail : Airisu.groundRaised
    readonly property color lever: !root.available ? Airisu.inkThird
        : root.reversed && root.on ? IrisStyle.selectionFill
        : root.on ? Airisu.inkOnSeal
        : root.hovered || root.pressed ? Airisu.step(root.restingLever, root.pressed ? Airisu.pressStep : Airisu.hoverStep)
        : root.restingLever

    ALacquer {
        anchors.fill: parent
        cut: Math.max(2, Math.round(root.height / 3))
        lacquer: root.slot
    }
    ALacquer {
        width: Math.round(root.width / 2) - root.inset
        height: root.height - 2 * root.inset
        x: (root.on ? root.width - root.inset - width : root.inset) + root.run
        y: root.inset + root.run
        Behavior on x { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
        cut: Math.max(2, Math.round(height / 3))
        lacquer: root.lever
    }
    AKey {
        anchors.fill: parent
        lacquer: "transparent"
        available: false
        keyed: root.keyed
    }
}
