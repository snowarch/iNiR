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

    function check(): void {
        if (!enabled || isChecking || isUpdating) return
        root.isChecking = true
        root.lastError = ""
        fetchProc.running = true
    }

    function performUpdate(): void {
        if (isUpdating || !hasUpdate) return
        root.isUpdating = true
        root.lastError = ""
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
                root.check()
            }
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

    // Note: Update runs via Quickshell.execDetached() in performUpdate()
    // so it survives the shell restart that ./setup update triggers.
}
