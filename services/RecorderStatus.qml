pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isRecording: false
    property int recorderPid: 0
    property string requestedAudioMode: "none"
    property string activeAudioMode: "none"
    property bool audioFallback: false
    property bool hasAudioMetadata: false
    property bool hasStoredAudioMode: false
    property bool hasStoredSystemAudioSource: false
    property bool hasStoredMicrophoneSource: false
    property string legacyAudioSource: ""
    readonly property string configuredAudioMode: root.hasStoredAudioMode
        ? root.normalizeAudioMode(Config.options?.screenRecord?.audioMode ?? "system")
        : root.audioModeFromLegacySource(root.legacyAudioSource)
    readonly property string configuredSystemAudioSource: {
        const configured = String(Config.options?.screenRecord?.systemAudioSource ?? "")
        if (root.hasStoredSystemAudioSource)
            return configured
        return root.legacyAudioSource.endsWith(".monitor") ? root.legacyAudioSource : configured
    }
    readonly property string configuredMicrophoneSource: {
        const configured = String(Config.options?.screenRecord?.microphoneSource ?? "")
        if (root.hasStoredMicrophoneSource)
            return configured
        return root.legacyAudioSource.length > 0 && !root.legacyAudioSource.endsWith(".monitor")
            ? root.legacyAudioSource : configured
    }
    readonly property string effectiveAudioMode: isRecording && hasAudioMetadata ? activeAudioMode : configuredAudioMode
    readonly property string recorderStatusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/inir/recorder-status.json"
    // Timestamp (ms since epoch) when recording started, 0 when not recording
    property real recordingStartTime: 0
    // Elapsed seconds since recording started, updated every second
    property int elapsedSeconds: 0

    function normalizeAudioMode(mode: string): string {
        switch (mode) {
        case "none":
        case "system":
        case "microphone":
        case "both":
            return mode
        default:
            return "system"
        }
    }

    function audioModeFromLegacySource(source: string): string {
        if (source.length > 0 && !source.endsWith(".monitor"))
            return "microphone"
        return "system"
    }

    function setConfiguredAudioMode(mode: string): void {
        Config.setNestedValue("screenRecord.audioMode", root.normalizeAudioMode(mode))
        root.hasStoredAudioMode = true
    }

    function setConfiguredSystemAudioSource(source): void {
        Config.setNestedValue("screenRecord.systemAudioSource", String(source ?? ""))
        root.hasStoredSystemAudioSource = true
    }

    function setConfiguredMicrophoneSource(source): void {
        Config.setNestedValue("screenRecord.microphoneSource", String(source ?? ""))
        root.hasStoredMicrophoneSource = true
    }

    function resetStoredAudioConfig(): void {
        root.hasStoredAudioMode = false
        root.hasStoredSystemAudioSource = false
        root.hasStoredMicrophoneSource = false
        root.legacyAudioSource = ""
    }

    function parseStoredAudioConfig(payloadText: string): void {
        try {
            const payload = JSON.parse(payloadText.trim() || "{}")
            const screenRecord = payload?.screenRecord
            if (screenRecord === null || typeof screenRecord !== "object" || Array.isArray(screenRecord)) {
                root.resetStoredAudioConfig()
                return
            }
            root.hasStoredAudioMode = Object.prototype.hasOwnProperty.call(screenRecord, "audioMode")
            root.hasStoredSystemAudioSource = Object.prototype.hasOwnProperty.call(screenRecord, "systemAudioSource")
            root.hasStoredMicrophoneSource = Object.prototype.hasOwnProperty.call(screenRecord, "microphoneSource")
            root.legacyAudioSource = typeof screenRecord.audioSource === "string"
                ? screenRecord.audioSource : ""
        } catch (error) {
            root.resetStoredAudioConfig()
        }
    }

    function refreshStoredAudioConfig(): void {
        if (Config.ready && !storedConfigProcess.running)
            storedConfigProcess.running = true
    }

    function resetAudioMetadata(): void {
        requestedAudioMode = "none"
        activeAudioMode = "none"
        audioFallback = false
        hasAudioMetadata = false
    }

    function loadAudioMetadata(): void {
        if (!metadataProcess.running)
            metadataProcess.running = true
    }

    onIsRecordingChanged: {
        if (isRecording) {
            recordingStartTime = Date.now()
            elapsedSeconds = 0
        } else {
            recordingStartTime = 0
            elapsedSeconds = 0
            recorderPid = 0
            resetAudioMetadata()
        }
    }

    function refreshStatus() {
        if (!checkProcess.running)
            checkProcess.running = true
    }

    // Idle poll: infrequent check for externally-started recordings
    Timer {
        id: idlePollTimer
        interval: 5000
        running: Config.ready && !root.isRecording
        repeat: true
        onTriggered: root.refreshStatus()
    }

    // Active poll: 1s tick while recording (elapsed counter + stop detection)
    Timer {
        id: activePollTimer
        interval: 1000
        running: root.isRecording
        repeat: true
        onTriggered: {
            if (root.recordingStartTime > 0)
                root.elapsedSeconds = Math.floor((Date.now() - root.recordingStartTime) / 1000)
            root.refreshStatus()
        }
    }

    // Quick recheck after a recording action (start/stop) to catch state change fast
    function scheduleQuickCheck(): void {
        quickCheckTimer.restart()
    }
    Timer {
        id: quickCheckTimer
        interval: 500
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready)
                Qt.callLater(root.refreshStoredAudioConfig)
        }
    }

    Component.onCompleted: {
        Qt.callLater(root.refreshStatus)
        Qt.callLater(root.refreshStoredAudioConfig)
    }

    Process {
        id: storedConfigProcess
        command: ["/usr/bin/cat", Config.filePath]
        stdout: StdioCollector {
            id: storedConfigCollector
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.parseStoredAudioConfig(storedConfigCollector.text)
            else
                root.resetStoredAudioConfig()
        }
    }

    Process {
        id: metadataProcess
        command: ["/usr/bin/cat", root.recorderStatusPath]
        stdout: StdioCollector {
            id: metadataCollector
        }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.resetAudioMetadata()
                return
            }
            try {
                const payload = JSON.parse(metadataCollector.text)
                const payloadPid = Number(payload.recorderPid ?? 0)
                if (!root.isRecording || payloadPid <= 0 || payloadPid !== root.recorderPid) {
                    root.resetAudioMetadata()
                    return
                }
                root.requestedAudioMode = root.normalizeAudioMode(String(payload.requestedAudioMode ?? "system"))
                root.activeAudioMode = root.normalizeAudioMode(String(payload.activeAudioMode ?? "none"))
                root.audioFallback = payload.audioFallback === true
                root.hasAudioMetadata = true
            } catch (error) {
                root.resetAudioMetadata()
            }
        }
    }

    Process {
        id: checkProcess
        command: ["/usr/bin/pgrep", "-xo", "wf-recorder"]
        stdout: StdioCollector {
            id: recorderPidCollector
        }
        onExited: (exitCode, exitStatus) => {
            const previousPid = root.recorderPid
            const parsedPid = parseInt(recorderPidCollector.text.trim(), 10)
            root.recorderPid = exitCode === 0 && !isNaN(parsedPid) ? parsedPid : 0
            root.isRecording = root.recorderPid > 0
            if (root.isRecording && (!root.hasAudioMetadata || root.recorderPid !== previousPid))
                root.loadAudioMetadata()
        }
    }
}
