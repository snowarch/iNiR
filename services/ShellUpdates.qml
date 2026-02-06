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
 */
Singleton {
    id: root

    // Public state
    property bool hasUpdate: false
    property int commitsBehind: 0
    property string latestMessage: ""
    property string localCommit: ""
    property string remoteCommit: ""
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

    // Repo path (where ii is installed)
    readonly property string repoPath: FileUtils.trimFileProtocol(Quickshell.shellPath("."))

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
        Quickshell.execDetached(["bash", root.repoPath + "/setup", "update", "-y", "-q"])
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
            print("[ShellUpdates] Starting availability check, repoPath: " + root.repoPath)
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
            localCommitProc.running = true
        }
    }

    // Step 3: Get local commit
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

    // Step 4: Get remote commit
    Process {
        id: remoteCommitProc
        running: false
        command: ["git", "-C", root.repoPath, "rev-parse", "--short", "origin/main"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.remoteCommit = (text ?? "").trim()
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // Try origin/master as fallback
                remoteCommitFallbackProc.running = true
                return
            }
            countCommitsProc.running = true
        }
    }

    // Step 4b: Fallback to origin/master
    Process {
        id: remoteCommitFallbackProc
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

    // Step 5: Count commits behind
    Process {
        id: countCommitsProc
        running: false
        command: ["git", "-C", root.repoPath, "rev-list", "--count", "HEAD..origin/main"]
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

    // Step 6: Get latest commit message from remote
    Process {
        id: latestMessageProc
        running: false
        command: ["git", "-C", root.repoPath, "log", "--oneline", "-1", "origin/main"]
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
