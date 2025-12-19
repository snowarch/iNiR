pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool hasRun: false
    property bool _systemdUnitsRefreshRequested: false
    readonly property bool globalEnabled: Config.options?.autostart?.enable ?? false

    readonly property var entries: (Config.options?.autostart && Config.options?.autostart?.entries)
        ? Config.options.autostart.entries
        : []

    property var systemdUnits: []

    function load() {
        if (hasRun)
            return;

        hasRun = true;

        if (Config.ready) {
            startFromConfig();
        }
    }

    function startFromConfig() {
        if (!globalEnabled)
            return;

        const cfg = Config.options?.autostart;
        if (!cfg || !cfg.entries)
            return;

        for (let i = 0; i < cfg.entries.length; ++i) {
            const entry = cfg.entries[i];
            if (!entry || entry.enabled !== true)
                continue;
            startEntry(entry);
        }
    }

    function startEntry(entry) {
        if (!entry)
            return;

        if (entry.type === "desktop" && entry.desktopId) {
            startDesktop(entry.desktopId);
        } else if (entry.type === "command" && entry.command) {
            startCommand(entry.command);
        }
    }

    // Desktop autostart launches are serialized to avoid races caused by reusing one Process
    // instance (desktopId/command being overwritten while it is running).
    property var _pendingDesktopLaunches: []

    function _enqueueDesktopLaunch(desktopId: string): void {
        root._pendingDesktopLaunches.push(desktopId)
        root._startNextDesktopLaunch()
    }

    function _startNextDesktopLaunch(): void {
        if (startDesktopProc.running)
            return
        if (root._pendingDesktopLaunches.length === 0)
            return

        const next = String(root._pendingDesktopLaunches[0] || "").trim()
        if (next.length === 0) {
            root._pendingDesktopLaunches.shift()
            root._startNextDesktopLaunch()
            return
        }

        startDesktopProc.start(next)
    }

    function startDesktop(desktopId) {
        if (!desktopId)
            return;

        const id = String(desktopId).trim();
        if (id.length === 0)
            return;

        root._enqueueDesktopLaunch(id)
    }

    Process {
        id: startDesktopProc
        property string desktopId: ""

        function start(desktopId: string): void {
            this.desktopId = desktopId
            exec(["gtk-launch", this.desktopId])
        }

        onExited: (exitCode, exitStatus) => {
            const id = startDesktopProc.desktopId
            if (exitCode !== 0 && id.length > 0) {
                console.warn("[Autostart] gtk-launch failed for", id, "exit", exitCode, exitStatus)
                // Best-effort fallback: try executing the id directly.
                Quickshell.execDetached([id])
            }

            startDesktopProc.desktopId = ""

            if (root._pendingDesktopLaunches.length > 0)
                root._pendingDesktopLaunches.shift()
            root._startNextDesktopLaunch()
        }
    }

    function startCommand(command) {
        if (!command)
            return;

        const cmd = String(command).trim();
        if (cmd.length === 0)
            return;

        Quickshell.execDetached(["bash", "-lc", cmd]);
    }

    Process {
        id: systemdListProc
        property var buffer: []
        command: [
            "bash", "-lc",
            "dir=\"$HOME/.config/systemd/user\"; "
            + "[ -d \"$dir\" ] || exit 0; "
            + "for f in \"$dir\"/*.service; do "
            + "[ -e \"$f\" ] || continue; "
            + "name=$(basename \"$f\"); "
            + "enabled=$(systemctl --user is-enabled \"$name\" 2>/dev/null || echo disabled); "
            + "desc=$(grep -m1 '^Description=' \"$f\" | cut -d= -f2-); "
            + "wanted=$(grep -m1 '^WantedBy=' \"$f\" | cut -d= -f2-); "
            + "after=$(grep -m1 '^After=' \"$f\" | cut -d= -f2-); "
            + "desc=${desc//|/ }; wanted=${wanted//|/ }; kind=session; "
            + "printf '%s\n' \"$wanted\" \"$after\" | grep -q 'tray-apps.target' && kind=tray; "
            + "ii_managed=no; "
            + "grep -q '^# ii-autostart' \"$f\" 2>/dev/null && ii_managed=yes; "
            + "echo \"$name|$enabled|$kind|$desc|$wanted|$ii_managed\"; "
            + "done"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                systemdListProc.buffer.push(line)
            }
        }
        onExited: (exitCode, exitStatus) => {
            const units = []
            if (exitCode !== 0) {
                console.log("[Autostart] systemdListProc exited with", exitCode, exitStatus)
                root.systemdUnits = units
                systemdListProc.buffer = []
                return;
            }

            for (let i = 0; i < systemdListProc.buffer.length; ++i) {
                const raw = systemdListProc.buffer[i].trim()
                if (raw.length === 0)
                    continue;
                const parts = raw.split("|")
                if (parts.length < 6)
                    continue;
                const name = parts[0]
                const state = parts[1]
                const kind = parts[2]
                const desc = parts.length > 3 ? parts[3] : ""
                const wanted = parts.length > 4 ? parts[4] : ""
                const enabled = state.indexOf("enabled") !== -1
                const isTray = kind === "tray"
                const iiManaged = parts[5] === "yes"
                units.push({
                    name: name,
                    state: state,
                    description: desc,
                    enabled: enabled,
                    isTray: isTray,
                    iiManaged: iiManaged
                })
            }
            console.log("[Autostart] Loaded", units.length, "user systemd services")
            root.systemdUnits = units
            systemdListProc.buffer = []
        }
    }

    function refreshSystemdUnits() {
        systemdListProc.buffer = []
        systemdListProc.running = true
    }

    function requestRefreshSystemdUnits(): void {
        root._systemdUnitsRefreshRequested = true
        refreshTimer.restart()
    }

    Timer {
        id: refreshTimer
        interval: 1200
        repeat: false
        onTriggered: {
            if (!root._systemdUnitsRefreshRequested)
                return;
            if (!(Config.ready ?? false))
                return;
            root._systemdUnitsRefreshRequested = false
            root.refreshSystemdUnits()
        }
    }

    Process {
        id: systemdToggleProc
        function toggle(name, enabled) {
            if (!name || name.length === 0)
                return;
            const op = enabled ? "enable" : "disable"
            console.log("[Autostart] Toggling user service", name, "->", enabled ? "enabled" : "disabled")
            exec(["systemctl", "--user", op, "--now", name])
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[Autostart] systemdToggleProc exited with", exitCode, exitStatus)
            refreshSystemdUnits()
        }
    }

    // Creating a user systemd unit needs two ordering guarantees:
    // 1) the destination directory exists
    // 2) the file is written before we run `systemctl --user daemon-reload && enable --now`
    //
    // Using Quickshell.execDetached(["mkdir", ...]) + FileView.setText() can race.
    // Instead, do mkdir + write through a Process and only activate after it exits.

    property var _pendingServiceWrites: []

    function _enqueueServiceWrite(dir: string, filePath: string, text: string, unitName: string): void {
        root._pendingServiceWrites.push({ dir, filePath, text, unitName })
        root._startNextServiceWrite()
    }

    function _startNextServiceWrite(): void {
        if (serviceWriteProc.running) return
        if (root._pendingServiceWrites.length === 0) return

        const next = root._pendingServiceWrites[0]
        if (!next?.dir || !next?.filePath) {
            console.warn("[Autostart] Invalid pending service write:", JSON.stringify(next))
            root._pendingServiceWrites.shift()
            root._startNextServiceWrite()
            return
        }

        serviceWriteProc.start(next.dir, next.filePath, next.text, next.unitName)
    }

    Process {
        id: serviceWriteProc

        property string dir: ""
        property string filePath: ""
        property string text: ""
        property string unitName: ""

        stdinEnabled: true

        function start(dir: string, filePath: string, text: string, unitName: string): void {
            this.dir = dir
            this.filePath = filePath
            this.text = text
            this.unitName = unitName

            const dirEsc = StringUtils.shellSingleQuoteEscape(dir)
            const fileEsc = StringUtils.shellSingleQuoteEscape(filePath)

            // cat reads unit file contents from stdin.
            exec(["bash", "-lc", `mkdir -p '${dirEsc}' && cat > '${fileEsc}'`])
        }

        onRunningChanged: {
            if (serviceWriteProc.running) {
                serviceWriteProc.write(serviceWriteProc.text)
                // Close stdin so `cat` can exit.
                serviceWriteProc.stdinEnabled = false
            } else {
                serviceWriteProc.stdinEnabled = true
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[Autostart] Failed to write user service file", filePath, "exit", exitCode, exitStatus)
            } else if (unitName && unitName.length > 0) {
                console.log("[Autostart] Wrote user service file", filePath, "-> activating", unitName)
                systemdCreateProc.activate(unitName)
            }

            // Clear state
            dir = ""
            filePath = ""
            text = ""
            unitName = ""

            // Advance queue
            if (root._pendingServiceWrites.length > 0)
                root._pendingServiceWrites.shift()
            root._startNextServiceWrite()
        }
    }

    Process {
        id: systemdCreateProc
        function activate(unitName) {
            if (!unitName || unitName.length === 0)
                return;
            console.log("[Autostart] Activating new user service", unitName)
            const escaped = StringUtils.shellSingleQuoteEscape(unitName)
            exec(["bash", "-lc", "systemctl --user daemon-reload && systemctl --user enable --now '" + escaped + "' 2>/dev/null || true"])
        }
        onExited: (exitCode, exitStatus) => {
            console.log("[Autostart] systemdCreateProc exited with", exitCode, exitStatus)
            refreshSystemdUnits()
        }
    }

    // User systemd unit deletion
    //
    // Goals:
    // - No `bash -lc` string concatenation for unit names/paths (avoid injection / quoting bugs).
    // - Only delete units we created (marker line `# ii-autostart`).
    // - Serialize delete operations to avoid overlapping `systemctl --user ...` calls.
    property var _pendingServiceDeletes: []

    function _enqueueServiceDelete(unitName: string): void {
        root._pendingServiceDeletes.push(unitName)
        root._startNextServiceDelete()
    }

    function _startNextServiceDelete(): void {
        if (systemdDeleteProc.running)
            return
        if (root._pendingServiceDeletes.length === 0)
            return

        const next = root._pendingServiceDeletes[0]
        const unitName = String(next || "").trim()
        if (unitName.length === 0) {
            root._pendingServiceDeletes.shift()
            root._startNextServiceDelete()
            return
        }

        // Safety: don't allow paths here (only unit filenames).
        if (unitName.indexOf("/") !== -1 || unitName.indexOf("\\") !== -1) {
            console.warn("[Autostart] Refusing to delete suspicious unit name:", unitName)
            root._pendingServiceDeletes.shift()
            root._startNextServiceDelete()
            return
        }

        systemdDeleteProc.start(unitName)
    }

    Process {
        id: systemdDeleteProc

        // Phases: disable -> checkMarker -> rm -> reload
        //
        // Notes:
        // - `disable` is best-effort (may fail if unit doesn't exist or isn't enabled).
        // - `checkMarker` uses grep exit code to decide whether the unit is ii-managed.
        // - `reload` runs regardless (even if we didn't delete a file) so systemd forgets removed units.
        property string _phase: ""
        property string _unitName: ""
        property string _unitPath: ""

        readonly property string _unitDir: FileUtils.trimFileProtocol(Directories.home) + "/.config/systemd/user"

        function start(unitName: string): void {
            _unitName = unitName
            _unitPath = _unitDir + "/" + unitName

            console.log("[Autostart] Deleting user service", _unitName)

            _phase = "disable"
            exec(["systemctl", "--user", "disable", "--now", _unitName])
        }

        onExited: (exitCode, exitStatus) => {
            // Disable may fail if service isn't enabled/running; proceed regardless.
            if (_phase === "disable") {
                _phase = "checkMarker"
                exec(["grep", "-q", "^# ii-autostart", _unitPath])
                return
            }

            // grep exit code: 0 = found, 1 = not found, 2 = error
            if (_phase === "checkMarker") {
                if (exitCode === 0) {
                    _phase = "rm"
                    exec(["rm", "-f", _unitPath])
                } else {
                    _phase = "reload"
                    exec(["systemctl", "--user", "daemon-reload"])
                }
                return
            }

            if (_phase === "rm") {
                _phase = "reload"
                exec(["systemctl", "--user", "daemon-reload"])
                return
            }

            if (_phase === "reload") {
                console.log("[Autostart] systemdDeleteProc finished", _unitName)

                // Clear state
                _phase = ""
                _unitName = ""
                _unitPath = ""

                // Advance queue
                if (root._pendingServiceDeletes.length > 0)
                    root._pendingServiceDeletes.shift()

                refreshSystemdUnits()
                root._startNextServiceDelete()
            }
        }
    }

    function setServiceEnabled(name, enabled) {
        systemdToggleProc.toggle(name, enabled)
    }

    function createUserService(name, description, command, kind) {
        if (!name)
            return;
        const trimmedName = String(name).trim()
        if (trimmedName.length === 0)
            return;
        const exec = String(command || "").trim()
        if (exec.length === 0)
            return;
        const safeName = trimmedName.replace(/\s+/g, "-")
        const unitName = safeName + ".service"
        const desc = String(description || safeName)
        const isTray = kind === "tray"
        const afterTarget = isTray ? "tray-apps.target" : "graphical-session.target"
        const wantedByTarget = isTray ? "tray-apps.target" : "graphical-session.target"

        // Build path using XDG home directory and trim any file:// prefix to get a real filesystem path
        const homePath = FileUtils.trimFileProtocol(Directories.home)
        const dir = `${homePath}/.config/systemd/user`
        const filePath = `${dir}/${safeName}.service`

        const text = "# ii-autostart\n"
            + "[Unit]\n"
            + "Description=" + desc + "\n"
            + "After=" + afterTarget + "\n"
            + "\n"
            + "[Service]\n"
            + "Type=simple\n"
            + "ExecStart=" + exec + "\n"
            + "Restart=on-failure\n"
            + "RestartSec=3\n"
            + "\n"
            + "[Install]\n"
            + "WantedBy=" + wantedByTarget + "\n"

        root._enqueueServiceWrite(dir, filePath, text, unitName)
    }

    function deleteUserService(name) {
        if (!name || name.length === 0)
            return;
        root._enqueueServiceDelete(String(name).trim())
    }

    Component.onCompleted: {
        load()
        // Defer systemd scanning to keep shell startup smooth.
        root.requestRefreshSystemdUnits()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && !root.hasRun) {
                root.startFromConfig();
                root.hasRun = true;
            }
            if (Config.ready) {
                root.requestRefreshSystemdUnits()
            }
        }
    }
}
