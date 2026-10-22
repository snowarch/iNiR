import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Folio's choice: the options as words on the sheet, the one taken on a quiet ruled plate that slides between them.
Item {
    id: root
    property Item host
    readonly property real wantHeight: 32
    readonly property var options: root.host?.options ?? []
    readonly property int chosen: root.host?.selectedIndex ?? -1
    readonly property real d: IrisStyle.settingsDensity
    function slot(i: int): real { return root.host ? root.host.slotX(i) : 0 }
    readonly property real slotWidth: root.host ? root.host.slot : 0
    Rectangle {
        visible: root.chosen >= 0
        x: root.slot(Math.max(0, root.chosen)) + 2
        y: 2
        width: root.slotWidth - 4
        height: root.height - 4
        radius: height / 2
        color: IrisStyle.fill
        border.width: 1
        border.color: IrisStyle.hairline
        Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
    }
    Repeater {
        model: root.options
        Row {
            id: option
            required property var modelData
            required property int index
            readonly property bool taken: option.index === root.chosen
            readonly property bool hovered: option.index === (root.host?.hoveredIndex ?? -1)
            x: root.slot(option.index) + Math.round((root.slotWidth - width) / 2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                visible: (root.host?.glyphOnly ?? false) && String(option.modelData.glyph ?? "").length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: String(option.modelData.glyph ?? "")
                iconSize: Math.round(16 * root.d)
                color: option.taken || option.hovered ? IrisStyle.text : IrisStyle.muted
            }
            IrisText {
                visible: !(root.host?.glyphOnly ?? false)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, root.slotWidth - Math.round(10 * root.d))
                elide: Text.ElideRight
                text: Translation.tr(String(option.modelData.label ?? ""))
                color: option.taken || option.hovered ? IrisStyle.text : IrisStyle.muted
                font.family: root.host?.fontFor ? (root.host.fontFor(option.modelData) || IrisStyle.fontMain) : IrisStyle.fontMain
                font.pixelSize: IrisStyle.typeLabel
                font.weight: option.taken ? Font.Medium : Font.Normal
            }
        }
    }
}
