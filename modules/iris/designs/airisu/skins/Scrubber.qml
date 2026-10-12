import QtQuick
import "../components"

// AIRISU's scrubber. A setting's range (the host has a knob) is the graduated rule. A position in time is punched tape:
// the time still to come is a line of holes, the time played a solid rule of ink, and the head is a small seal square
// while it plays (a rule end when paused). Engaged, the head grows to be taken. The host keeps the drag, keys and wheel.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
    readonly property bool engaged: root.host?.engaged ?? false
    readonly property bool knob: root.host?.knob ?? false

    ARuler {
        visible: root.knob
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(16 * Airisu.d)
        value: root.value
        held: root.host?.dragging ?? false
        available: root.host?.enabled ?? true
    }

    Item {
        id: tape
        visible: !root.knob
        anchors.fill: parent
        readonly property real head: Math.round(tape.width * root.value)
        APerforation {
            x: tape.head
            width: tape.width - tape.head
            anchors.verticalCenter: parent.verticalCenter
            colour: Airisu.inkThird
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: tape.head
            height: Airisu.strong
            color: root.host?.enabled ?? true ? Airisu.ink : Airisu.inkThird
        }
        Rectangle {
            property int side: Math.round((root.engaged ? 10 : 6) * Airisu.d)
            x: Math.round(Math.max(0, Math.min(tape.width - width, tape.head - width / 2)))
            anchors.verticalCenter: parent.verticalCenter
            width: side
            height: side
            color: !(root.host?.enabled ?? true) ? Airisu.inkThird : root.host?.live ?? true ? Airisu.seal : Airisu.ink
            Behavior on side { enabled: Airisu.moving; NumberAnimation { duration: Airisu.detent } }
        }
    }
}
