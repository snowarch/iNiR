pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.background.widgets
import qs.modules.background.widgets.clock
import qs.modules.background.widgets.mediaControls
import qs.modules.background.widgets.weather
import "root:modules/common/functions/parallax.js" as ParallaxMath

Variants {
    id: root
    model: Quickshell.screens

    // Shared cache for magick identify results across all monitor instances.
    // Avoids re-running the subprocess for previously-seen wallpapers.
    property var _wallpaperSizeCache: ({})

    PanelWindow {
        id: bgRoot

        required property var modelData

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: CompositorService.isHyprland ? Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name) : []
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        property bool hasFullscreenWindow: {
            if (CompositorService.isHyprland) {
                return activeWorkspaceWithFullscreen != undefined
            }
            if (CompositorService.isNiri && NiriService.windows) {
                return NiriService.windows.some(w => w.is_focused && w.is_fullscreen)
            }
            return false
        }
        visible: !GameMode.shouldHidePanels && (GlobalStates.screenLocked || !hasFullscreenWindow || !(Config.options?.background?.hideWhenFullscreen ?? false))

        // Workspaces
        property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(modelData) : null
        property list<var> relevantWindows: CompositorService.isHyprland ? HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id) : []
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        readonly property string screenName: screen?.name ?? ""
        readonly property var backgroundOptions: Config.options?.background ?? {}
        readonly property var parallaxOptions: backgroundOptions.parallax ?? {}
        readonly property var effectsOptions: backgroundOptions.effects ?? {}
        readonly property var workSafetyOptions: Config.options?.workSafety ?? {}
        readonly property var workSafetyEnableOptions: workSafetyOptions.enable ?? {}
        readonly property var workSafetyTriggerOptions: workSafetyOptions.triggerCondition ?? {}
        readonly property var lockBlurOptions: Config.options?.lock?.blur ?? {}
        readonly property var backgroundWidgetsOptions: backgroundOptions.widgets ?? {}

        // Multi-monitor wallpaper support
        // IMPORTANT: Only use WallpaperListener when multi-monitor is enabled.
        // When disabled, use direct config path to preserve QML reactive bindings
        // that Aurora glass/blur depends on.
        readonly property bool _multiMonEnabled: WallpaperListener.multiMonitorEnabled
        readonly property string monitorName: {
            if (CompositorService.isNiri) {
                return modelData.name ?? ""
            } else if (CompositorService.isHyprland && bgRoot.monitor) {
                return bgRoot.monitor.name ?? ""
            }
            return modelData.name ?? ""
        }
        readonly property var wallpaperData: _multiMonEnabled
            ? (WallpaperListener.effectivePerMonitor[monitorName] ?? { path: "" })
            : ({ path: "" })

        // Per-monitor workspace range for parallax
        readonly property bool usePerMonitorRange: _multiMonEnabled &&
            (wallpaperData.workspaceFirst !== undefined && wallpaperData.workspaceLast !== undefined)
        readonly property int effectiveWorkspaceFirst: usePerMonitorRange ? wallpaperData.workspaceFirst : 1
        readonly property int effectiveWorkspaceLast: usePerMonitorRange ? wallpaperData.workspaceLast : (Config.options?.bar?.workspaces?.shown ?? 10)

        // Wallpaper — use per-monitor path when multi-monitor enabled, otherwise direct config
        readonly property string wallpaperPathRaw: {
            if (_multiMonEnabled && wallpaperData.path) return wallpaperData.path
            return bgRoot.backgroundOptions.wallpaperPath ?? ""
        }
        readonly property string wallpaperThumbnailPath: bgRoot.backgroundOptions.thumbnailPath ?? bgRoot.wallpaperPathRaw
        readonly property bool enableAnimation: bgRoot.backgroundOptions.enableAnimation ?? true
        property bool wallpaperIsVideo: wallpaperPathRaw.endsWith(".mp4") || wallpaperPathRaw.endsWith(".webm") || wallpaperPathRaw.endsWith(".mkv") || wallpaperPathRaw.endsWith(".avi") || wallpaperPathRaw.endsWith(".mov")
        property bool wallpaperIsGif: wallpaperPathRaw.toLowerCase().endsWith(".gif")
        property string wallpaperPath: bgRoot.wallpaperPathRaw
        property bool wallpaperSafetyTriggered: {
            const enabled = bgRoot.workSafetyEnableOptions.wallpaper ?? false;
            const fileKeywords = bgRoot.workSafetyTriggerOptions.fileKeywords ?? [];
            const networkKeywords = bgRoot.workSafetyTriggerOptions.networkNameKeywords ?? [];
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), networkKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        readonly property string fillMode: bgRoot.backgroundOptions.fillMode ?? "fill"
        readonly property var panOptions: bgRoot.backgroundOptions.pan ?? {}
        readonly property real panX: bgRoot.panOptions.x ?? 0.0
        readonly property real panY: bgRoot.panOptions.y ?? 0.0
        readonly property real panZoom: Math.max(1.0, Math.min(3.0, bgRoot.panOptions.zoom ?? 1.0))
        readonly property bool hasPan: bgRoot.panX !== 0.0 || bgRoot.panY !== 0.0 || bgRoot.panZoom !== 1.0
        property string _panReadyWallpaperPath: bgRoot.wallpaperPath
        readonly property bool parallaxEnabled: bgRoot.parallaxOptions.enable
            ?? ((bgRoot.parallaxOptions.enableWorkspace ?? false) || (bgRoot.parallaxOptions.enableSidebar ?? false))
        readonly property bool workspaceParallaxEnabled: bgRoot.parallaxEnabled && (bgRoot.parallaxOptions.enableWorkspace ?? false)
        readonly property bool sidebarParallaxEnabled: bgRoot.parallaxEnabled && (bgRoot.parallaxOptions.enableSidebar ?? false)
        readonly property bool dynamicParallaxRequested: bgRoot.workspaceParallaxEnabled || bgRoot.sidebarParallaxEnabled
        readonly property real parallaxWorkspaceShift: ParallaxMath.resolveWorkspaceShift(bgRoot.parallaxOptions, 1)
        readonly property real parallaxPanelShift: ParallaxMath.resolvePanelShift(bgRoot.parallaxOptions, 0.15)
        readonly property real parallaxWidgetDepth: ParallaxMath.resolveWidgetDepth(bgRoot.parallaxOptions, 1.2)
        readonly property bool pauseParallaxDuringTransitions: bgRoot.parallaxOptions.pauseDuringTransitions ?? true
        readonly property int parallaxTransitionSettleMs: ParallaxMath.resolveTransitionSettle(bgRoot.parallaxOptions, 220)
        readonly property bool externalMainWallpaperEligible: !wallpaperSafetyTriggered
            && !((bgRoot.backgroundOptions.backdrop?.enable ?? false) && (bgRoot.backgroundOptions.backdrop?.hideWallpaper ?? false))
            && AwwwBackend.supportsVisibleMainWallpaper(
                bgRoot.wallpaperPathRaw,
                bgRoot.fillMode,
                bgRoot.dynamicParallaxRequested,
                bgRoot.effectsOptions.enableAnimatedBlur ?? false
            )
        readonly property bool effectiveHasPan: bgRoot.hasPan
            && (!bgRoot.externalMainWallpaperEligible || bgRoot._panReadyWallpaperPath === bgRoot.wallpaperPath)
        readonly property bool externalMainWallpaperActive: bgRoot.externalMainWallpaperEligible
            && !bgRoot.effectiveHasPan
        property real preferredWallpaperScale: ParallaxMath.resolveZoom(bgRoot.parallaxOptions, 1.0)
        property real _manualWallpaperScaleOverride: 0
        property int wallpaperWidth: modelData.width
        property int wallpaperHeight: modelData.height
        readonly property real baseWallpaperScale: ParallaxMath.effectiveScale(
            wallpaperWidth,
            wallpaperHeight,
            screen.width,
            screen.height,
            preferredWallpaperScale
        )
        readonly property real effectiveWallpaperScale: {
            const overrideScale = Number(bgRoot._manualWallpaperScaleOverride)
            const baseScale = Number.isFinite(overrideScale) && overrideScale > 0 ? overrideScale : bgRoot.baseWallpaperScale
            return bgRoot.effectiveHasPan ? baseScale * bgRoot.panZoom : baseScale
        }
        readonly property real scaledWallpaperWidth: bgRoot.wallpaperWidth * bgRoot.effectiveWallpaperScale
        readonly property real scaledWallpaperHeight: bgRoot.wallpaperHeight * bgRoot.effectiveWallpaperScale
        readonly property real parallaxTotalX: ParallaxMath.parallaxTotalPixels(bgRoot.scaledWallpaperWidth, bgRoot.screen.width)
        readonly property real parallaxTotalY: ParallaxMath.parallaxTotalPixels(bgRoot.scaledWallpaperHeight, bgRoot.screen.height)
        readonly property string parallaxAxis: ParallaxMath.resolveAxis(
            bgRoot.parallaxOptions.axis,
            bgRoot.parallaxOptions.autoVertical ?? false,
            bgRoot.parallaxOptions.vertical ?? false,
            wallpaperWidth,
            wallpaperHeight
        )
        readonly property bool verticalParallax: bgRoot.parallaxAxis === "vertical"
        
        // Backdrop mode
        readonly property bool backdropActive: (bgRoot.backgroundOptions.backdrop?.enable ?? false) && (bgRoot.backgroundOptions.backdrop?.hideWallpaper ?? false)

        // awww reveal: when parallax is active and awww handles wallpaper,
        // instantly hide crossfader, let awww transition play, then fade back in.
        property real _awwwRevealOpacity: 1
        readonly property bool _awwwParallaxRevealNeeded: AwwwBackend.active
            && bgRoot.dynamicParallaxRequested
            && !bgRoot.wallpaperIsGif
            && !bgRoot.wallpaperIsVideo
            && !bgRoot.wallpaperSafetyTriggered
            && !bgRoot.backdropActive
        
        readonly property int _wallpaperTransitionDurationMs: {
            const transitionBaseDuration = Config.options?.background?.transition?.duration ?? 800
            const qmlTransitionDuration = (Config.options?.background?.transition?.enable ?? true)
                ? Appearance.calcEffectiveDuration(transitionBaseDuration)
                : 0
            const awwwTransitionDuration = AwwwBackend.active ? AwwwBackend.transitionDurationMs : 0
            return Math.max(qmlTransitionDuration, awwwTransitionDuration)
        }
        property bool parallaxTransitionActive: false
        property real parallaxResumeProgress: 1
        property real parallaxFreezeValueX: 0.5
        property real parallaxFreezeValueY: 0.5
        property bool _parallaxWaitingCrossfader: false
        property string _parallaxTransitionReason: ""
        property string pendingWallpaperMetricsPath: ""
        property string activeWallpaperMetricsPath: ""

        function beginParallaxTransition(waitForCrossfader: bool, reason: string): void {
            if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                return

            if (waitForCrossfader && bgRoot.parallaxTransitionActive && bgRoot._parallaxWaitingCrossfader)
                return

            const currentX = Number(wallpaperContainer ? wallpaperContainer.activeValueX : 0.5)
            const currentY = Number(wallpaperContainer ? wallpaperContainer.activeValueY : 0.5)
            bgRoot.parallaxFreezeValueX = Number.isFinite(currentX) ? currentX : 0.5
            bgRoot.parallaxFreezeValueY = Number.isFinite(currentY) ? currentY : 0.5
            bgRoot.parallaxTransitionActive = true
            bgRoot.parallaxResumeProgress = 0
            bgRoot._parallaxWaitingCrossfader = waitForCrossfader
            bgRoot._parallaxTransitionReason = String(reason ?? "")
            parallaxResumeAnimation.stop()
            parallaxTransitionPauseTimer.stop()

            if (!waitForCrossfader) {
                parallaxTransitionPauseTimer.interval = bgRoot._wallpaperTransitionDurationMs + bgRoot.parallaxTransitionSettleMs
                parallaxTransitionPauseTimer.restart()
            }
        }

        function settleParallaxAfterTransition(): void {
            if (!bgRoot.parallaxTransitionActive)
                return
            bgRoot._parallaxWaitingCrossfader = false
            parallaxTransitionPauseTimer.interval = bgRoot.parallaxTransitionSettleMs
            parallaxTransitionPauseTimer.restart()
        }

        function pauseParallaxForWallpaperTransition(): void {
            if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                return
            if (bgRoot.wallpaperIsGif || bgRoot.wallpaperIsVideo)
                return

            const crossfaderTransitionsEnabled = !AwwwBackend.active
                && (Config.options?.background?.transition?.enable ?? true)

            if (!crossfaderTransitionsEnabled && bgRoot._wallpaperTransitionDurationMs <= 0)
                return

            bgRoot.beginParallaxTransition(crossfaderTransitionsEnabled, "wallpaper")
        }

        function queueWallpaperMetricsUpdate(path: string): void {
            const normalizedPath = String(path ?? "")
            if (!normalizedPath || normalizedPath.length === 0)
                return
            if (bgRoot.wallpaperIsVideo || bgRoot.wallpaperSafetyTriggered)
                return

            bgRoot.pendingWallpaperMetricsPath = normalizedPath
            if (bgRoot.activeWallpaperMetricsPath.length === 0)
                bgRoot.startNextWallpaperMetricsRequest()
        }

        function startNextWallpaperMetricsRequest(): void {
            if (bgRoot.pendingWallpaperMetricsPath.length === 0)
                return

            const nextPath = bgRoot.pendingWallpaperMetricsPath
            bgRoot.pendingWallpaperMetricsPath = ""
            bgRoot.activeWallpaperMetricsPath = nextPath
            getWallpaperSizeProc.path = nextPath
            getWallpaperSizeProc.running = true
        }

        function finishWallpaperMetricsRequest(): void {
            bgRoot.activeWallpaperMetricsPath = ""
            if (bgRoot.pendingWallpaperMetricsPath.length > 0)
                bgRoot.startNextWallpaperMetricsRequest()

            // Invariant: never keep manual override after reveal/metrics settle.
            if (bgRoot.pendingWallpaperMetricsPath.length === 0 && bgRoot._awwwRevealOpacity >= 1)
                bgRoot._manualWallpaperScaleOverride = 0
        }

        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && (bgRoot.lockBlurOptions.enable ?? false))
        property color dominantColor: Appearance.colors.colPrimary
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

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
                if (CompositorService.isHyprland && monitor && monitor.activeWorkspace) {
                    const wsId = monitor.activeWorkspace.id;
                    return relevantWindows.some(w => w.workspace.id === wsId);
                }
                return relevantWindows.length > 0;
            } catch (e) { return false; }
        }

        property bool focusWindowsPresent: !GlobalStates.screenLocked && hasWindowsOnCurrentWorkspace
        property real focusPresenceProgress: focusWindowsPresent ? 1 : 0
        Behavior on focusPresenceProgress {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        // Runtime invariant:
        // - _manualWallpaperScaleOverride is temporary and must return to 0 after reveal/metrics settle.
        // - _awwwRevealOpacity must return to 1 after each wallpaper transition.
        // - _blurTransitionFactor must return to 1 even if transitions overlap.
        // This avoids stale zoom/overlay artifacts during rapid wallpaper changes.

        // Blur suppression during wallpaper transitions — briefly fades blur out
        // so awww/crossfader transitions are visible, then fades back in.
        property real _blurTransitionFactor: 1
        property int _blurHoldDurationMs: 0
        function beginBlurSuppression(totalTransitionMs: int): void {
            if (bgRoot.blurProgress <= 0)
                return
            const holdMs = Math.max(0, totalTransitionMs)
            _blurTransitionAnimation.stop()
            bgRoot._blurTransitionFactor = 1
            bgRoot._blurHoldDurationMs = holdMs
            _blurTransitionAnimation.restart()
            _blurTransitionSafetyTimer.interval = holdMs + Appearance.calcEffectiveDuration(800)
            _blurTransitionSafetyTimer.restart()
        }
        SequentialAnimation {
            id: _blurTransitionAnimation
            NumberAnimation {
                target: bgRoot; property: "_blurTransitionFactor"
                to: 0; duration: Appearance.calcEffectiveDuration(200); easing.type: Easing.OutQuad
            }
            PauseAnimation {
                duration: bgRoot._blurHoldDurationMs
            }
            NumberAnimation {
                target: bgRoot; property: "_blurTransitionFactor"
                to: 1; duration: Appearance.calcEffectiveDuration(400); easing.type: Easing.InOutQuad
            }
        }
        Timer {
            id: _blurTransitionSafetyTimer
            interval: bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(1200)
            repeat: false
            onTriggered: bgRoot._blurTransitionFactor = 1
        }

        property real blurProgress: {
            const effects = bgRoot.effectsOptions;
            if (!(effects?.enableBlur && (effects?.blurRadius ?? 0) > 0)) return 0;
            return focusPresenceProgress * _blurTransitionFactor;
        }

        Connections {
            target: Wallpapers
            function onWallpaperBlurTransitionRequested(targetMonitors, durationMs): void {
                if (!targetMonitors || targetMonitors.length === 0 || targetMonitors.indexOf(bgRoot.monitorName) >= 0)
                    bgRoot.beginBlurSuppression(durationMs)
            }
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        // Keep background behind the lock surface. Moving this to Overlay can capture input.
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        anchors { top: true; bottom: true; left: true; right: true }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo) return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        onWallpaperPathChanged: {
            const normalizedPath = String(bgRoot.wallpaperPath ?? "")
            if (bgRoot.hasPan && bgRoot.externalMainWallpaperEligible) {
                bgRoot._panReadyWallpaperPath = ""
                panActivationTimer.restart()
            } else {
                bgRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
            }
            bgRoot.pauseParallaxForWallpaperTransition()
            if (bgRoot._awwwParallaxRevealNeeded) {
                // Instantly hide crossfader BEFORE bindings propagate the new source.
                // The crossfader swaps to the new wallpaper at opacity:0 (invisible).
                _awwwRevealAnimation.stop()
                bgRoot._awwwRevealOpacity = 0
                bgRoot._manualWallpaperScaleOverride = bgRoot.baseWallpaperScale
                _awwwRevealAnimation.restart()
                _awwwRevealSafetyTimer.interval = bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(900)
                _awwwRevealSafetyTimer.restart()
            } else {
                _awwwRevealAnimation.stop()
                _awwwRevealSafetyTimer.stop()
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
            }
            if (!Wallpapers._applyInProgress && bgRoot.blurProgress > 0) {
                bgRoot.beginBlurSuppression(bgRoot._wallpaperTransitionDurationMs)
            } else {
                _blurTransitionAnimation.stop()
                _blurTransitionSafetyTimer.stop()
                bgRoot._blurTransitionFactor = 1
            }
            bgRoot.updateZoomScale()
        }

        onHasPanChanged: {
            if (bgRoot.hasPan)
                return
            bgRoot._panReadyWallpaperPath = String(bgRoot.wallpaperPath ?? "")
            panActivationTimer.stop()
            bgRoot.updateZoomScale()
        }

        onPreferredWallpaperScaleChanged: {
            if (!bgRoot._awwwParallaxRevealNeeded) {
                bgRoot._manualWallpaperScaleOverride = 0
                return
            }
            if (_awwwRevealAnimation.running || bgRoot._awwwRevealOpacity < 1)
                bgRoot._manualWallpaperScaleOverride = bgRoot.baseWallpaperScale
        }

        onPanZoomChanged: {
            const normalizedPath = String(bgRoot.wallpaperPath ?? "")
            if (!bgRoot.hasPan) {
                bgRoot._panReadyWallpaperPath = normalizedPath
                panActivationTimer.stop()
                bgRoot.updateZoomScale()
                return
            }

            if (bgRoot.externalMainWallpaperEligible && bgRoot._panReadyWallpaperPath !== normalizedPath)
                return

            bgRoot._panReadyWallpaperPath = normalizedPath
            bgRoot.updateZoomScale()
        }

        function updateZoomScale(): void {
            wallpaperSizeDebounce.restart()
        }

        Timer {
            id: parallaxTransitionPauseTimer
            interval: bgRoot._wallpaperTransitionDurationMs + bgRoot.parallaxTransitionSettleMs
            repeat: false
            onTriggered: {
                bgRoot._parallaxWaitingCrossfader = false
                bgRoot._parallaxTransitionReason = ""
                bgRoot.parallaxTransitionActive = false
                parallaxResumeAnimation.restart()
            }
        }

        Connections {
            target: GlobalStates
            function onFamilyTransitionActiveChanged() {
                if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions)
                    return

                if (GlobalStates.familyTransitionActive) {
                    bgRoot.beginParallaxTransition(true, "family")
                    return
                }

                if (bgRoot._parallaxWaitingCrossfader && bgRoot._parallaxTransitionReason === "family")
                    bgRoot.settleParallaxAfterTransition()
            }
        }

        Timer {
            id: panActivationTimer
            interval: bgRoot._wallpaperTransitionDurationMs + 120
            repeat: false
            onTriggered: {
                const normalizedPath = String(bgRoot.wallpaperPath ?? "")
                bgRoot._panReadyWallpaperPath = normalizedPath
                if (bgRoot.hasPan)
                    bgRoot.updateZoomScale()
            }
        }

        NumberAnimation {
            id: parallaxResumeAnimation
            target: bgRoot
            property: "parallaxResumeProgress"
            from: 0
            to: 1
            duration: Appearance.calcEffectiveDuration(260)
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: _awwwRevealAnimation

            PauseAnimation {
                duration: AwwwBackend.transitionDurationMs + 400
            }
            NumberAnimation {
                target: bgRoot
                property: "_awwwRevealOpacity"
                to: 1
                duration: Appearance.calcEffectiveDuration(250)
                easing.type: Easing.OutQuad
            }
            onFinished: {
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
                _awwwRevealSafetyTimer.stop()
            }
            onStopped: {
                if (!_awwwRevealAnimation.running && bgRoot._awwwRevealOpacity >= 1)
                    bgRoot._manualWallpaperScaleOverride = 0
            }
        }
        Timer {
            id: _awwwRevealSafetyTimer
            interval: bgRoot._wallpaperTransitionDurationMs + Appearance.calcEffectiveDuration(900)
            repeat: false
            onTriggered: {
                bgRoot._awwwRevealOpacity = 1
                bgRoot._manualWallpaperScaleOverride = 0
            }
        }

        Timer {
            id: wallpaperSizeDebounce
            // Fire magick identify quickly so the result arrives while the
            // crossfader transition is still running.  The container has
            // Behavior on width/height/x/y so the resize blends smoothly
            // with the ongoing transition instead of snapping afterwards.
            interval: 80
            repeat: false
            onTriggered: {
                if (!bgRoot.wallpaperPath || bgRoot.wallpaperPath.length === 0) return;
                if (bgRoot.wallpaperIsVideo) return;
                if (bgRoot.wallpaperSafetyTriggered) return;

                // Check shared cache before spawning a subprocess
                const cached = root._wallpaperSizeCache[bgRoot.wallpaperPath]
                if (cached) {
                    bgRoot.wallpaperWidth = cached.width
                    bgRoot.wallpaperHeight = cached.height
                    bgRoot._manualWallpaperScaleOverride = 0
                    return
                }

                bgRoot.queueWallpaperMetricsUpdate(bgRoot.wallpaperPath)
            }
        }

        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["/usr/bin/magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const requestPath = bgRoot.activeWallpaperMetricsPath || getWallpaperSizeProc.path
                    const output = (wallpaperSizeOutputCollector.text ?? "").trim();
                    const parts = output.split(/\s+/).filter(Boolean);
                    const width = Number(parts[0]);
                    const height = Number(parts[1]);
                    const screenWidth = bgRoot.screen?.width ?? 0;
                    const screenHeight = bgRoot.screen?.height ?? 0;

                    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0 || screenWidth <= 0 || screenHeight <= 0) {
                        console.warn("[Background] Failed to parse wallpaper size:", output);
                        bgRoot._manualWallpaperScaleOverride = 0
                        bgRoot.finishWallpaperMetricsRequest()
                        return;
                    }

                    if (requestPath !== bgRoot.wallpaperPath) {
                        bgRoot.finishWallpaperMetricsRequest()
                        return
                    }

                    bgRoot.wallpaperWidth = Math.round(width);
                    bgRoot.wallpaperHeight = Math.round(height);
                    bgRoot._manualWallpaperScaleOverride = 0

                    // Cache the result so subsequent switches to this wallpaper skip magick identify
                    const cache = Object.assign({}, root._wallpaperSizeCache)
                    cache[requestPath] = { width: Math.round(width), height: Math.round(height) }
                    root._wallpaperSizeCache = cache

                    bgRoot.finishWallpaperMetricsRequest()
                }
            }
        }

        Item {
            anchors.fill: parent

            // Wallpaper container - used as reference for blur and widgets
            Item {
                id: wallpaperContainer
                property int chunkSize: bgRoot.usePerMonitorRange ?
                    (bgRoot.effectiveWorkspaceLast - bgRoot.effectiveWorkspaceFirst + 1) :
                    (Config?.options?.bar?.workspaces?.shown ?? 10)
                property int lower: bgRoot.usePerMonitorRange ?
                    bgRoot.effectiveWorkspaceFirst :
                    (Math.floor(bgRoot.firstWorkspaceId / chunkSize) * chunkSize)
                property int upper: bgRoot.usePerMonitorRange ?
                    bgRoot.effectiveWorkspaceLast :
                    (Math.ceil(bgRoot.lastWorkspaceId / chunkSize) * chunkSize)
                property int range: Math.max(1, upper - lower)
                property int currentWorkspaceId: CompositorService.isNiri ? (NiriService.focusedWorkspaceIndex ?? 1) : (bgRoot.monitor?.activeWorkspace?.id ?? 1)
                property real workspaceProgress: ParallaxMath.normalizedWorkspaceProgress(currentWorkspaceId, lower, upper)
                property real valueX: ParallaxMath.axisValue(
                    "horizontal",
                    bgRoot.parallaxAxis,
                    bgRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    bgRoot.parallaxWorkspaceShift,
                    bgRoot.sidebarParallaxEnabled,
                    [GlobalStates.sidebarLeftOpen],
                    [GlobalStates.sidebarRightOpen],
                    bgRoot.parallaxPanelShift
                )
                property real valueY: ParallaxMath.axisValue(
                    "vertical",
                    bgRoot.parallaxAxis,
                    bgRoot.workspaceParallaxEnabled,
                    workspaceProgress,
                    bgRoot.parallaxWorkspaceShift,
                    false,
                    [],
                    [],
                    0
                )
                property real effectiveValueX: Math.max(0, Math.min(1, valueX))
                property real effectiveValueY: Math.max(0, Math.min(1, valueY))
                
                readonly property bool useParallax: bgRoot.fillMode === "fill"
                    && !bgRoot.wallpaperIsGif
                    && !bgRoot.wallpaperIsVideo
                    && !bgRoot.externalMainWallpaperActive
                readonly property bool showInternalStaticWallpaper: !bgRoot.externalMainWallpaperActive
                readonly property real panOffsetX: bgRoot.effectiveHasPan ? (bgRoot.panX * (bgRoot.parallaxTotalX / 2)) : 0
                readonly property real panOffsetY: bgRoot.effectiveHasPan ? (bgRoot.panY * (bgRoot.parallaxTotalY / 2)) : 0
                readonly property real targetX: useParallax
                    ? (bgRoot.parallaxTotalX > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalX, activeValueX) + panOffsetX)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperWidth, bgRoot.screen.width))
                    : panOffsetX
                readonly property real targetY: useParallax
                    ? (bgRoot.parallaxTotalY > 0
                        ? (ParallaxMath.parallaxPosition(bgRoot.parallaxTotalY, activeValueY) + panOffsetY)
                        : ParallaxMath.centerOffset(bgRoot.scaledWallpaperHeight, bgRoot.screen.height))
                    : panOffsetY
                readonly property real targetWidth: (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperWidth : bgRoot.screen.width
                readonly property real targetHeight: (useParallax || bgRoot.effectiveHasPan) ? bgRoot.scaledWallpaperHeight : bgRoot.screen.height
                x: targetX
                y: targetY
                Behavior on x {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                            || bgRoot._parallaxWaitingCrossfader)
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                            || bgRoot._parallaxWaitingCrossfader)
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                width: targetWidth
                height: targetHeight
                // Animate container resize so it blends with the crossfader transition
                readonly property int _transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                readonly property int _transitionDur: Appearance.calcEffectiveDuration(_transitionBaseDuration)
                readonly property var _transitionBezierRaw: Config.options?.background?.transition?.bezier ?? [0.54, 0.0, 0.34, 0.99]
                readonly property list<real> _transitionBezierCurve: {
                    const raw = _transitionBezierRaw
                    if (!raw || raw.length !== 4)
                        return [0.54, 0.0, 0.34, 0.99, 1, 1]
                    const x1 = Number(raw[0])
                    const y1 = Number(raw[1])
                    const x2 = Number(raw[2])
                    const y2 = Number(raw[3])
                    if (!Number.isFinite(x1) || !Number.isFinite(y1) || !Number.isFinite(x2) || !Number.isFinite(y2))
                        return [0.54, 0.0, 0.34, 0.99, 1, 1]
                    return [x1, y1, x2, y2, 1, 1]
                }
                // Container resize is NOT animated during crossfader transitions.
                // The crossfader handles its own transition visually; animating the
                // container size simultaneously causes double-image artifacts.
                Behavior on width {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && bgRoot._awwwRevealOpacity >= 1
                        && !bgRoot.parallaxTransitionActive
                        && bgRoot.parallaxResumeProgress >= 1
                    NumberAnimation {
                        duration: wallpaperContainer._transitionDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: wallpaperContainer._transitionBezierCurve
                    }
                }
                Behavior on height {
                    enabled: Appearance.animationsEnabled
                        && (wallpaperContainer.useParallax || bgRoot.effectiveHasPan)
                        && bgRoot._awwwRevealOpacity >= 1
                        && !bgRoot.parallaxTransitionActive
                        && bgRoot.parallaxResumeProgress >= 1
                    NumberAnimation {
                        duration: wallpaperContainer._transitionDur
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: wallpaperContainer._transitionBezierCurve
                    }
                }

                readonly property real activeValueX: bgRoot.parallaxTransitionActive
                    ? bgRoot.parallaxFreezeValueX
                    : (bgRoot.parallaxFreezeValueX + ((effectiveValueX - bgRoot.parallaxFreezeValueX) * bgRoot.parallaxResumeProgress))
                readonly property real activeValueY: bgRoot.parallaxTransitionActive
                    ? bgRoot.parallaxFreezeValueY
                    : (bgRoot.parallaxFreezeValueY + ((effectiveValueY - bgRoot.parallaxFreezeValueY) * bgRoot.parallaxResumeProgress))

                // Static wallpaper — when awww manages the visible wallpaper
                // (externalMainWallpaperActive), this is just a hidden texture for blur.
                // Otherwise (parallax, unsupported fill mode, etc.), this is the visible
                // renderer and uses the user's transition settings.
                WallpaperCrossfader {
                    id: wallpaper
                    anchors.fill: parent
                    visible: !blurLoader.active && !bgRoot.backdropActive && !bgRoot.wallpaperIsGif && !bgRoot.wallpaperIsVideo
                    opacity: (wallpaperContainer.showInternalStaticWallpaper ? 1 : 0) * bgRoot._awwwRevealOpacity
                    layer.enabled: !wallpaperContainer.showInternalStaticWallpaper
                    source: (bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo || bgRoot.wallpaperIsGif) ? "" : bgRoot.wallpaperPath
                    // NEVER use crossfader transitions when awww is active — awww handles all transitions.
                    // When parallax is on, the crossfader fades out to reveal awww's native transition.
                    enableTransitions: !AwwwBackend.active
                        && (Config.options?.background?.transition?.enable ?? true)
                    transitionType: Config.options?.background?.transition?.type ?? "crossfade"
                    transitionDirection: Config.options?.background?.transition?.direction ?? "right"
                    transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                    fillMode: bgRoot.fillMode === "fit" ? Image.PreserveAspectFit
                            : bgRoot.fillMode === "tile" ? Image.Tile
                            : bgRoot.fillMode === "center" ? Image.Pad
                            : Image.PreserveAspectCrop
                    sourceSize {
                        width: Math.round((bgRoot.externalMainWallpaperActive ? bgRoot.screen.width : bgRoot.scaledWallpaperWidth) * (bgRoot.monitor?.scale ?? 1))
                        height: Math.round((bgRoot.externalMainWallpaperActive ? bgRoot.screen.height : bgRoot.scaledWallpaperHeight) * (bgRoot.monitor?.scale ?? 1))
                    }

                    onTransitionStarted: {
                        if (!bgRoot.dynamicParallaxRequested || !bgRoot.pauseParallaxDuringTransitions || AwwwBackend.active)
                            return
                        bgRoot.beginParallaxTransition(true, "wallpaper")
                    }

                    onTransitionFinished: {
                        if (bgRoot._parallaxWaitingCrossfader && bgRoot._parallaxTransitionReason === "wallpaper")
                            bgRoot.settleParallaxAfterTransition()
                    }
                }

                // Animated GIF wallpaper
                // Always loaded for GIFs: plays when animation enabled, frozen (first frame) when disabled
                AnimatedImage {
                    id: gifWallpaper
                    anchors.fill: parent
                    visible: opacity > 0 && !blurLoader.active && !bgRoot.backdropActive && bgRoot.wallpaperIsGif && !bgRoot.externalMainWallpaperActive
                    opacity: (status === AnimatedImage.Ready && bgRoot.wallpaperIsGif) ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    cache: false
                    playing: visible && bgRoot.enableAnimation && !GlobalStates.screenLocked && !Appearance._gameModeActive
                    asynchronous: true
                    source: (bgRoot.wallpaperSafetyTriggered || !bgRoot.wallpaperIsGif) ? "" : bgRoot.wallpaperPathRaw
                    fillMode: Image.PreserveAspectCrop
                    // No sourceSize for GIFs - let Qt handle native size for performance

                    layer.enabled: Appearance.effectsEnabled && (bgRoot.effectsOptions.enableAnimatedBlur ?? false) && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                    layer.effect: GaussianBlur {
                        radius: Math.round((bgRoot.effectsOptions.blurRadius ?? 32) * Math.max(0, Math.min(1, (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) / 100)))
                        samples: radius * 2 + 1
                    }
                }

                // Video wallpaper (Qt Multimedia)
                // Always loaded for videos: plays when animation enabled, frozen (paused) when disabled
                Video {
                    id: videoWallpaper
                    anchors.fill: parent
                    visible: opacity > 0 && !blurLoader.active && !bgRoot.backdropActive && bgRoot.wallpaperIsVideo
                    opacity: bgRoot.wallpaperIsVideo ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    source: {
                        if (bgRoot.wallpaperSafetyTriggered || !bgRoot.wallpaperIsVideo) return "";
                        const path = bgRoot.wallpaperPathRaw;
                        if (!path) return "";
                        return path.startsWith("file://") ? path : ("file://" + path);
                    }
                    fillMode: VideoOutput.PreserveAspectCrop
                    loops: MediaPlayer.Infinite
                    muted: true
                    autoPlay: true

                    readonly property bool shouldPlay: bgRoot.enableAnimation && !GlobalStates.screenLocked && !Appearance._gameModeActive && !GlobalStates.overviewOpen

                    function pauseAndShowFirstFrame() {
                        pause()
                        seek(0) // Ensure first frame is displayed when paused
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
                        if (visible && bgRoot.wallpaperIsVideo) {
                            if (shouldPlay) play()
                            else pauseAndShowFirstFrame()
                        }
                    }
                    
                    onVisibleChanged: {
                        if (visible && bgRoot.wallpaperIsVideo) {
                            if (shouldPlay) play()
                            else pauseAndShowFirstFrame()
                        } else {
                            pause()
                        }
                    }
                    
                    Connections {
                        target: GlobalStates
                        function onScreenLockedChanged() {
                            if (!videoWallpaper.shouldPlay) {
                                videoWallpaper.pauseAndShowFirstFrame()
                            } else if (videoWallpaper.visible && bgRoot.wallpaperIsVideo) {
                                videoWallpaper.play()
                            }
                        }
                    }

                    Connections {
                        target: GameMode
                        function onActiveChanged() {
                            if (!videoWallpaper.shouldPlay) {
                                videoWallpaper.pauseAndShowFirstFrame()
                            } else if (videoWallpaper.visible && bgRoot.wallpaperIsVideo) {
                                videoWallpaper.play()
                            }
                        }
                    }

                    layer.enabled: Appearance.effectsEnabled && (bgRoot.effectsOptions.enableAnimatedBlur ?? false) && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                    layer.effect: GaussianBlur {
                        radius: Math.round((bgRoot.effectsOptions.blurRadius ?? 32) * Math.max(0, Math.min(1, (bgRoot.effectsOptions.thumbnailBlurStrength ?? 50) / 100)))
                        samples: radius * 2 + 1
                    }
                }
            }

            // Always-on wallpaper blur — reads from crossfader texture (works with both QML and awww rendering; disabled for GIFs/videos)
            Loader {
                id: blurAlwaysLoader
                z: 1
                active: Appearance.effectsEnabled
                        && (bgRoot.blurProgress > 0)
                        && (bgRoot.effectsOptions.enableBlur ?? false)
                        && !Config.options?.performance?.lowPower
                        && (bgRoot.effectsOptions.blurRadius ?? 0) > 0
                        && !blurLoader.active
                        && !bgRoot.backdropActive
                        && !bgRoot.wallpaperIsGif
                        && !bgRoot.wallpaperIsVideo
                anchors.fill: wallpaperContainer
                sourceComponent: Item {
                    anchors.fill: parent
                    opacity: bgRoot.blurProgress

                    GaussianBlur {
                        anchors.fill: parent
                        source: wallpaper
                        radius: bgRoot.effectsOptions.blurRadius ?? 32
                        samples: radius * 2 + 1
                    }
                }
            }

            Loader {
                id: blurLoader
                z: 2
                active: (bgRoot.lockBlurOptions.enable ?? false) && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaperContainer
                scale: GlobalStates.screenLocked ? (bgRoot.lockBlurOptions.extraZoom ?? 1) : 1
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        id: scaleAnim
                        duration: Appearance.animation.elementMoveEnter.duration
                        easing.type: Appearance.animation.elementMoveEnter.type
                        easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaperContainer
                    radius: GlobalStates.screenLocked ? (bgRoot.lockBlurOptions.radius ?? 0) : 0
                    samples: radius * 2 + 1
                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            // Dimming overlay
            Rectangle {
                id: dimOverlay
                anchors.fill: parent
                visible: !bgRoot.backdropActive
                z: 10
                color: {
                    const effects = bgRoot.effectsOptions;
                    const baseSafe = Math.max(0, Math.min(100, Number(effects?.dim) || 0));
                    const dynSafe = Number(effects?.dynamicDim) || 0;
                    const extra = (!GlobalStates.screenLocked && bgRoot.focusPresenceProgress > 0) ? dynSafe * bgRoot.focusPresenceProgress : 0;
                    const total = Math.max(0, Math.min(100, baseSafe + extra));
                    return Qt.rgba(0, 0, 0, total / 100);
                }
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            // Desktop right-click context menu
            MouseArea {
                anchors.fill: parent
                z: 15  // Below WidgetCanvas (z: 20) so widgets can receive input
                acceptedButtons: Qt.RightButton
                onClicked: function(mouse) {
                    desktopMenuAnchor.x = mouse.x
                    desktopMenuAnchor.y = mouse.y
                    desktopContextMenu.active = true
                }
            }

            Item {
                id: desktopMenuAnchor
                z: 26
                width: 1; height: 1
            }

            ContextMenu {
                id: desktopContextMenu
                z: 27
                anchorItem: desktopMenuAnchor
                popupAbove: false
                closeOnFocusLost: false
                closeOnHoverLost: true
                model: [
                    { text: Translation.tr("Settings"), iconName: "settings", monochromeIcon: true,
                        action: () => { Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"]) } },
                    { type: "separator" },
                    { text: Translation.tr("Change wallpaper"), iconName: "image", monochromeIcon: true,
                        action: () => { GlobalActions.runLauncher(["wallpaperSelector", "toggle"]) } },
                    { text: Translation.tr("Screenshot"), iconName: "screenshot_monitor", monochromeIcon: true,
                        action: () => { GlobalStates.regionSelectorOpen = true } },
                    { type: "separator" },
                    { text: Translation.tr("Reload shell"), iconName: "refresh", monochromeIcon: true,
                        action: () => { Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")]) } }
                ]
            }

            WidgetCanvas {
                id: widgetCanvas
                z: 20
                enabled: !GlobalStates.screenLocked  // Disable all widget input during lock
                readonly property bool useParallax: wallpaperContainer.useParallax && !bgRoot.backdropActive
                anchors {
                    left: useParallax ? wallpaperContainer.left : parent.left
                    right: useParallax ? wallpaperContainer.right : parent.right
                    top: useParallax ? wallpaperContainer.top : parent.top
                    bottom: useParallax ? wallpaperContainer.bottom : parent.bottom
                    readonly property real parallaxFactor: bgRoot.parallaxWidgetDepth
                    leftMargin: useParallax ? (bgRoot.parallaxTotalX * wallpaperContainer.activeValueX * (1 - parallaxFactor)) : 0
                    topMargin: useParallax ? (bgRoot.parallaxTotalY * wallpaperContainer.activeValueY * (1 - parallaxFactor)) : 0
                    Behavior on leftMargin {
                        enabled: Appearance.animationsEnabled
                            && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                                || bgRoot._parallaxWaitingCrossfader)
                        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                    }
                    Behavior on topMargin {
                        enabled: Appearance.animationsEnabled
                            && ((!bgRoot.parallaxTransitionActive && bgRoot.parallaxResumeProgress >= 1)
                                || bgRoot._parallaxWaitingCrossfader)
                        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                    }
                }
                width: useParallax ? wallpaperContainer.width : parent.width
                height: useParallax ? wallpaperContainer.height : parent.height
                states: State {
                    name: "centered"
                    when: GlobalStates.screenLocked || bgRoot.wallpaperSafetyTriggered || bgRoot.backdropActive
                    PropertyChanges { target: widgetCanvas; width: parent.width; height: parent.height }
                    AnchorChanges { target: widgetCanvas; anchors { left: undefined; right: undefined; top: undefined; bottom: undefined } }
                }
                transitions: Transition {
                    PropertyAnimation { properties: "width,height"; duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                    AnchorAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

                FadeLoader {
                    shown: bgRoot.backgroundWidgetsOptions.weather?.enable ?? true
                    sourceComponent: WeatherWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: bgRoot.backgroundWidgetsOptions.clock?.enable ?? true
                    sourceComponent: ClockWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                    }
                }

                FadeLoader {
                    shown: bgRoot.backgroundWidgetsOptions.mediaControls?.enable ?? true
                    sourceComponent: MediaControlsWidget {
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }
            }
        }
    }
}
