pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property var availableThemes: []
    property string currentTheme: ""
    property string dockTheme: ""  // Separate theme for dock icons

    property bool _initialized: false
    property bool _restartQueued: false

    // The mode is known only once the colours load (it starts dark): pick the sibling again then and on every switch,
    // or a light scheme keeps the dark variant's white icons.
    readonly property bool _dark: Appearance.m3colors.darkmode
    on_DarkChanged: if (root._initialized && root.currentTheme.length > 0) root._apply(root.currentTheme, true)

    // Smart icon resolution: preserve app-provided identity whenever possible.
    // Only repair the duplicated Electron resources path that is known-broken.
    function smartIconName(icon, appId) {
        if (!icon) {
            const guessed = AppSearch.lookupDesktopEntry(appId)?.icon ?? AppSearch.guessIcon(appId);
            return guessed || "application-x-executable";
        }
        
        if (icon.startsWith("/") || icon.startsWith("file://")) {
            const path = icon.startsWith("file://") ? icon.substring(7) : icon;

            if (path.indexOf("/resources/app/resources/") !== -1) {
                return path.replace("/resources/app/resources/", "/resources/");
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
        
        // Once the theme is indexed, the answer is the one file that exists (or none, and
        // the caller falls back to the system theme). Probing guessed paths through Image
        // loads logged a "Cannot open" for every miss, on every delegate recycle.
        if (root._dockIndexTheme === root.dockTheme) {
            const hit = root._dockIndex[iconName]
            return hit ? [`file://${hit}`] : []
        }

        return root._dockDirs(root.dockTheme).map(d => `file://${d}/${iconName}${d.endsWith("scalable") || d.endsWith("scalable/apps") ? ".svg" : ".png"}`)
    }

    // Where a dock theme keeps app icons, in the order they win.
    function _dockDirs(theme: string): list<string> {
        const home = Quickshell.env("HOME")
        return [
            `${home}/.local/share/icons/${theme}/apps/scalable`,
            `/usr/share/icons/${theme}/apps/scalable`,
            `${home}/.local/share/icons/${theme}/scalable/apps`,
            `/usr/share/icons/${theme}/scalable/apps`,
            `${home}/.local/share/icons/${theme}/apps/256x256`,
            `/usr/share/icons/${theme}/apps/256x256`,
            `${home}/.local/share/icons/${theme}/256x256/apps`,
            `/usr/share/icons/${theme}/256x256/apps`,
        ]
    }

    property var _dockIndex: ({})
    property string _dockIndexTheme: ""
    onDockThemeChanged: {
        dockIndexProc.running = false
        if (!root.dockTheme)
            return
        dockIndexProc.theme = root.dockTheme
        dockIndexProc.command = ["sh", "-c", 'for d in "$@"; do [ -d "$d" ] && find -L "$d" -maxdepth 1 -type f \\( -name "*.svg" -o -name "*.png" \\) -printf "%h/%f\\n"; done', "sh", ...root._dockDirs(root.dockTheme)]
        dockIndexProc.running = true
    }

    Process {
        id: dockIndexProc
        property string theme: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const index = {}
                const dirs = root._dockDirs(dockIndexProc.theme)
                const rank = path => dirs.indexOf(path.substring(0, path.lastIndexOf("/")))
                for (const path of text.split("\n")) {
                    if (!path)
                        continue
                    const file = path.substring(path.lastIndexOf("/") + 1)
                    const ext = file.endsWith(".svg") ? ".svg" : ".png"
                    // Same order as the guesses: svg dirs come first, then the 256 px pngs.
                    if (ext === ".svg" && rank(path) > 3 || ext === ".png" && rank(path) < 4)
                        continue
                    const name = file.slice(0, -4)
                    if (!(name in index) || rank(path) < rank(index[name]))
                        index[name] = path
                }
                root._dockIndex = index
                root._dockIndexTheme = dockIndexProc.theme
            }
        }
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
            _log("[IconThemeService] Restoring saved icon theme:", root.currentTheme)
            root._apply(root.currentTheme, true)
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
        _log("[IconThemeService] Setting icon theme:", themeStr)

        // Update UI immediately; actual system change follows via gsettings.
        root.currentTheme = themeStr

        root._apply(themeStr, false)
        
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
            _log("[IconThemeService] Restarting shell now...")
            Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
        }
    }

    function queueRestart(): void {
        if (root._restartQueued)
            return;
        root._restartQueued = true
        restartDelay.restart()
    }

    // `currentTheme` is the family the user chose; the system gets its sibling for the scheme's mode
    // (WhiteSur-dark on a light scheme draws white icons), the same pick apply-gtk-theme.sh makes.
    function _apply(themeName: string, skipRestart: bool): void {
        variantProc.themeName = themeName
        variantProc.skipRestart = skipRestart
        variantProc.running = false
        variantProc.running = true
    }

    Process {
        id: variantProc
        property string themeName: ""
        property bool skipRestart: false
        property string resolved: ""
        command: [Quickshell.shellPath("scripts/lib/accel-run"), "icon-theme",
            variantProc.themeName, Appearance.m3colors.darkmode ? "dark" : "light"]
        onStarted: variantProc.resolved = ""
        stdout: SplitParser {
            onRead: line => variantProc.resolved = line.trim()
        }
        onExited: (exitCode, exitStatus) => {
            gsettingsSetProc.themeName = exitCode === 0 && variantProc.resolved.length > 0
                ? variantProc.resolved : variantProc.themeName
            gsettingsSetProc.skipRestart = variantProc.skipRestart
            gsettingsSetProc.running = false
            gsettingsSetProc.running = true
        }
    }

    Process {
        id: gsettingsSetProc
        property string themeName: ""
        property bool skipRestart: false
        command: ["/usr/bin/gsettings", "set", "org.gnome.desktop.interface", "icon-theme", gsettingsSetProc.themeName]
        onExited: (exitCode, exitStatus) => {
            _log("[IconThemeService] gsettings set exited:", exitCode, "theme:", gsettingsSetProc.themeName)
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
        command: [Quickshell.shellPath("scripts/lib/accel-run"), "ini-set", Directories.homePath + "/.config/kdeglobals", "Icons", "Theme",
            kdeGlobalsUpdateProc.themeName]
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
            _log("[IconThemeService] kwriteconfig exited:", exitCode, "theme:", kwriteconfigProc.themeName)
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
        command: [Quickshell.shellPath("scripts/lib/accel-run"), "ini-set", Directories.homePath + "/.config/qt5ct/qt5ct.conf", "Appearance",
            "icon_theme", qt5ctProc.themeName]
        onExited: (exitCode, exitStatus) => {
            _log("[IconThemeService] qt5ct updated:", exitCode === 0 ? "success" : "failed")
        }
    }

    // Sync icon theme to qt6ct
    Process {
        id: qt6ctProc
        property string themeName: ""
        command: [Quickshell.shellPath("scripts/lib/accel-run"), "ini-set", Directories.homePath + "/.config/qt6ct/qt6ct.conf", "Appearance",
            "icon_theme", qt6ctProc.themeName]
        onExited: (exitCode, exitStatus) => {
            _log("[IconThemeService] qt6ct updated:", exitCode === 0 ? "success" : "failed")
            // Also sync to GTK settings.ini files
            gtkSettingsProc.themeName = qt6ctProc.themeName
            gtkSettingsProc.running = false
            gtkSettingsProc.running = true
        }
    }

    // Sync icon theme to GTK settings.ini (gtk-3.0 and gtk-4.0)
    Process {
        id: gtkSettingsProc
        property string themeName: ""
        command: ["/usr/bin/bash", "-c",
            "for d in gtk-3.0 gtk-4.0; do \"$1\" ini-set \"$2/.config/$d/settings.ini\" Settings gtk-icon-theme-name \"$3\" --replace-invalid || s=1; done; exit ${s:-0}",
            "_", Quickshell.shellPath("scripts/lib/accel-run"), Directories.homePath, gtkSettingsProc.themeName]
        onExited: (exitCode, exitStatus) => {
            _log("[IconThemeService] GTK settings.ini updated:", exitCode === 0 ? "success" : "failed")
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
