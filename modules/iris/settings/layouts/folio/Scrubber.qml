import QtQuick
import qs.modules.iris.style

// Folio's range: a ruler of the range's steps (every fourth one long), the value an accent needle over a thin filled
// line. The row prints the figure beside it.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property var range: root.host?.range ?? null
    readonly property real value: Number(root.host?.shownValue ?? 0)
    readonly property int marks: {
        if (!root.range) return 21
        const steps = Math.round((root.range.max - root.range.min) / Math.max(1e-6, root.range.step))
        let n = steps
        while (n > 40) n = Math.ceil(n / 2)
        return Math.max(2, n) + 1
    }
    Repeater {
        model: root.marks
        Rectangle {
            required property int index
            readonly property bool major: index % 4 === 0
            x: Math.round(index / (root.marks - 1) * (root.width - 1))
            y: root.height - height - Math.round(4 * root.d)
            width: 1
            height: Math.round((major ? 12 : 7) * root.d)
            color: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, major ? 0.42 : 0.24)
        }
    }
    Rectangle {
        y: root.height - Math.round(4 * root.d)
        width: Math.round(root.value * root.width)
        height: Math.max(1, Math.round(2 * root.d))
        color: IrisStyle.accent
        opacity: 0.6
    }
    Rectangle {
        x: Math.round(root.value * (root.width - width))
        y: root.height - height
        width: Math.max(2, Math.round(3 * root.d))
        height: Math.round(((root.host?.engaged ?? false) ? 22 : 18) * root.d)
        radius: width / 2
        color: IrisStyle.accent
        Behavior on height { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }
}
