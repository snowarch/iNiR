pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Every warning and error the shell and qs-rs logged since launch, plus a compile of every file nobody has opened
// yet. qs-rs's ErrorLog does the work; on Quickshell there's no such type and this stays empty.
Singleton {
    id: root

    property QtObject log: null
    readonly property bool available: root.log !== null
    readonly property var report: {
        try {
            return JSON.parse(root.log?.json ?? "")
        } catch (e) {
            return null
        }
    }
    readonly property var kinds: root.report?.kinds ?? []
    readonly property var checked: root.report?.checked ?? []
    readonly property string summary: root.report?.summary ?? ""
    readonly property int reloads: root.report?.reloads ?? 0
    readonly property int count: root.log?.count ?? 0
    readonly property bool checking: root.log?.checking ?? false

    function load(): void {}
    function check(): void {
        root.log?.check()
    }
    // Paths in messages, from the shell's folder on: "modules/iris/bar/IrisBar.qml:12".
    function short(text: string): string {
        const dir = String(Quickshell.shellDir).replace(/\/$/, "") + "/"
        return String(text).split("file://" + dir).join("").split(dir).join("")
    }

    Component.onCompleted: {
        try {
            root.log = Qt.createQmlObject("import Quickshell; ErrorLog {}", root, "ShellErrors")
        } catch (e) {
            root.log = null
        }
    }
    // Once the shell has settled; a reload rebuilds this file, so every save gets a fresh check.
    Timer {
        running: root.available
        interval: 15000
        onTriggered: root.check()
    }
}
