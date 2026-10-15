import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick

// macOS-style dock icon overlay.
// Responsibilities:
//   • Exposes `iconScale` — DockAppButton's contentItem binds its scale to this.
//   • Renders a single indicator dot anchored to the shelf base (never magnifies).
//   • Provides clickPulse() for the micro-bounce on click.
//
// Architecture: this Item fills DockAppButton (anchors.fill: parent).
// It draws nothing except the indicator dot.
// The actual icon image lives in DockAppButton.contentItem and reads `iconScale`.

Item {
    id: root

    // ─── Inputs ──────────────────────────────────────────────────────────
    property bool appIsActive:      false
    property bool hasWindows:       false
    property string surfaceDialect: Appearance.surfaceDialectFor("")
    readonly property bool angelStyle: surfaceDialect === "angel"
    readonly property bool inirStyle: surfaceDialect === "inir"
    property bool buttonHovered:    false
    property bool previewVisible:   false  // Keep hover active while preview is shown
    property bool vertical:         false
    property int  neighborDistance: 99   // 0=self, 1=adjacent, 2=next-to-adjacent, 99=none
    property int  windowCount:      1
    property int  focusedWindowIndex: 0
    property int  maxDots: Config.options?.dock?.maxIndicatorDots ?? 5

    // Effective hover: true if button hovered OR its preview is visible
    readonly property bool effectiveHovered: buttonHovered || previewVisible

    // ─── Public output — DockAppButton.contentItem binds to this ─────────
    readonly property real iconScale: _magnifyScale * _pulseScale

    // ─── Click pulse ──────────────────────────────────────────────────────
    function clickPulse() { pulseAnim.restart() }

    // ─── Magnify scale ────────────────────────────────────────────────────
    // Reduced by 30% from original (1.40→1.28, 1.22→1.15, 1.10→1.07)
    readonly property real _magnifyTarget: {
        if (effectiveHovered)      return 1.28
        if (neighborDistance <= 1) return 1.15
        if (neighborDistance <= 2) return 1.07
        return 1.0
    }

    // Reactive binding — _magnifyScale follows _magnifyTarget automatically.
    // This avoids the bug where imperative assignment in onXChanged handlers
    // could leave _magnifyScale stuck at the wrong value after rapid hover changes.
    property real _magnifyScale: _magnifyTarget

    Behavior on _magnifyScale {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration:      root._magnifyScale >= 1.0 ? 300 : 220
            easing.type:   root._magnifyScale >= 1.0 ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.55
        }
    }

    // ─── Pulse scale ─────────────────────────────────────────────────────
    property real _pulseScale: 1.0

    SequentialAnimation {
        id: pulseAnim
        running: Appearance.animationsEnabled
        NumberAnimation {
            target: root; property: "_pulseScale"
            to: 0.88; duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            target: root; property: "_pulseScale"
            to: 1.0; duration: Appearance.animation.clickBounce.duration
            easing.type: Appearance.animation.clickBounce.type
            easing.bezierCurve: Appearance.animation.clickBounce.bezierCurve
        }
    }

    // ─── Indicator dots ──────────────────────────────────────────────────
    // Anchored to the bottom of the button — never moves with magnify.
    // Uses the same visual language as panel mode: focused dot is wider
    // and uses accent color; others are narrow and dimmed.
    Row {
        id: indicatorRow
        opacity: root.hasWindows ? 1 : 0
        visible: opacity > 0
        scale: root.hasWindows ? 1 : 0
        spacing: 3
        // Always below the icon, centered — matches Panel mode positioning
        anchors {
            bottom: parent.bottom
            bottomMargin: 3
            horizontalCenter: parent.horizontalCenter
        }

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        // Config options — same as panel mode
        property bool smartIndicator: Config.options?.dock?.smartIndicator !== false
        property bool showAllDots: Config.options?.dock?.showAllWindowDots !== false

        Repeater {
            model: {
                const showAll = indicatorRow.showAllDots
                const max = root.maxDots
                if (root.appIsActive || showAll)
                    return Math.min(root.windowCount, max)
                return 0
            }

            delegate: Rectangle {
                required property int index

                property bool isFocused: {
                    if (!root.appIsActive) return false
                    if (!indicatorRow.smartIndicator) return true
                    if (root.windowCount <= 1) return true
                    return index === root.focusedWindowIndex
                }

                radius: root.angelStyle ? 0 : Math.min(width, height) / 2
                implicitWidth: root.angelStyle
                    ? (isFocused ? 14 : 6)
                    : (isFocused ? 10 : 4)
                implicitHeight: root.angelStyle ? 2 : 4
                color: isFocused
                    ? (root.angelStyle ? Appearance.angel.colPrimary
                     : root.inirStyle ? Appearance.inir.colPrimary
                     : Appearance.colors.colPrimary)
                    : ColorUtils.transparentize(
                        root.angelStyle ? Appearance.angel.colTextSecondary
                      : root.inirStyle ? Appearance.inir.colText
                      : Appearance.colors.colOnLayer0, 0.5)

                Behavior on implicitWidth {
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
            opacity: !root.appIsActive && root.hasWindows && !indicatorRow.showAllDots ? 1 : 0
            visible: opacity > 0
            width: root.angelStyle ? 6 : 5
            height: root.angelStyle ? 2 : 5
            radius: root.angelStyle ? 0 : Math.min(width, height) / 2
            color: ColorUtils.transparentize(
                root.angelStyle ? Appearance.angel.colTextSecondary
              : root.inirStyle ? Appearance.inir.colText
              : Appearance.colors.colOnLayer0, 0.5)

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }
}
