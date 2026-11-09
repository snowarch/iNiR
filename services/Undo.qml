pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Act first, give a way back: whatever removes something hands its way back here instead of asking "are you sure".
// The notice goes through the notification server, so each family draws it with its own face; a newer act replaces it.
Singleton {
    id: root

    property string label: ""
    readonly property bool pending: root._undo !== null
    property var _undo: null
    property var _commit: null
    property int _gen: 0

    // `commit` (optional) finishes what was only held aside, once the notice is gone.
    function offer(text: string, undo: var, commit: var): void {
        root._settle()
        root._gen++
        root._undo = undo
        root._commit = commit ?? null
        root.label = text
        noticeComponent.createObject(root, { gen: root._gen, command: ["timeout", "60", "notify-send",
            "-a", "iNiR", "-u", "low", "-t", "6000", "-h", "int:transient:1",
            "-h", "string:x-canonical-private-synchronous:inir-undo", "-w", "-A", "undo=" + Translation.tr("Undo"), "--", text] })
    }

    function undo(): bool {
        if (!root._undo) return false
        const back = root._undo
        root._undo = null
        root._commit = null
        root.label = ""
        back()
        return true
    }

    function _settle(): void {
        const commit = root._commit
        root._undo = null
        root._commit = null
        root.label = ""
        if (commit) commit()
    }

    // The action word can land after the exit: settle a moment later so an Undo press is never lost.
    Timer {
        id: settleSoon
        property int gen: -1
        interval: 500
        onTriggered: if (settleSoon.gen === root._gen) root._settle()
    }

    Component {
        id: noticeComponent
        Process {
            id: notice
            required property int gen
            Component.onCompleted: notice.running = true
            stdout: StdioCollector {
                onStreamFinished: if ((text ?? "").trim() === "undo" && notice.gen === root._gen) root.undo()
            }
            onExited: {
                if (notice.gen === root._gen) {
                    settleSoon.gen = notice.gen
                    settleSoon.restart()
                }
                notice.destroy(1000)
            }
        }
    }

    /// Takes back the last removal (a clock, a preset, a clipboard entry, an autostart entry...) while its notice is up.
    IpcHandler {
        target: "undo"

        /// Undo the last removal; returns what came back, or "nothing to undo".
        function undo(): string {
            const what = root.label
            return root.undo() ? what : "nothing to undo"
        }

        /// What `undo` would take back right now, or "" when nothing.
        function status(): string {
            return root.label
        }
    }
}
