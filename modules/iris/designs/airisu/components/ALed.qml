import QtQuick
import qs.modules.iris.style

// A live level as an LED panel (the expressway's traffic boards, SYSTEM.md §6), only for a level that is changing now
// (the Island's volume and brightness as they move). Cells of light in a row, lit ones in the ink, dark ones the next
// sheet; past `safe` (a boost) the lit cells are the caution plate. The cell count follows the width at the module.
Item {
    id: root
    property real value: 0
    property real safe: 1
    property bool dim: false
    readonly property int pitch: 3 * Airisu.m
    readonly property int gap: Airisu.hair + Math.round(Airisu.d)
    readonly property int cells: Math.max(8, Math.floor((root.width + root.gap) / root.pitch))
    readonly property real cellWidth: (root.width - root.gap * (root.cells - 1)) / root.cells
    readonly property int lit: Math.round(Math.max(0, Math.min(1, root.value)) * root.cells)
    readonly property int safeCells: Math.round(Math.min(1, root.safe) * root.cells)
    implicitHeight: 2 * Airisu.m

    Repeater {
        model: root.cells
        Rectangle {
            required property int index
            x: Math.round(index * (root.cellWidth + root.gap))
            width: Math.round((index + 1) * (root.cellWidth + root.gap) - root.gap) - x
            height: root.height
            readonly property bool on: index < root.lit
            color: !on ? Airisu.groundRaised : root.dim ? Airisu.inkThird : index >= root.safeCells ? Airisu.caution : Airisu.ink
        }
    }
}
