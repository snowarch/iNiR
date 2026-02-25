pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool visible: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    // Use displayPlayers - includes title/position dedup to prevent duplicates (e.g. plasma-browser-integration)
    readonly property var allPlayers: MprisController.displayPlayers
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    readonly property real dockHeight: Config.options?.dock?.height ?? 60
    readonly property real dockMargin: Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut
    property real popupRounding: Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
    readonly property bool visualizerActive: mediaControlsLoader.active && (root.allPlayers?.length ?? 0) > 0

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

    Loader {
        id: mediaControlsLoader
        active: GlobalStates.mediaControlsOpen || closingTimer.running

        Timer {
            id: closingTimer
            interval: Appearance.animationsEnabled ? 350 : 0
        }

        Connections {
            target: GlobalStates
            function onMediaControlsOpenChanged() {
                if (!GlobalStates.mediaControlsOpen) {
                    closingTimer.restart()
                } else {
                    closingTimer.stop()
                }
            }
        }

        sourceComponent: PanelWindow {
            id: mediaControlsRoot
            visible: true

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mediaControls"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.mediaControlsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Click outside to close - covers entire screen
            FocusScope {
                id: inputScope
                anchors.fill: parent
                focus: true

                Component.onCompleted: focusTimer.start()

                Timer {
                    id: focusTimer
                    interval: 100
                    repeat: false
                    onTriggered: {
                        console.log("MediaControls: Forcing focus")
                        inputScope.forceActiveFocus()
                    }
                }

                Keys.onSpacePressed: {
                    console.log("MediaControls: Space pressed")
                    if (root.activePlayer?.canTogglePlaying) {
                        root.activePlayer.togglePlaying();
                    }
                }

                Keys.onEscapePressed: {
                    GlobalStates.mediaControlsOpen = false;
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.mediaControlsOpen = false
                }

                Item {
                    id: cardArea
                    width: root.widgetWidth
                height: playerColumnLayout.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter

                // Use screen height for reliable off-screen position
                readonly property real screenH: mediaControlsRoot.screen?.height ?? 1080
                readonly property real targetY: screenH - height - root.dockHeight - root.dockMargin - 5

                y: screenH + 50
                opacity: 0
                scale: 0.9
                transformOrigin: Item.Bottom

                states: State {
                    name: "visible"
                    when: GlobalStates.mediaControlsOpen
                    PropertyChanges {
                        target: cardArea
                        y: cardArea.targetY
                        opacity: 1
                        scale: 1
                    }
                }

                transitions: [
                    Transition {
                        to: "visible"
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { properties: "y"; duration: 350; easing.type: Easing.OutQuint }
                        NumberAnimation { properties: "opacity"; duration: 250; easing.type: Easing.OutCubic }
                        NumberAnimation { properties: "scale"; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    },
                    Transition {
                        from: "visible"
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.InQuint }
                        NumberAnimation { properties: "opacity"; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation { properties: "scale"; duration: 250; easing.type: Easing.InBack; easing.overshoot: 1.0 }
                    }
                ]

                ColumnLayout {
                    id: playerColumnLayout
                    anchors.fill: parent
                    spacing: 8

                    Repeater {
                        model: root.allPlayers
                        delegate: PlayerControl {
                            id: playerDelegate
                            required property MprisPlayer modelData
                            required property int index

                            player: modelData
                            visualizerPoints: root.visualizerPoints
                            implicitWidth: root.widgetWidth
                            implicitHeight: root.widgetHeight
                            radius: root.popupRounding
                            screenX: cardArea.x + (mediaControlsRoot.width - cardArea.width) / 2
                            screenY: cardArea.y + index * (root.widgetHeight - Appearance.sizes.elevationMargin)
                        }
                    }

                    Item { // No player placeholder
                        Layout.fillWidth: true
                        visible: root.allPlayers.length === 0
                        implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
                        implicitHeight: placeholderBackground.implicitHeight + Appearance.sizes.elevationMargin

                        StyledRectangularShadow {
                            target: placeholderBackground
                            visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
                        }

                        Rectangle {
                            id: placeholderBackground
                            anchors.centerIn: parent
                            color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                 : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
                                 : Appearance.colors.colLayer0
                            radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge : root.popupRounding
                            border.width: Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                                        : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                                        : "transparent"
                            property real padding: 20
                            implicitWidth: placeholderLayout.implicitWidth + padding * 2
                            implicitHeight: placeholderLayout.implicitHeight + padding * 2

                            ColumnLayout {
                                id: placeholderLayout
                                anchors.centerIn: parent

                                StyledText {
                                    text: Translation.tr("No active player")
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                                }
                                StyledText {
                                    color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                                    text: Translation.tr("Make sure your player has MPRIS support\\nor try turning off duplicate player filtering")
                                    font.pixelSize: Appearance.font.pixelSize.small
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
        target: "mediaControls"

        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
            if (GlobalStates.mediaControlsOpen)
                Notifications.timeoutAll();
        }

        function close(): void {
            GlobalStates.mediaControlsOpen = false;
        }

        function open(): void {
            GlobalStates.mediaControlsOpen = true;
            Notifications.timeoutAll();
        }
    }
    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "mediaControlsToggle"
                description: "Toggles media controls on press"

                onPressed: {
                    GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
                }
            }
            GlobalShortcut {
                name: "mediaControlsOpen"
                description: "Opens media controls on press"

                onPressed: {
                    GlobalStates.mediaControlsOpen = true;
                }
            }
            GlobalShortcut {
                name: "mediaControlsClose"
                description: "Closes media controls on press"

                onPressed: {
                    GlobalStates.mediaControlsOpen = false;
                }
            }
            GlobalShortcut {
                name: "mediaControlsPlayPause"
                description: "Toggles play/pause when media controls are open"

                onPressed: {
                    if (GlobalStates.mediaControlsOpen && activePlayer?.canTogglePlaying) {
                        activePlayer.togglePlaying();
                    }
                }
            }
        }
    }
}
