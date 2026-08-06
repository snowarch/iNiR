import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Literal translation of AlbumScreen.kt — header Row(144dp art + title/subtitle),
// Play (filled) + Shuffle (outlined) buttons, then a numbered SongListItem track list.
StyledFlickable {
    id: root
    property var album: ({})          // InnerTube.albumPage shape
    readonly property var tracks: album?.tracks ?? []
    contentHeight: column.implicitHeight
    clip: true

    signal backRequested()
    signal playRequested(int index, bool shuffle)

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        // Back chevron.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.appBarHeight
            ITIconButton {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                symbol: "arrow_back"
                onClicked: root.backRequested()
            }
        }

        // Header.
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 12
            spacing: 16
            ITThumbnail {
                Layout.preferredWidth: ITDimens.albumThumbnailSize
                Layout.preferredHeight: ITDimens.albumThumbnailSize
                thumbnailUrl: root.album?.thumbnail ?? ""
                cornerRadius: Appearance.rounding.normal
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                StyledText {
                    Layout.fillWidth: true
                    text: root.album?.title ?? ""
                    font.family: Appearance.font.family.title
                    font.pixelSize: Appearance.font.pixelSize.title
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                }
                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const parts = [];
                        if (root.album?.artist) parts.push(root.album.artist);
                        if (root.album?.year) parts.push(root.album.year);
                        const n = root.tracks.length;
                        if (n > 0) parts.push(Translation.tr("%1 songs").arg(n));
                        return parts.join(" • ");
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSecondary
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                }
            }
        }

        // Play + Shuffle buttons.
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            Layout.bottomMargin: 12
            spacing: 12

            ITButton {
                Layout.fillWidth: true
                kind: "filled"
                icon: "play_arrow"
                label: Translation.tr("Play")
                onClicked: root.playRequested(0, false)
            }
            ITButton {
                Layout.fillWidth: true
                kind: "outlined"
                icon: "shuffle"
                label: Translation.tr("Shuffle")
                onClicked: root.playRequested(0, true)
            }
        }

        // Track list (numbered).
        Repeater {
            model: root.tracks
            delegate: ITSongListItem {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitWidth: column.width
                song: modelData
                albumIndex: index
                isActive: modelData.videoId === YtMusic.currentVideoId
                isPlaying: isActive && YtMusic.isPlaying
                onClicked: root.playRequested(index, false)
            }
        }
    }
}
