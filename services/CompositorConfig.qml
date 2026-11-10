pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "UmbrielToml.js" as Toml

// What the running compositor can be told, by function, and the one place that tells it. Every family's Settings
// draws from here: a row carries a section and a key of this vocabulary (`comp`, `key`), never a compositor's file
// or option name. has() says whether the compositor in use can do it; what it cannot is not shown.
//   Niri     its own config through inir-accel niri-config (it reloads the file itself).
//   Umbriel  one file Settings owns, config.d/95-settings.toml, included last; Umbriel applies it on save.
Singleton {
    id: root

    readonly property string accelRun: Quickshell.shellPath("scripts/lib/accel-run")
    readonly property bool niri: CompositorService.niriNative
    readonly property bool umbriel: CompositorService.isUmbriel
    readonly property bool available: root.niri || root.umbriel
    readonly property string compositorName: root.niri ? "Niri" : root.umbriel ? "Umbriel" : ""

    property int revision: 0
    // A section the compositor's file took a write for: a family mirroring one reads it back.
    signal written(string section)
    property string error: ""
    property var outputs: []
    property var cursorThemes: []
    property bool hasTouchpad: false
    property bool hasTrackpoint: false
    property string selectedOutput: ""
    readonly property var output: root.outputs.find(entry => entry.name === root.selectedOutput) ?? root.outputs.find(entry => entry.enabled !== false) ?? root.outputs[0] ?? null
    readonly property var activeOutputs: root.outputs.filter(entry => entry.enabled !== false)

    // A display change waits for Keep; unanswered it goes back.
    property var pending: null
    property int secondsLeft: 0
    readonly property int revertAfter: 15

    // ---- Niri: sections as its config has them ----
    property var data: ({ input: {}, layout: {}, animations: {}, "window-rules": {} })
    property var local: ({})
    property var queue: []
    property var stale: ({ input: true, layout: true, animations: true, "window-rules": true, outputs: true })

    // ---- Umbriel: every included file merged as Umbriel merges them, and the file Settings owns ----
    readonly property string umbrielDir: `${Directories.configPath}/umbriel`
    readonly property string umbrielMain: `${root.umbrielDir}/config.toml`
    readonly property string umbrielOwn: `${root.umbrielDir}/config.d/95-settings.toml`
    property var effective: ({})
    property var own: ({})
    property var schema: ({})
    property var effects: ({ presets: [], pools: [] })
    property bool umbrielRead: false
    // False when the person's config.toml does not include Settings' file: link() adds the line, on their click.
    property bool linked: true
    property var files: ({})
    property var wanted: []

    // The shared vocabulary under Umbriel. A string is the option's path; `dash` trades Niri's a-b for a_b; `only`
    // marks what Niri has no equal for. Colours are not here: the theme writes Umbriel's.
    readonly property var umbrielKeys: ({
        "layout:gaps": "layout.gap",
        "layout:center-focused-column": { path: "layout.scrolling.center_focused", dash: true },
        "layout:always-center-single-column": "layout.scrolling.center_underfull_strip",
        "layout:default-column-display": "layout.tabs.default_display",
        "layout:empty-workspace-above-first": "workspaces.empty_above",
        "layout:border.enabled": { path: "appearance.border_width", read: value => Number(value) > 0, write: value => value ? 2 : 0 },
        "layout:border.width": "appearance.border_width",
        "layout:shadow.enabled": "appearance.shadow.enabled",
        "layout:shadow.softness": "appearance.shadow.softness",
        "layout:overview.zoom": "overview.zoom",
        "window-rules:corner-radius": "appearance.corner_radius",
        "animations:enabled": "animation.enabled",
        "input:workspace-auto-back-and-forth": "workspaces.back_and_forth",
        "input:keyboard.layout": "input.keyboard.layout",
        "input:keyboard.variant": "input.keyboard.variant",
        "input:keyboard.options": "input.keyboard.options",
        "input:keyboard.track-layout": "input.keyboard.track_layout",
        "input:keyboard.repeat-delay": "input.keyboard.repeat_delay",
        "input:keyboard.repeat-rate": "input.keyboard.repeat_rate",
        "input:keyboard.numlock": "input.keyboard.numlock_toggle",
        "input:mod-key": "general.mod_key",
        "input:mouse.accel-speed": "input.mouse.sensitivity",
        "input:mouse.accel-profile": "input.mouse.accel_profile",
        "input:mouse.natural-scroll": "input.mouse.natural_scroll",
        "input:mouse.left-handed": "input.mouse.left_handed",
        "input:touchpad.tap": "input.touchpad.tap",
        "input:touchpad.natural-scroll": "input.touchpad.natural_scroll",
        "input:touchpad.accel-speed": "input.touchpad.sensitivity",
        "input:touchpad.dwt": "input.touchpad.disable_while_typing",
        "input:touchpad.click-method": { path: "input.touchpad.click_method", dash: true },
        "input:touchpad.disabled-on-external-mouse": "input.touchpad.disable_on_external_mouse",
        "input:cursor.xcursor-theme": "input.cursor.theme",
        "input:cursor.xcursor-size": "input.cursor.size",
        "input:cursor.hide-when-typing": "input.cursor.hide_when_typing",
        "input:focus-follows-mouse": "input.focus.follows_mouse",
        "input:warp-mouse-to-focus": "input.cursor.follows_focus",

        "layout:mode": { path: "layout.mode", only: true },
        "layout:master.position": { path: "layout.master.position", only: true },
        "layout:master.share": { path: "layout.master.default_width_fraction", only: true },
        "layout:master.new-is-master": { path: "layout.master.new_becomes_master", only: true },
        "layout:dwindle.toward-pointer": { path: "layout.dwindle.new_toward_cursor", only: true },
        "layout:dwindle.keep-split": { path: "layout.dwindle.preserve_split", only: true },
        "layout:stacking.drop-zones": { path: "layout.stacking.drop_zones", only: true },
        "layout:maximize": { path: "layout.client_maximize", only: true },
        "layout:outer-border.width": { path: "appearance.outer_border_width", only: true },
        "layout:shadow.offset-x": { path: "appearance.shadow.offset_x", only: true },
        "layout:shadow.offset-y": { path: "appearance.shadow.offset_y", only: true },
        "layout:drag-opacity": { path: "appearance.drag_opacity", only: true },
        "tabs:position": { path: "appearance.tab_bar.position", only: true },
        "tabs:style": { path: "appearance.tab_bar.style", only: true },
        "tabs:height": { path: "appearance.tab_bar.height", only: true },
        "tabs:hide-when-single": { path: "appearance.tab_bar.hide_when_single", only: true },
        "tabs:middle-click-closes": { path: "layout.tabs.middle_click_closes", only: true },
        "tabs:scroll-switches": { path: "layout.tabs.scroll_switches_tabs", only: true },
        "tabs:new-tab": { path: "layout.tabs.new_tab_position", only: true },
        "titlebar:mode": { path: "appearance.title_bar.mode", only: true },
        "titlebar:height": { path: "appearance.title_bar.height", only: true },
        "titlebar:buttons-side": { path: "appearance.title_bar.button_position", only: true },
        "glass:enabled": { path: "appearance.blur.enabled", only: true },
        "glass:radius": { path: "appearance.blur.radius", only: true },
        "glass:passes": { path: "appearance.blur.passes", only: true },
        "glass:noise": { path: "appearance.blur.noise", only: true },
        "glass:brightness": { path: "appearance.blur.brightness", only: true },
        "glass:contrast": { path: "appearance.blur.contrast", only: true },
        "glass:saturation": { path: "appearance.blur.saturation", only: true },
        "glass:overview": { path: "overview.background_blur", only: true },
        "animations:duration": { path: "animation.duration_ms", only: true },
        "effects:border": { path: "effects.border", only: true, effect: "border" },
        "effects:window": { path: "effects.window", only: true, effect: "window" },
        "effects:screen": { path: "effects.screen", only: true, effect: "screen" },
        "effects:cursor": { path: "effects.cursor", only: true, effect: "cursor" },
        "corners:top-left": { path: "hot_corners.top_left", only: true, corner: true },
        "corners:top-right": { path: "hot_corners.top_right", only: true, corner: true },
        "corners:bottom-left": { path: "hot_corners.bottom_left", only: true, corner: true },
        "corners:bottom-right": { path: "hot_corners.bottom_right", only: true, corner: true },
        "corners:delay": { path: "hot_corners.top_left.delay_ms", only: true },
        "input:middle-click-paste": { path: "input.middle_click_paste", only: true },
        "input:cursor.hide-after": { path: "input.cursor.hide_timeout_ms", only: true },
        "input:focus.hover-raises": { path: "input.focus.hover_raises", only: true },
        "input:focus-on-activate": { path: "general.focus_on_activate", only: true },
        "overview:wallpaper": { path: "overview.workspace_wallpaper", only: true }
    })
    // What a hot corner can do, in the shell's words; the value is what the compositor runs.
    readonly property var cornerActions: [
        { label: "Nothing", value: "" },
        { label: "Overview", value: "overview-toggle" },
        { label: "App launcher", value: "spawn inir overview toggle" },
        { label: "Clipboard", value: "spawn inir clipboard toggle" },
        { label: "Lock", value: "spawn inir lock activate" }
    ]

    function entryOf(section: string, key: string): var {
        const entry = root.umbrielKeys[section + ":" + key]
        return typeof entry === "string" ? { path: entry } : entry ?? null
    }
    // Can the compositor in use do this? A row asks before it is shown.
    function has(section: string, key: string): bool {
        if (!root.available) return false
        if (section === "display") return root.displayHas(key)
        const entry = root.entryOf(section, key)
        if (root.niri) return !entry?.only
        if (!entry) return false
        root.revision
        if (entry.effect) return root.effectChoices(entry.effect).length > 1
        return true
    }
    function ensure(): void {
        if (!root.available) return
        if (!devices.running) devices.running = true
        if (!cursorReader.running) cursorReader.running = true
        if (root.niri) { root.reload(Object.keys(root.stale).filter(part => root.stale[part])); return }
        if (!schemaReader.running && Object.keys(root.schema).length === 0) {
            schemaReader.running = true
            Quickshell.execDetached(["mkdir", "-p", `${root.umbrielDir}/config.d`])
        }
        root.readUmbriel()
        root.reload(["outputs"])
    }
    Connections {
        target: NiriService
        function onConfigLoadFinished(ok: bool): void {
            if (!ok) return
            for (const part of ["input", "layout", "animations", "window-rules", "outputs"]) root.stale[part] = true
        }
        function onOutputsChanged(): void {
            root.stale.outputs = true
            if (root.umbriel && root.umbrielRead) outputsSettle.restart()
        }
    }
    function reload(parts: var): void {
        for (const part of parts) {
            if (root.umbriel) {
                if (part === "outputs" && !umbrielState.running) umbrielState.running = true
                else if (part !== "outputs") root.readUmbriel()
                continue
            }
            const reader = ({ input: inputReader, layout: layoutReader, animations: animationsReader, "window-rules": rulesReader, outputs: outputsReader })[part]
            if (reader && !reader.running) { reader.running = true; if (part in root.stale) root.stale[part] = false }
        }
    }

    // ---- values ----
    function readPath(spec: var): string {
        return String(spec.read ?? String(spec.key).replace(/-/g, "_"))
    }
    function lookup(section: string, path: string): var {
        let at = root.data[section] ?? {}
        for (const part of path.split(".")) {
            if (at === undefined || at === null) return undefined
            at = at[part]
        }
        return at
    }
    function value(spec: var): var {
        root.revision
        if (spec.comp === "display") return root.displayValue(spec.key)
        const id = spec.comp + ":" + spec.key
        if (id in root.local) return root.local[id]
        if (root.umbriel) {
            const entry = root.entryOf(spec.comp, spec.key)
            if (!entry) return spec.fallback
            if (entry.corner) {
                const corner = Toml.get(root.effective, entry.path.split(".")) ?? {}
                return corner.enabled === true ? String(corner.action ?? "") : ""
            }
            let found = Toml.get(root.effective, entry.path.split("."))
            if (found === undefined) found = root.schema[entry.path]
            if (found === undefined || found === null) return spec.fallback
            if (entry.read) return entry.read(found)
            return entry.dash && typeof found === "string" ? found.replace(/_/g, "-") : found
        }
        const found = root.lookup(spec.comp, root.readPath(spec))
        return found === undefined ? spec.fallback : found
    }
    function set(spec: var, next: var): void {
        if (spec.comp === "display") { root.applyDisplay(spec.key, next); return }
        const local = Object.assign({}, root.local)
        local[spec.comp + ":" + spec.key] = next
        root.local = local
        root.revision++
        if (root.umbriel) {
            const entry = root.entryOf(spec.comp, spec.key)
            if (!entry) return
            const path = entry.path.split(".")
            let made = root.own
            if (entry.corner) {
                made = Toml.set(made, path.concat(["enabled"]), String(next).length > 0)
                if (String(next).length > 0) made = Toml.set(made, path.concat(["action"]), String(next))
            } else if (spec.key === "delay" && spec.comp === "corners") {
                for (const corner of ["top_left", "top_right", "bottom_left", "bottom_right"]) made = Toml.set(made, ["hot_corners", corner, "delay_ms"], Math.round(Number(next)))
            } else {
                let written = entry.write ? entry.write(next) : entry.dash && typeof next === "string" ? next.replace(/-/g, "_") : next
                const kind = root.schemaKinds[entry.path]
                if (kind === "int") written = Math.round(Number(written))
                else if (kind === "float") written = Number(written)
                // A value outside what the compositor takes would make it refuse the whole file.
                const range = root.schemaLimits[entry.path]
                if (range && typeof written === "number") written = Math.max(range.min, Math.min(range.max, written))
                made = Toml.set(made, path, written)
            }
            root.writeOwn(made)
            // The layout of the workspace in front follows at once; the file decides the ones opened after.
            if (spec.comp === "layout" && spec.key === "mode") Quickshell.execDetached(["umbriel", "msg", "workspace-set-layout", String(next)])
            return
        }
        const written = spec.write ? spec.write(next) : typeof next === "boolean" ? (next ? "on" : "off") : String(next)
        root.queue = root.queue.filter(item => !(item.section === spec.comp && item.key === spec.key)).concat([{ section: spec.comp, key: spec.key, value: written }])
        root.next()
    }
    function next(): void {
        if (writer.running || root.queue.length === 0) return
        const item = root.queue[0]
        root.queue = root.queue.slice(1)
        writer.section = item.section
        writer.command = [root.accelRun, "niri-config", "set", item.section, item.key, item.value]
        writer.running = true
    }
    function parse(text: string, onValue: var): bool {
        try {
            const parsed = JSON.parse(text)
            if (parsed && parsed.error) { root.error = String(parsed.error); return false }
            onValue(parsed)
            root.revision++
            return true
        } catch (e) {
            root.error = String(e)
            return false
        }
    }
    function store(section: string, value: var): void {
        const next = Object.assign({}, root.data)
        next[section] = value ?? {}
        root.data = next
        root.forget(section + ":")
    }
    function forget(prefix: string): void {
        const local = {}
        for (const id of Object.keys(root.local)) if (prefix.length > 0 && !id.startsWith(prefix)) local[id] = root.local[id]
        root.local = local
    }
    // The limits the compositor itself gives a range, when it says them.
    function limits(spec: var): var {
        const entry = root.umbriel ? root.entryOf(spec.comp, spec.key) : null
        return entry ? root.schemaLimits[entry.path] ?? null : null
    }
    function effectChoices(kind: string): var {
        return [{ label: "None", value: "" }].concat((root.effects.presets ?? []).filter(preset => preset.kind === kind)
            .map(preset => ({ label: String(preset.name).replace(/[_-]/g, " ").replace(/^./, c => c.toUpperCase()), value: preset.name })))
    }
    function choicesFor(spec: var): var {
        root.revision
        const entry = root.entryOf(spec.comp, spec.key)
        if (entry?.effect) return root.effectChoices(entry.effect)
        if (entry?.corner) return root.cornerActions
        return []
    }

    // ---- Umbriel's files ----
    property var schemaKinds: ({})
    property var schemaLimits: ({})
    function pathFrom(file: string, holder: string): string {
        if (file.startsWith("~/")) return Directories.homePath + file.slice(1)
        if (file.startsWith("/")) return file
        return holder.replace(/\/[^\/]*$/, "") + "/" + file
    }
    function includesOf(file: string): var {
        const parsed = root.files[file]?.data ?? {}
        const list = [].concat(parsed.include?.files ?? [], parsed.include?.optional?.files ?? [])
        return list.filter(entry => typeof entry === "string").map(entry => root.pathFrom(entry, file))
    }
    function readUmbriel(): void {
        if (!root.umbriel || fileReader.running) return
        root.files = {}
        root.wanted = [root.umbrielMain, root.umbrielOwn]
        fileReader.command = root.catCommand(root.wanted)
        fileReader.running = true
    }
    function catCommand(list: var): var {
        return ["sh", "-c", 'for f in "$@"; do printf "\\n#@@inir-file %s\\n" "$f"; cat -- "$f" 2>/dev/null; done', "sh"].concat(list)
    }
    function takeFiles(text: string): void {
        const files = Object.assign({}, root.files)
        for (const chunk of text.split("\n#@@inir-file ").slice(1)) {
            const cut = chunk.indexOf("\n")
            const name = chunk.slice(0, cut < 0 ? chunk.length : cut)
            let parsed = {}
            try { parsed = Toml.parse(cut < 0 ? "" : chunk.slice(cut + 1)) } catch (e) { root.error = `${name}: ${e}` }
            files[name] = { data: parsed }
        }
        root.files = files
        const more = []
        for (const name of Object.keys(files)) for (const inner of root.includesOf(name)) if (!(inner in files) && !more.includes(inner)) more.push(inner)
        if (more.length > 0 && Object.keys(files).length < 64) {
            fileReader.command = root.catCommand(more)
            fileReader.running = true
            return
        }
        const seen = []
        const whole = file => {
            if (seen.includes(file)) return {}
            seen.push(file)
            let made = {}
            for (const inner of root.includesOf(file)) made = Toml.merge(made, whole(inner))
            const mine = Object.assign({}, files[file]?.data ?? {})
            delete mine.include
            return Toml.merge(made, mine)
        }
        root.effective = whole(root.umbrielMain)
        root.linked = seen.includes(root.umbrielOwn)
        root.own = files[root.umbrielOwn]?.data ?? {}
        root.umbrielRead = true
        root.forget("")
        root.revision++
    }
    function writeOwn(made: var): void {
        root.own = made
        root.effective = Toml.merge(root.effective, made)
        ownFile.setText(Toml.stringify(made, "iNiR Settings writes this file: what you change in Settings lands here and loads last.\nYour own additions go in 90-user-extra.toml; a key set in both follows Settings."))
        root.revision++
        ownSettle.restart()
    }
    readonly property string linkScript: [
        'f="$1"; mkdir -p "$(dirname "$f")/config.d"; [ -f "$f" ] || : > "$f"',
        'grep -q "95-settings.toml" "$f" && exit 0',
        'if grep -q "config.d/90-user-extra.toml" "$f"; then',
        "  sed -i 's|^\\( *\\)\"config.d/90-user-extra.toml\",\\{0,1\\}|\\1\"config.d/90-user-extra.toml\",\\n\\1\"config.d/95-settings.toml\",|' \"$f\"",
        'elif ! grep -q "^\\[include" "$f"; then',
        '  printf "\\n# What iNiR Settings changes\\n[include.optional]\\nfiles = [\\"config.d/95-settings.toml\\"]\\n" >> "$f"',
        'else exit 3; fi'
    ].join("\n")
    // Adds Settings' file to the person's config.toml, the one line it needs. Asked for by a click, never done alone.
    function link(): void {
        if (root.linked || !root.umbriel) return
        linker.command = ["sh", "-c", root.linkScript, "sh", root.umbrielMain]
        linker.running = true
    }
    FileView { id: ownFile; path: root.umbrielOwn; printErrors: false; watchChanges: false }
    Process {
        id: linker
        onExited: (code) => {
            root.error = code === 0 ? "" : "config.toml has its own include list: add config.d/95-settings.toml to it"
            root.readUmbriel()
        }
    }
    Process {
        id: fileReader
        stdout: StdioCollector { onStreamFinished: root.takeFiles(text) }
    }
    Process {
        id: schemaReader
        command: ["umbriel", "config", "schema", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const defaults = {}, kinds = {}, limits = {}
                    for (const option of JSON.parse(text)) {
                        if (option.default !== undefined && option.default !== null) defaults[option.path] = option.default
                        kinds[option.path] = option.type
                        if (option.min !== undefined && option.max !== undefined) limits[option.path] = { min: option.min, max: option.max }
                    }
                    root.schema = defaults
                    root.schemaKinds = kinds
                    root.schemaLimits = limits
                    root.revision++
                } catch (e) { root.error = String(e) }
            }
        }
    }
    // Umbriel applies a saved file by itself; the screens are read back once it has.
    property bool rereadFiles: false
    Timer {
        id: ownSettle
        interval: 450
        onTriggered: {
            if (root.rereadFiles) { root.rereadFiles = false; root.readUmbriel() }
            root.reload(["outputs"])
        }
    }
    Timer { id: outputsSettle; interval: 250; onTriggered: root.reload(["outputs"]) }
    Process {
        id: umbrielState
        command: ["sh", "-c", 'umbriel outputs --json; printf "\\n@@\\n"; umbriel color --json; printf "\\n@@\\n"; umbriel tearing --json; printf "\\n@@\\n"; umbriel effects --json']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split("\n@@\n").map(part => JSON.parse(part))
                    const colour = parts[1]?.outputs ?? [], tearing = parts[2]?.outputs ?? []
                    root.effects = parts[3] ?? { presets: [], pools: [] }
                    root.outputs = (Array.isArray(parts[0]) ? parts[0] : []).filter(out => !root.hostOutput(out))
                        .map(out => root.fromUmbriel(out, colour.find(entry => entry.name === out.name), tearing.find(entry => entry.name === out.name)))
                    root.stale.outputs = false
                    root.revision++
                } catch (e) { root.error = String(e) }
            }
        }
    }
    // A nested session's host window is not a screen a person owns.
    function hostOutput(out: var): bool {
        return out.enabled === false && Number(out.modes?.[0]?.refresh_mhz ?? 1) === 0
    }
    // Umbriel's output in the shape every face reads (inir-accel's for Niri), with what only Umbriel says added.
    function fromUmbriel(out: var, colour: var, tearing: var): var {
        const modes = out.modes ?? []
        const current = modes.find(mode => mode.current) ?? modes.find(mode => mode.preferred) ?? modes[0] ?? { width: 0, height: 0, refresh_mhz: 0 }
        const rateText = mhz => (Number(mhz) / 1000).toFixed(3)
        const resolutions = []
        for (const mode of modes) {
            let res = resolutions.find(entry => entry.width === mode.width && entry.height === mode.height)
            if (!res) resolutions.push(res = { width: mode.width, height: mode.height, rates: [], preferred: false })
            if (!res.rates.some(rate => rate.rate_string === rateText(mode.refresh_mhz)))
                res.rates.push({ rate: mode.refresh_mhz / 1000, rate_string: rateText(mode.refresh_mhz), preferred: mode.preferred === true })
            if (mode.preferred) res.preferred = true
        }
        const config = root.outputConfig(out)
        return {
            name: out.name, make: out.make ?? "", model: out.model ?? "", serial: out.serial ?? "", description: out.description ?? "",
            configName: out.config_name || out.name,
            enabled: out.enabled !== false, powered: out.powered !== false,
            physical_size: [Number(out.physical_size?.width_mm ?? 0), Number(out.physical_size?.height_mm ?? 0)],
            current_resolution: `${current.width}x${current.height}`, current_rate: current.refresh_mhz / 1000, current_rate_string: rateText(current.refresh_mhz),
            scale: Number(out.scale ?? 1), transform: String(out.transform ?? "normal"), position: { x: Number(out.position?.x ?? 0), y: Number(out.position?.y ?? 0) },
            vrr_supported: out.adaptive_sync !== null && out.adaptive_sync !== undefined, vrr_enabled: out.adaptive_sync === true,
            vrr_mode: ({ always: "on", fullscreen: "on-demand" })[String(config.vrr ?? "disabled")] ?? "off",
            resolutions: resolutions,
            hdr_supported: (colour?.supported_transfer_functions ?? []).length > 0, hdr_mode: String(colour?.hdr_mode ?? config.hdr ?? "off"), hdr_active: out.hdr_active === true,
            sdr_white: Number(colour?.sdr_white ?? 203), bit_depth: Number(colour?.bit_depth ?? 8), deep_colour: (colour?.supported_transfer_functions ?? []).length > 0 || Number(colour?.bit_depth ?? 8) > 8,
            tearing: config.tearing === true || tearing?.requested === true, main: config.focus_at_startup === true,
            scanout: out.direct_scanout?.active === true, workspace_axis: String(config.workspace_axis ?? "vertical")
        }
    }
    function outputConfig(out: var): var {
        const all = root.effective.output ?? {}
        return Object.assign({}, all[out.name] ?? {}, all[out.config_name ?? out.configName ?? ""] ?? {})
    }

    // ---- displays ----
    function displayHas(key: string): bool {
        root.revision
        const out = root.output
        if (!out) return false
        if (key === "arrange") return root.activeOutputs.length > 1
        if (key === "vrr") return out.vrr_supported === true
        if (["screen", "resolution", "rate", "scale", "transform"].includes(key)) return true
        if (!root.umbriel) return false
        if (key === "on") return root.outputs.length > 1
        if (key === "hdr" || key === "sdr-white") return out.hdr_supported === true
        if (key === "bit-depth") return out.deep_colour === true
        return ["tearing", "main", "workspace-axis"].includes(key)
    }
    function modeOf(output: var): string {
        return output ? `${output.current_resolution}@${output.current_rate_string}` : ""
    }
    // The compositor says "60.000" and "74.973"; people read "60 Hz" and "74.97 Hz". Two decimals at most, never
    // rounded to a whole number the screen does not run at.
    function rateLabel(rate: var): string {
        const hz = Number(rate)
        return hz > 0 ? `${Math.round(hz * 100) / 100} Hz` : ""
    }
    function resolutionLabel(output: var): string {
        return String(output?.current_resolution ?? "").replace("x", " × ")
    }
    // The name on the box: "LG Electronics" sells as LG. The connector stands in when the EDID names nothing.
    function screenName(output: var): string {
        const make = String(output?.make ?? "").replace(/\s+(Electronics|Electronic|Electric Company|Display|Displays|Technology|Corporation|Corp\.?|Co\.?,? Ltd\.?|Inc\.?)$/i, "").trim()
        return `${make} ${String(output?.model ?? "").trim()}`.trim() || String(output?.name ?? "")
    }
    // The diagonal from the EDID's millimetres; 0 when the screen does not say (projectors, some TVs, nested outputs).
    function inchesOf(output: var): real {
        const size = output?.physical_size ?? [0, 0]
        const mm = Math.hypot(Number(size?.[0] ?? 0), Number(size?.[1] ?? 0))
        return mm > 0 ? mm / 25.4 : 0
    }
    // Width over height as the screen shows it now, rotation included.
    function aspectOf(output: var): real {
        const rect = root.logicalRect(output)
        return rect.width > 0 && rect.height > 0 ? rect.width / rect.height : 16 / 9
    }
    // "Flipped90" and "flipped-90" are one turn: one spelling, the config's.
    function transformOf(out: var): string {
        return String(out?.transform ?? "Normal").toLowerCase().replace(/^flipped(\d)/, "flipped-$1")
    }
    function displayValue(key: string): var {
        const out = root.output
        if (key === "screen") return out?.name ?? ""
        if (!out) return ""
        if (key === "resolution") return out.current_resolution
        if (key === "rate") return out.current_rate_string
        if (key === "scale") return Number(out.scale)
        if (key === "transform") return root.transformOf(out)
        if (key === "vrr") return root.umbriel ? String(out.vrr_mode ?? "off") : out.vrr_enabled ? String(out.vrr_mode ?? "on") : "off"
        if (key === "place") return root.placeOf(out, root.neighbour(out))
        if (key === "on") return out.enabled !== false
        if (key === "hdr") return String(out.hdr_mode ?? "off")
        if (key === "sdr-white") return Number(out.sdr_white ?? 203)
        if (key === "bit-depth") return Number(out.bit_depth ?? 8)
        if (key === "tearing") return out.tearing === true
        if (key === "main") return out.main === true
        if (key === "workspace-axis") return String(out.workspace_axis ?? "vertical")
        return ""
    }
    // Where a screen sits, read against the first other screen: the side it touches, in logical pixels.
    function neighbour(out: var): var {
        return root.activeOutputs.find(entry => entry.name !== out?.name) ?? null
    }
    function logicalRect(out: var): var {
        const size = String(out?.current_resolution ?? "0x0").split("x").map(Number)
        const turned = ["90", "270", "flipped-90", "flipped-270"].includes(root.transformOf(out))
        const scale = Number(out?.scale ?? 1) || 1
        return { x: Number(out?.position?.x ?? 0), y: Number(out?.position?.y ?? 0),
            width: Math.round((turned ? size[1] : size[0]) / scale), height: Math.round((turned ? size[0] : size[1]) / scale) }
    }
    function placeOf(out: var, other: var): string {
        if (!out || !other) return ""
        const a = root.logicalRect(out), b = root.logicalRect(other)
        if (a.x >= b.x + b.width) return "right"
        if (a.x + a.width <= b.x) return "left"
        if (a.y >= b.y + b.height) return "below"
        return "above"
    }
    function displayChoices(key: string): var {
        root.revision
        const out = root.output
        if (key === "screen") return root.outputs.map(entry => ({ label: `${entry.make ?? ""} ${entry.model ?? ""}`.trim() || entry.name, value: entry.name }))
        if (!out) return []
        if (key === "resolution") return (out.resolutions ?? []).map(entry => ({ label: `${entry.width} × ${entry.height}`, value: `${entry.width}x${entry.height}` }))
        if (key === "rate") {
            const res = (out.resolutions ?? []).find(entry => `${entry.width}x${entry.height}` === out.current_resolution)
            return (res?.rates ?? []).slice().sort((a, b) => b.rate - a.rate).map(entry => ({ label: root.rateLabel(entry.rate), value: entry.rate_string }))
        }
        if (key === "scale") {
            const base = [1, 1.25, 1.5, 1.75, 2]
            if (!base.includes(Number(out.scale))) base.push(Number(out.scale))
            return base.sort((a, b) => a - b).map(scale => ({ label: `${Math.round(scale * 100)} %`, value: scale }))
        }
        if (key === "transform") {
            const turns = [{ label: "Normal", value: "normal" }, { label: "90°", value: "90" }, { label: "180°", value: "180" }, { label: "270°", value: "270" }]
            // A mirrored screen names its own turn instead of reading Custom.
            const current = root.transformOf(out)
            if (current.startsWith("flipped")) turns.push({ label: "Mirrored" + (current === "flipped" ? "" : " " + current.slice(8) + "°"), value: current })
            return turns
        }
        if (key === "vrr") return [{ label: "Off", value: "off" }, { label: "In games", value: "on-demand" }, { label: "Always", value: "on" }]
        if (key === "place") return [{ label: "Left", value: "left", glyph: "west" }, { label: "Right", value: "right", glyph: "east" }, { label: "Above", value: "above", glyph: "north" }, { label: "Below", value: "below", glyph: "south" }]
        if (key === "hdr") return [{ label: "Off", value: "off" }, { label: "When asked", value: "auto" }, { label: "Fullscreen", value: "fullscreen" }, { label: "Always", value: "on" }]
        if (key === "bit-depth") return [{ label: "8 bit", value: 8 }, { label: "10 bit", value: 10 }]
        if (key === "workspace-axis") return [{ label: "Stacked", value: "vertical", glyph: "swap_vert" }, { label: "Side by side", value: "horizontal", glyph: "swap_horiz" }]
        return []
    }
    function applyDisplay(key: string, next: var): void {
        if (key === "screen") { root.selectedOutput = String(next); root.revision++; return }
        if (key === "place") { root.place(String(next)); return }
        const out = root.output
        if (!out || root.pending) return
        let setting = key
        let wanted = String(next)
        let previous = ""
        if (key === "resolution") {
            const res = (out.resolutions ?? []).find(entry => `${entry.width}x${entry.height}` === wanted)
            const best = (res?.rates ?? []).slice().sort((a, b) => (b.preferred - a.preferred) || (b.rate - a.rate))[0]
            if (!best) return
            setting = "mode"
            wanted = `${wanted}@${best.rate_string}`
            previous = root.modeOf(out)
        } else if (key === "rate") {
            setting = "mode"
            wanted = `${out.current_resolution}@${wanted}`
            previous = root.modeOf(out)
        } else previous = String(root.displayValue(key))
        if (wanted === previous) return
        if (root.umbriel) {
            const names = ({ on: "enabled", vrr: "vrr", hdr: "hdr", "sdr-white": "sdr_white", "bit-depth": "bit_depth", main: "focus_at_startup", "workspace-axis": "workspace_axis" })
            const path = ["output", out.configName, names[setting] ?? setting]
            let written = wanted
            if (setting === "scale" || setting === "sdr-white") written = Number(wanted)
            else if (setting === "bit-depth") written = Math.round(Number(wanted))
            else if (["on", "tearing", "main"].includes(setting)) written = next === true || wanted === "true"
            else if (setting === "vrr") written = ({ on: "always", "on-demand": "fullscreen" })[wanted] ?? "disabled"
            // The last screen is never turned off: nothing would be left to turn it on from.
            if (setting === "on" && written === false && root.activeOutputs.length < 2) return
            const before = Toml.get(root.own, path)
            let made = Toml.set(root.own, path, written)
            // One main screen: choosing it takes the mark from the others.
            if (setting === "main" && written === true) for (const other of root.outputs) if (other.name !== out.name) made = Toml.set(made, ["output", other.configName, "focus_at_startup"], undefined)
            // What can leave a person without a picture waits for Keep; the rest is simply set.
            if (["mode", "scale", "transform", "on", "hdr", "bit-depth"].includes(setting)) {
                root.pending = { output: out.name, key: setting, value: wanted, previous: previous, path: path, before: before }
                root.secondsLeft = root.revertAfter
                countdown.restart()
            }
            // The row shows the new value now; the compositor's own answer replaces it when it comes.
            const shown = ({ vrr: { vrr_mode: wanted }, tearing: { tearing: written }, main: { main: written }, "sdr-white": { sdr_white: written },
                "workspace-axis": { workspace_axis: wanted }, hdr: { hdr_mode: wanted }, "bit-depth": { bit_depth: written }, scale: { scale: written }, transform: { transform: wanted } })[setting]
            if (shown) root.outputs = root.outputs.map(entry => entry.name === out.name ? Object.assign({}, entry, shown) : entry)
            root.writeOwn(made)
            return
        }
        root.pending = { output: out.name, key: setting, value: wanted, previous: previous }
        root.secondsLeft = root.revertAfter
        applier.command = [root.accelRun, "niri-config", "apply-output", out.name, `${setting}=${wanted}`]
        applier.running = true
        countdown.restart()
    }
    // Moves the chosen screen to one side of the other, edges aligned, and saves every position at once.
    function place(side: string): void {
        const out = root.output, other = root.neighbour(out)
        if (!out || !other || side === root.placeOf(out, other)) return
        const a = root.logicalRect(out), b = root.logicalRect(other)
        const at = side === "right" ? { x: b.x + b.width, y: b.y } : side === "left" ? { x: b.x - a.width, y: b.y }
            : side === "below" ? { x: b.x, y: b.y + b.height } : { x: b.x, y: b.y - a.height }
        const layout = {}
        for (const entry of root.activeOutputs) {
            const rect = root.logicalRect(entry)
            layout[entry.name] = entry.name === out.name ? at : { x: rect.x, y: rect.y }
        }
        root.arrange(layout)
    }
    // Where a dragged screen comes to rest: against the nearest edge of another, never over one, corners and centres
    // caught when close. `rects` are logical { name, x, y, width, height }; returns every screen's place, the
    // top-left one at 0,0, ready for arrange().
    function settle(rects: var, name: string, x: real, y: real): var {
        const moved = rects.find(rect => rect.name === name)
        const others = rects.filter(rect => rect.name !== name)
        if (!moved) return {}
        let best = null
        const catchAt = Math.max(moved.width, moved.height) * 0.12
        const near = (at, marks) => marks.reduce((pick, mark) => Math.abs(mark - at) < Math.abs(pick - at) && Math.abs(mark - at) <= catchAt ? mark : pick, at)
        const clamp = (at, low, high) => Math.max(low, Math.min(high, at))
        for (const other of others) {
            const alongY = near(clamp(y, other.y - moved.height + 1, other.y + other.height - 1), [other.y, other.y + other.height - moved.height, other.y + (other.height - moved.height) / 2])
            const alongX = near(clamp(x, other.x - moved.width + 1, other.x + other.width - 1), [other.x, other.x + other.width - moved.width, other.x + (other.width - moved.width) / 2])
            const tries = [{ x: other.x + other.width, y: alongY }, { x: other.x - moved.width, y: alongY }, { x: alongX, y: other.y + other.height }, { x: alongX, y: other.y - moved.height }]
            for (const at of tries) {
                const over = others.some(rect => at.x < rect.x + rect.width && at.x + moved.width > rect.x && at.y < rect.y + rect.height && at.y + moved.height > rect.y)
                const far = Math.hypot(at.x - x, at.y - y)
                if (!over && (!best || far < best.far)) best = { x: Math.round(at.x), y: Math.round(at.y), far: far }
            }
        }
        const placed = rects.map(rect => rect.name === name && best ? Object.assign({}, rect, { x: best.x, y: best.y }) : rect)
        const left = Math.min(...placed.map(rect => rect.x)), top = Math.min(...placed.map(rect => rect.y))
        const layout = {}
        for (const rect of placed) layout[rect.name] = { x: rect.x - left, y: rect.y - top }
        return layout
    }
    // Saves where every screen sits ({ name: { x, y } }, logical pixels). Both compositors apply it by themselves.
    function arrange(layout: var): void {
        if (Object.keys(layout).length === 0) return
        root.outputs = root.outputs.map(out => layout[out.name] ? Object.assign({}, out, { position: layout[out.name] }) : out)
        root.revision++
        if (root.umbriel) {
            let made = root.own
            for (const out of root.outputs) if (layout[out.name]) made = Toml.set(made, ["output", out.configName, "position"], [Math.round(layout[out.name].x), Math.round(layout[out.name].y)])
            root.writeOwn(made)
            return
        }
        if (layoutWriter.running) return
        layoutWriter.command = [root.accelRun, "niri-config", "persist-layout", JSON.stringify(layout)]
        layoutWriter.running = true
    }
    function keepDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        root.pending = null
        if (root.umbriel) return
        persister.command = [root.accelRun, "niri-config", "persist-output", change.output, `${change.key}=${change.value}`]
        persister.running = true
    }
    function revertDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        root.pending = null
        if (root.umbriel) { root.rereadFiles = true; root.writeOwn(Toml.set(root.own, change.path, change.before)); return }
        applier.command = [root.accelRun, "niri-config", "apply-output", change.output, `${change.key}=${change.previous}`]
        applier.running = true
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--
            if (root.secondsLeft <= 0) root.revertDisplay()
        }
    }

    component Reader: Process {
        id: reader
        required property string section
        command: [root.accelRun, "niri-config", "get-" + reader.section]
        stdout: StdioCollector {
            // A read that failed is read again on the next open.
            onStreamFinished: if (!root.parse(text, value => root.store(reader.section, value))) root.stale[reader.section] = true
        }
    }
    Reader { id: inputReader; section: "input" }
    Reader { id: layoutReader; section: "layout" }
    Reader { id: animationsReader; section: "animations" }
    Reader { id: rulesReader; section: "window-rules" }
    Process {
        id: layoutWriter
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.error = JSON.parse(text)?.error ? String(JSON.parse(text).error) : "" } catch (e) {}
            }
        }
        onExited: layoutSettle.restart()
    }
    // Niri reloads its config on its own; read the outputs back once it has.
    Timer { id: layoutSettle; interval: 600; onTriggered: root.reload(["outputs"]) }
    Process {
        id: outputsReader
        command: [root.accelRun, "niri-config", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: if (!root.parse(text, value => { root.outputs = Array.isArray(value) ? value : [] })) root.stale.outputs = true
        }
    }
    Process {
        id: cursorReader
        command: [root.accelRun, "niri-config", "list-cursor-themes"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text, value => { root.cursorThemes = Array.isArray(value) ? value : [] })
        }
    }
    Process {
        id: devices
        command: ["grep", "-i", "^N: Name=", "/proc/bus/input/devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.toLowerCase()
                root.hasTouchpad = names.includes("touchpad")
                root.hasTrackpoint = names.includes("trackpoint")
            }
        }
    }
    Process {
        id: writer
        property string section: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.error = parsed?.error ? String(parsed.error) : ""
                } catch (e) {}
            }
        }
        onExited: {
            root.written(writer.section)
            if (root.queue.every(item => item.section !== writer.section)) root.reload([writer.section])
            root.next()
        }
    }
    Process {
        id: applier
        onExited: root.reload(["outputs"])
    }
    Process {
        id: persister
        onExited: root.reload(["outputs"])
    }
}
