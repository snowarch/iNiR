pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

RowLayout {
    id: header
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property color tint: IrisStyle.accent
    default property alias actions: actionRow.data
    Layout.fillWidth: true
    spacing: 8 * IrisStyle.density
    Rectangle {
        implicitWidth: Math.round(24 * IrisStyle.density)
        implicitHeight: implicitWidth
        radius: IrisStyle.iconRadius(width)
        gradient: Gradient {
            GradientStop { position: 0; color: IrisStyle.tileTop(header.tint) }
            GradientStop { position: 1; color: header.tint }
        }
        MaterialSymbol { anchors.centerIn: parent; text: header.glyph; fill: 1; iconSize: Math.round(15 * IrisStyle.density); color: IrisStyle.onTint }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        IrisText {
            Layout.fillWidth: true
            text: header.title
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.pixelSize: IrisStyle.typeBody
            elide: Text.ElideRight
        }
        IrisText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: header.detail
            role: IrisText.Meta
            elide: Text.ElideRight
        }
    }
    RowLayout { id: actionRow; spacing: 0 }
}
