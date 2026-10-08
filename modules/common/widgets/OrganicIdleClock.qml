pragma Singleton

import QtQuick
import Quickshell

// One clock for every silent Organic field: separate timers land on separate frames, so three
// drifting fields repainted the desktop three times per tick instead of once.
Singleton {
    id: root

    property int users: 0
    signal tick(real dt)

    Timer {
        interval: 42
        repeat: true
        running: root.users > 0
        onTriggered: root.tick(interval / 1000)
    }
}
