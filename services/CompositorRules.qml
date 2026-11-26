pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import "UmbrielToml.js" as Toml

// Each app's own rule, the one owner of it: how its windows open (tiled, floating, maximized, fullscreen), where (a
// workspace, a screen), how wide, how see-through, and whether screenshots and recordings leave them out. One shape
// for both compositors, written where each reads it last:
//   Umbriel  [[window_rule]] entries in Settings' own config.d/95-settings.toml (CompositorConfig.writeOwn).
//   Niri     window-rule blocks inside one marked block of the person's 90-user-extra.kdl, checked by `niri validate`
//            on a copy of their config before it lands, so a bad line never reaches the running compositor.
//   Rin      [[window-rule]] tables in Niri's words, in Settings' own rules.d/90-settings.toml; Rin rereads the
//            folder on each write and keeps its rules when a file does not parse.
// Only the rules Settings wrote are read back; iNiR's own and the person's hand-written ones stay where they are.
// CompositorConfig holds it (`CompositorConfig.appRules`): the one place that tells the compositor anything.
// A rule: { app, title, open: ""|tiled|floating|maximized|fullscreen, workspace: ""|position|name, screen, opacity,
// hidden, width: 0|fraction, extra: Umbriel keys Settings does not draw, kept as they were }.
Scope {
    id: root

    required property var config

    readonly property bool niri: CompositorService.niriNative
    readonly property bool umbriel: CompositorService.isUmbriel
    readonly property bool rin: CompositorService.isRin
    // Umbriel's and Rin's files are replaced whole on a write: never before they were read.
    readonly property bool ready: root.niri ? niriMain.loaded : root.umbriel ? root.config.umbrielRead : root.rin && root.rinRead
    readonly property var rules: root.umbriel ? Array.from(root.config.own?.window_rule ?? []).map(root.fromUmbriel).filter(rule => rule.app.length > 0)
        : root.niri ? root.niriRules : root.rin ? root.rinRules : []
    property var niriRules: []
    property string error: ""
    // Niri's config.kdl could not be read (Niri started with another -c): nothing is written, Settings says so.
    property bool unread: false
    // What "On workspace" offers: Niri opens only on a named workspace; Umbriel takes a position or a name too; Rin
    // a position on its screen.
    readonly property var workspaceNames: root.rin ? [] : Array.from(NiriService.allWorkspaces ?? []).map(ws => String(ws?.name ?? "")).filter((name, at, all) => name.length > 0 && all.indexOf(name) === at)
    readonly property int positions: root.umbriel || root.rin ? Math.max(5, ...Object.values(Array.from(NiriService.allWorkspaces ?? [])
        .reduce((count, ws) => { count[ws.output] = (count[ws.output] ?? 0) + 1; return count }, ({})))) : 0

    function has(key: string): bool {
        if (key === "workspace") return root.positions > 0 || root.workspaceNames.length > 0
        if (key === "screen") return root.config.outputs.length > 1
        return root.niri || root.umbriel || root.rin
    }

    // Replaces Settings' rules with these, at once on screen; the compositor's file follows.
    function set(list: var): void {
        if (!root.ready) return
        const clean = Array.from(list ?? []).filter(rule => String(rule?.app ?? "").length > 0)
        root.error = ""
        if (root.umbriel) {
            root.config.writeOwn(Toml.set(root.config.own, ["window_rule"], clean.length > 0 ? clean.map(root.toUmbriel) : undefined))
            return
        }
        if (root.rin) {
            root.rinRules = clean
            root.writeRin()
            return
        }
        root.niriRules = clean
        root.niriWant = root.withBlock(root.niriText(), root.blockOf(clean))
        if (!niriWriter.running) root.writeNiri()
    }
    function rule(app: string): var {
        return root.rules.find(entry => entry.app === app) ?? null
    }
    // One app's rule changed (null removes it); a new app's rule goes last, so it wins over the ones before.
    function put(app: string, next: var): void {
        const list = root.rules.filter(entry => entry.app !== app)
        const at = root.rules.findIndex(entry => entry.app === app)
        if (next) list.splice(at < 0 ? list.length : at, 0, next)
        root.set(list)
    }

    // ── Regex: an app id matched whole, a title by what it holds.
    function regexOf(text: string): string { return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&") }
    function plainOf(text: string): string { return String(text).replace(/\\(.)/g, "$1") }
    function appOf(pattern: var): string {
        const text = String(Array.isArray(pattern) ? (pattern[0] ?? "") : (pattern ?? ""))
        return root.plainOf(text.replace(/^\^/, "").replace(/\$$/, ""))
    }

    // ── Umbriel
    readonly property var umbrielDrawn: ["match", "default_floating", "default_maximize", "default_fullscreen", "default_workspace", "default_output", "opacity", "block_capture", "default_scrolling_extent", "default_floating_size"]
    function fromUmbriel(entry: var): var {
        const extra = {}
        for (const key of Object.keys(entry ?? {})) if (!root.umbrielDrawn.includes(key)) extra[key] = entry[key]
        const match = entry?.match ?? {}
        for (const key of Object.keys(match)) if (key !== "app_id" && key !== "title") extra.match = Object.assign(extra.match ?? {}, { [key]: match[key] })
        const floatSize = entry?.default_floating_size ?? {}
        return {
            app: root.appOf(match.app_id),
            title: match.title === undefined ? "" : root.plainOf(String(match.title)),
            open: entry?.default_fullscreen === true ? "fullscreen" : entry?.default_maximize === true ? "maximized"
                : entry?.default_floating === true ? "floating" : entry?.default_floating === false ? "tiled" : "",
            workspace: entry?.default_workspace ?? "",
            screen: String(entry?.default_output ?? ""),
            opacity: Number(entry?.opacity ?? 1),
            hidden: entry?.block_capture === true,
            width: Number(entry?.default_scrolling_extent ?? floatSize.width ?? 0),
            extra: extra
        }
    }
    function toUmbriel(rule: var): var {
        const out = Object.assign({}, rule.extra ?? {})
        const match = Object.assign({}, rule.extra?.match ?? {}, { app_id: "^" + root.regexOf(rule.app) + "$" })
        if (String(rule.title ?? "").length > 0) match.title = root.regexOf(rule.title)
        out.match = match
        if (rule.open === "floating" || rule.open === "tiled") out.default_floating = rule.open === "floating"
        if (rule.open === "maximized") out.default_maximize = true
        if (rule.open === "fullscreen") out.default_fullscreen = true
        if (typeof rule.workspace === "number" || String(rule.workspace ?? "").length > 0) out.default_workspace = rule.workspace
        if (String(rule.screen ?? "").length > 0) out.default_output = rule.screen
        if (Number(rule.opacity ?? 1) < 1) out.opacity = Math.round(Number(rule.opacity) * 100) / 100
        if (rule.hidden === true) out.block_capture = true
        if (Number(rule.width ?? 0) > 0) {
            if (rule.open === "floating") out.default_floating_size = { width: Number(rule.width) }
            else out.default_scrolling_extent = Number(rule.width)
        }
        return out
    }

    // ── Rin
    readonly property string rinDir: `${Directories.configPath}/rin/rules.d`
    property var rinRules: []
    property bool rinRead: false
    readonly property var rinDrawn: ["match", "open-floating", "open-maximized", "open-fullscreen", "open-on-workspace", "open-on-output", "opacity", "block-out-from", "default-column-width"]
    function fromRin(entry: var): var {
        const extra = {}
        for (const key of Object.keys(entry ?? {})) if (!root.rinDrawn.includes(key)) extra[key] = entry[key]
        const match = (Array.isArray(entry?.match) ? entry.match[0] : entry?.match) ?? {}
        const width = entry?.["default-column-width"]
        const workspace = Number(entry?.["open-on-workspace"] ?? 0)
        return {
            app: root.appOf(match["app-id"]),
            title: match.title === undefined ? "" : root.plainOf(String(match.title)),
            open: entry?.["open-fullscreen"] === true ? "fullscreen" : entry?.["open-maximized"] === true ? "maximized"
                : entry?.["open-floating"] === true ? "floating" : entry?.["open-floating"] === false ? "tiled" : "",
            workspace: workspace > 0 ? workspace : "",
            screen: String(entry?.["open-on-output"] ?? ""),
            opacity: Number(entry?.opacity ?? 1),
            hidden: String(entry?.["block-out-from"] ?? "").length > 0,
            width: Number((typeof width === "object" ? width?.proportion : width) ?? 0),
            extra: extra
        }
    }
    function toRin(rule: var): var {
        const match = { "app-id": "^" + root.regexOf(rule.app) + "$" }
        if (String(rule.title ?? "").length > 0) match.title = root.regexOf(rule.title)
        const out = { match: match }
        if (rule.open === "floating" || rule.open === "tiled") out["open-floating"] = rule.open === "floating"
        if (rule.open === "maximized") out["open-maximized"] = true
        if (rule.open === "fullscreen") out["open-fullscreen"] = true
        if (typeof rule.workspace === "number" && rule.workspace > 0) out["open-on-workspace"] = rule.workspace
        if (String(rule.screen ?? "").length > 0) out["open-on-output"] = rule.screen
        if (Number(rule.opacity ?? 1) < 1) out.opacity = Math.round(Number(rule.opacity) * 100) / 100
        if (rule.hidden === true) out["block-out-from"] = "screen-capture"
        if (Number(rule.width ?? 0) > 0) out["default-column-width"] = { proportion: Math.round(Number(rule.width) * 10000) / 10000 }
        return Object.assign(out, rule.extra ?? {})
    }
    function rinParse(text: string): var {
        try {
            return Array.from(Toml.parse(text)?.["window-rule"] ?? []).map(root.fromRin).filter(rule => rule.app.length > 0)
        } catch (e) {
            root.error = String(e)
            return root.rinRules
        }
    }
    function writeRin(): void {
        if (rinWriter.running) { rinWriter.again = true; return }
        const text = Toml.stringify(root.rinRules.length > 0 ? { "window-rule": root.rinRules.map(root.toRin) } : {},
            "iNiR Settings writes this file, one window rule per app.\nYour own rules go in another file here; a file later by name wins key by key.")
        // Written beside its place and renamed, so Rin never reads half of it.
        rinWriter.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/.90-settings.part" && mv -f "$1/.90-settings.part" "$1/90-settings.toml"', "sh", root.rinDir, text]
        rinWriter.running = true
    }
    Process {
        id: rinWriter
        property bool again: false
        stderr: StdioCollector { id: rinWhy }
        onExited: code => {
            if (code !== 0) root.error = String(rinWhy.text ?? "").trim() || String(code)
            if (rinWriter.again) { rinWriter.again = false; root.writeRin() }
            else rinOwn.reload()
        }
    }
    FileView {
        id: rinOwn
        path: root.rin ? `${root.rinDir}/90-settings.toml` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: rinOwn.reload()
        onLoadFailed: root.rinRead = true
        onLoaded: {
            root.rinRead = true
            if (!rinWriter.running) root.rinRules = root.rinParse(rinOwn.text())
        }
    }

    // ── Niri
    readonly property string niriDir: `${Directories.configPath}/niri`
    // The person's file when the main config includes it (what `inir bind` writes too), else the main config.
    readonly property bool niriSplit: /^[ \t]*include[ \t]+(optional=true[ \t]+)?"config\.d\/90-user-extra\.kdl"/m.test(niriMain.text())
    readonly property string niriFile: root.niriSplit ? "config.d/90-user-extra.kdl" : "config.kdl"
    readonly property string blockStart: "// >>> inir-window-rules: Settings writes this block, one window-rule per app >>>"
    readonly property string blockEnd: "// <<< inir-window-rules <<<"
    property string niriWant: ""

    function niriText(): string { return root.niriSplit ? niriOwn.text() : niriMain.text() }
    function kdlString(text: var): string { return '"' + String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"' }
    function blockOf(list: var): string {
        if (list.length === 0) return ""
        const lines = [root.blockStart]
        for (const rule of list) {
            lines.push("window-rule {")
            lines.push(`    match app-id=r#"^${root.regexOf(rule.app)}$"#` + (String(rule.title ?? "").length > 0 ? ` title=r#"${root.regexOf(rule.title)}"#` : ""))
            if (rule.open === "floating" || rule.open === "tiled") lines.push(`    open-floating ${rule.open === "floating"}`)
            if (rule.open === "maximized") lines.push("    open-maximized true")
            if (rule.open === "fullscreen") lines.push("    open-fullscreen true")
            if (String(rule.workspace ?? "").length > 0 && typeof rule.workspace !== "number") lines.push(`    open-on-workspace ${root.kdlString(rule.workspace)}`)
            if (String(rule.screen ?? "").length > 0) lines.push(`    open-on-output ${root.kdlString(rule.screen)}`)
            if (Number(rule.opacity ?? 1) < 1) lines.push(`    opacity ${Math.round(Number(rule.opacity) * 100) / 100}`)
            if (rule.hidden === true) lines.push('    block-out-from "screen-capture"')
            if (Number(rule.width ?? 0) > 0) lines.push(`    default-column-width { proportion ${Math.round(Number(rule.width) * 10000) / 10000}; }`)
            lines.push("}")
        }
        lines.push(root.blockEnd)
        return lines.join("\n")
    }
    // The file with Settings' block put where it was, or at the end; an empty block leaves no trace.
    function withBlock(text: string, block: string): string {
        const start = text.indexOf(root.blockStart.slice(0, 26)), end = text.indexOf(root.blockEnd)
        if (start >= 0 && end > start) {
            const before = text.slice(0, start).replace(/\n+$/, "\n"), after = text.slice(end + root.blockEnd.length).replace(/^\n+/, "\n")
            return block.length > 0 ? before + block + after : (before + after.replace(/^\n/, "")).replace(/\n*$/, "\n")
        }
        return block.length > 0 ? text.replace(/\n*$/, "\n\n") + block + "\n" : text
    }
    function niriParse(text: string): var {
        const start = text.indexOf(root.blockStart.slice(0, 26)), end = text.indexOf(root.blockEnd)
        if (start < 0 || end < start) return []
        const out = []
        for (const body of text.slice(start, end).split(/^window-rule \{$/m).slice(1)) {
            const grab = pattern => (body.match(pattern) ?? [])[1]
            const unquote = text => text === undefined ? "" : String(text).replace(/\\(["\\])/g, "$1")
            const app = root.appOf(grab(/app-id=r#"(.*?)"#/))
            if (app.length === 0) continue
            out.push({
                app: app,
                title: root.plainOf(grab(/title=r#"(.*?)"#/) ?? ""),
                open: /open-fullscreen true/.test(body) ? "fullscreen" : /open-maximized true/.test(body) ? "maximized"
                    : /open-floating true/.test(body) ? "floating" : /open-floating false/.test(body) ? "tiled" : "",
                workspace: unquote(grab(/open-on-workspace "((?:[^"\\]|\\.)*)"/)),
                screen: unquote(grab(/open-on-output "((?:[^"\\]|\\.)*)"/)),
                opacity: Number(grab(/\bopacity ([0-9.]+)/) ?? 1),
                hidden: /block-out-from "screen-capture"/.test(body),
                width: Number(grab(/proportion ([0-9.]+)/) ?? 0),
                extra: ({})
            })
        }
        return out
    }
    function writeNiri(): void {
        const text = root.niriWant
        root.niriWant = ""
        niriWriter.command = ["sh", "-c", root.niriScript, "sh", root.niriDir, root.niriFile, text]
        niriWriter.running = true
    }
    // The new file goes into a copy of the person's config first; only what `niri validate` accepts lands.
    readonly property string niriScript: [
        'dir="$1"; rel="$2"; text="$3"',
        'tmp="$(mktemp -d)" || exit 1',
        'trap \'rm -rf "$tmp"\' EXIT',
        'cp -a "$dir/." "$tmp/" || exit 1',
        'mkdir -p "$(dirname "$tmp/$rel")" && printf "%s" "$text" > "$tmp/$rel" || exit 1',
        'niri validate -c "$tmp/config.kdl" >"$tmp/.why" 2>&1 || { tail -n 4 "$tmp/.why" >&2; exit 2; }',
        'printf "%s" "$text" > "$dir/$rel"'
    ].join("\n")

    Process {
        id: niriWriter
        stderr: StdioCollector { id: niriWhy }
        onExited: code => {
            if (code !== 0) {
                root.error = String(niriWhy.text ?? "").trim() || Translation.tr("Niri did not accept the rule.")
                root.niriRules = root.niriParse(root.niriText())
            }
            if (root.niriWant.length > 0) root.writeNiri()
        }
    }
    FileView {
        id: niriMain
        path: root.niri ? `${root.niriDir}/config.kdl` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: niriMain.reload()
        onLoadFailed: root.unread = true
        onLoaded: {
            root.unread = false
            if (!root.niriSplit) root.niriRules = root.niriParse(niriMain.text())
        }
    }
    FileView {
        id: niriOwn
        path: root.niri && root.niriSplit ? `${root.niriDir}/config.d/90-user-extra.kdl` : ""
        watchChanges: true
        printErrors: false
        onFileChanged: niriOwn.reload()
        onLoaded: if (!niriWriter.running && root.niriWant.length === 0) root.niriRules = root.niriParse(niriOwn.text())
    }
}
