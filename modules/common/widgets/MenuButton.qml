import qs.modules.common
import QtQuick

RippleButton {
    id: root

    buttonRadius: 0
    implicitHeight: 36
    implicitWidth: buttonTextWidget.implicitWidth + 14 * 2

    contentItem: StyledText {
        id: buttonTextWidget
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        text: root.buttonText
        horizontalAlignment: Text.AlignLeft
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.enabled ? Appearance.colors.colOnSurface : Appearance.colors.colOutline

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

}
