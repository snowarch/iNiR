pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.services
import qs.modules.common

Item {
    id: root

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property bool isYtMusicActive: MprisController.isYtMusicActive
    readonly property string sourceUrl: root.isYtMusicActive && YtMusic.currentThumbnail ? YtMusic.currentThumbnail : (root.player?.trackArtUrl ?? "")
    readonly property string title: root.isYtMusicActive && YtMusic.currentTitle ? YtMusic.currentTitle : (root.player?.trackTitle ?? "")
    readonly property string artist: root.isYtMusicActive && YtMusic.currentArtist ? YtMusic.currentArtist : (root.player?.trackArtist ?? "")
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property bool ready: artworkResolver.ready
    readonly property string displaySource: artworkResolver.displaySource
    readonly property string cacheDirectory: Directories.coverArt

    function refresh(): void {
        artworkResolver.refresh();
    }

    Connections {
        target: root.player

        function onTrackArtUrlChanged(): void {
            if (!root.isYtMusicActive)
                Qt.callLater(root.refresh);
        }

        function onTrackTitleChanged(): void {
            Qt.callLater(root.refresh);
        }

        function onTrackArtistChanged(): void {
            Qt.callLater(root.refresh);
        }

        function onTrackAlbumChanged(): void {
            Qt.callLater(root.refresh);
        }
    }

    Connections {
        target: YtMusic

        function onCurrentThumbnailChanged(): void {
            if (root.isYtMusicActive)
                Qt.callLater(root.refresh);
        }

        function onCurrentTitleChanged(): void {
            if (root.isYtMusicActive)
                Qt.callLater(root.refresh);
        }

        function onCurrentArtistChanged(): void {
            if (root.isYtMusicActive)
                Qt.callLater(root.refresh);
        }
    }

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.sourceUrl
        title: root.title
        artist: root.artist
        album: root.album
        cacheDirectory: root.cacheDirectory
    }
}
