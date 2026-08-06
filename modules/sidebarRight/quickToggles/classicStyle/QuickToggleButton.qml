import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    baseWidth: 40
    baseHeight: 40
    clickedWidth: baseWidth + 20
    toggled: false
    // A standalone square control: cookie mode reads "on" as a six-lobed face
    // instead of a filled circle.
    cookieMorphing: true
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : ((altAction && toggled) ? Appearance?.rounding.normal : Math.min(baseHeight, baseWidth) / 2)
    buttonRadiusPressed: Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance?.rounding?.small
    // ZZZ: the visible surface is the chamfered ZzzPlate below; hold the GroupButton
    // rounded rect transparent.
    colBackground: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer2Hover
    colBackgroundToggled: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.45)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer : Appearance.colors.colPrimary
    colBackgroundToggledHover: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimaryHover, 0.35)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover : Appearance.colors.colPrimaryHover

    contentItem: Item {
        // ZZZ console key: a real chamfered plate (geometry, not a sticker). The
        // fill carries the active state; a subtle hairline frames it when idle.
        ZzzPlate {
            anchors.fill: parent
            visible: Appearance.zzzEverywhere
            chamfer: button.buttonHovered ? Appearance.zzz.cutCorner : Appearance.zzz.cutCorner * 0.65
            fillColor: button.toggled ? Appearance.zzz.chrome
                : button.buttonHovered ? Appearance.zzz.chrome : "transparent"
            strokeColor: button.toggled ? Appearance.zzz.hairlineStrong
                : button.buttonHovered ? Appearance.zzz.hairline : "transparent"
            strokeWidth: 1
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 20
            fill: button.toggled ? 1 : 0
            animateFill: true
            color: Appearance.zzzEverywhere
                ? (button.toggled ? Appearance.zzz.accent : button.buttonHovered ? Appearance.zzz.ink : Appearance.zzz.inkMuted)
                : Appearance.angelEverywhere
                ? (button.toggled ? Appearance.angel.colOnPrimary : Appearance.angel.colText)
                : Appearance.inirEverywhere
                ? (button.toggled ? Appearance.inir.colOnPrimaryContainer : Appearance.inir.colText)
                : (button.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.buttonIcon

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
