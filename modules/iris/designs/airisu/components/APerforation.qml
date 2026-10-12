import QtQuick

// A perforation (ミシン目, SYSTEM.md law 2): where a body was torn from its origin, a line of holes at the module's
// pitch. `vertical` turns it; `torn` (0–1) is how much of it is already gone from the far end, a countdown torn off.
Item {
    id: root
    property bool vertical: false
    property color colour: Airisu.inkThird
    property real torn: 0
    readonly property int pitch: Airisu.perforation
    readonly property int hole: Math.max(1, Math.round(Airisu.perforation / 2))
    implicitWidth: root.vertical ? root.hole : 0
    implicitHeight: root.vertical ? 0 : root.hole

    Image {
        // Whole holes only: the line stops on a hole, never on half of one.
        readonly property real span: (root.vertical ? root.height : root.width) * (1 - Math.max(0, Math.min(1, root.torn)))
        readonly property real kept: Math.floor(span / root.pitch) * root.pitch
        width: root.vertical ? root.hole : kept
        height: root.vertical ? kept : root.hole
        anchors.centerIn: root.torn > 0 ? undefined : parent
        source: root.vertical
            ? Airisu.svgCell(root.hole, root.pitch, `<rect x='0' y='${Math.round((root.pitch - root.hole) / 2)}' width='${root.hole}' height='${root.hole}'/>`, root.colour)
            : Airisu.svgCell(root.pitch, root.hole, `<rect x='${Math.round((root.pitch - root.hole) / 2)}' y='0' width='${root.hole}' height='${root.hole}'/>`, root.colour)
        fillMode: Image.Tile
        smooth: false
        cache: true
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
    }
}
