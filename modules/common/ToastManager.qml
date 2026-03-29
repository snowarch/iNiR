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
    readonly property bool suppressOnScreenToasts: (GameMode?.active ?? false) || (GameMode?.hasAnyFullscreenWindow ?? false)
    
    // Unified reload tracking - only show ONE toast per reload event
    property real _lastReloadToastTime: 0
    property string _pendingReloadSource: ""  // "quickshell", "niri", or ""
    readonly property int _reloadDebounceMs: 800   // Wait this long to coalesce events
    readonly property int _reloadCooldownMs: 2500  // Minimum time between reload toasts
    
    // Track if we're in the middle of a QS reload (suppresses Niri toast)
    property bool _qsReloadInProgress: false
    
    // Check if reload toasts should be shown
    function shouldShowReloadToast(): bool {
        if (Config.isSettingsProcess) return false
        if (!(Config.options?.reloadToasts?.enable ?? true)) return false
        
        if (GameMode.disableReloadToasts && (GameMode.active || GameMode.hasAnyFullscreenWindow || GameMode.suppressNiriToast)) {
            return false
        }
        
        return true
    }
    
    function addToast(title, message, icon, isError, duration, source, accentColor) {
        // Prevent duplicates: if same source and title already visible, ignore
        if (toasts.some(t => t.source === source && t.title === title)) {
            return
        }
        
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
    
    // Show the pending reload toast
    function _showReloadToast() {
        if (!root._pendingReloadSource) return
        if (!root.shouldShowReloadToast()) {
            root._pendingReloadSource = ""
            return
        }
        
        const now = Date.now()
        // Check cooldown
        if (now - root._lastReloadToastTime < root._reloadCooldownMs) {
            root._pendingReloadSource = ""
            return
        }
        
        root._lastReloadToastTime = now
        const source = root._pendingReloadSource
        root._pendingReloadSource = ""
        
        if (source === "quickshell") {
            root.addToast(
                "Quickshell reloaded",
                "",
                "refresh",
                false,
                2000,
                "reload",
                Appearance.colors.colPrimary
            )
        } else if (source === "niri") {
            root.addToast(
                "Niri config reloaded",
                "",
                "settings",
                false,
                2000,
                "reload",
                Appearance.colors.colTertiary
            )
        }
    }
    
    // Single debounce timer for all reload events
    Timer {
        id: reloadDebounce
        interval: root._reloadDebounceMs
        onTriggered: {
            root._qsReloadInProgress = false
            root._showReloadToast()
        }
    }
    
    // Timer to clear QS reload flag after a longer period
    Timer {
        id: qsReloadClearTimer
        interval: 2000  // 2 seconds after QS reload, allow Niri toasts again
        onTriggered: {
            root._qsReloadInProgress = false
        }
    }

    // Quickshell reload signals
    Connections {
        target: Quickshell
        
        function onReloadCompleted() {
            // Mark that QS is reloading - this suppresses Niri toasts
            root._qsReloadInProgress = true
            qsReloadClearTimer.restart()
            
            // Quickshell reload takes priority
            root._pendingReloadSource = "quickshell"
            reloadDebounce.restart()
        }
        
        function onReloadFailed(error) {
            root._qsReloadInProgress = false
            root.addToast(
                "Quickshell reload failed",
                error,
                "error",
                true,
                8000,
                "error",
                Appearance.colors.colError
            )
        }
    }
    
    // Niri config reload signals
    Connections {
        target: NiriService
        
        function onConfigLoadFinished(ok, error) {
            if (ok) {
                // If QS just reloaded, ignore Niri's ConfigLoaded (it's from reconnection)
                if (root._qsReloadInProgress) {
                    return
                }
                
                // Only set pending if not already set to quickshell
                if (root._pendingReloadSource !== "quickshell") {
                    root._pendingReloadSource = "niri"
                    reloadDebounce.restart()
                }
            } else {
                // Errors always show immediately
                root.addToast(
                    "Niri config reload failed",
                    error || "Run 'niri validate' for details",
                    "error",
                    true,
                    8000,
                    "error",
                    Appearance.colors.colError
                )
            }
        }
    }
    
    LazyLoader {
        id: popupLoader
        
        PanelWindow {
            id: popup
            visible: root.toasts.length > 0 && !root.suppressOnScreenToasts
            exclusiveZone: 0
            anchors.top: true
            anchors.left: true
            anchors.right: true
            margins.top: 10
            
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:toast-manager"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
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
                        
                        Component.onCompleted: {
                            if (Appearance.animationsEnabled) {
                                entryAnim.start()
                            }
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
                            if (Appearance.animationsEnabled) {
                                exitAnim.start()
                            } else {
                                root.removeToast(modelData.id)
                            }
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
