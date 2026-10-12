import QtQuick

// A perforation (ミシン目, SYSTEM.md law 2): where a body was torn from its origin, a line of holes at the module's
// pitch. `vertical` turns it; `torn` (0–1) is how much of it is already gone, a countdown torn off: from the far end,
// or from the near end with `fromStart`. The holes keep their places as it tears; only whole ones are drawn.
Item {
    id: root
    property bool vertical: false
    property color colour: Airisu.inkThird
    property real torn: 0
    property bool fromStart: false
    readonly property int pitch: Airisu.perforation
    readonly property int hole: Math.max(1, Math.round(Airisu.perforation / 2))
    readonly property real length: root.vertical ? root.height : root.width
    readonly property int holes: Math.floor(root.length / root.pitch)
    implicitWidth: root.vertical ? root.hole : 0
    implicitHeight: root.vertical ? 0 : root.hole

    Image {
        readonly property real whole: root.holes * root.pitch
        readonly property real kept: Math.floor(root.holes * (1 - Math.max(0, Math.min(1, root.torn))) + 0.0001) * root.pitch
        // The line is centred whole; torn, the holes left stay where they were.
        readonly property real lead: Math.round((root.length - whole) / 2) + (root.fromStart ? whole - kept : 0)
        x: root.vertical ? Math.round((root.width - width) / 2) : lead
        y: root.vertical ? lead : Math.round((root.height - height) / 2)
        width: root.vertical ? root.hole : kept
        height: root.vertical ? kept : root.hole
        visible: kept > 0
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
