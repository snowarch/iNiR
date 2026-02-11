pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

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
    }
    id: root

    // Public state
    property bool hasUpdate: false
    property int commitsBehind: 0
    property string latestMessage: ""
    property string localCommit: ""
    property string remoteCommit: ""
    property string currentBranch: "main"  // Current git branch
    property bool isChecking: false
    property bool isUpdating: false
    property string lastError: ""
    property bool available: false  // git is available and repo exists

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

    // Derived
    readonly property bool enabled: Config.options?.shellUpdates?.enabled ?? true
    readonly property int checkIntervalMs: (Config.options?.shellUpdates?.checkIntervalMinutes ?? 360) * 60 * 1000
    readonly property string dismissedCommit: Config.options?.shellUpdates?.dismissedCommit ?? ""
    readonly property bool showUpdate: hasUpdate && !isDismissed && !isUpdating
    readonly property bool isDismissed: dismissedCommit.length > 0 && remoteCommit === dismissedCommit

    // Repo path - try to get from version.json, fallback to config dir
    readonly property string configDir: FileUtils.trimFileProtocol(Quickshell.shellPath("."))
    property string repoPath: configDir  // Will be updated after reading version.json
    property bool repoPathLoaded: false
    readonly property string manifestPath: configDir + "/.ii-manifest"

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
        root.overlayOpen = true
        if (hasUpdate) fetchDetails()
    }

    function closeOverlay(): void {
        root.overlayOpen = false
    }

    function performUpdate(): void {
        if (isUpdating || !hasUpdate) return
        root.isUpdating = true
        root.lastError = ""
        root.overlayOpen = false
        // Use execDetached so the update script survives shell restart
        // (./setup update calls qs kill -c ii at the end)
        Quickshell.execDetached(["/usr/bin/bash", root.repoPath + "/setup", "update", "-y", "-q"])
        print("[ShellUpdates] Update launched (detached)")
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

    // Load repo path from version.json
    Process {
        id: loadRepoPathProc
        property bool _handledFallback: false
        running: false
        onRunningChanged: if (running) _handledFallback = false
        command: ["cat", root.configDir + "/../illogical-impulse/version.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text ?? "{}")
                    if (json.repo_path && json.repo_path.length > 0) {
                        root.repoPath = json.repo_path
                        print("[ShellUpdates] Using repo path from version.json: " + root.repoPath)
                        root.repoPathLoaded = true
                        availabilityProc.running = true
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

    // Search for repository in common locations
    Process {
        id: searchRepoProc
        running: false
        command: [
            "/usr/bin/bash", "-c",
            // First check if config dir itself is a git repo (dev setup)
            "if [[ -d \"" + root.configDir + "/.git\" ]]; then echo \"" + root.configDir + "\"; exit 0; fi; " +
            // Then search common clone locations
            "for dir in ~/inir ~/iNiR ~/Downloads/inir ~/Downloads/iNiR ~/.local/src/inir ~/.local/src/iNiR /tmp/inir /tmp/iNiR; do " +
            "if [[ -d \"$dir/.git\" ]]; then echo \"$dir\"; exit 0; fi; done; " +
            "echo ''"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const foundPath = (text ?? "").trim()
                if (foundPath.length > 0) {
                    root.repoPath = foundPath
                    print("[ShellUpdates] Found repository at: " + root.repoPath)
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
    Process {
        id: localVersionStartupProc
        running: false
        command: ["cat", root.configDir + "/VERSION"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localVersion = (text ?? "").trim()
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
                // Silent fail - network might be down, retry next interval
                return
            }
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
            countCommitsProc.running = true
        }
    }

    // Step 6: Count commits behind
    Process {
        id: countCommitsProc
        running: false
        command: ["git", "-C", root.repoPath, "rev-list", "--count", "HEAD..origin/" + root.currentBranch]
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
                return
            }
            root.hasUpdate = root.commitsBehind > 0
            print("[ShellUpdates] Commits behind: " + root.commitsBehind + ", hasUpdate: " + root.hasUpdate)
            if (root.hasUpdate) {
                latestMessageProc.running = true
            } else {
                root.isChecking = false
                print("[ShellUpdates] Up to date (" + root.localCommit + ")")
            }
        }
    }

    // Step 7: Get latest commit message from remote
    Process {
        id: latestMessageProc
        running: false
        command: ["git", "-C", root.repoPath, "log", "--oneline", "-1", "origin/" + root.currentBranch]
        stdout: StdioCollector {
            onStreamFinished: {
                root.latestMessage = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isChecking = false
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
            "HEAD..origin/" + root.currentBranch
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
            "origin/" + root.currentBranch + ":VERSION"
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

    // Detail Step 3: Get local VERSION
    Process {
        id: localVersionProc
        running: false
        command: ["cat", root.configDir + "/VERSION"]
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
            "git -C '" + root.repoPath + "' show 'origin/" + root.currentBranch + ":CHANGELOG.md' 2>/dev/null | head -200"
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
            "[[ -f \"$manifest\" ]] || exit 0; " +
            "while IFS=: read -r path checksum; do " +
            "  [[ \"$path\" =~ ^# ]] && continue; " +
            "  [[ -z \"$path\" || -z \"$checksum\" ]] && continue; " +
            "  [[ -f \"$target/$path\" ]] || continue; " +
            "  current=$(sha256sum \"$target/$path\" 2>/dev/null | cut -d' ' -f1); " +
            "  [[ \"$current\" != \"$checksum\" ]] && echo \"$path\"; " +
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
