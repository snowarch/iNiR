pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

RowLayout {
    id: blockRow
    property string glyph: "circle"
    property string title: ""
    property string detail: ""
    Layout.fillWidth: true
    spacing: Math.round(12 * IrisStyle.density)
    Item {
        implicitWidth: Math.round(40 * IrisStyle.density)
        implicitHeight: implicitWidth
        Rectangle { anchors.fill: parent; radius: width / 2; color: IrisStyle.fill }
        MaterialSymbol { anchors.centerIn: parent; text: blockRow.glyph; fill: 1; iconSize: Math.round(20 * IrisStyle.density); color: IrisStyle.text }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Math.round(1 * IrisStyle.density)
        IrisText { Layout.fillWidth: true; text: blockRow.title; font.weight: IrisStyle.weight(Font.DemiBold); elide: Text.ElideRight }
        IrisText { Layout.fillWidth: true; text: blockRow.detail; color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta; elide: Text.ElideRight }
    }
}
