import QtQuick
import qs.modules.iris.style

// The meter (メーター): a level drawn as 20 segments, never a capsule. Lit segments are gofun; the last 15 % is the red
// line, the seal when lit and the seal dimmed into the lacquer when not. `ascending` grows each segment like a
// tachometer (the OSD). Drag, click or scroll to set it; the owner writes the value back through `moved`.
Item {
    id: root
    property real value: 0
    property bool ascending: false
    property bool interactive: true
    property int segments: 20
    readonly property int redFrom: Math.round(root.segments * 0.85)
    readonly property int lit: Math.round(Math.max(0, Math.min(1, root.value)) * root.segments)
    readonly property int gap: Math.max(2, Math.round(3 * Airisu.d))
    signal moved(real value)

    implicitHeight: Math.round(10 * Airisu.d)
    Accessible.role: Accessible.Slider

    Row {
        anchors.fill: parent
        spacing: root.gap
        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                readonly property bool on: index < root.lit
                readonly property bool red: index >= root.redFrom
                width: (root.width - root.gap * (root.segments - 1)) / root.segments
                height: root.ascending ? Math.max(2, Math.round(root.height * (0.3 + 0.7 * (index + 1) / root.segments))) : root.height
                anchors.bottom: parent.bottom
                color: red ? (on ? Airisu.seal : Airisu.sealDim) : on ? Airisu.gofun : Airisu.socket
                Behavior on color { enabled: IrisStyle.motionEnabled; ColorAnimation { duration: Airisu.shift } }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -Math.round(6 * Airisu.d)
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        function at(x: real): real { return Math.max(0, Math.min(1, Math.ceil((x - anchors.margins) / root.width * root.segments) / root.segments)) }
        onPressed: mouse => root.moved(at(mouse.x))
        onPositionChanged: mouse => { if (pressed) root.moved(at(mouse.x)) }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 1 : -1) / root.segments)))
    }
}
