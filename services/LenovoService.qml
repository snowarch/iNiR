pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// ============================================================================
// LENOVO CONSERVATION MODE SERVICE
// ============================================================================

Singleton {
    id: root

    // --- Configuration ---
    readonly property string nodePath: "/sys/devices/pci0000:00/0000:00:1f.0/PNP0C09:00/VPC2004:00/conservation_mode"
    
    // --- Public State ---
    property bool isActive: false
    property bool loading: false
    property bool available: false

    // --- Logic ---
    
    function updateStatus() {
        if (!available) return;
        statusCheck.running = true;
    }

    function toggle() {
        if (!available || loading) return;
        loading = true;
        toggleProcess.running = true;
    }

    // --- Processes ---

    // Initial hardware check
    Process {
        id: hardwareCheck
        command: ["test", "-f", root.nodePath]
        running: true
        onExited: (code) => {
            root.available = (code === 0);
            if (root.available) root.updateStatus();
        }
    }

    Process {
        id: statusCheck
        command: ["cat", root.nodePath]
        stdout: StdioCollector {
            id: outCollector
            onStreamFinished: {
                const result = outCollector.text.trim();
                root.isActive = (result === "1");
                root.loading = false;
            }
        }
    }

    Process {
        id: toggleProcess
        command: ["pkexec", "sh", "-c", `echo ${root.isActive ? "0" : "1"} > ${root.nodePath}`]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.updateStatus();
            } else {
                root.loading = false;
                // Optional: Trigger a notification on failure
                Quickshell.execDetached(["notify-send", "-a", "System", "Conservation Mode", "Authentication failed or cancelled."]);
            }
        }
    }

    // Periodic Refresh
    Timer {
        interval: 5000
        running: root.available
        repeat: true
        onTriggered: root.updateStatus()
    }
}
