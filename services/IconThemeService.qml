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
    property string dockTheme: ""  // Separate theme for dock icons

    property bool _initialized: false
    property bool _restartQueued: false

    // Smart icon resolution: handles broken absolute paths from Electron apps
    function smartIconName(icon, appId) {
        if (!icon) return appId || "application-x-executable";
        
        // Block known bad paths to avoid Qt warnings
        // Electron apps running from Downloads/tmp often report invalid absolute paths
        if (icon.startsWith("/") || icon.startsWith("file://")) {
            const path = icon.startsWith("file://") ? icon.substring(7) : icon;

            // Check for volatile/non-permanent paths first
            const volatilePaths = ["/Descargas/", "/Downloads/", "/tmp/", "/var/tmp/", "/home/"];
            const isVolatile = volatilePaths.some(vp => {
                if (vp === "/home/") {
                    // Only consider /home/ volatile if it's inside a download-like folder
                    return path.includes("/Descargas/") || path.includes("/Downloads/") || 
                           path.includes("/tmp/") || path.includes("/.local/share/Steam/") === false;
                }
                return path.includes(vp);
            });
            
            // Known Electron app patterns - return proper icon name
            if (path.includes("/Windsurf/") || path.includes("/windsurf/")) {
                return "visual-studio-code";
            }
            if (path.includes("/Code/") || path.includes("/code/") || path.includes("/VSCode/")) {
                return "visual-studio-code";
            }
            if (path.includes("/Cursor/") || path.includes("/cursor/")) {
                return "visual-studio-code";
            }
            if (path.includes("/Zed/") || path.includes("/zed/")) {
                return "dev.zed.Zed";
            }
            if (path.includes("/Discord/") || path.includes("/discord/")) {
                return "discord";
            }
            if (path.includes("/Slack/") || path.includes("/slack/")) {
                return "slack";
            }
            if (path.includes("/Obsidian/") || path.includes("/obsidian/")) {
                return "obsidian";
            }
            if (path.includes("/Spotify/") || path.includes("/spotify/")) {
                return "spotify";
            }

            // Try to fix common broken Electron paths
            // Example: .../resources/app/resources/linux/code.png -> .../resources/linux/code.png
            if (path.indexOf("/resources/app/resources/") !== -1) {
                return path.replace("/resources/app/resources/", "/resources/");
            }

            // For other volatile paths, extract base name
            if (isVolatile || path.includes("/resources/")) {
                const fileName = path.split("/").pop();
                let baseName = fileName;
                if (baseName.includes(".")) {
                    baseName = baseName.split(".").slice(0, -1).join(".");
                }
                // Try common icon name mappings
                if (baseName === "code") return "visual-studio-code";
                if (baseName === "discord") return "discord";
                if (baseName === "slack") return "slack";
                return baseName || appId || "application-x-executable";
            }
        }
        
        return icon;
    }

    // Get icon path from dock theme, fallback to system
    function dockIconPath(iconName: string, fallback: string): string {
        if (!iconName) return Quickshell.iconPath(fallback || "application-x-executable")
        
        // If iconName is already an absolute path, use it directly
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return iconName.startsWith("file://") ? iconName : `file://${iconName}`
        }
        
        if (!root.dockTheme) return Quickshell.iconPath(iconName, fallback || "application-x-executable")
        
        const home = Quickshell.env("HOME")
        const theme = root.dockTheme
        
        // Return first candidate path - Image will handle fallback via onStatusChanged
        // Structure: theme/apps/scalable (YAMIS, etc)
        return `file://${home}/.local/share/icons/${theme}/apps/scalable/${iconName}.svg`
    }
    
    // Get all candidate paths for dock icon
    function dockIconCandidates(iconName: string): list<string> {
        if (!iconName || !root.dockTheme) return []
        
        // If iconName is already an absolute path, return it as-is (no candidates needed)
        if (iconName.startsWith("/") || iconName.startsWith("file://")) {
            return []
        }
        
        const home = Quickshell.env("HOME")
        const theme = root.dockTheme
        
        return [
            `file://${home}/.local/share/icons/${theme}/apps/scalable/${iconName}.svg`,
            `file:///usr/share/icons/${theme}/apps/scalable/${iconName}.svg`,
            `file://${home}/.local/share/icons/${theme}/scalable/apps/${iconName}.svg`,
            `file:///usr/share/icons/${theme}/scalable/apps/${iconName}.svg`,
            `file://${home}/.local/share/icons/${theme}/apps/256x256/${iconName}.png`,
            `file:///usr/share/icons/${theme}/apps/256x256/${iconName}.png`,
            `file://${home}/.local/share/icons/${theme}/256x256/apps/${iconName}.png`,
            `file:///usr/share/icons/${theme}/256x256/apps/${iconName}.png`,
        ]
    }

    function ensureInitialized(): void {
        if (root._initialized)
            return;
        root._initialized = true;
        
        listThemesProc.running = false
        listThemesProc.running = true
        
        // Load system theme
        const savedTheme = Config.ready ? (Config.options?.appearance?.iconTheme ?? "") : ""
        if (savedTheme && String(savedTheme).trim().length > 0) {
            root.currentTheme = String(savedTheme).trim()
            console.log("[IconThemeService] Restoring saved icon theme:", root.currentTheme)
            gsettingsSetProc.themeName = root.currentTheme
            gsettingsSetProc.skipRestart = true
            gsettingsSetProc.running = false
            gsettingsSetProc.running = true
        } else {
            currentThemeProc.running = false
            currentThemeProc.running = true
        }
        
        // Load dock theme
        root.dockTheme = Config.options?.appearance?.dockIconTheme ?? ""
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

    function setDockTheme(themeName: string): void {
        root.dockTheme = themeName ?? ""
        Config.setNestedValue('appearance.dockIconTheme', themeName ?? "")
        Config.flushWrites()
        root.queueRestart()
    }

    Timer {
        id: restartDelay
        interval: 250
        repeat: false
        onTriggered: {
            root._restartQueued = false
            console.log("[IconThemeService] Restarting shell now...")
            Quickshell.execDetached(["/usr/bin/setsid", "/usr/bin/fish", "-c", "qs kill -c inir; sleep 0.3; qs -c inir"])
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
            // Also sync to qt5ct and qt6ct
            qt5ctProc.themeName = kwriteconfigProc.themeName
            qt5ctProc.running = false
            qt5ctProc.running = true
            qt6ctProc.themeName = kwriteconfigProc.themeName
            qt6ctProc.running = false
            qt6ctProc.running = true
        }
    }

    // Sync icon theme to qt5ct
    Process {
        id: qt5ctProc
        property string themeName: ""
        command: [
            "/usr/bin/python3",
            "-c",
            `
import configparser
import os

theme = "${qt5ctProc.themeName}"
config_path = os.path.expanduser("~/.config/qt5ct/qt5ct.conf")

if not os.path.exists(config_path):
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        f.write("[Appearance]\\nicon_theme=" + theme + "\\n")
else:
    config = configparser.ConfigParser()
    config.optionxform = str
    config.read(config_path)
    if "Appearance" not in config:
        config["Appearance"] = {}
    config["Appearance"]["icon_theme"] = theme
    with open(config_path, "w") as f:
        config.write(f, space_around_delimiters=False)
`
        ]
        onExited: (exitCode, exitStatus) => {
            console.log("[IconThemeService] qt5ct updated:", exitCode === 0 ? "success" : "failed")
        }
    }

    // Sync icon theme to qt6ct
    Process {
        id: qt6ctProc
        property string themeName: ""
        command: [
            "/usr/bin/python3",
            "-c",
            `
import configparser
import os

theme = "${qt6ctProc.themeName}"
config_path = os.path.expanduser("~/.config/qt6ct/qt6ct.conf")

if not os.path.exists(config_path):
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as f:
        f.write("[Appearance]\\nicon_theme=" + theme + "\\n")
else:
    config = configparser.ConfigParser()
    config.optionxform = str
    config.read(config_path)
    if "Appearance" not in config:
        config["Appearance"] = {}
    config["Appearance"]["icon_theme"] = theme
    with open(config_path, "w") as f:
        config.write(f, space_around_delimiters=False)
`
        ]
        onExited: (exitCode, exitStatus) => {
            console.log("[IconThemeService] qt6ct updated:", exitCode === 0 ? "success" : "failed")
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
