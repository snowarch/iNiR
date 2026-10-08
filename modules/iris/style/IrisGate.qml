pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// iRiS surfaces open only when the host shell is iNiR: its own shell.qml loads
// ShellIrisPanels.qml. A host that embeds the module under a different
// shell.qml keeps them closed.
QtObject {
    id: root

    readonly property bool official: hostFile.text().includes("ShellIrisPanels.qml")

    property FileView hostFile: FileView {
        path: Quickshell.shellPath("shell.qml")
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        if (!root.official)
            console.warn("[IrisGate] iRiS only runs inside iNiR; this host is not iNiR, so its surfaces stay closed.")
    }
}
