import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Console's choice: round keys in mono capitals, each in a thin ring; the taken one is the ink with dark letters.
Item {
    id: root
    property Item host
    readonly property real wantHeight: 32
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property real d: IrisStyle.settingsDensity
    readonly property real gap: Math.round(6 * root.d)
    function slot(i: int): real { return root.host ? root.host.slotX(i) : 0 }
    function span(i: int): real { return root.slot(i + 1) - root.slot(i) }
    FontMetrics { id: metrics; font.family: IrisStyle.fontMono; font.pixelSize: IrisStyle.typeCaption; font.weight: Font.Medium }
    function widthFor(label: string): real {
        const word = label.toUpperCase()
        return Math.ceil(metrics.advanceWidth(word) + word.length * IrisStyle.typeCaption * 0.1) + Math.round(26 * root.d)
    }
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
            height: Math.min(root.height, Math.round(32 * root.d))
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: key.taken ? IrisStyle.text : "transparent"
            border.width: key.taken ? 0 : 1
            border.color: key.hovered ? IrisStyle.muted : IrisStyle.hairlineStrong
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                visible: (root.host?.glyphOnly ?? false) && String(key.modelData.glyph ?? "").length > 0
                anchors.centerIn: parent
                text: String(key.modelData.glyph ?? "")
                iconSize: Math.round(16 * root.d)
                color: key.taken ? IrisStyle.surfaceOpaque : IrisStyle.subtext
            }
            IrisText {
                visible: !(root.host?.glyphOnly ?? false)
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Math.round(10 * root.d))
                elide: Text.ElideRight
                text: Translation.tr(String(key.modelData.label ?? ""))
                color: key.taken ? IrisStyle.surfaceOpaque : key.hovered ? IrisStyle.text : IrisStyle.muted
                font.family: IrisStyle.fontMono
                font.pixelSize: IrisStyle.typeCaption
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(IrisStyle.typeCaption * 0.1)
            }
        }
    }
}
