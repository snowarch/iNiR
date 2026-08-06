pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
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

    readonly property bool defaultApplyExternal: (Quickshell.env("INIR_STANDALONE_WINDOW") ?? "") !== "1"

    // Check if auto theme is selected (reads directly from Config to avoid circular dependency with ThemeService)
    readonly property bool isAutoTheme: (Config.options?.appearance?.theme ?? "auto") === "auto"

    function reapplyTheme() {
        _log("[MaterialThemeLoader] reapplyTheme called, filePath:", root.filePath)
        reloadDebounce.restart()
    }

    function colorToHex(c: color): string {
        return "#" + ((1 << 24) | (Math.round(c.r * 255) << 16) | (Math.round(c.g * 255) << 8) | Math.round(c.b * 255)).toString(16).slice(1)
    }

    // Toggle dark/light mode by running switchwall.sh with --mode and scheduling a reload.
    function setDarkMode(dark: bool): void {
        Config.setNestedValue("appearance.customTheme.darkmode", dark)
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
    // `mode` must be "dark" or "light" — without it, switchwall.sh falls back to
    // gsettings which is typically "prefer-dark", breaking light presets.
    function applySchemeVariant(seedColor: string, variant: string, mode: string): void {
        // Clear any stale force flag from a previous run
        root._forceApply = false
        Config.setNestedValue("appearance.palette.accentColor", seedColor)
        schemeVariantProc.command = [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--noswitch",
            "--skip-accent-write",
            "--color", seedColor,
            "--type", variant,
            "--mode", mode
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
                // Route through reloadDebounce so this doesn't race the
                // onFileChanged that the script's own write is about to fire.
                reloadDebounce.restart()
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
        
        if (typeof json.darkmode === "boolean") {
            Appearance.m3colors.darkmode = json.darkmode
        } else if (typeof json.darkmode === "string") {
            Appearance.m3colors.darkmode = json.darkmode === "true"
        } else {
            Appearance.m3colors.darkmode = (Appearance.m3colors.m3background.hslLightness < 0.5)
        }
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

    // Reactive colorInvert toggle: regenerate colors from wallpaper with
    // --invert-hue flag. The motor recalculates optimal tones for the
    // complementary hue, producing a natural palette.
    Connections {
        target: Config.options?.appearance ?? null
        function onColorInvertChanged() {
            root._log("[MaterialThemeLoader] colorInvert changed, regenerating from wallpaper")
            colorInvertProc.running = true
        }
    }

    Process {
        id: colorInvertProc
        running: false
        command: [
            "/usr/bin/bash",
            Directories.wallpaperSwitchScriptPath,
            "--noswitch",
            "--skip-accent-write"
        ]
        onExited: (code, status) => {
            if (code === 0) {
                root._forceApply = true
            }
            root.scheduleReload()
            delayedExternalApply.restart()
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

    // Single owner of external theme application. Every path that used to spawn
    // applycolor.sh on its own (ThemeService's auto branch, ThemePresets' preset
    // fan-out, variant/dark-mode process exits) routes here instead, so the
    // debounce collapses them into one run and the style overlay below is
    // guaranteed to land before any module reads the palette.
    function requestExternalApply(): void {
        delayedExternalApply.restart()
    }

    Timer {
        id: delayedExternalApply
        interval: 600
        repeat: false
        running: false
        onTriggered: root._applyExternalTheming()
    }

    // Re-apply external theming when the global style changes. The Material
    // palette is unchanged, so a full switchwall.sh re-extraction would be
    // wasted work — only the surface ramp the overlay writes has to catch up.
    Connections {
        target: Config.options?.appearance ?? null
        function onGlobalStyleChanged() {
            root._log("[MaterialThemeLoader] globalStyle changed, re-applying external theming")
            root.requestExternalApply()
        }
    }

    function _shq(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    // Flatten a token onto its backdrop. Style tokens are free to carry alpha
    // (cookie's hairline and inkMuted do); app-palette.json consumers are not.
    function _solid(value, backdrop): color {
        const c = Qt.color(value)
        if (!c.valid || c.a <= 0.001) return Qt.color(backdrop)
        if (c.a >= 0.999) return c
        return ColorUtils.mix(c, backdrop, c.a)
    }

    // The effective surface ramp of the active global style, in the shape
    // build_app_palette() emits. Same derivations as the generator — only the
    // input ramp differs, because zzz and cookie replace the Material
    // containers with their own generated plates and every other style
    // resolves back to the Material roles.
    function _styleAppPaletteOverlay(): var {
        const c = Appearance.colors
        if (!c) return null

        const l0 = _solid(c.colLayer0Base, Appearance.m3colors.m3background)
        const l1 = _solid(c.colLayer1Base, l0)
        const l2 = _solid(c.colLayer2Base, l1)
        const l3 = _solid(c.colLayer3Base, l2)
        const l4 = _solid(c.colLayer4Base, l3)

        const on0 = _solid(c.colOnLayer0, l0)
        const on1 = _solid(c.colOnLayer1, l1)
        const on2 = _solid(c.colOnLayer2, l2)
        const on3 = _solid(c.colOnLayer3, l3)
        const on4 = _solid(c.colOnLayer4, l4)

        const outline = _solid(c.colOutline, l1)
        const outlineVariant = _solid(c.colOutlineVariant, l1)
        const accent = _solid(c.colPrimary, l1)
        const onAccent = _solid(c.colOnPrimary, accent)
        const accentContainer = _solid(c.colPrimaryContainer, l2)
        const onAccentContainer = _solid(c.colOnPrimaryContainer, accentContainer)

        const subtext = ColorUtils.ensureReadable(ColorUtils.mix(on1, l1, 0.75), l1, 3.0)
        const selection = ColorUtils.mix(l3, accent, 0.82)
        const selectionHover = ColorUtils.mix(l3, accent, 0.74)
        const onSelection = ColorUtils.ensureReadable(on3, selection, 4.5)

        const hex = root.colorToHex
        return {
            "background": hex(l0),
            "on_background": hex(on0),
            "surface": hex(l0),
            "on_surface": hex(on1),
            "surface_dim": hex(l0),
            "surface_bright": hex(l3),
            "surface_container_lowest": hex(l0),
            "surface_container_low": hex(l1),
            "surface_container": hex(l2),
            "surface_container_high": hex(l3),
            "surface_container_highest": hex(l4),
            "outline": hex(outline),
            "outline_variant": hex(outlineVariant),
            "primary": hex(accent),
            "on_primary": hex(onAccent),
            "primary_container": hex(accentContainer),
            "on_primary_container": hex(onAccentContainer),
            "app_background": hex(l0),
            "app_foreground": hex(on0),
            "app_subtext": hex(subtext),
            "app_surface": hex(l1),
            "app_surface_hover": hex(ColorUtils.mix(l1, on1, 0.92)),
            "app_surface_active": hex(ColorUtils.mix(l1, on1, 0.85)),
            "app_surface_elevated": hex(l2),
            "app_surface_elevated_hover": hex(ColorUtils.mix(l2, on2, 0.90)),
            "app_surface_elevated_active": hex(ColorUtils.mix(l2, on2, 0.80)),
            "app_surface_popup": hex(l3),
            "app_surface_popup_hover": hex(ColorUtils.mix(l3, on3, 0.90)),
            "app_surface_popup_active": hex(ColorUtils.mix(l3, on3, 0.80)),
            "app_on_surface": hex(on1),
            "app_on_surface_elevated": hex(on2),
            "app_on_surface_popup": hex(on3),
            "app_on_surface_highest": hex(on4),
            "app_border": hex(outline),
            "app_border_subtle": hex(outlineVariant),
            "app_accent": hex(accent),
            "app_on_accent": hex(onAccent),
            "app_accent_container": hex(accentContainer),
            "app_selection": hex(selection),
            "app_selection_hover": hex(selectionHover),
            "app_on_selection": hex(onSelection),
            "app_window_bg": hex(l0),
            "app_view_bg": hex(l0),
            "app_headerbar_bg": hex(l0),
            "app_sidebar_bg": hex(l0),
            "app_card_bg": hex(l1),
            "app_popover_bg": hex(l2),
            "app_dialog_bg": hex(l3),
            "app_thumbnail_bg": hex(l4)
        }
    }

    function _applyExternalTheming(): void {
        if (!root.defaultApplyExternal) return;
        const applyColorPath = Directories.scriptsPath + "/colors/applycolor.sh"
        const overlay = root._styleAppPaletteOverlay()
        if (!overlay) {
            Quickshell.execDetached(["/usr/bin/bash", applyColorPath])
            return
        }
        // Merge and run share one shell invocation: the modules must never read
        // app-palette.json between the generator's write and the style overlay.
        // No `set -e` — a failed merge still has to fall through to the run.
        const script = `p=${_shq(Directories.generatedAppPalettePath)}
if command -v jq >/dev/null 2>&1 && [ -s "$p" ]; then
  printf '%s' ${_shq(JSON.stringify(overlay))} > "$p.style"
  if jq -s '.[0] * .[1]' "$p" "$p.style" > "$p.merged" 2>/dev/null; then
    mv -f "$p.merged" "$p"
  fi
  rm -f "$p.style" "$p.merged"
fi
exec /usr/bin/bash ${_shq(applyColorPath)}
`
        Quickshell.execDetached(["/usr/bin/bash", "-c", script])
    }

    // Debounce file-change notifications: theme pipeline writes the JSON
    // multiple times during boot (regenerateAutoTheme + applyCurrentTheme +
    // external scripts). Each onFileChanged calling reload() races the
    // previous reload op and drops it ("got operation finished from dropped
    // operation" warning). The timer batches rapid changes into one reload.
    Timer {
        id: reloadDebounce
        interval: 50
        repeat: false
        onTriggered: {
            themeFileView.reload()
            delayedFileRead.start()
            delayedExternalApply.restart()
        }
    }

    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true
        onFileChanged: {
            root._log("[MaterialThemeLoader] onFileChanged fired")
            reloadDebounce.restart()
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
