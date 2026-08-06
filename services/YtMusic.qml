pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services.deferred

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
    onAudioQualityChanged: {
        Config.setNestedValue('sidebar.ytmusic.audioQuality', audioQuality)
        // Apply the new quality to what's playing NOW (mpv's --ytdl-format is fixed at launch),
        // so the Settings control visibly correlates instead of only affecting the next track.
        if (root.currentVideoId !== "") root._reloadCurrentTrack()
    }
    // EBU R128 loudness normalization — matches YouTube Music's consistent ~-14 LUFS so tracks
    // don't jump between quiet/harsh. Applied as an mpv audio filter; reloads live like quality.
    readonly property bool normalizeVolume: Config.options?.sidebar?.ytmusic?.normalizeVolume ?? true
    onNormalizeVolumeChanged: if (root.currentVideoId !== "") root._reloadCurrentTrack()

    // Maps audioQuality setting to yt-dlp format string for mpv's --ytdl-format.
    // YouTube serves audio-only DASH at roughly ~50 kbps and ~130-135 kbps tiers (no middle), so:
    //   best   → highest available, preferring Opus (best codec; ~135k itag 251)
    //   medium → ≤130k, lands on the 130k m4a (itag 140) — broad device compatibility
    //   low    → smallest stream (~50k, data saver)
    // ([abr<=128] wrongly dropped the 130k tier and fell to ~50k — the old "medium" sounded bad.)
    readonly property string _ytdlFormat: {
        switch (root.audioQuality) {
            case "low": return "worstaudio"
            case "medium": return "bestaudio[abr<=130]/bestaudio"
            default: return "bestaudio[acodec=opus]/bestaudio/best"
        }
    }

    // One-shot seek (seconds) applied to the next mpv launch — used to resume the current
    // track in place after a quality change so playback doesn't jump back to the start.
    property real _resumeAtPosition: 0
    function _reloadCurrentTrack(): void {
        if (root.currentVideoId === "" || !root.available || root._playUrl === "") return
        root._resumeAtPosition = Math.max(0, root.currentPosition)
        root._userInitiatedPlay = true
        root._ipcEofReached = false
        root._stopMpv()
        _playDelayTimer.restart()
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
    
    // InnerTube owns the current browser-cookie session. Keep the legacy surface in sync with its
    // verified runtime state instead of trusting the persisted `connected` hint before validation.
    property bool googleConnected: InnerTube.authenticated
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
    // Account connect/auto-heal is owned by the InnerTube service now (rotation-safe direct cookie
    // read + YTM validation). This legacy yt-dlp-based auto-connect is disabled so the two flows
    // don't compete writing yt-cookies.txt (the old path rotated and clobbered a good session).
    readonly property bool autoConnectEnabled: false
    
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

    function _isYoutubeUrl(url): bool {
        const u = (url ?? "").toString().toLowerCase()
        return u.includes("youtube.com") || u.includes("youtu.be")
    }

    function _extractPlaylistId(url): string {
        const u = (url ?? "").toString()
        if (!u) return ""
        let m = u.match(/[?&]list=([A-Za-z0-9_-]+)/)
        if (m && m[1]) return m[1]
        m = u.match(/\/browse\/(VL[A-Za-z0-9_-]+)/)
        if (m && m[1]) return m[1]
        return ""
    }

    function _normalizeYoutubeUrl(url): string {
        return (url ?? "").toString().trim()
    }

    function _buildRelatedMixUrl(videoId, preferMusicMix): string {
        if (!videoId) return ""
        const listId = (preferMusicMix ? "RDAMVM" : "RDMM") + videoId
        return `https://music.youtube.com/watch?v=${videoId}&list=${listId}`
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
            // Keep the square YТM art set when the track was played; only derive the (16:9 video)
            // ytimg thumbnail as a fallback. Overwriting here is what letterboxed the player art.
            if (!root.currentThumbnail) root.currentThumbnail = root._getThumbnailUrl(vid)
        } else if (art && !root.currentThumbnail) {
            root.currentThumbnail = art
        }

        if (len > 0) root.currentDuration = len
        if (pos >= 0) root.currentPosition = pos
    }
    
    // P0-13: do nothing until the user enables the feature — no process spawns,
    // no disk reads. Initializes lazily when enabled flips at runtime.
    property bool _initialized: false
    Component.onCompleted: {
        if (root.enabled) root._initialize()
    }

    function _initialize() {
        if (root._initialized) return
        root._initialized = true
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
                if (root.currentDuration <= 0 && root._mpvPlayer.length > 0)
                    root.currentDuration = root._mpvPlayer.length
            } else if (!root._userInitiatedPlay) {
                _ipcQueryProc.running = true
                _ipcPauseQueryProc.running = true
            }

            // mpv knows the real duration once the stream is loaded; MPRIS `length` is often
            // missing for yt-dlp-streamed tracks, leaving the player stuck at 0:00. Query it
            // directly until we have it (stops firing once known).
            if (root.currentDuration <= 0 && root.ipcSocket)
                _ipcDurationQueryProc.running = true

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
        id: _ipcDurationQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"duration\"] }' | socat - " + root.ipcSocket + " 2>/dev/null"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (typeof res.data === "number" && res.data > 0) root.currentDuration = res.data
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
    property bool isPlaying: _mpvPlayer?.isPlaying
        ?? (_playProc.running && root.currentVideoId !== ""
            && !root._ipcPaused && !root._ipcEofReached)

    onEnabledChanged: {
        if (enabled) {
            root._initialize()
        } else {
            root.stop()
        }
    }

    function search(query, filter): void {
        if (!query.trim() || !root.available) return
        root.error = ""
        const trimmed = query.trim()
        const f = filter || "songs"
        if (root._isYoutubeUrl(trimmed)) {
            root.searching = true
            root.searchResults = []
            const normalizedUrl = root._normalizeYoutubeUrl(trimmed)
            const videoId = root._extractVideoId(normalizedUrl)
            const playlistId = root._extractPlaylistId(normalizedUrl)

            if (videoId) {
                root._resolveYoutubeTrackUrl = normalizedUrl
                _resolveYoutubeTrackProc.running = true
            } else if (playlistId) {
                root._resolveYoutubePlaylistUrl = normalizedUrl
                _resolveYoutubePlaylistProc.running = true
            } else {
                root.searching = false
                root.error = Translation.tr("Could not resolve this YouTube Music URL.")
            }

            _addToRecentSearches(trimmed)
            return
        }

        root.searching = true
        root.searchResults = []
        _searchQuery = trimmed
        // Prefer the InnerTube engine (no browser cookies, real YT Music songs).
        // Fall back to yt-dlp only when ytmusicapi is unavailable.
        if (InnerTube.available) {
            root._searchViaInnerTube = true
            InnerTube.search(trimmed, f)
        } else {
            root._searchViaInnerTube = false
            _searchProc.running = true
        }
        _addToRecentSearches(trimmed)
    }

    // Bridges InnerTube's async results back onto YtMusic's existing surface so the
    // current UI keeps binding to YtMusic.searchResults unchanged.
    property bool _searchViaInnerTube: false
    Connections {
        target: InnerTube
        function onSearchResultsChanged() {
            if (!root._searchViaInnerTube) return
            root.searchResults = InnerTube.searchResults
            root.searching = false
            root._searchViaInnerTube = false
        }
        function onRadioTracksChanged() { root._onRadioTracks() }
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
        // mpv starts without --pause; clear the previous track's paused state so
        // the isPlaying fallback reports true instead of a stale false for up to
        // the first IPC poll after the player starts.
        root._ipcPaused = false
        
        _fadeOutOtherPlayers()
        
        root.currentTitle = item.title || ""
        root.currentArtist = item.artist || ""
        root.currentVideoId = item.videoId || ""
        // Prefer the item's real (square) YT Music art; fall back to the derived 16:9 video
        // thumbnail only when none was provided. Using the video thumbnail unconditionally is what
        // letterboxed the player art with black bars.
        root.currentThumbnail = item.thumbnail || _getThumbnailUrl(item.videoId)
        root.currentUrl = item.url || `https://www.youtube.com/watch?v=${item.videoId}`
        root.currentDuration = item.duration || 0
        root.currentPosition = 0
        root._resumeAtPosition = 0   // normal play starts from the top

        root._playUrl = root.currentUrl
        root._pendingItem = item
        
        root._stopMpv()
        _playDelayTimer.restart()
    }
    
    function play(item): void {
        if (!item?.videoId) return
        root.activePlaylist = [item]
        root.currentIndex = 0
        root.activePlaylistSource = item.enableRelatedQueue ? "related-pending" : "single"
        _playInternal(item)
        if (item.enableRelatedQueue) {
            root._startRelatedQueue(item)
        } else {
            root._clearRelatedQueue()
        }
    }
    
    function playFromPlaylist(playlist, index, source): void {
        root._log("[YtMusic] playFromPlaylist. playlist.length=" + (playlist?.length ?? "null") + " index=" + index + " source=" + source)
        if (!playlist || index < 0 || index >= playlist.length) return
        const item = playlist[index]
        if (playlist.length === 1 && item?.enableRelatedQueue) {
            root.play(item)
            return
        }
        root.activePlaylist = [...playlist]
        root.currentIndex = index
        root.activePlaylistSource = source || "custom"
        root._clearRelatedQueue()
        root._log("[YtMusic] Set activePlaylist.length=" + root.activePlaylist.length + " currentIndex=" + root.currentIndex)
        _playInternal(item)
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
        // Mark this exit as intentional before stopping mpv. Depending on timing, Quickshell may
        // deliver onExited synchronously or after the rest of this function has cleared the track.
        root._userInitiatedPlay = true
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
        root._clearRelatedQueue()
        root._clearResume()
    }

    function _startRelatedQueue(item): void {
        if (!item?.videoId) return
        root._relatedSeedVideoId = item.videoId
        root._relatedSeedTitle = item.title || ""
        root._relatedSeedArtist = item.artist || ""
        root._relatedSeedDuration = item.duration || 0
        root._relatedSeedThumbnail = item.thumbnail || root._getThumbnailUrl(item.videoId)
        root._relatedSeedUrl = item.url || `https://www.youtube.com/watch?v=${item.videoId}`
        root._relatedQueueTriedFallback = false
        root._relatedQueuePending = true
        // Prefer InnerTube's watch-playlist (radio) — same source InnerTune uses.
        if (InnerTube.available) {
            InnerTube.loadRadio(item.videoId)
        } else if (!_relatedQueueProc.running) {
            _relatedQueueProc.running = true
        }
    }

    // Builds the autoplay playlist from InnerTube radio tracks, mirroring the
    // yt-dlp related-queue fill: seed first, then continuation, source "related".
    function _onRadioTracks(): void {
        const tracks = InnerTube.radioTracks
        if (!root._relatedSeedVideoId || root.currentVideoId !== root._relatedSeedVideoId) return
        if (!tracks || tracks.length === 0) {
            // Fall back to yt-dlp related mix if the radio came back empty.
            if (!_relatedQueueProc.running) _relatedQueueProc.running = true
            return
        }
        let playlist = [...tracks]
        let currentIdx = playlist.findIndex(t => t.videoId === root._relatedSeedVideoId)
        if (currentIdx < 0) {
            playlist.unshift({
                videoId: root._relatedSeedVideoId,
                title: root._relatedSeedTitle || root.currentTitle,
                artist: root._relatedSeedArtist || root.currentArtist,
                duration: root._relatedSeedDuration || root.currentDuration,
                thumbnail: root._relatedSeedThumbnail || root.currentThumbnail,
                url: root._relatedSeedUrl || root.currentUrl
            })
            currentIdx = 0
        }
        root.activePlaylist = playlist
        root.currentIndex = currentIdx
        root.activePlaylistSource = "related"
        root._clearRelatedQueue()
    }

    function _clearRelatedQueue(): void {
        root._relatedSeedVideoId = ""
        root._relatedSeedTitle = ""
        root._relatedSeedArtist = ""
        root._relatedSeedDuration = 0
        root._relatedSeedThumbnail = ""
        root._relatedSeedUrl = ""
        root._relatedQueueTriedFallback = false
        root._relatedQueuePending = false
    }

    function _didTrackEndNaturally(code: int, stderrText: string): bool {
        if (!root.currentVideoId) return false
        // Signal-killed exits are never natural — we killed mpv to switch tracks.
        if (code === 9 || code === 15 || code === 137 || code === 143) return false
        // mpv documents 0 as successful playback completion. Exit 4 means it quit because of a
        // signal or quit command; treating it as EOF made failed/interrupted starts skip tracks.
        if (code === 0) return true
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

    function moveActivePlaylistItem(from, to): void {
        if (from < 0 || to < 0 || from >= root.activePlaylist.length || to >= root.activePlaylist.length || from === to) return
        let playlist = [...root.activePlaylist]
        const item = playlist.splice(from, 1)[0]
        playlist.splice(to, 0, item)
        root.activePlaylist = playlist
        if (root.currentIndex === from) {
            root.currentIndex = to
        } else if (from < root.currentIndex && to >= root.currentIndex) {
            root.currentIndex -= 1
        } else if (from > root.currentIndex && to <= root.currentIndex) {
            root.currentIndex += 1
        }
        if (root.currentVideoId) root._persistResume()
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
        // Prefer the InnerTube account login; fall back to the legacy YouTube Data OAuth.
        if (InnerTube.authenticated) {
            InnerTube.rateSong(root.currentVideoId, true)
        } else if (root.oauthConfigured) {
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
        // Prefer the InnerTube account login; fall back to the legacy YouTube Data OAuth.
        if (InnerTube.authenticated) {
            InnerTube.rateSong(videoId, false)
        } else if (root.oauthConfigured) {
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
        Config.setNestedValues({
            'sidebar.ytmusic.connected': false,
            'sidebar.ytmusic.resolvedBrowserArg': "",
            'sidebar.ytmusic.profile.name': "",
            'sidebar.ytmusic.profile.avatar': "",
            'sidebar.ytmusic.profile.url': ""
        })
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
        Config.setNestedValues({
            'sidebar.ytmusic.profile.name': root.userName,
            'sidebar.ytmusic.profile.avatar': root.userAvatar,
            'sidebar.ytmusic.profile.url': root.userChannelUrl
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
    property string _resolveYoutubeTrackUrl: ""
    property string _resolveYoutubePlaylistUrl: ""
    property string _importPlaylistUrl: ""
    property string _importPlaylistName: ""
    property string _relatedSeedVideoId: ""
    property string _relatedSeedTitle: ""
    property string _relatedSeedArtist: ""
    property int _relatedSeedDuration: 0
    property string _relatedSeedThumbnail: ""
    property string _relatedSeedUrl: ""
    property bool _relatedQueueTriedFallback: false
    property bool _relatedQueuePending: false

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

    // Unified cookie source: the InnerTube account flow now owns connecting and maintains the
    // shared yt-cookies.txt (rotation-safe direct read). Playback reads that static file rather
    // than yt-dlp's --cookies-from-browser, whose completed YouTube request rotates and invalidates
    // the session. When no account is connected, omit cookies entirely (public playback still works).
    // Only use cookies after a session has been validated in this process. The persisted flag is
    // merely an auto-heal hint; using it directly feeds stale cookies to yt-dlp during startup.
    readonly property bool _hasCookieSession: InnerTube.authenticated || root.googleConnected
    property var _cookieArgs: root._hasCookieSession
        ? ["--cookies", root._mpvCookiesFile, "--js-runtimes", "node", "--remote-components", "ejs:github"]
        : ["--js-runtimes", "node", "--remote-components", "ejs:github"]

    // Static cookie file — used by mpv (which can't use --cookies-from-browser)
    // When user provides a manual cookies file, use that instead of the auto-exported one
    readonly property string _mpvCookiesFile: root._useManualCookies && root.customCookiesPath
        ? root.customCookiesPath : root._cookiesFilePath
    // yt-dlp's --cookies option writes the jar back after a request. Playback therefore gets a
    // disposable copy so server-side rotations can never corrupt InnerTube's canonical session.
    readonly property string _playbackCookiesFile: Directories.cachePath + "/inir/ytmusic-playback-cookies.txt"

    function _getThumbnailUrl(videoId): string {
        if (!videoId) return ""
        if (videoId.length !== 11 || videoId.startsWith("UC")) return ""
        // hqdefault (480x360) always exists and is far sharper than mqdefault (320x180); the player's
        // highRes path steps up to sddefault (640x480) with graceful fallback. Square YTM cover art
        // (from InnerTube) is preferred when the track carries it — this is the videoId-only fallback.
        return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
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

            _playProc.running = true
        }
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
        command: ["/bin/rm", "-f", "--", root._cookiesFilePath, root._playbackCookiesFile]
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

    Process {
        id: _resolveYoutubeTrackProc
        property var item: null
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "-j",
            "--no-warnings",
            "--quiet",
            root._resolveYoutubeTrackUrl
        ]
        onStarted: { item = null }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    const videoId = data.id || root._extractVideoId(root._resolveYoutubeTrackUrl)
                    if (!videoId) return
                    _resolveYoutubeTrackProc.item = {
                        videoId: videoId,
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        duration: data.duration || 0,
                        thumbnail: root._getThumbnailUrl(videoId),
                        url: data.webpage_url || data.url || root._resolveYoutubeTrackUrl,
                        enableRelatedQueue: true
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                root.searching = false
                if (item) {
                    root.searchResults = [item]
                } else {
                    root.error = Translation.tr("Could not resolve this YouTube Music URL.")
                }
            }
        }
    }

    Process {
        id: _resolveYoutubePlaylistProc
        property var items: []
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            root._resolveYoutubePlaylistUrl
        ]
        onStarted: { items = [] }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (!data.id) return
                    const duration = data.duration || 0
                    if (duration && (duration < 30 || duration > 600)) return
                    items.push({
                        videoId: data.id,
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        duration: duration,
                        thumbnail: root._getThumbnailUrl(data.id),
                        url: data.url || data.webpage_url || `https://music.youtube.com/watch?v=${data.id}`
                    })
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running) {
                root.searching = false
                if (items.length > 0) {
                    root.searchResults = items
                } else {
                    root.error = Translation.tr("Could not resolve this YouTube playlist.")
                }
            }
        }
    }

    Process {
        id: _relatedQueueProc
        property var items: []
        property string requestVideoId: ""
        property bool requestUsedFallback: false
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist",
            "--playlist-end", "25",
            "--no-warnings",
            "--quiet",
            "-j",
            root._buildRelatedMixUrl(root._relatedSeedVideoId, !root._relatedQueueTriedFallback)
        ]
        onStarted: {
            items = []
            requestVideoId = root._relatedSeedVideoId
            requestUsedFallback = root._relatedQueueTriedFallback
            root._relatedQueuePending = false
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (!data.id) return
                    const duration = data.duration || 0
                    if (duration && (duration < 30 || duration > 900)) return
                    items.push({
                        videoId: data.id,
                        title: data.title || "Unknown",
                        artist: data.channel || data.uploader || "",
                        duration: duration,
                        thumbnail: root._getThumbnailUrl(data.id),
                        url: data.url || data.webpage_url || `https://music.youtube.com/watch?v=${data.id}`
                    })
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (running) return

            if (root._relatedQueuePending) {
                _relatedQueueProc.running = true
                return
            }

            if (items.length === 0 && requestVideoId && !requestUsedFallback && requestVideoId === root._relatedSeedVideoId) {
                root._relatedQueueTriedFallback = true
                _relatedQueueProc.running = true
                return
            }

            if (!requestVideoId || requestVideoId !== root._relatedSeedVideoId) {
                return
            }

            if (!root._relatedSeedVideoId || root.currentVideoId !== root._relatedSeedVideoId) {
                root._clearRelatedQueue()
                return
            }

            if (items.length === 0) {
                root._clearRelatedQueue()
                return
            }

            let playlist = [...items]
            let currentIdx = playlist.findIndex(item => item.videoId === root._relatedSeedVideoId)

            if (currentIdx < 0) {
                playlist.unshift({
                    videoId: root._relatedSeedVideoId,
                    title: root._relatedSeedTitle || root.currentTitle,
                    artist: root._relatedSeedArtist || root.currentArtist,
                    duration: root._relatedSeedDuration || root.currentDuration,
                    thumbnail: root._relatedSeedThumbnail || root.currentThumbnail,
                    url: root._relatedSeedUrl || root.currentUrl
                })
                currentIdx = 0
            }

            root.activePlaylist = playlist
            root.currentIndex = currentIdx
            root.activePlaylistSource = "related"
            root._clearRelatedQueue()
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
        function _mpvArgs(): var {
            return ["/usr/bin/mpv",
            "--no-video",
            "--force-window=no",
            "--audio-display=no",
            "--input-ipc-server=" + root.ipcSocket,
            ...(root._hasMpvMpris ? ["--script=/usr/lib/mpv-mpris/mpris.so"] : []),
            "--force-media-title=" + root.currentTitle + (root.currentArtist ? " - " + root.currentArtist : ""),
            "--metadata-codepage=utf-8",
            "--volume=" + root._savedVolume,
            "--volume-max=100",
            ...(root.normalizeVolume ? ["--af=loudnorm=I=-14:TP=-1.5:LRA=11"] : []),
            ...(root._resumeAtPosition > 1 ? ["--start=+" + Math.floor(root._resumeAtPosition)] : []),
            "--audio-buffer=1",
            "--initial-audio-sync=yes",
            "--demuxer-max-bytes=50MiB",
            "--demuxer-readahead-secs=10",
            "--cache=yes",
            "--cache-secs=30",
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
            "--ytdl-format=" + root._ytdlFormat,
            ...(root._hasCookieSession && root._mpvCookiesFile ? [
                "--ytdl-raw-options=cookies=" + root._playbackCookiesFile + ",js-runtimes=node,remote-components=ejs:github",
                "--cookies-file=" + root._playbackCookiesFile
            ] : []),
            root._playUrl
            ]
        }
        command: {
            const args = _playProc._mpvArgs()
            if (!root._hasCookieSession || !root._mpvCookiesFile) return args
            // Copy and exec in one process lifecycle: mpv cannot start against a half-written jar,
            // and Quickshell still supervises the final mpv process directly after shell `exec`.
            return [
                "/bin/sh", "-c",
                "/usr/bin/install -Dm600 -- \"$1\" \"$2\" && shift 2 && exec \"$@\"",
                "_", root._mpvCookiesFile, root._playbackCookiesFile,
                ...args
            ]
        }
        stderr: SplitParser {
            onRead: line => { _playProc._stderr += line + "\n" }
        }

        onStarted: {
            _stderr = ""
            // Consume the one-shot resume seek so a later natural play starts from the top.
            root._resumeAtPosition = 0
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
            if (root._userInitiatedPlay || root.currentVideoId === "") return
            if (root._didTrackEndNaturally(code, _stderr) && !root._autoAdvanceTriggered) {
                // Track ended naturally, advance according to playlist/queue/repeat state
                root._autoAdvanceTriggered = true
                root.playNext(true)
            } else if (code !== 0 && code !== 9 && code !== 15 && code !== 143 && code !== 137) {
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
