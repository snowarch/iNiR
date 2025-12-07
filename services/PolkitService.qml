pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

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
    
    Component.onCompleted: {
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
}
