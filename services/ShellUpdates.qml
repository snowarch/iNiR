pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

/*
 * iNiR shell update checker service.
 * Periodically checks the git repo for new commits and exposes
 * update state to UI widgets. Separate from system Updates service.
 *
 * NOTE: The config directory (~/.config/quickshell/ii) is NOT a git repo.
 * Users clone the repo elsewhere, run ./setup install, which copies files.
 * The actual repo location is stored in version.json during installation.
 */
Singleton {
    IpcHandler {
        target: "shellUpdate"
        function toggle(): void { root.overlayOpen ? root.closeOverlay() : root.openOverlay() }
        function open(): void { root.openOverlay() }
        function close(): void { root.closeOverlay() }
        function check(): void { root.check() }
        function performUpdate(): void { root.performUpdate() }
        function dismiss(): void { root.dismiss() }
        function undismiss(): void { root.undismiss() }
        function diagnose(): string { return root.getDiagnostics() }
        function simulate(state: string): string { return root.simulate(state) }
    }
    id: root

    // A fake pending update for checking every surface that shows one; git, config and setup stay untouched.
    property bool simulated: false
    function simulate(state: string): string {
        if (state === "off") {
            if (!root.simulated) return "off"
            root.simulated = false
            root.commitLog = ""
            root.hasUpdate = false
            root.commitsBehind = 0
            root.isUpdating = false
            root.check()
            return "off"
        }
        if (state !== "on" && state !== "") return "Use on or off"
        if (state === "on") {
            root.simulated = true
            root.isUpdating = false
            root.repoRelation = "behind"
            root.commitsBehind = 3
            root.remoteCommit = "simulated"
            root.remoteVersion = root.localVersion.length > 0 ? root.localVersion + "+1" : ""
            root.commitLog = ["a1b2c3d|feat(iris): a pending update to look at|1 hour ago|iNiR",
                "e4f5a6b|fix(bar): a fix that comes with it|2 hours ago|iNiR",
                "c7d8e9f|chore: one more commit|3 hours ago|iNiR"].join("\n")
            root.latestMessage = "a1b2c3d feat(iris): a pending update to look at"
            root.hasUpdate = true
        }
        return root.simulated ? "on: " + root.commitsBehind + " commits behind" : "off"
    }

    // Public state
    property bool hasUpdate: false
    property int commitsBehind: 0
    property int commitsAhead: 0
    property string repoRelation: "unknown" // current | behind | ahead | diverged | unknown
    readonly property bool repoDiverged: repoRelation === "diverged"
    property string latestMessage: ""
    property string localCommit: ""
    property string remoteCommit: ""
    property string currentBranch: "main"  // Current git branch
    property string _remoteBranch: "main"  // Resolved remote branch (may differ from currentBranch if not pushed)
    readonly property bool isNonMainBranch: currentBranch.length > 0 && currentBranch !== "main" && currentBranch !== "master"
    property bool isChecking: false
    property bool isUpdating: false
    property string lastError: ""
    property bool available: false  // git is available and repo exists

    // Update progress tracking (populated from status file markers)
    property int updateStep: 0           // Current step (1-based, 0 = not started / unknown)
    property int updateTotalSteps: 0     // Total steps reported by setup
    property string updateStepMessage: "" // Human-readable step label
    property string _lastWatchdogStatus: "" // Staleness detection for watchdog

    function clearUpdateProgressUi(): void {
        updateProgressPoller.running = false
        updateWatchdog.stop()
        root.isUpdating = false
        root.updateStep = 0
        root.updateTotalSteps = 0
        root.updateStepMessage = ""
        root._lastWatchdogStatus = ""
    }

    function updateFailureMessage(status: string, previous: bool): string {
        const parts = status.split(":")
        const code = parts.length > 1 ? parts[1] : "unknown"
        const detail = parts.length > 2 ? parts.slice(2).join(":").trim() : ""
        const lead = previous ? "Last update failed" : "Update failed"
        return detail.length > 0
            ? detail + ". Check " + Directories.updateLogPath + " for details."
            : lead + " (exit " + code + "). Check " + Directories.updateLogPath + " for details."
    }

    function handleFailedUpdateStatus(status: string, previous: bool): void {
        const parts = status.split(":")
        const code = parts.length > 1 ? parts[1] : "unknown"
        root.clearUpdateProgressUi()
        root.lastError = root.updateFailureMessage(status, previous)
        clearStatusFileProc.running = true
        print("[ShellUpdates] Update FAILED with exit code " + code + (previous ? " (resume)" : ""))
    }

    // Notification tracking (prevent spam)
    property bool initialAvailabilityChecked: false
    property bool initialUpdateCheckDone: false
    property bool unavailableNotificationShown: false
    property int consecutiveFetchErrors: 0
    property bool fetchErrorNotificationShown: false

    // Overlay state
    property bool overlayOpen: false
    property bool isFetchingDetails: false
    property string commitLog: ""         // Full git log HEAD..origin/branch
    property string remoteChangelog: ""   // CHANGELOG.md from remote branch
    property string remoteVersion: ""     // VERSION from remote branch
    property string localVersion: ""      // Current local VERSION
    property var localModifications: []   // Files user modified vs manifest

    // Current system info (always available after first check)
    property string installedCommit: ""   // Commit hash from manifest
    property string installedDate: ""     // Install/update date from manifest
    property string recentLocalLog: ""    // Recent local commit history
    property int _openOverlayDelayMs: 0

    // Derived
    readonly property bool enabled: Config.options?.shellUpdates?.enabled ?? true
    readonly property int checkIntervalMs: (Config.options?.shellUpdates?.checkIntervalMinutes ?? 360) * 60 * 1000
    readonly property string dismissedCommit: Config.options?.shellUpdates?.dismissedCommit ?? ""
    readonly property string lastNotifiedCommit: Config.options?.shellUpdates?.lastNotifiedCommit ?? ""
    readonly property int remindDays: Math.max(0, Number(Config.options?.shellUpdates?.remindDays ?? 3))
    readonly property real lastNotifiedAt: Number(Config.options?.shellUpdates?.lastNotifiedAt ?? 0)
    readonly property bool showUpdate: hasUpdate && !isDismissed && !isUpdating
    readonly property real dismissedAt: Number(Config.options?.shellUpdates?.dismissedAt ?? 0)
    // Not now hides that version until `remindDays` have passed, then it shows again; 0 keeps it hidden.
    property real _clock: Date.now()
    readonly property bool isDismissed: dismissedCommit.length > 0 && remoteCommit === dismissedCommit
        && !(root.remindDays > 0 && root.dismissedAt > 0 && root._clock - root.dismissedAt >= root.remindDays * 86400000)

    // Repo path - try to get from version.json, fallback to config dir
    readonly property string configDir: FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    property string repoPath: configDir  // Will be updated after reading version.json
    property string pendingRepoPath: ""
    property bool repoPathLoaded: false
    readonly property string manifestPath: configDir + "/.inir-manifest"
    property string installMode: "unknown"
    property string updateStrategy: "unknown"
    property string installSource: "unknown"
    readonly property bool managedExternally: updateStrategy === "package-manager"
    readonly property bool selfUpdateSupported: updateStrategy === "repo-setup"
    readonly property string unavailableTitle: managedExternally
        ? "Updates Managed Externally"
        : "Updates Unavailable"
    readonly property string unavailableMessage: managedExternally
        ? "This iNiR installation is managed outside the runtime copy. Use your package manager or installation workflow to update it."
        : "Repository not found. The update system cannot locate the iNiR git repository."
    readonly property string unavailableHint: managedExternally
        ? "Runtime diagnostics are still available, but in-shell self-update is disabled for this installation mode."
        : "Run './setup doctor' in your terminal to diagnose the issue, or use the diagnose command below."

    // Handler: notify when availability changes to false (after initial check)
    onAvailableChanged: {
        if (initialAvailabilityChecked && !available && !unavailableNotificationShown && !managedExternally) {
            unavailableNotificationShown = true
            Notifications.send(root.unavailableTitle, root.unavailableHint, "normal", 10000)
            print("[ShellUpdates] Notification sent: Updates unavailable")
        }
        // Reset notification flag when available becomes true again
        if (available) {
            unavailableNotificationShown = false
        }
    }

    // Handler: notify when a new update is detected
    onHasUpdateChanged: root.maybeNotifyUpdate()

    // Raised once per upstream commit, then again every `remindDays` while it is still
    // pending, so an update that is never applied does not go quiet forever.
    function maybeNotifyUpdate(): void {
        if (!hasUpdate || !available || !initialUpdateCheckDone || isDismissed) return
        if (remoteCommit.length === 0) return
        if (root.simulated) {
            root.postUpdateNotice("iNiR Update Available (simulated)", "3 commits behind.")
            return
        }
        const now = Date.now()
        if (remoteCommit === lastNotifiedCommit) {
            if (root.remindDays <= 0 || root.lastNotifiedAt <= 0) return
            if (now - root.lastNotifiedAt < root.remindDays * 86400000) return
        }

        const version = root.remoteVersion.length > 0 ? (" v" + root.remoteVersion) : ""
        const commits = root.repoDiverged
            ? "Repository history changed upstream. iNiR will preserve local work and recover clean published checkouts automatically."
            : (root.commitsBehind > 0 ? (root.commitsBehind + " commits behind") : "New version available")
        root.postUpdateNotice("iNiR Update Available" + version,
            commits + ". Run `inir update`, or open it from the shell's own updater.")
        Config.setNestedValues({
            "shellUpdates.lastNotifiedCommit": remoteCommit,
            "shellUpdates.lastNotifiedAt": now
        })
        print("[ShellUpdates] Notification sent: Update available" + version)
    }

    function postUpdateNotice(summary: string, body: string): void {
        updateNotice.running = false
        updateNotice.command = ["/usr/bin/notify-send", "-a", "iNiR", "-u", "normal", "-t", "15000", "-w",
            "-A", "open=" + Translation.tr("What changed"), "--", summary, body]
        updateNotice.running = true
    }

    Process {
        id: updateNotice
        stdout: StdioCollector {
            onStreamFinished: if ((text ?? "").trim() === "open") root.openOverlay()
        }
    }

    // A check that could not run for lack of internet; retried when the connection returns.
    property bool waitingForNetwork: false
    Connections {
        target: Network
        function onOnlineChanged() {
            if (Network.online && root.waitingForNetwork) root.check()
        }
    }

    function check(): void {
        if (!enabled || isChecking || isUpdating || managedExternally || simulated) return
        root._clock = Date.now()
        root.waitingForNetwork = !Network.online
        if (root.waitingForNetwork) return
        root.isChecking = true
        root.lastError = ""
        fetchProc.running = true
    }

    // Fetch detailed info for the overlay (commit log, changelog, local mods)
    function fetchDetails(): void {
        if (isFetchingDetails || managedExternally) return
        if (root.simulated) return
        root.isFetchingDetails = true
        root.commitLog = ""
        root.remoteChangelog = ""
        root.remoteVersion = ""
        root.localVersion = ""
        root.localModifications = []
        commitLogProc.running = true
    }

    function openOverlay(): void {
        const panels = Config.options?.enabledPanels ?? []
        if (!panels.includes("iiShellUpdate")) {
            Config.setNestedValue("enabledPanels", [...panels, "iiShellUpdate"])
        }
        const panelWasOpen = GlobalStates.controlPanelOpen
        const settingsWasOpen = GlobalStates.settingsOverlayOpen ?? false
        GlobalStates.controlPanelOpen = false
        GlobalStates.settingsOverlayOpen = false
        // Always use a minimum delay to ensure other overlays fully close
        // and release keyboard focus before we open
        root._openOverlayDelayMs = (panelWasOpen || settingsWasOpen) ? 600 : 150
        openOverlayTimer.restart()
    }

    Timer {
        id: openOverlayTimer
        interval: root._openOverlayDelayMs
        repeat: false
        onTriggered: {
            root.overlayOpen = true
            root.fetchDetails()
        }
    }

    function closeOverlay(): void {
        root.overlayOpen = false
    }

    function performUpdate(): void {
        if (isUpdating || !hasUpdate || !available || managedExternally) return
        if (root.simulated) {
            root.overlayOpen = false
            root.isUpdating = true
            simulatedUpdate.restart()
            if (Config.options?.shellUpdates?.openTerminalOnUpdate ?? true) {
                const slot = (AppLauncher && typeof AppLauncher.commandFor === "function") ? AppLauncher.commandFor("terminal") : ""
                ShellExec.execDetachedArgs([(slot.length > 0 ? slot : "kitty").trim().split(/\s+/)[0], "-e", "/usr/bin/bash", "-c",
                    "echo 'Simulated iNiR update: nothing is downloaded or changed.'; echo; "
                    + "for s in Fetching Applying 'Restarting the shell'; do echo \"==> $s\"; sleep 1; done; "
                    + "echo; echo 'All good. You can close this window whenever you want.'; read -r _"], "Update iNiR", root.repoPath)
            }
            return
        }
        root.isUpdating = true
        root.lastError = ""
        root.updateStep = 0
        root.updateTotalSteps = 0
        root.updateStepMessage = ""
        root._lastWatchdogStatus = ""
        root.overlayOpen = false
        Config.setNestedValue("shellUpdates.dismissedCommit", "")

        const logPath = Directories.updateLogPath
        const statusPath = Directories.updateStatusPath
        const repoDir = root.repoPath
        const useTerminal = Config.options?.shellUpdates?.openTerminalOnUpdate ?? true

        // Bash one-liner: writes the initial 'updating' marker, runs setup, captures
        // its exit code. Terminal mode mirrors output through tee with process
        // substitution instead of a pipeline, so `$?` always belongs to setup and
        // does not depend on PIPESTATUS surviving the terminal/scope launch path.
        // Detached mode redirects to the log file only.
        // Terminal always stays open with a summary so people can read what happened.
        const teeCmd = useTerminal
            ? "./setup -y update > >(tee '" + logPath + "') 2>&1; rc=$?"
            : "./setup -y -q update > '" + logPath + "' 2>&1; rc=$?"
        const preserveFailureStatus =
            "status=$(cat '" + statusPath + "' 2>/dev/null || true); " +
            "if (( rc != 0 )) && [[ $status != failed:* ]]; then echo \"failed:$rc\" > '" + statusPath + "'; fi; "
        const termTail =
            "echo; " +
            preserveFailureStatus +
            "if (( rc == 0 )); then " +
                "echo 'All good — iNiR updated successfully. The shell will restart on its own.'; " +
                "echo 'You can close this window whenever you want.'; " +
            "else " +
                "echo \"Something went wrong (exit $rc). Check the output above for details.\"; " +
                "echo 'You can close this window whenever you want.'; " +
            "fi; " +
            "read -r _"
        const detachedTail =
            preserveFailureStatus
        const tail = useTerminal ? termTail : detachedTail
        const bashCmd = "echo 'updating' > '" + statusPath + "'; " +
            "cd '" + repoDir + "' && " + teeCmd + "; " + tail

        if (useTerminal) {
            // First token of the configured terminal command (e.g. "kitty -1" -> "kitty").
            // Most supported terminals (foot, kitty, ghostty, alacritty, wezterm, konsole)
            // accept '-e' for "execute this command". WezTerm accepts it via its compat layer.
            const termSlot = (AppLauncher && typeof AppLauncher.commandFor === "function")
                ? AppLauncher.commandFor("terminal") : ""
            const termBin = (termSlot.length > 0 ? termSlot : "kitty").trim().split(/\s+/)[0]
            ShellExec.execDetachedArgs(
                [termBin, "-e", "/usr/bin/bash", "-c", bashCmd],
                "Update iNiR", repoDir)
            print("[ShellUpdates] Update launched in terminal (" + termBin + ") from: " + repoDir)
        } else {
            // Detached background — same path as before the terminal toggle existed.
            Quickshell.execDetached(["/usr/bin/bash", "-c", bashCmd])
            print("[ShellUpdates] Update launched (detached) from: " + repoDir)
        }
        print("[ShellUpdates] Log: " + logPath + " | Status: " + statusPath)
        // Start watchdog — if shell hasn't restarted after timeout, check status file
        updateWatchdog.restart()
        // Start progress poller — reads status file every 2s for live progress
        updateProgressPoller.restart()
    }

    Timer {
        id: simulatedUpdate
        interval: 4000
        onTriggered: root.simulate("off")
    }

    function dismiss(): void {
        if (root.simulated) { root.simulate("off"); return }
        if (remoteCommit.length > 0) {
            Config.setNestedValues({ "shellUpdates.dismissedCommit": remoteCommit, "shellUpdates.dismissedAt": Date.now() })
        }
        root.overlayOpen = false
    }

    function undismiss(): void {
        Config.setNestedValue("shellUpdates.dismissedCommit", "")
    }

    function getDiagnostics(): string {
        const diag = {
            available: root.available,
            repoPath: root.repoPath,
            repoPathLoaded: root.repoPathLoaded,
            configDir: root.configDir,
            versionJsonPath: Directories.shellConfig + "/version.json",
            installMode: root.installMode,
            updateStrategy: root.updateStrategy,
            installSource: root.installSource,
            selfUpdateSupported: root.selfUpdateSupported,
            gitAvailable: root.available,
            lastError: root.lastError,
            consecutiveFetchErrors: root.consecutiveFetchErrors,
            hasUpdate: root.hasUpdate,
            isDismissed: root.isDismissed,
            showUpdate: root.showUpdate,
            commitsBehind: root.commitsBehind,
            commitsAhead: root.commitsAhead,
            repoRelation: root.repoRelation,
            localCommit: root.localCommit,
            remoteCommit: root.remoteCommit,
            currentBranch: root.currentBranch,
            localVersion: root.localVersion,
            remoteVersion: root.remoteVersion,
            overlayOpen: root.overlayOpen,
            isFetchingDetails: root.isFetchingDetails
        }
        return JSON.stringify(diag, null, 2)
    }

    // Initial check after startup delay
    Timer {
        id: startupDelay
        interval: 5000  // 5s after shell starts (quick first check)
        repeat: false
        running: root.enabled && Config.ready
        onTriggered: {
            print("[ShellUpdates] Loading repo path from version.json...")
            loadRepoPathProc.running = true
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Resume update display after shell restart
    // ─────────────────────────────────────────────────────────────────────────
    // `setup update` triggers `systemctl --user restart inir.service` as its
    // last step, killing the shell mid-flow. The new shell instance must
    // detect the prior state from the status file and either clean up
    // (if the final step was reached) or resume polling so the bar indicator
    // and overlay don't go silent while the update keeps running underneath.
    Timer {
        id: resumeUpdateCheck
        interval: 1000  // 1s — get the indicator back up fast
        repeat: false
        running: true
        onTriggered: updateResumeReader.running = true
    }

    Process {
        id: updateResumeReader
        running: false
        command: ["/usr/bin/bash", "-c", `
            status_file="$1"
            if [ ! -f "$status_file" ]; then exit 1; fi

            now=$(/usr/bin/date +%s)
            if read -r uptime _ < /proc/uptime; then
                uptime_s=$(/usr/bin/printf '%s\n' "$uptime" | /usr/bin/cut -d. -f1)
            else
                uptime_s=0
            fi
            boot_epoch=$((now - uptime_s))
            mtime=$(/usr/bin/stat -c %Y "$status_file" 2>/dev/null || echo 0)

            if [ "$mtime" -lt "$boot_epoch" ]; then
                echo "stale"
            else
                /usr/bin/cat "$status_file"
            fi
        `, "_", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                if (status.length === 0) return

                if (status === "stale") {
                    print("[ShellUpdates] Clearing stale update-status from previous boot")
                    clearStatusFileProc.running = true
                    return
                }

                if (status === "success") {
                    // Previous update finished cleanly — clear stale marker
                    clearStatusFileProc.running = true
                    return
                }

                if (status.startsWith("failed")) {
                    root.handleFailedUpdateStatus(status, true)
                    return
                }

                if (status.startsWith("progress:")) {
                    const parts = status.split(":")
                    const step = parts.length > 1 ? (parseInt(parts[1]) || 0) : 0
                    const total = parts.length > 2 ? (parseInt(parts[2]) || 0) : 0
                    const msg = parts.length > 3 ? parts.slice(3).join(":") : ""

                    // Final step reached — the restart we just survived was
                    // the last action. Mark complete and clear.
                    if (total > 0 && step >= total) {
                        print("[ShellUpdates] Resume detected final step (" + step + "/" + total + "), assuming complete: " + msg)
                        clearStatusFileProc.running = true
                        return
                    }

                    // Mid-flight update — restore visible state and keep polling
                    root.updateStep = step
                    root.updateTotalSteps = total
                    root.updateStepMessage = msg
                    root._lastWatchdogStatus = status
                    root.isUpdating = true
                    updateProgressPoller.restart()
                    updateWatchdog.restart()
                    print("[ShellUpdates] Resuming in-flight update display: " + status)
                    return
                }

                if (status === "updating") {
                    // Initial marker, no granular progress yet
                    root.isUpdating = true
                    updateProgressPoller.restart()
                    updateWatchdog.restart()
                    print("[ShellUpdates] Resuming update display (no granular progress yet)")
                    return
                }

                print("[ShellUpdates] Unknown status file content on resume: '" + status + "'")
            }
        }
    }

    Process {
        id: clearStatusFileProc
        running: false
        command: ["rm", "-f", Directories.updateStatusPath]
    }

    // Load repo path from version.json (stored in shellConfig dir, NOT in quickshell config dir)
    Process {
        id: loadRepoPathProc
        property bool _handledFallback: false
        running: false
        onRunningChanged: if (running) _handledFallback = false
        command: ["cat", Directories.shellConfig + "/version.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text ?? "{}")
                    // Extract version from version.json (always available even if VERSION file missing)
                    if (json.version && json.version !== "0.0.0") {
                        root.localVersion = json.version
                    }
                    const storedInstallMode = json.installMode ?? json.install_mode ?? ""
                    const storedUpdateStrategy = json.updateStrategy ?? json.update_strategy ?? ""
                    const storedSource = json.installSource ?? json.install_source ?? json.source ?? ""
                    if (storedInstallMode.length > 0) {
                        root.installMode = storedInstallMode
                    }
                    if (storedUpdateStrategy.length > 0) {
                        root.updateStrategy = storedUpdateStrategy
                    }
                    if (storedSource.length > 0) {
                        root.installSource = storedSource
                    }
                    const storedRepoPath = json.repoPath ?? json.repo_path ?? ""
                    if (storedRepoPath.length > 0 && root.installMode === "unknown") {
                        root.installMode = "repo-copy"
                    }
                    if (storedRepoPath.length > 0 && root.updateStrategy === "unknown") {
                        root.updateStrategy = "repo-setup"
                    }
                    if (root.managedExternally) {
                        root.repoPathLoaded = true
                        root.initialAvailabilityChecked = true
                        root.initialUpdateCheckDone = true
                        root.available = false
                        print("[ShellUpdates] Update strategy is managed externally: " + root.updateStrategy)
                        return
                    }
                    if (storedRepoPath.length > 0) {
                        root.pendingRepoPath = storedRepoPath
                        preferConfigRepoProc.running = true
                        return
                    }
                } catch (e) {
                    print("[ShellUpdates] Failed to parse version.json: " + e)
                }
                // No repo_path in version.json, try to find it
                print("[ShellUpdates] No repo_path in version.json, searching for repository...")
                loadRepoPathProc._handledFallback = true
                searchRepoProc.running = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !_handledFallback) {
                print("[ShellUpdates] version.json not found, searching for repository...")
                searchRepoProc.running = true
            }
        }
    }

    Process {
        id: preferConfigRepoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "p='" + root.configDir + "'; [[ -d \"$p/.git\" && -f \"$p/setup\" && -f \"$p/shell.qml\" ]] && echo OK || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = ((text ?? "").trim() === "OK")
                if (ok) {
                    root.repoPath = root.configDir
                    root.installMode = "repo-link"
                    root.updateStrategy = "repo-setup"
                    root.repoPathLoaded = true
                    print("[ShellUpdates] Using active config checkout as repo path: " + root.repoPath)
                    persistRepoPathProc.running = true
                    availabilityProc.running = true
                } else if (root.pendingRepoPath.length > 0) {
                    root.repoPath = root.pendingRepoPath
                    root.pendingRepoPath = ""
                    print("[ShellUpdates] Using repo path from version.json: " + root.repoPath)
                    root.repoPathLoaded = true
                    validateRepoPathProc.running = true
                } else {
                    searchRepoProc.running = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (root.pendingRepoPath.length > 0) {
                    root.repoPath = root.pendingRepoPath
                    root.pendingRepoPath = ""
                    root.repoPathLoaded = true
                    validateRepoPathProc.running = true
                } else {
                    searchRepoProc.running = true
                }
            }
        }
    }

    Process {
        id: validateRepoPathProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "p='" + root.repoPath + "'; [[ -d \"$p/.git\" && -f \"$p/setup\" && -f \"$p/shell.qml\" ]] && echo OK || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ok = ((text ?? "").trim() === "OK")
                if (ok) {
                    availabilityProc.running = true
                } else {
                    print("[ShellUpdates] repo_path from version.json is invalid, searching for repository...")
                    searchRepoProc.running = true
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                print("[ShellUpdates] Failed to validate repo_path, searching for repository...")
                searchRepoProc.running = true
            }
        }
    }

    // Search for repository — check config dir (dev), then use `find` on common parent dirs
    Process {
        id: searchRepoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            // First check if config dir itself is a git repo (dev setup)
            "if [[ -d \"" + root.configDir + "/.git\" ]]; then echo \"" + root.configDir + "\"; exit 0; fi; " +
            // Search for a git repo containing setup + shell.qml (our repo signature)
            // Check common locations first, then broader search
            "for dir in ~/illogical-impulse ~/inir ~/iNiR " +
            "~/.local/src/illogical-impulse ~/.local/src/inir " +
            "~/Projects/illogical-impulse ~/Projects/inir " +
            "~/Downloads/illogical-impulse ~/Downloads/inir " +
            "~/src/illogical-impulse ~/src/inir; do " +
            "if [[ -d \"$dir/.git\" && -f \"$dir/setup\" && -f \"$dir/shell.qml\" ]]; then echo \"$dir\"; exit 0; fi; done; " +
            // Last resort: find in home (max depth 3, timeout 2s)
            "timeout 2 find \"$HOME\" -maxdepth 3 -name setup \\( -path '*/inir/setup' -o -path '*/illogical-impulse/setup' -o -path '*/ii/setup' \\) 2>/dev/null | while read -r f; do [[ -f \"$(dirname \"$f\")/shell.qml\" ]] && dirname \"$f\" && break; done; "
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const foundPath = (text ?? "").trim()
                if (foundPath.length > 0) {
                    root.repoPath = foundPath
                    if (root.installMode === "unknown") {
                        root.installMode = foundPath === root.configDir ? "repo-link" : "repo-copy"
                    }
                    if (root.updateStrategy === "unknown") {
                        root.updateStrategy = "repo-setup"
                    }
                    print("[ShellUpdates] Found repository at: " + root.repoPath)
                    // Persist found path to version.json to avoid repeated searches
                    persistRepoPathProc.running = true
                } else {
                    print("[ShellUpdates] Repository not found, using config dir: " + root.configDir)
                    print("[ShellUpdates] Update feature will not be available")
                }
                root.repoPathLoaded = true
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Now check git availability
            availabilityProc.running = true
        }
    }

    // Persist found repo path to version.json
    Process {
        id: persistRepoPathProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "vfile='" + Directories.shellConfig + "/version.json'; " +
            "if [[ -s \"$vfile\" ]] && command -v jq &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  jq --arg p '" + root.repoPath + "' --arg m '" + root.installMode + "' --arg u '" + root.updateStrategy + "' '.repo_path = $p | .repoPath = $p | .install_mode = $m | .installMode = $m | .update_strategy = $u | .updateStrategy = $u' \"$vfile\" > \"$tmp\" && mv \"$tmp\" \"$vfile\" && " +
            "  echo 'Updated'; " +
            "elif command -v python3 &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  python3 -c 'import json,sys; path=sys.argv[1]; repo=sys.argv[2]; " +
            "\ntry: data=json.load(open(path,\"r\",encoding=\"utf-8\"))" +
            "\nexcept Exception: data={}" +
            "\ndata[\"repo_path\"]=repo" +
            "\ndata[\"repoPath\"]=repo" +
            "\ndata[\"install_mode\"]=sys.argv[3]" +
            "\ndata[\"installMode\"]=sys.argv[3]" +
            "\ndata[\"update_strategy\"]=sys.argv[4]" +
            "\ndata[\"updateStrategy\"]=sys.argv[4]" +
            "\njson.dump(data, sys.stdout, ensure_ascii=False, indent=2)' \"$vfile\" '" + root.repoPath + "' '" + root.installMode + "' '" + root.updateStrategy + "' > \"$tmp\" " +
            "    && mv \"$tmp\" \"$vfile\" && echo 'Updated' || echo 'Skipped'; " +
            "else " +
            "  echo 'Skipped'; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = (text ?? "").trim()
                if (result === "Updated") {
                    print("[ShellUpdates] Persisted repo_path to version.json: " + root.repoPath)
                }
            }
        }
    }

    // Periodic check
    Timer {
        id: periodicCheck
        interval: root.checkIntervalMs
        repeat: true
        running: root.enabled && root.available && Config.ready
        onTriggered: root.check()
    }

    // Also check when config becomes ready (session restore)
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && root.enabled) {
                startupDelay.restart()
            }
        }
    }

    // Lightweight git command prefix — disables LFS filter and auto-gc to prevent
    // CPU spikes from global git-lfs config on repos with zero LFS objects.
    readonly property var _gitCmd: [
        "git",
        "-c", "filter.lfs.process=",
        "-c", "filter.lfs.required=false",
        "-c", "filter.lfs.smudge=",
        "-c", "filter.lfs.clean=",
        "-c", "gc.auto=0",
        "-C", root.repoPath
    ]

    // Step 1: Check if git is available
    Process {
        id: availabilityProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--git-dir"]
        onExited: (exitCode, exitStatus) => {
            if (root.managedExternally) {
                root.available = false
                root.initialAvailabilityChecked = true
                root.initialUpdateCheckDone = true
                return
            }
            root.available = (exitCode === 0)
            root.initialAvailabilityChecked = true
            print("[ShellUpdates] Git available: " + root.available)
            if (root.available) {
                // Load system info (manifest + local log) before checking for updates
                manifestInfoProc.running = true
            }
        }
    }

    // Step 1b: Parse manifest for installed commit and date
    Process {
        id: manifestInfoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "manifest='" + root.manifestPath + "'; " +
            "[[ -f \"$manifest\" ]] || exit 1; " +
            "head -3 \"$manifest\" | grep -E '^# (generated|commit):' | sed 's/^# //'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text ?? "").trim().split("\n")
                for (const line of lines) {
                    if (line.startsWith("generated: ")) {
                        root.installedDate = line.substring(11).trim()
                    } else if (line.startsWith("commit: ")) {
                        root.installedCommit = line.substring(8).trim()
                    }
                }
                print("[ShellUpdates] Manifest: commit=" + root.installedCommit + " date=" + root.installedDate)
            }
        }
        onExited: (exitCode, exitStatus) => {
            recentLocalLogProc.running = true
        }
    }

    // Step 1c: Get recent local commit history (last 15 commits)
    Process {
        id: recentLocalLogProc
        running: false
        command: [
            ...root._gitCmd, "log",
            "--pretty=format:%h|%s|%cr|%an",
            "-15"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recentLocalLog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            // Also read local VERSION on startup
            localVersionStartupProc.running = true
        }
    }

    // Step 1d: Read local VERSION on startup
    // Try repo path first (VERSION is there), fallback to config dir (dev setup)
    Process {
        id: localVersionStartupProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "cat '" + root.repoPath + "/VERSION' 2>/dev/null || cat '" + root.configDir + "/VERSION' 2>/dev/null || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const ver = (text ?? "").trim()
                // Only override if we got a better version than what version.json gave us
                if (ver.length > 0 && ver !== root.localVersion) {
                    root.localVersion = ver
                }
                print("[ShellUpdates] Local version: " + root.localVersion)
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.check()
        }
    }

    // Step 2: Fetch from remote
    Process {
        id: fetchProc
        running: false
        command: [...root._gitCmd, "fetch", "origin", "--quiet", "--no-tags"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                root.consecutiveFetchErrors++
                print("[ShellUpdates] Fetch failed (attempt " + root.consecutiveFetchErrors + ")")

                // Notify after 3 consecutive failures (persistent problem)
                if (root.consecutiveFetchErrors >= 3 && !root.fetchErrorNotificationShown) {
                    root.fetchErrorNotificationShown = true
                    const title = "iNiR Update Check Failed"
                    const body = "Cannot reach remote repository. Check your internet connection or run './setup doctor'."
                    Notifications.send(title, body, "low", 8000)
                    print("[ShellUpdates] Notification sent: Persistent fetch errors")
                }
                return
            }
            // Success - reset error counters
            root.consecutiveFetchErrors = 0
            root.fetchErrorNotificationShown = false
            currentBranchProc.running = true
        }
    }

    // Step 3: Get current branch
    Process {
        id: currentBranchProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--abbrev-ref", "HEAD"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentBranch = (text ?? "").trim()
                print("[ShellUpdates] Current branch: " + root.currentBranch)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            localCommitProc.running = true
        }
    }

    // Step 4: Get local commit
    Process {
        id: localCommitProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "HEAD"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            remoteCommitProc.running = true
        }
    }

    // Step 5: Get remote commit
    Process {
        id: remoteCommitProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "origin/" + root.currentBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Try origin/main as fallback (in case branch doesn't exist remotely)
                remoteCommitFallbackProc.running = true
                return
            }
            root._remoteBranch = root.currentBranch
            countCommitsProc.running = true
        }
    }

    // Step 5b: Fallback to origin/main
    Process {
        id: remoteCommitFallbackProc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "origin/main"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Try origin/master as last resort
                remoteCommitFallback2Proc.running = true
                return
            }
            root._remoteBranch = "main"
            countCommitsProc.running = true
        }
    }

    // Step 5c: Fallback to origin/master
    Process {
        id: remoteCommitFallback2Proc
        running: false
        command: [...root._gitCmd, "rev-parse", "--short", "origin/master"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.isChecking = false
                return
            }
            root._remoteBranch = "master"
            countCommitsProc.running = true
        }
    }

    // Step 6: Classify the graph in both directions. Counting only HEAD..remote
    // made a force-pushed branch look like an ordinary update even when the
    // checkout also had commits that disappeared from the rewritten remote.
    Process {
        id: countCommitsProc
        running: false
        command: [...root._gitCmd, "rev-list", "--left-right", "--count", "HEAD...origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = (text ?? "0 0").trim().split(/\s+/)
                const localOnly = parseInt(parts[0] ?? "0")
                const remoteOnly = parseInt(parts[1] ?? "0")
                root.commitsAhead = isNaN(localOnly) ? 0 : localOnly
                root.commitsBehind = isNaN(remoteOnly) ? 0 : remoteOnly
                root.repoRelation = root.commitsAhead > 0 && root.commitsBehind > 0 ? "diverged"
                    : root.commitsAhead > 0 ? "ahead"
                    : root.commitsBehind > 0 ? "behind"
                    : "current"
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Fallback: compare commits directly
                root.hasUpdate = root.localCommit !== root.remoteCommit && root.remoteCommit.length > 0
                root.commitsBehind = root.hasUpdate ? 1 : 0
                root.commitsAhead = 0
                root.repoRelation = "unknown"
                root.isChecking = false
                root.initialUpdateCheckDone = true
                root.maybeNotifyUpdate()
                return
            }
            root.hasUpdate = root.commitsBehind > 0
            print("[ShellUpdates] Repo relation: " + root.repoRelation
                + " (ahead=" + root.commitsAhead + ", behind=" + root.commitsBehind + "), hasUpdate: " + root.hasUpdate)
            if (root.hasUpdate) {
                latestMessageProc.running = true
            } else {
                root.isChecking = false
                root.initialUpdateCheckDone = true
                print("[ShellUpdates] Up to date (" + root.localCommit + ")")
            }
        }
    }

    // Step 7: Get the pending commits; the newest is the latest message
    Process {
        id: latestMessageProc
        running: false
        command: [...root._gitCmd, "log", "--pretty=format:%h|%s|%cr|%an", "HEAD..origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.commitLog = (text ?? "").trim()
                const newest = root.commitLog.split("\n")[0].split("|")
                root.latestMessage = newest.length > 1 ? newest[0] + " " + newest[1] : ""
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isChecking = false
            root.initialUpdateCheckDone = true
            root.maybeNotifyUpdate()
        }
    }

    // =========================================================================
    // Detail fetching (on-demand when overlay opens)
    // =========================================================================

    // Detail Step 1: Get commit log between local and remote
    Process {
        id: commitLogProc
        running: false
        command: [
            ...root._gitCmd, "log",
            "--pretty=format:%h|%s|%cr|%an",
            "HEAD..origin/" + root._remoteBranch
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.commitLog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            remoteVersionProc.running = true
        }
    }

    // Detail Step 2: Get remote VERSION
    Process {
        id: remoteVersionProc
        running: false
        command: [
            ...root._gitCmd, "show",
            "origin/" + root._remoteBranch + ":VERSION"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteVersion = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            localVersionProc.running = true
        }
    }

    // Detail Step 3: Get local VERSION (try repo, then config dir, then version.json)
    Process {
        id: localVersionProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "cat '" + root.repoPath + "/VERSION' 2>/dev/null || cat '" + root.configDir + "/VERSION' 2>/dev/null || echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localVersion = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            remoteChangelogProc.running = true
        }
    }

    // Detail Step 4: Get remote CHANGELOG.md (first 200 lines)
    Process {
        id: remoteChangelogProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "git -C '" + root.repoPath + "' show 'origin/" + root._remoteBranch + ":CHANGELOG.md' 2>/dev/null | head -200"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteChangelog = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            localModsProc.running = true
        }
    }

    // Detail Step 5: Detect local modifications via manifest checksums
    Process {
        id: localModsProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            "manifest='" + root.manifestPath + "'; " +
            "target='" + root.configDir + "'; " +
            "repo='" + root.repoPath + "'; " +
            "[[ -f \"$manifest\" ]] || exit 0; " +
            "while IFS=: read -r path checksum; do " +
            "  [[ \"$path\" =~ ^# ]] && continue; " +
            "  [[ -z \"$path\" ]] && continue; " +
            "  [[ -f \"$target/$path\" ]] || continue; " +
            "  if [[ -n \"$checksum\" ]]; then " +
            "    current=$(sha256sum \"$target/$path\" 2>/dev/null | cut -d' ' -f1); " +
            "    [[ \"$current\" != \"$checksum\" ]] && echo \"$path\"; " +
            "  elif [[ -d \"$repo/.git\" ]]; then " +
            "    repo_hash=$(git -C \"$repo\" show HEAD:\"$path\" 2>/dev/null | sha256sum | cut -d' ' -f1); " +
            "    local_hash=$(sha256sum \"$target/$path\" 2>/dev/null | cut -d' ' -f1); " +
            "    [[ -n \"$repo_hash\" && \"$repo_hash\" != \"$local_hash\" ]] && echo \"$path\"; " +
            "  fi; " +
            "done < \"$manifest\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (text ?? "").trim()
                if (raw.length > 0) {
                    root.localModifications = raw.split("\n").filter(l => l.length > 0)
                } else {
                    root.localModifications = []
                }
                print("[ShellUpdates] Local modifications: " + root.localModifications.length + " file(s)")
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isFetchingDetails = false
            print("[ShellUpdates] Detail fetch complete")
        }
    }

    // Note: Update runs via Quickshell.execDetached() in performUpdate()
    // so it survives the shell restart that ./setup update triggers.

    // Progress poller: reads the status file every 2s while updating to parse
    // structured progress markers written by setup's _report_progress().
    Timer {
        id: updateProgressPoller
        interval: 2000
        repeat: true
        running: false
        onTriggered: {
            if (!root.isUpdating) {
                updateProgressPoller.running = false
                return
            }
            updateProgressReader.running = true
        }
    }

    Process {
        id: updateProgressReader
        running: false
        command: ["cat", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                if (status.startsWith("progress:")) {
                    // Format: progress:STEP:TOTAL:MESSAGE
                    const parts = status.split(":")
                    if (parts.length >= 4) {
                        root.updateStep = parseInt(parts[1]) || 0
                        root.updateTotalSteps = parseInt(parts[2]) || 0
                        root.updateStepMessage = parts.slice(3).join(":")
                    }
                } else if (status === "updating") {
                    // Legacy/initial marker — no granular progress yet
                    root.updateStep = 0
                    root.updateStepMessage = ""
                } else if (status.startsWith("failed")) {
                    // The setup process has already exited. Handle this immediately
                    // instead of leaving the bar spinner alive until the 120s watchdog.
                    root.handleFailedUpdateStatus(status, false)
                }
            }
        }
    }

    // Watchdog: if the shell is still alive after 120s, the update likely failed.
    // On success, ./setup update restarts the shell — this timer never fires.
    Timer {
        id: updateWatchdog
        interval: 120000
        repeat: false
        onTriggered: {
            if (!root.isUpdating) return
            print("[ShellUpdates] Watchdog: shell still alive after update launch — reading status file")
            updateStatusReader.running = true
        }
    }

    // Read the status file to determine if the update failed
    Process {
        id: updateStatusReader
        running: false
        command: ["cat", Directories.updateStatusPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const status = (text ?? "").trim()
                print("[ShellUpdates] Update status file: " + status)
                if (status.startsWith("failed")) {
                    root.handleFailedUpdateStatus(status, false)
                } else if (status.startsWith("progress:")) {
                    if (status === root._lastWatchdogStatus) {
                        // Same progress marker seen twice — update is stuck
                        root.clearUpdateProgressUi()
                        root.lastError = "Update stuck at: " + status.split(":").slice(3).join(":") + ". Check " + Directories.updateLogPath + " for details."
                        clearStatusFileProc.running = true
                        print("[ShellUpdates] Update stuck — same progress seen twice: " + status)
                    } else {
                        // Different progress marker — still moving, extend watchdog
                        root._lastWatchdogStatus = status
                        print("[ShellUpdates] Watchdog: update still progressing, extending timeout")
                        updateWatchdog.restart()
                    }
                } else if (status === "updating") {
                    // Still running after 120s — likely stuck
                    root.clearUpdateProgressUi()
                    root.lastError = "Update appears stuck. Check " + Directories.updateLogPath + " for details."
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update appears stuck (still 'updating' after watchdog)")
                } else if (status === "success") {
                    // Update completed successfully but shell wasn't restarted
                    root.clearUpdateProgressUi()
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update completed successfully (no restart)")
                } else {
                    // Empty or unexpected — assume failed
                    root.clearUpdateProgressUi()
                    root.lastError = "Update outcome unknown. Check " + Directories.updateLogPath + " for details."
                    clearStatusFileProc.running = true
                    print("[ShellUpdates] Update status unclear: '" + status + "'")
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.isUpdating) {
                // Status file doesn't exist — update process may not have started
                root.clearUpdateProgressUi()
                root.lastError = "Update may not have started. Check " + Directories.updateLogPath + " for details."
                print("[ShellUpdates] Status file not found (cat exited " + exitCode + ")")
            }
        }
    }
}
