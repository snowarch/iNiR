import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RippleButton {
    id: buttonWithIconRoot
    property string nerdIcon  // Manual override (empty = auto from MaterialSymbol)
    property string materialIcon
    property bool materialIconFill: true
    property string mainText: "Button text"
    property color contentColor: Appearance.zzzEverywhere ? Appearance.zzz.onColor
        : buttonWithIconRoot.colBackground.a > 0.01
            ? ColorUtils.ensureReadable(Appearance.colors.colOnLayer2,
                buttonWithIconRoot.colBackground, 4.5)
            : Appearance.colors.colOnSecondaryContainer
    property Component mainContentComponent: Component {
        StyledText {
            visible: text !== ""
            text: buttonWithIconRoot.mainText
            font.pixelSize: Appearance.font.pixelSize.small
            color: buttonWithIconRoot.contentColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
    implicitHeight: 35
    horizontalPadding: 10
    buttonRadius: Appearance.rounding.small
    colBackground: Appearance.colors.colLayer2

    contentItem: RowLayout {
        MaterialSymbol {
            text: buttonWithIconRoot.nerdIcon || buttonWithIconRoot.materialIcon
            iconSize: Appearance.font.pixelSize.larger
            color: buttonWithIconRoot.contentColor
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            fill: buttonWithIconRoot.materialIconFill ? 1 : 0
            animateFill: true
            forceNerd: buttonWithIconRoot.nerdIcon !== ""
        }
        Loader {
            Layout.fillWidth: true
            sourceComponent: buttonWithIconRoot.mainContentComponent
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
