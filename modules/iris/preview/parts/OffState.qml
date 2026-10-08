pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Rectangle {
    id: off
    property string text: ""
    anchors.centerIn: parent
    implicitWidth: offRow.implicitWidth + Math.round(28 * IrisStyle.density)
    implicitHeight: Math.round(36 * IrisStyle.density)
    radius: height / 2
    color: IrisStyle.veilHeavy
    border.width: 1
    border.color: IrisStyle.border
    RowLayout {
        id: offRow
        anchors.centerIn: parent
        spacing: Math.round(8 * IrisStyle.density)
        MaterialSymbol { text: "visibility_off"; iconSize: Math.round(16 * IrisStyle.density); color: IrisStyle.subtext }
        IrisText { text: off.text; font.weight: IrisStyle.weight(Font.DemiBold) }
    }
}
