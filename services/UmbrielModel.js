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
    case "SwitchLayout": return [_a("keyboard-layout-next")]
    case "Spawn": return Array.isArray(args.command) && args.command.length > 0
        ? [_a("spawn", { command: args.command.map(p => /^[\w@%+=:,./-]+$/.test(p) ? p : "'" + String(p).replace(/'/g, "'\\''") + "'").join(" ") })] : []
    }
    return []
}

// ---------------------------------------------------------------------------------------------------------------
// Key bindings: Umbriel's `[keybinds]` tables (iNiR's 70-binds.toml, then the person's 90-user-extra.toml, whose
// keys replace or, set to "", remove ours) in the cheatsheet's shape: categories from the `# Heading` comment above
// each group, `Mod` as Super.

const _names = {
    "overview-toggle": "Umbriel overview", "session-quit": "Quit Umbriel", "dpms-off": "Turn screens off",
    "shortcuts-inhibit-toggle": "Toggle shortcuts inhibit", "config-reload": "Reload Umbriel config",
    "window-toggle-maximize": "Maximize window", "window-toggle-fullscreen": "Fullscreen window",
    "window-toggle-floating": "Float window", "window-close": "Close window", "column-toggle-tabbed": "Tab the column",
    "window-toggle-pinned": "Pin window on every workspace", "scratchpad-toggle": "Show the scratchpad",
    "window-toggle-scratchpad": "Send window to the scratchpad", "workspace-set-layout toggle": "Next workspace layout"
}

function _humanize(action) {
    let text = String(action ?? "").trim()
    if (_names[text]) return _names[text]
    const inir = text.match(/^spawn\s+inir\s+(\S+)(?:\s+(\S+))?/)
    if (inir) text = `${inir[1]} ${inir[2] ?? ""}`.replace(/([a-z])([A-Z])/g, "$1 $2")
    else if (text.startsWith("spawn ")) text = "Run " + text.slice(6)
    text = text.replace(/-/g, " ").trim().toLowerCase()
    return text.charAt(0).toUpperCase() + text.slice(1)
}

function bindsFrom(texts, modKey) {
    const order = []
    const byCombo = {}
    for (const text of texts) {
        let inBinds = false
        let heading = "Other"
        for (const raw of String(text ?? "").split("\n")) {
            const line = raw.trim()
            if (/^\[[^\]]+\]$/.test(line)) { inBinds = line === "[keybinds]"; continue }
            if (!inBinds) continue
            const head = line.match(/^#\s*([^#].*)$/)
            if (head && head[1].length <= 40) { heading = head[1].trim(); continue }
            const m = line.match(/^"([^"]+)"\s*=\s*(.+)$/)
            if (!m) continue
            const value = m[2]
            const action = (value.match(/^"((?:[^"\\]|\\.)*)"/) ?? value.match(/action\s*=\s*"((?:[^"\\]|\\.)*)"/) ?? [])[1]
            if (action === undefined) continue
            if (!(m[1] in byCombo)) order.push(m[1])
            byCombo[m[1]] = { heading: byCombo[m[1]]?.heading ?? heading, action: action.replace(/\\"/g, '"') }
        }
    }
    const groups = []
    const index = {}
    for (const combo of order) {
        const bind = byCombo[combo]
        if (!bind.action) continue
        const parts = combo.split("+")
        const key = parts.pop()
        const mods = parts.map(p => p === "Mod" ? (modKey || "Super") : p)
        if (!(bind.heading in index)) {
            index[bind.heading] = groups.length
            groups.push({ name: bind.heading, children: [{ keybinds: [] }] })
        }
        groups[index[bind.heading]].children[0].keybinds.push({ mods: mods, key: key, comment: _humanize(bind.action) })
    }
    return groups
}
