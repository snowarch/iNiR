import QtQuick
import "../components"

// AIRISU's scrubber. A setting's range (the host has a knob) is the graduated rule. A position in time is punched tape
// (ATape): the time still to come a line of holes, the time played a solid rule of ink, the head the seal while it
// plays. Engaged, the head grows to be taken. The host keeps the drag, keys and wheel.
Item {
    id: root
    property Item host
    readonly property real value: root.host?.shownValue ?? 0
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
    ATape {
        visible: !root.knob
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        live: root.host?.live ?? true
        engaged: root.host?.engaged ?? false
        available: root.host?.enabled ?? true
    }
}
