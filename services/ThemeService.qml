pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
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
    // What iRiS asks of the system's mode and of the apps' surfaces: both are read by switchwall.sh, so a change regenerates.
    readonly property string irisSchemeChoice: panelFamily === "iris" ? String(Config.options?.iris?.appearance?.scheme ?? "auto") : "auto"
    readonly property bool irisMaterialApps: panelFamily === "iris" && (Config.options?.iris?.appearance?.materialForApps ?? true)
    property string appsSurfaceSeed: ""
    // A scheme the person picks is also their saved preference, so Auto keeps what they last saw instead of an older toggle.
    onIrisSchemeChoiceChanged: {
        if (!Config.ready || irisSchemeChoice === "auto") return
        const wantDark = irisSchemeChoice === "dark"
        if ((Config.options?.appearance?.customTheme?.darkmode ?? true) !== wantDark)
            Config.setNestedValue("appearance.customTheme.darkmode", wantDark)
    }
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
        enableFirefox: wallpaperThemingCfg?.enableFirefox ?? true,
        enableZed: wallpaperThemingCfg?.enableZed ?? true,
        enableVSCode: wallpaperThemingCfg?.enableVSCode ?? true,
        enableNeovim: wallpaperThemingCfg?.enableNeovim ?? false,
        useBackdropForColors: wallpaperThemingCfg?.useBackdropForColors ?? false,
        forceTerminalDarkMode: wallpaperThemingCfg?.terminalGenerationProps?.forceDarkMode ?? false,
        termSaturation: terminalAdjCfg?.saturation ?? 0.65,
        termBrightness: terminalAdjCfg?.brightness ?? 0.6,
        termHarmony: terminalAdjCfg?.harmony ?? 0.4,
        termBackgroundBrightness: terminalAdjCfg?.backgroundBrightness ?? 0.5,
        softenColors: Config.options?.appearance?.softenColors ?? true,
        autoDarkLightMode: wallpaperThemingCfg?.autoDarkLightMode ?? false,
        irisScheme: root.irisSchemeChoice === "ink" ? "light" : root.irisSchemeChoice,
        irisMaterialApps: root.irisMaterialApps,
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

    // A saved or Hub colour theme: its colours become the custom theme. ThemesConfig and the Hub
    // pages of every family apply through here, so a theme looks the same wherever it was chosen.
    function applyCustomColors(colors: var): void {
        const current = Config.options?.appearance?.customTheme ?? ({})
        const updates = ({})
        for (const key in colors) {
            if (current.hasOwnProperty(key))
                updates[`appearance.customTheme.${key}`] = colors[key]
        }
        Config.setNestedValues(updates)
        ThemePresets.applyPreset("custom")
        if (root.currentTheme !== "custom")
            root.setTheme("custom")
    }

    // ── Global style ────────────────────────────────────────────────────
    // Single owner of "what does selecting style X write to config". This
    // lived in three places (both settings families and the action registry)
    // that had already drifted: waffle ignored the per-style corner defaults
    // entirely, and the action registry had no cookie branch at all, so cookie
    // silently inherited material's corner style.

    function cornerStyleForGlobalStyle(styleId: string): int {
        const styles = Config.options?.appearance?.globalStyleCornerStyles
        switch (styleId) {
        case "cards": return styles?.cards ?? 3
        case "aurora": return styles?.aurora ?? 1
        case "inir": return styles?.inir ?? 1
        case "angel": return styles?.angel ?? 1
        case "regalia": return styles?.regalia ?? 1
        case "zzz": return styles?.zzz ?? 0
        case "cookie": return styles?.cookie ?? 1
        case "editorial": return styles?.editorial ?? 1
        default: return styles?.material ?? 1
        }
    }

    function setGlobalStyle(styleId: string): void {
        root._log("[ThemeService] setGlobalStyle:", styleId)
        const cards = styleId === "cards"
        let cornerStyle = root.cornerStyleForGlobalStyle(styleId)
        // Hug (0) leaves no float gap for angel's escalonado shadows to land in.
        if (styleId === "angel" && cornerStyle === 0)
            cornerStyle = 1
        Config.setNestedValues({
            "appearance.globalStyle": styleId,
            "dock.cardStyle": cards,
            "sidebar.cardStyle": cards,
            "bar.cornerStyle": cornerStyle
        })
    }

    readonly property var globalStyles: ["material", "cards", "aurora", "inir", "angel", "regalia", "zzz", "cookie", "editorial"]

    IpcHandler {
        target: "globalStyle"
        function set(style: string): string {
            const id = String(style ?? "").trim().toLowerCase()
            if (!root.globalStyles.includes(id))
                return "Unknown style: " + root.globalStyles.join(", ")
            root.setGlobalStyle(id)
            return id
        }
        function get(): string { return Config.options?.appearance?.globalStyle ?? "material" }
        function list(): string { return root.globalStyles.join(", ") }
    }

    IpcHandler {
        target: "colorMode"
        function set(mode: string): string {
            const wanted = String(mode ?? "").trim().toLowerCase()
            if (wanted === "toggle") { Appearance.toggleDarkMode(); return "toggled" }
            if (!["dark", "light"].includes(wanted)) return "Unknown mode: dark, light or toggle"
            if (root.isAutoTheme) MaterialThemeLoader.setDarkMode(wanted === "dark")
            else if (Appearance.m3colors.darkmode !== (wanted === "dark")) Appearance.toggleDarkMode()
            return wanted
        }
        function get(): string {
            return JSON.stringify({
                mode: Appearance.m3colors.darkmode ? "dark" : "light",
                colourTheme: root.currentTheme,
                saved: (Config.options?.appearance?.customTheme?.darkmode ?? true) ? "dark" : "light",
                fromWallpaper: wallpaperThemingCfg?.autoDarkLightMode ?? false,
                irisScheme: root.irisSchemeChoice
            })
        }
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

            // Apply terminal colors if they exist (from previous generation).
            // MaterialThemeLoader owns the run: spawning applycolor.sh here as
            // well doubled every user action into two parallel module waves.
            if (applyExternal) {
                MaterialThemeLoader.requestExternalApply();
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
            root._primeLiveRegen()
        }
    }
    // Prime the signature to current value so the first config write
    // doesn't get treated as a delta-from-empty.  The forced regen on
    // shell startup is still done explicitly by shell.qml via
    // ThemeService.applyCurrentTheme() — no need to do it here too.
    // Standalone settings windows must NEVER run a phantom regen on
    // open: they're observers, not orchestrators.
    // Config is usually ready before this singleton is first imported, and then readyChanged never comes.
    function _primeLiveRegen(): void {
        if (!Config.ready) return
        root._lastLiveRegenSignature = root.liveRegenSignature
        root._lastPanelFamily = root.panelFamily
    }
    Component.onCompleted: root._primeLiveRegen()

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
