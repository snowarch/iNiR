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
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Hover : Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Active : Appearance.colors.colSecondaryContainerActive

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        iconSize: Appearance.font.pixelSize.larger
        text: buttonIcon
        color: button.activated ? (Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary) :
            button.enabled ? (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface) :
            (Appearance.inirEverywhere ? Appearance.inir.colTextDisabled : Appearance.colors.colOnLayer1Inactive)

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
