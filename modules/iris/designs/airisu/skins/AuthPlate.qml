import QtQuick
import "../components"

// AIRISU's authentication dialog plate: a die of the next sheet, and along its head a band of yamabuki, the caution's
// one wide mark, because handing a program the right to act as the system is the one thing on the desktop that asks for
// care. The engine's dialog keeps its sign, words, field and keys over it.
Item {
    id: root
    property Item host
    ALacquer {
        id: plate
        anchors.fill: parent
        lacquer: Airisu.sheet
        coat: Airisu.tape
        head: true
        band: Airisu.u(1)
        share: 1
        moving: false
    }
}
