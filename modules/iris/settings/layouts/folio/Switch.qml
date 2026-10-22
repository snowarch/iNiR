import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's switch: the two words printed side by side, the taken one in the ink behind its dot: lit in the accent for
// on, a hollow ring for off. A click anywhere swaps them.
Item {
    id: root
    property Item host
    readonly property bool on: root.host?.on ?? false
    readonly property real d: IrisStyle.settingsDensity
    FontMetrics { id: metrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.DemiBold }
    readonly property real dot: Math.round(7 * root.d)
    readonly property real cellOn: Math.ceil(metrics.advanceWidth(Translation.tr("On"))) + root.dot + Math.round(8 * root.d)
    readonly property real cellOff: Math.ceil(metrics.advanceWidth(Translation.tr("Off"))) + root.dot + Math.round(8 * root.d)
    readonly property real wantWidth: (root.cellOn + root.cellOff) / root.d + 16
    readonly property real wantHeight: 30
    readonly property bool lit: (root.host?.hovered ?? false) || (root.host?.keyed ?? false)
    Repeater {
        model: [{ on: true, word: Translation.tr("On") }, { on: false, word: Translation.tr("Off") }]
        Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool taken: cell.modelData.on === root.on
            x: cell.index === 0 ? 0 : root.width - width
            width: cell.index === 0 ? root.cellOn : root.cellOff
            height: root.height
            Rectangle {
                id: mark
                visible: cell.taken
                anchors.verticalCenter: parent.verticalCenter
                width: root.dot
                height: width
                radius: width / 2
                color: root.on ? IrisStyle.accent : "transparent"
                border.width: root.on ? 0 : Math.max(1, Math.round(1.5 * root.d))
                border.color: IrisStyle.muted
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                x: root.dot + Math.round(7 * root.d)
                text: cell.modelData.word
                color: cell.taken ? IrisStyle.text : root.lit ? IrisStyle.muted : IrisStyle.textTertiary
                font.pixelSize: IrisStyle.typeLabel
                font.weight: cell.taken ? Font.DemiBold : Font.Normal
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
}
