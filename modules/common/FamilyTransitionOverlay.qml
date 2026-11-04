import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
// Elegant family transition overlay
//
// Choreography, the same swap a switch without animation does plus a curtain around it:
//   Entry  → the curtain fades in over a blur drawn once, so no frame of it pays for the blur
//   Hold   → exitComplete fires (panels swap underneath) and it holds exactly until the family stands
//   Exit   → the family's mark recedes, then the curtain fades out
//
// Each family has its own visual identity:
//   Waffle  → Fluent acrylic card with decelerate curve and accent shimmer
//   Material → Ink ripple with Material emphasized curves and container badge
//   iRiS    → Minimal optical mark with restrained type over a light blur
Scope {
    id: root

    signal exitComplete()
    signal enterComplete()

    // ── Timing ──────────────────────────────────────────────────────────
    readonly property bool _animated: Appearance.animationsEnabled
    readonly property int _entryFade: _animated ? 130 : 5
    readonly property int _enterDuration: _animated ? 150 : 5
    readonly property int _holdDuration: 50
    readonly property int _contentExitDelay: _animated ? 70 : 5
    readonly property int _exitDuration: _animated ? 210 : 5

    // ── State ───────────────────────────────────────────────────────────
    // The target family's own transition (its part `familyTransition`), Material's ink ripple otherwise. It may say
    // how much the wallpaper blurs (`blur`) and is tinted (`tint`), the plate behind it (`plate`) and its own wallpaper.
    property Item _familyPart: null
    property string _targetFamily: "ii"
    property bool _phase: false   // false = enter/hold, true = exit
    property bool _active: false
    // The new family is still being built under the curtain (shell.qml binds it): the hold lasts until it stands.
    property bool swapPending: false
    property int _holdWaits: 0

    // ── Animated background properties ──────────────────────────────────
    property real _overlayOpacity: 0
    property real _bgScale: 1.02

    // ── Color snapshot (frozen at transition start) ─────────────────────
    // Prevents palette shifts from affecting the overlay mid-animation.
    // Material transition colors
    property color _snapPrimaryContainer: "transparent"
    property color _snapPrimary: "transparent"
    property color _snapOnPrimaryContainer: "transparent"
    property color _snapBackground: "transparent"
    property color _snapOnSurface: "transparent"
    property bool _snapDarkmode: true

    // ════════════════════════════════════════════════════════════════════
    // TRIGGER
    // ════════════════════════════════════════════════════════════════════
    Connections {
        target: GlobalStates
        function onFamilyTransitionActiveChanged() {
            if (!GlobalStates.familyTransitionActive) return
            root._beginTransition()
        }
    }

    // Applying the family writes panelFamily to config, and Config's own
    // FileView watch turns that write into a full configuration reload — the
    // whole root object, this overlay included, is rebuilt mid-transition.
    // GlobalStates is a singleton and survives that, so the replacement is born
    // with familyTransitionActive already true and never sees the change signal:
    // no timer starts, fadeOut never runs, enterComplete never fires, and a
    // fullscreen WlrKeyboardFocus.Exclusive window stays up forever. That is the
    // freeze that forces a TTY. Arm on construction too.
    Component.onCompleted: if (GlobalStates.familyTransitionActive) root._beginTransition()

    // Nothing may hold exclusive keyboard focus on a timer chain alone. If the
    // choreography has not finished well past its own worst case, tear the
    // overlay down and hand input back rather than trap the session.
    Timer {
        id: watchdog
        interval: root._entryFade + root._enterDuration + root._holdDuration
            + root._contentExitDelay + root._exitDuration + 5500
        onTriggered: {
            if (!root._active && !GlobalStates.familyTransitionActive) return
            console.warn("[FamilyTransition] watchdog fired — releasing the overlay")
            root._forceFinish()
        }
    }

    function _forceFinish(): void {
        enterTimer.stop(); holdTimer.stop(); contentExitTimer.stop()
        fadeIn.stop(); bgScaleIn.stop()
        fadeOut.stop(); bgScaleOut.stop()
        watchdog.stop()
        // exitComplete may not have run yet; the family still has to be applied.
        root.exitComplete()
        root._overlayOpacity = 0
        root._active = false
        root.enterComplete()
    }

    function _beginTransition(): void {
            watchdog.restart()

            // Side effect kept out of the source binding: make sure the still
            // for a video/GIF wallpaper exists before the overlay asks for it.
            const wp = Config.options?.background?.wallpaperPath ?? ""
            if (wp)
                Wallpapers.ensureVideoFirstFrame(FileUtils.trimFileProtocol(wp))

            // Cancel any running exit
            fadeOut.stop()
            bgScaleOut.stop()

            root._targetFamily = GlobalStates.familyTransitionTarget || "ii"
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

            // Reset to pre-entry state
            root._overlayOpacity = 0
            root._bgScale = 1.02

            fadeIn.restart()
            bgScaleIn.restart()
            enterTimer.start()
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
        from: 1.02; to: 1.0
        duration: root._entryFade + root._enterDuration
        easing.type: Easing.OutCubic
    }

    // ════════════════════════════════════════════════════════════════════
    // CHOREOGRAPHY TIMERS
    // ════════════════════════════════════════════════════════════════════
    Timer {
        id: enterTimer
        interval: root._enterDuration
        onTriggered: {
            root.exitComplete()       // panels swap underneath
            holdTimer.start()
        }
    }

    Timer {
        id: holdTimer
        interval: root._holdDuration
        onTriggered: {
            // a first visit compiles the family under the curtain (~1.5 s for iRiS); lifting on a fixed 200 ms showed
            // its panels building in the reveal. Capped at 2.5 s more, under the watchdog.
            if (root.swapPending && root._holdWaits++ < 50) {
                holdTimer.restart()
                return
            }
            root._holdWaits = 0
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
        to: 0.99
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
                    color: root._familyPart?.plate ?? root._snapBackground
                }

                // ── Blurred wallpaper with cinematic zoom ──
                Item {
                    id: blurredBg
                    anchors.fill: parent
                    scale: root._bgScale
                    transformOrigin: Item.Center
                    // Drawn once and moved as a texture: a full screen blur every frame is what made the curtain crawl
                    // on an integrated GPU, with the new family building on the same thread.
                    layer.enabled: true

                    Image {
                        id: wallpaperImg
                        anchors.fill: parent
                        source: {
                            const path = root._familyPart?.wallpaperPath ?? (Config.options?.background?.wallpaperPath ?? "")
                            if (!path) return ""
                            // Image cannot decode a video, so a video wallpaper
                            // used to log "Formato de imagen no soportado" and
                            // leave the overlay on its flat plate. Use the still
                            // the thumbnail service already keeps for exactly
                            // these files, and ask for it if it is not there yet.
                            // Pure: generating the thumbnail from in here mutated
                            // state this same binding reads and Qt flagged a
                            // binding loop. _beginTransition() requests it.
                            // The full-size first frame, not the 256 px thumbnail still: iRiS
                            // barely blurs it, and a stretched thumbnail read as pixelated.
                            if (/\.(mp4|webm|mkv|avi|mov)$/i.test(path))
                                return Wallpapers.stillUrlFor(path)
                            return path.startsWith("file://") ? path : "file://" + path
                        }
                        fillMode: Image.PreserveAspectCrop
                        // Decoded at the output's size: a 4K frame never becomes a 4K texture.
                        sourceSize: Qt.size(Math.ceil(Screen.width * Screen.devicePixelRatio), Math.ceil(Screen.height * Screen.devicePixelRatio))
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: wallpaperImg
                        visible: wallpaperImg.status === Image.Ready
                        blurEnabled: Appearance.effectsEnabled
                        // The family's own depth; its part may arrive after the first frame.
                        blur: root._familyPart?.blur ?? 0.8
                        blurMax: 64
                        saturation: 0.25
                    }

                    // Tint overlay — Material gets a subtle colored scrim, Waffle stays clean
                    Rectangle {
                        anchors.fill: parent
                        color: root._snapBackground
                        opacity: root._familyPart?.tint ?? 0.28
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
                FamilyPart {
                    id: familyTransition
                    anchors.fill: parent
                    family: root._targetFamily
                    part: "familyTransition"
                    props: ({ overlay: root })
                    onItemChanged: root._familyPart = item
                }
                Loader {
                    anchors.fill: parent
                    active: familyTransition.url.length === 0
                    sourceComponent: materialTransition
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
