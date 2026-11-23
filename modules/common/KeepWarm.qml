pragma ComponentBehavior: Bound
import QtQuick
import qs.services

// Keeps a surface built while it is wanted or still on screen (`busy`: a close in motion), and `keepMs` after; then
// lets it go, at once while the shell is over its memory budget (MemoryPressureService.over). Bind a Loader's
// `active` to `warm`. Give `wanted` the request, never a state read off the loaded item: that would loop.
QtObject {
    id: root

    property bool wanted: false
    property bool busy: false
    property int keepMs: 120000
    readonly property bool held: root.wanted || root.busy
    property bool warm: false

    Component.onCompleted: root.warm = root.held
    onHeldChanged: {
        if (root.held) { root.release.stop(); root.warm = true }
        else root.release.restart()
    }

    // Over budget it lets go on the next turn of the event loop, never inside the change that let it go: the item it
    // drops is what `busy` reads.
    property Timer release: Timer {
        interval: MemoryPressureService.over ? 0 : root.keepMs
        onTriggered: root.warm = root.held
    }
    property Connections budget: Connections {
        target: MemoryPressureService
        function onOverChanged(): void { if (MemoryPressureService.over && !root.held && root.warm) root.release.restart() }
    }
}
