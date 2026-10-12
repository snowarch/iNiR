import QtQuick
import "../components"

// AIRISU's row slider (SYSTEM.md §6): the graduated rule. The host (IrisSlider) keeps the drag, the steps and the
// wheel; the pointer over it brings the crop marks.
Item {
    id: root
    property Item host
    ARuler {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(16 * Airisu.d)
        value: root.host?.value ?? 0
        held: root.host?.pressed ?? false
        available: root.host?.enabled ?? true
    }
    ATombo {
        anchors.fill: parent
        anchors.topMargin: Math.round((root.height - 16 * Airisu.d) / 2)
        anchors.bottomMargin: anchors.topMargin
        shown: (root.host?.hovered ?? false) && !(root.host?.pressed ?? false)
    }
}
