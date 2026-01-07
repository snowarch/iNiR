pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * YT Music service - Search and play music from YouTube using yt-dlp + mpv.
 * 
 * Features:
 * - MPRIS integration (mpv exposes controls, synced with MprisController)
 * - Playlist management (save/load custom playlists)
 * - Google account sync (via browser cookies for YouTube Music playlists)
 * - Queue management with persistence
 */
Singleton {
    id: root

    // === Public State ===
    property bool available: false
    property bool searching: false
    property bool loading: false
    property bool libraryLoading: false
    property string error: ""
    
    // Auto-connect state
    property bool autoConnectAttempted: false
    property bool autoConnectEnabled: Config.options?.sidebar?.ytmusic?.autoConnect ?? true
    
    // Current track info (synced with MPRIS when available)
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property string currentUrl: ""
    property string currentVideoId: ""
    property real currentDuration: 0
    property real currentPosition: 0
    
    // Playback state - isPlaying defined below with IPC fallback
    property bool canPause: _mpvPlayer?.canPause ?? true
    property bool canSeek: _mpvPlayer?.canSeek ?? true
    property real volume: _mpvPlayer?.volume ?? 1.0
    
    // Playback modes (persisted to config)
    property bool shuffleMode: Config.options?.sidebar?.ytmusic?.shuffleMode ?? false
    property int repeatMode: Config.options?.sidebar?.ytmusic?.repeatMode ?? 0  // 0: off, 1: repeat one, 2: repeat all
    
    onShuffleModeChanged: Config.setNestedValue('sidebar.ytmusic.shuffleMode', shuffleMode)
    onRepeatModeChanged: Config.setNestedValue('sidebar.ytmusic.repeatMode', repeatMode)
    
    // Collections
    property var searchResults: []
    property var recentSearches: []
    property var queue: []
    property var playlists: []  // [{name, items: [{videoId, title, artist, duration, thumbnail}]}]
    property list<var> likedSongs: []
    property string lastLikedSync: ""
    property bool syncingLiked: false
    
    // Artist info (populated when searching or playing artist content)
    property var currentArtistInfo: null  // {name, channelId, thumbnail, subscribers, description}
    
    // User Profile
    property string userName: ""
    property string userAvatar: ""
    property string userChannelUrl: ""
    
    // Google Account State
    property bool googleConnected: false
    property bool googleChecking: false
    property string googleError: ""
    property string googleBrowser: "firefox"
    property string customCookiesPath: ""
    property list<string> detectedBrowsers: []
    property var ytMusicPlaylists: []  // Playlists from YouTube Music account
    
    // Config limits
    readonly property int maxRecentSearches: 10
    readonly property int maxLikedSongs: 200 // Limit to keep config size manageable
    readonly property int maxSearchResults: 30
    
    // Supported browsers with their cookie paths
    readonly property var browserInfo: ({
        "firefox": { name: "Firefox", icon: "🦊", configPath: "~/.mozilla/firefox" },
        "chrome": { name: "Chrome", icon: "🌐", configPath: "~/.config/google-chrome" },
        "chromium": { name: "Chromium", icon: "🔵", configPath: "~/.config/chromium" },
        "brave": { name: "Brave", icon: "🦁", configPath: "~/.config/BraveSoftware" },
        "vivaldi": { name: "Vivaldi", icon: "🎼", configPath: "~/.config/vivaldi" },
        "opera": { name: "Opera", icon: "🔴", configPath: "~/.config/opera" },
        "edge": { name: "Edge", icon: "🔷", configPath: "~/.config/microsoft-edge" },
        "zen": { name: "Zen", icon: "☯️", configPath: "~/.zen" },
        "librewolf": { name: "LibreWolf", icon: "🐺", configPath: "~/.librewolf" },
        "floorp": { name: "Floorp", icon: "🌊", configPath: "~/.floorp" },
        "waterfox": { name: "Waterfox", icon: "💧", configPath: "~/.waterfox" }
    })

    // === MPRIS Player Reference ===
    property MprisPlayer _mpvPlayer: null
    
    // Find mpv player using Instantiator pattern (like MprisController)
    Instantiator {
        model: Mpris.players
        
        Connections {
            required property MprisPlayer modelData
            target: modelData
            
            Component.onCompleted: {
                if (modelData.identity === "mpv" || modelData.desktopEntry === "mpv" ||
                    modelData.identity?.includes("mpv") || modelData.desktopEntry?.includes("mpv")) {
                    root._mpvPlayer = modelData
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
            if (player.identity === "mpv" || player.desktopEntry === "mpv" || 
                player.identity?.includes("mpv") || player.desktopEntry?.includes("mpv")) {
                root._mpvPlayer = player
                return
            }
        }
        root._mpvPlayer = null
    }
    
    Component.onCompleted: {
        _checkAvailability.running = true
        _detectDefaultBrowserProc.running = true
        _detectBrowsersProc.running = true
        _loadData()
        _findMpvPlayer()
    }

    // Sync position - always run when playing, use MPRIS or IPC
    Timer {
        interval: 500
        running: root.currentVideoId !== ""
        repeat: true
        onTriggered: {
            if (root._mpvPlayer) {
                root.currentPosition = root._mpvPlayer.position
                root._ipcPaused = !root._mpvPlayer.isPlaying
            } else {
                _ipcQueryProc.running = true
                _ipcPauseQueryProc.running = true
            }
        }
    }
    
    Process {
        id: _ipcQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"time-pos\"] }' | socat - " + root.ipcSocket]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.data !== undefined) {
                        root.currentPosition = res.data
                    }
                } catch(e) {}
            }
        }
    }
    
    Process {
        id: _ipcPauseQueryProc
        command: ["/bin/sh", "-c", "echo '{ \"command\": [\"get_property\", \"pause\"] }' | socat - " + root.ipcSocket]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.data !== undefined) {
                        root._ipcPaused = res.data
                    }
                } catch(e) {}
            }
        }
    }
    
    property bool _ipcPaused: false
    
    // isPlaying now checks both MPRIS and IPC state
    property bool isPlaying: _mpvPlayer?.isPlaying ?? !_ipcPaused

    // === Public Functions ===
    
    // Search - also searches for artist if query looks like an artist name
    function search(query): void {
        if (!query.trim() || !root.available) return
        root.error = ""
        root.searching = true
        root.searchResults = []
        root.currentArtistInfo = null
        _searchQuery = query.trim()
        _searchProc.running = true
        _addToRecentSearches(query.trim())
    }
    
    // Clear artist info
    function clearArtistInfo(): void {
        root.currentArtistInfo = null
    }

    // Playback control
    function play(item): void {
        if (!item?.videoId || !root.available) return
        root.error = ""
        root.loading = true
        root.currentTitle = item.title || ""
        root.currentArtist = item.artist || ""
        root.currentVideoId = item.videoId || ""
        root.currentThumbnail = _getThumbnailUrl(item.videoId)
        root.currentUrl = item.url || `https://www.youtube.com/watch?v=${item.videoId}`
        root.currentDuration = item.duration || 0
        root.currentPosition = 0
        
        _stopProc.running = true
        _playUrl = root.currentUrl
        _playDelayTimer.restart()
    }

    function playFromSearch(index): void {
        if (index >= 0 && index < searchResults.length) {
            play(searchResults[index])
        }
    }

    function stop(): void {
        _playProc.running = false
        root.loading = false
    }

    // IPC Control
    Process {
        id: _ipcProc
        property string commandData
        command: ["/bin/sh", "-c", "echo '" + commandData + "' | socat - " + root.ipcSocket]
    }
    
    function _sendIpc(cmd): void {
        // Check if socket exists (mpv running) rather than process state
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
        if (root._mpvPlayer) {
            root._mpvPlayer.volume = Math.max(0, Math.min(1, vol))
        } else {
            // mpv volume is 0-100, not 0-1
            _sendIpc(["set_property", "volume", Math.round(vol * 100)])
        }
    }
    
    function getVolume(): real {
        return root._mpvPlayer?.volume ?? root._ipcVolume
    }
    
    property real _ipcVolume: 1.0

    // Playback mode controls
    function toggleShuffle(): void {
        root.shuffleMode = !root.shuffleMode
    }
    
    function cycleRepeatMode(): void {
        root.repeatMode = (root.repeatMode + 1) % 3
    }

    // Queue management
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

    function playNext(): void {
        // Repeat One: replay current track
        if (root.repeatMode === 1 && root.currentVideoId) {
            seek(0)
            if (!root.isPlaying) togglePlaying()
            return
        }
        
        if (root.queue.length > 0) {
            let nextIndex = 0
            if (root.shuffleMode && root.queue.length > 1) {
                nextIndex = Math.floor(Math.random() * root.queue.length)
            }
            const next = root.queue[nextIndex]
            let q = [...root.queue]
            q.splice(nextIndex, 1)
            root.queue = q
            _persistQueue()
            play(next)
        } else if (root.repeatMode === 2 && root.currentVideoId) {
            // Repeat All with empty queue: restart current track
            seek(0)
            if (!root.isPlaying) togglePlaying()
        } else if (root.searchResults.length > 0) {
            // Play next from search results
            const currentIdx = root.searchResults.findIndex(r => r.videoId === root.currentVideoId)
            if (currentIdx >= 0 && currentIdx < root.searchResults.length - 1) {
                play(root.searchResults[currentIdx + 1])
            } else if (root.searchResults.length > 0) {
                // Loop to first result
                play(root.searchResults[0])
            }
        }
    }
    
    function playPrevious(): void {
        // If more than 3 seconds in, restart current track
        if (root.currentPosition > 3) {
            seek(0)
            return
        }
        
        // Otherwise try to play previous from search results
        if (root.searchResults.length > 0) {
            const currentIdx = root.searchResults.findIndex(r => r.videoId === root.currentVideoId)
            if (currentIdx > 0) {
                play(root.searchResults[currentIdx - 1])
                return
            }
        }
        
        // Fallback: restart current track
        seek(0)
    }

    function playQueue(): void {
        if (root.queue.length > 0) {
            playNext()
        }
    }

    function shuffleQueue(): void {
        if (root.queue.length < 2) return
        let q = [...root.queue]
        // Fisher-Yates shuffle
        for (let i = q.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [q[i], q[j]] = [q[j], q[i]]
        }
        root.queue = q
        _persistQueue()
    }

    // Playlist management
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
        // Avoid duplicates
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
    }

    function unlikeSong(videoId): void {
        const idx = root.likedSongs.findIndex(s => s.videoId === videoId)
        if (idx < 0) return
        let liked = [...root.likedSongs]
        liked.splice(idx, 1)
        root.likedSongs = liked
        Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
    }

    function playPlaylist(playlistIndex, shuffle): void {
        if (playlistIndex < 0 || playlistIndex >= root.playlists.length) return
        let items = [...root.playlists[playlistIndex].items]
        if (items.length === 0) return
        
        if (shuffle) {
            // Fisher-Yates shuffle
            for (let i = items.length - 1; i > 0; i--) {
                const j = Math.floor(Math.random() * (i + 1));
                [items[i], items[j]] = [items[j], items[i]]
            }
        }
        
        root.queue = items.slice(1)
        _persistQueue()
        play(items[0])
    }

    // Google account / YouTube Music
    function connectGoogle(browser): void {
        root.googleBrowser = browser || "firefox"
        root.googleError = ""
        root.googleChecking = true
        // Clear custom cookies if switching to browser
        if (root.customCookiesPath) {
            root.customCookiesPath = ""
            Config.setNestedValue('sidebar.ytmusic.cookiesPath', "")
        }
        Config.setNestedValue('sidebar.ytmusic.browser', root.googleBrowser)
        _checkGoogleConnection()
    }

    function setCustomCookiesPath(path): void {
        if (!path) return
        root.customCookiesPath = path
        root.googleError = ""
        root.googleChecking = true
        Config.setNestedValue('sidebar.ytmusic.cookiesPath', path)
        _checkGoogleConnection()
    }

    function disconnectGoogle(): void {
        root.googleConnected = false
        root.googleError = ""
        root.ytMusicPlaylists = []
    }
    
    // Quick connect - tries default browser, then all detected browsers
    function quickConnect(): void {
        if (root.googleConnected || root.googleChecking) return
        root.googleError = ""
        root.googleChecking = true
        root._quickConnectIndex = 0
        root._tryNextBrowser()
    }
    
    property int _quickConnectIndex: 0
    property var _browsersToTry: []
    
    function _tryNextBrowser(): void {
        // Build priority list: default browser first, then detected browsers
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
        _quickConnectProc.running = true
    }
    
    Process {
        id: _quickConnectProc
        command: ["python3", "scripts/ytmusic_auth.py", root.googleBrowser]
        
        stdout: SplitParser {
            onRead: line => {
                try {
                    const res = JSON.parse(line)
                    if (res.status === "success") {
                        root.googleConnected = true
                        root.googleError = ""
                        root.customCookiesPath = res.cookies_path
                        Config.setNestedValue('sidebar.ytmusic.cookiesPath', res.cookies_path)
                        Config.setNestedValue('sidebar.ytmusic.browser', root.googleBrowser)
                        root.fetchUserProfile()
                    } else {
                        root.googleConnected = false
                        root.googleError = res.message || Translation.tr("Connection failed.")
                    }
                } catch (e) {
                    console.log("Auth Error: " + e)
                }
            }
        }
        
        onExited: (code) => {
            root.googleChecking = false
        }
    }
    
    // Fetch User Profile (Name & Avatar)
    Process {
        id: _fetchProfileProc
        // Step 1: Get name and channel URL from library
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
                    // Step 2: Trigger avatar fetch
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
                        // Get the last (highest res) thumbnail
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
        // Trigger other syncs
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
        _googleCheckProc.running = true
    }
    
    function getBrowserDisplayName(browserId): string {
        return root.browserInfo[browserId]?.name ?? browserId
    }

    Process {
        id: _fetchLikedProc
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--print", "%(title)s|%(uploader)s|%(id)s|%(duration)s",
            "--playlist-end", root.maxLikedSongs.toString(),
            "https://music.youtube.com/playlist?list=LM"
        ]
        
        property var newLiked: []
        
        onStarted: { newLiked = [] }
        
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split("|")
                if (parts.length >= 3) {
                    _fetchLikedProc.newLiked.push({
                        title: parts[0],
                        artist: parts[1],
                        videoId: parts[2],
                        duration: parseFloat(parts[3] || "0"),
                        thumbnail: root._getThumbnailUrl(parts[2])
                    })
                }
            }
        }
        
        onExited: (code) => {
            root.syncingLiked = false
            if (code === 0) {
                root.likedSongs = _fetchLikedProc.newLiked
                root.lastLikedSync = new Date().toLocaleString(Qt.locale(), "yyyy-MM-dd hh:mm")
                Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
                Config.setNestedValue('sidebar.ytmusic.lastLikedSync', root.lastLikedSync)
            }
        }
    }
    
    function fetchLikedSongs(): void {
        if (!root.googleConnected || root.syncingLiked) return
        root.syncingLiked = true
        _fetchLikedProc.running = true
    }
    
    // Automatically sync liked songs when connected
    /* onGoogleConnectedChanged removed due to syntax ambiguity */
    
    function fetchYtMusicPlaylists(): void {
        fetchLikedPlaylists() // Alias for compatibility
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

    // Recent searches
    function clearRecentSearches(): void {
        root.recentSearches = []
        _persistRecentSearches()
    }

    // === Private ===
    property string _searchQuery: ""
    property string _playUrl: ""
    property string _importPlaylistUrl: ""
    property string _importPlaylistName: ""
    
    property var _cookieArgs: root.customCookiesPath 
        ? ["--cookies", root.customCookiesPath] 
        : ["--cookies-from-browser", root.googleBrowser]

    property string _mpvCookieArgs: root.customCookiesPath
        ? "cookies=" + root.customCookiesPath
        : "cookies-from-browser=" + root.googleBrowser

    function _getThumbnailUrl(videoId): string {
        if (!videoId) return ""
        // Validate videoId - should be 11 chars and not a channel ID (UC prefix)
        if (videoId.length !== 11 || videoId.startsWith("UC")) return ""
        return `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`
    }

    // Component.onCompleted moved to top with _findMpvPlayer
    
    // Auto-connect when browser detection completes
    Connections {
        target: _detectBrowsersProc
        function onRunningChanged() {
            if (!_detectBrowsersProc.running && root.autoConnectEnabled && !root.autoConnectAttempted) {
                root.autoConnectAttempted = true
                // Try to connect with detected default browser
                if (root.defaultBrowser && root.detectedBrowsers.includes(root.defaultBrowser)) {
                    Qt.callLater(() => root._checkGoogleConnection())
                } else if (root.detectedBrowsers.length > 0) {
                    // Fallback to first detected browser
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
        
        const profile = Config.options?.sidebar?.ytmusic?.profile
        if (profile) {
            root.userName = profile.name ?? ""
            root.userAvatar = profile.avatar ?? ""
            root.userChannelUrl = profile.url ?? ""
        }
        
        // Use saved browser, or wait for default detection
        const savedBrowser = Config.options?.sidebar?.ytmusic?.browser
        if (savedBrowser) {
            root.googleBrowser = savedBrowser
        }
        // Check Google connection after a delay
        Qt.callLater(_checkGoogleConnection)
    }

    // Detect system default browser
    Process {
        id: _detectDefaultBrowserProc
        command: ["/usr/bin/xdg-settings", "get", "default-web-browser"]
        stdout: SplitParser {
            onRead: line => {
                // Parse "firefox.desktop" -> "firefox", "google-chrome.desktop" -> "chrome"
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
    
    property string defaultBrowser: ""

    // Detect installed browsers by checking config folders
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

    function _checkGoogleConnection(): void {
        if (!root.available) return
        root.googleChecking = true
        _googleCheckProc.running = true
    }

    Timer {
        id: _playDelayTimer
        interval: 200
        onTriggered: _playProc.running = true
    }

    // Auto-play next when track ends
    Connections {
        target: root._mpvPlayer
        enabled: root._mpvPlayer !== null
        
        function onPlaybackStateChanged() {
            // When mpv stops and we have queue items, play next
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && 
                root.currentVideoId && root.queue.length > 0) {
                // Small delay to distinguish between pause and track end
                _autoNextTimer.restart()
            } else {
                _autoNextTimer.stop()
            }
        }
    }

    Timer {
        id: _autoNextTimer
        interval: 500
        onTriggered: {
            // Double-check mpv is really stopped (not just paused)
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && root.queue.length > 0) {
                root.playNext()
            }
        }
    }

    // Check if yt-dlp is available
    Process {
        id: _checkAvailability
        command: ["/usr/bin/which", "yt-dlp"]
        onExited: (code) => {
            root.available = (code === 0)
        }
    }

    // Check Google account connection by testing access to YT Music
    Process {
        id: _googleCheckProc
        property string errorOutput: ""
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-I", "1",
            "--print", "id",
            "https://music.youtube.com/library/playlists"
        ]
        stderr: SplitParser {
            onRead: line => {
                _googleCheckProc.errorOutput += line + "\n"
            }
        }
        onStarted: { errorOutput = "" }
        onExited: (code) => {
            root.googleChecking = false
            if (code === 0) {
                root.googleConnected = true
                root.googleError = ""
            } else {
                root.googleConnected = false
                // Parse error to give helpful message
                if (errorOutput.includes("cookies") || errorOutput.includes("browser")) {
                    root.googleError = Translation.tr("Could not read cookies from %1. Make sure the browser is closed.").arg(root.googleBrowser)
                } else if (errorOutput.includes("Sign in") || errorOutput.includes("login") || errorOutput.includes("403")) {
                    root.googleError = Translation.tr("Not logged in. Open YouTube Music in your browser and sign in first.")
                } else if (errorOutput.includes("network") || errorOutput.includes("connection")) {
                    root.googleError = Translation.tr("Network error. Check your internet connection.")
                } else {
                    root.googleError = Translation.tr("Connection failed. Try a different browser or log in again.")
                }
            }
        }
    }

    // Search YouTube
    Process {
        id: _searchProc
        command: ["/usr/bin/yt-dlp",
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            `ytsearch${root.maxSearchResults}:${root._searchQuery}`
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        root.searchResults = [...root.searchResults, {
                            videoId: data.id,
                            title: data.title || "Unknown",
                            artist: data.channel || data.uploader || "",
                            duration: data.duration || 0,
                            thumbnail: root._getThumbnailUrl(data.id),
                            url: data.url || `https://www.youtube.com/watch?v=${data.id}`
                        }]
                    }
                } catch (e) {}
            }
        }
        onRunningChanged: {
            if (!running) root.searching = false
        }
        onExited: (code) => {
            if (code !== 0 && root.searchResults.length === 0) {
                root.error = Translation.tr("Search failed. Check your connection.")
            }
            // Extract artist info from first result if available
            if (root.searchResults.length > 0) {
                const first = root.searchResults[0]
                if (first.artist) {
                    root.currentArtistInfo = {
                        name: first.artist,
                        channelId: "",
                        channelUrl: "",
                        thumbnail: first.thumbnail || "",
                        subscribers: 0
                    }
                }
            }
        }
    }

    property string ipcSocket: "/tmp/qs-ytmusic-mpv.sock"

    // Stop any existing mpv playback
    Process {
        id: _stopProc
        command: ["/usr/bin/pkill", "-f", "mpv.*--no-video"]
    }

    // Play audio via mpv (exposes MPRIS via mpv-mpris)
    Process {
        id: _playProc
        command: ["/usr/bin/mpv",
            "--no-video",
            "--really-quiet",
            "--input-ipc-server=" + root.ipcSocket,
            "--script=/usr/lib/mpv-mpris/mpris.so",
            "--force-media-title=" + root.currentTitle + (root.currentArtist ? " - " + root.currentArtist : ""),
            "--metadata-codepage=utf-8",
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
            ...(root.googleConnected ? ["--ytdl-raw-options=" + root._mpvCookieArgs] : []),
            root._playUrl
        ]
        onRunningChanged: {
            if (running) {
                root.loading = false
                // Re-find mpv player after a short delay
                Qt.callLater(root._findMpvPlayer)
            }
        }
        onExited: (code) => {
            root.loading = false
            root._mpvPlayer = null
            if (code !== 0 && code !== 4 && code !== 9 && code !== 15) { // 9=KILL, 15=TERM
                root.error = Translation.tr("Playback failed")
            }
        }
    }

    // Fetch YouTube Music playlists from account
    Process {
        id: _ytPlaylistsProc
        property var results: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            "https://music.youtube.com/library/playlists"
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id && data.title) {
                        _ytPlaylistsProc.results.push({
                            id: data.id,
                            title: data.title,
                            url: data.url || `https://music.youtube.com/playlist?list=${data.id}`,
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

    // Import a YouTube Music playlist
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
            if (!running && items.length > 0) {
                root.playlists = [...root.playlists, {
                    name: root._importPlaylistName,
                    items: items
                }]
                root._persistPlaylists()
                root.searching = false
            }
        }
    }
    
    // Fetch Liked Songs from YouTube Music
    Process {
        id: _likedSongsProc
        property var items: []
        command: ["/usr/bin/yt-dlp",
            ...root._cookieArgs,
            "--flat-playlist",
            "--no-warnings",
            "--quiet",
            "-j",
            "-I", "1:100",  // Limit to first 100 liked songs for performance
            "https://music.youtube.com/playlist?list=LM"
        ]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id) {
                        _likedSongsProc.items.push({
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
            if (!running && items.length > 0) {
                // Check if "Liked Songs" playlist already exists
                const existingIdx = root.playlists.findIndex(p => p.name === "Liked Songs")
                if (existingIdx >= 0) {
                    // Update existing
                    let p = [...root.playlists]
                    p[existingIdx].items = items
                    root.playlists = p
                } else {
                    // Create new
                    root.playlists = [...root.playlists, {
                        name: "Liked Songs",
                        items: items
                    }]
                }
                root._persistPlaylists()
                root.searching = false
            }
        }
    }
}
