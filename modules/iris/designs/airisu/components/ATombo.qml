import QtQuick

// Crop marks (トンボ, SYSTEM.md law 6): what the pointer is over gets the marks a printer trims to. Each corner has two
// short rules on the extensions of the edges that meet there, standing off the object by `air`: they line up with the
// cut, never touch the piece and never box it in. The keyboard's focus is the same marks in the seal, one step heavier:
// the keyboard is seen more than the pointer. Fill the target (`anchors.fill`): the marks stand outside it.
Item {
    id: root
    property bool shown: false
    property bool focusMarks: false
    property color colour: root.focusMarks ? Airisu.seal : Airisu.ink
    property int length: Airisu.tomboLength
    property int air: Airisu.tomboAir
    readonly property int w: root.focusMarks ? Airisu.strong : Airisu.hair
    opacity: root.shown || root.focusMarks ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent } }

    Repeater {
        model: [[-1, -1], [1, -1], [-1, 1], [1, 1]]
        Item {
            id: corner
            required property var modelData
            readonly property int sx: corner.modelData[0]
            readonly property int sy: corner.modelData[1]
            // The rule on the horizontal edge's extension, beyond the side.
            Rectangle {
                color: root.colour
                width: root.length
                height: root.w
                x: corner.sx < 0 ? -root.air - root.length : root.width + root.air
                y: corner.sy < 0 ? 0 : root.height - root.w
            }
            // The rule on the vertical edge's extension, beyond the top or the foot.
            Rectangle {
                color: root.colour
                width: root.w
                height: root.length
                x: corner.sx < 0 ? 0 : root.width - root.w
                y: corner.sy < 0 ? -root.air - root.length : root.height + root.air
            }
        }
    }
}
