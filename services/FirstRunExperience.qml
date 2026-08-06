pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property string firstRunNotifSummary: "Welcome!"
    property string firstRunNotifBody: "Hit Super+/ for a list of keybinds"
    property string defaultWallpaperPath: ""
    property bool _pendingFirstRun: false

    function load() {
        if (checkFirstRunProc.running || listWallpapersProc.running)
            return;

        checkFirstRunProc.running = true
    }

    function enableNextTime() {
        Quickshell.execDetached(["/usr/bin/rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["/bin/sh", "-c", `echo "${root.firstRunFileContent}" > "${root.firstRunFilePath}"`])
    }

    function handleFirstRun(): void {
        if (root.defaultWallpaperPath.length > 0)
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, root.defaultWallpaperPath])
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "welcome"])
    }

    Process {
        id: listWallpapersProc
        property string wallDir: FileUtils.trimFileProtocol(`${Directories.assetsPath}/wallpapers`)
        command: ["/bin/sh", "-c", `find "${wallDir}" -maxdepth 1 -type f \\( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \\) 2>/dev/null`]
        stdout: SplitParser {
            onRead: (line) => {
                const trimmed = line.trim()
                if (trimmed.length > 0)
                    listWallpapersProc._candidates.push(trimmed)
            }
        }
        property var _candidates: []
        onExited: (exitCode) => {
            if (_candidates.length > 0) {
                const sorted = [..._candidates].sort()
                root.defaultWallpaperPath = sorted.find(path => path.endsWith("/qs-niri.jpg"))
                    ?? sorted[0]
            }
            if (root._pendingFirstRun) {
                root.disableNextTime()
                root.handleFirstRun()
                root._pendingFirstRun = false
            }
        }
    }

    Process {
        id: checkFirstRunProc
        command: ["/usr/bin/test", "-f", root.firstRunFilePath]
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root._pendingFirstRun = true
                const parentDir = root.firstRunFilePath.substring(0, root.firstRunFilePath.lastIndexOf('/'))
                Quickshell.execDetached(["/bin/sh", "-c", `mkdir -p "${parentDir}"`])
                listWallpapersProc.running = true
            }
        }
    }
}
