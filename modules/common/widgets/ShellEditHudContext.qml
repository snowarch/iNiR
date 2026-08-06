pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

Item {
    id: root

    required property string icon
    required property string title
    required property string detail
    required property color accentColor
    required property color backgroundColor
    required property color textColor
    required property color secondaryTextColor
    required property real radius
    required property string iconFontFamily
    required property string textFontFamily
    required property int titlePixelSize
    required property int detailPixelSize

    readonly property real contentWidth: contextRow.implicitWidth + 16
    implicitWidth: contentWidth
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: ColorUtils.applyAlpha(root.backgroundColor, 0.94)
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.accentColor, 0.28)
    }

    Row {
        id: contextRow
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.accentColor
            font.family: root.iconFontFamily
            font.pixelSize: Math.max(root.titlePixelSize + 5, 16)
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: root.title
                color: root.textColor
                font.family: root.textFontFamily
                font.pixelSize: root.titlePixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Text {
                visible: root.detail.length > 0
                text: root.detail
                color: root.secondaryTextColor
                font.family: root.textFontFamily
                font.pixelSize: root.detailPixelSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }
}
