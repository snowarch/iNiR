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
    property string welcomeQmlPath: FileUtils.trimFileProtocol(Quickshell.shellPath("welcome.qml"))

    function pickRandomWallpaper(): string {
        const wallDir = FileUtils.trimFileProtocol(`${Directories.assetsPath}/wallpapers`)
        const extensions = [".png", ".jpg", ".jpeg", ".webp"]
        let candidates = []
        // Use FolderListModel results aren't available synchronously,
        // so we use a shell one-liner to list wallpapers
        return wallDir  // placeholder, actual pick happens in listWallpapersProc
    }

    function load() {
        listWallpapersProc.running = true
    }

    function enableNextTime() {
        Quickshell.execDetached(["/usr/bin/rm", "-f", root.firstRunFilePath])
    }
    function disableNextTime() {
        Quickshell.execDetached(["/bin/sh", "-c", `echo "${root.firstRunFileContent}" > "${root.firstRunFilePath}"`])
    }

    function handleFirstRun(): void {
        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, root.defaultWallpaperPath])
        Quickshell.execDetached(["/usr/bin/qs", "-p", root.welcomeQmlPath])
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
                const idx = Math.floor(Math.random() * _candidates.length)
                root.defaultWallpaperPath = _candidates[idx]
            }
            checkFirstRunProc.running = true
        }
    }

    Process {
        id: checkFirstRunProc
        command: ["/usr/bin/test", "-f", root.firstRunFilePath]
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // File doesn't exist, create it and run setup
                const parentDir = root.firstRunFilePath.substring(0, root.firstRunFilePath.lastIndexOf('/'))
                Quickshell.execDetached(["/bin/sh", "-c", `mkdir -p "${parentDir}" && echo "${root.firstRunFileContent}" > "${root.firstRunFilePath}"`])
                root.handleFirstRun()
            }
        }
    }

    Component.onCompleted: listWallpapersProc.running = true
}
