pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../UmbrielModel.js" as UmbrielModel

/**
 * Keybinds for Niri compositor with iNiR shell.
 * Dynamically parses user's ~/.config/niri/config.kdl
 * Falls back to defaults if parsing fails.
 *
 * Under Umbriel the cheatsheet reads ~/.config/umbriel/config.d/70-binds.toml and
 * 90-user-extra.toml instead (read-only: Umbriel's keys are edited in its files).
 *
 * Read/write support: setBind() and removeBind() write back
 * to the keybinds KDL file via inir-accel niri-config.
 */
Singleton {
    id: root

    // ── Legacy cheatsheet model (inir-accel niri-keybinds) ────────────────
    property var keybinds: ({
        children: defaultKeybinds
    })

    property bool loaded: false
    property string configPath: ""
    property string errorMessage: ""

    // ── Enriched editor model (inir-accel niri-config get-binds) ──────────────────
    property var allBinds: []
    property var enrichedCategories: []

    // ── Signals for UI feedback ───────────────────────────────────────────
    signal bindSaved(string keyCombo)
    signal bindRemoved(string keyCombo)
    signal bindError(string message)

    // ── Script paths ──────────────────────────────────────────────────────
    readonly property string accelRun: Quickshell.shellPath("scripts/lib/accel-run")

    // Internal: pending key combos tracked for signal emission
    property string _pendingSetCombo: ""
    property string _pendingRemoveCombo: ""

    // ── Public API ────────────────────────────────────────────────────────

    readonly property bool umbriel: CompositorService.isUmbriel
    readonly property string umbrielConfigDir: Quickshell.env("HOME") + "/.config/umbriel/config.d"

    function reload(): void {
        if (root.umbriel) {
            root._readUmbrielBinds()
            return
        }
        if (!CompositorService.niriNative)
            return
        keybindParser.running = true
        enrichedBindsLoader.running = true
    }

    function _readUmbrielBinds(): void {
        const groups = UmbrielModel.bindsFrom([umbrielBinds.text(), umbrielUserBinds.text()], "Super")
        root.allBinds = []
        root.enrichedCategories = []
        if (groups.length === 0)
            return
        root.keybinds = { children: groups, configPath: umbrielBinds.path }
        root.configPath = umbrielBinds.path
        root.loaded = true
    }

    FileView {
        id: umbrielBinds
        path: root.umbriel ? root.umbrielConfigDir + "/70-binds.toml" : ""
        watchChanges: true
        printErrors: false
        onLoaded: root._readUmbrielBinds()
        onFileChanged: reload()
    }

    FileView {
        id: umbrielUserBinds
        path: root.umbriel ? root.umbrielConfigDir + "/90-user-extra.toml" : ""
        watchChanges: true
        printErrors: false
        onLoaded: root._readUmbrielBinds()
        onLoadFailed: root._readUmbrielBinds()
        onFileChanged: reload()
    }

    // False when a save is already in flight; the result comes back as bindSaved or bindError.
    function setBind(keyCombo: string, action: string, options: string): bool {
        if (!CompositorService.niriNative)
            return false
        if (setBindProcess.running) {
            console.warn("[NiriKeybinds] setBind: process already running, ignoring")
            return false
        }
        root._pendingSetCombo = keyCombo
        const args = [root.accelRun, "niri-config", "set-bind", keyCombo, action]
        if (options && options.length > 0)
            args.push("--options", options)
        setBindProcess.command = args
        setBindProcess.running = true
        return true
    }

    // inir-accel niri-config prints {"error", "detail"} JSON on a non-zero exit too.
    function _failureText(output: string, fallback: string): string {
        try {
            const result = JSON.parse(output)
            if (result?.detail)
                console.warn("[NiriKeybinds] niri said:", result.detail)
            return result?.error ?? fallback
        } catch (e) {
            return output.length > 0 ? output : fallback
        }
    }

    function removeBind(keyCombo: string): void {
        if (!CompositorService.niriNative) return
        root._removeBind(keyCombo, true)
    }

    // A rename drops the old combo after saving the new one: nothing was removed, so no Undo.
    function removeBindQuietly(keyCombo: string): void {
        if (!CompositorService.niriNative) return
        root._removeBind(keyCombo, false)
    }

    function _removeBind(keyCombo: string, offerUndo: bool): void {
        if (removeBindProcess.running) {
            console.warn("[NiriKeybinds] removeBind: process already running, ignoring")
            return
        }
        root._pendingRemoveCombo = keyCombo
        removeBindProcess.command = [root.accelRun, "niri-config", "remove-bind", keyCombo]
        removeBindProcess.running = true
        const gone = root.allBinds.find(bind => bind.keyCombo === keyCombo)
        if (offerUndo && gone && String(gone.actionRaw ?? "").length > 0)
            Undo.offer(Translation.tr("Removed %1").arg(keyCombo), () => root.setBind(keyCombo, gone.actionRaw, gone.optionsStr ?? ""))
    }

    // Niri's config is the truth (a managed block in 90-user-extra.kdl, inir-accel niri-config);
    // "custom" is an Alt+Tab the person bound themselves.
    property string altTabSource: ""
    function refreshAltTab(): void {
        if (CompositorService.niriNative && !altTabReader.running) altTabReader.running = true
    }
    function setAltTabSource(source: string): void {
        if (source !== "inir" && source !== "niri") return
        if (altTabWriter.running || !CompositorService.niriNative) return
        root.altTabSource = source
        altTabWriter.command = [root.accelRun, "niri-config", "set-alt-tab", source]
        altTabWriter.running = true
    }
    Process {
        id: altTabReader
        command: [root.accelRun, "niri-config", "get-alt-tab"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.altTabSource = JSON.parse(text).source ?? "" } catch (e) { root.altTabSource = "" }
            }
        }
    }
    Process {
        id: altTabWriter
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (!result.success) root.bindError(result.error ?? "Alt+Tab")
                } catch (e) {}
                root.refreshAltTab()
                root.reload()
            }
        }
    }
    // ── Legacy keybind parser (cheatsheet) ───────────────────────────────
    Process {
        id: keybindParser
        command: [Quickshell.shellPath("scripts/lib/accel-run"), "niri-keybinds"]

        stdout: StdioCollector {
            id: keybindCollector
        }

        onExited: (exitCode, exitStatus) => {
            const output = keybindCollector.text?.trim() ?? ""
            if (exitCode === 0 && output.length > 0) {
                try {
                    const result = JSON.parse(output)
                    if (!result) {
                        console.warn("[NiriKeybinds] Empty result, using defaults")
                        return
                    }
                    if (result.error) {
                        console.warn("[NiriKeybinds] Parser error:", result.error)
                        root.errorMessage = result.error
                    } else if (result.children && result.children.length > 0) {
                        root.keybinds = result
                        root.configPath = result.configPath ?? ""
                        root.loaded = true
                        console.info("[NiriKeybinds] Loaded", result.children.length, "categories from", root.configPath)
                    } else {
                        console.warn("[NiriKeybinds] No keybinds found, using defaults")
                    }
                } catch (e) {
                    console.warn("[NiriKeybinds] JSON parse error, using defaults:", e)
                    root.errorMessage = "Failed to parse keybinds"
                }
            } else if (exitCode !== 0) {
                console.warn("[NiriKeybinds] Parser failed (exit", exitCode + "), using defaults")
                root.errorMessage = "Parser script failed"
            } else {
                console.info("[NiriKeybinds] No output from parser, using defaults")
            }
        }
    }

    // ── Enriched binds loader (inir-accel niri-config get-binds) ─────────────────
    Process {
        id: enrichedBindsLoader
        command: [root.accelRun, "niri-config", "get-binds"]
        running: false

        stdout: StdioCollector {
            id: enrichedCollector
        }

        onExited: (exitCode, exitStatus) => {
            const output = enrichedCollector.text?.trim() ?? ""
            if (exitCode === 0 && output.length > 0) {
                try {
                    const result = JSON.parse(output)
                    if (!result) {
                        console.warn("[NiriKeybinds] get-binds: empty result")
                        return
                    }
                    if (result.error) {
                        console.warn("[NiriKeybinds] get-binds error:", result.error)
                    } else {
                        root.allBinds = result.binds ?? []
                        root.enrichedCategories = result.categories ?? []
                        console.info("[NiriKeybinds] get-binds loaded", root.allBinds.length, "binds")
                    }
                } catch (e) {
                    console.warn("[NiriKeybinds] get-binds JSON parse error:", e)
                }
            } else if (exitCode !== 0) {
                console.warn("[NiriKeybinds] get-binds failed (exit", exitCode + "), or inir-accel is missing")
            }
        }
    }

    // ── setBind process ───────────────────────────────────────────────────
    Process {
        id: setBindProcess
        running: false

        stdout: StdioCollector {
            id: setBindCollector
        }

        onExited: (exitCode, exitStatus) => {
            const output = setBindCollector.text?.trim() ?? ""
            const combo = root._pendingSetCombo
            root._pendingSetCombo = ""
            if (exitCode === 0) {
                try {
                    const result = output.length > 0 ? JSON.parse(output) : {}
                    if (result.success !== false) {
                        console.info("[NiriKeybinds] setBind succeeded:", combo)
                        root.reload()
                        root.bindSaved(combo)
                    } else {
                        const msg = result.error ?? "set-bind returned failure"
                        console.warn("[NiriKeybinds] setBind failed:", combo, msg, result.detail ?? "")
                        root.errorMessage = msg
                        root.bindError(msg)
                    }
                } catch (e) {
                    // Exit 0 but non-JSON output — treat as success
                    console.info("[NiriKeybinds] setBind succeeded (no JSON):", combo)
                    root.reload()
                    root.bindSaved(combo)
                }
            } else {
                const msg = root._failureText(output, "set-bind exited " + exitCode)
                console.warn("[NiriKeybinds] setBind failed:", msg)
                root.errorMessage = msg
                root.bindError(msg)
            }
        }
    }

    // ── removeBind process ────────────────────────────────────────────────
    Process {
        id: removeBindProcess
        running: false

        stdout: StdioCollector {
            id: removeBindCollector
        }

        onExited: (exitCode, exitStatus) => {
            const output = removeBindCollector.text?.trim() ?? ""
            const combo = root._pendingRemoveCombo
            root._pendingRemoveCombo = ""
            if (exitCode === 0) {
                try {
                    const result = output.length > 0 ? JSON.parse(output) : {}
                    if (result.success !== false) {
                        console.info("[NiriKeybinds] removeBind succeeded:", combo)
                        root.reload()
                        root.bindRemoved(combo)
                    } else {
                        const msg = result.error ?? "remove-bind returned failure"
                        console.warn("[NiriKeybinds] removeBind failed:", msg)
                        root.errorMessage = msg
                        root.bindError(msg)
                    }
                } catch (e) {
                    // Exit 0 but non-JSON output — treat as success
                    console.info("[NiriKeybinds] removeBind succeeded (no JSON):", combo)
                    root.reload()
                    root.bindRemoved(combo)
                }
            } else {
                const msg = root._failureText(output, "remove-bind exited " + exitCode)
                console.warn("[NiriKeybinds] removeBind failed:", msg)
                root.errorMessage = msg
                root.bindError(msg)
            }
        }
    }

    // ── File watchers ─────────────────────────────────────────────────────
    FileView {
        id: configWatcher
        path: CompositorService.niriNative ? Quickshell.env("HOME") + "/.config/niri/config.kdl" : ""
        watchChanges: true

        onFileChanged: {
            reloadDebounce.restart()
        }
    }

    FileView {
        id: bindsWatcher
        path: CompositorService.niriNative ? Quickshell.env("HOME") + "/.config/niri/config.d/70-binds.kdl" : ""
        watchChanges: true

        onFileChanged: reloadDebounce.restart()
    }

    Timer {
        id: reloadDebounce
        interval: 300
        repeat: false
        onTriggered: {
            console.info("[NiriKeybinds] Config changed, reloading...")
            root.reload()
        }
    }

    Component.onCompleted: {
        reload()
        refreshAltTab()
    }

    // ── Default keybinds (fallback for cheatsheet) ────────────────────────
    readonly property var defaultKeybinds: [
        {
            name: "System",
            children: [{ keybinds: [
                { mods: ["Super"], key: "Tab", comment: root.umbriel ? "Umbriel Overview" : "Niri Overview" },
                { mods: ["Super", "Shift"], key: "E", comment: root.umbriel ? "Quit Umbriel" : "Quit Niri" },
                { mods: ["Super"], key: "Escape", comment: "Toggle shortcuts inhibit" },
                { mods: ["Super", "Shift"], key: "O", comment: "Power off monitors" }
            ]}]
        },
        {
            name: "iNiR Shell",
            children: [{ keybinds: [
                { mods: ["Super"], key: "Space", comment: "iNiR Overview" },
                { mods: ["Super"], key: "G", comment: "iNiR Overlay" },
                { mods: ["Super"], key: "V", comment: "Clipboard" },
                { mods: ["Super"], key: "Comma", comment: "Settings" },
                { mods: ["Super"], key: "Slash", comment: "Cheatsheet" },
                { mods: ["Super", "Alt"], key: "L", comment: "Lock Screen" },
                { mods: ["Ctrl", "Alt"], key: "T", comment: "Wallpaper Selector" },
                { mods: ["Super", "Shift"], key: "W", comment: "Cycle panel style" },
                { mods: ["Super", "Shift"], key: "Q", comment: "Session dialog" }
            ]}]
        },
        {
            name: "Window Switcher",
            children: [{ keybinds: [
                { mods: ["Alt"], key: "Tab", comment: "Next window" },
                { mods: ["Alt", "Shift"], key: "Tab", comment: "Previous window" }
            ]}]
        },
        {
            name: "Region Tools",
            children: [{ keybinds: [
                { mods: ["Super", "Shift"], key: "S", comment: "Screenshot region" },
                { mods: ["Super", "Shift"], key: "X", comment: "OCR region" },
                { mods: ["Super", "Shift"], key: "A", comment: "Reverse image search" }
            ]}]
        },
        {
            name: "Applications",
            children: [{ keybinds: [
                { mods: ["Super"], key: "T", comment: "Terminal" },
                { mods: ["Super"], key: "Return", comment: "Terminal" },
                { mods: ["Super"], key: "E", comment: "File manager" },
                { mods: ["Super"], key: "W", comment: "Browser" }
            ]}]
        },
        {
            name: "Window Management",
            children: [{ keybinds: [
                { mods: ["Super"], key: "Q", comment: "Close window" },
                { mods: ["Super"], key: "D", comment: "Maximize column" },
                { mods: ["Super"], key: "F", comment: "Fullscreen" },
                { mods: ["Super"], key: "A", comment: "Toggle floating" },
                { mods: ["Super", "Shift"], key: "V", comment: "Switch float/tile focus" },
                { mods: ["Super"], key: "[", comment: "Consume/expel left" },
                { mods: ["Super"], key: "]", comment: "Consume/expel right" }
            ]}]
        },
        {
            name: "Layout",
            children: [{ keybinds: [
                { mods: ["Super"], key: "R", comment: "Cycle column width" },
                { mods: ["Super", "Shift"], key: "R", comment: "Cycle window height" },
                { mods: ["Super", "Ctrl"], key: "R", comment: "Reset window height" },
                { mods: ["Super"], key: "C", comment: "Center column" }
            ]}]
        },
        {
            name: "Resize",
            children: [{ keybinds: [
                { mods: ["Super"], key: "-", comment: "Shrink column 10%" },
                { mods: ["Super"], key: "=", comment: "Grow column 10%" },
                { mods: ["Super", "Shift"], key: "-", comment: "Shrink window 10%" },
                { mods: ["Super", "Shift"], key: "=", comment: "Grow window 10%" }
            ]}]
        },
        {
            name: "Focus",
            children: [{ keybinds: [
                { mods: ["Super"], key: "←/→/↑/↓", comment: "Focus direction" },
                { mods: ["Super"], key: "H/J/K/L", comment: "Focus (vim)" },
                { mods: ["Super"], key: "Home", comment: "Focus first column" },
                { mods: ["Super"], key: "End", comment: "Focus last column" }
            ]}]
        },
        {
            name: "Move Windows",
            children: [{ keybinds: [
                { mods: ["Super", "Shift"], key: "←/→/↑/↓", comment: "Move direction" },
                { mods: ["Super", "Shift"], key: "H/J/K/L", comment: "Move (vim)" },
                { mods: ["Super", "Ctrl"], key: "Home", comment: "Move to first" },
                { mods: ["Super", "Ctrl"], key: "End", comment: "Move to last" }
            ]}]
        },
        {
            name: "Monitors",
            children: [{ keybinds: [
                { mods: ["Super", "Ctrl"], key: "←/→/↑/↓", comment: "Focus monitor" },
                { mods: ["Super", "Ctrl", "Shift"], key: "←/→/↑/↓", comment: "Move to monitor" }
            ]}]
        },
        {
            name: "Workspaces",
            children: [{ keybinds: [
                { mods: ["Super"], key: "1-9", comment: "Focus workspace" },
                { mods: ["Super", "Ctrl"], key: "1-9", comment: "Move to workspace" },
                { mods: ["Super"], key: "PgUp/PgDn", comment: "Workspace up/down" }
            ]}]
        },
        {
            name: "Screenshots",
            children: [{ keybinds: [
                { mods: [], key: "Print", comment: "Screenshot (select)" },
                { mods: ["Ctrl"], key: "Print", comment: "Screenshot screen" },
                { mods: ["Alt"], key: "Print", comment: "Screenshot window" }
            ]}]
        },
        {
            name: "Media",
            children: [{ keybinds: [
                { mods: [], key: "Vol+", comment: "Volume up" },
                { mods: [], key: "Vol-", comment: "Volume down" },
                { mods: [], key: "Mute", comment: "Mute audio" },
                { mods: ["Ctrl", "Super"], key: "Space", comment: "Play/Pause" },
                { mods: ["Super", "Alt"], key: "N", comment: "Next track" },
                { mods: ["Super", "Alt"], key: "P", comment: "Previous track" }
            ]}]
        }
    ]
}
