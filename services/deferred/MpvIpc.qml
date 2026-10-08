pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Talks to one mpv instance over its JSON IPC socket. `observe_property` only
// lives while the connection stays open, so this keeps one Socket for the whole
// playback instead of a one-shot client per command. mpv binds its socket after
// the wrapper starts it and the file can exist before it listens, so a failed
// connect is retried on a freshly created Socket: Quickshell's Socket does not
// reconnect once its first connect errored. A connection that drops after it
// carried data means the player closed, which the caller persists on.
Item {
    id: root

    property string path: ""
    property string rejectPath: ""
    property bool running: false
    property bool connected: false
    property double position: 0
    property double duration: 0
    // Subtitle tracks as mpv sees them. ani-cli hands it a single external track
    // with no language, so a list of one is the normal case, not a degenerate one.
    property var subTracks: []
    property int subId: 0
    property var audioTracks: []
    property int audioId: 0
    property double subDelay: 0
    // What the wrapper told mpv to call this: "<show> Episode <n>". It is how a
    // player that outlived a shell reload says which show it belongs to.
    property string mediaTitle: ""

    readonly property int maxAttempts: 120

    signal started()
    signal closed()
    signal rejected(string expected, string found)

    property bool _established: false
    property bool _received: false
    property bool _stopping: false
    property int _attempts: 0

    function begin(socketPath: string, rejectFilePath: string): void {
        root.stop()
        root.position = 0
        root.duration = 0
        root.subTracks = []
        root.subId = 0
        root.audioTracks = []
        root.audioId = 0
        root.subDelay = 0
        root.mediaTitle = ""
        root._established = false
        root._received = false
        root._stopping = false
        root._attempts = 0
        root.connected = false
        root.path = socketPath
        root.rejectPath = rejectFilePath
        root.running = true
        waitProcess.running = false
        waitProcess.running = true
    }

    function stop(): void {
        root._stopping = true
        retryTimer.stop()
        waitProcess.running = false
        socketLoader.active = false
        root.connected = false
        root._established = false
        root.running = false
    }

    function _attempt(): void {
        if (!root.running)
            return
        if (root._attempts >= root.maxAttempts) {
            root._finish()
            return
        }
        root._attempts++
        socketLoader.active = true
    }

    function _retry(): void {
        if (!root.running || root._stopping)
            return
        socketLoader.active = false
        retryTimer.interval = 400
        retryTimer.restart()
    }

    function _finish(): void {
        if (!root.running)
            return
        root.running = false
        retryTimer.stop()
        socketLoader.active = false
        root.connected = false
        root.closed()
    }

    function _handleLine(line: string): void {
        let message = null
        try {
            message = JSON.parse(line)
        } catch (error) {
            return
        }
        if (message?.event === "shutdown") {
            root._finish()
            return
        }
        if (message?.event !== "property-change")
            return
        if (message.name === "time-pos" && typeof message.data === "number")
            root.position = message.data
        else if (message.name === "duration" && typeof message.data === "number")
            root.duration = message.data
        else if (message.name === "track-list") {
            const all = Array.isArray(message.data) ? message.data : []
            root.subTracks = all.filter(track => track?.type === "sub")
            root.audioTracks = all.filter(track => track?.type === "audio")
            return
        } else if (message.name === "media-title") {
            root.mediaTitle = typeof message.data === "string" ? message.data : ""
            return
        } else if (message.name === "sid") {
            root.subId = typeof message.data === "number" ? message.data : 0
            return
        } else if (message.name === "aid") {
            root.audioId = typeof message.data === "number" ? message.data : 0
            return
        } else if (message.name === "sub-delay") {
            root.subDelay = typeof message.data === "number" ? message.data : 0
            return
        } else
            return
        if (!root._received) {
            root._received = true
            retryTimer.stop()
            root.started()
        }
    }

    function selectSub(id: int): void {
        if (!root.connected) return
        root._send(["set_property", "sid", id > 0 ? id : "no"])
    }

    function apply(name: string, value: var): void {
        if (!root.connected) return
        root._send(["set_property", name, value])
    }

    function seekBy(seconds: real): void {
        if (!root.connected) return
        root._send(["seek", seconds, "relative"])
    }

    function addSub(path: string): void {
        if (!root.connected || path.length === 0) return
        root._send(["sub-add", path, "select"])
    }

    function quit(): void {
        if (!root.connected) return
        root._send(["quit"])
    }

    function _send(command: var): void {
        const client = socketLoader.item
        if (!client)
            return
        client.write(JSON.stringify({ "command": command }) + "\n")
        client.flush()
    }

    // The wrapper refuses to play when ani-cli resolved a different show than
    // iNiR expected, and can only say so on disk: there is no mpv to talk to.
    // This waits for the reject file or for a socket that really accepts
    // connections, so the first QML connect succeeds instead of logging errors.
    Process {
        id: waitProcess
        command: ["/usr/bin/python3", "-c",
            "import os, socket, sys, time\n"
            + "reject = sys.argv[2]\n"
            + "try:\n"
            + "    os.unlink(reject)\n"
            + "except OSError:\n"
            + "    pass\n"
            + "deadline = time.time() + 180\n"
            + "while time.time() < deadline:\n"
            + "    if os.path.exists(reject):\n"
            + "        try:\n"
            + "            with open(reject) as handle:\n"
            + "                sys.stdout.write(handle.read())\n"
            + "            os.unlink(reject)\n"
            + "        except OSError:\n"
            + "            pass\n"
            + "        sys.exit(2)\n"
            + "    try:\n"
            + "        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)\n"
            + "        client.settimeout(1)\n"
            + "        client.connect(sys.argv[1])\n"
            + "        client.close()\n"
            + "        sys.exit(0)\n"
            + "    except OSError:\n"
            + "        time.sleep(0.2)\n"
            + "sys.exit(1)\n",
            root.path, root.rejectPath]

        stdout: StdioCollector {
            id: probeCollector
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.running)
                return
            if (exitCode === 0) {
                root._attempt()
                return
            }
            if (exitCode === 2) {
                const lines = String(probeCollector.text ?? "").split("\n")
                root.running = false
                retryTimer.stop()
                socketLoader.active = false
                root.connected = false
                root.rejected(String(lines[0] ?? ""), String(lines[1] ?? ""))
                return
            }
            root._finish()
        }
    }

    Loader {
        id: socketLoader
        active: false

        sourceComponent: Component {
            Socket {
                id: socket

                parser: SplitParser {
                    onRead: line => root._handleLine(line)
                }

                onConnectionStateChanged: {
                    root.connected = socket.connected
                    if (socket.connected) {
                        root._established = true
                        root._send(["observe_property", 1, "time-pos"])
                        root._send(["observe_property", 2, "duration"])
                        root._send(["observe_property", 3, "track-list"])
                        root._send(["observe_property", 4, "sid"])
                        root._send(["observe_property", 5, "media-title"])
                        root._send(["observe_property", 6, "aid"])
                        root._send(["observe_property", 7, "sub-delay"])
                        return
                    }
                    root._established = false
                    if (root._received)
                        root._finish()
                }

                onError: (socketError) => {
                    root._established = false
                    if (root._received) {
                        root._finish()
                        return
                    }
                    Qt.callLater(() => root._retry())
                }
            }
        }

        onLoaded: {
            if (!root.running) {
                socketLoader.active = false
                return
            }
            item.path = root.path
            item.connected = true
        }
    }

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: root._attempt()
    }
}
