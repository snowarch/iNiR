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
    // A fullscreen window stays above the Top layer at rest on both; in the overview both draw Top above it (Niri
    // since 25.05), so a surface there never needs Overlay to be seen. The keyboard differs: Niri gives a Top surface
    // the keys in the overview, Umbriel refuses Top the keys while its output has a fullscreen window, overview or not.
    readonly property bool overviewTopTakesKeys: root.niri

    property int revision: 0
    // A section the compositor's file took a write for: a family mirroring one reads it back.
    signal written(string section)
    property string error: ""
    // The file the error is in, to open it from Settings.
    property string errorFile: ""
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
    // Every file but Settings' own: what a key goes back to when Settings' line for it is dropped.
    property var below: ({})
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
        "layout:center-focused-column": { toml: "layout.scrolling.center_focused", dash: true },
        "layout:always-center-single-column": "layout.scrolling.center_underfull_strip",
        "layout:default-column-display": "layout.tabs.default_display",
        "layout:empty-workspace-above-first": "workspaces.empty_above",
        "layout:border.enabled": { toml: "appearance.border_width", read: value => Number(value) > 0, write: value => value ? 2 : 0 },
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
        // `device`: what the pointer does with no line anywhere (libinput's own default; Umbriel's schema leaves these to it).
        "input:mouse.natural-scroll": { toml: "input.mouse.natural_scroll", device: false },
        "input:mouse.left-handed": { toml: "input.mouse.left_handed", device: false },
        "input:touchpad.tap": "input.touchpad.tap",
        "input:touchpad.natural-scroll": { toml: "input.touchpad.natural_scroll", device: false },
        "input:touchpad.accel-speed": { toml: "input.touchpad.sensitivity", device: 0 },
        "input:touchpad.dwt": { toml: "input.touchpad.disable_while_typing", device: true },
        "input:touchpad.click-method": { toml: "input.touchpad.click_method", dash: true },
        "input:touchpad.disabled-on-external-mouse": { toml: "input.touchpad.disable_on_external_mouse", device: false },
        "input:cursor.xcursor-theme": "input.cursor.theme",
        "input:cursor.xcursor-size": "input.cursor.size",
        "input:cursor.hide-when-typing": "input.cursor.hide_when_typing",
        "input:focus-follows-mouse": "input.focus.follows_mouse",
        "input:warp-mouse-to-focus": "input.cursor.follows_focus",

        "layout:mode": { toml: "layout.mode", only: true },
        "layout:master.position": { toml: "layout.master.position", only: true },
        "layout:master.share": { toml: "layout.master.default_width_fraction", only: true },
        "layout:master.new-is-master": { toml: "layout.master.new_becomes_master", only: true },
        "layout:dwindle.toward-pointer": { toml: "layout.dwindle.new_toward_cursor", only: true },
        "layout:dwindle.keep-split": { toml: "layout.dwindle.preserve_split", only: true },
        "layout:stacking.drop-zones": { toml: "layout.stacking.drop_zones", only: true },
        "layout:maximize": { toml: "layout.client_maximize", only: true },
        "layout:outer-border.width": { toml: "appearance.outer_border_width", only: true },
        "layout:shadow.offset-x": { toml: "appearance.shadow.offset_x", only: true },
        "layout:shadow.offset-y": { toml: "appearance.shadow.offset_y", only: true },
        "layout:drag-opacity": { toml: "appearance.drag_opacity", only: true },
        "tabs:position": { toml: "appearance.tab_bar.position", only: true },
        "tabs:style": { toml: "appearance.tab_bar.style", only: true },
        "tabs:height": { toml: "appearance.tab_bar.height", only: true },
        "tabs:hide-when-single": { toml: "appearance.tab_bar.hide_when_single", only: true },
        "tabs:middle-click-closes": { toml: "layout.tabs.middle_click_closes", only: true },
        "tabs:scroll-switches": { toml: "layout.tabs.scroll_switches_tabs", only: true },
        "tabs:new-tab": { toml: "layout.tabs.new_tab_position", only: true },
        "titlebar:mode": { toml: "appearance.title_bar.mode", only: true },
        "titlebar:height": { toml: "appearance.title_bar.height", only: true },
        "titlebar:buttons-side": { toml: "appearance.title_bar.button_position", only: true },
        "glass:enabled": { toml: "appearance.blur.enabled", only: true },
        "glass:radius": { toml: "appearance.blur.radius", only: true },
        "glass:passes": { toml: "appearance.blur.passes", only: true },
        "glass:noise": { toml: "appearance.blur.noise", only: true },
        "glass:brightness": { toml: "appearance.blur.brightness", only: true },
        "glass:contrast": { toml: "appearance.blur.contrast", only: true },
        "glass:saturation": { toml: "appearance.blur.saturation", only: true },
        "glass:overview": { toml: "overview.background_blur", only: true },
        "animations:duration": { toml: "animation.duration_ms", only: true },
        "effects:border": { toml: "effects.border", only: true, effect: "border" },
        "effects:window": { toml: "effects.window", only: true, effect: "window" },
        "effects:screen": { toml: "effects.screen", only: true, effect: "screen" },
        "effects:cursor": { toml: "effects.cursor", only: true, effect: "cursor" },
        // How windows open, close and move and workspaces change: the compositor's own styles and its effects in one list
        // (`style` holds the built-in way, `needs` what an effect there asks of its table).
        "animations:open": { toml: "animation.windows_in.effect", only: true, effect: "animation", slot: "open", style: "animation.windows_in.style" },
        "animations:close": { toml: "animation.windows_out.effect", only: true, effect: "animation", slot: "close", style: "animation.windows_out.style" },
        "animations:move": { toml: "animation.windows_move.effect", only: true, effect: "animation", slot: "move" },
        "animations:workspaces": { toml: "animation.workspaces.effect", only: true, effect: "animation", slot: "workspaces", needs: { toml: "animation.workspaces.style", value: "reveal" } },
        "corners:top-left": { toml: "hot_corners.top_left", only: true, corner: true },
        "corners:top-right": { toml: "hot_corners.top_right", only: true, corner: true },
        "corners:bottom-left": { toml: "hot_corners.bottom_left", only: true, corner: true },
        "corners:bottom-right": { toml: "hot_corners.bottom_right", only: true, corner: true },
        "corners:delay": { toml: "hot_corners.top_left.delay_ms", only: true },
        "input:middle-click-paste": { toml: "input.middle_click_paste", only: true },
        "input:cursor.hide-after": { toml: "input.cursor.hide_timeout_ms", only: true },
        "input:focus.hover-raises": { toml: "input.focus.hover_raises", only: true },
        "input:focus-on-activate": { toml: "general.focus_on_activate", only: true },
        "overview:wallpaper": { toml: "overview.workspace_wallpaper", only: true }
    })
    // What a hot corner can do, in the shell's words; the value is what the compositor runs.
    readonly property var cornerActions: [
        { label: "Nothing", value: "", glyph: "block" },
        { label: "Overview", value: "overview-toggle", also: ["overview-open"], glyph: "overview_key" },
        { label: "App launcher", value: "spawn inir overview toggle", glyph: "apps" },
        { label: "Search", value: "spawn inir search toggle", glyph: "search" },
        { label: "Clipboard", value: "spawn inir clipboard toggle", glyph: "content_paste" },
        { label: "Screenshot", value: "spawn inir region screenshot", glyph: "screenshot_region" },
        { label: "Power menu", value: "spawn inir session toggle", glyph: "power_settings_new" },
        { label: "Lock", value: "spawn inir lock activate", glyph: "lock" }
    ]

    // A corner the compositor itself acts on (Niri's overview corner, any of Umbriel's hot corners), in the shell's
    // names (topLeft ...): a shell piece aiming at a corner leaves it free.
    function cornerTaken(outputName: string, corner: string): bool {
        if (root.niri) return NiriService.isOverviewHotCornerActive(outputName, corner)
        if (!root.umbriel) return false
        if (!root.asked) Qt.callLater(root.ask)
        root.revision
        const key = ({ topLeft: "top-left", topRight: "top-right", bottomLeft: "bottom-left", bottomRight: "bottom-right" })[corner]
        return key !== undefined && String(root.value({ comp: "corners", key: key, fallback: "" })).length > 0
    }
    // Loaded, it does nothing: a surface reading a capability is not asking. Umbriel's files are read once a corner
    // (cornerTaken) or Settings (ensure) asks; the screens are followed only once Settings has.
    property bool asked: false
    property bool settingsAsked: false
    function ask(): void {
        root.asked = true
        if (root.umbriel && !root.umbrielRead) root.readUmbriel()
    }
    onUmbrielChanged: if (root.asked) root.ask()

    function entryOf(section: string, key: string): var {
        const entry = root.umbrielKeys[section + ":" + key]
        return typeof entry === "string" ? { toml: entry } : entry ?? null
    }
    // Can the compositor in use do this? A row asks before it is shown.
    function has(section: string, key: string): bool {
        if (!root.available) return false
        if (section === "display") return root.displayHas(key, false)
        const entry = root.entryOf(section, key)
        if (root.niri) return !entry?.only
        if (!entry) return false
        root.revision
        if (entry.style) return (root.schemaValues[entry.style] ?? []).length > 0
        if (entry.effect) return root.effectChoices(entry.effect, entry.slot ?? "").length > 0
        return true
    }
    function ensure(): void {
        root.asked = true
        root.settingsAsked = true
        if (!root.available) return
        if (!devices.running) devices.running = true
        if (!cursorReader.running) cursorReader.running = true
        if (root.niri) { root.reload(Object.keys(root.stale).filter(part => root.stale[part])); return }
        if (!schemaReader.running && Object.keys(root.schema).length === 0) {
            schemaReader.running = true
            effectFinder.running = true
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
            if (root.umbriel && root.settingsAsked) outputsSettle.restart()
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
            return entry ? root.readFrom(root.effective, entry, spec) : spec.fallback
        }
        const found = root.lookup(spec.comp, root.readPath(spec))
        return found === undefined ? spec.fallback : found
    }
    // What a row reads with nothing set in Settings: the files below it and Umbriel's own defaults, so a row knows
    // when it left them and Restore puts them back. Unknown under Niri: its defaults are not kept apart from the person's.
    function factory(spec: var): var {
        root.revision
        if (!root.umbriel || !root.umbrielRead || spec.comp === "display") return undefined
        const entry = root.entryOf(spec.comp, spec.key)
        return entry ? root.readFrom(root.below, entry, spec) : undefined
    }
    // One row's value in one of Umbriel's tables, Umbriel's own default under it.
    function readFrom(table: var, entry: var, spec: var): var {
        if (entry.corner) {
            const corner = Toml.get(table, entry.toml.split(".")) ?? {}
            if (corner.enabled !== true) return ""
            const action = String(corner.action ?? "")
            return root.cornerActions.find(known => (known.also ?? []).includes(action))?.value ?? action
        }
        if (entry.style) {
            const effect = String(Toml.get(table, entry.toml.split(".")) ?? root.schema[entry.toml] ?? "")
            return effect.length > 0 ? effect : "style:" + String(Toml.get(table, entry.style.split(".")) ?? root.schema[entry.style] ?? "")
        }
        let found = Toml.get(table, entry.toml.split("."))
        if (found === undefined) found = root.schema[entry.toml]
        if (found === undefined) found = entry.device
        if (found === undefined || found === null) return spec.fallback
        if (entry.read) return entry.read(found)
        return entry.dash && typeof found === "string" ? found.replace(/_/g, "-") : found
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
            const path = entry.toml.split(".")
            let made = root.own
            if (entry.corner) {
                // A corner put back as the files below have it leaves no line of its own.
                const under = Toml.get(root.below, path) ?? {}
                const wantedAction = String(next)
                const same = wantedAction.length === 0 ? under.enabled !== true : under.enabled === true && String(under.action ?? "") === wantedAction
                if (same) made = Toml.set(made, path, undefined)
                else {
                    made = Toml.set(made, path.concat(["enabled"]), wantedAction.length > 0)
                    made = Toml.set(made, path.concat(["action"]), wantedAction.length > 0 ? wantedAction : undefined)
                }
            } else if (entry.effect) {
                // A built-in style clears the effect; an effect leaves the style under it, which it replaces while it runs.
                const wanted = String(next)
                const styled = wanted.startsWith("style:")
                made = root.ownLine(made, entry.toml, styled ? "" : wanted)
                if (styled && entry.style) made = root.ownLine(made, entry.style, wanted.slice(6))
                if (entry.needs) made = root.ownLine(made, entry.needs.toml, wanted.length > 0 ? entry.needs.value : undefined)
                made = root.withEffectFiles(made)
            } else if (spec.key === "delay" && spec.comp === "corners") {
                const delay = Math.round(Number(next))
                for (const corner of ["top_left", "top_right", "bottom_left", "bottom_right"]) {
                    const at = ["hot_corners", corner, "delay_ms"]
                    const under = Toml.get(root.below, at) ?? root.schema[at.join(".")]
                    made = Toml.set(made, at, root.same(under, delay) ? undefined : delay)
                }
            } else {
                let written = entry.write ? entry.write(next) : entry.dash && typeof next === "string" ? next.replace(/-/g, "_") : next
                const kind = root.schemaKinds[entry.toml]
                if (kind === "int") written = Math.round(Number(written))
                else if (kind === "float") written = Number(written)
                // A value outside what the compositor takes would make it refuse the whole file.
                const range = root.schemaLimits[entry.toml]
                if (range && typeof written === "number") written = Math.max(range.min, Math.min(range.max, written))
                // Put back to what the files below (or Umbriel, or the device) give, the line goes: the file keeps only
                // changes. Compared as written and as the row reads it (a click method the device picks reads as the row's).
                const under = Toml.get(root.below, path) ?? root.schema[entry.toml] ?? entry.device
                const plain = root.same(under, written) || root.same(root.readFrom(root.below, entry, spec), next)
                made = Toml.set(made, path, plain ? undefined : written)
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
    function same(a: var, b: var): bool {
        if (typeof a === "number" && typeof b === "number") return Math.abs(a - b) < 1e-6
        return a !== undefined && JSON.stringify(a) === JSON.stringify(b)
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
        return entry ? root.schemaLimits[entry.toml] ?? null : null
    }
    // The effects Umbriel ships, found where it is installed: { kind, name, file }. Offered before they are defined; the
    // one picked is included from Settings' own file (withEffectFiles).
    property var bundledEffects: []
    // What each shipped effect does, in the shell's words. `slots` keeps a motion to the moment it was made for; `feed`
    // marks one that stays dark until a program feeds it, offered only once the person defines it.
    readonly property var effectWords: ({
        pulse: { label: "Pulse", glyph: "favorite", detail: "The border of the window you are in breathes in your colours." },
        audio: { label: "Sound", glyph: "graphic_eq", detail: "The border lights with the lowest notes playing.", feed: true },
        scanlines: { label: "Scanlines", glyph: "tv", detail: "Every window wears the lines of an old screen." },
        vignette: { label: "Vignette", glyph: "vignette", detail: "The edges of the screen fall softly into shade." },
        glow: { label: "Glow", glyph: "flare", detail: "A soft light in your colours follows the pointer." },
        trail: { label: "Trail", glyph: "gesture", detail: "A short violet and gold tail follows the pointer." },
        "trail-path": { label: "Long trail", glyph: "draw", detail: "A two-second tail draws where the pointer went." },
        reveal: { label: "Wipe", glyph: "swipe_right", detail: "Windows wipe in from the left and out to it.", slots: ["open", "close"] },
        squash: { label: "Squash", glyph: "compress", detail: "A moved window squashes a little, then settles.", slots: ["move"] },
        workspace_wipe: { label: "Wipe", glyph: "swipe_left", detail: "The next workspace wipes over the one you leave.", slots: ["workspaces"] }
    })
    readonly property var styleWords: ({
        popin: { label: "Pop", glyph: "open_in_full" },
        zoom: { label: "Zoom", glyph: "zoom_in" },
        slide: { label: "Slide", glyph: "swipe_up" },
        fade: { label: "Fade", glyph: "gradient" },
        none: { label: "None", glyph: "block" }
    })
    function effectChoices(kind: string, slot: string): var {
        const words = name => root.effectWords[name] ?? {}
        const defined = (root.effects.presets ?? []).concat(root.effects.pools ?? []).filter(item => item.kind === kind).map(item => String(item.name))
        const offered = root.bundledEffects.filter(effect => effect.kind === kind && !words(effect.name).feed).map(effect => effect.name)
        return defined.concat(offered).filter((name, at, all) => all.indexOf(name) === at && (!slot || !words(name).slots || words(name).slots.includes(slot)))
            .map(name => ({ label: words(name).label ?? name.replace(/[_-]/g, " ").replace(/^./, c => c.toUpperCase()), value: name,
                glyph: words(name).glyph ?? "auto_awesome", detail: words(name).detail }))
    }
    function choicesFor(spec: var): var {
        root.revision
        const entry = root.entryOf(spec.comp, spec.key)
        if (entry?.effect) {
            const effects = root.effectChoices(entry.effect, entry.slot ?? "")
            if (entry.style) return (root.schemaValues[entry.style] ?? []).map(style => ({ label: root.styleWords[style]?.label ?? style, value: "style:" + style, glyph: root.styleWords[style]?.glyph ?? "animation" })).concat(effects)
            const plain = entry.slot === "workspaces" ? { label: "Slide", glyph: "swipe_up" } : entry.slot === "move" ? { label: "Glide", glyph: "open_with" } : { label: "None", glyph: "block" }
            return [{ label: plain.label, value: "", glyph: plain.glyph }].concat(effects)
        }
        if (entry?.corner) return root.cornerActions
        return []
    }
    // One line of Settings' file, gone when it says what the files below (or Umbriel) already do.
    function ownLine(made: var, at: string, written: var): var {
        const path = at.split(".")
        const under = Toml.get(root.below, path) ?? root.schema[at]
        return Toml.set(made, path, written === undefined || root.same(under, written) ? undefined : written)
    }
    // Settings' file includes the shipped effects it names and no other: one the person's own files already define is
    // theirs (defined twice, Umbriel refuses both), and one nothing names any more goes.
    function withEffectFiles(made: var): var {
        const named = Object.values(root.umbrielKeys).filter(entry => typeof entry === "object" && entry.effect)
            .map(entry => Toml.get(made, entry.toml.split("."))).filter(name => typeof name === "string" && name.length > 0)
        const shipped = root.bundledEffects.map(effect => effect.file)
        const kept = [].concat(made.include?.files ?? []).filter(file => !shipped.includes(file))
        const wanted = root.bundledEffects.filter(effect => named.includes(effect.name) && Toml.get(root.below, ["effects", "preset", effect.name]) === undefined).map(effect => effect.file)
        const files = kept.concat(wanted)
        return Toml.set(made, ["include", "files"], files.length > 0 ? files : undefined)
    }
    Process {
        id: effectFinder
        // Next to the binary first (a Nix store, /usr/local), then the data dirs; the first that has them wins.
        command: ["sh", "-c", 'b=$(command -v umbriel) || exit 0; for d in "$(dirname "$(readlink -f "$b")")/../share" $(printf %s "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr : " "); do e="$d/umbriel/effects"; [ -d "$e" ] || continue; for f in "$e"/*/*/effect.toml; do [ -f "$f" ] && readlink -f "$f"; done; exit 0; done']
        stdout: StdioCollector {
            onStreamFinished: {
                root.bundledEffects = text.split("\n").filter(line => line.endsWith("/effect.toml")).map(file => {
                    const parts = file.split("/")
                    return { kind: parts[parts.length - 3], name: parts[parts.length - 2], file: file }
                })
                root.revision++
            }
        }
    }

    // ---- Umbriel's files ----
    property var schemaKinds: ({})
    property var schemaLimits: ({})
    property var schemaValues: ({})
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
        let seen = []
        // What Settings' file includes (the effects it picked) is Settings' too: never "below" it.
        const whole = (file, skip) => {
            if (seen.includes(file)) return {}
            seen.push(file)
            if (file === skip) return {}
            let made = {}
            for (const inner of root.includesOf(file)) made = Toml.merge(made, whole(inner, skip))
            const mine = Object.assign({}, files[file]?.data ?? {})
            delete mine.include
            return Toml.merge(made, mine)
        }
        root.below = whole(root.umbrielMain, root.umbrielOwn)
        seen = []
        root.effective = whole(root.umbrielMain, "")
        root.linked = seen.includes(root.umbrielOwn)
        root.own = files[root.umbrielOwn]?.data ?? {}
        // A shipped effect the person's own files came to define is theirs now: Settings' include of it goes.
        if (root.bundledEffects.length > 0) {
            const healed = root.withEffectFiles(root.own)
            if (JSON.stringify(healed.include?.files ?? []) !== JSON.stringify(root.own.include?.files ?? [])) root.writeOwn(healed)
        }
        root.umbrielRead = true
        root.forget("")
        root.revision++
        root.syncRange()
    }
    function writeOwn(made: var): void {
        made = root.withRange(made, root.rangeMarked())
        root.own = made
        root.effective = Toml.merge(root.below, made)
        ownFile.setText(Toml.stringify(made, "iNiR Settings writes this file: what you change in Settings lands here and loads last.\nYour own additions go in 90-user-extra.toml; a key set in both follows Settings."))
        root.revision++
        ownSettle.restart()
    }
    readonly property string linkScript: [
        'f="$1"; mkdir -p "$(dirname "$f")/config.d"; [ -f "$f" ] || : > "$f"',
        // Only a listed file counts: the header's comments name both files too.
        `grep -qE '^[^#]*"([^"]*/)?config.d/95-settings.toml"' "$f" && exit 0`,
        `if grep -qE '^[^#]*"config.d/90-user-extra.toml"' "$f"; then`,
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
            root.error = code === 0 ? "" : Translation.tr("config.toml lists its own files: add config.d/95-settings.toml to that list.")
            root.errorFile = code === 0 ? "" : root.umbrielMain
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
                    const defaults = {}, kinds = {}, limits = {}, values = {}
                    // { version, revision, options: [{ path, type, default?, min?, max?, values? }] }
                    const told = JSON.parse(text)
                    for (const option of (Array.isArray(told) ? told : told.options ?? [])) {
                        if (option.default !== undefined && option.default !== null) defaults[option.path] = option.default
                        kinds[option.path] = option.type
                        if (option.min !== undefined && option.max !== undefined) limits[option.path] = { min: option.min, max: option.max }
                        if (Array.isArray(option.values)) values[option.path] = option.values
                    }
                    root.schema = defaults
                    root.schemaKinds = kinds
                    root.schemaLimits = limits
                    root.schemaValues = values
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
            if (!validator.running) validator.running = true
        }
    }
    // Umbriel keeps its last good config when a file is refused: the refusal is said, never silent.
    Process {
        id: validator
        command: ["umbriel", "config", "validate", "-c", root.umbrielMain]
        stdout: StdioCollector { id: validOut }
        stderr: StdioCollector { id: validErr }
        // "warning: FILE:LINE:COL: what" is a setting Umbriel skipped (the rest applies); "error:" a file it could not
        // read at all. The first is said in a person's words, with the file it is in.
        onExited: (code) => {
            const lines = `${validErr.text}\n${validOut.text}`.split("\n").map(line => line.trim()).filter(line => line.length > 0)
            const told = lines.map(line => /^(warning|error): (.+?):(\d+):\d+: (.*)$/.exec(line)).filter(found => found !== null)
            const first = told.find(found => found[1] === "error") ?? told[0]
            root.errorFile = first ? first[2] : code === 0 ? "" : root.umbrielOwn
            if (code === 0) root.error = ""
            else if (!first) root.error = lines[0] ?? ""
            else if (first[1] === "error") root.error = Translation.tr("%1, line %2 can't be read, so the compositor keeps its last good settings.").arg(first[2].split("/").pop()).arg(first[3])
            else root.error = Translation.tr("%1, line %2: %3. Everything else applies.").arg(first[2].split("/").pop()).arg(first[3]).arg(first[4])
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
                    root.syncRange()
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

    // ---- the HDMI range ----
    // The driver sends limited range (16-235) at a TV (CTA-861) mode and full range at a screen's own modes, and
    // neither compositor can set DRM's "Broadcast RGB". A screen that reads every HDMI signal as limited shows its own
    // modes crushed and darker (11-10: an LG at 75 Hz, fine at 60). The person marks it in Settings; Settings' file
    // then squeezes the picture with a screen effect, only while that screen runs a mode the driver sends full.
    readonly property string rangeEffect: "inir-limited-range"
    readonly property string rangeFile: Quickshell.shellPath("defaults/umbriel/effects/inir-limited-range/effect.toml")
    function rangeMarked(): var {
        return [].concat(Config.options?.display?.limitedRange ?? [])
    }
    // The TV modes a screen offers in practice, 1000/1001 rates (59.94) included; anything else goes out full.
    function sendsLimited(mode: string): bool {
        const found = /^(\d+)x(\d+)@([\d.]+)$/.exec(mode)
        if (!found) return false
        const tv = [24, 25, 30, 48, 50, 60, 100, 120]
        const rates = ({ "720x480": [60, 120, 240], "720x576": [50, 100, 200], "1280x720": tv, "1920x1080": tv, "2560x1080": tv,
            "3840x2160": tv, "4096x2160": tv })[`${found[1]}x${found[2]}`] ?? []
        const hz = Number(found[3])
        return rates.some(rate => Math.abs(hz - rate) < 0.005 || Math.abs(hz - rate * 1000 / 1001) < 0.005)
    }
    // Settings' file with the squeeze on each marked HDMI screen whose mode (the file's, else the running one) goes out
    // full, off everywhere else, and the effect's file included only while a screen uses it.
    function withRange(made: var, marked: var): var {
        if (!root.umbriel || root.outputs.length === 0) return made
        let used = false
        for (const out of root.outputs) {
            const path = ["output", out.configName, "screen_effect"]
            const set = String(Toml.get(made, ["output", out.configName, "mode"]) ?? "")
            const mode = set.includes("@") ? set : root.modeOf(out)
            if (marked.includes(out.configName) && String(out.name).startsWith("HDMI") && !root.sendsLimited(mode)) {
                made = Toml.set(made, path, root.rangeEffect)
                used = true
            } else if (Toml.get(made, path) === root.rangeEffect) made = Toml.set(made, path, undefined)
        }
        const files = [].concat(made.include?.files ?? []).filter(file => !String(file).endsWith(`/${root.rangeEffect}/effect.toml`)).concat(used ? [root.rangeFile] : [])
        return Toml.set(made, ["include", "files"], files.length > 0 ? files : undefined)
    }
    // A mode changed outside Settings (or the shell started) puts the squeeze right once both the file and the screens are read.
    function syncRange(): void {
        if (!root.umbrielRead || root.pending) return
        const made = root.withRange(root.own, root.rangeMarked())
        if (JSON.stringify(made) !== JSON.stringify(root.own)) root.writeOwn(made)
    }

    // ---- displays ----
    // `anyScreen` asks what the compositor can do at all, whether or not the chosen screen is on.
    function displayHas(key: string, anyScreen: bool): bool {
        root.revision
        const out = root.output
        if (!out) return false
        // Two screens or more are drawn on their desk, the ones turned off waiting under it.
        if (key === "arrange") return root.outputs.length > 1
        // A screen turned off has only its switch.
        if (!anyScreen && out.enabled === false && key !== "on" && key !== "screen") return false
        if (key === "vrr") return out.vrr_supported === true
        if (["screen", "resolution", "rate", "scale", "transform"].includes(key)) return true
        if (!root.umbriel) return false
        // The last screen on has no switch: nothing would be left to turn it on from.
        if (key === "on") return root.outputs.length > 1 && (out.enabled === false || root.activeOutputs.length > 1)
        if (key === "hdr" || key === "sdr-white") return out.hdr_supported === true
        if (key === "bit-depth") return out.deep_colour === true
        if (key === "limited-range") return String(out.name).startsWith("HDMI")
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
        if (key === "limited-range") return root.rangeMarked().includes(out.configName)
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
        if (key === "limited-range") {
            if (!root.umbriel || !root.umbrielRead) return
            const marked = root.rangeMarked().filter(name => name !== out.configName).concat(next === true || next === "true" ? [out.configName] : [])
            Config.setNestedValue("display.limitedRange", marked)
            root.writeOwn(root.withRange(root.own, marked))
            return
        }
        if (root.umbriel) {
            const names = ({ on: "enabled", vrr: "vrr", hdr: "hdr", "sdr-white": "sdr_white", "bit-depth": "bit_depth", main: "focus_at_startup", "workspace-axis": "workspace_axis" })
            const path = ["output", out.configName, names[setting] ?? setting]
            // A value as the row says it, in the file's own words.
            const inFile = value => {
                if (setting === "scale" || setting === "sdr-white") return Number(value)
                if (setting === "bit-depth") return Math.round(Number(value))
                if (["on", "tearing", "main"].includes(setting)) return value === true || value === "true"
                if (setting === "vrr") return ({ on: "always", "on-demand": "fullscreen" })[value] ?? "disabled"
                return value
            }
            const written = inFile(wanted)
            // The last screen is never turned off: nothing would be left to turn it on from.
            if (setting === "on" && written === false && root.activeOutputs.length < 2) return
            const before = Toml.get(root.own, path)
            let made = Toml.set(root.own, path, written)
            // One main screen: choosing it takes the mark from the others.
            if (setting === "main" && written === true) for (const other of root.outputs) if (other.name !== out.name) made = Toml.set(made, ["output", other.configName, "focus_at_startup"], undefined)
            // The shell's one-screen panels (the wallpaper gallery and its kin) open on the same main screen.
            if (setting === "main") Config.setNestedValue("display.primaryMonitor", written === true ? out.name : "")
            // What can leave a person without a picture waits for Keep; the rest is simply set.
            if (["mode", "scale", "transform", "on", "hdr", "bit-depth"].includes(setting)) {
                root.pending = { output: out.name, key: setting, value: wanted, previous: previous, path: path, before: before, back: inFile(previous) }
                root.secondsLeft = root.revertAfter
                countdown.restart()
            }
            // The row shows the new value now; the compositor's own answer replaces it when it comes.
            const shown = ({ vrr: { vrr_mode: wanted }, tearing: { tearing: written }, main: { main: written }, "sdr-white": { sdr_white: written },
                "workspace-axis": { workspace_axis: wanted }, hdr: { hdr_mode: wanted }, "bit-depth": { bit_depth: written }, scale: { scale: written }, transform: { transform: wanted } })[setting]
            if (shown) root.outputs = root.outputs.map(entry => entry.name === out.name ? Object.assign({}, entry, shown) : entry)
            root.writeOwn(made)
            if (!root.pending) root.tidyLater(path)
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
        const near = (at, marks) => {
            let pick = at, gap = catchAt
            for (const mark of marks) if (Math.abs(mark - at) <= gap) { pick = mark; gap = Math.abs(mark - at) }
            return pick
        }
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
    // A screen's line that says what the files below or Umbriel already say leaves once the screen took it (Umbriel
    // keeps a screen as it is when its line goes, so the line is needed only until then).
    function tidyLater(path: var): void {
        const under = Toml.get(root.below, path) ?? root.schema[["output", "<name>", path[2]].join(".")]
        if (under === undefined || !root.same(under, Toml.get(root.own, path))) return
        tidyDisplay.path = path
        tidyDisplay.restart()
    }
    function keepDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        root.pending = null
        if (root.umbriel) { root.tidyLater(change.path); return }
        persister.command = [root.accelRun, "niri-config", "persist-output", change.output, `${change.key}=${change.value}`]
        persister.running = true
    }
    function revertDisplay(): void {
        const change = root.pending
        if (!change) return
        countdown.stop()
        root.pending = null
        if (root.umbriel) {
            // Umbriel keeps a screen as it is when its line goes: the old value is written so the screen returns, and
            // a line that was not there before leaves once the screen is back.
            root.rereadFiles = true
            root.writeOwn(Toml.set(root.own, change.path, change.back))
            if (change.before === undefined) { tidyDisplay.path = change.path; tidyDisplay.restart() }
            else if (!root.same(change.before, change.back)) root.writeOwn(Toml.set(root.own, change.path, change.before))
            return
        }
        applier.command = [root.accelRun, "niri-config", "apply-output", change.output, `${change.key}=${change.previous}`]
        applier.running = true
    }

    Timer {
        id: tidyDisplay
        property var path: []
        interval: 1500
        onTriggered: if (Toml.get(root.own, tidyDisplay.path) !== undefined) root.writeOwn(Toml.set(root.own, tidyDisplay.path, undefined))
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
