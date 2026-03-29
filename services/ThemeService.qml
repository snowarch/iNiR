pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common
import qs.services

Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property bool ready: false
    readonly property string currentTheme: Config.options?.appearance?.theme ?? "auto"
    readonly property bool isAutoTheme: currentTheme === "auto"
    readonly property bool isStandaloneSettingsWindow: (Quickshell.env("QS_NO_RELOAD_POPUP") ?? "") === "1"
    readonly property bool defaultApplyExternal: !isStandaloneSettingsWindow
    readonly property bool vesktopEnabled: (Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true) !== false
    readonly property var wallpaperThemingCfg: Config.options?.appearance?.wallpaperTheming ?? null
    readonly property var terminalAdjCfg: wallpaperThemingCfg?.terminalColorAdjustments ?? null
    readonly property string liveRegenSignature: JSON.stringify({
        theme: currentTheme,
        themingWallpaperPath: Wallpapers.effectiveWallpaperPath ?? "",
        enableAppsAndShell: wallpaperThemingCfg?.enableAppsAndShell ?? true,
        enableTerminal: wallpaperThemingCfg?.enableTerminal ?? true,
        enableVesktop: wallpaperThemingCfg?.enableVesktop ?? true,
        enableChrome: wallpaperThemingCfg?.enableChrome ?? true,
        enableZed: wallpaperThemingCfg?.enableZed ?? true,
        enableVSCode: wallpaperThemingCfg?.enableVSCode ?? true,
        useBackdropForColors: wallpaperThemingCfg?.useBackdropForColors ?? false,
        forceTerminalDarkMode: wallpaperThemingCfg?.terminalGenerationProps?.forceDarkMode ?? false,
        termSaturation: terminalAdjCfg?.saturation ?? 0.65,
        termBrightness: terminalAdjCfg?.brightness ?? 0.6,
        termHarmony: terminalAdjCfg?.harmony ?? 0.4,
        termBackgroundBrightness: terminalAdjCfg?.backgroundBrightness ?? 0.5,
        softenColors: Config.options?.appearance?.softenColors ?? true,
    })
    property string _lastLiveRegenSignature: ""
    property real _lastRegenTimestamp: 0

    onCurrentThemeChanged: {
        if (Config.ready) {
            root._log("[ThemeService] currentTheme changed to:", currentTheme, "- applying");
            Qt.callLater(() => applyCurrentTheme(defaultApplyExternal));
        }
    }

    function setTheme(themeId, applyExternal = true): void {
        root._log("[ThemeService] setTheme called with:", themeId);
        Config.setNestedValue(["appearance", "theme"], themeId)
        
        // Update recent themes (max 4, no duplicates)
        let recent = Config.options?.appearance?.recentThemes ?? []
        recent = recent.filter(t => t !== themeId)
        recent.unshift(themeId)
        if (recent.length > 4) recent = recent.slice(0, 4)
        Config.setNestedValue("appearance.recentThemes", recent)
        
        root._log("[ThemeService] Config updated, now applying theme");
        if (themeId === "auto") {
            root._log("[ThemeService] Auto theme, regenerating from wallpaper");
            // Force regeneration of colors from wallpaper
            Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch"]);
        } else {
            root._log("[ThemeService] Manual theme, calling ThemePresets.applyPreset");
            ThemePresets.applyPreset(themeId, applyExternal);
            if (applyExternal && vesktopEnabled) {
                root._log("[ThemeService] Manual setTheme requesting Vesktop regeneration")
                root._triggerVesktopThemeGeneration()
            }
        }
        root._log("[ThemeService] setTheme completed");
    }

    function _triggerVesktopThemeGeneration(): void {
        root._log("[ThemeService] Triggering Vesktop theme generation wrapper")
        Qt.callLater(() => {
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptPath + "/colors/system24_palette.sh"
            ]);
        });
    }

    function applyCurrentTheme(applyExternal = defaultApplyExternal): void {
        root._log("[ThemeService] applyCurrentTheme called, currentTheme:", currentTheme, "isAutoTheme:", isAutoTheme);
        if (isAutoTheme) {
            root._log("[ThemeService] Delegating to MaterialThemeLoader");
            MaterialThemeLoader.reapplyTheme();

            // Apply terminal colors if they exist (from previous generation)
            if (applyExternal) {
                Qt.callLater(() => {
                    Quickshell.execDetached([
                        "/usr/bin/bash",
                        Directories.scriptPath + "/colors/applycolor.sh"
                    ]);
                });
            }

            if (applyExternal && vesktopEnabled) {
                root._triggerVesktopThemeGeneration()
            }
        } else {
            root._log("[ThemeService] Applying manual theme:", currentTheme);
            ThemePresets.applyPreset(currentTheme, applyExternal);
            if (applyExternal && vesktopEnabled) {
                root._log("[ThemeService] applyCurrentTheme manual branch requesting Vesktop regeneration")
                root._triggerVesktopThemeGeneration()
            }
        }
        root.ready = true;
    }

    function regenerateAutoTheme(): void {
        root._log("[ThemeService] regenerateAutoTheme called");
        // Cooldown: prevent rapid successive regenerations (e.g. during settings navigation)
        const now = Date.now()
        if (now - root._lastRegenTimestamp < 3000) {
            root._log("[ThemeService] regenerateAutoTheme skipped — cooldown active");
            return
        }
        root._lastRegenTimestamp = now
        if (isAutoTheme) {
            // Force full regeneration from wallpaper (includes terminals, GTK, etc)
            const themingPath = Wallpapers.currentThemingWallpaperPath()
            const command = [Directories.wallpaperSwitchScriptPath, "--noswitch"]
            if (themingPath && themingPath.length > 0)
                command.push("--image", themingPath)
            Quickshell.execDetached(command);
        } else {
            // For manual presets, just re-apply with external apps
            ThemePresets.applyPreset(currentTheme, true);
        }
    }

    function _tryLiveRegenerateFromConfig(): void {
        if (!Config.ready || !isAutoTheme) return
        // Skip if a direct Wallpapers.apply() already launched switchwall.sh
        if (Wallpapers._applyInProgress) return
        if (root.liveRegenSignature === root._lastLiveRegenSignature) return
        root._lastLiveRegenSignature = root.liveRegenSignature
        root.regenerateAutoTheme()
    }

    Connections {
        target: Config
        function onConfigChanged() {
            liveRegenerateDebounce.restart()
        }
        function onReadyChanged() {
            if (Config.ready) {
                root._lastLiveRegenSignature = ""
                liveRegenerateDebounce.restart()
            }
        }
    }

    Timer {
        id: liveRegenerateDebounce
        interval: 260
        repeat: false
        running: false
        onTriggered: root._tryLiveRegenerateFromConfig()
    }

    // Theme Scheduling
    readonly property bool scheduleEnabled: Config.options?.appearance?.themeSchedule?.enabled ?? false
    
    function isNightTime(): bool {
        const now = new Date()
        const currentMinutes = now.getHours() * 60 + now.getMinutes()
        
        const dayStart = Config.options?.appearance?.themeSchedule?.dayStart ?? "06:00"
        const nightStart = Config.options?.appearance?.themeSchedule?.nightStart ?? "18:00"
        
        const [dayH, dayM] = dayStart.split(":").map(Number)
        const [nightH, nightM] = nightStart.split(":").map(Number)
        
        const dayMinutes = dayH * 60 + dayM
        const nightMinutes = nightH * 60 + nightM
        
        // Night if before day start or after night start
        return currentMinutes < dayMinutes || currentMinutes >= nightMinutes
    }
    
    function applyScheduledTheme(): void {
        if (!scheduleEnabled) return
        
        const schedule = Config.options?.appearance?.themeSchedule
        const targetTheme = isNightTime() ? schedule?.nightTheme : schedule?.dayTheme
        
        if (targetTheme && targetTheme !== currentTheme) {
            root._log("[ThemeService] Schedule: switching to", targetTheme)
            setTheme(targetTheme, true)
        }
    }
    
    Timer {
        interval: 60000  // Check every minute
        running: root.scheduleEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: root.applyScheduledTheme()
    }
}
