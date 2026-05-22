pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isRecording: false
    // Timestamp (ms since epoch) when recording started, 0 when not recording
    property real recordingStartTime: 0
    // Elapsed seconds since recording started, updated every second
    property int elapsedSeconds: 0

    onIsRecordingChanged: {
        if (isRecording) {
            recordingStartTime = Date.now()
            elapsedSeconds = 0
        } else {
            recordingStartTime = 0
            elapsedSeconds = 0
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

    Component.onCompleted: Qt.callLater(root.refreshStatus)

    Process {
        id: checkProcess
        command: ["/usr/bin/pgrep", "-x", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            // pgrep returns 0 if process found, 1 if not found
            root.isRecording = (exitCode === 0)
        }
    }
}
