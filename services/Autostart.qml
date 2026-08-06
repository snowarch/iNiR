pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Autostart manager for niri.
 *
 * Source of truth is the niri startup file
 *   ~/.config/niri/config.d/50-startup.kdl
 * which uses `spawn-at-startup` / `spawn-sh-at-startup` directives run by the
 * compositor at login. iNiR does NOT spawn these itself — niri owns startup.
 *
 * To stay safe for every user (the file ships base iNiR lines for polkit,
 * cliphist, XDG_MENU_PREFIX, etc.), this service only ever touches a
 * marker-delimited section:
 *
 *   // >>> inir-managed-autostart >>>
 *   ...managed entries...
 *   // <<< inir-managed-autostart <<<
 *
 * Everything outside the markers is read-only as far as this service is
 * concerned — base iNiR lines and any hand-written user lines are preserved
 * verbatim across every write. If the markers are absent (first run), they are
 * appended at the end of the file.
 *
 * Entry line grammar (inside the markers):
 *   spawn-at-startup "gtk-launch" "<desktopId>"        → enabled app
 *   // spawn-at-startup "gtk-launch" "<desktopId>"     → disabled app
 *   spawn-sh-at-startup "<shell command>"              → enabled command
 *   // spawn-sh-at-startup "<shell command>"           → disabled command
 *
 * Apps launch via gtk-launch so the .desktop Exec/working dir/etc. are
 * respected. Commands use spawn-sh-at-startup so pipes, env, &&, etc. work.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    // ── Paths / environment ──────────────────────────────────────────────

    readonly property bool isNiri: CompositorService.isNiri

    readonly property string startupFilePath: {
        try {
            const home = Directories.homePath ?? ""
            if (home.length === 0) return ""
            return `${home}/.config/niri/config.d/50-startup.kdl`
        } catch (e) {
            return ""
        }
    }

    readonly property string beginMarker: "// >>> inir-managed-autostart >>>"
    readonly property string endMarker: "// <<< inir-managed-autostart <<<"
    readonly property string sectionHeader: "// Managed by iNiR Settings — add or remove entries via Settings › Autostart."

    // ── Model ────────────────────────────────────────────────────────────

    // Each entry: { type: "app"|"command", desktopId?: string, command?: string, enabled: bool }
    property var entries: []
    // spawn-at-startup / spawn-sh-at-startup lines found OUTSIDE the managed
    // markers (base iNiR lines + hand-written user lines). Each:
    //   { tokens: [string], enabled: bool, raw: string }
    // Read-only — we never rewrite these, only reflect them in the UI so the
    // user sees what niri is already launching.
    property var externalLines: []
    property bool ready: false
    // "" | "missing" (file absent) | "notniri" (compositor isn't niri) | "read" | "write"
    property string status: isNiri ? "read" : "notniri"

    // Frozen head/tail captured at parse time so writes never disturb lines
    // outside the managed section.
    property string _head: ""
    property string _tail: ""
    property bool _hasMarkers: false

    // ── Lifecycle ────────────────────────────────────────────────────────

    Component.onCompleted: root.reload()

    Connections {
        target: CompositorService
        function onIsNiriChanged() {
            root.status = root.isNiri ? "read" : "notniri"
            if (root.isNiri) root.reload()
        }
    }

    function reload(): void {
        if (!isNiri || startupFilePath.length === 0) {
            root.status = isNiri ? "missing" : "notniri"
            return
        }
        startupFileView.path = Qt.resolvedUrl(startupFilePath)
        startupFileView.reload()
    }

    // ── Parse / serialize ────────────────────────────────────────────────

    function _escape(s): string {
        return String(s ?? "").replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    }

    function _unescape(s): string {
        // KDL strings only escape " and \; any other \x passes through as x.
        return String(s ?? "").replace(/\\(.)/g, (_, c) => c)
    }

    function _basename(p): string {
        const s = String(p ?? "")
        const i = s.lastIndexOf("/")
        return (i >= 0 ? s.slice(i + 1) : s).toLowerCase()
    }

    // Extract the quoted tokens of a spawn line. Returns [] if not a spawn line.
    function _spawnTokens(rawLine): var {
        let line = String(rawLine ?? "").trim()
        if (line.length === 0) return null
        let enabled = true
        if (line.startsWith("//")) {
            enabled = false
            line = line.replace(/^\/\//, "").trim()
        }
        const kw = /^(spawn-sh-at-startup|spawn-at-startup)\s+/
        if (!kw.test(line)) return null
        const rest = line.replace(kw, "")
        const tokens = []
        const re = /"((?:[^"\\]|\\.)*)"/g
        let m
        while ((m = re.exec(rest)) !== null) tokens.push(_unescape(m[1]))
        if (tokens.length === 0) return null
        return { tokens: tokens, enabled: enabled, raw: String(rawLine ?? "").trim() }
    }

    // Does an AppSearch entry match a parsed external spawn line?
    // gtk-launch form: tokens[0]==="gtk-launch", tokens[1] is a desktop id.
    // Raw form: tokens[0] is an executable — match by id or command basename.
    function _appMatchesTokens(app, tokens): bool {
        if (!app || !tokens || tokens.length === 0) return false
        const id = String(app.id ?? "").toLowerCase()
        const cmd0 = _basename(Array.isArray(app.command) ? (app.command[0] ?? "") : (app.command ?? ""))
        const t0 = String(tokens[0] ?? "").toLowerCase()
        if (t0 === "gtk-launch") {
            const t1 = String(tokens[1] ?? "").toLowerCase().replace(/\.desktop$/, "")
            return t1.length > 0 && t1 === id
        }
        // Raw executable form.
        const b0 = _basename(tokens[0])
        return (id.length > 0 && (id === t0 || id === b0))
            || (cmd0.length > 0 && (cmd0 === t0 || cmd0 === b0))
    }

    function _applyParsed(content): void {
        const lines = (content ?? "").split("\n")
        let beginIdx = -1
        let endIdx = -1
        for (let i = 0; i < lines.length; i++) {
            const t = lines[i].trim()
            if (t === beginMarker && beginIdx < 0) beginIdx = i
            else if (t === endMarker && endIdx < 0) endIdx = i
        }

        let head, managedText, tail
        let hasMarkers = false
        if (beginIdx >= 0 && endIdx > beginIdx) {
            hasMarkers = true
            head = lines.slice(0, beginIdx).join("\n")
            managedText = lines.slice(beginIdx + 1, endIdx).join("\n")
            tail = lines.slice(endIdx + 1).join("\n")
        } else {
            // First run: no markers. Head = whole file, markers appended on write.
            head = content ?? ""
            managedText = ""
            tail = ""
        }

        // Guarantee a trailing newline on head so the begin marker starts on
        // its own line.
        if (head.length > 0 && !head.endsWith("\n")) head += "\n"

        const entries = []
        const mlines = managedText.split("\n")
        const appRe = /^spawn-at-startup\s+"gtk-launch"\s+"((?:[^"\\]|\\.)*)"\s*$/
        const cmdRe = /^spawn-sh-at-startup\s+"((?:[^"\\]|\\.)*)"\s*$/
        for (let i = 0; i < mlines.length; i++) {
            let line = mlines[i].trim()
            if (line.length === 0) continue
            let enabled = true
            if (line.startsWith("//")) {
                enabled = false
                line = line.replace(/^\/\//, "").trim()
            }
            let m = line.match(appRe)
            if (m) {
                entries.push({ type: "app", desktopId: _unescape(m[1]), enabled: enabled })
                continue
            }
            m = line.match(cmdRe)
            if (m) {
                entries.push({ type: "command", command: _unescape(m[1]), enabled: enabled })
                continue
            }
            // Anything else (decorative comments / blanks) is ignored on parse.
        }

        // Scan lines OUTSIDE the markers for spawn directives the user (or
        // iNiR defaults) already has — reflected read-only in the UI.
        const external = []
        const outside = (head + "\n" + tail).split("\n")
        for (let i = 0; i < outside.length; i++) {
            const parsed = _spawnTokens(outside[i])
            if (parsed) external.push(parsed)
        }

        root._head = head
        root._tail = tail
        root._hasMarkers = hasMarkers
        root.entries = entries
        root.externalLines = external
        root.ready = true
        root.status = "read"
        _log("[Autostart] Parsed", entries.length, "managed +", external.length, "external spawn lines")
    }

    function _serialize(): string {
        const lines = []
        lines.push(beginMarker)
        lines.push(sectionHeader)
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            const prefix = e.enabled ? "" : "// "
            if (e.type === "app") {
                const id = _escape(e.desktopId ?? "")
                lines.push(`${prefix}spawn-at-startup "gtk-launch" "${id}"`)
            } else {
                const cmd = _escape(e.command ?? "")
                lines.push(`${prefix}spawn-sh-at-startup "${cmd}"`)
            }
        }
        lines.push(endMarker)
        const section = lines.join("\n")

        let out = root._head
        if (out.length > 0 && !out.endsWith("\n")) out += "\n"
        out += section + "\n"
        // Tail: ensure it starts on its own line and ends with a newline.
        if (root._tail.length > 0) {
            if (!root._tail.startsWith("\n")) out += "\n"
            out += root._tail
            if (!out.endsWith("\n")) out += "\n"
        }
        return out
    }

    function _write(): void {
        if (!isNiri || startupFilePath.length === 0) {
            root.status = isNiri ? "missing" : "notniri"
            return
        }
        const text = _serialize()
        // Ensure the directory exists (defensive — the file ships with iNiR).
        Quickshell.execDetached(["/usr/bin/mkdir", "-p",
            (Directories.homePath ?? "") + "/.config/niri/config.d"])
        startupFileView.path = Qt.resolvedUrl(startupFilePath)
        startupFileView.setText(text)
        _log("[Autostart] Wrote", root.entries.length, "entries to", startupFilePath)
    }

    // ── Public mutations ─────────────────────────────────────────────────

    function addApp(desktopId): void {
        const id = String(desktopId ?? "").trim()
        if (id.length === 0) return
        // Avoid duplicates by desktopId.
        const entries = root.entries.slice()
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].type === "app" && entries[i].desktopId === id) {
                if (!entries[i].enabled) entries[i].enabled = true
                root.entries = entries
                _write()
                return
            }
        }
        entries.push({ type: "app", desktopId: id, enabled: true })
        root.entries = entries
        _write()
    }

    function addCommand(command): void {
        const cmd = String(command ?? "").trim()
        if (cmd.length === 0) return
        const entries = root.entries.slice()
        entries.push({ type: "command", command: cmd, enabled: true })
        root.entries = entries
        _write()
    }

    function removeEntry(index): void {
        const entries = root.entries.slice()
        if (index >= 0 && index < entries.length) {
            entries.splice(index, 1)
            root.entries = entries
            _write()
        }
    }

    function setEntryEnabled(index, enabled): void {
        const entries = root.entries.slice()
        if (index >= 0 && index < entries.length) {
            entries[index].enabled = enabled === true
            root.entries = entries
            _write()
        }
    }

    function isAppEnabled(desktopId): bool {
        const id = String(desktopId ?? "")
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            if (e.type === "app" && e.desktopId === id) return e.enabled === true
        }
        return false
    }

    // Does any external (outside-markers) spawn line match this app? Read-only.
    function isAppExternal(app): bool {
        const lines = root.externalLines ?? []
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].enabled && _appMatchesTokens(app, lines[i].tokens))
                return true
        }
        return false
    }

    // App is launched at login either via a managed entry or an external line.
    function isAppOn(app): bool {
        if (!app) return false
        if (root.isAppEnabled(app.id)) return true
        return root.isAppExternal(app)
    }

    // "managed" (we own it) | "external" (user/defaults own it) | "none"
    function appEntrySource(app): string {
        if (!app) return "none"
        const id = String(app.id ?? "")
        for (let i = 0; i < root.entries.length; i++) {
            if (root.entries[i].type === "app" && root.entries[i].desktopId === id)
                return "managed"
        }
        if (root.isAppExternal(app)) return "external"
        return "none"
    }

    function setAppEnabled(desktopId, enabled): void {
        const id = String(desktopId ?? "")
        const entries = root.entries.slice()
        let idx = -1
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].type === "app" && entries[i].desktopId === id) { idx = i; break }
        }
        if (enabled && idx === -1) {
            entries.push({ type: "app", desktopId: id, enabled: true })
        } else if (idx !== -1) {
            entries[idx].enabled = enabled === true
        }
        root.entries = entries
        _write()
    }

    // ── IPC (scripts / keybinds) ────────────────────────────────

    IpcHandler {
        target: "autostart"
        function status(): string {
            return `${root.isNiri ? "niri" : "other"}|${root.startupFilePath}|${root.entries.length}|${root.externalLines.length}|${root.status}`
        }
        function addCommand(cmd: string): string {
            root.addCommand(cmd)
            return "ok"
        }
        function addApp(desktopId: string): string {
            root.addApp(desktopId)
            return "ok"
        }
        function removeLast(): string {
            if (root.entries.length > 0) root.removeEntry(root.entries.length - 1)
            return "ok"
        }
        function reload(): string {
            root.reload()
            return "ok"
        }
    }

    // ── File I/O ─────────────────────────────────────────────────────────

    FileView {
        id: startupFileView
        watchChanges: true
        printErrors: false
        onFileChanged: {
            // External edit (user touched the file by hand) — re-read.
            _log("[Autostart] file changed externally, reloading")
            startupFileView.reload()
        }
        onLoadedChanged: {
            if (startupFileView.loaded) {
                root._applyParsed(startupFileView.text())
            }
        }
        onLoadFailed: {
            root.ready = true
            root.status = "missing"
            root.entries = []
            root.externalLines = []
            root._head = ""
            root._tail = ""
            root._hasMarkers = false
            _log("[Autostart] load failed — file missing:", root.startupFilePath)
        }
    }
}
