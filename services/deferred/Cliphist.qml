pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    // Limit how many entries we keep/read to avoid huge models and heavy fuzzy search
    property int maxEntries: 400
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property list<string> entries: []
    property int _readAttempts: 0
    property bool _refreshQueued: false
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries.slice(0, root.maxEntries);
        }
        if (root.sloppySearch) {
            const results = entries.slice(0, Math.min(100, root.maxEntries)).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function entryId(entry): string {
        const match = String(entry ?? "").match(/^\s*(\d+)/)
        return match ? match[1] : ""
    }

    // Entries captured before the watcher started stripping browser markup still
    // hold it, and they outlive the fix — so clean on the way out as well. The
    // filter forwards anything that is not a browser text/html payload byte for
    // byte, which keeps images intact.
    readonly property string _markupFilter: `'${Directories.scriptsPath}/clipboard-store.py' --filter`

    function decodeCommand(entry): string {
        if (root.cliphistBinary.includes("cliphist")) {
            const id = root.entryId(entry)
            if (id.length > 0)
                return `${root.cliphistBinary} decode ${id} | ${root._markupFilter}`
            return `printf '%s\n' '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | ${root._markupFilter}`
        }

        const entryNumber = String(entry ?? "").split("\t")[0]
        return `${root.cliphistBinary} decode ${entryNumber} | ${root._markupFilter}`
    }

    function refresh() {
        if (readProc.running) {
            root._refreshQueued = true
            return
        }
        readProc.buffer = []
        readProc.running = true
    }

    function copy(entry) {
        root._log("[Cliphist] copy()", String(entry).slice(0, 120))
        root._selfCopy = true
        selfCopyResetTimer.restart()
        Quickshell.execDetached(["/usr/bin/bash", "-c", `${root.decodeCommand(entry)} | /usr/bin/wl-copy`]);
    }

    function paste(entry) {
        root._selfCopy = true
        Quickshell.execDetached(["/usr/bin/bash", "-c", `${root.decodeCommand(entry)} | /usr/bin/wl-copy\n${root.pressPasteCommand}`]);
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => `${root.decodeCommand(entry)} | /usr/bin/wl-copy\n/usr/bin/sleep ${root.pasteDelay}\n${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["/usr/bin/bash", "-c", pasteCommands.join(`\n/usr/bin/sleep ${root.pasteDelay}\n`)]);
    }

    Process {
        id: deleteProc
        property string entry: ""
        command: [root.cliphistBinary, "delete"]
        stdinEnabled: true
        function deleteEntry(entry) {
            deleteProc.entry = entry;
            deleteProc.stdinEnabled = true
            deleteProc.running = true;
        }
        onRunningChanged: {
            if (deleteProc.running) {
                const toWrite = deleteProc.entry
                deleteProc.write(toWrite)
                deleteProc.write("\n")
                deleteProc.stdinEnabled = false
            } else {
                deleteProc.stdinEnabled = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            deleteProc.entry = "";
            root.refresh();
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    Process {
        id: wipeProc
        command: [root.cliphistBinary, "wipe"]
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    // Pins store the decoded text, not the cliphist id: ids are recycled and
    // entries fall out of the store once maxEntries rotates past them.
    readonly property var pinned: Config.options?.clipboard?.pinned ?? []
    property int maxPinLength: 8000

    function isPinnable(entry): bool {
        return String(entry ?? "").length > 0 && !root.entryIsImage(entry)
    }

    function pinPreview(text): string {
        const firstLine = String(text ?? "").split("\n").find(l => l.trim().length > 0) ?? ""
        return firstLine.trim()
    }

    function isPinned(text): bool {
        return root.pinned.indexOf(text) !== -1
    }

    // Pins hold decoded text; list entries are "id<TAB>preview". Decoding every
    // visible row to compare would mean a subprocess per item, so match on the
    // preview instead.
    //
    // cliphist truncates that preview at 100 characters. Below the cut the
    // preview IS the whole entry, so it has to match exactly: prefix-matching a
    // short preview would mark every entry that merely starts a longer pin as
    // pinned. At or above the cut the preview is a prefix of the pinned text.
    readonly property int previewLimit: 100

    function _previewKey(text): string {
        return String(text ?? "").replace(/\s+/g, " ").trim()
    }

    function pinnedTextFor(entry): string {
        const raw = String(entry ?? "")
        const tab = raw.indexOf("\t")
        if (tab < 0) return ""
        const preview = root._previewKey(raw.slice(tab + 1))
        if (preview.length === 0) return ""
        const truncated = preview.length >= root.previewLimit
        return root.pinned.find(p => {
            const key = root._previewKey(p)
            return truncated ? key.startsWith(preview) : key === preview
        }) ?? ""
    }

    function unpin(text): void {
        Config.setNestedValue("clipboard.pinned", root.pinned.filter(p => p !== text))
    }

    function pinEntry(entry): void {
        if (!root.isPinnable(entry)) return
        pinProc.command = ["/usr/bin/bash", "-c", root.decodeCommand(entry)]
        pinProc.running = true
    }

    Process {
        id: pinProc
        stdout: StdioCollector {
            onStreamFinished: {
                // Entries stored before the watcher stripped browser markup still
                // carry it, and a pin keeps the decoded text forever — so clean it
                // here too, or pinning an old entry pins the markup with it.
                const decoded = root.stripBrowserMarkup(text).slice(0, root.maxPinLength)
                if (decoded.length === 0 || root.isPinned(decoded)) return
                Config.setNestedValue("clipboard.pinned", [decoded, ...root.pinned])
            }
        }
    }

    // Two wrappers mark a text/html payload: Firefox's content-type meta tag and
    // the CF_HTML fragment markers Chromium and Electron apps emit. They are the
    // only reliable sign that the content is markup rather than text that happens
    // to contain tags. Kept in sync with scripts/clipboard-store.py.
    function isBrowserMarkup(str): bool {
        return str.startsWith('<meta http-equiv="content-type" content="text/html')
            || str.indexOf("<!--StartFragment-->") !== -1
    }

    function stripBrowserMarkup(text): string {
        const str = String(text ?? "")
        if (!root.isBrowserMarkup(str))
            return str
        return StringUtils.stripHtmlTags(str.replace(/<!--[\s\S]*?-->/g, "")).trim()
    }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            // Skip refresh if clipboard text matches what we just copied ourselves
            if (root._selfCopy) {
                root._selfCopy = false;
                selfCopyResetTimer.stop();
                return;
            }
            // Skip refresh while window previews are being captured
            // (screenshots pollute clipboard temporarily, script cleans them up)
            if (root.suppressRefresh) return;
            delayedUpdateTimer.restart()
        }
    }

    property bool _selfCopy: false
    property bool suppressRefresh: false

    // Safety: reset _selfCopy if onClipboardTextChanged never fires (e.g. pipeline failed)
    Timer {
        id: selfCopyResetTimer
        interval: 2000
        onTriggered: {
            if (root._selfCopy) {
                root._log("[Cliphist] _selfCopy reset by timeout (pipeline may have failed)")
                root._selfCopy = false
            }
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: 800
        repeat: false
        onTriggered: {
            // Only refresh if not already running a read
            if (!readProc.running) root.refresh()
        }
    }

    Timer {
        id: readRetryTimer
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: readProc
        property list<string> buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Cap the number of entries we keep to avoid heavy models
                root.entries = readProc.buffer.slice(0, root.maxEntries)
                root._readAttempts = 0
                if (root._refreshQueued) {
                    root._refreshQueued = false
                    root.refresh()
                }
            } else {
                if (root._readAttempts < 3) {
                    root._readAttempts++
                    readRetryTimer.interval = 250 * root._readAttempts
                    readRetryTimer.restart()
                } else {
                    root._readAttempts = 0
                    console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
                }
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }
}
