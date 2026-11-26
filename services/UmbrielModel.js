.pragma library

// Umbriel's IPC (https://docs.noctalia.dev/umbriel/) in the shapes NiriService already serves, so every surface that
// reads windows, workspaces and outputs works on both compositors without knowing which one runs.
//
// Umbriel sends whole snapshots (`subscribe`), not deltas, and names windows and workspaces by strings
// ("df16ed81…", "DP-1:2"). The shell, like Niri, uses numbers: `ids` (owned by NiriService, one per session) gives
// each string a number for as long as it lives, and turns it back when an action names it.

function newIds() {
    return { window: { num: {}, key: {}, next: 1 }, workspace: { num: {}, key: {}, next: 1 }, focusStamp: {}, outputs: {} }
}

function _num(table, key) {
    if (!key) return null
    let n = table.num[key]
    if (n === undefined) {
        n = table.next++
        table.num[key] = n
        table.key[n] = key
    }
    return n
}

// Forget what no snapshot names any more: a closed window's number is never handed out again.
function _prune(table, liveKeys) {
    const live = new Set(liveKeys)
    for (const key in table.num) {
        if (live.has(key)) continue
        delete table.key[table.num[key]]
        delete table.num[key]
    }
}

function windowKey(ids, id) {
    return ids.window.key[id] ?? (typeof id === "string" ? id : null)
}

// Niri's transform names for Umbriel's ("normal", "90", "flipped-90").
function _transform(t) {
    const map = { "normal": "Normal", "90": "_90", "180": "_180", "270": "_270", "flipped": "Flipped",
                  "flipped-90": "Flipped90", "flipped-180": "Flipped180", "flipped-270": "Flipped270" }
    return map[String(t ?? "normal")] ?? "Normal"
}

// outputs event -> Niri's `niri msg -j outputs` map (name -> output).
function outputs(ids, list) {
    const result = {}
    for (const o of (Array.isArray(list) ? list : [])) {
        const modes = Array.isArray(o.modes) ? o.modes : []
        const current = modes.findIndex(m => m.current)
        result[o.name] = {
            name: o.name,
            make: o.make ?? "",
            model: o.model ?? "",
            serial: o.serial || null,
            physical_size: [o.physical_size?.width_mm ?? 0, o.physical_size?.height_mm ?? 0],
            modes: modes.map(m => ({ width: m.width, height: m.height, refresh_rate: m.refresh_mhz, is_preferred: !!m.preferred })),
            current_mode: current >= 0 ? current : null,
            vrr_supported: o.adaptive_sync !== null && o.adaptive_sync !== undefined,
            vrr_enabled: o.adaptive_sync === true,
            // A disabled output has no logical box (Niri reports null too).
            logical: o.enabled ? {
                x: o.position?.x ?? 0, y: o.position?.y ?? 0,
                width: o.logical_size?.width ?? 0, height: o.logical_size?.height ?? 0,
                scale: o.scale ?? 1, transform: _transform(o.transform)
            } : null,
            // Umbriel's own, beyond Niri's shape.
            is_focused: !!o.focused,
            powered: !!o.powered,
            hdr_active: !!o.hdr_active,
            usable_area: o.usable_area ?? null
        }
    }
    ids.outputs = result
    return result
}

// workspaces event -> Niri's workspace list.
function workspaces(ids, list) {
    // A disabled output keeps its workspaces in Umbriel; Niri lists none for it.
    const known = Object.keys(ids.outputs).length > 0
    const entries = (Array.isArray(list) ? list : []).filter(w => !known || ids.outputs[w.output]?.logical)
    _prune(ids.workspace, entries.map(w => w.id))
    return entries.map(w => ({
        id: _num(ids.workspace, w.id),
        idx: w.index,
        name: w.named ? w.name : null,
        output: w.output,
        is_active: !!w.active,
        is_focused: !!w.focused,
        is_urgent: !!w.urgent,
        active_window_id: w.focused_window ? _num(ids.window, w.focused_window) : null,
        // Umbriel's own: the workspace's layout ("scrolling", "dwindle", "master", "stacking") and how many windows.
        layout: w.layout ?? "scrolling",
        window_count: w.window_count ?? 0,
        umbriel_id: w.id
    }))
}

// windows event -> Niri's window list. `now` stamps the window that just took focus (Niri's focus_timestamp).
function windows(ids, list, now) {
    const entries = Array.isArray(list) ? list : []
    _prune(ids.window, entries.map(w => w.id))
    const stamps = {}
    const result = []
    for (const w of entries) {
        const id = _num(ids.window, w.id)
        const out = ids.outputs[w.output]?.logical
        const tiled = w.column >= 0
        if (w.active && !ids.focusStamp[w.id]?.active)
            stamps[w.id] = { at: now, active: true }
        else
            stamps[w.id] = { at: ids.focusStamp[w.id]?.at ?? 0, active: !!w.active }
        const at = stamps[w.id].at
        result.push({
            id: id,
            title: w.title ?? "",
            app_id: w.app_id ?? "",
            pid: w.pid > 0 ? w.pid : null,
            workspace_id: w.workspace ? _num(ids.workspace, w.workspace) : null,
            is_focused: !!w.active,
            is_floating: !!w.floating,
            is_urgent: !!w.urgent,
            focus_timestamp: at > 0 ? { secs: Math.floor(at / 1000), nanos: (at % 1000) * 1e6 } : null,
            layout: {
                pos_in_scrolling_layout: tiled ? [w.column + 1, w.row + 1] : null,
                tile_size: [w.w ?? 0, w.h ?? 0],
                window_size: [w.w ?? 0, w.h ?? 0],
                // Where it is on its output, while it shows there.
                tile_pos_in_workspace_view: w.visible && out ? [(w.x ?? 0) - out.x, (w.y ?? 0) - out.y] : null,
                window_offset_in_tile: [0, 0]
            },
            // Umbriel's own, beyond Niri's shape.
            is_fullscreen: !!w.fullscreen,
            is_maximized: !!w.maximized,
            is_minimized: !!w.minimized,
            is_pinned: !!w.pinned,
            is_visible: !!w.visible,
            scratchpad: w.scratchpad || "",
            tabbed: !!w.tabbed,
            tab_hidden: !!w.tab_hidden,
            output: w.output ?? "",
            umbriel_id: w.id
        })
    }
    ids.focusStamp = stamps
    return result
}

function keyboardLayouts(data) {
    return { names: Array.isArray(data?.names) ? data.names : [], current_idx: Number(data?.current_index ?? 0) }
}

// ---------------------------------------------------------------------------------------------------------------
// Actions: one Niri `{ "Action": { Name: {...} } }` request -> the Umbriel requests that do the same, in order.
// `ctx` answers what the translation needs to know: workspaceRef(niriRef) -> { workspace, output } and
// focusedWindowKey(). An action Umbriel has no equal for gives [] (the caller logs it once).

function _ws(ctx, reference) {
    const r = reference ?? {}
    if (r.Index !== undefined) return { workspace: Number(r.Index) }
    if (r.Name !== undefined) return { workspace: String(r.Name) }
    if (r.Id !== undefined) return ctx.workspaceRef(r.Id)
    return null
}

function _a(action, fields) {
    const request = { cmd: "action", action: action }
    for (const k in (fields ?? {})) {
        if (fields[k] !== undefined && fields[k] !== null && fields[k] !== "") request[k] = fields[k]
    }
    return request
}

// Niri's SizeChange ("+10%", { SetProportion: 50 }, { AdjustProportion: -10 }) as Umbriel extent requests.
function _extent(change, verb) {
    if (typeof change === "string") {
        const m = change.match(/^([+-]?)(\d+(?:\.\d+)?)%$/)
        if (!m) return []
        const value = Number(m[2]) / 100
        return m[1] ? [_a(`window-modify-${verb}-extent`, { delta: m[1] === "-" ? -value : value })]
                    : [_a(`window-set-${verb}-extent`, { fraction: value })]
    }
    if (change?.SetProportion !== undefined) return [_a(`window-set-${verb}-extent`, { fraction: Number(change.SetProportion) / 100 })]
    if (change?.AdjustProportion !== undefined) return [_a(`window-modify-${verb}-extent`, { delta: Number(change.AdjustProportion) / 100 })]
    return []
}

function actionRequests(ids, request, ctx) {
    const body = request?.Action
    if (!body || typeof body !== "object") return []
    const name = Object.keys(body)[0]
    const args = body[name] ?? {}
    const win = id => (id === undefined || id === null) ? undefined : windowKey(ids, id) ?? undefined
    // Umbriel's workspace moves act on the focused window: focus the one asked for first, and give focus back
    // after a silent move.
    const onWindow = (id, requests, restore) => {
        const key = win(id)
        const focused = ctx.focusedWindowKey()
        if (!key || key === focused) return requests
        const before = [_a("window-focus", { window: key })]
        const after = restore && focused ? [_a("window-focus", { window: focused })] : []
        return before.concat(requests, after)
    }
    switch (name) {
    // iNiR's own names for Umbriel's scratchpad, which Niri has no equal for. Focusing a hidden member reveals it.
    case "MoveWindowToScratchpad": return onWindow(args.id, [_a("window-move-to-scratchpad", { scratchpad: args.scratchpad })], false)
    case "RestoreWindowFromScratchpad": return onWindow(args.id, [_a("window-restore-from-scratchpad", { scratchpad: args.scratchpad })], false)
    case "ToggleScratchpad": return [_a("scratchpad-toggle", { scratchpad: args.scratchpad })]
    case "FocusWindow": return [_a("window-focus", { window: win(args.id) })]
    case "CloseWindow": return [_a("window-close", { window: win(args.id) })]
    case "ToggleWindowFloating": return [_a("window-toggle-floating", { window: win(args.id) })]
    case "FullscreenWindow": return onWindow(args.id, [_a("window-toggle-fullscreen")], false)
    case "FocusWorkspace": {
        const ref = _ws(ctx, args.reference)
        return ref ? [_a("workspace-switch", ref)] : []
    }
    case "MoveWindowToWorkspace": {
        const ref = _ws(ctx, args.reference)
        if (!ref) return []
        const focus = args.focus !== false
        return onWindow(args.window_id, [_a(focus ? "window-move-to-workspace" : "window-move-to-workspace-silent", ref)], !focus)
    }
    case "MoveColumnToWorkspace": {
        const ref = _ws(ctx, args.reference)
        return ref ? [_a("column-move-to-workspace", ref)] : []
    }
    case "MoveWindowToMonitor": return args.output ? [_a("workspace-switch", { workspace: 1, output: args.output })] : []
    case "ToggleOverview": return [_a("overview-toggle")]
    case "OpenOverview": return [_a("overview-open")]
    case "CloseOverview": return [_a("overview-close")]
    case "PowerOffMonitors": return [_a("dpms-off")]
    case "PowerOnMonitors": return [_a("dpms-on")]
    case "Quit": return [_a("session-quit", { skip_confirmation: args.skip_confirmation === true ? true : undefined })]
    case "FocusWorkspaceUp": return [_a("workspace-previous")]
    case "FocusWorkspaceDown": return [_a("workspace-next")]
    case "FocusWorkspacePrevious": return [_a("workspace-focus-last")]
    case "FocusColumnLeft": return [_a("window-focus-left")]
    case "FocusColumnRight": return [_a("window-focus-right")]
    case "FocusColumnFirst": return [_a("column-focus-first")]
    case "FocusColumnLast": return [_a("column-focus-last")]
    case "FocusWindowUp": return [_a("window-focus-up")]
    case "FocusWindowDown": return [_a("window-focus-down")]
    case "MoveColumnLeft": return [_a("column-move-left")]
    case "MoveColumnRight": return [_a("column-move-right")]
    case "MoveColumnToFirst": return [_a("column-move-to-first")]
    case "MoveColumnToLast": return [_a("column-move-to-last")]
    case "CenterColumn": return [_a("column-center")]
    case "MaximizeColumn": return [_a("window-toggle-maximize")]
    case "ConsumeWindowIntoColumn": return [_a("window-consume-from-right")]
    case "ExpelWindowFromColumn": return [_a("window-consume-or-expel-right")]
    case "ConsumeOrExpelWindowLeft": return [_a("window-consume-or-expel-left")]
    case "ConsumeOrExpelWindowRight": return [_a("window-consume-or-expel-right")]
    case "SetColumnWidth": return _extent(args.change ?? args, "primary")
    case "SetWindowHeight": return _extent(args.change ?? args, "secondary")
    case "SwitchPresetColumnWidth": return [_a("window-cycle-primary-extent")]
    // Umbriel only steps forward; Rin also steps back and takes an index.
    case "SwitchLayout": {
        const layout = args.layout ?? "Next"
        if (!ctx.rin || layout === "Next") return [_a("keyboard-layout-next")]
        if (layout === "Prev") return [_a("keyboard-layout-prev")]
        return layout?.Index !== undefined ? [_a("switch-layout", { args: String(Number(layout.Index)) })] : []
    }
    case "Spawn": return Array.isArray(args.command) && args.command.length > 0
        ? [_a("spawn", { command: args.command.map(p => /^[\w@%+=:,./-]+$/.test(p) ? p : "'" + String(p).replace(/'/g, "'\\''") + "'").join(" ") })] : []
    }
    return []
}

// ---------------------------------------------------------------------------------------------------------------
// Key bindings: Umbriel's `[keybinds]` tables (iNiR's 70-binds.toml, then the person's 90-user-extra.toml, whose
// keys replace or, set to "", remove ours) in the cheatsheet's shape: categories from the `# Heading` comment above
// each group, `Mod` as Super.

// Niri's, Rin's and Umbriel's actions in the words Niri's cheatsheet uses, so a key reads, and translates, the same
// on every compositor. Umbriel's own come first; `names` in _humanize puts a compositor's own words before these.
const _names = {
    "overview-toggle": "Umbriel overview", "session-quit": "Quit Umbriel", "dpms-off": "Turn screens off",
    "shortcuts-inhibit-toggle": "Toggle shortcuts inhibit", "config-reload": "Reload Umbriel config",
    "window-toggle-maximize": "Maximize window", "window-toggle-fullscreen": "Fullscreen",
    "window-toggle-floating": "Toggle floating", "window-close": "Close window", "column-toggle-tabbed": "Tab the column",
    "window-toggle-pinned": "Pin window on every workspace", "scratchpad-toggle": "Show the scratchpad",
    "window-toggle-scratchpad": "Send window to the scratchpad", "workspace-set-layout toggle": "Next workspace layout",
    "window-focus-switch-floating": "Switch float/tile focus", "window-cycle-primary-extent": "Cycle column width",
    "column-center": "Center column", "window-consume-or-expel-left": "Consume/expel left",
    "window-consume-or-expel-right": "Consume/expel right", "window-focus-left": "Focus left",
    "window-focus-right": "Focus right", "window-focus-up": "Focus up", "window-focus-down": "Focus down",
    "column-focus-first": "Focus first column", "column-focus-last": "Focus last column", "column-move-left": "Move left",
    "column-move-right": "Move right", "window-move-up": "Move up", "window-move-down": "Move down",
    "column-move-to-first": "Move to first", "column-move-to-last": "Move to last", "workspace-next": "Next workspace",
    "workspace-previous": "Previous workspace", "column-move-to-workspace-next": "Move to next workspace",
    "column-move-to-workspace-previous": "Move to previous workspace",
    // Niri's and Rin's spellings.
    "power-off-monitors": "Turn screens off", "toggle-keyboard-shortcuts-inhibit": "Toggle shortcuts inhibit",
    "close-window": "Close window", "maximize-column": "Maximize column", "maximize-window-to-edges": "Maximize to edges",
    "fullscreen-window": "Fullscreen", "toggle-window-floating": "Toggle floating",
    "switch-focus-between-floating-and-tiling": "Switch float/tile focus", "center-column": "Center column",
    "center-visible-columns": "Center visible columns", "expand-column-to-available-width": "Expand to available width",
    "consume-or-expel-window-left": "Consume/expel left", "consume-or-expel-window-right": "Consume/expel right",
    "expel-window-from-column": "Expel from column", "consume-window-into-column": "Consume into column",
    "switch-preset-column-width": "Cycle column width", "switch-preset-window-height": "Cycle window height",
    "reset-window-height": "Reset window height", "toggle-column-tabbed-display": "Toggle tabbed display",
    "focus-column-left": "Focus left", "focus-column-right": "Focus right", "focus-window-up": "Focus up",
    "focus-window-down": "Focus down", "focus-column-first": "Focus first column", "focus-column-last": "Focus last column",
    "move-column-left": "Move left", "move-column-right": "Move right", "move-window-up": "Move up",
    "move-window-down": "Move down", "move-column-to-first": "Move to first", "move-column-to-last": "Move to last",
    "focus-workspace-up": "Previous workspace", "focus-workspace-down": "Next workspace",
    "move-column-to-workspace-up": "Move to previous workspace", "move-column-to-workspace-down": "Move to next workspace",
    "move-workspace-up": "Move workspace up", "move-workspace-down": "Move workspace down",
    "screenshot": "Screenshot", "screenshot-screen": "Screenshot the screen", "screenshot-window": "Screenshot the window",
    "switch-layout next": "Next keyboard layout", "switch-layout prev": "Previous keyboard layout",
    "keyboard-layout-next": "Next keyboard layout", "keyboard-layout-prev": "Previous keyboard layout",
    "keyboard-layout-previous": "Previous keyboard layout"
}
// Written out whole, so each label is a key the translation tools find.
const _monitors = {
    left: ["Focus monitor left", "Move to monitor left"], right: ["Focus monitor right", "Move to monitor right"],
    up: ["Focus monitor up", "Move to monitor up"], down: ["Focus monitor down", "Move to monitor down"]
}
for (const side in _monitors) {
    _names[`focus-monitor-${side}`] = _names[`output-focus-${side}`] = _monitors[side][0]
    _names[`move-column-to-monitor-${side}`] = _names[`column-move-to-output-${side}`] = _monitors[side][1]
}

// An action that takes a workspace number: the words around it.
const _numbered = {
    "focus-workspace": "Focus workspace %1", "workspace-switch": "Focus workspace %1",
    "move-column-to-workspace": "Move to workspace %1", "column-move-to-workspace": "Move to workspace %1",
    "move-window-to-workspace": "Move window to workspace %1", "window-move-to-workspace": "Move window to workspace %1",
    "window-move-to-workspace-silent": "Send window to workspace %1", "switch-layout": "Keyboard layout %1"
}
// A size step, shrink or grow or set: Niri's and Rin's in percent, Umbriel's as a fraction of the output.
const _column = ["Shrink column %1", "Grow column %1", "Column width %1"]
const _window = ["Shrink window %1", "Grow window %1", "Window height %1"]
const _sized = { "set-column-width": _column, "window-modify-primary-extent": _column, "set-window-height": _window,
    "window-modify-secondary-extent": _window }
const _apps = [["Terminal", ["foot", "kitty", "alacritty", "wezterm", "ghostty", "konsole", "gnome-terminal"]],
    ["File manager", ["dolphin", "nautilus", "thunar", "nemo", "pcmanfm", "ranger", "inir-files"]],
    ["Browser", ["firefox", "zen-browser", "chromium", "brave", "vivaldi"]]]

// iNiR's own calls by what they do: Umbriel runs `inir TARGET FUNCTION`, Rin sends `shell TARGET FUNCTION`.
const _shellNames = {
    "overview toggle": "iNiR overview", "overlay toggle": "iNiR overlay", "taskview toggle": "Task view",
    "search toggle": "Search", "clipboard toggle": "Clipboard", "cheatsheet toggle": "Cheatsheet", "settings": "Settings",
    "session toggle": "Power menu", "lock activate": "Lock screen", "lock focus": "Focus the lock screen",
    "region menu": "Region tools", "region screenshot": "Screenshot a region", "region screen": "Screenshot the screen",
    "region window": "Screenshot the window",
    "region ocr": "Read text in a region", "region search": "Search a region by image",
    "region recordWithSound": "Record a region with sound", "region record": "Record a region",
    "wallpaperSelector toggle": "Wallpaper selector",
    "panelFamily cycle": "Next panel style", "equalizer toggle": "Equalizer", "altSwitcher next": "Next window",
    "altSwitcher previous": "Previous window", "closeConfirm trigger": "Close window", "close": "Close window",
    "audio volumeUp": "Volume up", "audio volumeDown": "Volume down", "audio mute": "Mute audio",
    "audio micMute": "Mute microphone", "brightness increment": "Brightness up",
    "brightness decrement": "Brightness down", "mpris playPause": "Play or pause", "mpris next": "Next track",
    "mpris previous": "Previous track", "terminal": "Terminal", "browser": "Browser"
}

// `names` gives the compositor's own words first (Rin's overview-toggle is iNiR's overview, not Umbriel's).
function _humanize(action, names) {
    let text = String(action ?? "").trim()
    const named = (names ?? {})[text] ?? _names[text]
    if (named) return named
    const call = text.match(/^(?:spawn\s+inir|shell)\s+(\S+)(?:\s+(\S+))?/)
    if (call) {
        const pair = call[2] ? `${call[1]} ${call[2]}` : call[1]
        if (_shellNames[pair]) return _shellNames[pair]
        text = pair.replace(/([a-z])([A-Z])/g, "$1 $2")
    } else {
        const [verb, arg = ""] = text.split(/\s+(.*)/)
        if (_numbered[verb] && /^\d+$/.test(arg)) return _numbered[verb].replace("%1", arg)
        const step = _sized[verb] ? arg.match(/^([+-]?)(\d*\.?\d+)(%?)$/) : null
        if (step) {
            // Umbriel's extent is a fraction of the output; Niri's and Rin's bare number is logical pixels.
            const amount = step[3] ? Number(step[2]) + "%"
                : verb.startsWith("window-modify-") ? Math.round(Number(step[2]) * 100) + "%" : Number(step[2]) + " px"
            return _sized[verb][step[1] === "-" ? 0 : step[1] === "+" ? 1 : 2].replace("%1", amount)
        }
        if (verb === "spawn" || verb === "spawn-sh") {
            const app = arg.split(/\s+/)[0].replace(/^.*\//, "")
            const kind = _apps.find(pair => pair[1].includes(app))
            if (kind) return kind[0]
            text = "Run " + arg
            return text
        }
    }
    // A dash between words is a space; one before a number is its sign ("set-column-width -10%").
    text = text.replace(/(\w)-(?=\w)/g, "$1 ").trim().toLowerCase()
    return text.charAt(0).toUpperCase() + text.slice(1)
}

// Every bind the files set, in their order, a later file's line replacing an earlier one ("" removes it): the combo as
// written, the heading over its first line, the action and what else its table says ("repeat=false").
function _bindLines(texts) {
    const order = []
    const byCombo = {}
    for (const text of texts) {
        let inBinds = false
        // A bind written as a table of its own ([keybinds."Mod+U"], its action and options under it), as Settings
        // writes one with options.
        let table = ""
        let heading = "Other"
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim()
            if (/^\[[^\]]+\]$/.test(line)) {
                table = (line.match(/^\[keybinds\."([^"]+)"\]$/) ?? [])[1] ?? ""
                inBinds = line === "[keybinds]"
                if (table.length > 0) {
                    if (!(table in byCombo)) order.push(table)
                    byCombo[table] = { heading: byCombo[table]?.heading ?? heading, action: "", options: "" }
                }
                continue
            }
            if (table.length > 0) {
                const pair = line.match(/^([A-Za-z_-]+)\s*=\s*(.+?)\s*(#.*)?$/)
                if (!pair) continue
                const bind = byCombo[table]
                if (pair[1] === "action") bind.action = ((pair[2].match(/^"((?:[^"\\]|\\.)*)"$/) ?? [])[1] ?? "").replace(/\\"/g, '"')
                else bind.options = [bind.options, pair[1] + "=" + pair[2]].filter(part => part.length > 0).join(" ")
                continue
            }
            if (!inBinds) continue
            // A heading's aside goes when it makes the name long ("Media and hardware keys (work on the lock screen)").
            const head = line.match(/^#\s*([^#].*)$/)
            const named = head ? (head[1].trim().length > 40 ? head[1].replace(/\s*\(.*$/, "") : head[1]).trim() : ""
            if (head && named.length <= 40) { heading = named; continue }
            const m = line.match(/^"([^"]+)"\s*=\s*(.+)$/)
            if (!m) continue
            const value = m[2]
            const action = (value.match(/^"((?:[^"\\]|\\.)*)"/) ?? value.match(/action\s*=\s*"((?:[^"\\]|\\.)*)"/) ?? [])[1]
            if (action === undefined) continue
            const options = value.startsWith("{") ? value.replace(/^\{|\}\s*(#.*)?$/g, "").split(",").map(part => part.trim())
                .filter(part => part.length > 0 && !/^action\s*=/.test(part)).map(part => part.replace(/\s*=\s*/, "=")).join(" ") : ""
            if (!(m[1] in byCombo)) order.push(m[1])
            byCombo[m[1]] = { heading: byCombo[m[1]]?.heading ?? heading, action: action.replace(/\\"/g, '"'), options: options }
        }
    }
    // A bind from a file without headings (Settings' own) goes under the heading its action has elsewhere.
    const binds = order.map(combo => Object.assign({ combo: combo }, byCombo[combo])).filter(bind => bind.action.length > 0)
    for (const bind of binds) {
        if (bind.heading !== "Other") continue
        bind.heading = binds.find(one => one.action === bind.action && one.heading !== "Other")?.heading ?? "Other"
    }
    return binds
}

function bindsFrom(texts, modKey, names) {
    const groups = []
    const index = {}
    for (const bind of _bindLines(texts)) {
        const parts = bind.combo.split("+")
        const key = parts.pop()
        const mods = parts.map(p => p === "Mod" ? (modKey || "Super") : p)
        if (!(bind.heading in index)) {
            index[bind.heading] = groups.length
            groups.push({ name: bind.heading, children: [{ keybinds: [] }] })
        }
        groups[index[bind.heading]].children[0].keybinds.push({ mods: mods, key: key, comment: _humanize(bind.action, names) })
    }
    return groups
}

// The same binds in the shape inir-accel's `niri-config get-binds` gives Niri's, so one editor reads both.
function bindListFrom(texts, names) {
    const binds = []
    const categories = []
    for (const bind of _bindLines(texts)) {
        let category = categories.find(entry => entry.name === bind.heading)
        if (!category) { category = { name: bind.heading, binds: [] }; categories.push(category) }
        category.binds.push(binds.length)
        binds.push({ key_combo: bind.combo, options: bind.options, action: bind.action, action_raw: bind.action,
            category: bind.heading, description: _humanize(bind.action, names), commented: false })
    }
    return { binds: binds, categories: categories }
}
