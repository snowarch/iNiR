import QtQuick

// The seal box (印): AIRISU's sign that something is on. An empty box ruled in the third ink waits; when the thing is on,
// the box is ruled in the seal and stamped, its square of shu pressed in from the middle in one snap, the way a hanko
// lands. It is the logo's red square, so a lit control carries the mark of the shell itself.
Item {
    id: root
    property bool stamped: false
    property color seal: Airisu.seal
    property color rule: Airisu.inkThird
    property bool available: true
    // Set when the caller drives `pressed` (a hold), so it follows the hand with no travel of its own.
    property bool driven: false
    implicitWidth: Airisu.u(3)
    implicitHeight: Airisu.u(3)

    // How far the stamp has been pressed in, 0 to 1; a hold drives it itself.
    property real pressed: root.stamped ? 1 : 0
    Behavior on pressed {
        enabled: Airisu.moving && !root.driven
        NumberAnimation { duration: Airisu.snap; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve }
    }
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Airisu.hair
        border.color: !root.available ? root.rule : root.stamped ? root.seal : root.rule
        antialiasing: false
    }
    Rectangle {
        readonly property real inset: Math.max(2, Math.round(root.width * 0.2))
        readonly property real side: (root.width - 2 * inset) * root.pressed
        visible: root.pressed > 0.01
        x: Math.round((root.width - side) / 2)
        y: Math.round((root.height - side) / 2)
        width: Math.round(side)
        height: Math.round(side)
        color: root.available ? root.seal : root.rule
        antialiasing: false
    }
}
