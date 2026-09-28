pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.services

/**
 * Handles EasyEffects active state and presets.
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false
    property bool nativeInstalled: false
    property bool equalizerLoading: false
    property bool equalizerServerAvailable: false
    property bool equalizerPluginAvailable: false
    property bool equalizerSupported: true
    property int equalizerBandCount: 0
    property int equalizerInstanceId: -1
    property bool equalizerSplitChannels: false
    property bool equalizerBypassed: false
    property var equalizerBands: []
    property string equalizerError: ""
    property string equalizerPreset: "Custom"
    property var _equalizerCommandQueue: []

    readonly property bool equalizerReady: root.equalizerServerAvailable
        && root.equalizerPluginAvailable
        && root.equalizerSupported
        && root.equalizerBandCount === 10
        && root.equalizerBands.length === 10
    readonly property string equalizerScript: Quickshell.shellPath("scripts/audio/easyeffects-eq.sh")

    readonly property var equalizerPresets: ({
        "Flat": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass": [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        "Treble": [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
        "Vocal": [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        "Pop": [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
        "Rock": [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        "Jazz": [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
        "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })

    function _detectEqualizerPreset(): string {
        if (!root.equalizerReady) return "Custom"
        const names = Object.keys(root.equalizerPresets)
        for (const name of names) {
            const expected = root.equalizerPresets[name]
            let matches = true
            for (let i = 0; i < 10; i++) {
                const actual = Number(root.equalizerBands[i]?.gain ?? 0)
                if (Math.abs(actual - expected[i]) > 0.15) {
                    matches = false
                    break
                }
            }
            if (matches) return name
        }
        return "Custom"
    }

    function _applyEqualizerState(rawText: string): void {
        const text = String(rawText ?? "").trim()
        if (!text) {
            root.equalizerLoading = false
            root.equalizerError = "empty_response"
            return
        }
        try {
            const state = JSON.parse(text)
            root.equalizerServerAvailable = state.serverAvailable === true
            root.equalizerPluginAvailable = state.pluginAvailable === true
            root.equalizerSupported = state.supported !== false
            root.equalizerInstanceId = Number(state.instanceId ?? -1)
            root.equalizerBandCount = Number(state.numBands ?? 0)
            root.equalizerSplitChannels = state.splitChannels === true
            root.equalizerBypassed = state.bypassed === true
            root.equalizerBands = Array.isArray(state.bands) ? state.bands : []
            root.equalizerError = String(state.error ?? "")
            root.equalizerPreset = root._detectEqualizerPreset()
        } catch (e) {
            root.equalizerError = "invalid_response"
        }
        root.equalizerLoading = false
    }

    function refreshEqualizer(): void {
        if (equalizerReadProc.running) return
        root.equalizerLoading = true
        equalizerReadProc.command = [root.equalizerScript, "get"]
        equalizerReadProc.running = true
    }

    function ensureEqualizer(): void {
        if (equalizerReadProc.running) return
        root.equalizerLoading = true
        equalizerReadProc.command = [root.equalizerScript, "bootstrap"]
        equalizerReadProc.running = true
    }

    function _runEqualizerCommand(args: var): void {
        if (!Array.isArray(args) || args.length === 0) return
        if (equalizerWriteProc.running) {
            root._equalizerCommandQueue = [...root._equalizerCommandQueue, args]
            return
        }
        equalizerWriteProc.command = [root.equalizerScript, ...args]
        root.equalizerLoading = true
        equalizerWriteProc.running = true
    }

    function setEqualizerBand(index: int, gain: real): void {
        if (!root.equalizerReady || index < 0 || index >= 10) return
        const next = root.equalizerBands.map(b => Object.assign({}, b))
        if (next[index]) next[index].gain = gain
        root.equalizerBands = next
        root.equalizerPreset = root._detectEqualizerPreset()
        root._runEqualizerCommand(["set-band", String(index), String(gain)])
    }

    function applyEqualizerPreset(name: string): void {
        if (!root.equalizerReady || !root.equalizerPresets[name]) return
        const expected = root.equalizerPresets[name]
        const next = root.equalizerBands.map((band, i) => Object.assign({}, band, { gain: expected[i] }))
        root.equalizerBands = next
        root.equalizerPreset = name
        root._runEqualizerCommand(["preset", name])
    }

    function configureTenBandEqualizer(): void {
        if (!root.equalizerPluginAvailable || !root.equalizerSupported) return
        root._runEqualizerCommand(["configure"])
    }

    function openWindow(): void {
        if (root.nativeInstalled) {
            Quickshell.execDetached(["easyeffects"])
        } else if (root.available) {
            Quickshell.execDetached(["flatpak", "run", "com.github.wwmm.easyeffects"])
        }
    }

    function fetchAvailability() {
        if (whichProc.running || flatpakInfoProc.running) return
        whichProc.running = true
    }

    function fetchActiveState() {
        if (!root.available) {
            root.active = false
            return
        }
        if (root.nativeInstalled) {
            if (nativeStatusProc.running) return
            nativeStatusProc.running = true
            return
        }
        if (flatpakPsProc.running) return
        flatpakPsProc.running = true
    }

    function disable() {
        if (!root.available) return
        root.active = false
        if (pkillProc.running || flatpakKillProc.running) return
        pkillProc.running = true
    }

    function enable() {
        if (!root.available) return
        root.active = true
        if (root.nativeInstalled) {
            Quickshell.execDetached(["easyeffects", "--service-mode"])
        } else {
            Quickshell.execDetached(["flatpak", "run", "com.github.wwmm.easyeffects", "--service-mode"])
        }
        refreshStateTimer.restart()
    }

    function toggle() {
        if (root.active) {
            root.disable()
        } else {
            root.enable()
        }
    }

    Timer {
        id: initTimer
        interval: 1200
        repeat: false
        onTriggered: {
            root.fetchAvailability()
            root.fetchActiveState()
        }
    }

    Timer {
        id: refreshStateTimer
        interval: 900
        repeat: false
        onTriggered: root.fetchActiveState()
    }

    Timer {
        id: statePollTimer
        interval: 5000
        repeat: true
        running: Config.ready && root.available
        onTriggered: root.fetchActiveState()
    }

    Component.onCompleted: {
        if (Config.ready) {
            initTimer.start()
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                initTimer.start()
            }
        }
    }

    Process {
        id: whichProc
        running: false
        command: ["sh", "-c", "command -v easyeffects >/dev/null 2>&1"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.nativeInstalled = true
                root.available = true
            } else {
                root.nativeInstalled = false
                flatpakInfoProc.running = true
            }
        }
    }

    Process {
        id: flatpakInfoProc
        running: false
        command: ["/bin/sh", "-c", "flatpak info com.github.wwmm.easyeffects"]
        onExited: (exitCode, exitStatus) => {
            root.nativeInstalled = false
            root.available = (exitCode === 0)
        }
    }

    Process {
        id: nativeStatusProc
        running: false
        command: ["pgrep", "-x", "easyeffects"]
        onExited: (exitCode, _exitStatus) => {
            root.active = (exitCode === 0)
        }
    }

    Process {
        id: flatpakPsProc
        running: false
        command: ["/bin/sh", "-c", "flatpak ps --columns=application"]
        stdout: StdioCollector {
            id: flatpakPsCollector
            onStreamFinished: {
                const t = (flatpakPsCollector.text ?? "")
                root.active = t.split("\n").some(l => l.trim().includes("com.github.wwmm.easyeffects"))
            }
        }
    }

    Process {
        id: pkillProc
        running: false
        command: ["pkill", "easyeffects"]
        onExited: (_exitCode, _exitStatus) => {
            flatpakKillProc.running = true
            refreshStateTimer.restart()
        }
    }

    Process {
        id: flatpakKillProc
        running: false
        command: ["/bin/sh", "-c", "flatpak kill com.github.wwmm.easyeffects"]
        onExited: (_exitCode, _exitStatus) => refreshStateTimer.restart()
    }

    Process {
        id: equalizerReadProc
        running: false
        command: [root.equalizerScript, "get"]
        stdout: StdioCollector {
            id: equalizerReadCollector
            onStreamFinished: root._applyEqualizerState(equalizerReadCollector.text)
        }
        onExited: (_exitCode, _exitStatus) => {
            if (root.equalizerLoading && !String(equalizerReadCollector.text ?? "").trim())
                root.equalizerLoading = false
        }
    }

    Process {
        id: equalizerWriteProc
        running: false
        command: [root.equalizerScript, "get"]
        stdout: StdioCollector {
            id: equalizerWriteCollector
            onStreamFinished: {
                if (root._equalizerCommandQueue.length === 0)
                    root._applyEqualizerState(equalizerWriteCollector.text)
            }
        }
        onExited: (_exitCode, _exitStatus) => {
            if (root._equalizerCommandQueue.length > 0) {
                const queue = [...root._equalizerCommandQueue]
                const next = queue.shift()
                root._equalizerCommandQueue = queue
                Qt.callLater(() => root._runEqualizerCommand(next))
            } else if (root.equalizerLoading && !String(equalizerWriteCollector.text ?? "").trim()) {
                root.equalizerLoading = false
            }
        }
    }
}
