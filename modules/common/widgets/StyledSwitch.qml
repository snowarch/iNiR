pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * Material 3 switch. See https://m3.material.io/components/switch/overview
 */
Switch {
    id: root
    property real scale: 0.6 // Default in m3 spec is huge af
    implicitHeight: Appearance.regaliaEverywhere ? 22 : 32 * root.scale
    implicitWidth: Appearance.regaliaEverywhere ? 40 : 52 * root.scale
    property color activeColor: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimary
    property color inactiveColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer2
        : Appearance.colors.colSurfaceContainerHighest

    PointingHandInteraction {}

    // Custom track styling
    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
            : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : (Appearance?.rounding.full ?? 9999)
        color: Appearance.regaliaEverywhere ? "transparent"
            : root.checked ? root.activeColor : root.inactiveColor
        border.width: Appearance.regaliaEverywhere ? 0
            : Appearance.zzzEverywhere ? Appearance.zzz.hairlineThick : 2 * root.scale
        border.color: Appearance.regaliaEverywhere ? "transparent"
            : root.checked ? root.activeColor
            : (Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : Appearance.colors.colOutline)

        RegaliaControlFace {
            anchors.fill: parent
            visible: Appearance.regaliaEverywhere
            fillColor: root.checked ? root.activeColor : root.inactiveColor
            radius: parent.radius
            hovered: root.hovered
            pressed: root.down
            selected: root.checked
            focused: root.visualFocus
        }

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    // Custom thumb styling
    indicator: Rectangle {
        id: thumb
        width: Appearance.regaliaEverywhere ? 16
            : (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        height: Appearance.regaliaEverywhere ? 16
            : (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        radius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
            : Appearance.zzzEverywhere ? Appearance.zzz.pillRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Math.min(width, height) / 2
        color: Appearance.regaliaEverywhere
            ? (root.checked
                ? Appearance.regalia.hardwarePrimary
                : Appearance.regalia.onMuted)
            : root.checked
                ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                    : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.colors.colOnPrimary)
                : Appearance.colors.colOutline
        border.width: Appearance.regaliaEverywhere ? 1 : 0
        border.color: Appearance.regaliaEverywhere
            ? ColorUtils.applyAlpha(root.checked ? Appearance.regalia.hardwarePrimaryInk : Appearance.regalia.onColor, 0.18)
            : "transparent"
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Appearance.regaliaEverywhere
                    ? ColorUtils.mix(thumb.color,
                        root.checked ? Appearance.regalia.hardwarePrimaryInk : Appearance.regalia.onColor, 0.96)
                    : thumb.color
            }
            GradientStop {
                position: 1
                color: Appearance.regaliaEverywhere
                    ? ColorUtils.mix(thumb.color, Appearance.m3colors.m3shadow, 0.96)
                    : thumb.color
            }
        }
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Appearance.regaliaEverywhere
            ? (root.checked ? parent.width - width - 3 : 3)
            : root.checked ? ((root.pressed || root.down) ? (22 * root.scale) : 24 * root.scale) : ((root.pressed || root.down) ? (2 * root.scale) : 8 * root.scale)

        Behavior on anchors.leftMargin {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.regaliaEverywhere ? Appearance.regalia.switchDuration : Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.regaliaEverywhere ? Appearance.animationCurves.regaliaWeighted : Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on width {
            enabled: Appearance.animationsEnabled && !Appearance.regaliaEverywhere
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled && !Appearance.regaliaEverywhere
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
}
