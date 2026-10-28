pragma Singleton

import QtQuick
import Quickshell

// Tooltips warm up: the first waits for a rest, and while one is up (or just went) its neighbours show at once.
// The only timer runs for a second after a tooltip leaves.
Singleton {
    id: root

    readonly property int coldDelay: 500
    property bool warm: false

    function shown(): void {
        cooling.stop()
        root.warm = true
    }

    function left(): void {
        if (root.warm) cooling.restart()
    }

    Timer {
        id: cooling
        interval: 1000
        onTriggered: root.warm = false
    }
}
