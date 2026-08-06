import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Translation of OnlineSearchResult.kt — a vertical list of results. Songs render as
// SongListItems (tap to play); albums/artists/playlists render as ListItems (tap to open the
// detail screen). Results come through YtMusic.searchResults (routed via InnerTube), filtered
// by the active search filter chip.
StyledFlickable {
    id: root
    property var results: []
    contentHeight: column.implicitHeight
    clip: true

    signal playRequested(int index)
    signal albumRequested(string browseId)
    signal artistRequested(string browseId)
    signal playlistRequested(string playlistId)

    function _open(item) {
        switch (item.type) {
            case "album": if (item.browseId) root.albumRequested(item.browseId); break;
            case "artist": if (item.browseId) root.artistRequested(item.browseId); break;
            default: if (item.playlistId || item.browseId) root.playlistRequested(item.playlistId || item.browseId);
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            visible: YtMusic.searching || root.results.length === 0
            MaterialLoadingIndicator {
                anchors.centerIn: parent
                visible: YtMusic.searching
            }
            StyledText {
                anchors.centerIn: parent
                visible: !YtMusic.searching && root.results.length === 0
                text: Translation.tr("No results")
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        Repeater {
            model: root.results
            delegate: ColumnLayout {
                id: resultDelegate
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: 0

                // Song → playable row with duration + playing indicator.
                ITSongListItem {
                    visible: resultDelegate.modelData.type === "song"
                    Layout.fillWidth: true
                    implicitWidth: column.width
                    song: resultDelegate.modelData
                    liked: resultDelegate.modelData.liked ?? false
                    isActive: resultDelegate.modelData.videoId === YtMusic.currentVideoId
                    isPlaying: isActive && YtMusic.isPlaying
                    onClicked: root.playRequested(resultDelegate.index)
                }
                // Album / artist / playlist → opens its detail screen.
                ITListItem {
                    visible: resultDelegate.modelData.type !== "song"
                    Layout.fillWidth: true
                    implicitWidth: column.width
                    title: resultDelegate.modelData.title ?? ""
                    subtitle: resultDelegate.modelData.subtitle ?? resultDelegate.modelData.artist ?? ""
                    thumbnailUrl: resultDelegate.modelData.thumbnail ?? ""
                    circle: resultDelegate.modelData.type === "artist"
                    onClicked: root._open(resultDelegate.modelData)
                }
            }
        }
    }
}
