pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

// Single cava process shared across all visualizers (waveform/spectrum widgets,
// media player cards, lock screen, background visualizer, etc).
//
// Before this service, every CavaProcess instance spawned its own subprocess
// even though they all read the same PipeWire stream with identical config —
// 2+ cava processes idle-running at ~1.4% CPU each. See #160.
//
// Consumers subscribe()/unsubscribe() to drive lifecycle. While `_subscribers > 0`
// one process runs; bars are broadcast via the `points` property.
//
// Framerate, sensitivity and sample count are global, so a single process
// satisfies every consumer with identical output. The internal process stays
// mono; standalone terminal Cava owns the user-facing stereo option.
Singleton {
    id: root

    property int _legacySubscribers: 0
    property var _sampleRequests: []
    property int _nextSampleRequestId: 1
    property bool _suppressConfigRestart: false
    readonly property int _subscribers: _legacySubscribers + _sampleRequests.length
    readonly property bool active: _subscribers > 0

    property list<real> points: []
    property real framePeak: 0
    property real frameAverage: 0
    property real normalizationCeiling: 100
    property bool audioSignalActive: false
    // Real PipeWire streams frequently peak in the 20-100 range even though
    // cava's ASCII output can represent 0-1000. Keep silence restrained without
    // flattening ordinary playback to a one-pixel line.
    readonly property real normalizationFloor: 20

    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_config.txt"
    readonly property string scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/generate_config.sh"

    // Mirror CavaProcess's previous config schema reading
    readonly property int cfgFramerate: Config.options?.appearance?.cava?.framerate ?? 60
    readonly property int cfgSensitivity: Config.options?.appearance?.cava?.sensitivity ?? 100
    readonly property int cfgBars: Config.options?.appearance?.cava?.bars ?? 0
    // The internal shell spectrum is a decorative full-width surface, not a
    // channel meter. Mono keeps every renderer populated even when a player or
    // browser exposes only one active channel. The standalone cava keeps its
    // user-configurable stereo setting in scripts/colors/modules/90-cava.sh.
    readonly property bool cfgStereo: false
    readonly property int requestedBars: {
        let requested = 0
        for (let i = 0; i < root._sampleRequests.length; ++i)
            requested = Math.max(requested, root._sampleRequests[i].bars ?? 0)
        return requested
    }
    readonly property int effectiveBars: {
        let count = root.cfgBars > 0
            ? Math.max(2, Math.round(root.cfgBars))
            : Math.min(320, Math.max(50, root.requestedBars))
        if (root.cfgStereo && count % 2 !== 0)
            count++
        return count
    }

    readonly property string playerDesktopEntry: {
        if (YtMusic.isPlaying)
            return "mpv ytmusic youtube-music"
        const player = MprisController.activePlayer
        return player?.desktopEntry || player?.identity || "__inir_music_player__"
    }

    function _afterSubscriptionChange(wasActive: bool): void {
        if (!wasActive && root.active) {
            stopDebounce.stop()
            frameClear.stop()
            if (!cavaProc.running && !configGen.running)
                configGen.running = true
        } else if (wasActive && !root.active) {
            stopDebounce.restart()
        }
    }

    function subscribe(requestedBars): int {
        const wasActive = root.active
        if (requestedBars === undefined) {
            root._legacySubscribers++
            root._afterSubscriptionChange(wasActive)
            return 0
        }

        const requestId = root._nextSampleRequestId++
        const previousBars = root.effectiveBars
        const next = root._sampleRequests.slice()
        next.push({
            id: requestId,
            bars: Math.max(0, Math.round(Number(requestedBars) || 0))
        })
        root._suppressConfigRestart = true
        root._sampleRequests = next
        root._suppressConfigRestart = false
        root._afterSubscriptionChange(wasActive)
        if (wasActive && root.active && root.effectiveBars !== previousBars)
            configRestart.restart()
        return requestId
    }

    function updateSubscription(requestId: int, requestedBars): void {
        if (requestId <= 0)
            return
        const previousBars = root.effectiveBars
        const bars = Math.max(0, Math.round(Number(requestedBars) || 0))
        const next = root._sampleRequests.map(request =>
            request.id === requestId ? { id: request.id, bars: bars } : request)
        root._suppressConfigRestart = true
        root._sampleRequests = next
        root._suppressConfigRestart = false
        if (root.active && root.effectiveBars !== previousBars)
            configRestart.restart()
    }

    function unsubscribe(requestId): void {
        const wasActive = root.active
        const previousBars = root.effectiveBars
        if (requestId === undefined || requestId === 0) {
            root._legacySubscribers = Math.max(0, root._legacySubscribers - 1)
        } else {
            root._suppressConfigRestart = true
            root._sampleRequests = root._sampleRequests.filter(request => request.id !== requestId)
            root._suppressConfigRestart = false
        }
        root._afterSubscriptionChange(wasActive)
        if (wasActive && root.active && root.effectiveBars !== previousBars)
            configRestart.restart()
    }

    // Live config changes — restart cava with new parameters
    onCfgFramerateChanged: if (active) configRestart.restart()
    onCfgSensitivityChanged: if (active) configRestart.restart()
    onEffectiveBarsChanged: if (active && !root._suppressConfigRestart) configRestart.restart()
    onPlayerDesktopEntryChanged: if (active) sourceRefresh.restart()

    onPointsChanged: {
        if (root.points.length === 0) {
            root.framePeak = 0
            root.frameAverage = 0
            root.normalizationCeiling = root.normalizationFloor
            if (!root._pendingRestart && root.audioSignalActive)
                signalRelease.restart()
            return
        }

        let peak = 0
        let sum = 0
        for (let i = 0; i < root.points.length; ++i) {
            const value = Number(root.points[i]) || 0
            peak = Math.max(peak, value)
            sum += value
        }
        root.framePeak = peak
        root.frameAverage = sum / root.points.length

        const target = Math.max(root.normalizationFloor, peak * 1.15)
        root.normalizationCeiling = target >= root.normalizationCeiling
            ? target
            : Math.max(root.normalizationFloor, root.normalizationCeiling * 0.995)

        if (peak >= 2 || root.frameAverage >= 0.35) {
            signalRelease.stop()
            root.audioSignalActive = true
        } else if (root.audioSignalActive && !signalRelease.running) {
            signalRelease.restart()
        }
    }

    property bool _pendingRestart: false

    Connections {
        target: MprisController
        function onTrackChanged(): void {
            if (root.active)
                sourceRefresh.restart()
        }
    }

    Connections {
        target: YtMusic
        function onCurrentVideoIdChanged(): void {
            if (root.active)
                sourceRefresh.restart()
        }
    }

    Timer {
        id: sourceRefresh
        interval: 800
        repeat: false
        onTriggered: if (root.active) configRestart.restart()
    }

    Timer {
        id: signalRelease
        interval: 1800
        repeat: false
        onTriggered: root.audioSignalActive = false
    }

    Timer {
        id: frameClear
        interval: 2600
        repeat: false
        onTriggered: {
            if (!root.active && !cavaProc.running) {
                root.points = []
                root.framePeak = 0
                root.frameAverage = 0
                root.normalizationCeiling = root.normalizationFloor
            }
        }
    }

    Timer {
        id: configRestart
        interval: 300
        onTriggered: {
            if (cavaProc.running) {
                root._pendingRestart = true
                cavaProc.running = false
            } else if (root.active) {
                configGen.running = true
            }
        }
    }

    // Defer process teardown so brief unsubscribe/subscribe cycles
    // (e.g. panel close + immediate reopen) don't churn the subprocess.
    Timer {
        id: stopDebounce
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.active) {
                root._pendingRestart = false
                configGen.running = false
                cavaProc.running = false
                signalRelease.restart()
                frameClear.restart()
            }
        }
    }

    Process {
        id: configGen
        running: false
        command: ["/usr/bin/bash", root.scriptPath, root.configPath,
            String(root.cfgFramerate), String(root.cfgSensitivity),
            String(root.effectiveBars), String(root.cfgStereo),
            root.playerDesktopEntry]
        onExited: (code, status) => {
            if (code === 0 && root.active)
                cavaProc.running = true
            else if (root.active) {
                signalRelease.restart()
                frameClear.restart()
            }
        }
    }

    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root.configPath]
        onRunningChanged: {
            if (!running) {
                if (root._pendingRestart && root.active) {
                    root._pendingRestart = false
                    configGen.running = true
                } else if (root.active) {
                    signalRelease.restart()
                    sourceRefresh.restart()
                } else if (!root.active) {
                    signalRelease.restart()
                    frameClear.restart()
                }
            }
        }
        stdout: SplitParser {
            onRead: data => {
                const fields = data.split(";")
                const parsed = []
                for (let i = 0; i < fields.length; ++i) {
                    const value = parseFloat(fields[i])
                    if (!isNaN(value))
                        parsed.push(value)
                }
                root.points = parsed
            }
        }
    }
}
