pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "../UmbrielModel.js" as UmbrielModel
import "../UmbrielToml.js" as Toml

/**
 * Keybinds for Niri compositor with iNiR shell.
 * Dynamically parses user's ~/.config/niri/config.kdl
 * Falls back to defaults if parsing fails.
 *
 * Under Umbriel it reads ~/.config/umbriel/config.d/70-binds.toml, 90-user-extra.toml and Settings'
 * 95-settings.toml instead, in the same shape (UmbrielModel.bindListFrom).
 *
 * Read/write support: setBind() and removeBind() write back to the keybinds KDL file via
 * inir-accel niri-config under Niri, to Settings' own 95-settings.toml under Umbriel (CompositorConfig.bind).
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
        if (root.shippedBinds.length === 0 && !shippedBindsLoader.running) shippedBindsLoader.running = true
    }

    // Settings' own file is CompositorConfig's: its binds are read from the copy it keeps, so one written from the
    // keyboard shows at once (watching the file never saw a first one: it did not exist yet).
    function _settingsText(): string {
        const own = CompositorConfig.own?.keybinds
        return own ? Toml.stringify({ keybinds: own }, "") : ""
    }
    property string _settingsSeen: ""
    Connections {
        target: CompositorConfig
        enabled: root.umbriel
        function onRevisionChanged() {
            if (root._settingsText() !== root._settingsSeen) root._readUmbrielBinds()
        }
    }

    function _readUmbrielBinds(): void {
        root._settingsSeen = root._settingsText()
        const texts = [umbrielBinds.text(), umbrielUserBinds.text(), root._settingsSeen]
        const groups = UmbrielModel.bindsFrom(texts, "Super")
        const list = UmbrielModel.bindListFrom(texts)
        root.allBinds = list.binds
        root.enrichedCategories = list.categories
        root.shippedBinds = UmbrielModel.bindListFrom(texts.slice(0, 2)).binds
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

    // A bind in Umbriel's words: the action alone, or a table with its options ("repeat=false" → repeat = false).
    function _umbrielValue(action: string, options: string): var {
        const pairs = String(options ?? "").trim().split(/\s+/).filter(pair => pair.includes("="))
        if (pairs.length === 0) return action
        const out = { action: action }
        for (const pair of pairs) {
            const [name, raw] = [pair.slice(0, pair.indexOf("=")), pair.slice(pair.indexOf("=") + 1)]
            out[name] = raw === "true" ? true : raw === "false" ? false : /^-?\d+(\.\d+)?$/.test(raw) ? Number(raw) : raw.replace(/^"|"$/g, "")
        }
        return out
    }
    // Is this key set by a file under Settings' own (iNiR's 70 or the person's 90)? Removing it then needs "".
    function _umbrielBelow(keyCombo: string): bool {
        return UmbrielModel.bindListFrom([umbrielBinds.text(), umbrielUserBinds.text()]).binds.some(bind => bind.key_combo === keyCombo)
    }

    // False when a save is already in flight; the result comes back as bindSaved or bindError.
    function setBind(keyCombo: string, action: string, options: string): bool {
        if (root.umbriel) {
            if (!CompositorConfig.bind(keyCombo, root._umbrielValue(action, options))) {
                root.bindError(Translation.tr("Umbriel's files are still being read"))
                return false
            }
            root.bindSaved(keyCombo)
            return true
        }
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

    // The binds iNiR ships, what a key goes back to: Niri's read from `defaults/niri` as a person's config would be,
    // Umbriel's from the files under Settings' own (iNiR's 70 and the person's 90).
    property var shippedBinds: []
    // Several keys changed as one, one write after another (Niri's file takes one at a time): `{ combo, action, options }`
    // gives a key that bind, `{ combo, action: "" }` frees it, `{ combo, shipped: true }` puts back what iNiR's files say.
    // Settings keeps them in its own history; nothing here offers Undo.
    property var _steps: []
    function applyBinds(steps: var): void {
        root._steps = root._steps.concat(steps)
        root._nextStep()
    }
    function _nextStep(): void {
        while (root._steps.length > 0 && !setBindProcess.running && !removeBindProcess.running) {
            const step = root._steps[0]
            root._steps = root._steps.slice(1)
            if (root.umbriel) {
                const value = step.shipped ? undefined
                    : String(step.action ?? "").length > 0 ? root._umbrielValue(step.action, step.options ?? "")
                    : root._umbrielBelow(step.combo) ? "" : undefined
                if (!CompositorConfig.bind(step.combo, value)) root.bindError(Translation.tr("Umbriel's files are still being read"))
                continue
            }
            if (!CompositorService.niriNative) { root._steps = []; return }
            const own = step.shipped ? root.shippedBinds.find(bind => bind.key_combo === step.combo && !bind.commented) : null
            const action = step.shipped ? String(own?.action_raw ?? "") : String(step.action ?? "")
            if (action.length > 0) root.setBind(step.combo, action, step.shipped ? String(own?.options ?? "") : String(step.options ?? ""))
            else root.removeBindQuietly(step.combo)
        }
    }

    function removeBind(keyCombo: string): void {
        if (!CompositorService.niriNative && !root.umbriel) return
        root._removeBind(keyCombo, true)
    }

    // A rename drops the old combo after saving the new one: nothing was removed, so no Undo.
    function removeBindQuietly(keyCombo: string): void {
        if (!CompositorService.niriNative && !root.umbriel) return
        root._removeBind(keyCombo, false)
    }

    function _removeBind(keyCombo: string, offerUndo: bool): void {
        const gone = root.allBinds.find(bind => bind.key_combo === keyCombo)
        if (root.umbriel) {
            if (!CompositorConfig.bind(keyCombo, root._umbrielBelow(keyCombo) ? "" : undefined)) return
            root.bindRemoved(keyCombo)
            if (offerUndo && gone)
                Undo.offer(Translation.tr("Removed %1").arg(keyCombo), () => root.setBind(keyCombo, gone.action_raw, gone.options ?? ""))
            return
        }
        if (removeBindProcess.running) {
            console.warn("[NiriKeybinds] removeBind: process already running, ignoring")
            return
        }
        root._pendingRemoveCombo = keyCombo
        removeBindProcess.command = [root.accelRun, "niri-config", "remove-bind", keyCombo]
        removeBindProcess.running = true
        // get-binds names its fields in snake case: `keyCombo` never matched, and a removed key had no Undo.
        if (offerUndo && gone && String(gone.action_raw ?? "").length > 0)
            Undo.offer(Translation.tr("Removed %1").arg(keyCombo), () => root.setBind(keyCombo, gone.action_raw, gone.options ?? ""))
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

    // niri-config reads `$XDG_CONFIG_HOME/niri`: pointed at the shell's defaults it reads iNiR's binds as shipped.
    Process {
        id: shippedBindsLoader
        command: [root.accelRun, "niri-config", "get-binds"]
        environment: ({ XDG_CONFIG_HOME: Quickshell.shellPath("defaults") })
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.shippedBinds = JSON.parse(text)?.binds ?? [] } catch (e) {}
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
        onRunningChanged: if (!running) Qt.callLater(root._nextStep)

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
        onRunningChanged: if (!running) Qt.callLater(root._nextStep)

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
