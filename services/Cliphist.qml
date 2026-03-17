pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

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

    function decodeCommand(entry): string {
        if (root.cliphistBinary.includes("cliphist")) {
            const id = root.entryId(entry)
            if (id.length > 0)
                return `${root.cliphistBinary} decode ${id}`
            return `printf '%s\n' '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode`
        }

        const entryNumber = String(entry ?? "").split("\t")[0]
        return `${root.cliphistBinary} decode ${entryNumber}`
    }

    function refresh() {
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
            } else {
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
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
