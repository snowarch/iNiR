import QtQuick

// Punched tape (SYSTEM.md §6, scrubber): a run in time. What is still to come is a line of holes, what has run a solid
// rule of ink, and the head is a small square: the seal while it runs, the ink while it waits. `engaged` grows the
// head to be taken. Drawing only: whoever wears it keeps its input.
Item {
    id: root
    property real value: 0
    property bool live: true
    property bool engaged: false
    property bool available: true
    property bool head: true
    readonly property real at: Math.round(root.width * Math.max(0, Math.min(1, root.value)))
    implicitHeight: Math.round(10 * Airisu.d)

    APerforation {
        x: root.at
        width: root.width - root.at
        anchors.verticalCenter: parent.verticalCenter
        colour: Airisu.inkThird
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: root.at
        height: Airisu.strong
        color: root.available ? Airisu.ink : Airisu.inkThird
    }
    Rectangle {
        visible: root.head
        property int side: Math.round((root.engaged ? 10 : 6) * Airisu.d)
        x: Math.round(Math.max(0, Math.min(root.width - width, root.at - width / 2)))
        anchors.verticalCenter: parent.verticalCenter
        width: side
        height: side
        color: !root.available ? Airisu.inkThird : root.live ? Airisu.seal : Airisu.ink
        Behavior on side { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent; easing.type: Easing.BezierSpline; easing.bezierCurve: Airisu.curve } }
    }
}
