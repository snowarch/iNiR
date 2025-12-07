import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root
    
    // Toast queue
    property var toasts: []
    property int maxToasts: 5
    property int toastSpacing: 8
    
    function addToast(title, message, icon, isError, duration, source, accentColor) {
        // Prevent duplicates: remove existing toast from same source with same error state
        toasts = toasts.filter(t => !(t.source === source && t.isError === isError))
        
        const toast = {
            id: Date.now(),
            title: title,
            message: message || "",
            icon: icon || (isError ? "error" : "check_circle"),
            isError: isError || false,
            duration: duration || (isError ? 6000 : 2000),
            source: source || "system",
            accentColor: accentColor || Appearance.colors.colPrimary
        }
        
        toasts = [...toasts, toast]
        
        // Limit max toasts
        if (toasts.length > maxToasts) {
            toasts = toasts.slice(-maxToasts)
        }
        
        popupLoader.loading = true
    }
    
    function removeToast(id) {
        toasts = toasts.filter(t => t.id !== id)
        if (toasts.length === 0) {
            popupLoader.active = false
        }
    }
    
    // Check if reload toasts should be shown
    readonly property bool reloadToastsEnabled: (Config.options?.reloadToasts?.enable ?? true) 
        && !(GameMode.active && (Config.options?.gameMode?.disableReloadToasts ?? true))

    // Quickshell reload signals
    Connections {
        target: Quickshell
        
        function onReloadCompleted() {
            if (!root.reloadToastsEnabled) return
            root.addToast(
                "Quickshell reloaded",
                "",
                "refresh",
                false,
                2000,
                "quickshell",
                Appearance.colors.colPrimary
            )
        }
        
        function onReloadFailed(error) {
            // Always show errors
            root.addToast(
                "Quickshell reload failed",
                error,
                "error",
                true,
                8000,
                "quickshell",
                Appearance.colors.colError
            )
        }
    }
    
    // Niri config reload signals
    Connections {
        target: NiriService
        
        function onConfigLoadFinished(ok, error) {
            if (ok) {
                if (!root.reloadToastsEnabled) return
                root.addToast(
                    "Niri config reloaded",
                    "",
                    "settings",
                    false,
                    2000,
                    "niri",
                    Appearance.colors.colTertiary
                )
            } else {
                // Always show errors
                root.addToast(
                    "Niri config reload failed",
                    error || "Run 'niri validate' in terminal for details",
                    "error",
                    true,
                    8000,
                    "niri",
                    Appearance.colors.colError
                )
            }
        }
    }
    
    LazyLoader {
        id: popupLoader
        
        PanelWindow {
            id: popup
            exclusiveZone: 0
            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: 10
            
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:toast-manager"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            // Only capture input on actual toast area
            mask: Region {
                item: toastColumn
            }
            
            implicitHeight: toastColumn.implicitHeight + 20
            color: "transparent"
            
            ColumnLayout {
                id: toastColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                spacing: root.toastSpacing
                
                Repeater {
                    model: root.toasts
                    
                    delegate: ToastNotification {
                        required property var modelData
                        required property int index
                        
                        title: modelData.title
                        message: modelData.message
                        icon: modelData.icon
                        isError: modelData.isError
                        duration: modelData.duration
                        source: modelData.source
                        accentColor: modelData.accentColor
                        
                        opacity: 1
                        scale: 1
                        
                        // Entry animation
                        Component.onCompleted: {
                            entryAnim.start()
                        }
                        
                        ParallelAnimation {
                            id: entryAnim
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                from: 0.9
                                to: 1
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        onDismissed: {
                            exitAnim.start()
                        }
                        
                        ParallelAnimation {
                            id: exitAnim
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                to: 0
                                duration: 150
                                easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                to: 0.9
                                duration: 150
                                easing.type: Easing.InCubic
                            }
                            onFinished: root.removeToast(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
