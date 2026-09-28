import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overlay
import qs.modules.ii.sidebarRight.volumeMixer
import qs.modules.iris.style
import qs.modules.iris.stage
import Quickshell.Services.Mpris

StyledOverlayWidget {
    id: root
    minimumWidth: 300
    minimumHeight: 380

    contentItem: OverlayBackground {
        radius: root.contentRadius
        property real padding: 6

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: parent.padding
            }
            spacing: 8

            OverlaySegments {
                visible: OverlayLook.iris
                Layout.fillWidth: true
                segments: [{ label: "Output", glyph: "media_output" }, { label: "Input", glyph: "mic" }, { label: "Music", glyph: "music_note" }]
                currentIndex: tabBar.currentIndex
                onActivated: index => tabBar.currentIndex = index
            }
            SecondaryTabBar {
                id: tabBar
                visible: !OverlayLook.iris

                currentIndex: Persistent.states.overlay.volumeMixer.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.volumeMixer.tabIndex = tabBar.currentIndex;
                }

                SecondaryTabButton {
                    buttonIcon: "media_output"
                    buttonText: Translation.tr("Output")
                }
                SecondaryTabButton {
                    buttonIcon: "mic"
                    buttonText: Translation.tr("Input")
                }
                SecondaryTabButton {
                    buttonIcon: "music_note"
                    buttonText: Translation.tr("Music")
                }
            }
            SwipeView {
                id: swipeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: Persistent.states.overlay.volumeMixer.tabIndex
                onCurrentIndexChanged: {
                    Persistent.states.overlay.volumeMixer.tabIndex = swipeView.currentIndex;
                }
                clip: true

                PaddedVolumeDialogContent {
                    isSink: true
                    irisKind: "sound"
                }
                PaddedVolumeDialogContent {
                    isSink: false
                    irisKind: "mic"
                }
                Item {
                    MusicControlContent {
                        anchors.fill: parent
                        visible: !OverlayLook.iris
                    }
                    IrisCardPage {
                        anchors.fill: parent
                        visible: OverlayLook.iris
                        kind: "media"
                        bleeds: true
                    }
                }
            }
        }
    }

    component PaddedVolumeDialogContent: Item {
        id: paddedVolumeDialogContent
        property alias isSink: volDialogContent.isSink
        property string irisKind: ""
        property real padding: 12
        implicitWidth: volDialogContent.implicitWidth + padding * 2
        implicitHeight: volDialogContent.implicitHeight + padding * 2

        VolumeDialogContent {
            id: volDialogContent
            visible: !OverlayLook.iris
            anchors {
                fill: parent
                margins: paddedVolumeDialogContent.padding
            }
            dialogShown: SwipeView.isCurrentItem && !OverlayLook.iris
        }
        IrisCardPage {
            anchors.fill: parent
            visible: OverlayLook.iris
            kind: paddedVolumeDialogContent.irisKind
        }
    }

    component IrisCardPage: Flickable {
        id: cardPage
        property string kind: ""
        property bool bleeds: false
        readonly property real pad: cardPage.bleeds ? 0 : Math.round(14 * IrisStyle.density)
        clip: true
        contentWidth: width
        contentHeight: (cardLoader.item?.implicitHeight ?? 0) + cardPage.pad * 2
        boundsBehavior: Flickable.StopAtBounds
        Loader {
            id: cardLoader
            active: cardPage.visible && cardPage.kind.length > 0
            x: cardPage.pad
            y: cardPage.pad
            width: cardPage.width - cardPage.pad * 2
            sourceComponent: IrisCardContent {
                kind: cardPage.kind
            }
        }
    }

    component MusicControlContent: Item {
        id: musicContent

        readonly property MprisPlayer activePlayer: MprisController.activePlayer
        readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

        // Datos de carátula (cover art) y progreso para la pestaña Music
        property var artUrl: activePlayer?.trackArtUrl
        property string artDownloadLocation: Directories.coverArt
        readonly property bool downloaded: MediaArtwork.ready
        property string displayedArtFilePath: MediaArtwork.displaySource

        function checkAndDownloadArt() {
            MediaArtwork.refresh()
        }

        function stepVolume(delta: real): void {
            if (!MprisController.canChangeVolume)
                return
            MprisController.setVolume(MprisController.getVolume() + delta)
        }

        onVisibleChanged: {
            if (visible && artUrl) {
                checkAndDownloadArt()
            }
        }

        Timer {
            running: activePlayer?.playbackState == MprisPlaybackState.Playing
            interval: Config.options?.resources?.updateInterval ?? 3000
            repeat: true
            onTriggered: activePlayer?.positionChanged()
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    id: coverFrame
                    implicitWidth: 96
                    implicitHeight: 96
                    radius: OverlayLook.roundingSmall
                    color: OverlayLook.colLayer2

                    StyledImage {
                        anchors.fill: parent
                        opacity: musicContent.displayedArtFilePath !== "" && status !== Image.Error ? 1 : 0
                        visible: opacity > 0
                        source: musicContent.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        opacity: musicContent.displayedArtFilePath === "" ? 1 : 0
                        visible: opacity > 0
                        text: "music_note"
                        iconSize: Appearance.font.pixelSize.huge
                        color: OverlayLook.colOnLayer2
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        elide: Text.ElideRight
                        text: musicContent.cleanedTitle
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: OverlayLook.colSubtext
                        elide: Text.ElideRight
                        text: activePlayer?.trackArtist || ""
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: OverlayLook.colSubtext
                        elide: Text.ElideRight
                        text: MprisController.lengthOf(activePlayer) > 0
                              ? `${StringUtils.friendlyTimeForSeconds(MprisController.positionOf(activePlayer))} / ${StringUtils.friendlyTimeForSeconds(MprisController.lengthOf(activePlayer))}`
                              : ""
                    }

                    StyledProgressBar {
                        Layout.fillWidth: true
                        wavy: activePlayer?.isPlaying ?? false
                        highlightColor: OverlayLook.colPrimary
                        trackColor: OverlayLook.colSecondaryContainer
                        value: MprisController.lengthOf(activePlayer) > 0
                               ? (MprisController.positionOf(activePlayer) / MprisController.lengthOf(activePlayer))
                               : 0
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                RippleButton {
                    enabled: MprisController.canGoPrevious
                    colBackground: OverlayLook.colLayer3
                    colBackgroundHover: OverlayLook.colLayer3Hover
                    colRipple: OverlayLook.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 40
                    implicitWidth: 40
                    onClicked: MprisController.previous()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        iconSize: 22
                    }
                }

                RippleButton {
                    enabled: MprisController.canTogglePlaying
                    colBackground: OverlayLook.colLayer3
                    colBackgroundHover: OverlayLook.colLayer3Hover
                    colRipple: OverlayLook.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 44
                    implicitWidth: 44
                    onClicked: MprisController.togglePlaying()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: MprisController.isPlaying ? "pause" : "play_arrow"
                        iconSize: 26
                    }
                }

                RippleButton {
                    enabled: MprisController.canGoNext
                    colBackground: OverlayLook.colLayer3
                    colBackgroundHover: OverlayLook.colLayer3Hover
                    colRipple: OverlayLook.colLayer3Active
                    buttonRadius: height / 2
                    implicitHeight: 40
                    implicitWidth: 40
                    onClicked: MprisController.next()

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"
                        iconSize: 22
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                if (!MprisController.canChangeVolume)
                    return
                const verticalDelta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                if (verticalDelta === 0)
                    return
                musicContent.stepVolume(verticalDelta > 0 ? 0.05 : -0.05)
                event.accepted = true
            }
        }
    }
}
