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
    property int  windowCount: 1
    property int  focusedWindowIndex: 0
    property bool vertical: false
    property real countDotWidth: 10
    property real countDotHeight: 4
    property int  maxDots: Config.options?.dock?.maxIndicatorDots ?? 5

    // Standard rounding - not a full circle
    readonly property real pillRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                      : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                      : Appearance.rounding.small

    // Background only visible when app is active/focused - translucent and aesthetic
    readonly property color _pillBg: {
        if (!appIsActive) return "transparent"
        // Active app: subtle translucent background
        if (Appearance.angelEverywhere) return ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.35)
        if (Appearance.inirEverywhere) return ColorUtils.transparentize(Appearance.inir.colLayer2, 0.45)
        if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.aurora.colSubSurface, 0.4)
        return ColorUtils.transparentize(Appearance.colors.colLayer1, 0.45)
    }

    // Border only on active apps - very subtle
    readonly property color _pillBorder: {
        if (!appIsActive) return "transparent"
        if (Appearance.angelEverywhere) return ColorUtils.transparentize(Appearance.angel.colBorder, 0.5)
        if (Appearance.inirEverywhere) return ColorUtils.transparentize(Appearance.inir.colBorderAccent, 0.55)
        if (Appearance.auroraEverywhere) return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
        return ColorUtils.transparentize(Appearance.colors.colPrimary, 0.65)
    }

    readonly property real _pillBorderWidth: appIsActive ? 1 : 0

    // Smart window-count indicators — same visual language as panel mode (flat pill dots).
    // Shows one dot per open window (up to maxDots). The focused window's dot is wider
    // and uses the accent color; others are dimmed.
    Row {
        id: indicatorRow
        visible: root.hasWindows && !Appearance.gameModeMinimal
        spacing: 3
        anchors {
            bottom: parent.bottom
            bottomMargin: root.vertical ? 0 : 2
            horizontalCenter: !root.vertical ? parent.horizontalCenter : undefined
            verticalCenter: root.vertical ? parent.verticalCenter : undefined
            right: root.vertical ? parent.right : undefined
            rightMargin: root.vertical ? 2 : 0
        }

        Repeater {
            model: {
                const showAll = Config.options?.dock?.showAllWindowDots !== false
                const max = root.maxDots
                if (root.appIsActive || showAll)
                    return Math.min(root.windowCount, max)
                return 0
            }

            delegate: Rectangle {
                required property int index

                property bool isFocused: {
                    if (!root.appIsActive) return false
                    if (!(Config.options?.dock?.smartIndicator !== false)) return true
                    if (root.windowCount <= 1) return true
                    return index === root.focusedWindowIndex
                }

                radius: Appearance.angelEverywhere ? 0 : Appearance.rounding.full
                implicitWidth: Appearance.angelEverywhere
                    ? (isFocused ? 14 : 6)
                    : (isFocused ? root.countDotWidth : root.countDotHeight)
                implicitHeight: Appearance.angelEverywhere ? 2 : root.countDotHeight
                color: isFocused
                    ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                     : Appearance.inirEverywhere  ? Appearance.inir.colPrimary
                     : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                     : Appearance.colors.colPrimary)
                    : ColorUtils.transparentize(
                        Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                      : Appearance.inirEverywhere  ? Appearance.inir.colText
                      : Appearance.colors.colOnLayer0, 0.5)

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }

        // Fallback: single dim dot when showAllDots is off and app is inactive
        Rectangle {
            visible: !root.appIsActive && root.hasWindows && Config.options?.dock?.showAllWindowDots === false
            width:  Appearance.angelEverywhere ? 6 : 5
            height: Appearance.angelEverywhere ? 2 : 5
            radius: Appearance.angelEverywhere ? 0 : 2.5
            color: ColorUtils.transparentize(
                Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
              : Appearance.inirEverywhere  ? Appearance.inir.colText
              : Appearance.colors.colOnLayer0, 0.5)
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
        visible: root.appIsActive
        opacity: root.appIsActive ? 1 : 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        AngelPartialBorder {
            visible: Appearance.angelEverywhere
            targetRadius: pillRect.radius
        }
    }
}
