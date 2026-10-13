import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's row slider: a setting's range is a run (ARun) in a slot sunk into the row, its 45° edge the grip. The host
// (IrisSlider) keeps the drag, the steps and the wheel.
Item {
    id: root
    property Item host
    ARun {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round((root.host?.pressed || root.host?.hovered ? 12 : 10) * Airisu.d)
        value: root.host?.value ?? 0
        hovered: root.host?.hovered ?? false
        held: root.host?.pressed ?? false
        available: root.host?.enabled ?? true
        keyed: root.host?.keyed ?? root.host?.activeFocus ?? false
    }
}
