pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.functions

// Live dimension readout shown while a shell-edit resize gesture is active.
// Washi chip with a lit filament and tabular numbers, fed by family tokens.
Rectangle {
    id: root

    required property color accentColor
    required property color surfaceColor
    required property color textColor
    required property string fontFamily
    required property int fontPixelSize

    property string valueText: ""
    property bool active: false

    visible: root.active
    width: badgeRow.implicitWidth + 22
    height: badgeRow.implicitHeight + 12
    radius: height / 2
    border.width: 1
    color: root.surfaceColor
    border.color: ColorUtils.applyAlpha(root.accentColor, 0.82)

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.valueText
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontPixelSize
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
