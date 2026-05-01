pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Rectangle {
    id: root
    implicitHeight: 120
    implicitWidth: 358
    color: Looks.colors.bgPanelBody

    readonly property var activePlayer: MprisController.activePlayer
    readonly property string effectiveArtUrl: MprisController.isYtMusicActive ? YtMusic.currentThumbnail : (activePlayer?.trackArtUrl ?? "")
    readonly property string effectiveTitle: MprisController.isYtMusicActive ? YtMusic.currentTitle : (activePlayer?.trackTitle ?? "")
    readonly property string effectiveArtist: MprisController.isYtMusicActive ? YtMusic.currentArtist : (activePlayer?.trackArtist ?? "")

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.effectiveArtUrl
        title: root.effectiveTitle
        artist: root.effectiveArtist
        album: root.activePlayer?.trackAlbum ?? ""
        cacheDirectory: Directories.coverArt
    }

    // Volume feedback overlay
    Rectangle {
        id: volumeOverlay
        anchors.centerIn: parent
        width: 80
        height: 80
        radius: Looks.radius.medium
        color: ColorUtils.transparentize(Looks.colors.bg0, 0.15)
        opacity: 0
        visible: opacity > 0
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 4

            FluentIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: root.activePlayer?.volume > 0 ? "speaker" : "speaker-mute"
                implicitSize: 24
            }

            WText {
                Layout.alignment: Qt.AlignHCenter
                text: Math.round((root.activePlayer?.volume ?? 0) * 100) + "%"
                font.pixelSize: Looks.font.pixelSize.normal
                font.weight: Font.DemiBold
            }
        }

        Behavior on opacity {
            animation: Looks.transition.opacity
        }

        Timer {
            id: volumeHideTimer
            interval: 1000
            onTriggered: volumeOverlay.opacity = 0
        }
    }

    // Scroll to change player volume
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (!MprisController.canChangeVolume) return
            const step = 0.05
            const current = MprisController.getVolume()
            if (wheel.angleDelta.y > 0)
                MprisController.setVolume(Math.min(1, current + step))
            else if (wheel.angleDelta.y < 0)
                MprisController.setVolume(Math.max(0, current - step))
            
            // Show volume feedback
            volumeOverlay.opacity = 1
            volumeHideTimer.restart()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Album art
        Rectangle {
            Layout.preferredWidth: 88
            Layout.preferredHeight: 88
            radius: Looks.radius.medium
            color: Looks.colors.bg1Base
            clip: true

            StyledImage {
                id: artImage
                anchors.fill: parent
                source: artworkResolver.displaySource
                fillMode: Image.PreserveAspectCrop
                cache: false
            }

            FluentIcon {
                anchors.centerIn: parent
                icon: "music-note-2"
                implicitSize: 32
                visible: !artworkResolver.ready || artImage.status !== Image.Ready
            }
        }

        // Info + controls
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Track info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    WText {
                        Layout.fillWidth: true
                        text: StringUtils.cleanMusicTitle(root.activePlayer?.trackTitle) || Translation.tr("Not playing")
                        font.pixelSize: Looks.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    // Player app icon
                    IconImage {
                        id: playerIcon
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        source: {
                            const de = root.activePlayer?.desktopEntry ?? "";
                            const identity = (root.activePlayer?.identity ?? "").toLowerCase();
                            
                            // Special cases for common players
                            if (identity.includes("spotify")) return Quickshell.iconPath("spotify", "");
                            if (identity.includes("firefox")) return Quickshell.iconPath("firefox", "");
                            if (identity.includes("chrome")) return Quickshell.iconPath("google-chrome", "");
                            if (identity.includes("chromium")) return Quickshell.iconPath("chromium", "");
                            if (identity.includes("vlc")) return Quickshell.iconPath("vlc", "");
                            if (identity.includes("mpv")) return Quickshell.iconPath("mpv", "");
                            if (identity.includes("youtube")) return Quickshell.iconPath("youtube", "");
                            
                            // Try desktop entry icon
                            const entry = DesktopEntries.byId(de) ?? DesktopEntries.heuristicLookup(de);
                            if (entry?.icon) return AppSearch.resolveIcon(entry.icon, "");
                            
                            // Fallback to identity as icon name
                            if (identity) return Quickshell.iconPath(identity, "");
                            
                            return "";
                        }
                        // Only show if loaded successfully
                        visible: status === Image.Ready
                    }
                }

                WText {
                    Layout.fillWidth: true
                    text: root.activePlayer?.trackArtist || ""
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.fg1
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            Item { Layout.fillHeight: true }

            // Controls
            RowLayout {
                spacing: 4

                MediaBtn {
                    iconName: "previous"
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                }
                MediaBtn {
                    iconName: root.activePlayer?.isPlaying ? "pause" : "play"
                    size: 36
                    iconSize: 18
                    onClicked: MprisController.togglePlaying()
                }
                MediaBtn {
                    iconName: "next"
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()
                }
            }
        }
    }

    component MediaBtn: WBorderlessButton {
        property string iconName
        property int size: 32
        property int iconSize: 14
        implicitWidth: size
        implicitHeight: size
        contentItem: FluentIcon {
            anchors.centerIn: parent
            icon: parent.iconName
            implicitSize: parent.iconSize
        }
    }
}
