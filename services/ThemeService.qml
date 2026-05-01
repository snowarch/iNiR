pragma Singleton
pragma ComponentBehavior: Bound

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
    readonly property bool isStandaloneSettingsWindow: (Quickshell.env("INIR_STANDALONE_WINDOW") ?? "") === "1"
    readonly property bool defaultApplyExternal: !isStandaloneSettingsWindow
    readonly property bool vesktopEnabled: (Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true) !== false
    readonly property var wallpaperThemingCfg: Config.options?.appearance?.wallpaperTheming ?? null
    readonly property var terminalAdjCfg: wallpaperThemingCfg?.terminalColorAdjustments ?? null
    readonly property string panelFamily: Config.options?.panelFamily ?? "ii"
    readonly property bool waffleUsesMainWallpaper: Config.options?.waffles?.background?.useMainWallpaper ?? true
    readonly property string liveRegenSignature: JSON.stringify({
        theme: currentTheme,
        panelFamily: root.panelFamily,
        waffleUsesMainWallpaper: root.waffleUsesMainWallpaper,
        paletteType: Config.options?.appearance?.palette?.type ?? "auto",
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
    property string _lastPanelFamily: ""
    property real _lastRegenTimestamp: 0
    property bool _regenPending: false
    readonly property int _regenCooldownMs: 700

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
            root._log("[ThemeService] Auto theme, scheduling wallpaper regeneration");
            // Delay switchwall.sh so Config.setNestedValue flushes to disk first
            // (50ms FileView timer). Without this, switchwall.sh reads the OLD
            // theme from config.json and may erroneously use the accent color.
            setAutoRegenTimer.restart()
        } else {
            root._log("[ThemeService] Manual theme, calling ThemePresets.applyPreset");
            const paletteType = Config.options?.appearance?.palette?.type ?? "auto"
            if (paletteType !== "auto") {
                // Variant active: apply preset instantly, then regenerate variant colors
                ThemePresets.applyPreset(themeId, false, true);
                const seedColor = MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                const mode = Appearance.m3colors.darkmode ? "dark" : "light"
                root._log("[ThemeService] setTheme with variant", paletteType, "seed", seedColor, "mode", mode);
                MaterialThemeLoader.applySchemeVariant(seedColor, paletteType, mode)
            } else {
                ThemePresets.applyPreset(themeId, applyExternal);
                if (applyExternal && vesktopEnabled) {
                    root._log("[ThemeService] Manual setTheme requesting Vesktop regeneration")
                    root._triggerVesktopThemeGeneration()
                }
            }
        }
        root._log("[ThemeService] setTheme completed");
    }

    function _triggerVesktopThemeGeneration(): void {
        root._log("[ThemeService] Triggering Vesktop theme generation wrapper")
        Qt.callLater(() => {
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptsPath + "/colors/system24_palette.sh"
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
                        Directories.scriptsPath + "/colors/applycolor.sh"
                    ]);
                });
            }

            if (applyExternal && vesktopEnabled) {
                root._triggerVesktopThemeGeneration()
            }
        } else {
            const paletteType = Config.options?.appearance?.palette?.type ?? "auto"
            root._log("[ThemeService] Applying manual theme:", currentTheme, "paletteType:", paletteType);
            if (paletteType !== "auto") {
                // Variant active: apply preset colors instantly (skip colors.json — variant will overwrite)
                ThemePresets.applyPreset(currentTheme, false, true);
                const configAccent = Config.options?.appearance?.palette?.accentColor ?? ""
                const seedColor = configAccent.length > 0
                    ? configAccent
                    : MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                const mode = Appearance.m3colors.darkmode ? "dark" : "light"
                root._log("[ThemeService] Re-applying variant", paletteType, "with seed", seedColor, "mode", mode);
                MaterialThemeLoader.applySchemeVariant(seedColor, paletteType, mode)
                if (applyExternal && vesktopEnabled) {
                    root._triggerVesktopThemeGeneration()
                }
            } else {
                ThemePresets.applyPreset(currentTheme, applyExternal);
                if (applyExternal && vesktopEnabled) {
                    root._log("[ThemeService] applyCurrentTheme manual branch requesting Vesktop regeneration")
                    root._triggerVesktopThemeGeneration()
                }
            }
        }
        root.ready = true;
    }

    function regenerateAutoTheme(): void {
        root._log("[ThemeService] regenerateAutoTheme called");
        const now = Date.now()
        const elapsed = now - root._lastRegenTimestamp
        if (elapsed < root._regenCooldownMs) {
            root._regenPending = true
            regenCooldownTimer.interval = Math.max(80, root._regenCooldownMs - elapsed)
            regenCooldownTimer.restart()
            root._log("[ThemeService] regenerateAutoTheme deferred — cooldown active");
            return
        }

        // Sync the live-regen signature now so the debounce path that
        // tails an explicit regen call (config write + manual call from a
        // settings widget) doesn't fire a redundant second switchwall.sh
        // once the cooldown lifts.
        root._lastLiveRegenSignature = root.liveRegenSignature
        root._lastPanelFamily = root.panelFamily
        root._regenPending = false
        regenCooldownTimer.stop()
        root._lastRegenTimestamp = now
        if (isAutoTheme) {
            // Force full regeneration from wallpaper (includes terminals, GTK, etc)
            const themingPath = Wallpapers.currentThemingWallpaperPath()
            const paletteType = Config.options?.appearance?.palette?.type ?? "auto"
            const command = [Directories.wallpaperSwitchScriptPath, "--noswitch"]
            if (paletteType !== "auto")
                command.push("--type", paletteType)
            if (themingPath && themingPath.length > 0)
                command.push("--image", themingPath)
            Quickshell.execDetached(command);
        } else {
            // For manual presets, re-apply (variant-aware)
            const paletteType = Config.options?.appearance?.palette?.type ?? "auto"
            if (paletteType !== "auto") {
                ThemePresets.applyPreset(currentTheme, false, true);
                const configAccent = Config.options?.appearance?.palette?.accentColor ?? ""
                const seedColor = configAccent.length > 0
                    ? configAccent
                    : MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                const mode = Appearance.m3colors.darkmode ? "dark" : "light"
                MaterialThemeLoader.applySchemeVariant(seedColor, paletteType, mode)
            } else {
                ThemePresets.applyPreset(currentTheme, true);
            }
        }
    }

    function _tryLiveRegenerateFromConfig(): void {
        if (!Config.ready) return
        if (root.liveRegenSignature === root._lastLiveRegenSignature) return
        // Always track the signature — even when not on auto theme.
        // Otherwise switching manual→auto sees the stale auto signature
        // and skips regeneration.
        root._lastLiveRegenSignature = root.liveRegenSignature

        // Detect family change — switchwall.sh is family-aware so the full
        // pipeline must re-run even for manual themes (different wallpaper
        // resolution, different external-app color targets).
        const familyChanged = root.panelFamily !== root._lastPanelFamily
        root._lastPanelFamily = root.panelFamily

        if (!isAutoTheme && !familyChanged) return
        // Skip if a direct Wallpapers.apply() already launched switchwall.sh
        if (Wallpapers._applyInProgress) return
        root.regenerateAutoTheme()
    }

    Connections {
        target: Config
        function onConfigChanged() {
            liveRegenerateDebounce.restart()
        }
        function onReadyChanged() {
            if (!Config.ready) return
            // Prime the signature to current value so the first config write
            // doesn't get treated as a delta-from-empty.  The forced regen on
            // shell startup is still done explicitly by shell.qml via
            // ThemeService.applyCurrentTheme() — no need to do it here too.
            // Standalone settings windows must NEVER run a phantom regen on
            // open: they're observers, not orchestrators.
            root._lastLiveRegenSignature = root.liveRegenSignature
            root._lastPanelFamily = root.panelFamily
        }
    }

    Timer {
        id: liveRegenerateDebounce
        interval: 260
        repeat: false
        running: false
        onTriggered: root._tryLiveRegenerateFromConfig()
    }

    Timer {
        id: regenCooldownTimer
        interval: root._regenCooldownMs
        repeat: false
        running: false
        onTriggered: {
            if (root._regenPending)
                root.regenerateAutoTheme()
        }
    }

    Timer {
        id: setAutoRegenTimer
        interval: 100  // > Config FileView 50ms flush timer
        repeat: false
        running: false
        // Route through regenerateAutoTheme so the signature stays in sync —
        // this prevents the configChanged debounce 260ms later from firing a
        // duplicate switchwall.sh.
        onTriggered: root.regenerateAutoTheme()
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
