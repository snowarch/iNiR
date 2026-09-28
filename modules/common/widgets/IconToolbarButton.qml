pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

ToolbarButton {
    id: iconBtn
    implicitWidth: height
    property int iconRenderType: Text.NativeRendering
    property int iconSize: Appearance.regaliaEverywhere ? 18 : 22

    colBackgroundToggled: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.zzzEverywhere ? Appearance.zzz.sticker
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colSelection 
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface 
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateHover
        : Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colSelectionHover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover 
        : Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
        : Appearance.colors.colSecondaryContainerActive
    property color colText: toggled
        ? (Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
            : Appearance.zzzEverywhere ? Appearance.zzz.onSticker
            : Appearance.inirEverywhere ? Appearance.inir.colOnSelection : Appearance.colors.colOnSecondaryContainer)
        : (Appearance.regaliaEverywhere ? Appearance.regalia.onColor
            : Appearance.zzzEverywhere ? Appearance.zzz.ink
            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant)

    contentItem: MaterialSymbol {
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        iconSize: iconBtn.iconSize
        text: iconBtn.text
        textRenderType: iconBtn.iconRenderType
        color: iconBtn.colText
    }
}
