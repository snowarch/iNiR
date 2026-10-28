pragma Singleton

import QtQuick
import Quickshell

// Tooltips warm up: the first waits for a rest, and while one is up (or just went) its neighbours show at once.
// The only timer runs for a second after a tooltip leaves.
Singleton {
    id: root

    readonly property int coldDelay: 500
    property bool warm: false
    property int _up: 0

    function shown(): void {
        root._up++
        cooling.stop()
        root.warm = true
    }

    // Cools only once the last one is gone.
    function left(): void {
        root._up = Math.max(0, root._up - 1)
        if (root.warm && root._up === 0) cooling.restart()
    }

    Timer {
        id: cooling
        interval: 1000
        onTriggered: root.warm = false
    }
}
