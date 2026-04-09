pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum MonitorSource { Monitor, Input }

    property var monitorSource: SongRec.MonitorSource.Monitor
    property int timeoutInterval: Config.options?.musicRecognition?.interval ?? 10
    property int timeoutDuration: Config.options?.musicRecognition?.timeout ?? 10
    readonly property bool running: recognizeMusicProc.running
    property bool dunstifyAvailable: false

    function toggleRunning(running) {
        const wantRunning = (running !== undefined) ? running : !root.running
        if (recognizeMusicProc.running && wantRunning === false) root.manuallyStopped = true;
        if (wantRunning === true) root.manuallyStopped = false;

        recognizeMusicProc.running = wantRunning
        musicReconizedProc.running = false
    }

    function toggleMonitorSource(source) {
        if (source !== undefined) {
            root.monitorSource = source
            return
        }
        root.monitorSource = (root.monitorSource === SongRec.MonitorSource.Monitor) ? SongRec.MonitorSource.Input : SongRec.MonitorSource.Monitor
    }
    function monitorSourceToString(source) {
        if (source === SongRec.MonitorSource.Monitor) {
            return "monitor"
        } else {
            return "input"
        }
    }
    readonly property string monitorSourceString: monitorSourceToString(monitorSource)
    property var recognizedTrack: ({ title:"", subtitle:"", url:""})
    property bool manuallyStopped: false

    Component.onCompleted: {
        dunstifyCheckProc.running = true
    }

    Process {
        id: dunstifyCheckProc
        running: false
        command: ["/usr/bin/which", "dunstify"]
        onExited: (exitCode, exitStatus) => {
            root.dunstifyAvailable = (exitCode === 0)
        }
    }

    function handleRecognition(jsonText) {
        try {
            if ((jsonText ?? "").trim() === "") {
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("No match found before timeout"), "-a", "Shell"])
                return
            }
            var obj = JSON.parse(jsonText)
            root.recognizedTrack = {
                title: obj.track.title,
                subtitle: obj.track.subtitle,
                url: obj.track.url
            }

            if (root.dunstifyAvailable) {
                musicReconizedProc.running = true
            } else {
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Music Recognized"), root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle, "-a", "Shell"])
                Qt.openUrlExternally(root.recognizedTrack.url);
            }
        } catch(e) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Perhaps what you're listening to is too niche"), "-a", "Shell"])
        }
    }

    Process {
        id: recognizeMusicProc
        running: false
        command: ["/usr/bin/bash", `${Directories.scriptsPath}/musicRecognition/recognize-music.sh`, "-i", String(root.timeoutInterval), "-t", String(root.timeoutDuration), "-s", root.monitorSourceString]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.manuallyStopped) {
                    root.manuallyStopped = false
                    return
                }
                handleRecognition(this.text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1) {
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Make sure you have songrec installed"), "-a", "Shell"])
            }
        }
    }

    Process {
        id: musicReconizedProc
        running: false
        command: [
            "/usr/bin/dunstify",
            Translation.tr("Music Recognized"), 
            root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle, 
            "-A", "Shazam",
            "-A", "YouTube",
            "-a", "Shell"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === "") return
                if (this.text == 0) {
                    Qt.openUrlExternally(root.recognizedTrack.url);
                } else {
                    Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle);
                }
            }
        }
    }
}
