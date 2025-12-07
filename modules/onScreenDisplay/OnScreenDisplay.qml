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
        ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0]
        : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    property string currentIndicator: "volume"
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
    ]

    function triggerOsd() {
        if (!initialized) return;
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.restart();
    }

    function triggerMediaOsd() {
        if (!initialized) return;
        if (!MprisController.activePlayer) return;
        root.currentIndicator = "media";
        GlobalStates.osdMediaOpen = true;
        osdTimeout.restart();
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
            GlobalStates.osdVolumeOpen = false;
            GlobalStates.osdMediaOpen = false;
            root.protectionMessage = "";
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
            if (!Audio.ready)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onMutedChanged() {
            if (!Audio.ready)
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

    // Media OSD is triggered via IPC only (not on every track change)
    // See services/MprisController.qml IpcHandler

    Loader {
        id: osdLoader
        active: GlobalStates.osdVolumeOpen || GlobalStates.osdMediaOpen

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"

            Connections {
                target: root
                function onFocusedScreenChanged() {
                    osdRoot.screen = root.focusedScreen;
                }
            }

            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: !(Config.options?.bar?.bottom ?? false)
                bottom: Config.options?.bar?.bottom ?? false
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
            visible: osdLoader.active

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                // Subtle open animation for the OSD, sliding from the bar edge
                transformOrigin: !(Config.options?.bar?.bottom ?? false) ? Item.Top : Item.Bottom
                scale: GlobalStates.osdVolumeOpen ? 1.0 : 0.96
                opacity: GlobalStates.osdVolumeOpen ? 1.0 : 0.0
                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
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
                        onEntered: GlobalStates.osdVolumeOpen = false
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
                                radius: Appearance.rounding.normal

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
            GlobalStates.osdVolumeOpen = false;
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
