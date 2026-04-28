pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string scriptPath: FileUtils.trimFileProtocol(`${Directories.scriptsPath}/quickshell-keepass`)
    readonly property string vaultDir: Config.options?.keepass?.vaultDir
        || FileUtils.trimFileProtocol(`${Directories.home}/.local/share/keepassqs`)
    property string vaultPath: ""
    readonly property string vaultName: {
        if (vaultPath.length === 0) return ""
        const n = vaultPath.split("/").pop()
        return n.endsWith(".kdbx") ? n.slice(0, -5) : n
    }

    property bool available: true
    property bool open: false
    property bool vaultExists: false
    property list<string> availableVaults: []
    property bool addMode: false
    property bool unlocked: false
    property bool busy: false
    property string lastError: ""
    property string pendingPassword: ""

    property string password: ""
    property list<string> entries: []
    property string filter: ""

    property string selectedEntry: ""
    property bool reveal: false
    property string revealedPassword: ""
    property string generatedPassword: ""

    property int cacheTtl: 300 // default 5 min in seconds
    property int remainingTime: 0

    Timer {
        id: lockTimer
        interval: 1000
        repeat: true
        running: root.unlocked && root.remainingTime > 0
        onTriggered: {
            root.remainingTime--;
            if (root.remainingTime <= 0) {
                root.lock();
            }
        }
    }

    function resetSensitive() {
        password = ""
        unlocked = false
        entries = []
        selectedEntry = ""
        reveal = false
        revealedPassword = ""
        lastError = ""
    }

    function scanVaults() {
        scanProc.exec(["find", root.vaultDir, "-maxdepth", "1", "-name", "*.kdbx", "-type", "f"])
    }

    function selectVault(path) {
        if (vaultPath.length > 0 && path !== vaultPath) {
            lockProc.exec({
                environment: { KP_VAULT_PATH: root.vaultPath },
                command: [scriptPath, "lock"]
            })
        }
        vaultPath = path
        vaultExists = true
        resetSensitive()
    }

    function createVault(name, passwordValue) {
        if (!name || name.trim().length === 0) {
            lastError = Translation.tr("Missing vault name")
            return
        }
        if (!passwordValue || passwordValue.trim().length === 0) {
            lastError = Translation.tr("Missing password")
            return
        }
        const safeName = name.trim().replace(/[^a-zA-Z0-9_\-]/g, "_")
        const targetPath = root.vaultDir + "/" + safeName + ".kdbx"
        busy = true
        lastError = ""
        createProc.targetPath = targetPath
        createProc.exec({
            environment: { KP_VAULT_PATH: targetPath },
            command: [scriptPath, "create"]
        })
        createProc.write(passwordValue + "\n")
    }

    function openList() {
        open = true
        addMode = false
        scanVaults()
    }

    function openAdd() {
        open = true
        addMode = true
        scanVaults()
    }

    function close() {
        open = false
        addMode = false
        pendingPassword = ""
        // Don't resetSensitive here, let it stay unlocked in background
    }

    function openAddWithSelection() {
        if (root.open && addMode) {
            close()
            return
        }
        selectionProc.exec(["wl-paste"])
    }

    function lock() {
        lockProc.exec({
            environment: { KP_VAULT_PATH: root.vaultPath },
            command: [scriptPath, "lock"]
        })
        root.remainingTime = 0
        resetSensitive()
    }

    function envFor() {
        return {
            KP_VAULT_PATH: root.vaultPath,
            KP_NONINTERACTIVE: "1"
        }
    }

    function unlock(passwordValue) {
        if (!passwordValue || passwordValue.trim().length === 0) {
            lastError = Translation.tr("Missing password")
            return
        }
        password = passwordValue
        refreshEntries()
    }

    function refreshEntries() {
        busy = true
        listProc.buffer = []
        listProc.exec({
            environment: envFor(),
            command: [scriptPath, "ls", "-R", "-f"]
        })
    }

    function filteredEntries(query) {
        const q = (query ?? "").trim().toLowerCase()
        if (q.length === 0) return entries
        return entries.filter(e => e.toLowerCase().includes(q))
    }

    function openEntry(entry) {
        selectedEntry = entry
        reveal = false
        revealedPassword = ""
    }

    function showPassword() {
        if (!selectedEntry) return
        getProc.exec({
            environment: envFor(),
            command: [scriptPath, "get", selectedEntry, "password"]
        })
    }

    function copyPassword() {
        if (!selectedEntry) return
        copyGetProc.exec({
            environment: envFor(),
            command: [scriptPath, "get", selectedEntry, "password"]
        })
    }

    function copyUsername() {
        if (!selectedEntry) return
        copyUsernameProc.exec({
            environment: envFor(),
            command: [scriptPath, "get", selectedEntry, "username"]
        })
    }

    function generate(length, useUpper, useNumbers, useSymbols, useWords) {
        genProc.exec({
            environment: {
                KP_GEN_LENGTH:    length.toString(),
                KP_GEN_UPPER:     useUpper   ? "1" : "0",
                KP_GEN_NUMBERS:   useNumbers ? "1" : "0",
                KP_GEN_SYMBOLS:   useSymbols ? "1" : "0",
                KP_GEN_WORDS:     useWords   ? "1" : "0",
                KP_GEN_WORDLIST:  Translation.tr("keepass_wordlist")
            },
            command: [scriptPath, "generate"]
        })
    }

    function addEntry(entry, entryPassword, username, url) {
        if (!entry || entry.trim().length === 0 || !entryPassword) {
            lastError = Translation.tr("Missing entry name or password")
            return
        }
        addProc.entryPassword = entryPassword
        addProc.exec({
            environment: envFor(),
            command: [scriptPath, "add", entry, username ?? "", url ?? ""]
        })
    }

    Component.onCompleted: availabilityProc.exec(["sh", "-c", "command -v keepassxc-cli >/dev/null 2>&1"])

    // ── Processes ────────────────────────────────────────────────────────────

    Process {
        id: availabilityProc
        onExited: (exitCode) => { root.available = (exitCode === 0) }
    }

    Process {
        id: scanProc
        property list<string> buffer: []
        stdout: SplitParser {
            onRead: (line) => { if (line.trim().length > 0) scanProc.buffer.push(line.trim()) }
        }
        onStarted: scanProc.buffer = []
        onExited: {
            root.availableVaults = scanProc.buffer
            root.vaultExists = root.availableVaults.includes(root.vaultPath)
            if (root.vaultExists && root.open) root.refreshEntries()
        }
    }

    Process {
        id: createProc
        property string targetPath: ""
        stdinEnabled: true
        stderr: StdioCollector { id: createErr }
        onExited: (exitCode) => {
            busy = false
            if (exitCode === 0) {
                root.vaultPath = createProc.targetPath
                root.vaultExists = true
                root.availableVaults = [...root.availableVaults, createProc.targetPath]
                root.lastError = ""
                root.refreshEntries()
            } else {
                const err = createErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Failed to create vault")
            }
        }
    }

    Process { id: lockProc }

    Timer {
        id: autoCloseTimer
        interval: 400
        repeat: false
        onTriggered: root.close()
    }

    Process {
        id: listProc
        property list<string> buffer: []
        stdinEnabled: true
        onRunningChanged: {
            if (running && root.password.length > 0) {
                write(root.password + "\n")
            }
        }
        stdout: SplitParser {
            onRead: (line) => {
                if (line && line.trim().length > 0)
                    listProc.buffer.push(line)
            }
        }
        stderr: StdioCollector { id: listErr }
        onExited: (exitCode) => {
            busy = false
            if (exitCode === 0) {
                root.entries = listProc.buffer
                
                // If root.password is set, it means we just performed a fresh unlock
                if (root.password.length > 0) {
                    root.remainingTime = root.cacheTtl
                }
                
                root.unlocked = true
                root.lastError = ""
                root.password = ""
            } else {
                root.entries = []
                root.unlocked = false
                const err = listErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Unlock failed")
            }
        }
    }

    Process {
        id: getProc
        stdinEnabled: true
        onRunningChanged: {
            if (running && root.password.length > 0) {
                write(root.password + "\n")
            }
        }
        stdout: StdioCollector {
            id: passwordCollector
            onStreamFinished: {
                const pwd = passwordCollector.text.replace(/\n+$/, "")
                root.revealedPassword = pwd
                root.reveal = true
                root.lastError = ""
            }
        }
        stderr: StdioCollector { id: getErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                const err = getErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Failed to read password")
                root.unlocked = false
            }
        }
    }

    Timer {
        id: cliphistCleanupTimer
        interval: 150
        repeat: false
        onTriggered: cliphistCleanupProc.exec(["bash", "-c", "cliphist list | head -n 1 | cliphist delete"])
    }

    Process { id: cliphistCleanupProc }

    Process {
        id: copyGetProc
        stdinEnabled: true
        onRunningChanged: {
            if (running && root.password.length > 0) {
                write(root.password + "\n")
            }
        }
        stdout: StdioCollector {
            id: copyCollector
            onStreamFinished: {
                const value = copyCollector.text.replace(/\n+$/, "")
                if (value.length > 0) {
                    Quickshell.clipboardText = value
                    root.lastError = ""
                    cliphistCleanupTimer.restart()
                    autoCloseTimer.restart()
                }
            }
        }
        stderr: StdioCollector { id: copyErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                const err = copyErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Failed to copy password")
                root.unlocked = false
            }
        }
    }

    Process {
        id: copyUsernameProc
        stdinEnabled: true
        onRunningChanged: {
            if (running && root.password.length > 0) {
                write(root.password + "\n")
            }
        }
        stdout: StdioCollector {
            id: copyUsernameCollector
            onStreamFinished: {
                const value = copyUsernameCollector.text.replace(/\n+$/, "")
                if (value.length > 0) {
                    Quickshell.clipboardText = value
                    root.lastError = ""
                    autoCloseTimer.restart()
                }
            }
        }
        stderr: StdioCollector { id: copyUserErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                const err = copyUserErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Failed to copy username")
                root.unlocked = false
            }
        }
    }

    Process {
        id: addProc
        property string entryPassword: ""
        stdinEnabled: true
        onRunningChanged: {
            if (running) {
                const payload = root.password.length > 0
                    ? root.password + "\n" + addProc.entryPassword + "\n"
                    : addProc.entryPassword + "\n"
                write(payload)
            }
        }
        stderr: StdioCollector { id: addErr }
        onExited: (exitCode) => {
            addProc.entryPassword = ""
            if (exitCode === 0) {
                root.lastError = ""
                root.refreshEntries()
            } else {
                const err = addErr.text.trim()
                root.lastError = err.length > 0 ? err.replace("quickshell-keepass: ", "") : Translation.tr("Failed to add entry")
                root.unlocked = false
            }
        }
    }

    Process {
        id: genProc
        stdout: StdioCollector {
            id: genCollector
            onStreamFinished: root.generatedPassword = genCollector.text.replace(/\n+$/, "")
        }
    }

    Process {
        id: selectionProc
        stdout: StdioCollector {
            id: selectionCollector
            onStreamFinished: root.pendingPassword = selectionCollector.text.replace(/\n+$/, "").trim()
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) root.pendingPassword = ""
            root.open = true
            root.addMode = true
            root.resetSensitive()
            root.refreshEntries()
        }
    }

    // ── IPC ──────────────────────────────────────────────────────────────────

    IpcHandler {
        target: "keepass"

        function toggle(): void {
            if (root.open) {
                root.close()
            } else {
                root.openList()
            }
        }

        function add(): void {
            root.openAddWithSelection()
        }
    }
}
