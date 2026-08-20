pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText: ""
    property var urgency: NotificationUrgency.Normal
    readonly property bool critical: button.urgency === NotificationUrgency.Critical
        || String(button.urgency ?? "").toLowerCase() === "critical"

    implicitHeight: 34
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    colBackground: Appearance.zzzEverywhere
        ? (button.critical ? Appearance.zzz.secondary : Appearance.zzz.paperAlt)
        : button.critical
        ? Appearance.colors.colSecondaryContainer
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer4
    colBackgroundHover: Appearance.zzzEverywhere
        ? (button.critical
            ? Appearance.colors.colSecondaryContainerHover
            : Appearance.colors.colLayer2Hover)
        : button.critical
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer4Hover
    colRipple: Appearance.zzzEverywhere
        ? (button.critical
            ? Appearance.colors.colSecondaryContainerActive
            : Appearance.colors.colLayer2Active)
        : button.critical
        ? Appearance.colors.colSecondaryContainerActive
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer3Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer4Active

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: Appearance.zzzEverywhere
            ? (button.critical ? Appearance.zzz.onSecondary : Appearance.zzz.ink)
            : button.critical
                ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer3

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
