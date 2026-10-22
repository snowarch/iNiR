import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's switch: the two words in one ruled capsule, the one taken filled; on is the accent, off a quiet plate.
Item {
    id: root
    property Item host
    readonly property real wantWidth: 98
    readonly property real wantHeight: 30
    readonly property bool on: root.host?.on ?? false
    readonly property real d: IrisStyle.settingsDensity
    readonly property real cell: (root.width - 4) / 2
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: (root.host?.hovered ?? false) || (root.host?.keyed ?? false) ? IrisStyle.hairlineStrong : IrisStyle.hairline
    }
    Rectangle {
        x: root.on ? 2 : 2 + root.cell
        y: 2
        width: root.cell
        height: root.height - 4
        radius: height / 2
        color: root.on ? IrisStyle.accent : IrisStyle.fill
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
    }
    Repeater {
        model: [{ on: true, word: Translation.tr("On") }, { on: false, word: Translation.tr("Off") }]
        IrisText {
            required property var modelData
            required property int index
            x: 2 + index * root.cell
            width: root.cell
            height: root.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData.word
            readonly property bool taken: modelData.on === root.on
            color: taken && root.on ? IrisStyle.inkOnAccent : taken ? IrisStyle.text : IrisStyle.muted
            font.pixelSize: IrisStyle.typeLabel
            font.weight: taken ? Font.DemiBold : Font.Normal
        }
    }
}
