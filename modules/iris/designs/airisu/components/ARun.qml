import QtQuick

// A run: how far a level goes, as AIRISU paints it. A slot sunk into whatever it is cut in, and the level's lacquer
// laid along it from the start as far as the value, its leading edge at the die's 45°; the edge is the grip a hand
// takes. The pointer, or the keyboard on it, lifts the slot a step; held, the edge follows the hand with no travel,
// otherwise it moves by a snap.
ALacquer {
    id: root
    property real value: 0
    property bool hovered: false
    property bool held: false
    property bool keyed: false
    property bool available: true
    property color pigment: Airisu.seal
    // A caller's own slot (over a picture); the pointer then leaves it as it is.
    property color slot: "transparent"
    cut: Math.max(2, Math.round(root.height / 3))
    lacquer: root.slot.a > 0 ? root.slot : (root.hovered || root.keyed) && root.available && !root.held ? Airisu.slotLifted : Airisu.slot
    coat: root.available ? root.pigment : Airisu.inkThird
    share: root.value
    travel: root.held ? 0 : Airisu.snap
}
