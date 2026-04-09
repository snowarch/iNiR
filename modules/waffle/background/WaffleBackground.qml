pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.waffle.looks
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panelRoot
        required property var modelData

        // Waffle background config
        readonly property var wBg: Config.options?.waffles?.background ?? {}
        readonly property var wEffects: wBg.effects ?? {}
        readonly property var wClock: wBg.widgets?.clock ?? {}
        readonly property bool activationWatermarkEnabled: Config.options?.waffles?.bar?.activationWatermark?.enable ?? false
        readonly property bool barAtBottom: Config.options?.waffles?.bar?.bottom ?? true
        readonly property real activationWatermarkBottomMargin: panelRoot.barAtBottom
            ? (Looks.scaledBar(48, panelRoot.screen) + Looks.dp(8))
            : Looks.dp(14)

        // Multi-monitor wallpaper support
        readonly property bool _multiMonEnabled: WallpaperListener.multiMonitorEnabled
        readonly property string _monitorName: WallpaperListener.getMonitorName(panelRoot.modelData)
        readonly property var _perMonitorData: _multiMonEnabled
            ? (WallpaperListener.effectivePerMonitor[_monitorName] ?? { path: "" })
            : ({ path: "" })

        // Wallpaper source — per-monitor when multi-monitor enabled, otherwise waffle/main per setting
        readonly property string wallpaperSourceRaw: {
            if (_multiMonEnabled && _perMonitorData.path) return _perMonitorData.path;
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? "";
            return wBg.wallpaperPath ?? (Config.options?.background?.wallpaperPath ?? "");
        }

        readonly property string wallpaperThumbnail: {
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.thumbnailPath ?? ""
            return wBg.thumbnailPath ?? (Config.options?.background?.thumbnailPath ?? "")
        }
        readonly property bool enableAnimation: wBg.enableAnimation ?? true
        readonly property bool enableAnimatedBlur: wEffects.enableAnimatedBlur ?? false
        readonly property int thumbnailBlurStrength: wEffects.thumbnailBlurStrength ?? Config.options?.background?.effects?.thumbnailBlurStrength ?? 70

        readonly property bool externalMainWallpaperEligible:
            AwwwBackend.supportsVisibleMainWallpaper(
                wallpaperSourceRaw,
                "fill",
                false,
                enableAnimatedBlur
            )
        readonly property bool externalMainWallpaperActive: panelRoot.externalMainWallpaperEligible
        readonly property bool showInternalStaticWallpaper: !externalMainWallpaperActive

        readonly property bool wallpaperIsVideo: {
            const lowerPath = wallpaperSourceRaw.toLowerCase();
            return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov");
        }

        readonly property bool wallpaperIsGif: {
            return wallpaperSourceRaw.toLowerCase().endsWith(".gif");
        }

        // Effective source: use thumbnail if animation disabled for videos/GIFs
        readonly property string wallpaperSource: {
            if (!panelRoot.enableAnimation && (panelRoot.wallpaperIsVideo || panelRoot.wallpaperIsGif)) {
                return panelRoot.wallpaperThumbnail || panelRoot.wallpaperSourceRaw;
            }
            return panelRoot.wallpaperSourceRaw;
        }

        readonly property string wallpaperUrl: {
            const path = wallpaperSource;
            if (!path) return "";
            if (path.startsWith("file://")) return path;
            return "file://" + path;
        }

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:wBackground"
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        readonly property int _wallpaperTransitionDurationMs: {
            const transitionBaseDuration = Config.options?.background?.transition?.duration ?? 800
            const qmlTransitionDuration = (Config.options?.background?.transition?.enable ?? true)
                ? Appearance.calcEffectiveDuration(transitionBaseDuration)
                : 0
            const awwwTransitionDuration = AwwwBackend.active ? AwwwBackend.transitionDurationMs : 0
            return Math.max(qmlTransitionDuration, awwwTransitionDuration)
        }

        property int _blurHoldDurationMs: 0
        function beginBlurSuppression(totalTransitionMs: int): void {
            if (panelRoot.blurProgress <= 0)
                return
            const holdMs = Math.max(0, totalTransitionMs)
            _blurTransitionAnimation.stop()
            panelRoot._blurTransitionFactor = 1
            panelRoot._blurHoldDurationMs = holdMs
            _blurTransitionAnimation.restart()
            _blurTransitionSafetyTimer.interval = holdMs + (Looks.transition.enabled ? Looks.transition.duration.slow + 600 : 900)
            _blurTransitionSafetyTimer.restart()
        }

        onWallpaperSourceChanged: {
            if (!Wallpapers._applyInProgress && panelRoot.blurProgress > 0)
                panelRoot.beginBlurSuppression(panelRoot._wallpaperTransitionDurationMs)
        }

        property bool hasFullscreenWindow: {
            if (CompositorService.isNiri && NiriService.windows) {
                return NiriService.windows.some(w => w.is_focused && w.is_fullscreen)
            }
            return false
        }

        // Hide wallpaper (show only backdrop for overview)
        readonly property bool backdropOnly: (wBg.backdrop?.enable ?? false) && (wBg.backdrop?.hideWallpaper ?? false)

        visible: !GameMode.shouldHidePanels && !backdropOnly && (GlobalStates.screenLocked || !hasFullscreenWindow || !(wBg.hideWhenFullscreen ?? true))

        // Dynamic focus based on windows
        property bool hasWindowsOnCurrentWorkspace: {
            try {
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows && NiriService.workspaces) {
                    const allWs = Object.values(NiriService.workspaces);
                    if (!allWs || allWs.length === 0) return false;
                    const currentNumber = NiriService.getCurrentWorkspaceNumber();
                    const currentWs = allWs.find(ws => ws.idx === currentNumber);
                    if (!currentWs) return false;
                    return NiriService.windows.some(w => w.workspace_id === currentWs.id);
                }
                return false;
            } catch (e) { return false; }
        }

        property bool focusWindowsPresent: !GlobalStates.screenLocked && hasWindowsOnCurrentWorkspace
        property real focusPresenceProgress: focusWindowsPresent ? 1 : 0
        Behavior on focusPresenceProgress {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }

        // Blur suppression during wallpaper transitions — briefly fades blur out
        // so awww/crossfader transitions are visible, then fades back in.
        property real _blurTransitionFactor: 1
        SequentialAnimation {
            id: _blurTransitionAnimation
            NumberAnimation {
                target: panelRoot; property: "_blurTransitionFactor"
                to: 0; duration: Looks.transition.enabled ? 140 : 0; easing.type: Easing.OutQuad
            }
            PauseAnimation {
                duration: panelRoot._blurHoldDurationMs
            }
            NumberAnimation {
                target: panelRoot; property: "_blurTransitionFactor"
                to: 1; duration: Looks.transition.enabled ? 220 : 0; easing.type: Easing.InOutQuad
            }
        }
        Timer {
            id: _blurTransitionSafetyTimer
            interval: panelRoot._wallpaperTransitionDurationMs + (Looks.transition.enabled ? Looks.transition.duration.slow + 800 : 1200)
            repeat: false
            onTriggered: panelRoot._blurTransitionFactor = 1
        }

        Connections {
            target: Wallpapers
            function onWallpaperBlurTransitionRequested(targetMonitors, durationMs): void {
                if (!targetMonitors || targetMonitors.length === 0 || targetMonitors.indexOf(panelRoot._monitorName) >= 0)
                    panelRoot.beginBlurSuppression(durationMs)
            }
        }

        // Blur progress — blur activates only when windows are present on the current workspace
        property real blurProgress: {
            const blurEnabled = wEffects.enableBlur ?? false;
            const blurRadius = wEffects.blurRadius ?? 0;
            if (!blurEnabled || blurRadius <= 0) return 0;
            return focusPresenceProgress * _blurTransitionFactor;
        }

        Item {
            anchors.fill: parent

            Item {
                id: wallpaperContainer
                anchors.fill: parent

                WallpaperCrossfader {
                    id: wallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    enableTransitions: !AwwwBackend.active
                        && (Config.options?.background?.transition?.enable ?? true)
                    transitionType: Config.options?.background?.transition?.type ?? "crossfade"
                    transitionDirection: Config.options?.background?.transition?.direction ?? "right"
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    source: panelRoot.wallpaperUrl && !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo
                        ? panelRoot.wallpaperUrl
                        : ""
                    visible: !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo && ready
                    opacity: panelRoot.showInternalStaticWallpaper ? 1 : 0
                    layer.enabled: !panelRoot.showInternalStaticWallpaper
                    sourceSize {
                        width: panelRoot.screen.width
                        height: panelRoot.screen.height
                    }
                }

                AnimatedImage {
                    id: gifWallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: panelRoot.wallpaperIsGif
                        ? (panelRoot.wallpaperSourceRaw.startsWith("file://")
                            ? panelRoot.wallpaperSourceRaw
                            : "file://" + panelRoot.wallpaperSourceRaw)
                        : ""
                    asynchronous: true
                    cache: false
                    sourceSize.width: 1920
                    sourceSize.height: 1080
                    visible: panelRoot.wallpaperIsGif && !blurEffect.visible && !panelRoot.externalMainWallpaperActive
                    playing: visible && panelRoot.enableAnimation && !GlobalStates.screenLocked && !Appearance._gameModeActive

                    layer.enabled: Appearance.effectsEnabled && panelRoot.enableAnimatedBlur && (panelRoot.wEffects.blurRadius ?? 0) > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: ((panelRoot.wEffects.blurRadius ?? 32) * Math.max(0, Math.min(1, panelRoot.thumbnailBlurStrength / 100))) / 100.0
                        blurMax: 64
                    }
                }

                Video {
                    id: videoWallpaper
                    anchors.fill: parent
                    visible: panelRoot.wallpaperIsVideo && !blurEffect.visible
                    source: {
                        if (!panelRoot.wallpaperIsVideo) return "";
                        const path = panelRoot.wallpaperSourceRaw;
                        if (!path) return "";
                        return path.startsWith("file://") ? path : ("file://" + path);
                    }
                    fillMode: VideoOutput.PreserveAspectCrop
                    loops: MediaPlayer.Infinite
                    muted: true
                    autoPlay: true

                    readonly property bool shouldPlay: panelRoot.enableAnimation && !GlobalStates.screenLocked && !Appearance._gameModeActive && !GlobalStates.overviewOpen

                    function pauseAndShowFirstFrame() {
                        pause()
                        seek(0)
                    }

                    onPlaybackStateChanged: {
                        if (playbackState === MediaPlayer.PlayingState && !shouldPlay) {
                            pauseAndShowFirstFrame()
                        }
                        if (playbackState === MediaPlayer.StoppedState && visible && shouldPlay) {
                            play()
                        }
                    }

                    onShouldPlayChanged: {
                        if (visible && panelRoot.wallpaperIsVideo) {
                            if (shouldPlay) play()
                            else pauseAndShowFirstFrame()
                        }
                    }

                    onVisibleChanged: {
                        if (visible && panelRoot.wallpaperIsVideo) {
                            if (shouldPlay) play()
                            else pauseAndShowFirstFrame()
                        } else {
                            pause()
                        }
                    }

                    layer.enabled: Appearance.effectsEnabled && panelRoot.enableAnimatedBlur && (panelRoot.wEffects.blurRadius ?? 0) > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: ((panelRoot.wEffects.blurRadius ?? 32) * Math.max(0, Math.min(1, panelRoot.thumbnailBlurStrength / 100))) / 100.0
                        blurMax: 64
                    }
                }
            }

            // Blur effect for static images — reads from crossfader texture (works with both QML and awww rendering)
            MultiEffect {
                id: blurEffect
                anchors.fill: parent
                source: wallpaper
                visible: Appearance.effectsEnabled && panelRoot.blurProgress > 0 &&
                         !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo &&
                         wallpaper.ready
                blurEnabled: visible
                blur: panelRoot.blurProgress * ((panelRoot.wEffects.blurRadius ?? 32) / 100.0)
                blurMax: 64
            }

            // Dim overlay
            Rectangle {
                anchors.fill: parent
                color: {
                    const baseN = Number(panelRoot.wEffects.dim) || 0;
                    const dynN = Number(panelRoot.wEffects.dynamicDim) || 0;
                    const extra = panelRoot.focusPresenceProgress > 0 ? dynN * panelRoot.focusPresenceProgress : 0;
                    const total = Math.max(0, Math.min(100, baseN + extra));
                    return Qt.rgba(0, 0, 0, total / 100);
                }
                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
            }

            WidgetCanvas {
                anchors.fill: parent
                enabled: !GlobalStates.overviewOpen

                WaffleBackgroundClock {
                    id: backgroundClockWidget
                    screenWidth: panelRoot.screen.width
                    screenHeight: panelRoot.screen.height
                    scaledScreenWidth: panelRoot.screen.width
                    scaledScreenHeight: panelRoot.screen.height
                    wallpaperScale: 1
                    wallpaperPath: panelRoot.wallpaperIsVideo
                        ? (panelRoot.wallpaperThumbnail || panelRoot.wallpaperSourceRaw)
                        : panelRoot.wallpaperSourceRaw
                }
            }

            // Windows-style activation watermark
            Column {
                id: activationWatermark
                visible: panelRoot.activationWatermarkEnabled && !GlobalStates.screenLocked && !GlobalStates.overviewOpen
                z: 20
                spacing: 0
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: Looks.dp(16)
                    bottomMargin: panelRoot.activationWatermarkBottomMargin
                }

                Text {
                    text: "Activate Waffle"
                    font.pixelSize: Math.round(22 * Looks.fontScale)
                    font.family: "Segoe UI"
                    font.weight: Font.Light
                    color: Qt.rgba(1, 1, 1, 0.6)
                    anchors.right: parent.right
                }

                Text {
                    text: "Go to Settings to activate Waffle."
                    font.pixelSize: Math.round(14 * Looks.fontScale)
                    font.family: "Segoe UI"
                    font.weight: Font.Light
                    color: Qt.rgba(1, 1, 1, 0.5)
                    anchors.right: parent.right
                }
            }
        }
    }
}
