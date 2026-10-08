import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root

    property bool initialized: false
    readonly property var targetScreens: {
        const list = Config.options?.osd?.screenList ?? []
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        // Fallback safety: stale monitor names should never hide the OSD everywhere.
        return matched.length > 0 ? matched : screens
    }
    property string currentIndicator: "volume"
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "VolumeOSD.qml",
            globalStateValue: "osdVolumeOpen"
        },
        {
            id: "brightness",
            sourceUrl: "BrightnessOSD.qml",
            globalStateValue: "osdBrightnessOpen"
        },
        {
            id: "media",
            sourceUrl: "MediaOSD.qml",
            globalStateValue: "osdMediaOpen"
        },
        {
            id: "keyboardLayout",
            sourceUrl: "KeyboardLayoutOSD.qml",
            globalStateValue: "osdKeyboardLayoutOpen"
        },
        {
            id: "connection",
            sourceUrl: "ConnectionOSD.qml",
            globalStateValue: "osdConnectionOpen"
        },
    ]
    readonly property bool topNotice: root.currentIndicator === "keyboardLayout" || root.currentIndicator === "connection"

    // Suppress OSD during startup and gamemode niri-reload transitions
    Timer {
        id: initDelay
        interval: 1500
        running: true
        onTriggered: root.initialized = true
    }

    function triggerBrightnessOsd() {
        root.currentIndicator = "brightness";
        GlobalStates.osdBrightnessOpen = true;
    }

    function triggerVolumeOSD() {
        root.currentIndicator = "volume";
        GlobalStates.osdVolumeOpen = true;
    }

    function triggerMediaOSD() {
        if (!(Config.options?.osd?.mediaEnabled ?? true))
            return;
        root.currentIndicator = "media";
        GlobalStates.osdMediaOpen = true;
    }

    function triggerConnectionOSD() {
        root.currentIndicator = "connection";
        GlobalStates.osdConnectionOpen = true;
    }

    function triggerKeyboardLayoutOSD() {
        root.currentIndicator = "keyboardLayout";
        GlobalStates.osdKeyboardLayoutOpen = true;
    }

    // Listen to brightness changes
    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.triggerBrightnessOsd();
        }
    }

    // Listen to volume changes
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (Audio.ready && root.initialized && !GameMode.suppressNiriToast)
                root.triggerVolumeOSD();
        }
        function onMutedChanged() {
            if (Audio.ready && root.initialized && !GameMode.suppressNiriToast)
                root.triggerVolumeOSD();
        }
    }

    // Media OSD is triggered via IPC only (not on every track change)
    // See services/MprisController.qml IpcHandler

    Connections {
        target: KeyboardIndicators
        function onPopupSequenceChanged() {
            if (!root.initialized)
                return;
            root.triggerKeyboardLayoutOSD();
        }
    }

    Connections {
        target: DeviceEvents
        function onHappened(event) {
            if (!root.initialized || GameMode.active)
                return;
            root.triggerConnectionOSD();
        }
    }

    // Open when global state changes
    Connections {
        target: GlobalStates

        function onOsdBrightnessOpenChanged() {
            if (GlobalStates.osdBrightnessOpen)
                panelLoader.active = true;
        }
        function onOsdVolumeOpenChanged() {
            if (GlobalStates.osdVolumeOpen)
                panelLoader.active = true;
        }
        function onOsdMediaOpenChanged() {
            if (GlobalStates.osdMediaOpen) {
                if (!(Config.options?.osd?.mediaEnabled ?? true)) {
                    GlobalStates.osdMediaOpen = false;
                    return;
                }
                root.currentIndicator = "media";
                panelLoader.active = true;
            }
        }
        function onOsdKeyboardLayoutOpenChanged() {
            if (GlobalStates.osdKeyboardLayoutOpen) {
                root.currentIndicator = "keyboardLayout";
                panelLoader.active = true;
            }
        }
        function onOsdConnectionOpenChanged() {
            if (GlobalStates.osdConnectionOpen) {
                root.currentIndicator = "connection";
                panelLoader.active = true;
            }
        }
    }

    // The actual thing
    Loader {
        id: panelLoader
        active: false
        onActiveChanged: {
            if (active) return;
            root.indicators.forEach(i => {
                GlobalStates[i.globalStateValue] = false;
            });
        }
        sourceComponent: Variants {
            model: root.targetScreens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:wOnScreenDisplay"
            WlrLayershell.layer: root.topNotice
                ? WlrLayer.Top
                : WlrLayer.Overlay
            anchors {
                top: root.topNotice ? true : !(Config.options?.waffles?.bar?.bottom ?? false)
                bottom: root.topNotice ? false : Config.options?.waffles?.bar?.bottom ?? false
            }
            mask: Region {
                item: osdIndicatorLoader
            }

            implicitWidth: osdIndicatorLoader.implicitWidth
            implicitHeight: osdIndicatorLoader.implicitHeight

            Loader {
                id: osdIndicatorLoader
                anchors.fill: parent
                source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl

                Connections {
                    target: osdIndicatorLoader.item
                    function onClosed() {
                        panelLoader.active = false;
                        GlobalStates[root.indicators.find(i => i.id === root.currentIndicator)?.globalStateValue] = false;
                    }
                }

                Behavior on source {
                    id: switchBehavior

                    SequentialAnimation {
                        id: switchAnim
                        // Animate close of current indicator
                        ScriptAction {
                            script: {
                                osdIndicatorLoader.item.close();
                            }
                        }
                        // Wait for close anim
                        PauseAnimation {
                            duration: osdIndicatorLoader.item.closeAnimDuration
                        }
                        PropertyAction {} // The source change happens here
                    }
                }
            }
        }
    }
    }

}
