import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

GroupButton {
    id: button
    property string buttonIcon
    property bool activated: false
    toggled: activated
    baseWidth: height
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        iconSize: Appearance.font.pixelSize.larger
        text: buttonIcon
        color: button.activated ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.m3colors.m3onPrimary) :
            button.enabled ? (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface) :
            (Appearance.inirEverywhere ? Appearance.inir.colTextDisabled : Appearance.colors.colOnLayer1Inactive)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
