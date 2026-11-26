pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Autostart manager for niri (and Umbriel, whose `[general] autostart` array in
 * ~/.config/umbriel/config.d/50-startup.toml holds the same managed section, one
 * quoted command per line: Umbriel replaces an array a later include sets, so
 * the section lives inside the one array, never in a file of its own).
 *
 * On Rin, whose session starts xdg-desktop-autostart.target, each managed entry is a desktop file in
 * ~/.config/autostart (see the Rin section below).
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

    readonly property bool rin: CompositorService.isRin
    // iNiR manages login apps on Niri and Umbriel (their startup file) and on Rin (XDG autostart).
    readonly property bool supported: CompositorService.isNiri || root.rin
    // The name the families read; it means `supported`.
    readonly property bool isNiri: root.supported
    // Umbriel's TOML: entries are array strings, comments start with #.
    readonly property bool toml: CompositorService.isUmbriel
    readonly property string _comment: toml ? "#" : "//"

    readonly property string startupDir: {
        if (root.rin) return `${Directories.configPath}/autostart`
        const home = Directories.homePath ?? ""
        return home.length === 0 ? "" : `${home}/.config/${root.toml ? "umbriel" : "niri"}/config.d`
    }
    readonly property string startupFilePath: root.rin ? root.startupDir : startupDir.length === 0 ? ""
        : `${startupDir}/50-startup.${root.toml ? "toml" : "kdl"}`

    readonly property string beginMarker: `${_comment} >>> inir-managed-autostart >>>`
    readonly property string endMarker: `${_comment} <<< inir-managed-autostart <<<`
    readonly property string sectionHeader: `${_comment} Managed by iNiR Settings — add or remove entries via Settings › Autostart.`

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
        function onIsRinChanged() {
            root.status = root.isNiri ? "read" : "notniri"
            if (root.isNiri) root.reload()
        }
    }

    function reload(): void {
        if (root.rin) {
            rinReader.running = false
            rinReader.running = true
            return
        }
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

    // An Umbriel autostart entry: one quoted command, split on blanks for matching.
    function _tomlTokens(rawLine): var {
        let line = String(rawLine ?? "").trim()
        let enabled = true
        if (line.startsWith("#")) {
            enabled = false
            line = line.replace(/^#/, "").trim()
        }
        const m = line.match(/^"((?:[^"\\]|\\.)*)"\s*,?\s*$/)
        if (!m) return null
        const tokens = _unescape(m[1]).split(/\s+/).filter(t => t.length > 0)
        return tokens.length > 0 ? { tokens: tokens, enabled: enabled, raw: String(rawLine ?? "").trim() } : null
    }

    // Extract the quoted tokens of a spawn line. Returns [] if not a spawn line.
    function _spawnTokens(rawLine): var {
        if (root.toml) return _tomlTokens(rawLine)
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
        } else if (root.toml) {
            // No markers yet: the section goes in before the autostart array closes.
            const open = lines.findIndex(l => /^\s*autostart\s*=\s*\[/.test(l))
            const close = open < 0 ? -1 : lines.findIndex((l, i) => i > open && /^\s*\]/.test(l))
            if (close < 0) {
                head = (content ?? "") + ((content ?? "").includes("[general]") ? "" : "\n[general]") + "\nautostart = ["
                tail = "]\n"
            } else {
                head = lines.slice(0, close).join("\n")
                tail = lines.slice(close).join("\n")
            }
            managedText = ""
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
        const appRe = root.toml ? /^"gtk-launch\s+((?:[^"\\\s]|\\.)+)"\s*,?\s*$/
                                : /^spawn-at-startup\s+"gtk-launch"\s+"((?:[^"\\]|\\.)*)"\s*$/
        const cmdRe = root.toml ? /^"((?:[^"\\]|\\.)*)"\s*,?\s*$/
                                : /^spawn-sh-at-startup\s+"((?:[^"\\]|\\.)*)"\s*$/
        for (let i = 0; i < mlines.length; i++) {
            let line = mlines[i].trim()
            if (line.length === 0 || line === root.sectionHeader) continue
            let enabled = true
            if (line.startsWith(root._comment)) {
                enabled = false
                line = line.slice(root._comment.length).trim()
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
        const indent = root.toml ? "  " : ""
        lines.push(indent + beginMarker)
        lines.push(indent + sectionHeader)
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i]
            const prefix = e.enabled ? "" : `${root._comment} `
            if (root.toml) {
                // Umbriel runs each with /bin/sh -c.
                const command = e.type === "app" ? `gtk-launch ${e.desktopId ?? ""}` : (e.command ?? "")
                lines.push(`  ${prefix}"${_escape(command)}",`)
            } else if (e.type === "app") {
                const id = _escape(e.desktopId ?? "")
                lines.push(`${prefix}spawn-at-startup "gtk-launch" "${id}"`)
            } else {
                const cmd = _escape(e.command ?? "")
                lines.push(`${prefix}spawn-sh-at-startup "${cmd}"`)
            }
        }
        lines.push(indent + endMarker)
        const section = lines.join("\n")

        let out = root._head
        if (out.length > 0 && !out.endsWith("\n")) out += "\n"
        out += section + "\n"
        // Tail: ensure it starts on its own line and ends with a newline.
        if (root._tail.length > 0) {
            if (!root._tail.startsWith("\n") && !root.toml) out += "\n"
            out += root._tail
            if (!out.endsWith("\n")) out += "\n"
        }
        return out
    }

    function _write(): void {
        if (root.rin) {
            root._writeRin()
            return
        }
        if (!isNiri || startupFilePath.length === 0) {
            root.status = isNiri ? "missing" : "notniri"
            return
        }
        const text = _serialize()
        // Ensure the directory exists (defensive — the file ships with iNiR).
        Quickshell.execDetached(["mkdir", "-p", root.startupDir])
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
            const gone = entries.splice(index, 1)[0]
            root.entries = entries
            _write()
            const name = gone.type === "app" ? (DesktopEntries.byId(gone.desktopId)?.name ?? gone.desktopId) : gone.command
            Undo.offer(Translation.tr("Removed %1 from autostart").arg(name), () => {
                const back = root.entries.slice()
                back.splice(Math.min(index, back.length), 0, gone)
                root.entries = back
                _write()
            })
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
            if (lines[i].enabled && (lines[i].id === String(app.id ?? "").toLowerCase() || _appMatchesTokens(app, lines[i].tokens)))
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

    /// Login autostart manager. On Rin each entry is a desktop file in `~/.config/autostart`; on Niri: Reads and writes the managed section of `~/.config/niri/config.d/50-startup.kdl`
    /// (delimited by `// >>> inir-managed-autostart >>>` / `// <<< inir-managed-autostart <<<`). Base iNiR lines and
    /// any hand-written `spawn-at-startup` lines outside the markers are preserved verbatim; toggling an entry
    /// comments the line out instead of deleting it. Safe no-op on non-Niri compositors (the page shows a guard
    /// instead).
    ///
    /// The Settings UI (ii: AutostartConfig, waffle: WAutostartPage) is the primary interface; these IPC calls exist
    /// for scripts/keybinds. Apps the user already launches via hand-written lines outside the markers are detected
    /// and shown as "External" (read-only) in the list.
    IpcHandler {
        target: "autostart"
        /// Return `<compositor>|<path>|<managedCount>|<externalCount>|<state>` (compositor: niri, umbriel or other)
        function status(): string {
            return `${root.isNiri ? CompositorService.compositor : "other"}|${root.startupFilePath}|${root.entries.length}|${root.externalLines.length}|${root.status}`
        }
        /// Append a managed `spawn-sh-at-startup` shell line
        function addCommand(cmd: string): string {
            root.addCommand(cmd)
            return "ok"
        }
        /// Append a managed `gtk-launch <desktopId>` entry
        function addApp(desktopId: string): string {
            root.addApp(desktopId)
            return "ok"
        }
        /// Remove the last managed entry
        function removeLast(): string {
            if (root.entries.length > 0) root.removeEntry(root.entries.length - 1)
            return "ok"
        }
        /// Force re-read the startup file
        function reload(): string {
            root.reload()
            return "ok"
        }
    }

    // ── Rin: XDG autostart ───────────────────────────────────────────────
    // Rin's session starts xdg-desktop-autostart.target, so each managed entry is its own desktop file,
    // ~/.config/autostart/inir-autostart-NNN.desktop, marked X-iNiR-Autostart; a disabled one carries Hidden=true.
    // A command runs from base64 through sh: systemd's generator reads `$` and `\` in Exec its own way. Every
    // other desktop file there is external.
    readonly property string rinPrefix: "inir-autostart-"
    property bool _rinAgain: false

    function _desktopValue(s): string {
        return String(s ?? "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n")
    }

    function _desktopText(s): string {
        return String(s ?? "").replace(/\\(.)/g, (_, c) => c === "n" ? "\n" : c === "t" ? "\t" : c === "s" ? " " : c)
    }

    function _applyRin(listing): void {
        const entries = []
        const external = []
        for (const chunk of String(listing ?? "").split("\x1e")) {
            const lines = chunk.split("\n")
            const name = String(lines.shift() ?? "").trim()
            if (!name.endsWith(".desktop")) continue
            const keys = {}
            let group = ""
            for (const line of lines) {
                const t = line.trim()
                if (t.startsWith("[")) { group = t; continue }
                const eq = t.indexOf("=")
                if (group !== "[Desktop Entry]" || eq <= 0) continue
                const key = t.slice(0, eq).trim()
                if (keys[key] === undefined) keys[key] = t.slice(eq + 1).trim()
            }
            const enabled = keys["Hidden"] !== "true" && keys["X-GNOME-Autostart-enabled"] !== "false"
            const kind = name.startsWith(root.rinPrefix) ? keys["X-iNiR-Autostart"] : undefined
            if (kind === "app") {
                entries.push({ type: "app", desktopId: root._desktopText(keys["X-iNiR-App"]), enabled: enabled })
            } else if (kind === "command") {
                entries.push({ type: "command", command: root._desktopText(keys["X-iNiR-Command"]), enabled: enabled })
            } else {
                const tokens = root._desktopText(keys["Exec"]).replace(/%[a-zA-Z%]/g, "").replace(/"/g, "")
                    .split(/\s+/).filter(t => t.length > 0)
                external.push({ tokens: tokens, enabled: enabled, raw: name, id: name.replace(/\.desktop$/, "").toLowerCase() })
            }
        }
        root.entries = entries
        root.externalLines = external
        root.ready = true
        root.status = "read"
        _log("[Autostart] Read", entries.length, "managed +", external.length, "external autostart files")
    }

    function _writeRin(): void {
        if (rinWriter.running) {
            root._rinAgain = true
            return
        }
        const args = []
        for (const e of root.entries) {
            const app = e.type === "app"
            const what = String((app ? e.desktopId : e.command) ?? "")
            const name = app ? (DesktopEntries.byId(what)?.name ?? what) : what
            args.push(app ? "app" : "command", what, root._desktopValue(what), root._desktopValue(name), e.enabled ? "" : "Hidden=true")
        }
        rinWriter.command = ["/bin/sh", "-c", root.rinWrite, "sh", root.startupDir].concat(args)
        rinWriter.running = true
    }

    // $1: the folder, then five words an entry: kind, what it starts, the same as a desktop value, its name, Hidden=true or "".
    readonly property string rinWrite: 'dir=$1; shift; mkdir -p "$dir" || exit 1; rm -f "$dir"/inir-autostart-*.desktop; i=0; '
        + 'while [ $# -ge 5 ]; do i=$((i + 1)); f="$dir/inir-autostart-$(printf %03d "$i").desktop"; '
        + 'if [ "$1" = app ]; then run="gtk-launch $2"; key="X-iNiR-App=$3"; '
        + 'else run="sh -c \\"echo $(printf %s "$2" | base64 -w0) | base64 -d | sh\\""; key="X-iNiR-Command=$3"; fi; '
        + 'printf "[Desktop Entry]\\nType=Application\\nName=%s\\nExec=%s\\nX-iNiR-Autostart=%s\\n%s\\n" "$4" "$run" "$1" "$key" > "$f" || exit 1; '
        + '[ -z "$5" ] || printf "%s\\n" "$5" >> "$f"; shift 5; done'

    Process {
        id: rinReader
        command: ["/bin/sh", "-c", 'for f in "$1"/*.desktop; do [ -f "$f" ] || continue; printf "\\036%s\\n" "${f##*/}"; cat "$f"; echo; done', "sh", root.startupDir]
        stdout: StdioCollector {
            onStreamFinished: root._applyRin(text)
        }
    }

    Process {
        id: rinWriter
        onExited: exitCode => {
            if (exitCode !== 0) root.status = "write"
            if (root._rinAgain) {
                root._rinAgain = false
                root._writeRin()
            } else {
                root.reload()
            }
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
