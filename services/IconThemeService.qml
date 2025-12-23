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
    property bool _restartQueued: false

    function ensureInitialized(): void {
        if (root._initialized)
            return;
        root._initialized = true;
        currentThemeProc.running = false
        currentThemeProc.running = true
        listThemesProc.running = false
        listThemesProc.running = true
        
        // Restore saved theme on first initialization
        if (Config.ready && Config.options?.appearance?.iconTheme) {
            const savedTheme = Config.options.appearance.iconTheme
            if (savedTheme && String(savedTheme).trim().length > 0) {
                console.log("[IconThemeService] Restoring saved icon theme:", String(savedTheme).trim())
                // Apply saved theme without triggering restart
                gsettingsSetProc.themeName = String(savedTheme).trim()
                gsettingsSetProc.skipRestart = true
                gsettingsSetProc.running = false
                gsettingsSetProc.running = true
            }
        }
    }

    function setTheme(themeName) {
        if (!themeName || String(themeName).trim().length === 0)
            return;

        const themeStr = String(themeName).trim()
        console.log("[IconThemeService] Setting icon theme:", themeStr)

        // Update UI immediately; actual system change follows via gsettings.
        root.currentTheme = themeStr

        gsettingsSetProc.themeName = themeStr
        gsettingsSetProc.skipRestart = false
        gsettingsSetProc.running = false
        gsettingsSetProc.running = true
        
        // Persist to config.json
        Config.setNestedValue('appearance.iconTheme', themeStr)

        // Ensure config is written before we do any restart.
        Config.flushWrites()
    }

    Timer {
        id: restartDelay
        interval: 250
        repeat: false
        onTriggered: {
            root._restartQueued = false
            console.log("[IconThemeService] Restarting shell now...")
            // IMPORTANT: do NOT kill the current shell and then rely on its own timers.
            // Run a single external command that kills and relaunches.
            Quickshell.execDetached([
                "/usr/bin/bash",
                "-lc",
                "/usr/bin/qs kill -c ii 2>/dev/null; /usr/bin/qs -c ii >/dev/null 2>&1 & disown"
            ])
        }
    }

    function queueRestart(): void {
        if (root._restartQueued)
            return;
        root._restartQueued = true
        restartDelay.restart()
    }

    Process {
        id: gsettingsSetProc
        property string themeName: ""
        property bool skipRestart: false
        command: ["/usr/bin/gsettings", "set", "org.gnome.desktop.interface", "icon-theme", gsettingsSetProc.themeName]
        onExited: (exitCode, exitStatus) => {
            console.log("[IconThemeService] gsettings set exited:", exitCode, "theme:", gsettingsSetProc.themeName)
            // Sync to KDE/Qt apps via kdeglobals
            kdeGlobalsUpdateProc.themeName = gsettingsSetProc.themeName
            kdeGlobalsUpdateProc.skipRestart = gsettingsSetProc.skipRestart
            kdeGlobalsUpdateProc.running = false
            kdeGlobalsUpdateProc.running = true
        }
    }

    // Update kdeglobals [Icons] section properly
    Process {
        id: kdeGlobalsUpdateProc
        property string themeName: ""
        property bool skipRestart: false
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
            kwriteconfigProc.skipRestart = kdeGlobalsUpdateProc.skipRestart

            kwriteconfigProc.running = false
            kwriteconfigProc.running = true

            // Restart shell if user actively changed theme.
            // Do not depend on kwriteconfig6 succeeding.
            if (!kdeGlobalsUpdateProc.skipRestart) {
                root.queueRestart()
            }
        }
    }

    // Use kwriteconfig6 for better KDE integration (if available)
    Process {
        id: kwriteconfigProc
        property string themeName: ""
        property bool skipRestart: false
        command: [
            "/usr/bin/kwriteconfig6",
            "--file", "kdeglobals",
            "--group", "Icons",
            "--key", "Theme",
            kwriteconfigProc.themeName
        ]
        onExited: (exitCode, exitStatus) => {
            console.log("[IconThemeService] kwriteconfig exited:", exitCode, "theme:", kwriteconfigProc.themeName)
        }
    }

    Process {
        id: currentThemeProc
        command: ["/usr/bin/gsettings", "get", "org.gnome.desktop.interface", "icon-theme"]
        stdout: SplitParser {
            onRead: line => {
                root.currentTheme = line.trim().replace(/'/g, "")
            }
        }
    }

    Process {
        id: listThemesProc
        command: [
            "/usr/bin/find",
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
