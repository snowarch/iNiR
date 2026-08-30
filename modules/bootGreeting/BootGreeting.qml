pragma ComponentBehavior: Bound
import qs
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root

    // Config shortcuts
    readonly property int autoDismissDelay: Config.options?.bootGreeting?.autoDismissDelay ?? 5000
    readonly property bool showWeather: (Config.options?.bootGreeting?.showWeather ?? true) && Weather.enabled && (Weather.data?.temp ?? "") !== ""
    readonly property bool showDate: Config.options?.bootGreeting?.showDate ?? true

    // Greeting based on time of day
    readonly property string greeting: {
        const hour = new Date().getHours()
        if (hour < 6) return Translation.tr("Good night")
        if (hour < 12) return Translation.tr("Good morning")
        if (hour < 18) return Translation.tr("Good afternoon")
        return Translation.tr("Good evening")
    }

    // Wallpaper
    readonly property string wallpaperPath: Config.options?.background?.wallpaperPath ?? ""
    readonly property bool wallpaperIsVideo: WallpaperListener.isVideoPath(wallpaperPath)
    readonly property string wallpaperPreviewPath: {
        if (!wallpaperIsVideo)
            return wallpaperPath
        const cachedFrame = Wallpapers.getVideoFirstFramePath(wallpaperPath)
        if (cachedFrame.length > 0)
            return cachedFrame
        return Config.options?.background?.thumbnailPath ?? ""
    }

    Component.onCompleted: {
        if (wallpaperIsVideo)
            Wallpapers.ensureVideoFirstFrame(wallpaperPath)
        if (GlobalStates.bootGreetingOpen)
            root.beginEntrance()
    }
    onWallpaperPathChanged: {
        if (wallpaperIsVideo)
            Wallpapers.ensureVideoFirstFrame(wallpaperPath)
    }

    // ── Organic morphing: entrance cascade state ──
    property int _cascade: 0
    property bool _visible: false
    property bool _panelVisible: false  // stays true until cleanup finishes (covers exit animation)
    property bool _dismissing: false

    Timer {
        id: cascadeTimer
        interval: 80
        repeat: true
        onTriggered: {
            if (root._cascade < 5) {
                root._cascade++
            } else {
                cascadeTimer.stop()
            }
        }
    }

    Timer {
        id: autoDismissTimer
        interval: root.autoDismissDelay
        repeat: false
        onTriggered: root.dismiss()
    }

    function beginEntrance(): void {
        if (root._panelVisible && root._visible)
            return
        root._panelVisible = true
        root._visible = true
        root._cascade = 0
        root._dismissing = false
        // Start cascade after a brief frame to let the scrim morph in.
        Qt.callLater(() => cascadeTimer.start())
        autoDismissTimer.start()
    }

    // Begin entrance when greeting opens. Component.onCompleted mirrors this
    // state so an async loader cannot miss an earlier bootGreetingOpen change.
    Connections {
        target: GlobalStates
        function onBootGreetingOpenChanged() {
            if (GlobalStates.bootGreetingOpen)
                root.beginEntrance()
        }
    }

    function dismiss(): void {
        if (root._dismissing) return
        root._dismissing = true
        autoDismissTimer.stop()
        // Reverse: cascade collapses, then scrim fades
        root._cascade = 0
        _exitTimer.start()
    }

    Timer {
        id: _exitTimer
        interval: Appearance.animationsEnabled ? 500 : 0
        repeat: false
        onTriggered: {
            root._visible = false
            // Let the scrim fade finish before cleaning up
            _cleanupTimer.start()
        }
    }

    Timer {
        id: _cleanupTimer
        interval: Appearance.animationsEnabled ? 350 : 0
        repeat: false
        onTriggered: {
            root._panelVisible = false
            GlobalStates.bootGreetingOpen = false
            GlobalStates.bootGreetingDone = true
        }
    }

    PanelWindow {
        id: greetingPanel
        visible: root._panelVisible
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:boot-greeting"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root._visible && !root._dismissing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        screen: GlobalStates.primaryScreen
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080

        // ── Scrim: blurred wallpaper + darken ──
        Item {
            id: scrim
            anchors.fill: parent
            opacity: root._visible ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Easing.OutCubic
                }
            }

            readonly property int blurOverflow: 64

            Item {
                id: blurSource
                anchors.fill: parent
                anchors.margins: -scrim.blurOverflow

                Image {
                    anchors.fill: parent
                    anchors.margins: scrim.blurOverflow
                    source: root.wallpaperPreviewPath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: greetingPanel.implicitWidth
                    sourceSize.height: greetingPanel.implicitHeight
                }
            }

            MultiEffect {
                source: blurSource
                anchors.fill: parent
                anchors.margins: -scrim.blurOverflow
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1.0 : 0
                saturation: Appearance.effectsEnabled ? 0.1 : 0
            }

            // Dark scrim overlay
            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: 0.5
            }

            // Subtle vignette
            GE.RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.55; color: "transparent" }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.4) }
                }
            }
        }

        // ── Click/key to dismiss ──
        MouseArea {
            anchors.fill: parent
            onClicked: root.dismiss()
        }
        Item {
            focus: root._visible && !root._dismissing
            Keys.onPressed: (event) => {
                event.accepted = true
                root.dismiss()
            }
        }

        // ── Content: centered column with staggered entrance ──
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            width: Math.min(600, parent.width * 0.8)

            // ── Clock ──
            StyledText {
                id: clockText
                Layout.alignment: Qt.AlignHCenter
                text: DateTime.time
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: 96
                    weight: Font.Light
                }
                color: Appearance.zzzEverywhere ? Appearance.zzz.onBg : Appearance.colors.colOnLayer0
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                opacity: root._cascade >= 1 ? 1.0 : 0.0
                scale: root._cascade >= 1 ? 1.0 : 0.85
                transformOrigin: Item.Center
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Easing.OutBack
                    }
                }
            }

            // ── Mascot wave ──
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 132
                Layout.preferredHeight: 132
                visible: greetingMascotAnim.active
                opacity: root._cascade >= 1 ? 1.0 : 0.0
                scale: root._cascade >= 1 ? 1.0 : 0.85
                transformOrigin: Item.Center
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Easing.OutBack
                    }
                }

                // Rare dramatic boot: she arrives by rocket instead of waving
                readonly property bool dramaticBoot: Math.random() < 0.12

                MascotAnimation {
                    id: greetingMascotAnim
                    anchors.fill: parent
                    surface: "bootGreeting"
                    pose: "wave-loop"
                    visible: active && status !== Image.Error && !parent.dramaticBoot
                }

                MascotImage {
                    anchors.fill: parent
                    surface: "bootGreeting"
                    pose: "rocket-ride"
                    visible: active && parent.dramaticBoot
                }

                MascotImage {
                    anchors.fill: parent
                    surface: "bootGreeting"
                    pose: "welcome-wave"
                    visible: active && !parent.dramaticBoot && greetingMascotAnim.status === Image.Error
                }
            }

            // ── Greeting ──
            StyledText {
                id: greetingText
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                text: Appearance.zzzEverywhere ? root.greeting.toUpperCase() : root.greeting
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.hugeass
                    weight: Appearance.zzzEverywhere ? Font.Bold : Font.Normal
                    letterSpacing: Appearance.zzzEverywhere ? 2 : 0
                }
                color: Appearance.zzzEverywhere ? Appearance.zzz.accent : Appearance.colors.colPrimary
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                opacity: root._cascade >= 2 ? 1.0 : 0.0
                transform: Translate {
                    y: root._cascade >= 2 ? 0 : 16
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ── Date ──
            StyledText {
                id: dateText
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                visible: root.showDate && opacity > 0
                text: DateTime.date
                font {
                    family: Appearance.font.family.main
                    pixelSize: Appearance.font.pixelSize.larger
                    weight: Font.Normal
                    capitalization: Font.Capitalize
                }
                color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                    : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.2)
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                opacity: root._cascade >= 3 ? 1.0 : 0.0
                transform: Translate {
                    y: root._cascade >= 3 ? 0 : 12
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            // ── Weather row (optional) ──
            RowLayout {
                id: weatherRow
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 16
                spacing: 8
                visible: root.showWeather && opacity > 0

                opacity: root._cascade >= 4 ? 1.0 : 0.0
                transform: Translate {
                    y: root._cascade >= 4 ? 0 : 12
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }

                MaterialSymbol {
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "thermostat"
                    iconSize: 22
                    color: Appearance.zzzEverywhere ? Appearance.zzz.onBg : Appearance.colors.colOnLayer0
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
                StyledText {
                    text: Weather.data?.temp ?? ""
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.zzzEverywhere ? Appearance.zzz.onBg : Appearance.colors.colOnLayer0
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
                StyledText {
                    text: Weather.data?.description ?? ""
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                        : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.3)
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }

            // ── Dismiss hint ──
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 40
                text: Appearance.zzzEverywhere ? Translation.tr("Click or press any key to continue").toUpperCase() : Translation.tr("Click or press any key to continue")
                font.pixelSize: Appearance.font.pixelSize.small
                font.letterSpacing: Appearance.zzzEverywhere ? 1 : 0
                color: Appearance.zzzEverywhere ? Appearance.zzz.ghostInk
                    : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.5)
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                opacity: root._cascade >= 5 ? 0.7 : 0.0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
