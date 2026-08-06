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
            let configuredPath = "";
            if (_multiMonEnabled && _perMonitorData.path)
                configuredPath = _perMonitorData.path;
            else if (wBg.useMainWallpaper ?? true)
                configuredPath = Config.options?.background?.wallpaperPath ?? "";
            else
                configuredPath = wBg.wallpaperPath ?? (Config.options?.background?.wallpaperPath ?? "");
            // Supplies the preview path only. awww eligibility is untouched, so
            // whichever engine already owns this wallpaper keeps owning it.
            return Wallpapers.internalPreviewFor(_monitorName, configuredPath);
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

        // Mirror of Background.qml: the family LazyLoader can retain this tree
        // after a switch, and without this both families kept a video decoding.
        readonly property bool _familyOwnsScreen: (Config.options?.panelFamily ?? "ii") === "waffle"
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
                ? Looks.effectiveDuration(transitionBaseDuration)
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
            if (CompositorService.isNiri) {
                return GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
            }
            return false
        }

        // Hide wallpaper (show only backdrop for overview)
        readonly property bool backdropOnly: (wBg.backdrop?.enable ?? false) && (wBg.backdrop?.hideWallpaper ?? false)

        visible: !backdropOnly && (GlobalStates.screenLocked
            || !hasFullscreenWindow || !(wBg.hideWhenFullscreen ?? true))

        // Dynamic focus based on windows
        property bool hasWindowsOnCurrentWorkspace: {
            try {
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows && NiriService.workspaces) {
                    const allWs = Object.values(NiriService.workspaces);
                    if (!allWs || allWs.length === 0) return false;
                    const outputName = panelRoot.modelData?.name ?? "";
                    const currentWs = allWs.find(ws => ws.output === outputName
                        && ws.is_active);
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

                readonly property bool localBlurNeedsStaticTexture:
                    panelRoot.visible
                    && Looks.effectsEnabled
                    && panelRoot.blurProgress > 0
                    && !panelRoot.wallpaperIsGif
                    && !panelRoot.wallpaperIsVideo
                readonly property bool needsStaticTexture:
                    !panelRoot.wallpaperIsGif
                    && !panelRoot.wallpaperIsVideo
                    && (panelRoot.showInternalStaticWallpaper
                        || wallpaperContainer.localBlurNeedsStaticTexture)

                WallpaperCrossfader {
                    id: wallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    enableTransitions: !AwwwBackend.active
                        && (Config.options?.background?.transition?.enable ?? true)
                    transitionType: Config.options?.background?.transition?.type ?? "crossfade"
                    transitionDirection: Config.options?.background?.transition?.direction ?? "right"
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    source: wallpaperContainer.needsStaticTexture
                        ? panelRoot.wallpaperUrl : ""
                    visible: !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo && ready
                    opacity: panelRoot.showInternalStaticWallpaper ? 1 : 0
                    layer.enabled: wallpaperContainer.needsStaticTexture
                        && !panelRoot.showInternalStaticWallpaper
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
                    playing: visible && panelRoot.enableAnimation
                        && !GlobalStates.screenLocked && !Looks.gameModeActive
                        && !Wallpapers.batteryPauseActive

                    layer.enabled: visible && Looks.effectsEnabled
                        && panelRoot.enableAnimatedBlur
                        && (panelRoot.wEffects.blurRadius ?? 0) > 0
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: ((panelRoot.wEffects.blurRadius ?? 32) * Math.max(0, Math.min(1, panelRoot.thumbnailBlurStrength / 100))) / 100.0
                        blurMax: 64
                    }
                }

                // Two-slot crossfader — see modules/common/widgets/VideoCrossfader.qml.
                // A single Video went black between clips while the new file loaded.
                VideoCrossfader {
                    id: videoWallpaper
                    anchors.fill: parent
                    visible: panelRoot.wallpaperIsVideo && !blurEffect.visible
                    source: (panelRoot.wallpaperIsVideo && panelRoot._familyOwnsScreen)
                        ? panelRoot.wallpaperSourceRaw : ""
                    fillMode: VideoOutput.PreserveAspectCrop
                    enableTransitions: Config.options?.background?.transition?.enable ?? true
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    shouldPlay: panelRoot.enableAnimation && !GlobalStates.screenLocked
                        && !Looks.gameModeActive && !Wallpapers.batteryPauseActive
                        && panelRoot._familyOwnsScreen
                        && visible

                    layer.enabled: visible && Looks.effectsEnabled
                        && panelRoot.enableAnimatedBlur
                        && (panelRoot.wEffects.blurRadius ?? 0) > 0
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
                visible: Looks.effectsEnabled && panelRoot.blurProgress > 0 &&
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

            // Vignette over the workspace wallpaper. This whole window is hidden
            // in backdrop-only mode (visible: !backdropOnly above), so WaffleBackdrop
            // owns the vignette there; here it covers normal mode — making the
            // effect apply over the workspace without hiding the main wallpaper.
            Rectangle {
                anchors.fill: parent
                visible: panelRoot.wBg.backdrop?.vignetteEnabled ?? false
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: panelRoot.wBg.backdrop?.vignetteRadius ?? 0.7; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, panelRoot.wBg.backdrop?.vignetteIntensity ?? 0.5) }
                }
            }

            WidgetCanvas {
                anchors.fill: parent
                visible: DesktopWidgetLayout.outputAllowed(
                    panelRoot.modelData?.name ?? "")
                enabled: visible && !GlobalStates.overviewOpen

                WaffleBackgroundClock {
                    id: backgroundClockWidget
                    outputName: panelRoot.modelData?.name ?? ""
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
                    text: Translation.tr("Activate Waffle")
                    font.pixelSize: Math.round(22 * Looks.fontScale)
                    font.family: "Segoe UI"
                    font.weight: Font.Light
                    color: Qt.rgba(1, 1, 1, 0.6)
                    anchors.right: parent.right
                }

                Text {
                    text: Translation.tr("Go to Settings to activate Waffle.")
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
