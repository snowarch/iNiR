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

    /// Close window confirmation dialog. Shows a prompt before closing the focused window. Useful if you're the type
    /// who accidentally closes things and then regrets it.
    ///
    /// ```kdl
    /// Mod+Q repeat=false allow-inhibiting=false { spawn "inir" "close-window"; }
    /// ```
    ///
    /// By default, confirmation is disabled (closes immediately). Enable it in settings or config:
    ///
    /// ```json
    /// "closeConfirm": {
    ///   "enabled": true
    /// }
    /// ```
    IpcHandler {
        target: "closeConfirm"

        /// Show close confirmation for focused window
        function trigger(): void {
            if (!root._acceptTrigger())
                return;

            // Try cached activeWindow first, fallback to niri query
            const win = NiriService.activeWindow ?? (CompositorService.niriNative ? null : NiriService.windows.find(w => w.is_focused));
            if (win?.id) {
                root.processWindow(win);
            } else if (CompositorService.niriNative) {
                focusedWindowProc.running = true;
            }
        }

        /// Close or confirm the exact window captured by `inir close-window`
        function triggerWindow(windowId: int, appId: string): void {
            if (windowId <= 0 || !root._acceptTrigger())
                return;
            root.processWindow({
                id: windowId,
                app_id: appId
            });
        }

        /// Dismiss the dialog without closing
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
        if (CompositorService.niriNative)
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.id)]);
        else
            NiriService.closeWindow(win.id);
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
                // A family draws its own confirmation (Plugins part "closeConfirm"); Material's is the shared one.
                // Every content declares targetWindow as required: a family's file loads through setSource with it
                // as an initial property, since a bare source URL fails to Loader.Error and would leave this
                // keyboard-exclusive fullscreen window with no way out.
                readonly property string familySource: Plugins.part(Plugins.active, "closeConfirm")
                function pick(): void {
                    if (familySource.length > 0) setSource(familySource, { targetWindow: root.targetWindow })
                    else sourceComponent = iiContent
                }
                Component.onCompleted: pick()
                onFamilySourceChanged: pick()
                onLoaded: if (item) item.forceActiveFocus()

                Binding {
                    target: contentLoader.item
                    when: contentLoader.item !== null
                    property: "targetWindow"
                    value: root.targetWindow
                }
                Connections {
                    target: contentLoader.item
                    ignoreUnknownSignals: true
                    function onConfirm(): void { root.confirmClose() }
                    function onCancel(): void { root.cancel() }
                }

                Component {
                    id: iiContent
                    CloseConfirmContent {
                        targetWindow: root.targetWindow
                    }
                }
            }
        }
    }
}
