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
import Quickshell.Io
import Quickshell.Wayland
import "root:modules/common/functions/parallax.js" as ParallaxMath

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
        readonly property var wParallax: wBg.parallax ?? {}

        // Multi-monitor wallpaper support
        readonly property bool _multiMonEnabled: WallpaperListener.multiMonitorEnabled
        readonly property string _monitorName: WallpaperListener.getMonitorName(panelRoot.modelData)
        readonly property var _perMonitorData: _multiMonEnabled
            ? (WallpaperListener.effectivePerMonitor[_monitorName] ?? { path: "" })
            : ({ path: "" })
        readonly property bool usePerMonitorRange: _multiMonEnabled
            && (_perMonitorData.workspaceFirst !== undefined && _perMonitorData.workspaceLast !== undefined)
        readonly property int effectiveWorkspaceFirst: usePerMonitorRange ? _perMonitorData.workspaceFirst : 1
        readonly property int effectiveWorkspaceLast: usePerMonitorRange ? _perMonitorData.workspaceLast : Math.max(2, Config.options?.bar?.workspaces?.shown ?? 10)

        // Wallpaper source — per-monitor when multi-monitor enabled, otherwise config
        readonly property string wallpaperSourceRaw: {
            if (_multiMonEnabled && _perMonitorData.path) return _perMonitorData.path;
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? "";
            return wBg.wallpaperPath || Config.options?.background?.wallpaperPath || "";
        }

        readonly property string wallpaperThumbnail: {
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.thumbnailPath ?? "";
            return wBg.thumbnailPath || Config.options?.background?.thumbnailPath || "";
        }

        readonly property bool enableAnimation: wBg.enableAnimation ?? Config.options?.background?.enableAnimation ?? true
        readonly property bool enableAnimatedBlur: wEffects.enableAnimatedBlur ?? false
        readonly property int thumbnailBlurStrength: wEffects.thumbnailBlurStrength ?? Config.options?.background?.effects?.thumbnailBlurStrength ?? 70
        readonly property bool parallaxEnabled: wParallax.enable
            ?? ((wParallax.enableWorkspace ?? false) || (wParallax.enableSidebar ?? false))
        readonly property bool workspaceParallaxEnabled: parallaxEnabled && (wParallax.enableWorkspace ?? false)
        readonly property bool panelParallaxEnabled: parallaxEnabled && (wParallax.enableSidebar ?? false)
        readonly property bool dynamicParallaxRequested: workspaceParallaxEnabled || panelParallaxEnabled
        readonly property real parallaxWorkspaceShift: ParallaxMath.resolveWorkspaceShift(wParallax, 1)
        readonly property real parallaxPanelShift: ParallaxMath.resolvePanelShift(wParallax, 0.12)
        readonly property real parallaxWidgetDepth: ParallaxMath.resolveWidgetDepth(wParallax, 1)
        readonly property bool pauseParallaxDuringTransitions: wParallax.pauseDuringTransitions ?? true
        readonly property int parallaxTransitionSettleMs: ParallaxMath.resolveTransitionSettle(wParallax, 220)
        readonly property string fillMode: Config.options?.background?.fillMode ?? "fill"
        property string _panReadyWallpaperPath: panelRoot.wallpaperSourceRaw
        readonly property bool externalMainWallpaperEligible:
            AwwwBackend.supportsVisibleMainWallpaper(
                wallpaperSourceRaw,
                fillMode,
                dynamicParallaxRequested,
                enableAnimatedBlur
            )
        readonly property bool effectiveHasPan: panelRoot.hasPan
            && (!panelRoot.externalMainWallpaperEligible || panelRoot._panReadyWallpaperPath === panelRoot.wallpaperSourceRaw)
        readonly property bool externalMainWallpaperActive: panelRoot.externalMainWallpaperEligible
            && !panelRoot.effectiveHasPan
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

        // Wallpaper scaling — decode at correct resolution for quality parity with ii/material.
        // Uses magick identify to detect actual image size, same approach as Background.qml.
        readonly property real _preferredScale: ParallaxMath.resolveZoom(wParallax, 1.05)
        property real _effectiveWallpaperScale: _preferredScale
        property int _wallpaperWidth: panelRoot.screen.width
        property int _wallpaperHeight: panelRoot.screen.height
        readonly property real wallpaperToScreenRatio: Math.min(_wallpaperWidth / screen.width, _wallpaperHeight / screen.height)
        readonly property real movableXSpace: ((_wallpaperWidth / wallpaperToScreenRatio * _effectiveWallpaperScale) - screen.width) / 2
        readonly property real movableYSpace: ((_wallpaperHeight / wallpaperToScreenRatio * _effectiveWallpaperScale) - screen.height) / 2
        readonly property var _panOptions: Config.options?.background?.pan ?? {}
        readonly property real panX: _panOptions.x ?? 0.0
        readonly property real panY: _panOptions.y ?? 0.0
        readonly property real panZoom: Math.max(1.0, Math.min(3.0, _panOptions.zoom ?? 1.0))
        readonly property bool hasPan: panX !== 0.0 || panY !== 0.0 || panZoom !== 1.0
        readonly property string parallaxAxis: ParallaxMath.resolveAxis(
            wParallax.axis,
            wParallax.autoVertical ?? true,
            wParallax.vertical ?? false,
            _wallpaperWidth,
            _wallpaperHeight
        )
        property real _awwwRevealOpacity: 1
        readonly property bool _awwwParallaxRevealNeeded: AwwwBackend.active
            && dynamicParallaxRequested
            && !wallpaperIsGif
            && !wallpaperIsVideo
            && !(wBg.backdrop?.hideWallpaper ?? false)
        readonly property int _wallpaperTransitionDurationMs: {
            const qmlTransitionDuration = (wBg.useMainWallpaper ?? true)
                ? ((Config.options?.background?.transition?.enable ?? true) ? (Config.options?.background?.transition?.duration ?? 800) : 0)
                : ((wBg.transition?.enable ?? true) ? (wBg.transition?.duration ?? 800) : 0)
            const awwwTransitionDuration = AwwwBackend.active ? AwwwBackend.transitionDurationMs : 0
            return Math.max(qmlTransitionDuration, awwwTransitionDuration)
        }
        property bool parallaxTransitionActive: false
        property real parallaxResumeProgress: 1
        property string _pendingWallpaperMetricsPath: ""
        property string _activeWallpaperMetricsPath: ""

        function pauseParallaxForWallpaperTransition(): void {
            if (!dynamicParallaxRequested || !pauseParallaxDuringTransitions)
                return
            parallaxTransitionActive = true
            parallaxResumeProgress = 0
            parallaxTransitionPauseTimer.restart()
        }

        function queueWallpaperMetricsUpdate(path: string): void {
            const normalizedPath = String(path ?? "")
            if (!normalizedPath || normalizedPath.length === 0)
                return
            if (panelRoot.wallpaperIsVideo)
                return

            panelRoot._pendingWallpaperMetricsPath = normalizedPath
            if (panelRoot._activeWallpaperMetricsPath.length === 0)
                panelRoot.startNextWallpaperMetricsRequest()
        }

        function startNextWallpaperMetricsRequest(): void {
            if (panelRoot._pendingWallpaperMetricsPath.length === 0)
                return

            const nextPath = panelRoot._pendingWallpaperMetricsPath
            panelRoot._pendingWallpaperMetricsPath = ""
            panelRoot._activeWallpaperMetricsPath = nextPath
            _getWallpaperSizeProc.path = nextPath
            _getWallpaperSizeProc.running = true
        }

        function finishWallpaperMetricsRequest(): void {
            panelRoot._activeWallpaperMetricsPath = ""
            if (panelRoot._pendingWallpaperMetricsPath.length > 0)
                panelRoot.startNextWallpaperMetricsRequest()
        }

        onWallpaperSourceChanged: {
            const normalizedPath = String(panelRoot.wallpaperSourceRaw ?? "")
            if (panelRoot.hasPan && panelRoot.externalMainWallpaperEligible) {
                panelRoot._panReadyWallpaperPath = ""
                panActivationTimer.restart()
            } else {
                panelRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
            }
            pauseParallaxForWallpaperTransition()
            _wallpaperSizeDebounce.restart()
            if (panelRoot._awwwParallaxRevealNeeded) {
                panelRoot._awwwRevealOpacity = 0
                _awwwRevealAnimation.restart()
                panelRoot._effectiveWallpaperScale = panelRoot._preferredScale
            }
            // Suppress blur during transition so the wallpaper change is visible
            if (panelRoot.blurProgress > 0)
                _blurTransitionAnimation.restart()
        }

        on_PreferredScaleChanged: {
            if (panelRoot._awwwParallaxRevealNeeded)
                panelRoot._effectiveWallpaperScale = panelRoot._preferredScale
        }

        onPanZoomChanged: {
            const normalizedPath = String(panelRoot.wallpaperSourceRaw ?? "")
            if (!panelRoot.hasPan) {
                panelRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
                _wallpaperSizeDebounce.restart()
                return
            }

            if (panelRoot.externalMainWallpaperEligible && panelRoot._panReadyWallpaperPath !== normalizedPath)
                return

            panelRoot._panReadyWallpaperPath = normalizedPath
            _wallpaperSizeDebounce.restart()
        }

        onHasPanChanged: {
            if (panelRoot.hasPan)
                return
            panelRoot._panReadyWallpaperPath = String(panelRoot.wallpaperSourceRaw ?? "")
            panActivationTimer.stop()
            _wallpaperSizeDebounce.restart()
        }

        Timer {
            id: parallaxTransitionPauseTimer
            interval: panelRoot._wallpaperTransitionDurationMs + panelRoot.parallaxTransitionSettleMs
            repeat: false
            onTriggered: {
                panelRoot.parallaxTransitionActive = false
                parallaxResumeAnimation.restart()
            }
        }

        Timer {
            id: panActivationTimer
            interval: panelRoot._wallpaperTransitionDurationMs + 120
            repeat: false
            onTriggered: {
                const normalizedPath = String(panelRoot.wallpaperSourceRaw ?? "")
                panelRoot._panReadyWallpaperPath = normalizedPath
                if (panelRoot.hasPan)
                    _wallpaperSizeDebounce.restart()
            }
        }

        NumberAnimation {
            id: parallaxResumeAnimation
            target: panelRoot
            property: "parallaxResumeProgress"
            from: 0
            to: 1
            duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: _awwwRevealAnimation

            PauseAnimation {
                duration: AwwwBackend.transitionDurationMs + 400
            }
            NumberAnimation {
                target: panelRoot
                property: "_awwwRevealOpacity"
                to: 1
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.OutQuad
            }
        }

        Timer {
            id: _wallpaperSizeDebounce
            interval: 80
            repeat: false
            onTriggered: {
                const path = panelRoot.wallpaperSourceRaw
                if (!path || path.length === 0) return
                if (panelRoot.wallpaperIsVideo) return
                panelRoot.queueWallpaperMetricsUpdate(path)
            }
        }

        Process {
            id: _getWallpaperSizeProc
            property string path: panelRoot.wallpaperSourceRaw
            command: ["/usr/bin/magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: _sizeOutput
                onStreamFinished: {
                    const requestPath = panelRoot._activeWallpaperMetricsPath || _getWallpaperSizeProc.path
                    const output = (_sizeOutput.text ?? "").trim()
                    const parts = output.split(/\s+/).filter(Boolean)
                    const w = Number(parts[0])
                    const h = Number(parts[1])
                    const sw = panelRoot.screen?.width ?? 0
                    const sh = panelRoot.screen?.height ?? 0
                    if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0 || sw <= 0 || sh <= 0) {
                        panelRoot.finishWallpaperMetricsRequest()
                        return
                    }
                    if (requestPath !== panelRoot.wallpaperSourceRaw) {
                        panelRoot.finishWallpaperMetricsRequest()
                        return
                    }
                    panelRoot._wallpaperWidth = Math.round(w)
                    panelRoot._wallpaperHeight = Math.round(h)
                    if (panelRoot._awwwParallaxRevealNeeded) {
                        panelRoot._effectiveWallpaperScale = panelRoot._preferredScale
                    } else if (w <= sw || h <= sh) {
                        const baseScale = Math.max(sw / w, sh / h)
                        panelRoot._effectiveWallpaperScale = panelRoot.effectiveHasPan ? baseScale * panelRoot.panZoom : baseScale
                    } else {
                        const baseScale = Math.min(panelRoot._preferredScale, w / sw, h / sh)
                        panelRoot._effectiveWallpaperScale = panelRoot.effectiveHasPan ? baseScale * panelRoot.panZoom : baseScale
                    }
                    panelRoot.finishWallpaperMetricsRequest()
                }
            }
        }

        property bool hasFullscreenWindow: {
            if (CompositorService.isNiri && NiriService.windows) {
                return NiriService.windows.some(w => w.is_focused && w.is_fullscreen)
            }
            return false
        }

        // Hide wallpaper (show only backdrop for overview)
        readonly property bool backdropOnly: wBg.backdrop?.hideWallpaper ?? false

        visible: !backdropOnly && (GlobalStates.screenLocked || !hasFullscreenWindow || !(wBg.hideWhenFullscreen ?? true))

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
                to: 0; duration: Looks.transition.enabled ? 200 : 0; easing.type: Easing.OutQuad
            }
            PauseAnimation {
                duration: AwwwBackend.transitionDurationMs + 200
            }
            NumberAnimation {
                target: panelRoot; property: "_blurTransitionFactor"
                to: 1; duration: Looks.transition.enabled ? 400 : 0; easing.type: Easing.InOutQuad
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
            clip: true

            Item {
                id: wallpaperContainer
                property int lower: panelRoot.usePerMonitorRange ? panelRoot.effectiveWorkspaceFirst : 1
                property int upper: panelRoot.usePerMonitorRange ? panelRoot.effectiveWorkspaceLast : Math.max(2, Config.options?.bar?.workspaces?.shown ?? 10)
                property int currentWorkspaceId: CompositorService.isNiri ? (NiriService.focusedWorkspaceIndex ?? 1) : 1
                property real workspaceProgress: ParallaxMath.normalizedWorkspaceProgress(currentWorkspaceId, lower, upper)
                property real valueX: ParallaxMath.axisValue(
                    "horizontal",
                    panelRoot.parallaxAxis,
                    panelRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    panelRoot.parallaxWorkspaceShift,
                    panelRoot.panelParallaxEnabled,
                    [GlobalStates.searchOpen, GlobalStates.waffleWidgetsOpen, GlobalStates.waffleClipboardOpen],
                    [GlobalStates.waffleActionCenterOpen, GlobalStates.waffleNotificationCenterOpen],
                    panelRoot.parallaxPanelShift
                )
                property real valueY: ParallaxMath.axisValue(
                    "vertical",
                    panelRoot.parallaxAxis,
                    panelRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    panelRoot.parallaxWorkspaceShift,
                    false,
                    [],
                    [],
                    0
                )
                readonly property real effectiveValueX: Math.max(0, Math.min(1, valueX))
                readonly property real effectiveValueY: Math.max(0, Math.min(1, valueY))
                readonly property real activeValueX: panelRoot.parallaxTransitionActive
                    ? 0.5
                    : (0.5 + ((effectiveValueX - 0.5) * panelRoot.parallaxResumeProgress))
                readonly property real activeValueY: panelRoot.parallaxTransitionActive
                    ? 0.5
                    : (0.5 + ((effectiveValueY - 0.5) * panelRoot.parallaxResumeProgress))
                readonly property bool useParallax: panelRoot.fillMode === "fill"
                    && !panelRoot.wallpaperIsGif
                    && !panelRoot.wallpaperIsVideo
                    && !panelRoot.externalMainWallpaperActive
                readonly property real panOffsetX: panelRoot.effectiveHasPan ? (panelRoot.panX * Math.max(0, panelRoot.movableXSpace)) : 0
                readonly property real panOffsetY: panelRoot.effectiveHasPan ? (panelRoot.panY * Math.max(0, panelRoot.movableYSpace)) : 0
                readonly property real targetX: useParallax
                    ? (-(panelRoot.movableXSpace) - (activeValueX - 0.5) * 2 * panelRoot.movableXSpace + panOffsetX)
                    : panOffsetX
                readonly property real targetY: useParallax
                    ? (-(panelRoot.movableYSpace) - (activeValueY - 0.5) * 2 * panelRoot.movableYSpace + panOffsetY)
                    : panOffsetY
                readonly property real targetWidth: (useParallax || panelRoot.effectiveHasPan) ? (panelRoot._wallpaperWidth / panelRoot.wallpaperToScreenRatio * panelRoot._effectiveWallpaperScale) : panelRoot.screen.width
                readonly property real targetHeight: (useParallax || panelRoot.effectiveHasPan) ? (panelRoot._wallpaperHeight / panelRoot.wallpaperToScreenRatio * panelRoot._effectiveWallpaperScale) : panelRoot.screen.height
                x: targetX
                y: targetY
                width: targetWidth
                height: targetHeight

                Behavior on x {
                    enabled: Looks.transition.enabled && (wallpaperContainer.useParallax || panelRoot.effectiveHasPan) && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                    animation: NumberAnimation { duration: panelRoot._wallpaperTransitionDurationMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
                Behavior on y {
                    enabled: Looks.transition.enabled && (wallpaperContainer.useParallax || panelRoot.effectiveHasPan) && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                    animation: NumberAnimation { duration: panelRoot._wallpaperTransitionDurationMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
                Behavior on width {
                    enabled: Looks.transition.enabled && (wallpaperContainer.useParallax || panelRoot.effectiveHasPan) && panelRoot._awwwRevealOpacity >= 1 && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                    animation: NumberAnimation { duration: panelRoot._wallpaperTransitionDurationMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
                Behavior on height {
                    enabled: Looks.transition.enabled && (wallpaperContainer.useParallax || panelRoot.effectiveHasPan) && panelRoot._awwwRevealOpacity >= 1 && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                    animation: NumberAnimation { duration: panelRoot._wallpaperTransitionDurationMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }

                WallpaperCrossfader {
                    id: wallpaper
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    enableTransitions: !AwwwBackend.active
                        && ((wBg.useMainWallpaper ?? true)
                            ? (Config.options?.background?.transition?.enable ?? true)
                            : (wBg.transition?.enable ?? true))
                    transitionType: (wBg.useMainWallpaper ?? true)
                        ? (Config.options?.background?.transition?.type ?? "crossfade")
                        : (wBg.transition?.type ?? "crossfade")
                    transitionDirection: (wBg.useMainWallpaper ?? true)
                        ? (Config.options?.background?.transition?.direction ?? "right")
                        : (wBg.transition?.direction ?? "right")
                    transitionBaseDuration: (wBg.useMainWallpaper ?? true)
                        ? (Config.options?.background?.transition?.duration ?? 800)
                        : (wBg.transition?.duration ?? 800)
                    source: panelRoot.wallpaperUrl && !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo
                        ? panelRoot.wallpaperUrl
                        : ""
                    visible: !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo && ready
                        && (panelRoot.showInternalStaticWallpaper ? !blurEffect.visible : true)
                    opacity: panelRoot.showInternalStaticWallpaper ? panelRoot._awwwRevealOpacity : 0
                    layer.enabled: !panelRoot.showInternalStaticWallpaper
                    sourceSize {
                        width: Math.round(panelRoot.screen.width * ((wallpaperContainer.useParallax || panelRoot.effectiveHasPan) ? panelRoot._effectiveWallpaperScale : 1))
                        height: Math.round(panelRoot.screen.height * ((wallpaperContainer.useParallax || panelRoot.effectiveHasPan) ? panelRoot._effectiveWallpaperScale : 1))
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
                readonly property bool useParallax: wallpaperContainer.useParallax
                anchors {
                    left: useParallax ? wallpaperContainer.left : parent.left
                    right: useParallax ? wallpaperContainer.right : parent.right
                    top: useParallax ? wallpaperContainer.top : parent.top
                    bottom: useParallax ? wallpaperContainer.bottom : parent.bottom
                    readonly property real parallaxFactor: panelRoot.parallaxWidgetDepth
                    leftMargin: useParallax ? (panelRoot.movableXSpace - (wallpaperContainer.activeValueX * 2 * panelRoot.movableXSpace) * (parallaxFactor - 1)) : 0
                    topMargin: useParallax ? (panelRoot.movableYSpace - (wallpaperContainer.activeValueY * 2 * panelRoot.movableYSpace) * (parallaxFactor - 1)) : 0
                    Behavior on leftMargin {
                        enabled: Looks.transition.enabled && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                    Behavior on topMargin {
                        enabled: Looks.transition.enabled && !panelRoot.parallaxTransitionActive && panelRoot.parallaxResumeProgress >= 1
                        animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
                width: useParallax ? wallpaperContainer.width : parent.width
                height: useParallax ? wallpaperContainer.height : parent.height
                enabled: !GlobalStates.overviewOpen

                WaffleBackgroundClock {
                    screenWidth: panelRoot.screen.width
                    screenHeight: panelRoot.screen.height
                    scaledScreenWidth: panelRoot.screen.width / panelRoot._effectiveWallpaperScale
                    scaledScreenHeight: panelRoot.screen.height / panelRoot._effectiveWallpaperScale
                    wallpaperScale: panelRoot._effectiveWallpaperScale
                    wallpaperPath: panelRoot.wallpaperIsVideo
                        ? (panelRoot.wallpaperThumbnail || panelRoot.wallpaperSourceRaw)
                        : panelRoot.wallpaperSourceRaw
                }
            }
        }
    }
}
