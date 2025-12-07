import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common

Scope {
    id: root

    // Window info captured when dialog is triggered
    property var targetWindow: null
    property bool dialogVisible: false
    property bool _pendingConfirmation: false
    
    // Read enabled state reactively
    property bool confirmEnabled: Config.options?.closeConfirm?.enabled ?? false
    
    // Initialize config if missing
    Component.onCompleted: {
        if (Config.ready && Config.options?.closeConfirm === undefined) {
            Config.setNestedValue("closeConfirm.enabled", false)
        }
    }
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready && Config.options?.closeConfirm === undefined) {
                Config.setNestedValue("closeConfirm.enabled", false)
            }
        }
    }

    // Process to get focused window from Niri
    Process {
        id: focusedWindowProc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: SplitParser {
            onRead: line => {
                if (!line || line.trim() === "") return
                
                try {
                    const windowData = JSON.parse(line)
                    if (windowData && windowData.id) {
                        const appId = windowData.app_id || ""
                        if (root._pendingConfirmation) {
                            root.targetWindow = windowData
                            root.dialogVisible = true
                            root._pendingConfirmation = false
                        } else {
                            NiriService.closeWindow(windowData.id)
                        }
                    }
                } catch (e) {
                    console.warn("[CloseConfirm] Failed to parse focused window:", e)
                }
            }
        }
    }

    IpcHandler {
        target: "closeConfirm"
        
        function trigger(): void {
            root._pendingConfirmation = root.confirmEnabled
            focusedWindowProc.running = true
        }
        
        function close(): void {
            root.dialogVisible = false
            root.targetWindow = null
        }
    }

    function confirmClose() {
        if (targetWindow) {
            NiriService.closeWindow(targetWindow.id)
        }
        dialogVisible = false
        targetWindow = null
    }

    function cancel() {
        dialogVisible = false
        targetWindow = null
    }

    Loader {
        active: root.dialogVisible

        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:closeConfirm"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                Loader {
                    anchors.fill: parent
                    sourceComponent: Config.options?.panelFamily === "waffle" ? waffleContent : iiContent
                    
                    Component {
                        id: iiContent
                        CloseConfirmContent {
                            targetWindow: root.targetWindow
                            onConfirm: root.confirmClose()
                            onCancel: root.cancel()
                        }
                    }
                    
                    Component {
                        id: waffleContent
                        WCloseConfirmContent {
                            targetWindow: root.targetWindow
                            onConfirm: root.confirmClose()
                            onCancel: root.cancel()
                        }
                    }
                }
            }
        }
    }
}
