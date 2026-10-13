import QtQuick
import "../components"

// AIRISU's row slider: a rule (ARule). The host (IrisSlider) keeps the drag, the steps and the wheel.
Item {
    id: root
    property Item host
    ARule {
        anchors.fill: parent
        value: Number(root.host?.value ?? 0)
        hovered: root.host?.hovered ?? false
        held: root.host?.pressed ?? false
        available: root.host?.enabled ?? true
        keyed: root.host?.keyed ?? root.host?.activeFocus ?? false
    }
}
