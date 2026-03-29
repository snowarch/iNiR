pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    readonly property string provider: "awww"
    readonly property bool enabled: true
    readonly property int transitionFps: Config.options?.background?.backend?.awww?.transitionFps ?? 60
    readonly property int simpleStep: Config.options?.background?.backend?.awww?.simpleStep ?? 5
    readonly property int spatialStep: Config.options?.background?.backend?.awww?.spatialStep ?? 30
    readonly property bool _usingWaffleOwnWallpaper: panelFamily === "waffle" && !waffleUsesMainWallpaper
    readonly property var _waffleTransition: Config.options?.waffles?.background?.transition ?? {}
    readonly property int transitionDurationMs: _usingWaffleOwnWallpaper
        ? (_waffleTransition.duration ?? 800)
        : (Config.options?.background?.transition?.duration ?? 800)
    readonly property var transitionBezier: Config.options?.background?.transition?.bezier ?? [0.54, 0.0, 0.34, 0.99]
    readonly property bool transitionsEnabled: _usingWaffleOwnWallpaper
        ? (_waffleTransition.enable ?? true)
        : (Config.options?.background?.transition?.enable ?? true)
    readonly property string transitionType: _usingWaffleOwnWallpaper
        ? (_waffleTransition.type ?? "crossfade")
        : (Config.options?.background?.transition?.type ?? "crossfade")
    readonly property string transitionDirection: _usingWaffleOwnWallpaper
        ? (_waffleTransition.direction ?? "right")
        : (Config.options?.background?.transition?.direction ?? "right")
    readonly property string fillMode: Config.options?.background?.fillMode ?? "fill"
    readonly property bool animationEnabled: Config.options?.background?.enableAnimation ?? true
    readonly property string panelFamily: Config.options?.panelFamily ?? "ii"
    readonly property bool hideMainWallpaper: panelFamily === "waffle"
        ? (Config.options?.waffles?.background?.backdrop?.hideWallpaper ?? false)
        : (Config.options?.background?.backdrop?.hideWallpaper ?? false)
    readonly property bool waffleUsesMainWallpaper: Config.options?.waffles?.background?.useMainWallpaper ?? true
    readonly property string waffleWallpaperPath: Config.options?.waffles?.background?.wallpaperPath ?? ""
    readonly property bool multiMonitorEnabled: WallpaperListener.multiMonitorEnabled
    readonly property var effectivePerMonitor: WallpaperListener.effectivePerMonitor
    readonly property string globalWallpaperPath: Config.options?.background?.wallpaperPath ?? ""

    property bool clientAvailable: false
    property bool daemonAvailable: false
    property bool probing: false
    property string lastSyncSignature: ""
    property string lastError: ""
    property bool warnedMissing: false
    property bool stoppedForNoOutputs: false
    property bool _queuedStopAfterApply: false

    readonly property bool available: clientAvailable && daemonAvailable
    readonly property bool active: enabled && available

    function supportsMainWallpaper(path: string): bool {
        const cleanPath = FileUtils.trimFileProtocol(String(path ?? ""))
        if (!active || cleanPath.length === 0)
            return false
        if (WallpaperListener.isVideoPath(cleanPath))
            return false
        if (WallpaperListener.isGifPath(cleanPath))
            return false
        return true
    }

    function supportsFillMode(fillModeValue: string): bool {
        return fillModeValue === "fill" || fillModeValue === "fit" || fillModeValue === "center"
    }

    function resizeModeForFillMode(fillModeValue: string): string {
        switch (fillModeValue) {
        case "fit":
            return "fit"
        case "center":
            return "no"
        case "tile":
            return "crop"
        default:
            return "crop"
        }
    }

    function supportsVisibleMainWallpaper(path: string, fillModeValue: string, dynamicParallax: bool, allowAnimatedEffects: bool): bool {
        if (!supportsMainWallpaper(path))
            return false
        if (dynamicParallax)
            return false
        if (WallpaperListener.isGifPath(FileUtils.trimFileProtocol(String(path ?? ""))) && allowAnimatedEffects)
            return false
        return supportsFillMode(fillModeValue)
    }

    function scheduleSync(): void {
        syncDebounce.restart()
    }

    function isAwwwNativeTransitionType(type): bool {
        return ["none", "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "any", "outer", "random"].includes(String(type ?? ""))
    }

    function normalizedAwwwTransitionType(type, directionValue = transitionDirection): string {
        const rawType = String(type ?? "crossfade")
        if (isAwwwNativeTransitionType(rawType))
            return rawType
        switch (rawType) {
        case "crossfade":
        case "fadeThrough":
        case "blurFade":
            return "fade"
        case "zoom":
            return "center"
        case "wipe":
            return "wipe"
        case "slide":
        case "push":
            return ["left", "right", "top", "bottom"].includes(directionValue) ? directionValue : "right"
        default:
            return "simple"
        }
    }

    function _mappedTransitionType(): string {
        if (!transitionsEnabled)
            return "none"
        return normalizedAwwwTransitionType(transitionType, transitionDirection)
    }

    function _mappedTransitionStep(): int {
        if (!transitionsEnabled)
            return 255
        const mappedType = _mappedTransitionType()
        return mappedType === "simple" || mappedType === "fade" || mappedType === "none"
            ? Math.max(1, simpleStep)
            : Math.max(1, spatialStep)
    }

    function _mappedTransitionDuration(): real {
        return Math.max(0, transitionDurationMs) / 1000
    }

    function _mappedTransitionBezier(): string {
        const raw = transitionBezier
        if (!raw || raw.length !== 4)
            return ".54,0,.34,.99"

        const values = []
        for (let index = 0; index < 4; index++) {
            const value = Number(raw[index])
            if (!Number.isFinite(value))
                return ".54,0,.34,.99"
            values.push(String(value))
        }
        return values.join(",")
    }

    function _mappedTransitionAngle(): int {
        switch (transitionDirection) {
        case "left":
            return 180
        case "top":
            return 90
        case "bottom":
            return 270
        default:
            return 0
        }
    }

    function _desiredOutputMap() {
        if (hideMainWallpaper)
            return {}

        const result = {}
        for (const screen of Quickshell.screens) {
            const monitorName = WallpaperListener.getMonitorName(screen)
            if (!monitorName)
                continue

            const monitorData = multiMonitorEnabled ? (effectivePerMonitor[monitorName] ?? null) : null
            const usingWaffleCustomWallpaper = panelFamily === "waffle" && !waffleUsesMainWallpaper
            const rawPath = usingWaffleCustomWallpaper
                ? waffleWallpaperPath
                : (monitorData && monitorData.path ? monitorData.path : globalWallpaperPath)
            const cleanPath = FileUtils.trimFileProtocol(String(rawPath ?? ""))
            if (!supportsMainWallpaper(cleanPath))
                continue
            result[monitorName] = cleanPath
        }
        return result
    }

    function _signatureFor(map): string {
        const keys = Object.keys(map).sort()
        return JSON.stringify({
            provider: provider,
            fillMode: fillMode,
            resizeMode: resizeModeForFillMode(fillMode),
            transitionType: _mappedTransitionType(),
            transitionDuration: _mappedTransitionDuration(),
            transitionBezier: _mappedTransitionBezier(),
            transitionAngle: _mappedTransitionAngle(),
            transitionFps: Math.max(1, transitionFps),
            transitionStep: _mappedTransitionStep(),
            outputs: keys.map(key => ({ output: key, path: map[key] }))
        })
    }

    function _probe(): void {
        if (probeProc.running)
            return
        probing = true
        probeProc.running = true
    }

    function _syncNow(): void {
        if (!enabled) {
            if (stopProc.running)
                return
            if (available)
                stopProc.running = true
            lastSyncSignature = ""
            return
        }

        if (!available) {
            _probe()
            if (!warnedMissing) {
                console.warn("[AwwwBackend] awww backend selected but binaries are unavailable")
                warnedMissing = true
            }
            return
        }

        warnedMissing = false
        const outputMap = _desiredOutputMap()
        const keys = Object.keys(outputMap)
        if (keys.length === 0) {
            if (applyProc.running) {
                root._queuedStopAfterApply = true
                applyProc._queuedSignature = ""
                applyProc._queuedCommand = []
                return
            }
            if (!stoppedForNoOutputs && !stopProc.running)
                stopProc.running = true
            return
        }

        root._queuedStopAfterApply = false
        stoppedForNoOutputs = false
        const signature = _signatureFor(outputMap)
        if (signature === lastSyncSignature && !lastError)
            return

        // If applyProc is already running with this exact signature, don't
        // kill the in-progress transition just to restart the same one.
        if (applyProc.running && applyProc._pendingSignature === signature)
            return

        const transitionName = _mappedTransitionType()
        const resizeMode = resizeModeForFillMode(fillMode)
        const fps = Math.max(1, transitionFps)
        const step = _mappedTransitionStep()
        const duration = _mappedTransitionDuration()
        const bezier = _mappedTransitionBezier()
        const angle = _mappedTransitionAngle()
        const lines = [
            "if ! pgrep -x awww-daemon >/dev/null 2>&1; then nohup awww-daemon >/dev/null 2>&1 & sleep 0.35; fi"
        ]

        for (const key of keys) {
            const escapedOutput = StringUtils.shellSingleQuoteEscape(key)
            const escapedPath = StringUtils.shellSingleQuoteEscape(outputMap[key])
            let command = "awww img --outputs '" + escapedOutput + "' --resize '" + resizeMode + "' --transition-type '" + transitionName + "' --transition-fps " + fps + " --transition-step " + step
            if (transitionName !== "simple" && transitionName !== "none")
                command += " --transition-duration " + duration
            if (transitionName === "fade")
                command += " --transition-bezier '" + bezier + "'"
            if (transitionName === "wipe" || transitionName === "wave")
                command += " --transition-angle " + angle
            command += " '" + escapedPath + "'"
            lines.push(command)
        }

        if (applyProc.running) {
            applyProc._queuedSignature = signature
            applyProc._queuedCommand = ["/usr/bin/bash", "-lc", lines.join("\n")]
            return
        }

        lastError = ""
        stoppedForNoOutputs = false
        applyProc._queuedSignature = ""
        applyProc._queuedCommand = []
        applyProc.command = ["/usr/bin/bash", "-lc", lines.join("\n")]
        applyProc._pendingSignature = signature
        applyProc.running = true
    }

    Process {
        id: probeProc
        command: ["/usr/bin/bash", "-lc", "if command -v awww >/dev/null 2>&1; then echo client; fi; if command -v awww-daemon >/dev/null 2>&1; then echo daemon; fi"]
        stdout: StdioCollector {
            id: probeStdout
        }
        onExited: {
            const text = (probeStdout.text ?? "")
            root.clientAvailable = text.indexOf("client") >= 0
            root.daemonAvailable = text.indexOf("daemon") >= 0
            root.probing = false
            if (root.available)
                syncDebounce.restart()
        }
    }

    Process {
        id: applyProc
        property string _pendingSignature: ""
        property string _queuedSignature: ""
        property var _queuedCommand: []
        stdout: StdioCollector {
            id: applyStdout
        }
        stderr: StdioCollector {
            id: applyStderr
        }
        onExited: (exitCode) => {
            const queuedSignature = applyProc._queuedSignature
            const queuedCommand = applyProc._queuedCommand
            const shouldStopAfterApply = root._queuedStopAfterApply

            if (exitCode === 0) {
                root.lastSyncSignature = applyProc._pendingSignature
                root.lastError = ""
            } else {
                root.lastError = (applyStderr.text ?? applyStdout.text ?? "").trim()
                if (root.lastError.length === 0)
                    root.lastError = "awww apply failed"
                console.warn("[AwwwBackend]", root.lastError)
            }

            applyProc._pendingSignature = ""
            applyProc._queuedSignature = ""
            applyProc._queuedCommand = []

            if (shouldStopAfterApply) {
                root._queuedStopAfterApply = false
                if (!stopProc.running)
                    stopProc.running = true
                return
            }

            root._queuedStopAfterApply = false

            if (queuedSignature !== "" && queuedCommand.length > 0
                    && (queuedSignature !== root.lastSyncSignature || root.lastError !== "")) {
                root.lastError = ""
                applyProc.command = queuedCommand
                applyProc._pendingSignature = queuedSignature
                applyProc.running = true
            }
        }
    }

    Process {
        id: stopProc
        command: ["/usr/bin/bash", "-lc", "command -v awww >/dev/null 2>&1 && awww kill >/dev/null 2>&1 || true"]
        onExited: {
            root.lastSyncSignature = ""
            root.lastError = ""
            root.stoppedForNoOutputs = true
        }
    }

    Timer {
        id: syncDebounce
        interval: 180
        onTriggered: root._syncNow()
    }

    onEnabledChanged: syncDebounce.restart()
    onAvailableChanged: syncDebounce.restart()
    onGlobalWallpaperPathChanged: syncDebounce.restart()
    onPanelFamilyChanged: syncDebounce.restart()
    onWaffleUsesMainWallpaperChanged: syncDebounce.restart()
    onWaffleWallpaperPathChanged: syncDebounce.restart()
    onEffectivePerMonitorChanged: syncDebounce.restart()
    onMultiMonitorEnabledChanged: syncDebounce.restart()
    onHideMainWallpaperChanged: syncDebounce.restart()
    onTransitionTypeChanged: syncDebounce.restart()
    onTransitionDirectionChanged: syncDebounce.restart()
    onTransitionsEnabledChanged: syncDebounce.restart()
    onTransitionDurationMsChanged: syncDebounce.restart()
    onTransitionBezierChanged: syncDebounce.restart()
    onTransitionFpsChanged: syncDebounce.restart()
    onSimpleStepChanged: syncDebounce.restart()
    onSpatialStepChanged: syncDebounce.restart()
    onFillModeChanged: syncDebounce.restart()
    onAnimationEnabledChanged: syncDebounce.restart()

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.scheduleSync()
        }
    }

    Component.onCompleted: {
        root._probe()
        syncDebounce.restart()
    }
}
