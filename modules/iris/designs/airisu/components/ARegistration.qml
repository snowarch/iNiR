import QtQuick

// A run out of register (SYSTEM.md §7, the lock): the ink plate jumps off the paper three times and comes back, one
// detent each, the way a misfed sheet prints; never a shake. A surface binds its ink plate's x and y to `dx` and `dy`
// and calls `run()`. With motion off the plates stay where they are and the words say what happened.
Item {
    id: root
    property real reach: 3 * Airisu.registration
    property real dx: 0
    property real dy: 0
    function run(): void { if (Airisu.moving) runs.restart() }

    SequentialAnimation {
        id: runs
        PropertyAction { target: root; property: "dx"; value: root.reach }
        PropertyAction { target: root; property: "dy"; value: Math.round(root.reach / 2) }
        PauseAnimation { duration: Airisu.detent }
        PropertyAction { target: root; property: "dx"; value: -root.reach }
        PropertyAction { target: root; property: "dy"; value: 0 }
        PauseAnimation { duration: Airisu.detent }
        PropertyAction { target: root; property: "dx"; value: Math.round(root.reach / 2) }
        PropertyAction { target: root; property: "dy"; value: -Math.round(root.reach / 2) }
        PauseAnimation { duration: Airisu.detent }
        PropertyAction { target: root; property: "dx"; value: 0 }
        PropertyAction { target: root; property: "dy"; value: 0 }
    }
}
