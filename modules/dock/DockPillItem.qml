import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell.Widgets

// Pill-style background for a single dock icon.
// Minimalist design: translucent background only on focused/active apps.
// Renders smart window-count indicators matching the panel style (flat pill dots).
Item {
    id: root

    property bool appIsActive: false
    property bool hasWindows: false
    property bool isPillStyle: true
    property string surfaceDialect: Appearance.surfaceDialectFor("")
    readonly property bool zzzStyle: surfaceDialect === "zzz"
    readonly property bool angelStyle: surfaceDialect === "angel"
    readonly property bool inirStyle: surfaceDialect === "inir"
    readonly property bool auroraStyle: surfaceDialect === "aurora" || angelStyle
    property int  windowCount: 1
    property int  focusedWindowIndex: 0
    property bool vertical: false
    property real countDotWidth: 10
    property real countDotHeight: 4
    property int  maxDots: Config.options?.dock?.maxIndicatorDots ?? 5

    // Standard rounding - not a full circle
    readonly property real pillRadius: root.zzzStyle ? Appearance.zzz.controlRadius
                                      : root.angelStyle ? Appearance.angel.roundingSmall
                                      : root.inirStyle ? Appearance.inir.roundingSmall
                                      : Appearance.rounding.small

    // Background only visible when app is active/focused - translucent and aesthetic
    readonly property color _pillBg: {
        if (!appIsActive) return "transparent"
        if (root.zzzStyle) return Appearance.zzz.bg2
        if (root.angelStyle) return ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.35)
        if (root.inirStyle) return ColorUtils.transparentize(Appearance.inir.colLayer2, 0.45)
        if (root.auroraStyle) return ColorUtils.transparentize(Appearance.aurora.colSubSurface, 0.4)
        return ColorUtils.transparentize(Appearance.colors.colLayer1, 0.45)
    }

    // Border only on active apps - very subtle
    readonly property color _pillBorder: {
        if (!appIsActive) return "transparent"
        if (root.zzzStyle) return Appearance.zzz.hairlineStrong
        if (root.angelStyle) return ColorUtils.transparentize(Appearance.angel.colBorder, 0.5)
        if (root.inirStyle) return ColorUtils.transparentize(Appearance.inir.colBorderAccent, 0.55)
        if (root.auroraStyle) return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
        return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.65)
    }

    readonly property real _pillBorderWidth: appIsActive ? 1 : 0

    // Smart window-count indicators — same visual language as panel mode (flat pill dots).
    // Shows one dot per open window (up to maxDots). The focused window's dot is wider
    // and uses the accent color; others are dimmed.
    // Config options — hoisted for reuse across repeater and fallback
    property bool smartIndicator: Config.options?.dock?.smartIndicator !== false
    property bool showAllDots: Config.options?.dock?.showAllWindowDots !== false

    Row {
        id: indicatorRow
        opacity: (root.hasWindows && !Appearance.gameModeMinimal) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        spacing: 3
        // Always below the icon, centered — matches Panel mode positioning
        anchors {
            bottom: parent.bottom
            bottomMargin: 2
            horizontalCenter: parent.horizontalCenter
        }

        Repeater {
            model: {
                const showAll = root.showAllDots
                const max = root.maxDots
                if (root.appIsActive || showAll)
                    return Math.min(root.windowCount, max)
                return 0
            }

            delegate: Rectangle {
                required property int index

                property bool isFocused: {
                    if (!root.appIsActive) return false
                    if (!root.smartIndicator) return true
                    if (root.windowCount <= 1) return true
                    return index === root.focusedWindowIndex
                }

                // Unfocused: circle (dotHeight+2 × dotHeight+2), focused: pill (dotWidth × dotHeight)
                // Both dimensions animate simultaneously → SecondHand-style squish morph
                radius: (root.angelStyle || root.zzzStyle) ? 0 : Math.min(width, height) / 2
                implicitWidth: (root.angelStyle || root.zzzStyle)
                    ? (isFocused ? 14 : 6)
                    : (isFocused ? root.countDotWidth : root.countDotHeight + 2)
                implicitHeight: (root.angelStyle || root.zzzStyle) ? 2 : (isFocused ? root.countDotHeight : root.countDotHeight + 2)
                color: isFocused
                    ? (root.zzzStyle ? Appearance.zzz.accent
                     : root.angelStyle ? Appearance.angel.colPrimary
                     : root.inirStyle ? Appearance.inir.colPrimary
                     : Appearance.colors.colPrimary)
                    : ColorUtils.transparentize(
                        root.zzzStyle ? Appearance.zzz.ghostInk
                      : root.angelStyle ? Appearance.angel.colTextSecondary
                      : root.inirStyle ? Appearance.inir.colText
                      : Appearance.colors.colOnLayer0, 0.5)

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on implicitHeight {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }

        // Fallback: single dim dot when showAllDots is off and app is inactive
        Rectangle {
            opacity: (!root.appIsActive && root.hasWindows && !root.showAllDots) ? 1 : 0
            visible: opacity > 0
            width: (root.angelStyle || root.zzzStyle) ? 6 : 5
            height: (root.angelStyle || root.zzzStyle) ? 2 : 5
            radius: (root.angelStyle || root.zzzStyle) ? 0 : Math.min(width, height) / 2
            color: ColorUtils.transparentize(
                root.zzzStyle ? Appearance.zzz.ghostInk
              : root.angelStyle ? Appearance.angel.colTextSecondary
              : root.inirStyle ? Appearance.inir.colText
              : Appearance.colors.colOnLayer0, 0.5)

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    // Background rectangle - only visible on active apps
    Rectangle {
        id: pillRect
        anchors.fill: parent
        radius: parent.pillRadius
        color: root._pillBg
        border.width: root._pillBorderWidth
        border.color: root._pillBorder
        visible: opacity > 0
        opacity: root.appIsActive ? 1 : 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        AngelPartialBorder {
            opacity: root.angelStyle ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            targetRadius: pillRect.radius
        }
    }
}
