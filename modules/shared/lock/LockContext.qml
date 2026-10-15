import qs
import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Scope {
    id: root

    enum ActionEnum { Unlock, Poweroff, Reboot }

    signal shouldReFocus()
    signal unlocked(targetAction: var)
    signal failed()

    // These properties are in the context and not individual lock surfaces
    // so all surfaces can share the same state.
    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool fingerprintsConfigured: false
    property var targetAction: LockContext.ActionEnum.Unlock
    property bool alsoInhibitIdle: false

    function resetTargetAction() {
        root.targetAction = LockContext.ActionEnum.Unlock;
    }

    function clearText() {
        root.currentText = "";
    }

    function resetClearTimer() {
        passwordClearTimer.restart();
    }

    function reset() {
        root.resetTargetAction();
        root.clearText();
        root.unlockInProgress = false;
        stopFingerPam();
        if (GlobalStates.screenLocked)
            Qt.callLater(root.tryFingerUnlock);
    }

    Timer {
        id: passwordClearTimer
        interval: 10000
        onTriggered: {
            root.reset();
        }
    }

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            showFailure = false;
            GlobalStates.screenUnlockFailed = false;
        }
        GlobalStates.screenLockContainsCharacters = currentText.length > 0;
        passwordClearTimer.restart();
    }

    function tryUnlock(alsoInhibitIdle = false) {
        root.alsoInhibitIdle = alsoInhibitIdle;
        root.unlockInProgress = true;
        pamTimeoutTimer.restart();
        pam.start();
    }

    // Safety timeout - if PAM doesn't respond in 10 seconds, reset state
    Timer {
        id: pamTimeoutTimer
        interval: 10000
        onTriggered: {
            if (root.unlockInProgress) {
                console.warn("[LockContext] PAM timeout - resetting state");
                root.unlockInProgress = false;
                root.showFailure = true;
                GlobalStates.screenUnlockFailed = true;
            }
        }
    }

    function tryFingerUnlock() {
        if (!GlobalStates.screenLocked || !root.fingerprintsConfigured || fingerPam.active)
            return;
        fingerprintRetryTimer.stop();
        if (!fingerPam.start())
            fingerprintRetryTimer.restart();
    }

    function stopFingerPam() {
        fingerprintRetryTimer.stop();
        if (fingerPam.active)
            fingerPam.abort();
    }

    Timer {
        id: fingerprintRetryTimer
        interval: 750
        repeat: false
        onTriggered: root.tryFingerUnlock()
    }

    Process {
        id: fingerprintCheckProc
        running: true
        command: ["/usr/bin/bash", "-c", "command -v fprintd-list >/dev/null && fprintd-list $(whoami) 2>/dev/null || exit 1"]
        stdout: StdioCollector {
            id: fingerprintOutputCollector
            onStreamFinished: {
                // fprintd's enrolled-print rows are stable machine-readable finger
                // identifiers; do not depend on the localized heading text.
                root.fingerprintsConfigured = /(^|\n)\s*-\s+#\d+:/.test(fingerprintOutputCollector.text);
                if (root.fingerprintsConfigured && GlobalStates.screenLocked)
                    Qt.callLater(root.tryFingerUnlock);
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                // fprintd not installed or no fingerprints configured
                root.fingerprintsConfigured = false;
            }
        }
    }
    
    PamContext {
        id: pam

        // pam_unix will ask for a response for the password prompt
        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        // pam_unix won't send any important messages so all we need is the completion status.
        onCompleted: result => {
            pamTimeoutTimer.stop();
            if (result == PamResult.Success) {
                root.unlockInProgress = false;
                root.unlocked(root.targetAction);
                stopFingerPam();
            } else {
                root.clearText();
                root.unlockInProgress = false;
                GlobalStates.screenUnlockFailed = true;
                root.showFailure = true;
            }
        }
    }

    PamContext {
        id: fingerPam

        configDirectory: "pam"
        config: "fprintd.conf"

        onCompleted: result => {
            if (result == PamResult.Success) {
                fingerprintRetryTimer.stop();
                root.unlocked(root.targetAction);
            } else if (GlobalStates.screenLocked && root.fingerprintsConfigured) {
                // Failed scans, PAM errors and max-tries completions are all
                // recoverable while the lock remains active. Retry through a
                // timer so a broken device/PAM stack cannot create a tight loop.
                fingerprintRetryTimer.restart();
            }
        }
    }
}
