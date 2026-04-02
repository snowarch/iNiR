import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.services

// Elegant family transition overlay
//
// Choreography:
//   Entry  → overlay fades in + background zooms/settles + blur builds progressively
//   Hold   → exitComplete fires (panels swap underneath), brief hold for loading
//   Exit   → content recedes first, then family element, then background fades out
//
// Each family has its own visual identity:
//   Waffle  → Fluent acrylic card with decelerate curve and accent shimmer
//   Material → Ink ripple with Material emphasized curves and container badge
Scope {
    id: root

    signal exitComplete()
    signal enterComplete()

    // ── Timing ──────────────────────────────────────────────────────────
    readonly property bool _animated: Appearance.animationsEnabled
    readonly property int _entryFade: _animated ? 300 : 5
    readonly property int _enterDuration: _animated ? 380 : 5
    readonly property int _holdDuration: 200
    readonly property int _contentExitDelay: _animated ? 180 : 5
    readonly property int _exitDuration: _animated ? 380 : 5

    // ── State ───────────────────────────────────────────────────────────
    property bool _isWaffle: false
    property bool _phase: false   // false = enter/hold, true = exit
    property bool _active: false

    // ── Animated background properties ──────────────────────────────────
    property real _overlayOpacity: 0
    property real _bgScale: 1.05
    property real _blurAmount: 0

    // ── Color snapshot (frozen at transition start) ─────────────────────
    // Prevents palette shifts from affecting the overlay mid-animation.
    // Material transition colors
    property color _snapPrimaryContainer: "transparent"
    property color _snapPrimary: "transparent"
    property color _snapOnPrimaryContainer: "transparent"
    property color _snapBackground: "transparent"
    property color _snapOnSurface: "transparent"
    property bool _snapDarkmode: true
    // Waffle transition colors
    property color _snapWaffleBg0: "transparent"
    property color _snapWaffleBg1: "transparent"
    property color _snapWaffleFg: "transparent"
    property color _snapWaffleSubfg: "transparent"
    property color _snapWaffleAccent: "transparent"

    // ════════════════════════════════════════════════════════════════════
    // TRIGGER
    // ════════════════════════════════════════════════════════════════════
    Connections {
        target: GlobalStates
        function onFamilyTransitionActiveChanged() {
            if (!GlobalStates.familyTransitionActive) return

            // Cancel any running exit
            fadeOut.stop()
            bgScaleOut.stop()

            root._isWaffle = GlobalStates.familyTransitionDirection === "left"
            root._phase = false
            root._active = true

            // Snapshot colors at transition start so palette changes
            // during animation don't cause color flicker.
            root._snapPrimaryContainer = Appearance.colors.colPrimaryContainer
            root._snapPrimary = Appearance.colors.colPrimary
            root._snapOnPrimaryContainer = Appearance.colors.colOnPrimaryContainer
            root._snapBackground = Appearance.m3colors.m3background
            root._snapOnSurface = Appearance.m3colors.m3onSurface
            root._snapDarkmode = Appearance.m3colors.darkmode
            root._snapWaffleBg0 = Looks.colors.bg0
            root._snapWaffleBg1 = Looks.colors.bg1
            root._snapWaffleFg = Looks.colors.fg
            root._snapWaffleSubfg = Looks.colors.subfg
            root._snapWaffleAccent = Looks.colors.accent

            // Reset to pre-entry state
            root._overlayOpacity = 0
            root._bgScale = 1.05
            root._blurAmount = 0

            // Launch entry animations (smooth, never instant)
            fadeIn.restart()
            bgScaleIn.restart()
            blurIn.restart()
            enterTimer.start()
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // ENTRY ANIMATIONS
    // ════════════════════════════════════════════════════════════════════
    NumberAnimation {
        id: fadeIn
        target: root; property: "_overlayOpacity"
        from: 0; to: 1
        duration: root._entryFade
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: bgScaleIn
        target: root; property: "_bgScale"
        from: 1.05; to: 1.0
        duration: _animated ? 520 : 5
        easing.type: Easing.OutQuart
    }

    NumberAnimation {
        id: blurIn
        target: root; property: "_blurAmount"
        from: 0; to: 0.8
        duration: _animated ? 360 : 5
        easing.type: Easing.OutQuad
    }

    // ════════════════════════════════════════════════════════════════════
    // CHOREOGRAPHY TIMERS
    // ════════════════════════════════════════════════════════════════════
    Timer {
        id: enterTimer
        interval: root._enterDuration + 60
        onTriggered: {
            root.exitComplete()       // panels swap underneath
            holdTimer.start()
        }
    }

    Timer {
        id: holdTimer
        interval: root._holdDuration
        onTriggered: {
            root._phase = true        // triggers content exit in family components
            contentExitTimer.start()
        }
    }

    Timer {
        id: contentExitTimer
        interval: root._contentExitDelay
        onTriggered: {
            fadeOut.restart()
            bgScaleOut.restart()
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // EXIT ANIMATIONS
    // ════════════════════════════════════════════════════════════════════
    NumberAnimation {
        id: fadeOut
        target: root; property: "_overlayOpacity"
        to: 0
        duration: root._exitDuration
        easing.type: Easing.InOutCubic
        onFinished: {
            root._active = false
            root.enterComplete()
        }
    }

    NumberAnimation {
        id: bgScaleOut
        target: root; property: "_bgScale"
        to: 0.98
        duration: root._exitDuration
        easing.type: Easing.InCubic
    }

    // ════════════════════════════════════════════════════════════════════
    // OVERLAY WINDOW
    // ════════════════════════════════════════════════════════════════════
    Loader {
        active: GlobalStates.familyTransitionActive || root._active

        sourceComponent: PanelWindow {
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "quickshell:familyTransition"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            implicitWidth: screen?.width ?? 1920
            implicitHeight: screen?.height ?? 1080

            Item {
                id: content
                anchors.fill: parent
                opacity: root._overlayOpacity

                // Solid fallback behind the blur (visible while image loads)
                Rectangle {
                    anchors.fill: parent
                    color: root._isWaffle ? root._snapWaffleBg0 : root._snapBackground
                }

                // ── Blurred wallpaper with cinematic zoom ──
                Item {
                    id: blurredBg
                    anchors.fill: parent
                    scale: root._bgScale
                    transformOrigin: Item.Center

                    Image {
                        id: wallpaperImg
                        anchors.fill: parent
                        source: {
                            let path = ""
                            if (root._isWaffle) {
                                const wBg = Config.options?.waffles?.background ?? {}
                                const useMain = wBg.useMainWallpaper ?? true
                                path = useMain
                                    ? (Config.options?.background?.wallpaperPath ?? "")
                                    : (wBg.wallpaperPath ?? Config.options?.background?.wallpaperPath ?? "")
                            } else {
                                path = Config.options?.background?.wallpaperPath ?? ""
                            }
                            if (!path) return ""
                            return path.startsWith("file://") ? path : "file://" + path
                        }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaperImg
                        visible: wallpaperImg.status === Image.Ready
                        blurEnabled: Appearance.effectsEnabled
                        blur: root._blurAmount
                        blurMax: 64
                        saturation: 0.25
                    }

                    // Tint overlay — Material gets a subtle colored scrim, Waffle stays clean
                    Rectangle {
                        anchors.fill: parent
                        color: root._snapBackground
                        opacity: root._isWaffle ? 0.08 : 0.28
                    }
                }

                // ── Subtle vignette for depth ──
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.45; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.15) }
                    }
                }

                // ── Family-specific transition effect ──
                Loader {
                    anchors.fill: parent
                    sourceComponent: root._isWaffle ? waffleTransition : materialTransition
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // WAFFLE — Fluent acrylic card reveal
    //
    // A translucent card scales up from center with the Fluent Design
    // decelerate curve, content staggers in, accent shimmer at bottom.
    // ════════════════════════════════════════════════════════════════════
    Component {
        id: waffleTransition

        Item {
            id: waffleRoot
            anchors.fill: parent

            property bool expanded: false
            property bool showIcon: false
            property bool showText: false
            property bool showAccent: false

            Component.onCompleted: Qt.callLater(() => expanded = true)

            // Staggered content reveal
            Timer { interval: 160; running: waffleRoot.expanded; onTriggered: waffleRoot.showIcon = true }
            Timer { interval: 240; running: waffleRoot.expanded; onTriggered: waffleRoot.showText = true }
            Timer { interval: 320; running: waffleRoot.expanded; onTriggered: waffleRoot.showAccent = true }

            // ── Acrylic card ──
            Rectangle {
                id: acrylicCard
                anchors.centerIn: parent
                width: 260
                height: 180
                radius: Looks.radius.xLarge
                color: ColorUtils.transparentize(root._snapWaffleBg1, 0.15)
                border.width: 1
                border.color: ColorUtils.transparentize(root._snapWaffleFg, 0.9)

                opacity: root._phase ? 0 : (waffleRoot.expanded ? 1 : 0)
                scale: root._phase ? 0.92 : (waffleRoot.expanded ? 1 : 0.82)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root._phase ? 200 : 280
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Looks.transition.easing.bezierCurve.accelerate
                            : Looks.transition.easing.bezierCurve.decelerate
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._phase ? 220 : 340
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Looks.transition.easing.bezierCurve.accelerate
                            : Looks.transition.easing.bezierCurve.decelerate
                    }
                }

                // Accent shimmer line
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: waffleRoot.showAccent && !root._phase ? 48 : 0
                    height: 2.5
                    radius: 1.25
                    color: root._snapWaffleAccent
                    opacity: root._phase ? 0 : 1

                    Behavior on width {
                        NumberAnimation {
                            duration: root._phase ? 120 : 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            // ── Icon ──
            Image {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -22
                width: 48
                height: 48
                source: `${Looks.iconsPath}/start-here.svg`
                sourceSize: Qt.size(48, 48)
                opacity: root._phase ? 0 : (waffleRoot.showIcon ? 1 : 0)
                scale: root._phase ? 0.9 : (waffleRoot.showIcon ? 1 : 0.7)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root._phase ? 120 : 240
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._phase ? 140 : 300
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }
                }

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    colorization: 1.0
                    colorizationColor: root._snapWaffleFg
                }
            }

            // ── Text group ──
            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 32
                spacing: 3
                opacity: root._phase ? 0 : (waffleRoot.showText ? 1 : 0)
                scale: root._phase ? 0.95 : (waffleRoot.showText ? 1 : 0.92)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root._phase ? 100 : 220
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._phase ? 120 : 260
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Waffle"
                    font.pixelSize: 19
                    font.family: Looks.font.family.ui
                    font.weight: Font.DemiBold
                    color: root._snapWaffleFg
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Windows 11 Style"
                    font.pixelSize: Looks.font.pixelSize.small
                    font.family: Looks.font.family.ui
                    color: root._snapWaffleSubfg
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MATERIAL II — Ink ripple expansion
    //
    // A primary-colored ink circle expands from center using the
    // Material emphasized deceleration curve. Container badge and
    // text stagger in. Exit reverses with accelerate curve.
    // ════════════════════════════════════════════════════════════════════
    Component {
        id: materialTransition

        Item {
            id: materialRoot
            anchors.fill: parent

            readonly property real maxRadius: Math.sqrt(width * width + height * height) / 2 + 80
            property bool expanded: false
            property bool showBadge: false
            property bool showSubtext: false

            Component.onCompleted: Qt.callLater(() => expanded = true)

            // Staggered content reveal
            Timer { interval: 180; running: materialRoot.expanded; onTriggered: materialRoot.showBadge = true }
            Timer { interval: 280; running: materialRoot.expanded; onTriggered: materialRoot.showSubtext = true }

            // ── Primary ink ripple ──
            Rectangle {
                anchors.centerIn: parent
                width: materialRoot.expanded && !root._phase ? materialRoot.maxRadius * 2 : 0
                height: width
                radius: width / 2
                color: ColorUtils.transparentize(root._snapPrimaryContainer, 0.45)
                opacity: root._phase ? 0 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: root._phase ? (root._exitDuration * 0.6) : root._enterDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Appearance.animationCurves.emphasizedAccel
                            : Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: root._exitDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }

            // ── Secondary ring (subtle, trailing) ──
            Rectangle {
                anchors.centerIn: parent
                width: materialRoot.expanded && !root._phase ? materialRoot.maxRadius * 2.05 : 0
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1.5
                border.color: ColorUtils.transparentize(root._snapPrimary, 0.78)
                opacity: root._phase ? 0 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: root._phase ? (root._exitDuration * 0.5) : (root._enterDuration + 100)
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Appearance.animationCurves.emphasizedAccel
                            : Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on opacity { NumberAnimation { duration: root._exitDuration * 0.7 } }
            }

            // ── Container badge ──
            Rectangle {
                id: badge
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -26
                width: 68
                height: 68
                radius: 34
                color: root._snapPrimaryContainer

                opacity: root._phase ? 0 : (materialRoot.showBadge ? 1 : 0)
                scale: root._phase ? 0.85 : (materialRoot.showBadge ? 1 : 0.6)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root._phase ? 160 : 280
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Appearance.animationCurves.emphasizedAccel
                            : Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._phase ? 180 : 350
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Appearance.animationCurves.emphasizedAccel
                            : Appearance.animationCurves.emphasizedDecel
                    }
                }

                // Logo shown at native colors — SVG has dark bg + teal gradients,
                // MultiEffect colorization makes it a muddy blob at this size
                Image {
                    anchors.centerIn: parent
                    width: 40
                    height: 40
                    source: Qt.resolvedUrl("assets/icons/illogical-impulse.svg")
                    sourceSize: Qt.size(40, 40)
                }
            }

            // ── Text ──
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 38
                text: "Material"
                font.pixelSize: Appearance.font.pixelSize.larger
                font.family: Appearance.font.family.main
                font.weight: Font.Normal
                color: root._snapOnSurface

                opacity: root._phase ? 0 : (materialRoot.showSubtext ? 1 : 0)
                scale: root._phase ? 0.92 : (materialRoot.showSubtext ? 1 : 0.85)

                Behavior on opacity {
                    NumberAnimation {
                        duration: root._phase ? 140 : 260
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root._phase ? 160 : 320
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._phase
                            ? Appearance.animationCurves.emphasizedAccel
                            : Appearance.animationCurves.emphasizedDecel
                    }
                }

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root._snapDarkmode ? "#40000000" : "#40FFFFFF"
                    shadowBlur: 0.6
                    shadowVerticalOffset: 1
                }
            }
        }
    }
}
