import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Deck's choice: a sunken track, each name in a segment of its own width, the taken one lifted on a lit tile.
Item {
    id: root
    property Item host
    readonly property real wantHeight: 36
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property real d: IrisStyle.settingsDensity
    function slot(i: int): real { return root.host ? root.host.slotX(i) : 0 }
    function span(i: int): real { return root.slot(i + 1) - root.slot(i) }
    FontMetrics { id: metrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeMeta; font.weight: Font.Medium }
    function widthFor(label: string): real { return Math.ceil(metrics.advanceWidth(label)) + Math.round(24 * root.d) }
    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.radiusTile
        color: Qt.rgba(0, 0, 0, IrisStyle.light ? 0.06 : 0.24) // iris-literal: the track is sunk into the card
        border.width: 1
        border.color: IrisStyle.hairline
    }
    Rectangle {
        visible: root.chosen >= 0
        x: root.slot(Math.max(0, root.chosen)) + 1
        y: 3
        width: root.span(Math.max(0, root.chosen)) - 2
        height: root.height - 6
        radius: IrisStyle.radiusRow
        color: IrisStyle.fill
        Rectangle { x: parent.radius / 2; width: parent.width - parent.radius; height: 1; color: IrisStyle.hairline }
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    }
    Repeater {
        model: root.options
        IrisText {
            id: option
            required property var modelData
            required property int index
            readonly property bool taken: option.index === root.chosen
            x: root.slot(option.index) + Math.round((root.span(option.index) - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.span(option.index) - Math.round(8 * root.d))
            elide: Text.ElideRight
            text: Translation.tr(String(option.modelData.label ?? ""))
            color: option.taken || option.index === (root.host?.hoveredIndex ?? -1) ? IrisStyle.text : IrisStyle.muted
            font.family: root.host?.fontFor ? (root.host.fontFor(option.modelData) || IrisStyle.fontMain) : IrisStyle.fontMain
            font.pixelSize: IrisStyle.typeMeta
            font.weight: Font.Medium
        }
    }
}
