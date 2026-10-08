pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    required property var picker
    readonly property bool shrug: root.picker.online && !root.picker.searching

    spacing: Math.round(6 * IrisStyle.density)

    MaterialSymbol {
        Layout.alignment: Qt.AlignHCenter
        visible: !root.shrug
        text: root.picker.emptyGlyph
        fill: 1
        iconSize: Math.round(30 * IrisStyle.density)
        color: IrisStyle.muted
    }
    IrisText {
        Layout.alignment: Qt.AlignHCenter
        visible: root.shrug
        text: "(´・ω・`)"
        color: IrisStyle.subtext
        font.pixelSize: 22 * IrisStyle.typeScale
    }
    IrisText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: root.picker.emptyText
        color: IrisStyle.muted
    }
}
