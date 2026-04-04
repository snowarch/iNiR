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
 *
 * Scheme variant generation (applySchemeVariant) runs switchwall.sh with a seed color.
 * Colors are force-applied from colors.json when the process exits, bypassing the
 * isAutoTheme gate to ensure variant colors always reach Appearance.m3colors.
 */
Singleton {
    id: root
    property string filePath: Directories.generatedMaterialThemePath
    property bool ready: false

    // Set to true ONLY when a variant generation process exits successfully.
    // Consumed by the next applyColors call. Unlike the old _schemeVariantPending
    // (set at start, consumed by any file-change callback), this flag cannot be
    // prematurely cleared by unrelated file-watch events.
    property bool _forceApply: false

    // Set by variant/dark-mode process exits; consumed by delayedExternalApply
    // to trigger applycolor.sh for terminals, GTK, etc.
    property bool _pendingExternalApply: false

    readonly property bool defaultApplyExternal: (Quickshell.env("QS_NO_RELOAD_POPUP") ?? "") !== "1"

    // Check if auto theme is selected (reads directly from Config to avoid circular dependency with ThemeService)
    readonly property bool isAutoTheme: (Config.options?.appearance?.theme ?? "auto") === "auto"

    function reapplyTheme() {
        _log("[MaterialThemeLoader] reapplyTheme called, filePath:", root.filePath)
        themeFileView.reload()
    }

    function colorToHex(c: color): string {
        return "#" + ((1 << 24) | (Math.round(c.r * 255) << 16) | (Math.round(c.g * 255) << 8) | Math.round(c.b * 255)).toString(16).slice(1)
    }

    // Toggle dark/light mode by running switchwall.sh with --mode and scheduling a reload.
    function setDarkMode(dark: bool): void {
        darkModeProc.command = [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--mode", dark ? "dark" : "light",
            "--noswitch"
        ]
        darkModeProc.running = true
    }

    // Apply a scheme variant using a seed color.
    // Works for both auto and static themes. Persists seed in config, then runs
    // the color generation script. Colors are force-applied on process exit.
    function applySchemeVariant(seedColor: string, variant: string): void {
        // Clear any stale force flag from a previous run
        root._forceApply = false
        Config.setNestedValue("appearance.palette.accentColor", seedColor)
        schemeVariantProc.command = [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--noswitch",
            "--skip-accent-write",
            "--color", seedColor,
            "--type", variant
        ]
        schemeVariantProc.running = true
    }

    Process {
        id: schemeVariantProc
        running: false
        onExited: (code, status) => {
            if (code === 0) {
                // Script succeeded — colors.json is ready. Set force flag so the
                // next applyColors call bypasses the isAutoTheme gate.
                root._forceApply = true
                root._pendingExternalApply = true
                // Trigger immediate re-read. onLoadedChanged will call applyColors
                // with _forceApply=true, applying the variant colors to Appearance.
                themeFileView.reload()
            }
            // Safety net: poll for file changes in case the immediate reload misses
            root.scheduleReload()
            // Apply external app theming (terminals, GTK, etc.) after generation
            delayedExternalApply.restart()
        }
    }

    Process {
        id: darkModeProc
        running: false
        onExited: (code, status) => {
            if (code === 0) {
                root._forceApply = true
                root._pendingExternalApply = true
            }
            root.scheduleReload()
            delayedExternalApply.restart()
        }
    }

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    function applyColors(fileContent) {
        _log("[MaterialThemeLoader] applyColors called, isAutoTheme:", root.isAutoTheme, "_forceApply:", root._forceApply)
        // Gate: only apply when auto theme is active OR we have an explicit
        // force flag from a completed variant/dark-mode generation.
        if (!root.isAutoTheme && !root._forceApply) {
            _log("[MaterialThemeLoader] BLOCKED by gate (not auto, no force)")
            return;
        }
        if (!fileContent || fileContent.trim().length === 0) {
            _log("[MaterialThemeLoader] BLOCKED — empty file content (keeping _forceApply for retry)")
            return
        }

        let json
        try {
            json = JSON.parse(fileContent)
        } catch (e) {
            _log("[MaterialThemeLoader] BLOCKED — JSON parse error (keeping _forceApply for retry):", e)
            return
        }

        if (!json || typeof json !== "object" || !json.background) {
            _log("[MaterialThemeLoader] BLOCKED — invalid JSON structure (no background key)")
            return
        }

        // Consume _forceApply only after successful validation — failed reads
        // must keep the flag so the poll timer can retry.
        root._forceApply = false

        _log("[MaterialThemeLoader] Applying", Object.keys(json).length, "color keys, bg:", json.background, "primary:", json.primary)
        for (const key in json) {
            if (json.hasOwnProperty(key)) {
                const camelCaseKey = key.replace(/_([a-z])/g, (g) => g[1].toUpperCase())
                const noPrefix = camelCaseKey.startsWith("term") || camelCaseKey === "darkmode" || camelCaseKey === "transparent"
                const m3Key = noPrefix ? camelCaseKey : `m3${camelCaseKey}`
                if (Appearance.m3colors[m3Key] === undefined)
                    continue
                Appearance.m3colors[m3Key] = json[key]
            }
        }
        
        Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5)
        _log("[MaterialThemeLoader] Colors applied successfully, darkmode:", Appearance.m3colors.darkmode)
    }

    function resetFilePathNextTime() {
        resetFilePathNextWallpaperChange.enabled = !!(Config.options?.background)
    }

    // Force a re-read of colors.json via polling, as a safety net when
    // file-change notifications are missed on some systems.
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
            // Run for auto themes (wallpaper change) and after explicit
            // variant/dark-mode generation (static or auto).
            if (!root.isAutoTheme && !root._pendingExternalApply) return;
            root._pendingExternalApply = false
            if (!root.defaultApplyExternal) return;
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptsPath + "/colors/applycolor.sh"
            ])
        }
    }

    FileView { 
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            root._log("[MaterialThemeLoader] onFileChanged fired")
            this.reload()
            delayedFileRead.start()
            delayedExternalApply.restart()
        }
        onLoadedChanged: {
            root._log("[MaterialThemeLoader] onLoadedChanged fired, loaded:", themeFileView.loaded)
            const fileContent = themeFileView.text()
            root._log("[MaterialThemeLoader] file content length:", fileContent ? fileContent.length : 0)
            root.applyColors(fileContent)
            root.ready = true
        }
        onLoadFailed: root.resetFilePathNextTime();
    }
}
