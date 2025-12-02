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

    // Scroll to change player volume
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (!root.activePlayer?.volumeSupported) return
            const step = 0.05
            if (wheel.angleDelta.y > 0)
                root.activePlayer.volume = Math.min(1, root.activePlayer.volume + step)
            else if (wheel.angleDelta.y < 0)
                root.activePlayer.volume = Math.max(0, root.activePlayer.volume - step)
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
                source: MprisController.activeTrack?.artUrl || ""
                fillMode: Image.PreserveAspectCrop
            }

            FluentIcon {
                anchors.centerIn: parent
                icon: "music-note-2"
                implicitSize: 32
                visible: !artImage.source || artImage.status !== Image.Ready
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
                            if (entry?.icon) return Quickshell.iconPath(entry.icon, "");
                            
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
                    onClicked: root.activePlayer?.previous()
                }
                MediaBtn {
                    iconName: root.activePlayer?.isPlaying ? "pause" : "play"
                    size: 36
                    iconSize: 18
                    onClicked: root.activePlayer?.togglePlaying()
                }
                MediaBtn {
                    iconName: "next"
                    onClicked: root.activePlayer?.next()
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
