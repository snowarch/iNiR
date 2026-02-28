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
        NumberAnimation {
            target: root; property: "_pulseScale"
            to: 0.88; duration: 70
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root; property: "_pulseScale"
            to: 1.0; duration: 260
            easing.type: Easing.OutBack; easing.overshoot: 0.5
        }
    }

    // ─── Indicator dots ──────────────────────────────────────────────────
    // Anchored to the bottom of the button — never moves with magnify.
    // Shows one dot per open window (up to maxDots). Focused window dot uses
    // accent color at full opacity; others are dimmed.
    Row {
        id: indicatorRow
        visible: root.hasWindows
        spacing: 3

        anchors {
            bottom:           parent.bottom
            bottomMargin:     root.vertical ? 0 : 3
            horizontalCenter: !root.vertical ? parent.horizontalCenter : undefined
            verticalCenter:   root.vertical  ? parent.verticalCenter   : undefined
            right:            root.vertical  ? parent.right            : undefined
            rightMargin:      root.vertical  ? 2                       : 0
        }

        Repeater {
            model: {
                const showAll = Config.options?.dock?.showAllWindowDots !== false
                const max = root.maxDots
                if (root.appIsActive || showAll)
                    return Math.min(root.windowCount, max)
                // App has windows but is not focused and showAll is off — show one dim dot
                return 1
            }

            delegate: Rectangle {
                required property int index

                property bool isFocused: {
                    if (!root.appIsActive) return false
                    if (!(Config.options?.dock?.smartIndicator !== false)) return true
                    if (root.windowCount <= 1) return true
                    return index === root.focusedWindowIndex
                }

                width:  5
                height: 5
                radius: Appearance.rounding.full

                color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                     : Appearance.inirEverywhere  ? Appearance.inir.colPrimary
                     : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.15)
                     : Appearance.colors.colOnLayer0

                // Focused window: full opacity; other windows: dim; inactive: very dim
                opacity: isFocused ? 1.0 : (root.appIsActive ? 0.38 : 0.25)

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
