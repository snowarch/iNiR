import QtQuick
import QtQuick.Shapes
import qs.modules.iris.style

// A key, AIRISU's control: a die printed in two plates, one over the other in register. It answers by the ladder and the
// register, never by tinting, growing or glowing: the pointer lifts the top plate one rung of the lacquer's ladder
// (sumi toward tetsu, laid at the die's 45° in one snap), keyboard focus brings crop marks in shu to its corners
// (AMarks), and a press drops the top plate down and right (`shift`, which the host's content follows) so the plate
// under it shows along its head and its start, a deeper print of the same lacquer. A key with no lacquer (a
// quiet one) has only its under plate, which a press lays on the body it sits on. A key that cannot be taken keeps no
// marks and no register.
Item {
    id: root
    property color lacquer: Airisu.groundRaised
    property bool hovered: false
    property bool pressed: false
    property bool keyed: false
    property bool available: true
    property int cut: Airisu.cutFor(root.height)
    property bool cutTopRight: true
    property bool cutBottomLeft: true
    // What lies under a quiet key, so its under plate is a print of that.
    property color under: Airisu.ground
    readonly property color stock: root.lacquer.a > 0 ? root.lacquer : root.under
    readonly property color ink: Airisu.inkOn(root.stock)
    // The under plate (版の下刷り): the lacquer printed deeper, seen only where the top plate has moved off it.
    property color coat: Airisu.underPlate(root.stock)
    // The rung the pointer lifts the key to.
    property color lift: Airisu.step(root.stock, Airisu.hoverStep)
    // The marks' colour while the keyboard holds the key (they stand on the body, so always shu).
    property color flag: Airisu.seal
    readonly property bool down: root.pressed && root.available
    readonly property int shift: root.down ? Airisu.offset : 0

    ALacquer {
        anchors.fill: parent
        visible: root.down
        cut: root.cut
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        lacquer: root.coat
    }
    ALacquer {
        x: root.shift
        y: root.shift
        width: root.width
        height: root.height
        cut: root.cut
        cutTopRight: root.cutTopRight
        cutBottomLeft: root.cutBottomLeft
        // Pressed, the top plate is printed solid, so the under plate shows only where it has moved off it.
        lacquer: root.down && root.lacquer.a > 0 ? Airisu.solid(root.lacquer) : root.lacquer
        coat: root.lift
        share: root.available && root.hovered && !root.down ? 1 : 0
        travel: Airisu.snap
    }
    AMarks {
        anchors.fill: parent
        shown: root.keyed
        color: root.flag
    }
}
