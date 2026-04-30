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
        : (player?.trackArtUrl ?? "")
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
    
    // Art download management
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: effectiveArtUrl ? Qt.md5(effectiveArtUrl) : ""
    property string artFilePath: artFileName ? `${artDownloadLocation}/${artFileName}` : ""
    property bool downloaded: false
    readonly property string displayedArtFilePath: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    property int _downloadRetryCount: 0
    readonly property int _maxRetries: 3
    
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
    readonly property color inirText: Appearance.inir.colText
    readonly property color inirTextSecondary: Appearance.inir.colTextSecondary
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
        if (isYtMusicPlayer) {
            YtMusic.playPrevious()
        } else {
            player?.previous()
        }
    }
    
    function next(): void {
        if (isYtMusicPlayer) {
            YtMusic.playNext()
        } else {
            player?.next()
        }
    }
    
    function seek(seconds: real): void {
        if (isYtMusicPlayer) {
            YtMusic.seek(seconds)
        } else if (player) {
            player.position = seconds
        }
    }
    
    // Art download logic
    property string _lastCheckedPath: ""
    function checkAndDownloadArt(): void {
        if (!effectiveArtUrl) {
            downloaded = false
            _downloadRetryCount = 0
            _lastCheckedPath = ""
            return
        }
        if (artFilePath === _lastCheckedPath && downloaded) return
        _lastCheckedPath = artFilePath
        artExistsChecker.running = false
        artExistsChecker.running = true
    }
    
    function retryDownload(): void {
        if (_downloadRetryCount < _maxRetries && effectiveArtUrl) {
            _downloadRetryCount++
            retryTimer.start()
        }
    }
    
    // Internal components
    property var retryTimer: Timer {
        interval: 1000 * root._downloadRetryCount
        repeat: false
        onTriggered: {
            if (root.effectiveArtUrl && !root.downloaded) {
                coverArtDownloader.targetFile = root.effectiveArtUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = false
                coverArtDownloader.running = true
            }
        }
    }
    
    property var artExistsChecker: Process {
        command: ["/usr/bin/test", "-f", root.artFilePath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                coverArtDownloader.targetFile = root.effectiveArtUrl
                coverArtDownloader.artFilePath = root.artFilePath
                coverArtDownloader.running = false
                coverArtDownloader.running = true
            }
        }
    }
    
    property var coverArtDownloader: Process {
        property string targetFile
        property string artFilePath
        command: ["/usr/bin/bash", "-c", `
            target="$1"
            out="$2"
            dir="$3"
            
            if [ -f "$out" ]; then exit 0; fi
            mkdir -p "$dir"
            tmp="$out.tmp"
            /usr/bin/curl -sSL --connect-timeout 10 --max-time 30 "$target" -o "$tmp" && \
            [ -s "$tmp" ] && /usr/bin/mv -f "$tmp" "$out" || { rm -f "$tmp"; exit 1; }
        `, 
        "_", 
        targetFile, 
        artFilePath, 
        root.artDownloadLocation
        ]
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.downloaded = true
                root._downloadRetryCount = 0
            } else {
                root.downloaded = false
                root.retryDownload()
            }
        }
    }
    
    property var positionUpdateTimer: Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
    
    property var playerConnections: Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (!root.isYtMusicPlayer) {
                root._downloadRetryCount = 0
                root.checkAndDownloadArt()
            }
        }
    }
    
    // Watchers
    onArtFilePathChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }
    
    onEffectiveArtUrlChanged: {
        _downloadRetryCount = 0
        checkAndDownloadArt()
    }
}
