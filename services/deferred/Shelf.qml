pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions

// The Shelf: what you copied, the screenshots you took and the files you dropped, newest first. Clips stay in
// cliphist and shots stay where they were saved; only dropped files and pinned clips are copied into the shelf's
// own folder. Clear and logout hide (floors), they never wipe another surface's history.
Singleton {
    id: root

    readonly property var prefs: Config.options?.shelf
    readonly property bool enabled: root.prefs?.enable ?? true
    readonly property int length: Math.max(6, Math.min(96, Number(root.prefs?.length ?? 24)))
    readonly property bool images: root.prefs?.images ?? true
    readonly property string dir: `${Directories.stateUserPath}/shelf`
    readonly property string keptDir: `${root.dir}/kept`
    readonly property string shotsDir: FileUtils.trimFileProtocol(String(Directories.screenshotsPath).replace(/^~(?=\/|$)/, Directories.home))

    // What the page shows ("all", "shots", "copied", "files"); IPC and Super+V set it before opening.
    property string filter: "all"
    signal copied(string kind)

    // Persisted (state.json, 0600 with its folder).
    property var kept: []
    property real clipFloor: 0
    property real shotFloor: 0
    property var hidden: []
    property var seen: ({})
    property string session: ""
    property bool loaded: false
    property bool firstRun: false
    property bool shotsReady: false

    readonly property var clipEntries: Cliphist.entries
    readonly property var items: {
        const out = []
        const keptClips = new Set()
        const keptShots = new Set()
        for (const k of root.kept) {
            if (k.clip) keptClips.add(String(k.clip))
            if (k.origin === "shot") keptShots.add(k.source ?? k.path)
            out.push({ key: k.key, kind: k.kind, origin: k.origin, path: k.path, name: k.name ?? "",
                preview: k.preview ?? "", at: Number(k.at ?? 0), pinned: !!k.pinned, entry: "" })
        }
        const hidden = new Set(root.hidden)
        const shotTimes = []
        for (let i = 0; i < shotsModel.count; i++) {
            const path = FileUtils.trimFileProtocol(String(shotsModel.get(i, "fileUrl")))
            const at = shotsModel.get(i, "fileModified")?.getTime?.() ?? 0
            shotTimes.push(at)
            if (at < root.shotFloor || keptShots.has(path) || hidden.has("shot:" + path)) continue
            out.push({ key: "shot:" + path, kind: "image", origin: "shot", path: path,
                name: String(shotsModel.get(i, "fileName")), preview: "", at: at, pinned: false, entry: "" })
        }
        for (const entry of root.clipEntries) {
            const id = Number(Cliphist.entryId(entry))
            if (!(id > root.clipFloor) || keptClips.has(String(id))) continue
            const image = Cliphist.entryIsImage(entry)
            const at = Number(root.seen[id] ?? 0)
            // A shot the shell also copied: the shot already stands for it.
            if (image && (!root.images || shotTimes.some(t => Math.abs(t - at) < 4000))) continue
            out.push({ key: "clip:" + id, kind: image ? "image" : "text", origin: "copied",
                path: image ? `${Directories.cliphistDecode}/${id}` : "", name: "", clip: id,
                preview: image ? "" : String(entry).slice(String(entry).indexOf("\t") + 1),
                at: at, pinned: false, entry: entry })
        }
        out.sort((a, b) => (b.pinned - a.pinned) || (b.at - a.at))
        let loose = 0
        return out.filter(item => item.pinned || loose++ < root.length)
    }
    function matches(item, filter: string): bool {
        if (filter === "shots") return item.origin === "shot"
        if (filter === "copied") return item.origin === "copied"
        if (filter === "files") return item.origin === "dropped"
        return true
    }
    function itemsFor(filter: string): var { return root.items.filter(item => root.matches(item, filter)) }
    function countOf(filter: string): int { return root.itemsFor(filter).length }

    // --- Acting on an item -----------------------------------------------------------------------------------
    function copy(item): void {
        if (!item) return
        if (item.entry.length > 0) Cliphist.copy(item.entry)
        else if (item.kind === "text") Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "sh", item.path])
        else if (item.kind === "image") Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", item.path])
        else Quickshell.execDetached(["sh", "-c", 'printf "%s\\r\\n" "$1" | wl-copy --type text/uri-list', "sh", root.uriOf(item.path)])
        root.copied(item.kind)
    }
    function uriOf(path: string): string {
        return "file://" + String(path).split("/").map(part => encodeURIComponent(part)).join("/")
    }
    function remove(item): void {
        if (!item) return
        if (item.origin === "copied" && item.entry.length > 0) { Cliphist.deleteEntry(item.entry); return }
        if (item.key.startsWith("shot:")) { root.hidden = root.hidden.concat([item.key]).slice(-200); root.save(); return }
        root.forget(item.key)
    }
    function forget(key: string): void {
        const k = root.kept.find(entry => entry.key === key)
        if (!k) return
        if (String(k.path).startsWith(root.keptDir + "/")) Quickshell.execDetached(["rm", "-rf", "--", k.path])
        root.kept = root.kept.filter(entry => entry.key !== key)
        root.save()
    }
    function togglePin(item): void {
        if (!item) return
        if (item.pinned) {
            const k = root.kept.find(entry => entry.key === item.key)
            // A dropped file stays on the shelf unpinned; a pinned clip or shot goes back to being live.
            if (k?.origin === "dropped") { root.kept = root.kept.map(e => e.key === k.key ? Object.assign({}, e, { pinned: false }) : e); root.save() }
            else root.forget(item.key)
            return
        }
        if (item.origin === "dropped") {
            root.kept = root.kept.map(e => e.key === item.key ? Object.assign({}, e, { pinned: true }) : e)
            root.save()
            return
        }
        const key = `kept:${Date.now()}-${root.pinQueue.length}`
        if (item.origin === "shot") {
            if (root.pinQueue.some(pin => pin.record.source === item.path)) return
            // A copy: the screenshot itself can be deleted or moved.
            const path = `${root.keptDir}/${Date.now()}-${item.name}`
            root.queuePin({ key: key, kind: "image", origin: "shot", path: path, source: item.path, name: item.name,
                at: item.at, pinned: true }, ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$2")" && cp --reflink=auto -- "$1" "$2"', "sh", item.path, path])
            return
        }
        // A clip is decoded into the shelf's folder: cliphist recycles ids and rotates entries out.
        if (root.pinQueue.some(pin => pin.record.clip === String(item.clip))) return
        const path = `${root.keptDir}/clip-${item.clip}${item.kind === "image" ? ".png" : ".txt"}`
        root.queuePin({ key: key, kind: item.kind, origin: "copied", path: path, clip: String(item.clip),
            preview: item.preview.slice(0, 240), at: item.at, pinned: true },
            ["sh", "-c", 'umask 077; mkdir -p "$(dirname "$2")" && cliphist decode "$1" > "$2"', "sh", String(item.clip), path])
    }
    // One pin at a time: a second one started while the first ran was dropped and kept the first's file.
    property var pinQueue: []
    function queuePin(record, command): void {
        root.pinQueue = root.pinQueue.concat([{ record: record, command: command }])
        if (!pinProc.running) root.pinNext()
    }
    function pinNext(): void {
        if (root.pinQueue.length === 0) return
        pinProc.command = root.pinQueue[0].command
        pinProc.running = true
    }
    Process {
        id: pinProc
        onExited: (code) => {
            const done = root.pinQueue[0]
            root.pinQueue = root.pinQueue.slice(1)
            if (code === 0 && done) { root.kept = [done.record].concat(root.kept); root.save() }
            root.pinNext()
        }
    }

    // Everything unpinned leaves: clips and shots by floor, dropped copies from disk.
    function clear(): void {
        root.clipFloor = Math.max(root.clipFloor, ...root.clipEntries.map(entry => Number(Cliphist.entryId(entry)) || 0))
        root.shotFloor = Date.now()
        for (const k of root.kept) if (!k.pinned && String(k.path).startsWith(root.keptDir + "/"))
            Quickshell.execDetached(["rm", "-rf", "--", k.path])
        root.kept = root.kept.filter(k => k.pinned)
        root.hidden = []
        root.save()
    }

    // --- Keeping what was dropped ----------------------------------------------------------------------------
    readonly property var imageExtensions: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "avif"]
    function keepUrls(urls): int {
        let n = 0
        const fresh = []
        const stamp = Date.now()
        for (const url of urls) {
            const text = String(url)
            if (!text.startsWith("file://")) continue
            let source = ""
            try { source = decodeURIComponent(text.slice(7)).replace(/\/$/, "") } catch (error) { continue }
            const name = source.split("/").pop()
            if (name.length === 0) continue
            const target = `${root.keptDir}/${stamp}-${n}-${name}`
            const ext = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
            Quickshell.execDetached(["sh", "-c", 'umask 077; mkdir -p "$(dirname "$2")" && cp -r --reflink=auto -- "$1" "$2"', "sh", source, target])
            fresh.push({ key: `kept:${stamp}-${n}`, kind: root.imageExtensions.includes(ext) ? "image" : "file",
                origin: "dropped", path: target, name: name, at: stamp + n, pinned: false })
            n++
        }
        if (n === 0) return 0
        root.kept = fresh.reverse().concat(root.kept)
        root.trimDropped()
        root.save()
        return n
    }
    function keepText(text: string): bool {
        const body = String(text ?? "")
        if (body.trim().length === 0) return false
        const stamp = Date.now()
        const path = `${root.keptDir}/${stamp}.txt`
        Quickshell.execDetached(["sh", "-c", 'umask 077; mkdir -p "$(dirname "$2")" && printf "%s" "$1" > "$2"', "sh", body, path])
        root.kept = [{ key: "kept:" + stamp, kind: "text", origin: "dropped", path: path, name: "",
            preview: body.slice(0, 240), at: stamp, pinned: false }].concat(root.kept)
        root.trimDropped()
        root.save()
        return true
    }
    function trimDropped(): void {
        const loose = root.kept.filter(k => !k.pinned && k.origin === "dropped")
        for (const k of loose.slice(root.length)) root.forget(k.key)
    }

    // --- Text for dragging out: decoded on press, held for one item ------------------------------------------
    property string textKey: ""
    property string text: ""
    function fetchText(item): void {
        if (!item || item.kind !== "text" || root.textKey === item.key) return
        root.textKey = item.key
        root.text = item.preview
        textProc.running = false
        textProc.command = item.entry.length > 0
            ? ["sh", "-c", 'cliphist decode "$1"', "sh", String(item.clip)]
            : ["cat", "--", item.path]
        textProc.running = true
    }
    Process {
        id: textProc
        stdout: StdioCollector { onStreamFinished: root.text = Cliphist.stripBrowserMarkup(this.text) }
    }

    // --- Image clips decode on demand for their thumbnails ---------------------------------------------------
    property var decoded: ({})
    property var decodeQueue: []
    function want(item): void {
        if (!item || item.origin !== "copied" || item.kind !== "image" || item.entry.length === 0) return
        const id = String(item.clip)
        if (root.decoded[id] || root.decodeQueue.includes(id)) return
        root.decodeQueue = root.decodeQueue.concat([id])
        if (!decodeProc.running) root.decodeNext()
    }
    function decodeNext(): void {
        if (root.decodeQueue.length === 0) return
        const id = root.decodeQueue[0]
        decodeProc.clipId = id
        decodeProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] && exit 0; cliphist decode "$1" > "$2.$$" && [ -s "$2.$$" ] && mv -f "$2.$$" "$2" || { rm -f "$2.$$"; exit 1; }',
            "sh", id, `${Directories.cliphistDecode}/${id}`]
        decodeProc.running = true
    }
    function thumbOf(item): string {
        if (!item || item.kind !== "image") return ""
        if (item.entry.length > 0 && !root.decoded[String(item.clip)]) return ""
        return "file://" + item.path
    }
    Process {
        id: decodeProc
        property string clipId: ""
        onExited: (code) => {
            const next = Object.assign({}, root.decoded)
            next[decodeProc.clipId] = code === 0
            root.decoded = next
            root.decodeQueue = root.decodeQueue.filter(id => id !== decodeProc.clipId)
            root.decodeNext()
        }
    }

    // --- Sources ---------------------------------------------------------------------------------------------
    FolderListModel {
        id: shotsModel
        // Set once the folder exists: a model on a missing folder never sees it appear.
        folder: root.enabled && root.shotsReady && root.shotsDir.length > 0 ? "file://" + root.shotsDir : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Time
    }

    // First sight of each clip id is its time: cliphist keeps none.
    onClipEntriesChanged: root.noteClips()
    function noteClips(): void {
        if (!root.loaded) return
        const next = {}
        let changed = false
        for (const entry of root.clipEntries) {
            const id = Cliphist.entryId(entry)
            if (id.length === 0) continue
            if (root.seen[id] !== undefined) next[id] = root.seen[id]
            else { next[id] = root.firstRun ? 0 : Date.now(); changed = true }
        }
        if (Object.keys(next).length !== Object.keys(root.seen).length) changed = true
        if (!changed) return
        root.seen = next
        root.firstRun = false
        root.save()
    }

    // --- Persistence -----------------------------------------------------------------------------------------
    function save(): void {
        if (!root.loaded) return
        saveTimer.restart()
    }
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: stateFile.setText(JSON.stringify({ version: 1, kept: root.kept, clipFloor: root.clipFloor,
            shotFloor: root.shotFloor, hidden: root.hidden, seen: root.seen, session: root.session }))
    }
    Process {
        id: prepare
        running: true
        command: ["sh", "-c", 'mkdir -p "$2"; umask 077; mkdir -p "$1" && chmod 700 "$1"; [ -e "$1/state.json" ] || printf "{}" > "$1/state.json"', "sh", root.dir, root.shotsDir]
        onExited: { stateFile.path = `${root.dir}/state.json`; root.shotsReady = true }
    }
    FileView {
        id: stateFile
        onLoaded: {
            let data = {}
            try { data = JSON.parse(stateFile.text() || "{}") } catch (e) { data = {} }
            root.firstRun = data.version === undefined
            root.kept = Array.isArray(data.kept) ? data.kept : []
            root.clipFloor = Number(data.clipFloor ?? 0)
            root.shotFloor = Number(data.shotFloor ?? 0)
            root.hidden = Array.isArray(data.hidden) ? data.hidden : []
            root.seen = data.seen ?? {}
            root.session = String(data.session ?? "")
            root.loaded = true
            bootId.reload()
            root.noteClips()
        }
        // A failed read never counts as empty: saving after it wiped the pins.
        onLoadFailed: if (++root.loadTries <= 3) retryLoad.start()
    }
    property int loadTries: 0
    Timer { id: retryLoad; interval: 1500; onTriggered: stateFile.reload() }
    // A new login is a new boot or a new session id; with "Clear on logout" the last one's loose items leave.
    FileView {
        id: bootId
        path: "/proc/sys/kernel/random/boot_id"
        blockLoading: false
        onLoaded: {
            const now = `${bootId.text().trim()}:${Quickshell.env("XDG_SESSION_ID") ?? ""}`
            if (root.session === now) return
            const fresh = root.session.length > 0
            root.session = now
            if (!fresh || !(root.prefs?.clearOnLogout ?? false)) root.save()
            else if (Cliphist.listed) root.clear()
            // Cleared before cliphist was read, the floor stayed under last session's clips.
            else root.clearOnList = true
        }
    }
    property bool clearOnList: false
    Connections {
        target: Cliphist
        function onListedChanged(): void {
            if (!root.clearOnList || !Cliphist.listed) return
            root.clearOnList = false
            root.clear()
        }
    }

    Component.onCompleted: if (root.enabled) Cliphist.refresh()
}
