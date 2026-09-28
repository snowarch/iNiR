pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Re-assigning `screen` on a mapped layer surface re-creates it, so the output is only chosen while unmapped.
QtObject {
    id: root

    property var wanted: null
    property bool live: false
    property var held: null
    readonly property bool heldConnected: root.held !== null
        && Quickshell.screens.some(screen => (screen?.name ?? "") === (root.held?.name ?? ""))
    readonly property var output: root.live && root.heldConnected ? root.held : root.wanted
    readonly property string outputName: root.output?.name ?? ""

    onLiveChanged: if (root.live) root.held = root.wanted
    Component.onCompleted: if (root.live) root.held = root.wanted
}
