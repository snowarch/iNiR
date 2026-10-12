import QtQuick
import "../components"

// AIRISU's row slider (board Components › MEDIDOR): the level as twenty segments, the last 15 % the red line. The host
// (IrisSlider) keeps the drag, the steps and the wheel; this only draws.
Item {
    id: root
    property Item host
    AMeter {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(10 * Airisu.d)
        interactive: false
        value: root.host?.value ?? 0
        opacity: root.host?.enabled ?? true ? 1 : 0.4
    }
}
