pragma ComponentBehavior: Bound

import qs.modules.common
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
    implicitHeight: 32 * root.scale
    implicitWidth: 52 * root.scale
    property color activeColor: Appearance.zzzEverywhere
        ? Appearance.zzz.sticker : Appearance.colors.colPrimary
    property color inactiveColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer2
        : Appearance.colors.colSurfaceContainerHighest

    PointingHandInteraction {}

    // Custom track styling
    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : (Appearance?.rounding.full ?? 9999)
        color: root.checked ? root.activeColor : root.inactiveColor
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.hairlineThick : 2 * root.scale
        border.color: root.checked
            ? root.activeColor
            : (Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : Appearance.colors.colOutline)

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
        width: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        height: (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        radius: Appearance.zzzEverywhere ? Appearance.zzz.pillRadius
            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Math.min(width, height) / 2
        color: root.checked
            ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                : Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                : Appearance.colors.colOnPrimary)
            : Appearance.colors.colOutline
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.checked ? ((root.pressed || root.down) ? (22 * root.scale) : 24 * root.scale) : ((root.pressed || root.down) ? (2 * root.scale) : 8 * root.scale)

        Behavior on anchors.leftMargin {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on height {
            enabled: Appearance.animationsEnabled
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
