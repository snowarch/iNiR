import QtQuick
import qs.modules.iris.style

// Deck's range: a meter of twenty cells, the lit ones in the accent; held or keyed the cells stand taller.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property real value: Number(root.host?.shownValue ?? 0)
    readonly property bool engaged: root.host?.engaged ?? false
    readonly property int cells: 20
    readonly property real gap: Math.max(2, Math.round(3 * root.d))
    readonly property real cell: (root.width - (root.cells - 1) * root.gap) / root.cells
    readonly property int lit: Math.round(root.value * root.cells)
    Repeater {
        model: root.cells
        Rectangle {
            required property int index
            readonly property bool on: index < root.lit
            x: Math.round(index * (root.cell + root.gap))
            width: Math.max(2, Math.round(root.cell))
            height: Math.min(root.height, Math.round((root.engaged ? 22 : 16) * root.d))
            anchors.verticalCenter: parent.verticalCenter
            radius: Math.min(width / 2, Math.round(3 * root.d))
            color: on ? IrisStyle.accent : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.12)
            Behavior on height { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
        }
    }
}
