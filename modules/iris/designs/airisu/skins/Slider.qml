import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's row slider: a graduated rule (ARuler). The host (IrisSlider) keeps the drag, the steps and the wheel.
Item {
    id: root
    property Item host
    ARuler {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(16 * Airisu.d)
        value: root.host?.value ?? 0
        hovered: root.host?.hovered ?? false
        held: root.host?.pressed ?? false
        available: root.host?.enabled ?? true
        keyed: root.host?.keyed ?? root.host?.activeFocus ?? false
    }
}
