import QtQuick
import Quickshell.Io

Item {
    id: root

    // `path` and `parser` are plain properties rather than aliases into the
    // socket. The Socket is created and destroyed on every attempt, so there is
    // no stable object left to alias to.
    property string path: ""
    property var parser: null

    // Intent, not fact: whether this link WANTS to be up. What the socket is
    // actually doing is announced through connectionStateChanged.
    property bool connected: false

    property int reconnectBaseMs: 400
    property int reconnectMaxMs: 15000

    property int _reconnectAttempt: 0

    // Carries the socket's REAL state, never the intent. A listener that
    // retries only while it believes it is disconnected must never be told
    // the intent, or it stops retrying and waits forever.
    signal connectionStateChanged(bool isConnected)

    onConnectedChanged: {
        if (connected) rebuild.restart()
        else socketLoader.active = false
    }

    // A Quickshell Socket that failed to connect stays failed. Assigning
    // `connected = true` again on that same object is silently ignored from
    // then on: no connect, no error, no connectionStateChanged, ever.
    //
    // The panel's first connect races the bridge's own startup and routinely
    // loses, so the Socket born from that attempt is poisoned. From then on
    // the retry timer dutifully assigns `true` to a dead object while the
    // panel waits forever.
    //
    // So every attempt is a brand new Socket. Recreating the object is the only
    // recovery; re-asserting the flag on the poisoned one is not.
    Loader {
        id: socketLoader
        active: false
        sourceComponent: Socket {
            path: root.path
            parser: root.parser
            // Bound, not a literal: a Socket given only `path` does NOT connect
            // on its own, so without this the freshly built object would sit
            // there idle and the retry would look like it had done nothing.
            connected: root.connected
        }
    }

    // A Connections block pointed at the socket, not an inline handler declared
    // inside the Socket object: an inline `function onConnectionStateChanged` on
    // a Socket does not fire, this does. The signal's own parameter is used,
    // never the property of the same name, which would shadow it with the
    // intent.
    Connections {
        target: socketLoader.item
        enabled: socketLoader.item !== null
        function onConnectionStateChanged(isConnected: bool): void {
            root.connectionStateChanged(isConnected)
            if (isConnected) {
                root._reconnectAttempt = 0
                return
            }
            if (root.connected) root._scheduleReconnect()
        }
    }

    // A real timer between tearing the old socket down and building the new one.
    // Building the replacement in the same turn as the destruction overlaps the
    // teardown and the connect is swallowed.
    Timer {
        id: rebuild
        interval: 60
        repeat: false
        onTriggered: socketLoader.active = root.connected
    }

    Timer {
        id: reconnectTimer
        interval: 0
        repeat: false
        onTriggered: root.reconnect()
    }

    // Discard the socket and build another. Deliberately not a re-assert: the
    // poisoned object cannot be revived, so this is a replacement, not a nudge.
    function reconnect(): void {
        socketLoader.active = false
        rebuild.restart()
    }

    // Returns whether the write actually happened. Never gate this on your own
    // belief that the link is up: a panel that believes the link is down
    // refuses to send, so it can never find out otherwise, and the two
    // mechanisms deadlock. Asking the only thing that knows — is there a
    // socket to write to — is both simpler and true.
    function send(data): bool {
        const item = socketLoader.item
        if (!item) return false
        const json = typeof data === "string" ? data : JSON.stringify(data)
        item.write(json.endsWith("\n") ? json : json + "\n")
        item.flush()
        return true
    }

    function _scheduleReconnect() {
        const pow = Math.min(_reconnectAttempt, 10)
        const base = Math.min(reconnectBaseMs * Math.pow(2, pow), reconnectMaxMs)
        const jitter = Math.floor(Math.random() * Math.floor(base / 4))
        reconnectTimer.interval = base + jitter
        reconnectTimer.restart()
        _reconnectAttempt++
    }
}