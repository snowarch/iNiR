import QtQuick
import qs.modules.iris.style

// Console's range: a line of dots, the ones up to the value in the ink and the value itself a bigger red dot.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property real value: Number(root.host?.shownValue ?? 0)
    readonly property bool engaged: root.host?.engaged ?? false
    readonly property int dots: Math.max(9, Math.floor(root.width / Math.round(13 * root.d)))
    readonly property int knob: Math.round(Math.max(0, Math.min(1, root.value)) * (root.dots - 1))
    readonly property real dot: Math.round(6 * root.d)
    Repeater {
        model: root.dots
        Rectangle {
            required property int index
            readonly property bool here: index === root.knob
            readonly property real size: here ? Math.round((root.engaged ? 16 : 13) * root.d) : root.dot
            x: Math.round(index / (root.dots - 1) * (root.width - root.dot) + root.dot / 2 - size / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: size
            height: size
            radius: size / 2
            color: here ? IrisStyle.danger : index < root.knob ? IrisStyle.text : Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, 0.18)
        }
    }
}
