import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

/**
 * Material 3 dialog button. See https://m3.material.io/components/dialogs/overview
 */
RippleButton {
    id: root

    property string buttonText
    padding: 14
    implicitHeight: 36
    implicitWidth: buttonTextWidget.implicitWidth + padding * 2
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
               : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
               : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : (Appearance?.rounding.full ?? 9999)

    property color colEnabled: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : (Appearance.colors.colPrimary)
    property color colDisabled: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextDisabled : Appearance.colors.colOutline
    colBackground: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" 
        : ColorUtils.transparentize(Appearance.colors.colLayer3)
    colBackgroundHover: Appearance.zzzEverywhere ? ColorUtils.mix(Appearance.zzz.paperAlt, Appearance.zzz.signal, 0.92)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
        : Appearance.colors.colLayer3Hover
    colRipple: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.32)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
        : Appearance.colors.colLayer3Active
    property alias colText: buttonTextWidget.color

    contentItem: StyledText {
        id: buttonTextWidget
        anchors.fill: parent
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        text: Appearance.zzzEverywhere ? root.buttonText.toUpperCase() : root.buttonText
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Appearance?.font.pixelSize.small ?? 12
        font.family: Appearance.zzzEverywhere ? Appearance.font.family.title : Appearance.font.family.main
        font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Normal
        font.italic: Appearance.zzzEverywhere
        color: root.enabled ? root.colEnabled : root.colDisabled

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

}
