import QtQuick

// The body stripe (board Pegatinas › 01): three bars sheared to −24°, 14, 6 and 3 units thick, the first in the seal.
// `single` keeps only the seal bar (a card header). It is a sticker: one per panel.
Item {
    id: root
    property bool single: false
    readonly property real slant: Math.tan(24 * Math.PI / 180)
    readonly property real unit: root.single ? root.height : root.height / 26
    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -root.slant, 0, root.slant * root.height, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
    Rectangle { width: parent.width; height: root.single ? parent.height : Math.round(14 * root.unit); color: Airisu.seal }
    Rectangle {
        visible: !root.single
        x: Math.round(parent.width * 0.1); y: Math.round(18 * root.unit)
        width: parent.width - x; height: Math.max(1, Math.round(6 * root.unit)); color: Airisu.gofun
    }
    Rectangle {
        visible: !root.single
        x: Math.round(parent.width * 0.2); y: Math.round(23 * root.unit)
        width: parent.width - x; height: Math.max(1, Math.round(3 * root.unit)); color: Airisu.gofun
    }
}
