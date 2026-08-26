pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string killDialogQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("killDialog.qml"))

    function load() {
        // dummy to force init
    }

    // Defer conflict checks to avoid process spawns during the critical shell startup window
    Timer {
        id: conflictCheckDelay
        interval: 1500
        repeat: false
        onTriggered: {
            pidofTraysProc.running = true
            pidofNotifsProc.running = true
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                conflictCheckDelay.restart()
            }
        }
    }

    Component.onCompleted: {
        if (Config.ready) {
            conflictCheckDelay.restart()
        }
    }

    function _maybeHandleConflicts(): void {
        if (pidofTraysProc.running || pidofNotifsProc.running)
            return

        const conflictingTrays = root._traysConflict
        const conflictingNotifications = root._notifsConflict

        var openDialog = false;
        if (conflictingTrays) {
            if (!(Config.options?.conflictKiller?.autoKillTrays ?? false)) openDialog = true;
            else Quickshell.execDetached(["/usr/bin/killall", "kded6"])
        }
        if (conflictingNotifications) {
            if (!(Config.options?.conflictKiller?.autoKillNotificationDaemons ?? false)) openDialog = true;
            else Quickshell.execDetached(["/usr/bin/killall", "mako", "dunst"])
        }
        if (openDialog) {
            ShellExec.launch({ program: "/usr/bin/qs", args: ["-p", root.killDialogQmlPath], scope: "killdialog", description: "Conflict resolution dialog" })
        }
    }

    property bool _traysConflict: false
    property bool _notifsConflict: false

    Process {
        id: pidofTraysProc
        command: ["/usr/bin/pidof", "kded6"]
        onExited: (exitCode, exitStatus) => {
            root._traysConflict = (exitCode === 0)
            root._maybeHandleConflicts()
        }
    }

    Process {
        id: pidofNotifsProc
        command: ["/usr/bin/pidof", "mako", "dunst"]
        onExited: (exitCode, exitStatus) => {
            root._notifsConflict = (exitCode === 0)
            root._maybeHandleConflicts()
        }
    }
}
