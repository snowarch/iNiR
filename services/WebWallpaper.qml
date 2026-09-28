pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.modules.common

Singleton {
    id: root

    readonly property string provider: Config.options?.background?.backend?.provider ?? "awww"
    readonly property var options: Config.options?.background?.backend?.web ?? ({})
    readonly property string source: String(options.source ?? "").trim()
    readonly property bool interactive: options.interactive ?? false
    readonly property bool requested: provider === "web" && source.length > 0
    readonly property bool active: requested && available

    property bool available: false
    property string runner: ""
    property string lastError: ""
    property int revision: 0

    function refresh(): void {
        root.revision++
    }

    onRequestedChanged: refresh()
    onSourceChanged: refresh()
    onInteractiveChanged: refresh()
    onAvailableChanged: refresh()

    Process {
        id: runnerProbeProc
        command: ["/usr/bin/bash", "-lc", "command -v qml6 || command -v qml"]
        stdout: StdioCollector { id: probeOut }
        stderr: StdioCollector { id: probeErr }
        onExited: exitCode => {
            const path = String(probeOut.text ?? "").trim().split("\n")[0] ?? ""
            root.runner = exitCode === 0 ? path : ""
            if (root.runner.length === 0) {
                root.available = false
                root.lastError = String(probeErr.text ?? "qml6 was not found").trim()
                return
            }
            hostProbeProc.running = true
        }
    }

    Process {
        id: hostProbeProc
        command: [
            root.runner,
            Quickshell.shellPath("modules/background/WebWallpaperHost.qml"),
            "--", "--probe"
        ]
        stderr: StdioCollector { id: hostProbeErr }
        onExited: exitCode => {
            root.available = exitCode === 0
            root.lastError = root.available
                ? ""
                : String(hostProbeErr.text ?? "Qt WebEngine or LayerShellQt is unavailable").trim()
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property var modelData

            readonly property string screenName: modelData?.name ?? ""
            readonly property string hostPath: Quickshell.shellPath("modules/background/WebWallpaperHost.qml")
            readonly property string pidFile: "/tmp/quickshell/web-wallpaper-" + screenName.replace(/[^A-Za-z0-9_.-]/g, "_") + ".pid"
            property bool wantStart: false
            property bool restarting: false

            function syncHost(): void {
                restartTimer.stop()
                restartTimer.interval = 80
                screenScope.wantStart = root.active
                screenScope.restarting = true

                if (hostProc.running)
                    hostProc.running = false

                if (!stopProc.running)
                    stopProc.running = true
            }

            Connections {
                target: root
                function onRevisionChanged(): void { screenScope.syncHost() }
            }

            Component.onCompleted: syncHost()

            Process {
                id: stopProc
                command: [
                    "/usr/bin/bash", "-c",
                    `pidfile="$1"; host="$2";
                    if [ -r "$pidfile" ]; then
                        pid=$(cat "$pidfile" 2>/dev/null || true)
                        if [ -n "$pid" ] && [ -r "/proc/$pid/cmdline" ] \
                                && tr '\\0' ' ' < "/proc/$pid/cmdline" | grep -Fq -- "$host"; then
                            kill "$pid" 2>/dev/null || true
                            i=0
                            while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 20 ]; do
                                sleep 0.05
                                i=$((i + 1))
                            done
                            kill -KILL "$pid" 2>/dev/null || true
                        fi
                    fi
                    rm -f "$pidfile"`,
                    "_", screenScope.pidFile, screenScope.hostPath
                ]
                onExited: {
                    if (screenScope.wantStart)
                        restartTimer.restart()
                    else
                        screenScope.restarting = false
                }
            }

            Timer {
                id: restartTimer
                interval: 80
                repeat: false
                onTriggered: {
                    if (!screenScope.wantStart || !root.active)
                        return
                    screenScope.restarting = false
                    root.lastError = ""
                    hostProc.running = true
                }
            }

            Process {
                id: hostProc
                command: [
                    "/usr/bin/bash", "-c",
                    `pidfile="$1"; shift;
                    child=""
                    cleanup() {
                        if [ -n "$child" ]; then
                            kill "$child" 2>/dev/null || true
                            wait "$child" 2>/dev/null || true
                        fi
                        rm -f "$pidfile"
                    }
                    trap 'cleanup; exit 143' TERM INT HUP
                    "$@" &
                    child=$!
                    mkdir -p "$(dirname "$pidfile")"
                    printf '%s\\n' "$child" > "$pidfile"
                    wait "$child"
                    status=$?
                    child=""
                    rm -f "$pidfile"
                    trap - TERM INT HUP
                    exit "$status"`,
                    "_", screenScope.pidFile,
                    root.runner,
                    screenScope.hostPath,
                    "--",
                    ...(root.interactive ? ["--interactive"] : []),
                    "--screen", screenScope.screenName,
                    root.source
                ]
                stderr: StdioCollector { id: hostErr }
                onExited: exitCode => {
                    if (screenScope.restarting || !root.active || !screenScope.wantStart || exitCode === 0)
                        return
                    root.lastError = String(hostErr.text ?? "web wallpaper host exited").trim()
                    console.warn("[WebWallpaper] host exited on", screenScope.screenName,
                        "code", exitCode, root.lastError)
                    restartTimer.interval = 1000
                    restartTimer.restart()
                }
            }
        }
    }

    Component.onCompleted: runnerProbeProc.running = true
}
