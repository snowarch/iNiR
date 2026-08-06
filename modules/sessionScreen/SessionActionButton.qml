import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button

    property string buttonIcon
    property string buttonText
    property bool keyboardDown: false
    property real size: 120

    buttonRadius: Appearance.zzzEverywhere
        ? ((button.focus || button.down) ? Appearance.zzz.controlRadius : Appearance.zzz.panelRadius)
        : (button.focus || button.down) ? size / 2
        : (Appearance.angelEverywhere ? Appearance.angel.roundingLarge
            : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.verylarge)
    colBackground: Appearance.zzzEverywhere
        ? (button.keyboardDown
            ? Appearance.zzz.signal
            : button.focus ? Appearance.zzz.sticker : Appearance.zzz.paperAlt)
        : button.keyboardDown
        ? (Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colSecondaryContainerActive)
        : button.focus
            ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
            : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colSecondaryContainer)
    colBackgroundHover: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.sticker, 0.88)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colPrimary
    colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.30)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colPrimaryActive
    property color colText: Appearance.zzzEverywhere
        ? ((button.down || button.keyboardDown) ? Appearance.zzz.onSignal
            : (button.focus || button.hovered) ? Appearance.zzz.onSticker : Appearance.zzz.ink)
        : (button.down || button.keyboardDown || button.focus || button.hovered) ?
        (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
        : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    background.implicitHeight: size
    background.implicitWidth: size

    Behavior on buttonRadius {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
