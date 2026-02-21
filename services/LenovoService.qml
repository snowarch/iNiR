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
    // Common paths for Lenovo conservation mode
    readonly property list<string> potentialNodes: [
        "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode",
        "/sys/bus/platform/devices/VPC2004:00/conservation_mode",
        "/sys/devices/platform/ideapad_laptop/conservation_mode",
        "/sys/bus/platform/devices/VPC2004:00/firmware_node/conservation_mode"
    ]
    
    property string nodePath: ""
    
    // --- Public State ---
    property bool isActive: false
    property bool loading: false
    property bool available: false // Whether to show the toggle (is it a Lenovo?)
    property bool functional: false // Whether the control node was actually found

    // --- Logic ---
    
    function updateStatus() {
        if (!functional) return;
        statusCheck.running = true;
    }

    function toggle() {
        if (!functional || loading) return;
        loading = true;
        toggleProcess.running = true;
    }

    // --- Processes ---

    // 1. Hardware detection: Is this a Lenovo laptop?
    Process {
        id: hardwareCheck
        command: ["sh", "-c", "grep -qi 'lenovo' /sys/class/dmi/id/sys_vendor || test -d /sys/bus/platform/devices/VPC2004:00"]
        running: true
        onExited: (code) => {
            root.available = (code === 0);
            if (root.available) findNode.running = true;
        }
    }

    // 2. Node detection: Search for the actual conservation_mode file
    Process {
        id: findNode
        command: ["sh", "-c", "find /sys/bus/platform/devices/VPC2004:00/ /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/ /sys/devices/platform/ideapad_laptop/ -name conservation_mode 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            id: findCollector
            onStreamFinished: {
                const found = findCollector.text.trim();
                if (found !== "") {
                    root.nodePath = found;
                    root.functional = true;
                    root.updateStatus();
                } else {
                    // Fallback to first potential node for path-based check if find failed
                    root.nodePath = root.potentialNodes[0];
                    checkFunctional.running = true;
                }
            }
        }
    }

    Process {
        id: checkFunctional
        command: ["test", "-f", root.nodePath]
        onExited: (code) => {
            root.functional = (code === 0);
            if (root.functional) root.updateStatus();
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
                Quickshell.execDetached(["notify-send", "-a", "System", "Conservation Mode", "Failed to update setting. Ensure ideapad_laptop module is loaded."]);
            }
        }
    }

    // Periodic Refresh
    Timer {
        interval: 5000
        running: root.functional
        repeat: true
        onTriggered: root.updateStatus()
    }

    // Retry finding the node (in case driver is loaded late)
    Timer {
        interval: 15000
        running: root.available && !root.functional
        repeat: true
        onTriggered: findNode.running = true
    }
}
