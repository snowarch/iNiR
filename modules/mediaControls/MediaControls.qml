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
    property bool _presentedOpen: false
    Component.onCompleted: {
        if (GlobalStates.mediaControlsOpen)
            Qt.callLater(() => { root._presentedOpen = GlobalStates.mediaControlsOpen })
    }
    Connections {
        target: GlobalStates
        function onMediaControlsOpenChanged() {
            if (GlobalStates.mediaControlsOpen)
                Qt.callLater(() => { root._presentedOpen = GlobalStates.mediaControlsOpen })
            else
                root._presentedOpen = false
        }
    }
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    // Use displayPlayers - includes title/position dedup to prevent duplicates (e.g. plasma-browser-integration)
    readonly property var allPlayers: MprisController.displayPlayers
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    readonly property real dockHeight: Config.options?.dock?.height ?? 60
    readonly property real dockMargin: Appearance.sizes.elevationMargin + Appearance.sizes.hyprlandGapsOut
    property real popupRounding: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.large
    readonly property bool visualizerActive: mediaControlsLoader.active && MprisController.isPlaying
    property var focusedScreen: GlobalStates.focusedScreen ?? (CompositorService.isNiri
        ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen
        : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen)
    property var targetScreens: screensFromList(
        Config.options?.media?.screenList ?? [])
    readonly property string keyboardScreenName: {
        const preferred = String(root.focusedScreen?.name ?? "")
        if (root.targetScreens.some(screen => String(screen?.name ?? "") === preferred))
            return preferred
        return String(root.targetScreens[0]?.name ?? "")
    }

    function screensFromList(list) {
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen =>
            list.includes(String(screen?.name ?? "")))
        return matched.length > 0 ? matched : screens
    }

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
            interval: 350
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

        sourceComponent: Variants {
            model: root.targetScreens

            PanelWindow {
                id: mediaControlsRoot
                required property var modelData
                visible: true
                screen: modelData

                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                color: "transparent"
                WlrLayershell.namespace: "quickshell:mediaControls"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: GlobalStates.mediaControlsOpen
                    && String(mediaControlsRoot.screen?.name ?? "") === root.keyboardScreenName
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
                        if (Quickshell.env("QS_DEBUG") === "1") console.log("MediaControls: Forcing focus")
                        inputScope.forceActiveFocus()
                    }
                }

                Keys.onSpacePressed: {
                    if (Quickshell.env("QS_DEBUG") === "1") console.log("MediaControls: Space pressed")
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
                    // ZZZ panel backdrop removed from the media popup: the heavy
                    // poster frame behind a media card read as cluttered. The card
                    // itself now carries the clean ZZZ plate (see PlayerControl).
                    readonly property real zzzFrameInset: 0
                    width: root.widgetWidth + zzzFrameInset * 2
                    height: playerColumnLayout.implicitHeight + zzzFrameInset * 2
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Dock mode rises from its final edge instead of travelling
                    // through the whole output. The bounded offset keeps the
                    // entrance coherent for every player preset and stack height.
                    readonly property real screenH: mediaControlsRoot.screen?.height ?? 1080
                    readonly property real targetY: Math.max(root.dockMargin,
                        screenH - height - root.dockHeight - root.dockMargin - 5)
                    readonly property real revealDistance: Math.min(72,
                        Math.max(36, height * 0.12))
                    readonly property real hiddenY: targetY + revealDistance

                    y: hiddenY
                    opacity: 0
                    scale: 0.975
                    transformOrigin: Item.Bottom

                    states: State {
                        name: "visible"
                        when: root._presentedOpen
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
                            NumberAnimation { properties: "y"; duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                            NumberAnimation { properties: "opacity"; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            NumberAnimation { properties: "scale"; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        },
                        Transition {
                            from: "visible"
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { properties: "y"; duration: Appearance.animation.elementMoveExit.duration; easing.type: Appearance.animation.elementMoveExit.type; easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve }
                            NumberAnimation { properties: "opacity"; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            NumberAnimation { properties: "scale"; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    ]

                    ColumnLayout {
                        id: playerColumnLayout
                        anchors.fill: parent
                        anchors.margins: cardArea.zzzFrameInset
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
                                screenX: cardArea.x + (mediaControlsRoot.width - cardArea.width) / 2 + cardArea.zzzFrameInset
                                screenY: cardArea.y + cardArea.zzzFrameInset + index * (root.widgetHeight - Appearance.sizes.elevationMargin)
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
                                color: Appearance.zzzEverywhere ? Appearance.zzz.paper
                                     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                     : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
                                     : Appearance.colors.colLayer0
                                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                radius: root.popupRounding
                                border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick
                                    : Appearance.inirEverywhere || Appearance.auroraEverywhere ? 1 : 0
                                Behavior on border.width {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                                border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                                            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder
                                            : "transparent"
                                Behavior on border.color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                                property real padding: 20
                                implicitWidth: placeholderLayout.implicitWidth + padding * 2
                                implicitHeight: placeholderLayout.implicitHeight + padding * 2

                                ZzzGraphicPlate {
                                    anchors.fill: parent
                                    accentColor: Appearance.zzz.tertiary
                                }

                                ColumnLayout {
                                    id: placeholderLayout
                                    anchors.centerIn: parent

                                    MascotImage {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: 112
                                        Layout.preferredHeight: 132
                                        surface: "mediaControls"
                                        fallbackSurface: "emptyStates"
                                        pose: "headphone-groove-full-loop"
                                    }

                                    StyledText {
                                        text: Translation.tr("No active player")
                                        font.pixelSize: Appearance.font.pixelSize.large
                                        font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Normal
                                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                                            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                    StyledText {
                                        color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                            : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                        text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
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
    }

}
