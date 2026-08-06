pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText
    property string urgency

    implicitHeight: 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: Appearance.zzzEverywhere
        ? (urgency == NotificationUrgency.Critical ? Appearance.zzz.secondary : Appearance.zzz.paperAlt)
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainer
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer4
    colBackgroundHover: Appearance.zzzEverywhere
        ? (urgency == NotificationUrgency.Critical
            ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colLayer2Hover)
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer4Hover
    colRipple: Appearance.zzzEverywhere
        ? (urgency == NotificationUrgency.Critical
            ? Appearance.colors.colSecondaryContainerActive
            : Appearance.colors.colLayer2Active)
        : (urgency == NotificationUrgency.Critical)
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer4Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: Appearance.zzzEverywhere
            ? (urgency == NotificationUrgency.Critical ? Appearance.zzz.onSecondary : Appearance.zzz.ink)
            : (urgency == NotificationUrgency.Critical) ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnSurface

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
