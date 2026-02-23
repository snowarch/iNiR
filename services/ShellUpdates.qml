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
 * NOTE: The config directory (~/.config/quickshell/inir) is NOT a git repo.
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
    }
    id: root

    // Public state
    property bool hasUpdate: false
    property int commitsBehind: 0
    property string latestMessage: ""
    property string localCommit: ""
    property string remoteCommit: ""
    property string currentBranch: "main"  // Current git branch
    property string _remoteBranch: "main"  // Resolved remote branch (may differ from currentBranch if not pushed)
    property bool isChecking: false
    property bool isUpdating: false
    property string lastError: ""
    property bool available: false  // git is available and repo exists

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
    readonly property bool showUpdate: hasUpdate && !isDismissed && !isUpdating
    readonly property bool isDismissed: dismissedCommit.length > 0 && remoteCommit === dismissedCommit

    // Repo path - try to get from version.json, fallback to config dir
    readonly property string configDir: FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    property string repoPath: configDir  // Will be updated after reading version.json
    property bool repoPathLoaded: false
    readonly property string manifestPath: configDir + "/.inir-manifest"

    // Handler: notify when availability changes to false (after initial check)
    onAvailableChanged: {
        if (initialAvailabilityChecked && !available && !unavailableNotificationShown) {
            unavailableNotificationShown = true
            Notifications.notify({
                summary: "iNiR Updates Unavailable",
                body: "Repository not found. Run './setup doctor' to diagnose the issue.",
                urgency: NotificationUrgency.Normal,
                timeout: 10000,
                appName: "iNiR Shell"
            })
            print("[ShellUpdates] Notification sent: Updates unavailable")
        }
        // Reset notification flag when available becomes true again
        if (available) {
            unavailableNotificationShown = false
        }
    }

    // Handler: notify when a new update is detected
    onHasUpdateChanged: {
        if (!hasUpdate || !available || !initialUpdateCheckDone || isDismissed) return
        if (remoteCommit.length === 0 || remoteCommit === lastNotifiedCommit) return

        const version = root.remoteVersion.length > 0 ? (" v" + root.remoteVersion) : ""
        const commits = root.commitsBehind > 0 ? (root.commitsBehind + " commits behind") : "New version available"
        Notifications.notify({
            summary: "iNiR Update Available" + version,
            body: commits + ". Click the update indicator in the bar or open Settings → Services.",
            urgency: NotificationUrgency.Normal,
            timeout: 15000,
            appName: "iNiR Shell"
        })
        Config.setNestedValue("shellUpdates.lastNotifiedCommit", remoteCommit)
        print("[ShellUpdates] Notification sent: Update available" + version)
    }

    function check(): void {
        if (!enabled || isChecking || isUpdating) return
        root.isChecking = true
        root.lastError = ""
        fetchProc.running = true
    }

    // Fetch detailed info for the overlay (commit log, changelog, local mods)
    function fetchDetails(): void {
        if (isFetchingDetails) return
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
        if (!panels.includes("inirShellUpdate")) {
            Config.setNestedValue("enabledPanels", [...panels, "inirShellUpdate"])
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
        if (isUpdating || !hasUpdate || !available) return
        root.isUpdating = true
        root.lastError = ""
        root.overlayOpen = false
        // Use execDetached so the update script survives shell restart
        // (./setup update calls qs kill -c inir at the end)
        // Must cd to repo dir first — setup expects to run from its own directory
        Quickshell.execDetached(["/usr/bin/bash", "-c",
            "cd '" + root.repoPath + "' && ./setup update -y -q"])
        print("[ShellUpdates] Update launched (detached) from: " + root.repoPath)
        // Shell will be restarted by ./setup update, so just mark state
        root.hasUpdate = false
        root.commitsBehind = 0
        root.lastError = ""
        Config.setNestedValue("shellUpdates.dismissedCommit", "")
    }

    function dismiss(): void {
        if (remoteCommit.length > 0) {
            Config.setNestedValue("shellUpdates.dismissedCommit", remoteCommit)
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
            gitAvailable: root.available,
            lastError: root.lastError,
            consecutiveFetchErrors: root.consecutiveFetchErrors,
            hasUpdate: root.hasUpdate,
            commitsBehind: root.commitsBehind,
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
                    if (json.repo_path && json.repo_path.length > 0) {
                        root.repoPath = json.repo_path
                        print("[ShellUpdates] Using repo path from version.json: " + root.repoPath)
                        root.repoPathLoaded = true
                        validateRepoPathProc.running = true
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
            "for dir in ~/inir ~/inir ~/iNiR " +
            "~/.local/src/inir ~/.local/src/inir " +
            "~/Projects/inir ~/Projects/inir " +
            "~/Downloads/inir ~/Downloads/inir " +
            "~/src/inir ~/src/inir; do " +
            "if [[ -d \"$dir/.git\" && -f \"$dir/setup\" && -f \"$dir/shell.qml\" ]]; then echo \"$dir\"; exit 0; fi; done; " +
            // Last resort: find in home (max depth 3, timeout 2s)
            "timeout 2 find \"$HOME\" -maxdepth 3 -name setup \\( -path '*/inir/setup' -o -path '*/inir/setup' -o -path '*/inir/setup' \\) 2>/dev/null | while read -r f; do [[ -f \"$(dirname \"$f\")/shell.qml\" ]] && dirname \"$f\" && break; done; "
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const foundPath = (text ?? "").trim()
                if (foundPath.length > 0) {
                    root.repoPath = foundPath
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
            "if [[ -f \"$vfile\" ]] && command -v jq &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  jq --arg p '" + root.repoPath + "' '.repo_path = $p' \"$vfile\" > \"$tmp\" && mv \"$tmp\" \"$vfile\"; " +
            "  echo 'Updated'; " +
            "elif [[ -f \"$vfile\" ]] && command -v python3 &>/dev/null; then " +
            "  tmp=$(mktemp); " +
            "  python3 -c 'import json,sys; path=sys.argv[1]; repo=sys.argv[2]; " +
            "\ntry: data=json.load(open(path,\"r\",encoding=\"utf-8\"))" +
            "\nexcept Exception: data={}" +
            "\ndata[\"repo_path\"]=repo" +
            "\njson.dump(data, sys.stdout, ensure_ascii=False, indent=2)' \"$vfile\" '" + root.repoPath + "' > \"$tmp\" " +
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

    // Step 1: Check if git is available
    Process {
        id: availabilityProc
        running: false
        command: ["git", "-C", root.repoPath, "rev-parse", "--git-dir"]
        onExited: (exitCode, exitStatus) => {
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
            "git", "-C", root.repoPath, "log",
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
        command: ["git", "-C", root.repoPath, "fetch", "origin", "--quiet"]
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
                    Notifications.notify({
                        summary: title,
                        body: body,
                        urgency: NotificationUrgency.Low,
                        timeout: 8000,
                        appName: "iNiR Shell"
                    })
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
        command: ["git", "-C", root.repoPath, "rev-parse", "--abbrev-ref", "HEAD"]
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
        command: ["git", "-C", root.repoPath, "rev-parse", "--short", "HEAD"]
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
        command: ["git", "-C", root.repoPath, "rev-parse", "--short", "origin/" + root.currentBranch]
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
        command: ["git", "-C", root.repoPath, "rev-parse", "--short", "origin/main"]
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
        command: ["git", "-C", root.repoPath, "rev-parse", "--short", "origin/master"]
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

    // Step 6: Count commits behind
    Process {
        id: countCommitsProc
        running: false
        command: ["git", "-C", root.repoPath, "rev-list", "--count", "HEAD..origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                const count = parseInt((text ?? "0").trim())
                root.commitsBehind = isNaN(count) ? 0 : count
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Fallback: compare commits directly
                root.hasUpdate = root.localCommit !== root.remoteCommit && root.remoteCommit.length > 0
                root.commitsBehind = root.hasUpdate ? 1 : 0
                root.isChecking = false
                root.initialUpdateCheckDone = true
                return
            }
            root.hasUpdate = root.commitsBehind > 0
            print("[ShellUpdates] Commits behind: " + root.commitsBehind + ", hasUpdate: " + root.hasUpdate)
            if (root.hasUpdate) {
                latestMessageProc.running = true
            } else {
                root.isChecking = false
                root.initialUpdateCheckDone = true
                print("[ShellUpdates] Up to date (" + root.localCommit + ")")
            }
        }
    }

    // Step 7: Get latest commit message from remote
    Process {
        id: latestMessageProc
        running: false
        command: ["git", "-C", root.repoPath, "log", "--oneline", "-1", "origin/" + root._remoteBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.latestMessage = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isChecking = false
            root.initialUpdateCheckDone = true
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
            "git", "-C", root.repoPath, "log",
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
            "git", "-C", root.repoPath, "show",
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
}
