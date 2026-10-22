import QtQuick
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's range: a printed ruler, one tick per step (halved past forty), every fourth one long and the default's tick in
// the ink; the value an accent needle with its head over a hairline fill. Held or keyed, the needle stands taller and
// carries its figure. The row prints the figure beside it.
Item {
    id: root
    property Item host
    readonly property real d: IrisStyle.settingsDensity
    readonly property var range: root.host?.range ?? null
    readonly property real value: Number(root.host?.shownValue ?? 0)
    readonly property bool engaged: root.host?.engaged ?? false
    readonly property int marks: {
        if (!root.range) return 21
        let n = Math.round((root.range.max - root.range.min) / Math.max(1e-6, root.range.step))
        while (n > 40) n = Math.ceil(n / 2)
        return Math.max(2, n) + 1
    }
    readonly property real base: root.height - Math.round(3 * root.d)
    Repeater {
        model: root.marks
        Rectangle {
            required property int index
            readonly property bool major: index % 4 === 0 || index === root.marks - 1
            x: Math.round(index / (root.marks - 1) * (root.width - 1))
            y: root.base - height
            width: 1
            height: Math.round((major ? 11 : 6) * root.d)
            color: Qt.rgba(IrisStyle.text.r, IrisStyle.text.g, IrisStyle.text.b, major ? 0.44 : 0.22)
        }
    }
    Rectangle { y: root.base; width: root.width; height: 1; color: IrisStyle.hairline }
    Rectangle { y: root.base; width: Math.round(root.value * root.width); height: 1; color: IrisStyle.accent }
    Item {
        id: needle
        x: Math.round(root.value * (root.width - 3))
        width: Math.max(2, Math.round(3 * root.d))
        height: root.height
        readonly property real tall: Math.round((root.engaged ? 24 : 19) * root.d)
        Behavior on x { enabled: !(root.host?.dragging ?? false); NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        Rectangle {
            y: root.base + 1 - needle.tall
            width: needle.width
            height: needle.tall
            radius: width / 2
            color: IrisStyle.accent
            Behavior on height { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.base + 1 - needle.tall - Math.round(4 * root.d)
            width: Math.round(7 * root.d)
            height: width
            rotation: 45
            color: IrisStyle.accent
        }
        IrisText {
            visible: root.engaged && String(root.range?.text ?? "").length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.base - needle.tall - Math.round(10 * root.d) - height
            text: String(root.range?.text ?? "")
            color: IrisStyle.accent
            font.family: IrisStyle.fontMono
            font.pixelSize: IrisStyle.typeCaption
            font.weight: Font.DemiBold
        }
    }
}
