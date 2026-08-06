pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root
    property bool active: false

    horizontalPadding: Appearance.rounding.large
    verticalPadding: 12

    clip: true
    pointingHandCursor: !active    
    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2
    Behavior on implicitHeight {
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }

    colBackground: active
        ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: active
        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer2Hover
    colRipple: active
        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.rounding.normal
}
