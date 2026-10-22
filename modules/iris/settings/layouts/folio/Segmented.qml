import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's choice: the options as words in a line, kept apart by thin slashes; the taken one in the ink over an accent
// rule that slides between them. No plate, no box: a sentence you pick a word from.
Item {
    id: root
    property Item host
    readonly property real wantHeight: 32
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property real d: IrisStyle.settingsDensity
    function slot(i: int): real { return root.host ? root.host.slotX(i) : 0 }
    function span(i: int): real { return root.slot(i + 1) - root.slot(i) }
    FontMetrics { id: metrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.Medium }
    function widthFor(label: string): real { return Math.ceil(metrics.advanceWidth(label)) + Math.round(22 * root.d) }
    Rectangle {
        visible: root.chosen >= 0
        readonly property real inset: Math.round(9 * root.d)
        x: root.slot(Math.max(0, root.chosen)) + inset
        y: root.height - Math.round(5 * root.d)
        width: root.span(Math.max(0, root.chosen)) - 2 * inset
        height: Math.max(2, Math.round(2 * root.d))
        radius: height / 2
        color: IrisStyle.accent
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    }
    Repeater {
        model: root.options
        Item {
            id: option
            required property var modelData
            required property int index
            readonly property bool taken: option.index === root.chosen
            readonly property bool hovered: option.index === (root.host?.hoveredIndex ?? -1)
            x: root.slot(option.index)
            width: root.span(option.index)
            height: root.height
            IrisText {
                visible: option.index > 0
                x: -Math.round(width / 2)
                anchors.verticalCenter: parent.verticalCenter
                text: "/"
                color: IrisStyle.textTertiary
                opacity: 0.6
                font.pixelSize: IrisStyle.typeLabel
                font.weight: Font.Light
            }
            MaterialSymbol {
                visible: (root.host?.glyphOnly ?? false) && String(option.modelData.glyph ?? "").length > 0
                anchors.centerIn: parent
                text: String(option.modelData.glyph ?? "")
                iconSize: Math.round(16 * root.d)
                color: option.taken || option.hovered ? IrisStyle.text : IrisStyle.muted
            }
            IrisText {
                visible: !(root.host?.glyphOnly ?? false)
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Math.round(8 * root.d))
                elide: Text.ElideRight
                text: Translation.tr(String(option.modelData.label ?? ""))
                color: option.taken || option.hovered ? IrisStyle.text : IrisStyle.muted
                font.family: root.host?.fontFor ? (root.host.fontFor(option.modelData) || IrisStyle.fontMain) : IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                font.weight: option.taken ? Font.Medium : Font.Normal
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            }
        }
    }
}
