pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services

/**
 * PlayerBase - Shared logic for all media player presets
 * Handles art download, color extraction, YtMusic detection, and player state
 */
QtObject {
    id: root
    
    // Required properties
    required property MprisPlayer player
    property int slideDirection: 1
    property bool positionUpdatesActive: true
    
    // YtMusic detection
    readonly property bool isYtMusicPlayer: {
        if (!player) return false
        if (YtMusic.mpvPlayer && player === YtMusic.mpvPlayer) return true
        return MprisController._isYtMusicMpv(player)
    }
    
    // Effective properties (YtMusic or regular player)
    readonly property string effectiveTitle: isYtMusicPlayer 
        ? YtMusic.currentTitle 
        : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicPlayer 
        ? YtMusic.currentArtist 
        : (player?.trackArtist ?? "")
    readonly property string effectiveArtUrl: isYtMusicPlayer
        ? YtMusic.currentThumbnail
        : MprisController.effectiveArtUrl(player)
    // Artwork motion is keyed only by real art identity. Metadata-only updates
    // must not move the cover, or one track change animates twice.
    readonly property string mediaTransitionKey: (root.effectiveArtUrl ?? "").split("?")[0].split("#")[0]
    readonly property real effectivePosition: isYtMusicPlayer 
        ? YtMusic.currentPosition 
        : (player?.position ?? 0)
    readonly property real effectiveLength: isYtMusicPlayer 
        ? YtMusic.currentDuration 
        : (player?.length ?? 0)
    readonly property bool effectiveIsPlaying: isYtMusicPlayer 
        ? YtMusic.isPlaying 
        : (player?.isPlaying ?? false)
    readonly property bool effectiveCanSeek: isYtMusicPlayer 
        ? YtMusic.canSeek 
        : (player?.canSeek ?? false)
    readonly property bool effectiveCanGoPrevious: isYtMusicPlayer
        ? YtMusic.canGoPrevious
        : MprisController.canGoPreviousForPlayer(root.player)
    readonly property bool effectiveCanGoNext: isYtMusicPlayer
        ? YtMusic.canGoNext
        : MprisController.canGoNextForPlayer(root.player)
    
    // Art download management
    property string artDownloadLocation: Directories.coverArt
    readonly property bool downloaded: root.displayedArtFilePath !== ""
    readonly property string resolverDisplaySource: artworkResolver.displaySource
    property string displayedArtFilePath: ""
    
    // Color extraction
    property var colorQuantizer: ColorQuantizer {
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }
    
    readonly property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )
    
    // Style tokens (Inir fixed colors)
    readonly property color inirText: ColorUtils.boostInkSaturation(Appearance.inir.colText, Appearance.m3colors.m3primary)
    readonly property color inirTextSecondary: ColorUtils.boostInkSaturation(Appearance.inir.colTextSecondary, Appearance.m3colors.m3primary)
    readonly property color inirPrimary: Appearance.inir.colPrimary
    readonly property color inirLayer1: Appearance.inir.colLayer1
    readonly property color inirLayer2: Appearance.inir.colLayer2
    
    // Player actions
    function togglePlaying(): void {
        if (isYtMusicPlayer) {
            YtMusic.togglePlaying()
        } else {
            player?.togglePlaying()
        }
    }
    
    function previous(): void {
        root.slideDirection = -1
        MprisController.previousForPlayer(root.player)
    }
    
    function next(): void {
        root.slideDirection = 1
        MprisController.nextForPlayer(root.player)
    }
    
    function seek(seconds: real): void {
        if (isYtMusicPlayer) {
            YtMusic.seek(seconds)
        } else if (player) {
            player.position = seconds
        }
    }
    
    // Art download logic — mirrors BarMediaPlayerItem (the known-good impl)
    function checkAndDownloadArt(): void {
        artworkResolver.refresh()
    }

    onResolverDisplaySourceChanged: {
        const src = root.resolverDisplaySource
        if (src && src.length > 0) {
            clearArtTimer.stop()
            root.displayedArtFilePath = src
        } else {
            clearArtTimer.restart()
        }
    }

    Component.onCompleted: {
        if (root.resolverDisplaySource && root.resolverDisplaySource.length > 0)
            root.displayedArtFilePath = root.resolverDisplaySource
    }

    onPlayerChanged: Qt.callLater(root.checkAndDownloadArt)

    property var playerConnections: Connections {
        target: root.player

        function onTrackArtUrlChanged(): void {
            if (!root.isYtMusicPlayer)
                Qt.callLater(root.checkAndDownloadArt)
        }

        function onTrackTitleChanged(): void {
            Qt.callLater(root.checkAndDownloadArt)
        }

        function onTrackArtistChanged(): void {
            Qt.callLater(root.checkAndDownloadArt)
        }

        function onTrackAlbumChanged(): void {
            Qt.callLater(root.checkAndDownloadArt)
        }
    }

    property var ytMusicConnections: Connections {
        target: YtMusic

        function onCurrentThumbnailChanged(): void {
            if (root.isYtMusicPlayer)
                Qt.callLater(root.checkAndDownloadArt)
        }

        function onCurrentTitleChanged(): void {
            if (root.isYtMusicPlayer)
                Qt.callLater(root.checkAndDownloadArt)
        }

        function onCurrentArtistChanged(): void {
            if (root.isYtMusicPlayer)
                Qt.callLater(root.checkAndDownloadArt)
        }
    }
    
    // Internal components
    property var artworkResolver: MediaArtworkResolver {
        sourceUrl: root.effectiveArtUrl
        title: root.effectiveTitle
        artist: root.effectiveArtist
        album: root.player?.trackAlbum ?? ""
        cacheDirectory: root.artDownloadLocation
    }

    property var clearArtTimer: Timer {
        interval: 1600
        onTriggered: {
            if (!root.resolverDisplaySource || root.resolverDisplaySource.length === 0)
                root.displayedArtFilePath = ""
        }
    }
    
    property var positionUpdateTimer: Timer {
        running: root.positionUpdatesActive
            && root.player?.playbackState === MprisPlaybackState.Playing
        // Four bounded updates per second are enough for a continuous timeline
        // once PlayerProgress interpolates between samples.
        interval: 250
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
}
