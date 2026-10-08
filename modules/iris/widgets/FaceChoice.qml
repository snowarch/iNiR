pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common.widgets
import qs.modules.iris.style

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    signal clicked()

    implicitWidth: row.implicitWidth + Math.round(20 * IrisStyle.density)
    implicitHeight: Math.round(34 * IrisStyle.density)
    radius: height / 2
    color: root.selected ? IrisStyle.tintFill(IrisStyle.accent)
        : hover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
    border.width: root.selected ? 1 : 0
    border.color: IrisStyle.tintBorder(IrisStyle.accent)
    scale: tap.pressed ? IrisStyle.pressScale(0.97) : 1
    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(6 * IrisStyle.density)
        MaterialSymbol {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.selected ? 1 : 0
            iconSize: 16 * IrisStyle.typeScale
            color: root.selected ? IrisStyle.accent : IrisStyle.textSecondary
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.selected ? IrisStyle.text : IrisStyle.textSecondary
            font.family: IrisStyle.fontMain
            font.pixelSize: IrisStyle.typeLabel
            font.weight: root.selected ? Font.DemiBold : Font.Medium
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.checked: root.selected
}
