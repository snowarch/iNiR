import QtQuick
import qs
import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    // Window captured at the moment of trigger (prevents race condition)
    property var targetWindow: null
    property var dialogScreen: null
    property bool dialogVisible: false

    // Debounce to prevent double-trigger
    property bool _busy: false
    Timer {
        id: debounce
        interval: 200
        onTriggered: root._busy = false
    }

    // Config state
    readonly property bool confirmEnabled: Config.options?.closeConfirm?.enabled ?? false

    // Fallback: get focused window directly from niri when activeWindow is stale
    Process {
        id: focusedWindowProc
        command: ["niri", "msg", "-j", "focused-window"]
        stdout: SplitParser {
            onRead: line => {
                if (!line?.trim())
                    return;
                try {
                    const win = JSON.parse(line);
                    if (win?.id)
                        root.processWindow(win);
                } catch (e) {}
            }
        }
    }

    function processWindow(win): void {
        if (root.confirmEnabled) {
            root.targetWindow = win;
            root.dialogScreen = GlobalStates.focusedScreen;
            root.dialogVisible = true;
        } else {
            root.closeWindowFast(win);
        }
    }

    function _acceptTrigger(): bool {
        if (root._busy)
            return false;
        root._busy = true;
        debounce.restart();
        return true;
    }

    IpcHandler {
        target: "closeConfirm"

        function trigger(): void {
            if (!root._acceptTrigger())
                return;

            // Try cached activeWindow first, fallback to niri query
            const win = NiriService.activeWindow;
            if (win?.id) {
                root.processWindow(win);
            } else {
                focusedWindowProc.running = true;
            }
        }

        function triggerWindow(windowId: int, appId: string): void {
            if (windowId <= 0 || !root._acceptTrigger())
                return;
            root.processWindow({
                id: windowId,
                app_id: appId
            });
        }

        function close(): void {
            root.dialogVisible = false;
            root.targetWindow = null;
            root.dialogScreen = null;
        }
    }

    function closeWindowFast(win): void {
        if (!win?.id)
            return;
        const appId = String(win?.app_id ?? "").toLowerCase();
        if (appId === "spotify") {
            MinimizedWindows.minimize(win.id);
            return;
        }
        // Use niri msg directly - more reliable than socket IPC for some apps
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.id)]);
    }

    function confirmClose(): void {
        if (targetWindow) {
            closeWindowFast(targetWindow);
        }
        dialogVisible = false;
        targetWindow = null;
        dialogScreen = null;
    }

    function cancel(): void {
        dialogVisible = false;
        targetWindow = null;
        dialogScreen = null;
    }

    // Dialog UI
    Loader {
        active: root.dialogVisible

        sourceComponent: PanelWindow {
            screen: root.dialogScreen ?? GlobalStates.focusedScreen

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
                id: contentLoader
                anchors.fill: parent
                focus: true
                // Both contents declare targetWindow as required, so they must be
                // instantiated from an inline Component. A Loader source URL cannot
                // initialize required properties and fails to Loader.Error, leaving
                // this keyboard-exclusive fullscreen window with no way out.
                sourceComponent: Config.options?.panelFamily === "waffle" ? waffleContent : iiContent
                onLoaded: if (item) item.forceActiveFocus()

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
