pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Automatically reloads generated material colors.
 * It is necessary to run reapplyTheme() on startup because Singletons are lazily loaded.
 * 
 * When a manual theme is selected (Config.options.appearance.theme !== "auto"),
 * this loader will not apply wallpaper colors, allowing the manual theme to remain active.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property bool ready: false
    property bool _schemeVariantPending: false

    readonly property bool defaultApplyExternal: (Quickshell.env("QS_NO_RELOAD_POPUP") ?? "") !== "1"

    // Check if auto theme is selected (reads directly from Config to avoid circular dependency with ThemeService)
    readonly property bool isAutoTheme: (Config.options?.appearance?.theme ?? "auto") === "auto"

    function reapplyTheme() {
        themeFileView.reload()
    }

    // Toggle dark/light mode by running switchwall.sh with --mode and scheduling a reload.
    // Use this instead of Quickshell.execDetached so we can force-read colors.json on completion.
    function setDarkMode(dark: bool): void {
        darkModeProc.command = [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--mode", dark ? "dark" : "light",
            "--noswitch"
        ]
        darkModeProc.running = true
    }

    // Apply a scheme variant using a seed color (for non-auto themes).
    // Generates new Material colors from the given seed hex via matugen, then applies them.
    function applySchemeVariant(seedColor: string, variant: string): void {
        root._schemeVariantPending = true
        schemeVariantProc.command = [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--noswitch",
            "--color", seedColor,
            "--type", variant
        ]
        schemeVariantProc.running = true
    }

    Process {
        id: schemeVariantProc
        running: false
        onExited: root.scheduleReload()
    }

    Process {
        id: darkModeProc
        running: false
        onExited: root.scheduleReload()
    }

    function applyColors(fileContent) {
        // Only apply wallpaper colors when auto theme is selected or a scheme variant change is pending.
        // When a manual theme is active (without variant override), ThemePresets handles the colors.
        if (!root.isAutoTheme && !root._schemeVariantPending) {
            return;
        }
        root._schemeVariantPending = false

        if (!fileContent || fileContent.trim().length === 0) {
            return
        }

        let json
        try {
            json = JSON.parse(fileContent)
        } catch (e) {
            // FileView can read while colors.json is being rewritten.
            // Ignore transient parse errors and wait for next change event.
            return
        }

        if (!json || typeof json !== "object" || !json.background) {
            return
        }

        for (const key in json) {
            if (json.hasOwnProperty(key)) {
                // Convert snake_case to CamelCase
                const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                // Terminal colors (term0-term15) and control flags (darkmode, transparent)
                // are stored without the m3 prefix in Appearance.m3colors
                const noPrefix = camelCaseKey.startsWith("term") || camelCaseKey === "darkmode" || camelCaseKey === "transparent"
                const m3Key = noPrefix ? camelCaseKey : `m3${camelCaseKey}`
                if (Appearance.m3colors[m3Key] === undefined)
                    continue
                Appearance.m3colors[m3Key] = json[key]
            }
        }
        
        Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5)
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = !!(Config.options?.background)
    }

    // Called after dark/light mode toggle scripts to force a re-read of colors.json,
    // since external file watchers may miss rapid rewrites on some systems.
    function scheduleReload() {
        reloadPollTimer.remainingAttempts = 6
        reloadPollTimer.restart()
    }

    Timer {
        id: reloadPollTimer
        interval: 800
        repeat: true
        running: false
        property int remainingAttempts: 0
        onTriggered: {
            if (remainingAttempts <= 0) {
                running = false
                return
            }
            remainingAttempts--
            themeFileView.reload()
            const content = themeFileView.text()
            if (content && content.trim().length > 0) {
                root.applyColors(content)
                if (remainingAttempts <= 0) running = false
            }
        }
    }

    Connections {
        id: resetFilePathNextWallpaperChange
        enabled: false
        target: Config.options?.background ?? null
        function onWallpaperPathChanged() {
            root.filePath = ""
            root.filePath = Directories.generatedMaterialThemePath
            resetFilePathNextWallpaperChange.enabled = false
        }
    }

    Timer {
        id: delayedFileRead
        interval: Config.options?.hacks?.arbitraryRaceConditionDelay ?? 100
        repeat: false
        running: false
        onTriggered: {
            root.applyColors(themeFileView.text())
        }
    }

    Timer {
        id: delayedExternalApply
        interval: 600
        repeat: false
        running: false
        onTriggered: {
            if (!root.isAutoTheme) return;
            if (!root.defaultApplyExternal) return;
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptPath + "/colors/applycolor.sh"
            ])
        }
    }

    FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            this.reload()
            delayedFileRead.start()
            delayedExternalApply.restart()
        }
        onLoadedChanged: {
            const fileContent = themeFileView.text()
            root.applyColors(fileContent)
            root.ready = true
        }
        onLoadFailed: root.resetFilePathNextTime();
    }
}
