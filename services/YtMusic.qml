pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

/**
 * YT Music service - Search and play music from YouTube using yt-dlp + mpv.
 * Features: MPRIS, Library Sync (Playlists, Albums), Queue, Persistent Cache.
 */
Singleton {
    id: root

    // === Public State ===
    property bool available: false
    property bool searching: false
    property bool loading: false
    property bool libraryLoading: false
    property string error: ""
    
    // Current track info
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property string currentUrl: ""
    property string currentVideoId: ""
    property real currentDuration: 0
    property real currentPosition: 0
    
    // Playback state
    property bool isPlaying: _mpvPlayer?.isPlaying ?? false
    property bool canPause: _mpvPlayer?.canPause ?? false
    property bool canSeek: _mpvPlayer?.canSeek ?? false
    property real volume: _mpvPlayer?.volume ?? 1.0
    
    // Collections (Runtime)
    property var searchResults: []
    property var recentSearches: []
    property var queue: []
    
    // Cloud Library (Synced & Cached)
    property var cloudPlaylists: []
    property var cloudAlbums: []
    property var cloudLiked: []
    
    // Google account
    property bool googleConnected: false
    property bool googleChecking: false
    property string googleError: ""
    property string googleBrowser: Config.options?.sidebar?.ytmusic?.browser ?? "firefox"
    property string customCookiesPath: Config.options?.sidebar?.ytmusic?.cookiesPath ?? ""
    property list<string> detectedBrowsers: [] 
    
    readonly property int maxRecentSearches: 10
    readonly property int maxSearchResults: 20
    
    // Browser metadata
    readonly property var browserInfo: ({
        "firefox": { name: "Firefox", icon: "🦊" },
        "chrome": { name: "Chrome", icon: "🌐" },
        "chromium": { name: "Chromium", icon: "🔵" },
        "brave": { name: "Brave", icon: "🦁" },
        "vivaldi": { name: "Vivaldi", icon: "🎼" },
        "opera": { name: "Opera", icon: "🔴" },
        "edge": { name: "Edge", icon: "🔷" },
        "zen": { name: "Zen", icon: "☯️" },
        "librewolf": { name: "LibreWolf", icon: "🐺" },
        "floorp": { name: "Floorp", icon: "🌊" },
        "waterfox": { name: "Waterfox", icon: "💧" }
    })

    // === MPRIS Player Reference ===
    property MprisPlayer _mpvPlayer: {
        for (const player of Mpris.players.values) {
            if (player.identity === "mpv" || player.desktopEntry === "mpv") {
                return player
            }
        }
        return null
    }

    // Sync position
    Timer {
        interval: 1000
        running: root._mpvPlayer !== null && root.isPlaying
        repeat: true
        onTriggered: {
            if (root._mpvPlayer) root.currentPosition = root._mpvPlayer.position
        }
    }

    // === Public Functions ===
    
    function search(query): void {
        if (!query.trim() || !root.available) return
        root.error = ""
        root.searching = true
        root.searchResults = []
        _searchQuery = query.trim()
        
        // Try searching with cookies first if connected, otherwise fallback to public
        _searchProc.useCookies = root.googleConnected
        _searchProc.running = true
        
        _addToRecentSearches(query.trim())
    }

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
        if (index >= 0 && index < searchResults.length) play(searchResults[index])
    }

    function stop(): void {
        _playProc.running = false
        root.loading = false
    }

    function togglePlaying(): void {
        if (root._mpvPlayer) root._mpvPlayer.togglePlaying()
    }

    function seek(position): void {
        if (root._mpvPlayer && root.canSeek) root._mpvPlayer.position = position
    }

    function setVolume(vol): void {
        if (root._mpvPlayer) root._mpvPlayer.volume = Math.max(0, Math.min(1, vol))
    }

    // Queue
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
        if (root.queue.length > 0) {
            const next = root.queue[0]
            root.queue = root.queue.slice(1)
            _persistQueue()
            play(next)
        }
    }

    function playQueue(): void {
        if (root.queue.length > 0) playNext()
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

    // Account & Sync
    function connectGoogle(browser): void {
        root.googleBrowser = browser || "firefox"
        root.googleError = ""
        root.googleChecking = true
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
        root.cloudPlaylists = []
        root.cloudAlbums = []
        root.cloudLiked = []
        _persistCache()
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

    function fetchLibrary(): void {
        if (!root.googleConnected) return
        console.log("[YtMusic] Fetching library...")
        root.libraryLoading = true
        _ytPlaylistsProc.running = true
        _ytAlbumsProc.running = true
        _likedSongsProc.running = true
    }

    function importYtMusicPlaylist(playlistUrl): void {
        if (!playlistUrl) return
        root.searching = true
        _importPlaylistUrl = playlistUrl
        _importPlaylistProc.running = true
    }

    function clearRecentSearches(): void {
        root.recentSearches = []
        _persistRecentSearches()
    }

    // === Private ===
    property string _searchQuery: ""
    property string _playUrl: ""
    property string _importPlaylistUrl: ""
    
    property var _cookieArgs: root.customCookiesPath 
        ? ["--cookies", root.customCookiesPath] 
        : ["--cookies-from-browser", root.googleBrowser]

    property string _mpvCookieArgs: root.customCookiesPath
        ? "cookies=" + root.customCookiesPath
        : "cookies-from-browser=" + root.googleBrowser

    function _getThumbnailUrl(videoId): string {
        if (!videoId) return ""
        if (videoId.length !== 11 || videoId.startsWith("UC")) return ""
        return `https://i.ytimg.com/vi/${videoId}/mqdefault.jpg`
    }

    Component.onCompleted: {
        _checkAvailability.running = true
        _detectDefaultBrowserProc.running = true
        _detectBrowsersProc.running = true
        if (Config.ready) _loadData()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) _loadData()
        }
    }

    function _loadData(): void {
        root.recentSearches = Config.options?.sidebar?.ytmusic?.recentSearches ?? []
        root.queue = Config.options?.sidebar?.ytmusic?.queue ?? []
        
        // Load cached library
        root.cloudPlaylists = Config.options?.sidebar?.ytmusic?.cache?.playlists ?? []
        root.cloudAlbums = Config.options?.sidebar?.ytmusic?.cache?.albums ?? []
        root.cloudLiked = Config.options?.sidebar?.ytmusic?.cache?.liked ?? []
        
        const savedBrowser = Config.options?.sidebar?.ytmusic?.browser
        if (savedBrowser) root.googleBrowser = savedBrowser
        
        // Auto-connect if configured
        Qt.callLater(_checkGoogleConnection)
    }

    function _persistCache(): void {
        Config.setNestedValue('sidebar.ytmusic.cache.playlists', root.cloudPlaylists)
        Config.setNestedValue('sidebar.ytmusic.cache.albums', root.cloudAlbums)
        Config.setNestedValue('sidebar.ytmusic.cache.liked', root.cloudLiked)
    }

    // Detect system default browser
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
    
    property string defaultBrowser: ""

    // Detect installed browsers
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
        if (recent.length > root.maxRecentSearches) recent = recent.slice(0, root.maxRecentSearches)
        root.recentSearches = recent
        _persistRecentSearches()
    }

    function _persistRecentSearches(): void {
        Config.setNestedValue('sidebar.ytmusic.recentSearches', root.recentSearches)
    }

    function _persistQueue(): void {
        Config.setNestedValue('sidebar.ytmusic.queue', root.queue)
    }

    function _checkGoogleConnection(): void {
        _googleCheckProc.running = true
    }

    Timer {
        id: _playDelayTimer
        interval: 200
        onTriggered: _playProc.running = true
    }

    // Auto-play next
    Connections {
        target: root._mpvPlayer
        enabled: root._mpvPlayer !== null
        function onPlaybackStateChanged() {
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && 
                root.currentVideoId && root.queue.length > 0) {
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
            if (root._mpvPlayer && !root._mpvPlayer.isPlaying && root.queue.length > 0) {
                root.playNext()
            }
        }
    }

    Process {
        id: _checkAvailability
        command: ["/usr/bin/which", "yt-dlp"]
        onExited: (code) => { root.available = (code === 0) }
    }

    Process {
        id: _googleCheckProc
        property string outputData: ""
        command: ["/usr/bin/python3",
            Quickshell.workingDirectory + "/scripts/ytmusic_auth.py",
            root.customCookiesPath ? "" : root.googleBrowser
        ]
        stdout: SplitParser { onRead: line => _googleCheckProc.outputData += line }
        onStarted: { outputData = ""; root.googleChecking = true }
        onExited: (code) => {
            root.googleChecking = false
            try {
                const result = JSON.parse(outputData)
                if (result.status === "success") {
                    console.log("[YtMusic] Connected successfully via " + result.source)
                    root.googleConnected = true
                    root.googleError = ""
                    // Auto-fetch if cache is empty
                    if (root.cloudPlaylists.length === 0) root.fetchLibrary()
                } else {
                    console.warn("[YtMusic] Connection failed: " + result.message)
                    root.googleConnected = false
                    root.googleError = result.message || Translation.tr("Connection failed")
                }
            } catch (e) {
                root.googleConnected = false
                root.googleError = Translation.tr("Failed to verify connection.")
            }
        }
    }

    // Search Process with Fallback
    Process {
        id: _searchProc
        property bool useCookies: false
        
        command: ["/usr/bin/yt-dlp",
            ...(useCookies ? root._cookieArgs : []),
            "--flat-playlist", "--no-warnings", "--quiet", "-j",
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
        
        stderr: SplitParser {
            onRead: line => console.warn("[YtMusic] Search error: " + line)
        }
        
        onRunningChanged: { if (!running) root.searching = false }
        
        onExited: (code) => {
            if (code !== 0) {
                if (useCookies) {
                    console.log("[YtMusic] Search with cookies failed, retrying without cookies...")
                    // Fallback: try without cookies
                    _searchProc.useCookies = false
                    _searchProc.running = true
                } else {
                    root.error = Translation.tr("Search failed.")
                }
            }
        }
    }

    Process {
        id: _stopProc
        command: ["/usr/bin/pkill", "-f", "mpv.*--no-video"]
    }

    Process {
        id: _playProc
        command: ["/usr/bin/mpv",
            "--no-video", "--really-quiet",
            "--force-media-title=" + root.currentTitle,
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
            ...(root.googleConnected ? ["--ytdl-raw-options=" + root._mpvCookieArgs] : []),
            root._playUrl
        ]
        onRunningChanged: { if (running) root.loading = false }
        onExited: (code) => { root.loading = false }
    }

    // --- Library Fetchers ---

    // 1. Playlists
    Process {
        id: _ytPlaylistsProc
        property var results: []
        command: ["/usr/bin/yt-dlp", ...root._cookieArgs, "--flat-playlist", "--no-warnings", "--quiet", "-j", "https://music.youtube.com/library/playlists"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id && data.title) {
                        _ytPlaylistsProc.results.push({
                            id: data.id,
                            title: data.title,
                            url: data.url || `https://music.youtube.com/playlist?list=${data.id}`,
                            count: data.playlist_count || 0,
                            thumbnail: "" 
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { results = [] }
        onRunningChanged: {
            if (!running) {
                console.log("[YtMusic] Fetched " + results.length + " playlists")
                root.cloudPlaylists = results
                root._persistCache()
                checkLibraryLoading()
            }
        }
    }

    // 2. Albums
    Process {
        id: _ytAlbumsProc
        property var results: []
        command: ["/usr/bin/yt-dlp", ...root._cookieArgs, "--flat-playlist", "--no-warnings", "--quiet", "-j", "https://music.youtube.com/library/albums"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    if (data.id && data.title) {
                        _ytAlbumsProc.results.push({
                            id: data.id,
                            title: data.title,
                            artist: data.uploader || data.channel || "",
                            url: data.url || `https://music.youtube.com/playlist?list=${data.id}`
                        })
                    }
                } catch (e) {}
            }
        }
        onStarted: { results = [] }
        onRunningChanged: {
            if (!running) {
                console.log("[YtMusic] Fetched " + results.length + " albums")
                root.cloudAlbums = results
                root._persistCache()
                checkLibraryLoading()
            }
        }
    }
    
    // 3. Liked Songs (Limited to 50 for speed)
    Process {
        id: _likedSongsProc
        property var items: []
        command: ["/usr/bin/yt-dlp", ...root._cookieArgs, "--flat-playlist", "--no-warnings", "--quiet", "-j", "-I", "1:50", "https://music.youtube.com/playlist?list=LM"]
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
            if (!running) {
                console.log("[YtMusic] Fetched " + items.length + " liked songs")
                root.cloudLiked = items
                root._persistCache()
                checkLibraryLoading()
            }
        }
    }

    function checkLibraryLoading() {
        if (!_ytPlaylistsProc.running && !_ytAlbumsProc.running && !_likedSongsProc.running) {
            root.libraryLoading = false
        }
    }

    // Import Playlist (Play immediately)
    Process {
        id: _importPlaylistProc
        property var items: []
        // Use cookies if available for better access (e.g. private playlists)
        command: ["/usr/bin/yt-dlp", 
            ...(root.googleConnected ? root._cookieArgs : []),
            "--flat-playlist", "--no-warnings", "--quiet", "-j", root._importPlaylistUrl
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
                root.queue = items
                root._persistQueue()
                root.play(items[0])
                root.searching = false
            }
        }
    }
}
