import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button

    property string buttonIcon
    property string buttonText
    property bool keyboardDown: false
    property real size: 120

    buttonRadius: (button.focus || button.down) ? size / 2 
        : (Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.verylarge)
    colBackground: button.keyboardDown 
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colSecondaryContainerActive)
        : button.focus 
            ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
            : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
                : Appearance.colors.colSecondaryContainer)
    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimary
    colRipple: Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colPrimaryActive
    property color colText: (button.down || button.keyboardDown || button.focus || button.hovered) ?
        (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.m3colors.m3onPrimary) 
        : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    background.implicitHeight: size
    background.implicitWidth: size

    Behavior on buttonRadius {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = true
            button.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = false
            event.accepted = true;
        }
    }

    contentItem: MaterialSymbol {
        id: icon
        anchors.fill: parent
        color: button.colText
        horizontalAlignment: Text.AlignHCenter
        iconSize: 45
        text: buttonIcon
    }

    StyledToolTip {
        text: buttonText
    }

}
