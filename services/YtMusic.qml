pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

Singleton {
    id: root

    property bool _resumeRestored: false

    function _persistResume(): void {
        if (!root.currentVideoId) return
        Config.setNestedValues({
            'sidebar.ytmusic.resume.videoId': root.currentVideoId,
            'sidebar.ytmusic.resume.title': root.currentTitle,
            'sidebar.ytmusic.resume.artist': root.currentArtist,
            'sidebar.ytmusic.resume.thumbnail': root.currentThumbnail,
            'sidebar.ytmusic.resume.url': root.currentUrl,
            'sidebar.ytmusic.resume.position': root.currentPosition,
            'sidebar.ytmusic.resume.wasPlaying': root.isPlaying,
            'sidebar.ytmusic.resume.activePlaylist': root.activePlaylist,
            'sidebar.ytmusic.resume.currentIndex': root.currentIndex,
            'sidebar.ytmusic.resume.activePlaylistSource': root.activePlaylistSource
        })
    }

    function _clearResume(): void {
        Config.setNestedValues({
            'sidebar.ytmusic.resume.videoId': "",
            'sidebar.ytmusic.resume.title': "",
            'sidebar.ytmusic.resume.artist': "",
            'sidebar.ytmusic.resume.thumbnail': "",
            'sidebar.ytmusic.resume.url': "",
            'sidebar.ytmusic.resume.position': 0,
            'sidebar.ytmusic.resume.wasPlaying': false,
            'sidebar.ytmusic.resume.activePlaylist': [],
            'sidebar.ytmusic.resume.currentIndex': -1,
            'sidebar.ytmusic.resume.activePlaylistSource': ""
        })
    }

    Timer {
        id: _resumeSaveTimer
        interval: 5000
        repeat: true
        running: root.currentVideoId !== ""
        onTriggered: root._persistResume()
    }

    Component.onDestruction: {
        if (root.currentVideoId) {
            root._persistResume()
            Config.flushWrites()
        }
        _playProc.running = false
        _killOrphanedMpvProc.running = true
    }

    Timer {
        id: _resumeSeekTimer
        interval: 1500
        repeat: false
        property real _targetPosition: 0
        onTriggered: {
            if (_resumeSeekTimer._targetPosition > 3) {
                root.seek(_resumeSeekTimer._targetPosition)
            }
        }
    }

    property bool available: false
    property bool enabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    property bool searching: false
    property bool loading: false
    property bool libraryLoading: false
    property string error: ""
    property bool verbose: Config.options?.sidebar?.ytmusic?.verbose ?? false

    function _log(msg) { if (root.verbose) console.log(msg) }
    
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property string currentUrl: ""
    property string currentVideoId: ""
    property real currentDuration: 0
    property real currentPosition: 0
    
    property bool canPause: _mpvPlayer?.canPause ?? true
    property bool canSeek: _mpvPlayer?.canSeek ?? true
    property real volume: _mpvPlayer?.volume ?? (_savedVolume / 100)
    
    property bool shuffleMode: Config.options?.sidebar?.ytmusic?.shuffleMode ?? false
    property int repeatMode: Config.options?.sidebar?.ytmusic?.repeatMode ?? 0
    readonly property bool upNextNotificationsEnabled: Config.options?.sidebar?.ytmusic?.upNextNotifications ?? true
    readonly property bool suppressUpNextInFullscreen: Config.options?.sidebar?.ytmusic?.suppressUpNextInFullscreen ?? true
    
    property string audioQuality: Config.options?.sidebar?.ytmusic?.audioQuality ?? "best"
    onAudioQualityChanged: Config.setNestedValue('sidebar.ytmusic.audioQuality', audioQuality)

    // Maps audioQuality setting to yt-dlp format string for mpv's --ytdl-format
    readonly property string _ytdlFormat: {
        switch (root.audioQuality) {
            case "low": return "worstaudio"
            case "medium": return "bestaudio[abr<=128]/bestaudio"
            default: return "bestaudio"
        }
    }

    onShuffleModeChanged: Config.setNestedValue('sidebar.ytmusic.shuffleMode', shuffleMode)
    onRepeatModeChanged: Config.setNestedValue('sidebar.ytmusic.repeatMode', repeatMode)
    
    property var searchResults: []
    property var recentSearches: []
    property var queue: []
    property var playlists: []
    property list<var> likedSongs: []
    property string lastLikedSync: ""
    property bool syncingLiked: false
    
    property var activePlaylist: []
    property int currentIndex: -1
    property string activePlaylistSource: ""
    
    // currentArtistInfo removed — was declared but never populated.
    // Artist header UI in YtMusicView was dead code.
    
    property string userName: ""
    property string userAvatar: ""
    property string userChannelUrl: ""
    
    property bool googleConnected: false
    property bool googleChecking: false
    property string googleError: ""
    property string googleBrowser: "firefox"
    property string customCookiesPath: ""
    // True when user manually provided a cookies.txt (vs auto-detected browser)
    property bool _useManualCookies: false
    property list<string> detectedBrowsers: []
    property var ytMusicPlaylists: []
    property string defaultBrowser: ""
    property bool autoConnectAttempted: false
    property bool autoConnectEnabled: Config.options?.sidebar?.ytmusic?.autoConnect ?? true
    
    // OAuth state
    property bool oauthConfigured: false
    property string oauthChannel: ""
    property bool oauthSetupActive: false
    property string oauthUserCode: ""
    property string oauthVerificationUrl: ""
    property string oauthDeviceCode: ""
    property string oauthSetupError: ""
    property string _oauthClientId: ""
    property string _oauthClientSecret: ""
    
    readonly property int maxRecentSearches: 10
    readonly property int maxLikedSongs: 200
    readonly property int maxSearchResults: 30
    
    readonly property var browserInfo: ({
        "firefox": { name: "Firefox", icon: "local_fire_department", configPath: "~/.mozilla/firefox" },
        "chrome": { name: "Chrome", icon: "public", configPath: "~/.config/google-chrome" },
        "chromium": { name: "Chromium", icon: "public", configPath: "~/.config/chromium" },
        "brave": { name: "Brave", icon: "shield", configPath: "~/.config/BraveSoftware" },
        "vivaldi": { name: "Vivaldi", icon: "music_note", configPath: "~/.config/vivaldi" },
        "opera": { name: "Opera", icon: "radio_button_checked", configPath: "~/.config/opera" },
        "edge": { name: "Edge", icon: "diamond", configPath: "~/.config/microsoft-edge" },
        "zen": { name: "Zen", icon: "self_improvement", configPath: "~/.zen" },
        "librewolf": { name: "LibreWolf", icon: "pets", configPath: "~/.librewolf" },
        "floorp": { name: "Floorp", icon: "waves", configPath: "~/.floorp" },
        "waterfox": { name: "Waterfox", icon: "water_drop", configPath: "~/.waterfox" }
    })

    property MprisPlayer _mpvPlayer: null
    readonly property MprisPlayer mpvPlayer: _mpvPlayer
    
    readonly property bool hasActivePlaylist: activePlaylist.length > 0 && currentIndex >= 0
    readonly property bool canGoNext: hasActivePlaylist && (currentIndex < activePlaylist.length - 1 || repeatMode === 2 || shuffleMode)
    readonly property bool canGoPrevious: hasActivePlaylist && (currentIndex > 0 || repeatMode === 2 || currentPosition > 3)
    
    function _isOurMpv(player): bool {
        if (!player) return false
        const id = (player.identity ?? "").toLowerCase()
        const entry = (player.desktopEntry ?? "").toLowerCase()
        if (id !== "mpv" && !id.includes("mpv") && entry !== "mpv" && !entry.includes("mpv")) return false
        const trackUrl = player.metadata?.["xesam:url"] ?? ""
        if (trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be")) return true
        if (root.currentVideoId && player.trackTitle) {
            const playerTitle = player.trackTitle.toLowerCase()
            const currentTitleLower = root.currentTitle.toLowerCase()
            if (playerTitle.includes(currentTitleLower) || currentTitleLower.includes(playerTitle)) return true
        }
        return false
    }

    Instantiator {
        model: Mpris.players
        
        Connections {
            required property MprisPlayer modelData
            target: modelData
            
            Component.onCompleted: {
                if (root._isOurMpv(modelData)) {
                    root._mpvPlayer = modelData
                    root._syncFromMpvPlayer(modelData)
                }
            }
            
            function onIsPlayingChanged() {
                if (root._isOurMpv(modelData)) {
                    root._mpvPlayer = modelData
                    root._syncFromMpvPlayer(modelData)
                }
            }
            
            function onPostTrackChanged() {
                if (root._isOurMpv(modelData)) {
                    root._mpvPlayer = modelData
                    root._syncFromMpvPlayer(modelData)
                }
            }

            function onTrackTitleChanged() {
                if (root._isOurMpv(modelData)) {
                    root._syncFromMpvPlayer(modelData)
                }
            }

            function onTrackArtistChanged() {
                if (root._isOurMpv(modelData)) {
                    root._syncFromMpvPlayer(modelData)
                }
            }

            function onTrackArtUrlChanged() {
                if (root._isOurMpv(modelData)) {
                    root._syncFromMpvPlayer(modelData)
                }
            }
            
            Component.onDestruction: {
                if (root._mpvPlayer === modelData) {
                    root._mpvPlayer = null
                    root._findMpvPlayer()
                }
            }
        }
    }
    
    function _findMpvPlayer(): void {
        for (const player of Mpris.players.values) {
            if (root._isOurMpv(player)) {
                root._mpvPlayer = player
                root._syncFromMpvPlayer(player)
                return
            }
        }
        root._mpvPlayer = null
    }

    function _extractVideoId(url): string {
        const u = (url ?? "").toString()
        if (!u) return ""
        let m = u.match(/[?&]v=([A-Za-z0-9_-]{11})/)
        if (m && m[1]) return m[1]
        m = u.match(/youtu\.be\/([A-Za-z0-9_-]{11})/)
        if (m && m[1]) return m[1]
        m = u.match(/youtube\.com\/shorts\/([A-Za-z0-9_-]{11})/)
        if (m && m[1]) return m[1]
        return ""
    }

    function _syncFromMpvPlayer(player): void {
        if (!player) return

        const url = player.metadata?.["xesam:url"] ?? ""
        const art = player.trackArtUrl ?? ""
        const pos = player.position ?? 0
        const len = player.length ?? 0

        // Don't sync title/artist from MPRIS — we set them ourselves in _playInternal
        // and --force-media-title feeds back a concatenated "Title - Artist" string
        // which overwrites currentTitle, causing exponential title growth.
        // Only sync title/artist if we have nothing (e.g. picking up an orphaned player).
        if (!root.currentTitle) {
            const title = player.trackTitle ?? ""
            if (title) root.currentTitle = title
        }
        if (!root.currentArtist) {
            const artist = player.trackArtist ?? ""
            if (artist) root.currentArtist = artist
        }
        if (url) root.currentUrl = url

        const vid = root._extractVideoId(url)
        if (vid) {
            root.currentVideoId = vid
            root.currentThumbnail = root._getThumbnailUrl(vid)
        } else if (art && !root.currentThumbnail) {
            root.currentThumbnail = art
        }

        if (len > 0) root.currentDuration = len
        if (pos >= 0) root.currentPosition = pos
    }
    
    Component.onCompleted: {
        // Kill any mpv orphans from previous sessions before doing anything else
        _killOrphanedMpvProc.running = true

        _checkAvailability.running = true
        _checkMpvMpris.running = true
        _detectDefaultBrowserProc.running = true
        _detectBrowsersProc.running = true
        _loadData()
        _findMpvPlayer()
        checkOAuth()

        // Restore previous playback session if applicable.
        if (!root._resumeRestored) {
            root._resumeRestored = true
            const r = Config.options?.sidebar?.ytmusic?.resume
            if (r?.videoId && r.wasPlaying && !root.currentVideoId) {
                const item = {
                    videoId: r.videoId,
                    title: r.title ?? "",
                    artist: r.artist ?? "",
                    thumbnail: r.thumbnail ?? "",
                    url: r.url ?? ""
                }
                const playlist = r.activePlaylist ?? []
                const idx = r.currentIndex ?? 0
                const src = r.activePlaylistSource ?? "single"
                if (playlist.length > 0 && idx >= 0 && idx < playlist.length) {
                    root.playFromPlaylist(playlist, idx, src)
                } else {
                    root.play(item)
                }
                _resumeSeekTimer._targetPosition = r.position ?? 0
                _resumeSeekTimer.start()
            }
        }
    }

    Timer {
        interval: 500
        running: root.currentVideoId !== ""
        repeat: true
        onTriggered: {
            if (root._mpvPlayer) {
                root.currentPosition = root._mpvPlayer.position
                root._ipcPaused = !root._mpvPlayer.isPlaying
            } else if (!root._userInitiatedPlay) {
                _ipcQueryProc.running = true
                _ipcPauseQueryProc.running = true
            }

            // Don't query EOF while a new play is pending — the old socket
            // would return stale eof-reached=true and cause double-advance.
            if (!root._userInitiatedPlay)
                _ipcEofQueryProc.running = true

            // Covers keep-open style endings where mpv doesn't exit,
            // so onExited never fires but eof-reached becomes true.
            // Also guard against stale EOF from old mpv when user initiated a new play.
            if (root._ipcEofReached && !root._autoAdvanceTriggered && !root._userInitiatedPlay && root.currentVideoId !== "") {
                root._autoAdvanceTriggered = true
                root.playNext(true)
            }
        }
    }
    
    Process {
        id: _ipcQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"time-pos\"] }' | socat - " + root.ipcSocket + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.data !== undefined) root.currentPosition = res.data
                } catch(e) {}
            }
        }
    }
    
    Process {
        id: _ipcPauseQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"pause\"] }' | socat - " + root.ipcSocket + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.data !== undefined) root._ipcPaused = res.data
                } catch(e) {}
            }
        }
    }

    Process {
        id: _ipcEofQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"eof-reached\"] }' | socat - " + root.ipcSocket + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.data !== undefined) root._ipcEofReached = !!res.data
                } catch(e) {}
            }
        }
    }
    
    property bool _ipcPaused: false
    property bool _ipcEofReached: false
    property bool _autoAdvanceTriggered: false
    // Guard flag: true while a user-initiated play is pending (between _playInternal and new mpv start).
    // Suppresses spurious playNext() from old mpv's onExited or stale IPC EOF queries.
    property bool _userInitiatedPlay: false
    property bool isPlaying: _mpvPlayer?.isPlaying ?? !_ipcPaused

    onEnabledChanged: {
        if (!enabled) {
            root.stop()
        }
    }

    function search(query): void {
        if (!query.trim() || !root.available) return
        root.error = ""
        root.searching = true
        root.searchResults = []
        _searchQuery = query.trim()
        _searchProc.running = true
        _addToRecentSearches(query.trim())
    }
    
    // clearArtistInfo() removed — currentArtistInfo was dead code

    property var _pendingItem: null
    property real _fadeVolume: 1.0
    
    function _playInternal(item): void {
        if (!item?.videoId || !root.available) return
        root.error = ""
        root.loading = true
        // Mark that a user-initiated play is in progress. This prevents old mpv's
        // onExited or stale IPC EOF from triggering playNext() before the new mpv starts.
        root._userInitiatedPlay = true
        root._ipcEofReached = false
        
        _fadeOutOtherPlayers()
        
        root.currentTitle = item.title || ""
        root.currentArtist = item.artist || ""
        root.currentVideoId = item.videoId || ""
        root.currentThumbnail = _getThumbnailUrl(item.videoId)
        root.currentUrl = item.url || `https://www.youtube.com/watch?v=${item.videoId}`
        root.currentDuration = item.duration || 0
        root.currentPosition = 0
        
        root._playUrl = root.currentUrl
        root._pendingItem = item
        
        root._stopMpv()
        _playDelayTimer.restart()
    }
    
    function play(item): void {
        if (!item?.videoId) return
        root.activePlaylist = [item]
        root.currentIndex = 0
        root.activePlaylistSource = "single"
        _playInternal(item)
    }
    
    function playFromPlaylist(playlist, index, source): void {
        root._log("[YtMusic] playFromPlaylist. playlist.length=" + (playlist?.length ?? "null") + " index=" + index + " source=" + source)
        if (!playlist || index < 0 || index >= playlist.length) return
        root.activePlaylist = [...playlist]
        root.currentIndex = index
        root.activePlaylistSource = source || "custom"
        root._log("[YtMusic] Set activePlaylist.length=" + root.activePlaylist.length + " currentIndex=" + root.currentIndex)
        _playInternal(playlist[index])
    }
    
    function playFromSearch(index): void {
        if (index >= 0 && index < searchResults.length) {
            playFromPlaylist(searchResults, index, "search")
        }
    }
    
    function playFromLiked(index): void {
        root._log("[YtMusic] playFromLiked. index=" + index + " likedSongs.length=" + likedSongs.length)
        if (index >= 0 && index < likedSongs.length) {
            playFromPlaylist(likedSongs, index, "liked")
        }
    }
    
    function playFromQueue(index): void {
        if (index >= 0 && index < queue.length) {
            const item = queue[index]
            let q = [...queue]
            q.splice(index, 1)
            root.queue = q
            _persistQueue()
            // Queue playback advances by consuming root.queue on each track end.
            // Keep activePlaylist focused on the currently playing item to avoid
            // index drift/skip when queue has multiple tracks.
            root.activePlaylist = [item]
            root.currentIndex = 0
            root.activePlaylistSource = "queue"
            _playInternal(item)
        }
    }
    
    function _fadeOutOtherPlayers(): void {
        for (const player of Mpris.players.values) {
            if (player === root._mpvPlayer) continue
            if (player.isPlaying && player.canPause) {
                player.pause()
            }
        }
    }

    function stop(): void {
        _playProc.running = false
        _killOrphanedMpvProc.running = true // kill any orphaned mpv too
        _stopProc.running = true  // clean up socket
        _playDelayTimer.stop()
        root.loading = false
        root._autoAdvanceTriggered = false
        root._ipcEofReached = false
        root._userInitiatedPlay = false
        root.currentVideoId = ""
        root.currentTitle = ""
        root.currentArtist = ""
        root.currentThumbnail = ""
        root.currentUrl = ""
        root.currentDuration = 0
        root.currentPosition = 0
        root.activePlaylist = []
        root.currentIndex = -1
        root._clearResume()
    }

    function _didTrackEndNaturally(code: int, stderrText: string): bool {
        if (!root.currentVideoId) return false
        // Signal-killed exits are never natural — we killed mpv to switch tracks.
        if (code === 9 || code === 15 || code === 137 || code === 143) return false
        if (code === 0) return true
        // mpv can exit with code 4 for EOF-style finishes in some streams/builds.
        if (code === 4) return true
        return false
    }

    Process {
        id: _ipcProc
        property string commandData
        command: ["/bin/sh", "-c", "echo '" + commandData + "' | socat - " + root.ipcSocket + " 2>/dev/null"]
    }
    
    function _sendIpc(cmd): void {
        _ipcProc.commandData = JSON.stringify({ command: cmd })
        _ipcProc.running = true
    }

    function togglePlaying(): void {
        if (root._mpvPlayer) {
            root._mpvPlayer.togglePlaying()
        } else {
            _sendIpc(["cycle", "pause"])
        }
    }
    
    function seek(seconds): void {
        if (root._mpvPlayer) {
            root._mpvPlayer.position = seconds
        } else {
            _sendIpc(["seek", seconds, "absolute"])
            root.currentPosition = seconds
        }
    }

    function setVolume(vol): void {
        const clamped = Math.max(0, Math.min(1, vol))
        root._savedVolume = Math.round(clamped * 100)
        Config.setNestedValue("sidebar.ytmusic.volume", root._savedVolume)
        if (root._mpvPlayer) {
            root._mpvPlayer.volume = clamped
        } else {
            _sendIpc(["set_property", "volume", root._savedVolume])
        }
    }
    
    function getVolume(): real {
        return root._mpvPlayer?.volume ?? root._ipcVolume
    }
    
    property real _ipcVolume: 1.0
    property int _savedVolume: Config.options?.sidebar?.ytmusic?.volume ?? 100

    function toggleShuffle(): void {
        root.shuffleMode = !root.shuffleMode
    }
    
    function cycleRepeatMode(): void {
        root.repeatMode = (root.repeatMode + 1) % 3
    }

    function _shouldNotifyUpcomingTrack(): bool {
        if (!root.upNextNotificationsEnabled) return false
        if (Config.options?.notifications?.silent ?? false) return false
        if (root.suppressUpNextInFullscreen && (GameMode.active || GameMode.hasAnyFullscreenWindow)) return false
        return true
    }

    function _notifyUpcomingTrack(item): void {
        if (!item) return
        if (!root._shouldNotifyUpcomingTrack()) return

        const title = String(item.title ?? "").trim()
        if (!title) return
        const artist = String(item.artist ?? "").trim()
        const body = artist.length > 0 ? `${title} - ${artist}` : title

        Quickshell.execDetached([
            "/usr/bin/notify-send",
            Translation.tr("Up Next"),
            body,
            "-a", "YtMusic",
            "-i", "audio-x-generic",
            "-h", "int:transient:1",
            "-t", "4000"
        ])
    }

    function playNext(notifyUpcoming): void {
        notifyUpcoming = (notifyUpcoming === true)
        root._log("[YtMusic] playNext called. activePlaylist.length=" + activePlaylist.length + " currentIndex=" + currentIndex + " source=" + activePlaylistSource)
        
        if (root.repeatMode === 1 && root.currentVideoId) {
            seek(0)
            if (!root.isPlaying) togglePlaying()
            return
        }
        
        if (root.activePlaylist.length > 0 && root.currentIndex >= 0) {
            let nextIndex = root.currentIndex + 1
            
            if (root.shuffleMode && root.activePlaylist.length > 1) {
                do {
                    nextIndex = Math.floor(Math.random() * root.activePlaylist.length)
                } while (nextIndex === root.currentIndex)
            }
            
            if (nextIndex >= root.activePlaylist.length) {
                if (root.queue.length > 0) {
                    if (notifyUpcoming)
                        root._notifyUpcomingTrack(root.queue[0])
                    playFromQueue(0)
                    return
                }
                if (root.repeatMode === 2) {
                    nextIndex = 0
                } else {
                    return
                }
            }
            
            const nextItem = root.activePlaylist[nextIndex]
            if (notifyUpcoming)
                root._notifyUpcomingTrack(nextItem)
            root.currentIndex = nextIndex
            _playInternal(nextItem)
            return
        }
        
        if (root.queue.length > 0) {
            if (notifyUpcoming)
                root._notifyUpcomingTrack(root.queue[0])
            playFromQueue(0)
        }
    }
    
    function playPrevious(): void {
        if (root.currentPosition > 3) {
            seek(0)
            return
        }
        
        if (root.activePlaylist.length > 0 && root.currentIndex >= 0) {
            let prevIndex = root.currentIndex - 1
            
            if (prevIndex < 0) {
                if (root.repeatMode === 2) {
                    prevIndex = root.activePlaylist.length - 1
                } else {
                    seek(0)
                    return
                }
            }
            
            root.currentIndex = prevIndex
            _playInternal(root.activePlaylist[prevIndex])
            return
        }
        
        seek(0)
    }

    function addToQueue(item): void {
        if (!item?.videoId) return
        root.queue = [...root.queue, item]
        _persistQueue()
    }

    function removeFromQueue(index): void {
        if (index >= 0 && index < root.queue.length) {
            let q = [...root.queue]
            q.splice(index, 1)
            root.queue = q
            _persistQueue()
        }
    }

    function clearQueue(): void {
        root.queue = []
        _persistQueue()
    }

    function playQueue(): void {
        if (root.queue.length > 0) {
            playFromQueue(0)
        }
    }

    function shuffleQueue(): void {
        if (root.queue.length < 2) return
        let q = [...root.queue]
        for (let i = q.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [q[i], q[j]] = [q[j], q[i]]
        }
        root.queue = q
        _persistQueue()
    }

    function createPlaylist(name): void {
        if (!name.trim()) return
        root.playlists = [...root.playlists, { name: name.trim(), items: [] }]
        _persistPlaylists()
    }

    function deletePlaylist(index): void {
        if (index >= 0 && index < root.playlists.length) {
            let p = [...root.playlists]
            p.splice(index, 1)
            root.playlists = p
            _persistPlaylists()
        }
    }

    function addToPlaylist(playlistIndex, item): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        if (!item?.videoId) return
        
        let p = [...root.playlists]
        if (!p[playlistIndex].items.find(i => i.videoId === item.videoId)) {
            p[playlistIndex].items = [...p[playlistIndex].items, {
                videoId: item.videoId,
                title: item.title,
                artist: item.artist,
                duration: item.duration,
                thumbnail: _getThumbnailUrl(item.videoId)
            }]
            root.playlists = p
            _persistPlaylists()
        }
    }

    function removeFromPlaylist(playlistIndex, itemIndex): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        let p = [...root.playlists]
        if (itemIndex >= 0 && itemIndex < p[playlistIndex].items.length) {
            p[playlistIndex].items.splice(itemIndex, 1)
            root.playlists = p
            _persistPlaylists()
        }
    }

    function likeSong(): void {
        if (!root.currentVideoId) return
        if (root.likedSongs.some(s => s.videoId === root.currentVideoId)) return
        let liked = [...root.likedSongs]
        liked.unshift({
            videoId: root.currentVideoId,
            title: root.currentTitle,
            artist: root.currentArtist,
            duration: root.currentDuration,
            thumbnail: root.currentThumbnail
        })
        if (liked.length > root.maxLikedSongs) liked = liked.slice(0, root.maxLikedSongs)
        root.likedSongs = liked
        Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
        // Send real like to YouTube via OAuth
        if (root.oauthConfigured) {
            _rateLikeProc._videoId = root.currentVideoId
            _rateLikeProc.running = true
        }
    }

    function unlikeSong(videoId): void {
        const idx = root.likedSongs.findIndex(s => s.videoId === videoId)
        if (idx < 0) return
        let liked = [...root.likedSongs]
        liked.splice(idx, 1)
        root.likedSongs = liked
        Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
        // Send real unlike to YouTube via OAuth
        if (root.oauthConfigured) {
            _rateUnlikeProc._videoId = videoId
            _rateUnlikeProc.running = true
        }
    }

    Process {
        id: _rateLikeProc
        property string _videoId: ""
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "like", _videoId]
    }

    Process {
        id: _rateUnlikeProc
        property string _videoId: ""
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "unlike", _videoId]
    }

    // ── OAuth Setup ────────────────────────────────────────────────────
    function checkOAuth(): void {
        _oauthCheckProc.running = true
    }

    function startOAuthSetup(clientId, clientSecret): void {
        root._oauthClientId = clientId
        root._oauthClientSecret = clientSecret
        root.oauthSetupError = ""
        root.oauthSetupActive = true
        _oauthRequestProc._clientId = clientId
        _oauthRequestProc._clientSecret = clientSecret
        _oauthRequestProc.running = true
    }

    function cancelOAuthSetup(): void {
        root.oauthSetupActive = false
        root.oauthUserCode = ""
        root.oauthVerificationUrl = ""
        root.oauthDeviceCode = ""
        root.oauthSetupError = ""
        _oauthPollTimer.running = false
    }

    function disconnectOAuth(): void {
        root.oauthConfigured = false
        root.oauthChannel = ""
        // Delete the oauth json file
        _oauthDeleteProc.running = true
    }

    Process {
        id: _oauthCheckProc
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "check"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const r = JSON.parse(data)
                    root.oauthConfigured = r.configured === true
                    root.oauthChannel = r.channel || ""
                } catch(e) {}
            }
        }
    }

    Process {
        id: _oauthRequestProc
        property string _clientId: ""
        property string _clientSecret: ""
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "setup-request", _clientId, _clientSecret]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const r = JSON.parse(data)
                    if (r.error) {
                        root.oauthSetupError = r.error
                        return
                    }
                    root.oauthUserCode = r.user_code
                    root.oauthVerificationUrl = r.verification_url
                    root.oauthDeviceCode = r.device_code
                    _oauthPollTimer.interval = (r.interval || 5) * 1000
                    _oauthPollTimer.running = true
                } catch(e) {
                    root.oauthSetupError = "Failed to parse response"
                }
            }
        }
    }

    Timer {
        id: _oauthPollTimer
        interval: 5000
        repeat: true
        onTriggered: {
            _oauthPollProc._clientId = root._oauthClientId
            _oauthPollProc._clientSecret = root._oauthClientSecret
            _oauthPollProc._deviceCode = root.oauthDeviceCode
            _oauthPollProc.running = true
        }
    }

    Process {
        id: _oauthPollProc
        property string _clientId: ""
        property string _clientSecret: ""
        property string _deviceCode: ""
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "setup-poll", _clientId, _clientSecret, _deviceCode]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const r = JSON.parse(data)
                    if (r.status === "authorized") {
                        _oauthPollTimer.running = false
                        root.oauthSetupActive = false
                        root.oauthUserCode = ""
                        root.oauthDeviceCode = ""
                        root.oauthConfigured = true
                        root.checkOAuth() // fetch channel name
                    } else if (r.status === "pending" || r.status === "slow_down") {
                        // keep polling
                        if (r.status === "slow_down") _oauthPollTimer.interval += 2000
                    } else {
                        _oauthPollTimer.running = false
                        root.oauthSetupError = r.error || "Authorization failed"
                        root.oauthSetupActive = false
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: _oauthDeleteProc
        command: ["/bin/sh", "-c", "rm -f \"${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/ytmusic_oauth.json\""]
    }

    function playPlaylist(playlistIndex, shuffle): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        let items = [...root.playlists[playlistIndex].items]
        if (items.length === 0) return
        
        if (shuffle) {
            for (let i = items.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [items[i], items[j]] = [items[j], items[i]]
            }
        }
        
        playFromPlaylist(items, 0, "playlist:" + root.playlists[playlistIndex].name)
    }

    function connectGoogle(browser): void {
        root.googleBrowser = browser || "firefox"
        root.googleError = ""
        root.googleChecking = true
        root._resolvedBrowserArg = ""
        root._useManualCookies = false
        Config.setNestedValue('sidebar.ytmusic.browser', root.googleBrowser)
        Config.setNestedValue('sidebar.ytmusic.useManualCookies', false)
        _checkGoogleConnection()
    }

    function setCustomCookiesPath(path): void {
        if (!path) return
        root.customCookiesPath = path
        root._useManualCookies = true
        root.googleError = ""
        root.googleChecking = true
        Config.setNestedValue('sidebar.ytmusic.cookiesPath', path)
        Config.setNestedValue('sidebar.ytmusic.useManualCookies', true)
        _checkGoogleConnection()
    }

    function disconnectGoogle(): void {
        root.googleConnected = false
        root.googleError = ""
        root.googleChecking = false
        root.ytMusicPlaylists = []
        root._resolvedBrowserArg = ""
        root.autoConnectAttempted = false
        root.userName = ""
        root.userAvatar = ""
        root.userChannelUrl = ""
        Config.setNestedValue('sidebar.ytmusic.connected', false)
        Config.setNestedValue('sidebar.ytmusic.resolvedBrowserArg', "")
        Config.setNestedValue('sidebar.ytmusic.profile', { name: "", avatar: "", url: "" })
        // Delete stale cookie file
        _deleteCookiesProc.running = true
    }
    
    function quickConnect(): void {
        if (root.googleConnected) return
        root.googleError = ""
        root.googleChecking = true
        root._quickConnectIndex = 0
        root._tryNextBrowser()
    }
    
    property int _quickConnectIndex: 0
    property var _browsersToTry: []
    
    function _tryNextBrowser(): void {
        if (root._quickConnectIndex === 0) {
            let browsers = []
            if (root.defaultBrowser && root.detectedBrowsers.includes(root.defaultBrowser)) {
                browsers.push(root.defaultBrowser)
            }
            for (const b of root.detectedBrowsers) {
                if (!browsers.includes(b)) browsers.push(b)
            }
            root._browsersToTry = browsers
        }
        
        if (root._quickConnectIndex >= root._browsersToTry.length) {
            root.googleChecking = false
            root.googleError = Translation.tr("Could not connect. Log in to music.youtube.com in your browser first.")
            return
        }
        
        root.googleBrowser = root._browsersToTry[root._quickConnectIndex]
        root._resolvedBrowserArg = ""
        if (root._firefoxForks.includes(root.googleBrowser)) {
            _resolveBrowserArgProcQC._browser = root.googleBrowser
            _resolveBrowserArgProcQC.running = true
        } else {
            root._resolvedBrowserArg = root.googleBrowser
            _quickConnectCheckProc.running = true
        }
    }

    // Separate resolver for quickConnect to avoid conflict with main resolver
    Process {
        id: _resolveBrowserArgProcQC
        property string _browser: ""
        command: ["python3", "-c", `
import sys, os, glob
browser = '` + _resolveBrowserArgProcQC._browser + `'
forks = {"zen":"~/.zen","librewolf":"~/.librewolf","floorp":"~/.floorp","waterfox":"~/.waterfox","firefox":"~/.mozilla/firefox"}
base = os.path.expanduser(forks.get(browser, "~/.mozilla/firefox"))
if not os.path.exists(base):
    print("")
    sys.exit(0)
for pattern in ["*.default-release", "*.default"]:
    for m in glob.glob(os.path.join(base, pattern)):
        if os.path.isdir(m) and os.path.exists(os.path.join(m, "cookies.sqlite")):
            print("firefox:" + m)
            sys.exit(0)
for item in sorted(os.listdir(base)):
    p = os.path.join(base, item)
    if os.path.isdir(p) and os.path.exists(os.path.join(p, "cookies.sqlite")):
        print("firefox:" + p)
        sys.exit(0)
print("")
`]
        stdout: SplitParser {
            onRead: line => {
                const resolved = line.trim()
                if (resolved) {
                    root._resolvedBrowserArg = resolved
                }
            }
        }
        onExited: {
            _quickConnectCheckProc.running = true
        }
    }

    // Quick connect check — tries each browser with --cookies-from-browser
    Process {
        id: _quickConnectCheckProc
        property string stdOutput: ""
        command: ["/usr/bin/yt-dlp",
            "--cookies-from-browser", root._browserArgForYtdlp,
            "--flat-playlist",
            "--no-warnings",
            "-I", "1",
            "--print", "id",
            "https://www.youtube.com/feed/history"
        ]
        
        onStarted: { stdOutput = "" }
        
        stdout: SplitParser {
            onRead: line => {
                _quickConnectCheckProc.stdOutput += line + "\n"
            }
        }
        
        onExited: (code) => {
            if (code === 0 && _quickConnectCheckProc.stdOutput.trim().length > 0) {
                root.googleConnected = true
                root.googleError = ""
                root.googleChecking = false
                Config.setNestedValue('sidebar.ytmusic.browser', root.googleBrowser)
                Config.setNestedValue('sidebar.ytmusic.connected', true)
                Config.setNestedValue('sidebar.ytmusic.resolvedBrowserArg', root._resolvedBrowserArg)
                root._log("[YtMusic] QuickConnect succeeded with:", root._browserArgForYtdlp)
                // Export static cookie file for mpv
                _exportCookiesProc.running = true
                root.fetchUserProfile()
            } else {
                // Try next browser
                root._quickConnectIndex++
                root._tryNextBrowser()
            }
        }
    }
    
    Process {
        id: _fetchProfileProc
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--playlist-end", "1",
            "--print", "%(uploader)s|%(uploader_url)s",
            "https://music.youtube.com/library/playlists"
        ]
        
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|")
                if (parts.length >= 2) {
                    root.userName = parts[0]
                    root.userChannelUrl = parts[1]
                    _fetchAvatarProc.running = true
                }
            }
        }
    }
    
    Process {
        id: _fetchAvatarProc
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--dump-json",
            root.userChannelUrl
        ]
        
        stdout: SplitParser {
            onRead: line => {
                try {
                    const json = JSON.parse(line)
                    if (json.thumbnails && json.thumbnails.length > 0) {
                        root.userAvatar = json.thumbnails[json.thumbnails.length - 1].url
                        _persistProfile()
                    }
                } catch (e) {}
            }
        }
    }
    
    function fetchUserProfile(): void {
        if (!root.googleConnected) return
        _fetchProfileProc.running = true
        fetchLikedPlaylists()
        fetchLikedSongs()
    }
    
    function _persistProfile(): void {
        Config.setNestedValue('sidebar.ytmusic.profile', {
            name: root.userName,
            avatar: root.userAvatar,
            url: root.userChannelUrl
        })
    }
    
    function openYtMusicInBrowser(): void {
        Qt.openUrlExternally("https://music.youtube.com")
    }
    
    function retryConnection(): void {
        root.googleError = ""
        root.googleChecking = true
        root._resolvedBrowserArg = ""
        _checkGoogleConnection()
    }
    
    function getBrowserDisplayName(browserId): string {
        return root.browserInfo[browserId]?.name ?? browserId
    }

    Process {
        id: _fetchLikedProc
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "-j",
            "--playlist-end", root.maxLikedSongs.toString(),
            "https://music.youtube.com/playlist?list=LM"
        ]
        
        property var newLiked: []
        
        onStarted: { newLiked = [] }
        
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (!data.id) return
                    const duration = data.duration || 0
                    if (duration < 30 || duration > 900) return
                    _fetchLikedProc.newLiked.push({
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        videoId: data.id,
                        duration: duration,
                        thumbnail: root._getThumbnailUrl(data.id)
                    })
                } catch (e) {}
            }
        }
        
        onExited: (code) => {
            root.syncingLiked = false
            if (code === 0 && _fetchLikedProc.newLiked.length > 0) {
                root.likedSongs = _fetchLikedProc.newLiked
                root.lastLikedSync = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm")
                Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
                Config.setNestedValue('sidebar.ytmusic.lastLikedSync', root.lastLikedSync)
            } else {
                // Error or empty result — try YouTube LL fallback
                _fetchLikedFallbackProc.running = true
            }
        }
    }
    
    Process {
        id: _fetchLikedFallbackProc
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "-j",
            "--playlist-end", root.maxLikedSongs.toString(),
            "https://www.youtube.com/playlist?list=LL"
        ]
        
        property var newLiked: []
        
        onStarted: { newLiked = [] }
        
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (!data.id) return
                    const duration = data.duration || 0
                    if (duration < 30 || duration > 600) return
                    const title = (data.title || "").toLowerCase()
                    const videoKeywords = ['podcast', 'interview', 'documentary', 'tutorial', 
                                          'review', 'gameplay', 'walkthrough', 'vlog', 
                                          'episode', 'part ', 'full album', 'compilation',
                                          'hours of', 'asmr', 'white noise']
                    if (videoKeywords.some(kw => title.includes(kw))) return
                    _fetchLikedFallbackProc.newLiked.push({
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        videoId: data.id,
                        duration: duration,
                        thumbnail: root._getThumbnailUrl(data.id)
                    })
                } catch (e) {}
            }
        }
        
        onExited: (code) => {
            root.syncingLiked = false
            if (code === 0 && _fetchLikedFallbackProc.newLiked.length > 0) {
                root.likedSongs = _fetchLikedFallbackProc.newLiked
                root.lastLikedSync = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm")
                Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
                Config.setNestedValue('sidebar.ytmusic.lastLikedSync', root.lastLikedSync)
            }
        }
    }
    
    function fetchLikedSongs(): void {
        if (root.syncingLiked) return
        root.syncingLiked = true
        if (root.oauthConfigured) {
            _fetchLikedOAuthProc._items = []
            _fetchLikedOAuthProc.running = true
        } else if (root.googleConnected) {
            _fetchLikedProc.running = true
        } else {
            root.syncingLiked = false
        }
    }

    Process {
        id: _fetchLikedOAuthProc
        property var _items: []
        command: ["python3", Directories.scriptPath + "/ytmusic_rate.py", "fetch-liked"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const r = JSON.parse(data)
                    if (r._done || r._error) return
                    _fetchLikedOAuthProc._items.push(r)
                } catch(e) {}
            }
        }
        onExited: (code) => {
            if (_fetchLikedOAuthProc._items.length > 0) {
                root.likedSongs = _fetchLikedOAuthProc._items
                root.lastLikedSync = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm")
                Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
                Config.setNestedValue('sidebar.ytmusic.lastLikedSync', root.lastLikedSync)
                root.syncingLiked = false
            } else if (root.googleConnected) {
                // OAuth returned empty or failed — fallback to cookie method
                _fetchLikedProc.running = true
            } else {
                root.syncingLiked = false
            }
        }
    }
    
    function fetchYtMusicPlaylists(): void {
        fetchLikedPlaylists()
    }

    function fetchLikedPlaylists(): void {
        if (!root.googleConnected) return
        root.searching = true
        _ytPlaylistsProc.running = true
    }

    function importYtMusicPlaylist(playlistUrl, name): void {
        if (!root.googleConnected || !playlistUrl) return
        root.searching = true
        _importPlaylistUrl = playlistUrl
        _importPlaylistName = name || "Imported Playlist"
        _importPlaylistProc.running = true
    }

    function clearRecentSearches(): void {
        root.recentSearches = []
        _persistRecentSearches()
    }

    property string _searchQuery: ""
    property string _playUrl: ""
    property string _importPlaylistUrl: ""
    property string _importPlaylistName: ""

    readonly property string _cookiesFilePath: Directories.shellConfig + "/yt-cookies.txt"
    readonly property var _firefoxForks: ["zen", "librewolf", "floorp", "waterfox"]

    // Resolved browser arg for --cookies-from-browser (e.g. "firefox:/path/to/profile" for forks)
    // Persisted so it survives restarts without re-resolving
    property string _resolvedBrowserArg: ""

    // True when _resolvedBrowserArg is ready to use (non-empty or non-firefox-fork)
    readonly property bool _browserArgReady: root._resolvedBrowserArg !== "" || !root._firefoxForks.includes(root.googleBrowser)

    // ALWAYS use --cookies-from-browser for yt-dlp (fresh cookies, never stale)
    // Unless user manually provided a cookies.txt file
    readonly property string _browserArgForYtdlp: root._resolvedBrowserArg || root.googleBrowser

    property var _cookieArgs: root._useManualCookies && root.customCookiesPath
        ? ["--cookies", root.customCookiesPath, "--js-runtimes", "node", "--remote-components", "ejs:github"]
        : ["--cookies-from-browser", root._browserArgForYtdlp, "--js-runtimes", "node", "--remote-components", "ejs:github"]

    // Static cookie file — used by mpv (which can't use --cookies-from-browser)
    // When user provides a manual cookies file, use that instead of the auto-exported one
    readonly property string _mpvCookiesFile: root._useManualCookies && root.customCookiesPath
        ? root.customCookiesPath : root._cookiesFilePath

    function _getThumbnailUrl(videoId): string {
        if (!videoId) return ""
        if (videoId.length !== 11 || videoId.startsWith("UC")) return ""
        return `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`
    }
    
    Connections {
        target: _detectBrowsersProc
        function onRunningChanged() {
            if (!_detectBrowsersProc.running && root.available && root.autoConnectEnabled && !root.autoConnectAttempted) {
                root.autoConnectAttempted = true
                root._log("[YtMusic] Browser detection done. Detected:", JSON.stringify(root.detectedBrowsers), "Saved browser:", root.googleBrowser)
                // If already connected from persisted state, just verify silently
                if (root.googleConnected && root._browserArgReady) {
                    root._log("[YtMusic] Already connected (persisted). Verifying silently...")
                    _googleCheckProc.running = true
                    return
                }
                // If we have a saved browser, use it (don't override with detected[0])
                if (Config.options?.sidebar?.ytmusic?.browser) {
                    Qt.callLater(() => root._checkGoogleConnection())
                } else if (root.defaultBrowser && root.detectedBrowsers.includes(root.defaultBrowser)) {
                    Qt.callLater(() => root._checkGoogleConnection())
                } else if (root.detectedBrowsers.length > 0) {
                    root.googleBrowser = root.detectedBrowsers[0]
                    Qt.callLater(() => root._checkGoogleConnection())
                }
            }
        }
    }

    function _loadData(): void {
        root.recentSearches = Config.options?.sidebar?.ytmusic?.recentSearches ?? []
        root.queue = Config.options?.sidebar?.ytmusic?.queue ?? []
        root.playlists = Config.options?.sidebar?.ytmusic?.playlists ?? []
        root.likedSongs = Config.options?.sidebar?.ytmusic?.liked ?? []
        root.lastLikedSync = Config.options?.sidebar?.ytmusic?.lastLikedSync ?? ""
        root.customCookiesPath = Config.options?.sidebar?.ytmusic?.cookiesPath ?? ""
        root._useManualCookies = Config.options?.sidebar?.ytmusic?.useManualCookies ?? false
        
        const profile = Config.options?.sidebar?.ytmusic?.profile
        if (profile) {
            root.userName = profile.name ?? ""
            root.userAvatar = profile.avatar ?? ""
            root.userChannelUrl = profile.url ?? ""
        }
        
        const savedBrowser = Config.options?.sidebar?.ytmusic?.browser
        if (savedBrowser) {
            root.googleBrowser = savedBrowser
        }
        
        // Restore persisted resolved browser arg (avoids re-resolving on restart)
        const savedResolvedArg = Config.options?.sidebar?.ytmusic?.resolvedBrowserArg ?? ""
        if (savedResolvedArg) {
            root._resolvedBrowserArg = savedResolvedArg
        }
        
        // Restore persisted connection state
        const wasConnected = Config.options?.sidebar?.ytmusic?.connected ?? false
        if (wasConnected) {
            root.googleConnected = true
        }
        

    }

    Process {
        id: _detectDefaultBrowserProc
        command: ["/usr/bin/xdg-settings", "get", "default-web-browser"]
        stdout: SplitParser {
            onRead: line => {
                const desktop = line.trim().toLowerCase()
                let browser = ""
                if (desktop.includes("firefox")) browser = "firefox"
                else if (desktop.includes("google-chrome")) browser = "chrome"
                else if (desktop.includes("chromium")) browser = "chromium"
                else if (desktop.includes("brave")) browser = "brave"
                else if (desktop.includes("vivaldi")) browser = "vivaldi"
                else if (desktop.includes("opera")) browser = "opera"
                else if (desktop.includes("edge")) browser = "edge"
                else if (desktop.includes("zen")) browser = "zen"
                
                if (browser && !Config.options?.sidebar?.ytmusic?.browser) {
                    root.googleBrowser = browser
                    root.defaultBrowser = browser
                }
            }
        }
    }

    Process {
        id: _detectBrowsersProc
        command: ["/bin/bash", "-c", `
            for path in ~/.mozilla/firefox ~/.config/google-chrome ~/.config/chromium ~/.config/BraveSoftware ~/.config/vivaldi ~/.config/opera ~/.config/microsoft-edge ~/.zen ~/.librewolf ~/.floorp ~/.waterfox; do
                [ -d "$path" ] && echo "$path"
            done
        `]
        stdout: SplitParser {
            onRead: line => {
                const path = line.trim()
                if (path.includes("firefox") || path.includes("mozilla")) root.detectedBrowsers.push("firefox")
                else if (path.includes("google-chrome")) root.detectedBrowsers.push("chrome")
                else if (path.includes("chromium")) root.detectedBrowsers.push("chromium")
                else if (path.includes("BraveSoftware")) root.detectedBrowsers.push("brave")
                else if (path.includes("vivaldi")) root.detectedBrowsers.push("vivaldi")
                else if (path.includes("opera")) root.detectedBrowsers.push("opera")
                else if (path.includes("microsoft-edge")) root.detectedBrowsers.push("edge")
                else if (path.includes(".zen")) root.detectedBrowsers.push("zen")
                else if (path.includes("librewolf")) root.detectedBrowsers.push("librewolf")
                else if (path.includes("floorp")) root.detectedBrowsers.push("floorp")
                else if (path.includes("waterfox")) root.detectedBrowsers.push("waterfox")
            }
        }
    }

    function _addToRecentSearches(query): void {
        let recent = root.recentSearches.filter(s => s.toLowerCase() !== query.toLowerCase())
        recent.unshift(query)
        if (recent.length > root.maxRecentSearches) {
            recent = recent.slice(0, root.maxRecentSearches)
        }
        root.recentSearches = recent
        _persistRecentSearches()
    }

    function _persistRecentSearches(): void {
        Config.setNestedValue('sidebar.ytmusic.recentSearches', root.recentSearches)
    }

    function _persistQueue(): void {
        Config.setNestedValue('sidebar.ytmusic.queue', root.queue)
    }

    function _persistPlaylists(): void {
        Config.setNestedValue('sidebar.ytmusic.playlists', root.playlists)
    }

    function _resolveBrowserArg(): void {
        if (root._firefoxForks.includes(root.googleBrowser)) {
            _resolveBrowserArgProc.running = true
        } else {
            root._resolvedBrowserArg = root.googleBrowser
        }
    }

    // Resolves firefox:/path/to/profile for Firefox forks
    Process {
        id: _resolveBrowserArgProc
        property bool _pendingCheck: false
        command: ["python3", "-c", `
import sys, os, glob
browser = '` + root.googleBrowser + `'
forks = {"zen":"~/.zen","librewolf":"~/.librewolf","floorp":"~/.floorp","waterfox":"~/.waterfox","firefox":"~/.mozilla/firefox"}
base = os.path.expanduser(forks.get(browser, "~/.mozilla/firefox"))
if not os.path.exists(base):
    print("")
    sys.exit(0)
for pattern in ["*.default-release", "*.default"]:
    for m in glob.glob(os.path.join(base, pattern)):
        if os.path.isdir(m) and os.path.exists(os.path.join(m, "cookies.sqlite")):
            print("firefox:" + m)
            sys.exit(0)
for item in sorted(os.listdir(base)):
    p = os.path.join(base, item)
    if os.path.isdir(p) and os.path.exists(os.path.join(p, "cookies.sqlite")):
        print("firefox:" + p)
        sys.exit(0)
print("")
`]
        stdout: SplitParser {
            onRead: line => {
                const resolved = line.trim()
                if (resolved) {
                    root._resolvedBrowserArg = resolved
                    Config.setNestedValue('sidebar.ytmusic.resolvedBrowserArg', resolved)
                    root._log("[YtMusic] Resolved browser arg:", resolved)
                }
            }
        }
        onExited: {
            if (_resolveBrowserArgProc._pendingCheck) {
                _resolveBrowserArgProc._pendingCheck = false
                _googleCheckProc.running = true
            }
        }
    }

    function _checkGoogleConnection(): void {
        if (!root.available) {
            root.googleError = Translation.tr("yt-dlp not available")
            root.googleChecking = false
            return
        }
        root.googleChecking = true
        root.googleError = ""
        if (root._firefoxForks.includes(root.googleBrowser) && !root._resolvedBrowserArg) {
            // Need to resolve first, then check
            _resolveBrowserArgProc._pendingCheck = true
            root._resolveBrowserArg()
        } else {
            root._resolveBrowserArg()
            _googleCheckProc.running = true
        }
    }

    Timer {
        id: _playDelayTimer
        interval: 200
        onTriggered: {
            // Reset auto-advance and EOF flags — the new play supersedes any pending advance.
            root._autoAdvanceTriggered = false
            root._ipcEofReached = false
            // KEEP _userInitiatedPlay = true here! When _playProc.running = true kills
            // the old mpv, onExited fires synchronously. If _userInitiatedPlay were false,
            // that onExited would pass the guard and trigger a spurious playNext().
            // _userInitiatedPlay is cleared in _playProc.onRunningChanged when the new
            // mpv actually starts.

            // Refresh static cookie file for mpv before playing
            if (root.googleConnected) {
                _refreshCookiesForMpvProc.running = true
            }
            _playProc.running = true
        }
    }

    // Lightweight cookie refresh for mpv — exports fresh cookies from browser
    Process {
        id: _refreshCookiesForMpvProc
        command: ["python3", Directories.scriptPath + "/ytmusic_auth.py", root.googleBrowser]
    }

    // _trackEndDetector removed — track advancement is handled by _playProc.onExited (code 0)
    // Having both caused a race condition where playNext() could be called twice, skipping a track

    // Check if mpv-mpris plugin exists (optional — IPC fallback works without it)
    readonly property bool _hasMpvMpris: _mpvMprisExists
    property bool _mpvMprisExists: false

    Process {
        id: _checkMpvMpris
        command: ["/bin/sh", "-c", "test -f /usr/lib/mpv-mpris/mpris.so"]
        onExited: (code) => { root._mpvMprisExists = (code === 0) }
    }

    Process {
        id: _checkAvailability
        // Need yt-dlp, mpv and socat (for IPC fallback when MPRIS is absent)
        command: ["/bin/bash", "-c", "missing=''; command -v yt-dlp >/dev/null || missing=\"$missing yt-dlp\"; command -v mpv >/dev/null || missing=\"$missing mpv\"; command -v socat >/dev/null || missing=\"$missing socat\"; [ -z \"$missing\" ] && exit 0 || { echo \"$missing\"; exit 1; }"]
        stdout: SplitParser {
            onRead: line => {
                if (line.trim()) {
                    root.googleError = "Missing: " + line.trim() + ". Install with: sudo pacman -S" + line.trim()
                    root._log("[YtMusic] Missing dependencies:" + line.trim())
                }
            }
        }
        onExited: (code) => {
            root.available = (code === 0)
            root._log("[YtMusic] Dependencies check:", root.available ? "OK" : "FAILED")
            // If browser detection already finished, trigger auto-connect now
            if (root.available && !_detectBrowsersProc.running && root.autoConnectEnabled && !root.autoConnectAttempted) {
                root.autoConnectAttempted = true
                root._log("[YtMusic] Deps ready + browsers already detected:", JSON.stringify(root.detectedBrowsers))
                // If already connected from persisted state, just verify silently
                if (root.googleConnected && root._browserArgReady) {
                    root._log("[YtMusic] Already connected (persisted). Verifying silently...")
                    _googleCheckProc.running = true
                    return
                }
                // If we have a saved browser, use it
                if (Config.options?.sidebar?.ytmusic?.browser) {
                    Qt.callLater(_checkGoogleConnection)
                } else if (root.detectedBrowsers.length > 0) {
                    Qt.callLater(_checkGoogleConnection)
                }
            }
        }
    }

    Process {
        id: _googleCheckProc
        property string errorOutput: ""
        property string stdOutput: ""
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "-I", "1",
            "--print", "id",
            "https://www.youtube.com/feed/history"
        ]
        stdout: SplitParser {
            onRead: line => {
                _googleCheckProc.stdOutput += line + "\n"
            }
        }
        stderr: SplitParser {
            onRead: line => {
                _googleCheckProc.errorOutput += line + "\n"
            }
        }
        onStarted: { 
            errorOutput = ""; 
            stdOutput = "";
            root._log("[YtMusic] Starting connection check with browser:", root.googleBrowser)
        }
        onExited: (code) => {
            root._log("[YtMusic] Connection check exited. Code:", code, "Connected:", (code === 0 && stdOutput.trim().length > 0))
            if (code === 0 && stdOutput.trim().length > 0) {
                root.googleChecking = false
                root.googleConnected = true
                root.googleError = ""
                Config.setNestedValue('sidebar.ytmusic.connected', true)
                Config.setNestedValue('sidebar.ytmusic.resolvedBrowserArg', root._resolvedBrowserArg)
                root._log("[YtMusic] Successfully connected via --cookies-from-browser:", root._browserArgForYtdlp)
                // Export static cookie file for mpv use
                _exportCookiesProc.running = true
            } else {
                root.googleChecking = false
                root.googleConnected = false
                Config.setNestedValue('sidebar.ytmusic.connected', false)
                const err = errorOutput.toLowerCase()
                root._log("[YtMusic] Connection failed. Error output:", errorOutput.substring(0, 200))
                if (err.includes("sign in") || err.includes("403") || err.includes("not found")) {
                    root.googleError = Translation.tr("Could not connect. Log in to music.youtube.com in your browser first.")
                } else if (err.includes("cookies") || err.includes("browser") || err.includes("keyring")) {
                    root.googleError = Translation.tr("Could not read cookies. Close %1 and try again.").arg(root.getBrowserDisplayName(root.googleBrowser))
                } else if (err.includes("network") || err.includes("connection") || err.includes("unable to download")) {
                    root.googleError = Translation.tr("Network error. Check your internet connection.")
                } else {
                    root.googleError = Translation.tr("Could not connect. Log in to music.youtube.com in your browser first.")
                }
            }
        }
    }

    Process {
        id: _exportCookiesProc
        command: ["python3", Directories.scriptPath + "/ytmusic_auth.py", root.googleBrowser]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.status === "success" && res.cookies_path) {
                        root.customCookiesPath = res.cookies_path
                        Config.setNestedValue('sidebar.ytmusic.cookiesPath', res.cookies_path)
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: _deleteCookiesProc
        command: ["/bin/rm", "-f", root._cookiesFilePath]
    }

    Process {
        id: _searchProc
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            `ytsearch${root.maxSearchResults * 2}:${root._searchQuery} song`
        ]
        property var results: []
        
        onStarted: { results = [] }
        
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (!data.id || _searchProc.results.length >= root.maxSearchResults) return
                    const duration = data.duration || 0
                    if (duration < 30 || duration > 600) return
                    const title = (data.title || "").toLowerCase()
                    const videoKeywords = ['podcast', 'interview', 'documentary', 'tutorial', 
                                          'review', 'gameplay', 'walkthrough', 'vlog', 
                                          'episode', 'part ', 'full album', 'compilation',
                                          'hours of', 'asmr', 'white noise', 'rain sounds']
                    if (videoKeywords.some(kw => title.includes(kw))) return
                    _searchProc.results.push({
                        videoId: data.id,
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        duration: duration,
                        thumbnail: root._getThumbnailUrl(data.id),
                        url: data.url || `https://www.youtube.com/watch?v=${data.id}`
                    })
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                root.searchResults = results
                root.searching = false
            }
        }
        onExited: (code) => {
            if (code !== 0 && root.searchResults.length === 0) {
                root.error = Translation.tr("Search failed. Check your connection.")
            }
        }
    }

    // Use a short, guaranteed-existing path for the mpv IPC socket to avoid unix socket length issues
    property string ipcSocket: "/tmp/qs-ytmusic-mpv.sock"

    Process {
        id: _stopProc
        command: ["/bin/sh", "-c", "rm -f " + root.ipcSocket]
    }

    // Kill any orphaned mpv instances that use our IPC socket.
    // Handles processes that survived across inir restart or weren't cleaned up properly.
    Process {
        id: _killOrphanedMpvProc
        command: ["/bin/sh", "-c", "pkill -f 'mpv.*qs-ytmusic-mpv\\.sock' 2>/dev/null; true"]
    }

    function _stopMpv(): void {
        // Use running=false (not signal) so Quickshell marks the Process as stopped.
        // signal(15) sends SIGTERM but leaves running=true, so the next
        // _playProc.running=true becomes a no-op and orphans the old mpv.
        _playProc.running = false
        // Belt-and-suspenders: kill any orphaned mpv instances using our IPC socket
        _killOrphanedMpvProc.running = true
        _stopProc.running = true // clean up IPC socket
    }

    Process {
        id: _playProc
        property string _stderr: ""
        command: ["/usr/bin/mpv",
            "--no-video",
            "--force-window=no",
            "--audio-display=no",
            "--input-ipc-server=" + root.ipcSocket,
            ...(root._hasMpvMpris ? ["--script=/usr/lib/mpv-mpris/mpris.so"] : []),
            "--force-media-title=" + root.currentTitle + (root.currentArtist ? " - " + root.currentArtist : ""),
            "--metadata-codepage=utf-8",
            "--volume=" + root._savedVolume,
            "--audio-buffer=1",
            "--initial-audio-sync=yes",
            "--demuxer-max-bytes=50MiB",
            "--demuxer-readahead-secs=10",
            "--cache=yes",
            "--cache-secs=30",
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
            "--ytdl-format=" + root._ytdlFormat,
            ...(root.googleConnected && root._mpvCookiesFile ? [
                "--ytdl-raw-options=cookies=" + root._mpvCookiesFile + ",js-runtimes=node,remote-components=ejs:github",
                "--cookies-file=" + root._mpvCookiesFile
            ] : []),
            root._playUrl
        ]
        stderr: SplitParser {
            onRead: line => { _playProc._stderr += line + "\n" }
        }

        onStarted: {
            _stderr = ""
            root._log("[YtMusic] mpv started. URL:", root._playUrl)
        }
        onRunningChanged: {
            if (running) {
                root.loading = false
                // New mpv is confirmed running — safe to clear the guard now.
                // Any onExited from here on is for THIS mpv instance.
                root._userInitiatedPlay = false
                Qt.callLater(root._findMpvPlayer)
            }
        }
        onExited: (code) => {
            root._log("[YtMusic] mpv exited. Code:", code, "userInitiated:", root._userInitiatedPlay, "stderr:", _stderr.substring(0, 500))
            root.loading = false
            root._mpvPlayer = null
            // Skip auto-advance if a user-initiated play is pending — the old mpv was killed
            // to make room for the new one, this exit is NOT a natural track end.
            if (root._userInitiatedPlay) return
            if (root._didTrackEndNaturally(code, _stderr) && !root._autoAdvanceTriggered) {
                // Track ended naturally, advance according to playlist/queue/repeat state
                root._autoAdvanceTriggered = true
                root.playNext(true)
            } else if (code !== 0 && code !== 4 && code !== 9 && code !== 15 && code !== 143 && code !== 137) {
                const hint = _stderr.trim().split("\n").slice(-2).join(" ").substring(0, 120)
                root.error = Translation.tr("Playback failed") + (hint ? ": " + hint : "")
            }
        }
    }

    Process {
        id: _ytPlaylistsProc
        property var results: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "-j",
            "https://www.youtube.com/feed/playlists"
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    const systemPlaylists = ["LL", "WL", "LM", "RDMM", "RDEM"]
                    if (data.id && data.title && !systemPlaylists.includes(data.id)) {
                        _ytPlaylistsProc.results.push({
                            id: data.id,
                            title: data.title,
                            url: data.url || `https://www.youtube.com/playlist?list=${data.id}`,
                            count: data.playlist_count || 0
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { results = [] }
        onRunningChanged: {
            if (!running) {
                root.ytMusicPlaylists = results
                root.searching = false
            }
        }
    }

    Process {
        id: _importPlaylistProc
        property var items: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            root._importPlaylistUrl
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        _importPlaylistProc.items.push({
                            videoId: data.id,
                            title: data.title || "Unknown",
                            artist: data.channel || data.uploader || "",
                            duration: data.duration || 0,
                            thumbnail: root._getThumbnailUrl(data.id)
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { items = [] }
        onRunningChanged: {
            if (!running) {
                if (items.length > 0) {
                    root.playlists = [...root.playlists, {
                        name: root._importPlaylistName,
                        items: items
                    }]
                    root._persistPlaylists()
                }
                root.searching = false
            }
        }
    }
    
    IpcHandler {
        target: "ytmusic"
        
        function playPause(): void {
            root.togglePlaying()
        }
        
        function next(): void {
            root.playNext()
        }
        
        function previous(): void {
            root.playPrevious()
        }
        
        function stop(): void {
            root.stop()
        }
    }
}
