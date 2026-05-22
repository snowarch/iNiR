import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services

Item {
    id: root

    property bool active: false
    property list<real> points: []
    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_config.txt"
    readonly property string scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/generate_config.sh"

    // Read user config with fallbacks matching Config.qml schema defaults
    readonly property int cfgFramerate: Config.options?.appearance?.cava?.framerate ?? 60
    readonly property int cfgSensitivity: Config.options?.appearance?.cava?.sensitivity ?? 100
    readonly property int cfgBars: Config.options?.appearance?.cava?.bars ?? 0
    readonly property bool cfgStereo: Config.options?.appearance?.cava?.stereo ?? true

    // Bars: 0 means auto — use 50 as a sensible widget default
    readonly property int effectiveBars: cfgBars > 0 ? cfgBars : 50

    readonly property string playerDesktopEntry: {
        if (MprisController.isYtMusicActive && YtMusic.currentVideoId)
            return "mpv"
        return MprisController.activePlayer?.desktopEntry ?? ""
    }

    // Restart cava when config changes while active
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
            } else {
                configGen.running = true
            }
        }
    }

    onActiveChanged: {
        if (active) {
            stopDebounce.stop()
            if (cavaProc.running || configGen.running) return
            configGen.running = true
        } else {
            stopDebounce.restart()
        }
    }

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
    Component.onDestruction: {
        cavaProc.running = false
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
                if (root._pendingRestart) {
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
