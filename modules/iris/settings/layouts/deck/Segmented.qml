import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Deck's choice: a row of keys sunk into the card, the taken one lit in the accent with dark ink: read from across the
// room. Held from the keys (Deck's ⏎), arrows flank it.
Item {
    id: root
    property Item host
    readonly property real wantHeight: 38
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property real d: IrisStyle.settingsDensity
    readonly property real gap: Math.round(5 * root.d)
    function slot(i: int): real { return root.host ? root.host.slotX(i) : 0 }
    function span(i: int): real { return root.slot(i + 1) - root.slot(i) }
    FontMetrics { id: metrics; font.family: IrisStyle.fontMain; font.pixelSize: IrisStyle.typeLabel; font.weight: Font.DemiBold }
    function widthFor(label: string): real { return Math.max(Math.round(58 * root.d), Math.ceil(metrics.advanceWidth(label)) + Math.round(28 * root.d)) }
    Repeater {
        model: root.options
        Rectangle {
            id: key
            required property var modelData
            required property int index
            readonly property bool taken: key.index === root.chosen
            readonly property bool hovered: key.index === (root.host?.hoveredIndex ?? -1)
            x: root.slot(key.index) + Math.round(root.gap / 2)
            width: root.span(key.index) - root.gap
            height: root.height
            radius: IrisStyle.radiusRow
            color: key.taken ? IrisStyle.accent : key.hovered ? IrisStyle.fillHover : Qt.rgba(0, 0, 0, IrisStyle.light ? 0.06 : 0.26) // iris-literal: keys sunk into the card
            border.width: key.taken ? 0 : 1
            border.color: IrisStyle.hairline
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                visible: (root.host?.glyphOnly ?? false) && String(key.modelData.glyph ?? "").length > 0
                anchors.centerIn: parent
                text: String(key.modelData.glyph ?? "")
                iconSize: Math.round(18 * root.d)
                color: key.taken ? IrisStyle.inkOnAccent : IrisStyle.subtext
            }
            IrisText {
                visible: !(root.host?.glyphOnly ?? false)
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Math.round(10 * root.d))
                elide: Text.ElideRight
                text: Translation.tr(String(key.modelData.label ?? ""))
                color: key.taken ? IrisStyle.inkOnAccent : key.hovered ? IrisStyle.text : IrisStyle.muted
                font.family: root.host?.fontFor ? (root.host.fontFor(key.modelData) || IrisStyle.fontMain) : IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                font.weight: key.taken ? Font.Bold : Font.Medium
            }
        }
    }
}
