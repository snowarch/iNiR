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
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall 
        : ((altAction && toggled) ? Appearance?.rounding.normal : Math.min(baseHeight, baseWidth) / 2)
    buttonRadiusPressed: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance?.rounding?.small
    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
    colBackgroundToggled: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.45)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer : Appearance.colors.colPrimary
    colBackgroundToggledHover: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimaryHover, 0.35)
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover : Appearance.colors.colPrimaryHover

    contentItem: Item {
        // Item fills the button area, icon is centered inside
        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 22
            fill: button.toggled ? 1 : 0
            color: Appearance.angelEverywhere
                ? (button.toggled ? Appearance.angel.colOnPrimary : Appearance.angel.colText)
                : Appearance.inirEverywhere 
                ? (button.toggled ? Appearance.inir.colOnPrimaryContainer : Appearance.inir.colText)
                : (button.toggled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: button.buttonIcon

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}
