import QtQuick
import "../components"

// AIRISU's scrubber. A level (the host has a knob: Settings' ranges) is the twenty-segment meter; a position in time
// (media) is a light trail (board Movimiento › estela): a fillet of track, the played part in gofun, and the head a
// streak of the seal that fades back along the line, a tail light at speed. The host keeps the drag, keys and wheel.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
    readonly property bool engaged: root.host?.engaged ?? false

    AMeter {
        visible: root.host?.knob ?? false
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(10 * Airisu.d)
        interactive: false
        value: root.value
    }

    Item {
        visible: !(root.host?.knob ?? false)
        anchors.fill: parent
        readonly property real thick: Math.max(1, Math.round((root.engaged ? 4 : 2) * Airisu.d))
        readonly property real head: Math.round(parent.width * root.value)
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: parent.thick; color: Airisu.socket }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.head; height: parent.thick; color: Airisu.gofun }
        // The trail: the seal, strongest at the head, gone over 56 px.
        Rectangle {
            readonly property real length: Math.min(parent.head, Math.round(56 * Airisu.d))
            x: parent.head - length
            anchors.verticalCenter: parent.verticalCenter
            width: length
            height: parent.thick
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Airisu.seal }
            }
        }
        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.head - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(2, Math.round(3 * Airisu.d))
            height: Math.round((root.engaged ? 14 : 10) * Airisu.d)
            color: Airisu.seal
        }
    }
}
