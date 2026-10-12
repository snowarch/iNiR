import QtQuick

// A pressable print (SYSTEM.md law 6, board Piezas): two plates in register, the die's colour over its under-plate.
// Pressed, the top plate and everything on it run out of register by `Airisu.registration` toward the lower right and
// the under-plate shows at the upper left, as a stamp that came down and slid; it never scales. Children ride the top plate.
Item {
    id: root
    property string die: "chamfer"
    property color fill: "transparent"
    property color under: Airisu.inkUnder
    property color stroke: "transparent"
    property real strokeWidth: 0
    property bool dashed: false
    property bool pressed: false
    property real cut: Airisu.cutFor(root.height)
    default property alias content: plate.data
    readonly property real run: root.pressed ? Airisu.registration : 0

    ADie {
        anchors.fill: parent
        visible: root.pressed
        kind: root.die
        cut: root.cut
        fill: root.fill.a > 0 ? root.under : "transparent"
        stroke: root.under
        strokeWidth: root.strokeWidth
    }
    Item {
        id: plate
        width: root.width
        height: root.height
        x: root.run
        y: root.run
        ADie {
            anchors.fill: parent
            kind: root.die
            cut: root.cut
            fill: root.fill
            stroke: root.stroke
            strokeWidth: root.strokeWidth
            dashed: root.dashed
        }
    }
}
