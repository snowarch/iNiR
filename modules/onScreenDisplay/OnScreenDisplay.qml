import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property string protectionMessage: ""
    property bool initialized: false
    property var focusedScreen: CompositorService.isNiri
        ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen
        : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen

    property string currentIndicator: "volume"
    property bool _syncingOpenStates: false
    readonly property bool osdActive: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "indicators/VolumeIndicator.qml"
        },
        {
            id: "brightness",
            sourceUrl: "indicators/BrightnessIndicator.qml"
        },
        {
            id: "media",
            sourceUrl: "indicators/MediaIndicator.qml"
        },
        {
            id: "voiceSearch",
            sourceUrl: "indicators/VoiceSearchIndicator.qml"
        },
        {
            id: "keyboardLayout",
            sourceUrl: "indicators/KeyboardLayoutIndicator.qml"
        },
    ]

    function setOpenStates(volume, brightness, media, keyboardLayout) {
        root._syncingOpenStates = true;
        GlobalStates.osdVolumeOpen = volume;
        GlobalStates.osdBrightnessOpen = brightness;
        GlobalStates.osdMediaOpen = media;
        GlobalStates.osdKeyboardLayoutOpen = keyboardLayout;
        root._syncingOpenStates = false;
    }

    function hideOsd() {
        osdTimeout.stop();
        root.setOpenStates(false, false, false, false);
        root.protectionMessage = "";
    }

    function openIndicator(indicator, autoHide) {
        if (!initialized) return;
        root.currentIndicator = indicator;
        root.setOpenStates(
            indicator === "volume" || indicator === "voiceSearch",
            indicator === "brightness",
            indicator === "media",
            indicator === "keyboardLayout"
        );
        if (autoHide)
            osdTimeout.restart();
    }

    function triggerOsd() {
        root.openIndicator(root.currentIndicator, true);
    }

    function triggerMediaOsd() {
        if (!initialized) return;
        if (!(Config.options?.osd?.mediaEnabled ?? true)) return;
        if (!MprisController.activePlayer) return;
        root.openIndicator("media", true);
    }

    Timer {
        id: initDelay
        interval: 1500
        running: true
        onTriggered: root.initialized = true
    }

    Timer {
        id: osdTimeout
        interval: root.currentIndicator === "media" 
            ? (Config.options?.osd?.timeout ?? 2000) + 1500  // Longer for media
            : (Config.options?.osd?.timeout ?? 2000)
        repeat: false
        running: false
        onTriggered: {
            root.hideOsd();
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.protectionMessage = "";
            root.currentIndicator = "brightness";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready || GameMode.suppressNiriToast)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onMutedChanged() {
            if (!Audio.ready || GameMode.suppressNiriToast)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to protection triggers
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdVolumeOpen)
                return;
            root.currentIndicator = "volume";
            osdTimeout.restart();
        }
        function onOsdBrightnessOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdBrightnessOpen)
                return;
            root.currentIndicator = "brightness";
            osdTimeout.restart();
        }
        function onOsdMediaOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdMediaOpen)
                return;
            if (!(Config.options?.osd?.mediaEnabled ?? true)) {
                GlobalStates.osdMediaOpen = false;
                return;
            }
            root.currentIndicator = "media";
            osdTimeout.restart();
        }
        function onOsdKeyboardLayoutOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdKeyboardLayoutOpen)
                return;
            root.currentIndicator = "keyboardLayout";
            osdTimeout.restart();
        }
    }

    Connections {
        target: VoiceSearch
        function onRunningChanged() {
            if (VoiceSearch.running) {
                root.openIndicator("voiceSearch", false);
                osdTimeout.stop(); // Don't auto-hide while active
            } else {
                osdTimeout.restart();
            }
        }
    }

    Connections {
        target: KeyboardIndicators
        function onPopupSequenceChanged() {
            root.currentIndicator = "keyboardLayout";
            root.triggerOsd();
        }
    }

    Loader {
        id: osdLoader
        active: root.osdActive

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"
            screen: root.focusedScreen

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: root.currentIndicator === "keyboardLayout" ? true : !(Config.options?.bar?.bottom ?? false)
                bottom: root.currentIndicator === "keyboardLayout" ? false : Config.options?.bar?.bottom ?? false
            }
            mask: Region {
                item: osdValuesWrapper
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: Appearance.sizes.barHeight
                bottom: Appearance.sizes.barHeight
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight
            visible: root.osdActive

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                // Subtle open animation for the OSD, sliding from the bar edge
                transformOrigin: root.currentIndicator === "keyboardLayout" || !(Config.options?.bar?.bottom ?? false) ? Item.Top : Item.Bottom
                scale: root.osdActive ? 1.0 : 0.96
                opacity: root.osdActive ? 1.0 : 0.0
                Behavior on scale {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.hideOsd()
                    }

                    Column {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 0

                        Loader {
                            id: osdIndicatorLoader
                            source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl
                        }

                        Item {
                            id: protectionMessageWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitHeight: protectionMessageBackground.implicitHeight
                            implicitWidth: protectionMessageBackground.implicitWidth
                            opacity: root.protectionMessage !== "" ? 1 : 0

                            StyledRectangularShadow {
                                target: protectionMessageBackground
                            }
                            Rectangle {
                                id: protectionMessageBackground
                                anchors.centerIn: parent
                                color: Appearance.m3colors.m3error
                                property real padding: 10
                                implicitHeight: protectionMessageRowLayout.implicitHeight + padding * 2
                                implicitWidth: protectionMessageRowLayout.implicitWidth + padding * 2
                                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

                                RowLayout {
                                    id: protectionMessageRowLayout
                                    anchors.centerIn: parent
                                    MaterialSymbol {
                                        id: protectionMessageIcon
                                        text: "dangerous"
                                        iconSize: Appearance.font.pixelSize.hugeass
                                        color: Appearance.m3colors.m3onError
                                    }
                                    StyledText {
                                        id: protectionMessageTextWidget
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Appearance.m3colors.m3onError
                                        wrapMode: Text.Wrap
                                        text: root.protectionMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "osdVolume"

        function trigger(): void {
            root.triggerOsd();
        }

        function hide(): void {
            root.hideOsd();
        }

        function toggle(): void {
            GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen;
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "osdVolumeTrigger"
                description: "Triggers volume OSD on press"

                onPressed: {
                    root.triggerOsd();
                }
            }
            GlobalShortcut {
                name: "osdVolumeHide"
                description: "Hides volume OSD on press"

                onPressed: {
                    GlobalStates.osdVolumeOpen = false;
                }
            }
        }
    }
}
