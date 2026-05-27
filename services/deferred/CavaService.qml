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
// Config (framerate/sensitivity/bars/stereo) is global, so a single process
// satisfies every consumer with identical output. Per-consumer rendering
// (colors, scale, bar count downsample) happens in the widget layer.
Singleton {
    id: root

    property int _subscribers: 0
    readonly property bool active: _subscribers > 0

    property list<real> points: []

    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_config.txt"
    readonly property string scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/generate_config.sh"

    // Mirror CavaProcess's previous config schema reading
    readonly property int cfgFramerate: Config.options?.appearance?.cava?.framerate ?? 60
    readonly property int cfgSensitivity: Config.options?.appearance?.cava?.sensitivity ?? 100
    readonly property int cfgBars: Config.options?.appearance?.cava?.bars ?? 0
    readonly property bool cfgStereo: Config.options?.appearance?.cava?.stereo ?? true
    readonly property int effectiveBars: cfgBars > 0 ? cfgBars : 50

    readonly property string playerDesktopEntry: {
        if (MprisController.isYtMusicActive && YtMusic.currentVideoId)
            return "mpv"
        return MprisController.activePlayer?.desktopEntry ?? ""
    }

    function subscribe(): void {
        _subscribers++
        if (_subscribers === 1) {
            stopDebounce.stop()
            if (!cavaProc.running && !configGen.running)
                configGen.running = true
        }
    }

    function unsubscribe(): void {
        _subscribers = Math.max(0, _subscribers - 1)
        if (_subscribers === 0)
            stopDebounce.restart()
    }

    // Live config changes — restart cava with new parameters
    onCfgFramerateChanged: if (active) configRestart.restart()
    onCfgSensitivityChanged: if (active) configRestart.restart()
    onCfgBarsChanged: if (active) configRestart.restart()
    onCfgStereoChanged: if (active) configRestart.restart()
    onPlayerDesktopEntryChanged: if (active) configRestart.restart()

    property bool _pendingRestart: false

    Connections {
        target: MprisController
        function onTrackChanged(): void {
            if (root.active) configRestart.restart()
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
                root.points = []
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
        }
    }

    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root.configPath]
        onRunningChanged: {
            if (!running) {
                root.points = []
                if (root._pendingRestart && root.active) {
                    root._pendingRestart = false
                    configGen.running = true
                }
            }
        }
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }
}
