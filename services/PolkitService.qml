pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * PolkitService - Wrapper that gracefully handles missing Quickshell.Services.Polkit module
 * 
 * The Polkit module is optional in Quickshell and may not be compiled in all builds.
 * This wrapper provides a stub interface when the module is unavailable, preventing
 * the entire shell from failing to load.
 */
Singleton {
    id: root
    
    // Public API - matches PolkitServiceImpl
    property var agent: impl?.agent ?? null
    property bool active: impl?.active ?? false
    property var flow: impl?.flow ?? null
    property bool interactionAvailable: impl?.interactionAvailable ?? false
    
    // Whether the Polkit module is available
    readonly property bool available: impl !== null
    
    function cancel(): void {
        if (impl) impl.cancel()
    }
    
    function submit(text: string): void {
        if (impl) impl.submit(text)
    }
    
    // Private: actual implementation loaded dynamically
    property var impl: null

    function _loadImpl(): void {
        // Try to load the real implementation
        const component = Qt.createComponent("PolkitServiceImpl.qml", Component.Asynchronous)

        function finishCreation() {
            if (component.status === Component.Ready) {
                root.impl = component.createObject(root)
                console.log("[PolkitService] Polkit module loaded successfully")
            } else if (component.status === Component.Error) {
                console.warn("[PolkitService] Polkit module not available - polkit agent disabled")
                console.warn("[PolkitService] To enable, rebuild quickshell with -DSERVICE_POLKIT=ON")
            }
        }

        if (component.status === Component.Ready || component.status === Component.Error) {
            finishCreation()
        } else {
            component.statusChanged.connect(finishCreation)
        }
    }
    
    Component.onCompleted: {
        if (Quickshell.env("QS_DISABLE_POLKIT") === "1") {
            return
        }
        if (!(Config.options?.modules?.polkit ?? true)) {
            return
        }

        // If another authentication agent already exists, registering will fail and spam warnings.
        // Best-effort detection: if we can see a known agent process, skip our agent.
        polkitAgentCheck.running = true
    }

    Process {
        id: polkitAgentCheck
        running: false

        // Note: pidof returns 0 if ANY process exists. If pidof is missing or fails, exitCode != 0 and we proceed.
        command: [
            "/usr/bin/pidof",
            "polkit-gnome-authentication-agent-1",
            "lxqt-policykit-agent",
            "polkit-kde-authentication-agent-1",
            "mate-polkit"
        ]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // Another agent exists; avoid the Quickshell polkit listener warning.
                return
            }
            root._loadImpl()
        }
    }
}
