import QtQuick
import qs.modules.common.functions

// Caution tape (虎ロープ, SYSTEM.md §8: only what is critical, and polkit): the caution plate striped at 45° with the
// darkest ink on this stock, so it reads as tiger tape by day and by night. One tiled cell.
Item {
    id: root
    readonly property int cell: 2 * Airisu.m
    readonly property int half: Math.round(root.cell / 2)
    readonly property color stripe: ColorUtils.relativeLuminance(Airisu.ink) < ColorUtils.relativeLuminance(Airisu.inkOnCaution)
        ? Airisu.ink : Airisu.inkOnCaution
    implicitHeight: Math.round(1.5 * Airisu.m)
    clip: true

    Rectangle {
        anchors.fill: parent
        color: Airisu.caution
    }
    Image {
        anchors.fill: parent
        fillMode: Image.Tile
        smooth: false
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        source: Airisu.svgCell(root.cell, root.cell,
            `<polygon points='0,${root.half} ${root.half},0 ${root.cell},0 0,${root.cell}'/><polygon points='${root.cell},${root.half} ${root.cell},${root.cell} ${root.half},${root.cell}'/>`,
            root.stripe)
    }
}
