pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// ============================================================================
// BATTERY CONSERVATION MODE SERVICE
// ============================================================================

Singleton {
    id: root

    // --- Configuration ---
    // Common paths for battery conservation mode (manufacturer specific)
    readonly property list<string> potentialNodes: [
        "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode",
        "/sys/bus/platform/devices/VPC2004:00/conservation_mode",
        "/sys/devices/platform/ideapad_laptop/conservation_mode",
        "/sys/class/power_supply/BAT0/charge_control_end_threshold",
        "/sys/class/power_supply/BAT1/charge_control_end_threshold"
    ]
    
    property string nodePath: ""
    property bool isModernNode: false // Whether we are using charge_control_end_threshold
    
    // --- Public State ---
    property bool isActive: false
    property bool loading: false
    property bool available: false // Whether to show the toggle
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

    // 1. Hardware detection: Check for supported hardware
    Process {
        id: hardwareCheck
        command: ["sh", "-c", "grep -qi 'lenovo' /sys/class/dmi/id/sys_vendor || test -d /sys/bus/platform/devices/VPC2004:00 || test -f /sys/class/power_supply/BAT0/charge_control_end_threshold"]
        running: true
        onExited: (code) => {
            root.available = (code === 0);
            if (root.available) findNode.running = true;
        }
    }

    // 2. Node detection: Search for the actual control file
    Process {
        id: findNode
        command: ["sh", "-c", "find /sys/bus/platform/devices/VPC2004:00/ /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/ /sys/devices/platform/ideapad_laptop/ /sys/class/power_supply/BAT0/ /sys/class/power_supply/BAT1/ -name 'conservation_mode' -o -name 'charge_control_end_threshold' 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            id: findCollector
            onStreamFinished: {
                const found = findCollector.text.trim();
                if (found !== "") {
                    root.nodePath = found;
                    root.isModernNode = found.indexOf("charge_control_end_threshold") !== -1;
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
            if (root.functional) {
                root.isModernNode = root.nodePath.indexOf("charge_control_end_threshold") !== -1;
                root.updateStatus();
            }
        }
    }

    Process {
        id: statusCheck
        command: ["cat", root.nodePath]
        stdout: StdioCollector {
            id: outCollector
            onStreamFinished: {
                const result = outCollector.text.trim();
                if (root.isModernNode) {
                    // For threshold nodes, anything less than 100% is considered a form of conservation
                    // Usually 60 or 80.
                    root.isActive = (result !== "100");
                } else {
                    root.isActive = (result === "1");
                }
                root.loading = false;
            }
        }
    }

    Process {
        id: toggleProcess
        function getTargetValue() {
            if (root.isModernNode) {
                return root.isActive ? "100" : "80"; // Toggle between 80% and 100%
            }
            return root.isActive ? "0" : "1";
        }
        command: ["pkexec", "sh", "-c", `echo ${getTargetValue()} > ${root.nodePath}`]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.updateStatus();
            } else {
                root.loading = false;
                Quickshell.execDetached(["notify-send", "-a", "System", "Battery Conservation", "Failed to update setting. Check permissions or driver support."]);
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

    // Retry finding the node
    Timer {
        interval: 15000
        running: root.available && !root.functional
        repeat: true
        onTriggered: findNode.restart()
    }
}
