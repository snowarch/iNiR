pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

MaterialTextField {
    id: root

    enableSettingsSearch: false
    color: IrisStyle.text
    placeholderTextColor: "transparent"
    selectionColor: IrisStyle.accentContainer
    selectedTextColor: IrisStyle.onAccentContainer
    font.family: IrisStyle.fontTitle
    font.pixelSize: IrisStyle.typeHeadline
    leftPadding: 14 * IrisStyle.density
    rightPadding: 14 * IrisStyle.density
    // Material insets the background for a floating label iRiS never shows, which drops the box below its text.
    topInset: 0
    bottomInset: 0

    IrisText {
        anchors.left: parent.left
        anchors.leftMargin: root.leftPadding
        anchors.right: parent.right
        anchors.rightMargin: root.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: root.text.length === 0 && root.placeholderText.length > 0
        text: root.placeholderText
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        color: IrisStyle.subtext
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: IrisStyle.radiusSmall
        color: IrisStyle.field
        border.width: root.activeFocus ? 1 : 0
        border.color: IrisStyle.hairlineStrong
    }
}
