pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

WBarAttachedPanelContent {
    id: root

    readonly property string action: GlobalStates.osdMediaAction
    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: player !== null
    readonly property string effectiveArtUrl: MprisController.isYtMusicActive ? YtMusic.currentThumbnail : (player?.trackArtUrl ?? "")
    readonly property string effectiveTitle: MprisController.isYtMusicActive ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: MprisController.isYtMusicActive ? YtMusic.currentArtist : (player?.trackArtist ?? "")

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.effectiveArtUrl
        title: root.effectiveTitle
        artist: root.effectiveArtist
        album: root.player?.trackAlbum ?? ""
        cacheDirectory: Directories.coverArt
    }

    property Timer timer: Timer {
        id: autoCloseTimer
        running: true
        interval: Config.options?.osd?.timeout ?? 2500
        repeat: false
        onTriggered: root.close()
    }

    // Restart timer when action changes (user pressed play/pause/next/prev again)
    Connections {
        target: GlobalStates
        function onOsdMediaActionChanged() {
            if (GlobalStates.osdMediaOpen)
                autoCloseTimer.restart()
        }
    }

    contentItem: WPane {
        screenX: root.panelScreenX + root.visualMargin
        screenY: root.panelScreenY + root.visualMargin
        screenWidth: root._screenW
        screenHeight: root._screenH
        contentItem: Item {
            implicitWidth: 300
            implicitHeight: 90

            Rectangle {
                anchors.fill: parent
                color: Looks.colors.bgPanelFooter
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                // Album art (larger, like ModernFlyouts)
                Rectangle {
                    Layout.preferredWidth: 70
                    Layout.preferredHeight: 70
                    radius: Looks.radius.medium
                    color: Looks.colors.bg1Base

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: artworkResolver.displaySource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(140, 140)
                        visible: artworkResolver.ready && status === Image.Ready

                        layer.enabled: visible
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artImage.width
                                height: artImage.height
                                radius: Looks.radius.medium
                            }
                        }
                    }

                    // Action overlay on album art
                    Rectangle {
                        anchors.fill: parent
                        radius: Looks.radius.medium
                        color: ColorUtils.transparentize(Looks.colors.bg0, 0.3)
                        visible: root.action !== ""

                        FluentIcon {
                            anchors.centerIn: parent
                            icon: root.action
                            implicitSize: 28
                            color: Looks.colors.fg
                        }
                    }

                    // Fallback when no art
                    FluentIcon {
                        anchors.centerIn: parent
                        icon: "music-note-2"
                        implicitSize: 28
                        color: Looks.colors.subfg
                        visible: (!artworkResolver.ready || artImage.status !== Image.Ready) && root.action === ""
                    }
                }

                // Info column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    // Title
                    WText {
                        Layout.fillWidth: true
                        text: StringUtils.cleanMusicTitle(root.player?.trackTitle) ?? Translation.tr("No media")
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    // Artist
                    WText {
                        Layout.fillWidth: true
                        text: root.player?.trackArtist ?? ""
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                    }

                    Item { Layout.fillHeight: true }

                    // Mini controls row
                    RowLayout {
                        spacing: 2

                        WBorderlessButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            enabled: MprisController.canGoPrevious
                            contentItem: FluentIcon {
                                anchors.centerIn: parent
                                icon: "previous"
                                implicitSize: 12
                                color: Looks.colors.fg
                            }
                            onClicked: {
                                GlobalStates.osdMediaAction = "previous"
                                MprisController.previous()
                                autoCloseTimer.restart()
                            }
                        }

                        WBorderlessButton {
                            implicitWidth: 32
                            implicitHeight: 28
                            contentItem: FluentIcon {
                                anchors.centerIn: parent
                                icon: root.player?.isPlaying ? "pause" : "play"
                                implicitSize: 14
                                color: Looks.colors.fg
                            }
                            onClicked: {
                                GlobalStates.osdMediaAction = root.player?.isPlaying ? "pause" : "play"
                                MprisController.togglePlaying()
                                autoCloseTimer.restart()
                            }
                        }

                        WBorderlessButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            enabled: MprisController.canGoNext
                            contentItem: FluentIcon {
                                anchors.centerIn: parent
                                icon: "next"
                                implicitSize: 12
                                color: Looks.colors.fg
                            }
                            onClicked: {
                                GlobalStates.osdMediaAction = "next"
                                MprisController.next()
                                autoCloseTimer.restart()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Current state indicator
                        FluentIcon {
                            icon: root.player?.isPlaying ? "speaker" : "speaker-mute"
                            implicitSize: 12
                            color: Looks.colors.subfg
                        }
                    }
                }
            }
        }
    }
}
