pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property var availableThemes: []
    property string currentTheme: ""

    property bool _initialized: false

    function ensureInitialized(): void {
        if (root._initialized)
            return;
        root._initialized = true;
        currentThemeProc.running = true
        listThemesProc.running = true
    }

    function setTheme(themeName) {
        if (!themeName || String(themeName).trim().length === 0)
            return;

        gsettingsSetProc.themeName = String(themeName).trim()
        gsettingsSetProc.running = true
    }

    Timer {
        id: restartDelay
        interval: 300
        repeat: false
        onTriggered: Quickshell.execDetached(["qs", "-c", "ii"])
    }

    Process {
        id: gsettingsSetProc
        property string themeName: ""
        command: ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", gsettingsSetProc.themeName]
        onExited: (exitCode, exitStatus) => {
            // Sync to KDE/Qt apps via kdeglobals
            kdeGlobalsUpdateProc.themeName = gsettingsSetProc.themeName
            kdeGlobalsUpdateProc.running = true
        }
    }

    // Update kdeglobals [Icons] section properly
    Process {
        id: kdeGlobalsUpdateProc
        property string themeName: ""
        command: [
            "/usr/bin/python3",
            "-c",
            `
import configparser
import os

config_path = os.path.expanduser("~/.config/kdeglobals")
theme = "${kdeGlobalsUpdateProc.themeName}"

config = configparser.ConfigParser()
config.optionxform = str  # Preserve case

if os.path.exists(config_path):
    config.read(config_path)

if "Icons" not in config:
    config["Icons"] = {}

config["Icons"]["Theme"] = theme

with open(config_path, "w") as f:
    config.write(f, space_around_delimiters=False)
`
        ]
        onExited: (exitCode, exitStatus) => {
            // Also update plasma icon theme via kwriteconfig if available
            kwriteconfigProc.themeName = kdeGlobalsUpdateProc.themeName
            kwriteconfigProc.running = true
        }
    }

    // Use kwriteconfig6 for better KDE integration (if available)
    Process {
        id: kwriteconfigProc
        property string themeName: ""
        command: [
            "/usr/bin/kwriteconfig6",
            "--file", "kdeglobals",
            "--group", "Icons",
            "--key", "Theme",
            kwriteconfigProc.themeName
        ]
        onExited: (exitCode, exitStatus) => {
            // Restart shell
            Quickshell.execDetached(["qs", "kill", "-c", "ii"])
            restartDelay.start()
        }
    }

    Process {
        id: currentThemeProc
        command: ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"]
        stdout: SplitParser {
            onRead: line => {
                root.currentTheme = line.trim().replace(/'/g, "")
            }
        }
    }

    Process {
        id: listThemesProc
        command: [
            "find",
            "/usr/share/icons",
            `${FileUtils.trimFileProtocol(Directories.home)}/.local/share/icons`,
            "-maxdepth",
            "1",
            "-type",
            "d"
        ]
        
        property var themes: []
        
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim()
                if (!p)
                    return
                const parts = p.split("/")
                const name = parts[parts.length - 1]
                if (!name)
                    return
                if (["icons", "default", "hicolor", "locolor"].includes(name))
                    return
                if (name === "cursors")
                    return
                listThemesProc.themes.push(name)
            }
        }
        
        onRunningChanged: {
            if (!running && themes.length > 0) {
                const uniqueSorted = Array.from(new Set(themes)).sort()
                root.availableThemes = uniqueSorted
                themes = []
            }
        }
    }
}
