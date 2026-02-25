pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common

Singleton {
    id: root

    property bool available: false
    property bool searching: false
    property bool loading: false
    property bool libraryLoading: false
    property string error: ""
    
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentThumbnail: ""
    property string currentUrl: ""
    property string currentVideoId: ""
    property real currentDuration: 0
    property real currentPosition: 0
    
    property bool canPause: _mpvPlayer?.canPause ?? true
    property bool canSeek: _mpvPlayer?.canSeek ?? true
    property real volume: _mpvPlayer?.volume ?? 1.0
    
    property bool shuffleMode: Config.options?.sidebar?.ytmusic?.shuffleMode ?? false
    property int repeatMode: Config.options?.sidebar?.ytmusic?.repeatMode ?? 0
    
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
    
    property var currentArtistInfo: null
    
    property string userName: ""
    property string userAvatar: ""
    property string userChannelUrl: ""
    
    property bool googleConnected: false
    property bool googleChecking: false
    property string googleError: ""
    property string googleBrowser: "firefox"
    property string customCookiesPath: ""
    property list<string> detectedBrowsers: []
    property var ytMusicPlaylists: []
    property string defaultBrowser: ""
    property bool autoConnectAttempted: false
    property bool autoConnectEnabled: Config.options?.sidebar?.ytmusic?.autoConnect ?? true
    
    readonly property int maxRecentSearches: 10
    readonly property int maxLikedSongs: 200
    readonly property int maxSearchResults: 30
    
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
                }
            }
            
            function onIsPlayingChanged() {
                if (root._isOurMpv(modelData)) {
                    root._mpvPlayer = modelData
                }
            }
            
            function onPostTrackChanged() {
                if (root._isOurMpv(modelData)) {
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
            if (root._isOurMpv(player)) {
                root._mpvPlayer = player
                return
            }
        }
        root._mpvPlayer = null
    }
    
    Component.onCompleted: {
        _checkAvailability.running = true
        _checkMpvMpris.running = true
        _detectDefaultBrowserProc.running = true
        _detectBrowsersProc.running = true
        _loadData()
        _findMpvPlayer()
    }

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
    
    property bool _ipcPaused: false
    property bool isPlaying: _mpvPlayer?.isPlaying ?? !_ipcPaused

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
    
    function clearArtistInfo(): void {
        root.currentArtistInfo = null
    }

    property var _pendingItem: null
    property real _fadeVolume: 1.0
    
    function _playInternal(item): void {
        if (!item?.videoId || !root.available) return
        root.error = ""
        root.loading = true
        
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
        
        _stopProc.running = true
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
        console.log("[YtMusic] playFromPlaylist. playlist.length=" + (playlist?.length ?? "null") + " index=" + index + " source=" + source)
        if (!playlist || index < 0 || index >= playlist.length) return
        root.activePlaylist = [...playlist]
        root.currentIndex = index
        root.activePlaylistSource = source || "custom"
        console.log("[YtMusic] Set activePlaylist.length=" + root.activePlaylist.length + " currentIndex=" + root.currentIndex)
        _playInternal(playlist[index])
    }
    
    function playFromSearch(index): void {
        if (index >= 0 && index < searchResults.length) {
            playFromPlaylist(searchResults, index, "search")
        }
    }
    
    function playFromLiked(index): void {
        console.log("[YtMusic] playFromLiked. index=" + index + " likedSongs.length=" + likedSongs.length)
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
            if (q.length > 0) {
                root.activePlaylist = q
                root.currentIndex = 0
                root.activePlaylistSource = "queue"
            } else {
                root.activePlaylist = [item]
                root.currentIndex = 0
                root.activePlaylistSource = "single"
            }
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
        _stopProc.running = true
        root.loading = false
        root.currentVideoId = ""
        root.currentTitle = ""
        root.currentArtist = ""
        root.activePlaylist = []
        root.currentIndex = -1
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
        if (root._mpvPlayer) {
            root._mpvPlayer.volume = Math.max(0, Math.min(1, vol))
        } else {
            _sendIpc(["set_property", "volume", Math.round(vol * 100)])
        }
    }
    
    function getVolume(): real {
        return root._mpvPlayer?.volume ?? root._ipcVolume
    }
    
    property real _ipcVolume: 1.0

    function toggleShuffle(): void {
        root.shuffleMode = !root.shuffleMode
    }
    
    function cycleRepeatMode(): void {
        root.repeatMode = (root.repeatMode + 1) % 3
    }

    function playNext(): void {
        console.log("[YtMusic] playNext called. activePlaylist.length=" + activePlaylist.length + " currentIndex=" + currentIndex + " source=" + activePlaylistSource)
        
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
                    playFromQueue(0)
                    return
                }
                if (root.repeatMode === 2) {
                    nextIndex = 0
                } else {
                    return
                }
            }
            
            root.currentIndex = nextIndex
            _playInternal(root.activePlaylist[nextIndex])
            return
        }
        
        if (root.queue.length > 0) {
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
        _rateLikeProc._videoId = root.currentVideoId
        _rateLikeProc.running = true
    }

    function unlikeSong(videoId): void {
        const idx = root.likedSongs.findIndex(s => s.videoId === videoId)
        if (idx < 0) return
        let liked = [...root.likedSongs]
        liked.splice(idx, 1)
        root.likedSongs = liked
        Config.setNestedValue('sidebar.ytmusic.liked', root.likedSongs)
        // Send real unlike to YouTube via OAuth
        _rateUnlikeProc._videoId = videoId
        _rateUnlikeProc.running = true
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
                console.log("[YtMusic] QuickConnect succeeded with:", root._browserArgForYtdlp)
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
            if (code === 0 && _fetchLikedProc.newLiked.length > 0) {
                root.syncingLiked = false
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
        if (!root.googleConnected || root.syncingLiked) return
        root.syncingLiked = true
        _fetchLikedProc.running = true
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
    readonly property string _browserArgForYtdlp: root._resolvedBrowserArg || root.googleBrowser

    property var _cookieArgs: [
        "--cookies-from-browser", root._browserArgForYtdlp,
        "--js-runtimes", "node",
        "--remote-components", "ejs:github"
    ]

    // Static cookie file — only used by mpv (which can't use --cookies-from-browser)
    readonly property string _mpvCookiesFile: root._cookiesFilePath

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
                console.log("[YtMusic] Browser detection done. Detected:", JSON.stringify(root.detectedBrowsers), "Saved browser:", root.googleBrowser)
                // If already connected from persisted state, just verify silently
                if (root.googleConnected && root._browserArgReady) {
                    console.log("[YtMusic] Already connected (persisted). Verifying silently...")
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
                    console.log("[YtMusic] Resolved browser arg:", resolved)
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
                    console.log("[YtMusic] Missing dependencies:" + line.trim())
                }
            }
        }
        onExited: (code) => {
            root.available = (code === 0)
            console.log("[YtMusic] Dependencies check:", root.available ? "OK" : "FAILED")
            // If browser detection already finished, trigger auto-connect now
            if (root.available && !_detectBrowsersProc.running && root.autoConnectEnabled && !root.autoConnectAttempted) {
                root.autoConnectAttempted = true
                console.log("[YtMusic] Deps ready + browsers already detected:", JSON.stringify(root.detectedBrowsers))
                // If already connected from persisted state, just verify silently
                if (root.googleConnected && root._browserArgReady) {
                    console.log("[YtMusic] Already connected (persisted). Verifying silently...")
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
            console.log("[YtMusic] Starting connection check with browser:", root.googleBrowser)
        }
        onExited: (code) => {
            console.log("[YtMusic] Connection check exited. Code:", code, "Connected:", (code === 0 && stdOutput.trim().length > 0))
            if (code === 0 && stdOutput.trim().length > 0) {
                root.googleChecking = false
                root.googleConnected = true
                root.googleError = ""
                Config.setNestedValue('sidebar.ytmusic.connected', true)
                Config.setNestedValue('sidebar.ytmusic.resolvedBrowserArg', root._resolvedBrowserArg)
                console.log("[YtMusic] Successfully connected via --cookies-from-browser:", root._browserArgForYtdlp)
                // Export static cookie file for mpv use
                _exportCookiesProc.running = true
            } else {
                root.googleChecking = false
                root.googleConnected = false
                Config.setNestedValue('sidebar.ytmusic.connected', false)
                const err = errorOutput.toLowerCase()
                console.log("[YtMusic] Connection failed. Error output:", errorOutput.substring(0, 200))
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
                    if (duration < 60 || duration > 600) return
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
        command: ["/bin/bash", "-c", "pkill -f qs-ytmusic-mpv; rm -f " + root.ipcSocket]
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
            "--volume=100",
            "--audio-buffer=1",
            "--initial-audio-sync=yes",
            "--demuxer-max-bytes=50MiB",
            "--demuxer-readahead-secs=10",
            "--cache=yes",
            "--cache-secs=30",
            "--script-opts=ytdl_hook-ytdl_path=yt-dlp",
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
            console.log("[YtMusic] mpv started. URL:", root._playUrl)
        }
        onRunningChanged: {
            if (running) {
                root.loading = false
                Qt.callLater(root._findMpvPlayer)
            }
        }
        onExited: (code) => {
            console.log("[YtMusic] mpv exited. Code:", code, "stderr:", _stderr.substring(0, 500))
            root.loading = false
            root._mpvPlayer = null
            if (code === 0 && root.currentVideoId !== "") {
                // Normal exit = track ended naturally, play next
                root.playNext()
            } else if (code !== 0 && code !== 4 && code !== 9 && code !== 15 && code !== 143 && code !== 137) {
                root.error = Translation.tr("Playback failed")
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
