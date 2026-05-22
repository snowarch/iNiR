pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Singleton {
    id: root

    readonly property bool enabled: Config.options?.appearance?.wallpaperTheming?.enableCava ?? false
    readonly property bool useCoverSource: (Config.options?.appearance?.cava?.colorSource ?? "theme") === "cover"

    readonly property string coverSourceUrl: {
        if (MprisController.isYtMusicActive && YtMusic.currentVideoId)
            return YtMusic.currentThumbnail ?? ""
        return MprisController.activePlayer?.trackArtUrl ?? ""
    }

    readonly property string coverTitle: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? YtMusic.currentTitle
        : (MprisController.activePlayer?.trackTitle ?? "")

    readonly property string coverArtist: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? YtMusic.currentArtist
        : (MprisController.activePlayer?.trackArtist ?? "")

    readonly property string coverAlbum: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? ""
        : (MprisController.activePlayer?.trackAlbum ?? "")

    MediaArtworkResolver {
        id: coverArt
        sourceUrl: root.coverSourceUrl
        title: root.coverTitle
        artist: root.coverArtist
        album: root.coverAlbum
        cacheDirectory: Directories.coverArt

        onReadyChanged: if (coverArt.ready) root._scheduleCoverRefresh()
    }

    Timer {
        id: coverRefreshDebounce
        interval: 450
        repeat: false
        onTriggered: root._applyCoverTheme()
    }

    function _scheduleCoverRefresh(): void {
        if (!root.enabled || !root.useCoverSource) return
        coverRefreshDebounce.restart()
    }

    function _applyCoverTheme(): void {
        if (!root.enabled || !root.useCoverSource) return
        if (!coverArt.ready) return

        const path = FileUtils.trimFileProtocol(coverArt.displaySource)
        if (!path || path.length === 0) return

        Quickshell.execDetached([
            "/usr/bin/bash",
            Directories.scriptsPath + "/cava/apply_cover_theme.sh",
            path,
        ])
    }

    onEnabledChanged: root._scheduleCoverRefresh()
    onUseCoverSourceChanged: root._scheduleCoverRefresh()

    Connections {
        target: MprisController
        function onTrackChanged(): void {
            root._scheduleCoverRefresh()
        }
    }
}
