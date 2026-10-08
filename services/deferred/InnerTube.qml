pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

// InnerTube browsing engine — wraps scripts/innertube.py (ytmusicapi).
// Public browsing needs NO cookies; replaces the flaky yt-dlp + browser-cookie path.
// Playback stays in YtMusic.qml (mpv/MPRIS); this service only fetches metadata.
//
// Each command has its own Process so independent surfaces (e.g. search from the UI and
// radio autoplay) never race over shared parser state.
Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.ytmusic?.enable ?? false
    property bool ready: false
    property bool available: false       // ytmusicapi importable (probed via ping)
    property bool authenticated: false   // a logged-in session that actually works for browse
    property string accountName: ""
    property string accountAvatar: ""
    // Cookie-based connect (the working auth path — YouTube disabled the public device-flow client).
    property bool connecting: false
    property string connectError: ""     // "" | "not_logged_in" | "no_browser" | other
    property var detectedBrowsers: []    // [{id,name,kind,profile}] installed browsers with a cookie store
    property string defaultBrowser: ""   // system default web browser id, if detected
    property string connectedBrowser: "" // which browser the active session came from ("manual" for imports)

    // Per-surface results (InnerTune screens map onto these).
    property var searchResults: []
    property var homeShelves: []
    property var radioTracks: []
    property var artistPage: ({})
    property var albumPage: ({})
    property var playlistPage: ({})
    property var libraryPages: ({})
    property var libraryLoaded: ({})
    property var lyrics: ({})
    property string radioLyricsId: ""

    property bool searching: false
    property bool homeLoading: false
    property bool radioLoading: false
    property bool browseLoading: false
    property bool libraryLoading: false
    property string error: ""
    property string _libraryRequestKind: ""
    property bool _initialized: false

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log("[InnerTube]", ...args);
    }

    readonly property string _runner: Directories.scriptPath + "/innertube-runtime.sh"

    function ensureInitialized(): void {
        if (root._initialized || !root.enabled) return;
        root._initialized = true;
        _pingProc.running = true;
    }

    function retryAvailability(): void {
        if (!root.enabled || _pingProc.running) return;
        root.error = "";
        _pingProc.running = true;
    }

    Component.onCompleted: {
        root.ready = true;
        root.ensureInitialized();
    }

    // Config loads asynchronously. The feature can still be false when this
    // singleton is constructed even though it is enabled in the persisted config.
    onEnabledChanged: if (root.enabled) root.ensureInitialized()

    // ---- ping (availability probe) ----
    Process {
        id: _pingProc
        command: [root._runner, "ping"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    root.available = !!d.available;
                    if (!d.available) root._log("unavailable:", d.error);
                    else { root.detectBrowsers(); root.refreshAuth(); }
                } catch (e) {
                    root.available = false;
                }
            }
        }
    }

    // ---- login (device flow with the public YouTube-TV client) ----
    property bool loggingIn: false
    property string loginUserCode: ""
    property string loginVerificationUrl: ""
    property string _loginDeviceCode: ""

    function startLogin(): void {
        if (!root.available || root.loggingIn) return;
        root.loggingIn = true;
        root.loginUserCode = "";
        root.loginVerificationUrl = "";
        _loginReqProc.exec([root._runner, "oauth-request"]);
    }
    function cancelLogin(): void {
        root.loggingIn = false;
        _loginPollTimer.stop();
        root.loginUserCode = "";
    }
    function logout(): void {
        _logoutProc.exec([root._runner, "logout"]);
    }

    // ---- cookie connect (reuse the logged-in browser's YouTube session) ----
    // "auto" (default) detects installed browsers and tries each until one yields a working
    // personalized session. An explicit id extracts only from that browser. Firefox-family
    // browsers are read straight from cookies.sqlite (rotation-safe); Chromium via yt-dlp.
    function connect(browser): void {
        if (root.connecting) return;
        root.connecting = true;
        root.connectError = "";
        _connectProc.exec([root._runner, "connect", browser || "auto"]);
    }
    // Manual fallback: import a cookies.txt exported via the reliable incognito method.
    function connectManual(path): void {
        if (root.connecting || !path) return;
        root.connecting = true;
        root.connectError = "";
        _connectProc.exec([root._runner, "connect-manual", path]);
    }
    function disconnect(): void {
        _disconnectProc.exec([root._runner, "disconnect"]);
    }
    // Enumerate installed browsers + system default for the account picker.
    function detectBrowsers(): void {
        _detectProc.exec([root._runner, "detect-browsers"]);
    }
    Process {
        id: _detectProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    root.detectedBrowsers = d.browsers || [];
                    root.defaultBrowser = d.default || "";
                } catch (e) { root.detectedBrowsers = []; }
            }
        }
    }
    Process {
        id: _connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.connecting = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.authenticated) {
                        root.authenticated = true;
                        root.accountName = d.account || "";
                        root.accountAvatar = d.avatar || "";
                        root.connectedBrowser = d.browser || "";
                        root.connectError = "";
                        // Persist the working browser so playback (mpv/yt-dlp) reuses the same source.
                        if (d.browser && d.browser !== "manual" && d.browser !== "auto")
                            Config.setNestedValue("sidebar.ytmusic.browser", d.browser);
                        Config.setNestedValue("sidebar.ytmusic.connected", true);
                        root.loadHome();
                    } else {
                        root.authenticated = false;
                        root.connectError = d.error || "failed";
                    }
                } catch (e) { root.connectError = "failed"; }
            }
        }
    }
    Process {
        id: _disconnectProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.authenticated = false;
                root.accountName = "";
                root.accountAvatar = "";
                root.connectedBrowser = "";
                root.libraryPages = {};
                root.libraryLoaded = {};
                Config.setNestedValue("sidebar.ytmusic.connected", false);
            }
        }
    }

    Process {
        id: _loginReqProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    if (d.error || !d.user_code) { root.loggingIn = false; root.error = d.error || "login failed"; return; }
                    root.loginUserCode = d.user_code;
                    root.loginVerificationUrl = d.verification_url;
                    root._loginDeviceCode = d.device_code;
                    _loginPollTimer.interval = Math.max(3, d.interval || 5) * 1000;
                    _loginPollTimer.start();
                } catch (e) { root.loggingIn = false; }
            }
        }
    }
    // Raw poll timer (not a visual token) — device-flow polling cadence.
    Timer {
        id: _loginPollTimer
        repeat: true
        onTriggered: if (root.loggingIn && root._loginDeviceCode) _loginPollProc.exec([root._runner, "oauth-poll", root._loginDeviceCode])
    }
    Process {
        id: _loginPollProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    if (d.status === "authorized") {
                        _loginPollTimer.stop();
                        root.loggingIn = false;
                        root.loginUserCode = "";
                        root.refreshAuth();
                    } else if (d.status === "error") {
                        _loginPollTimer.stop();
                        root.loggingIn = false;
                        root.error = d.error || "login failed";
                    }
                } catch (e) {}
            }
        }
    }
    Process {
        id: _logoutProc
        stdout: StdioCollector { onStreamFinished: root.refreshAuth() }
    }

    // ---- auth status (reuses iNiR OAuth; re-probe when login state changes) ----
    function refreshAuth(): void {
        if (!root.available) return;
        _authProc.exec([root._runner, "auth-status"]);
    }
    Process {
        id: _authProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    const was = root.authenticated;
                    root.authenticated = !!d.authenticated;
                    root.accountName = d.account || "";
                    root.accountAvatar = d.avatar || "";
                    if (root.authenticated) {
                        if (!(Config.options?.sidebar?.ytmusic?.connected ?? false))
                            Config.setNestedValue("sidebar.ytmusic.connected", true);
                    }
                    if (!root.authenticated) {
                        root.libraryPages = {};
                        root.libraryLoaded = {};
                    }
                    // Refresh personalized home once we transition to signed-in.
                    if (root.authenticated && !was) root.loadHome();
                } catch (e) {}
            }
        }
    }

    // Reusable JSONL parser factory state holder. Each streaming Process accumulates into
    // its own buffer, then commits on the {_done} sentinel.
    component StreamCollector: SplitParser {
        property var buffer: []
        property string lyricsId: ""
        signal finished(var items, string lyricsId)
        onRead: (line) => {
            if (!line) return;
            let obj;
            try { obj = JSON.parse(line); } catch (e) { return; }
            if (obj._meta) { if (obj.lyricsId !== undefined) lyricsId = obj.lyricsId; return; }
            if (obj.error) { root.error = obj.error; return; }
            if (obj._done) { finished(buffer, lyricsId); buffer = []; lyricsId = ""; return; }
            buffer.push(obj);
        }
    }

    // ---- search ----
    function search(query, filter): void {
        if (!query || !root.available) return;
        root.error = "";
        root.searching = true;
        _searchProc.exec([root._runner, "search", query, filter || "songs"]);
    }
    Process {
        id: _searchProc
        stdout: StreamCollector { onFinished: (items) => { root.searchResults = items; root.searching = false; } }
    }

    // ---- radio (autoplay watch-playlist) ----
    function loadRadio(videoId): void {
        if (!videoId || !root.available) return;
        root.error = "";
        root.radioLoading = true;
        root.radioLyricsId = "";
        _radioProc.exec([root._runner, "radio", videoId]);
    }
    Process {
        id: _radioProc
        stdout: StreamCollector {
            onFinished: (items, lid) => { root.radioTracks = items; root.radioLyricsId = lid; root.radioLoading = false; }
        }
    }

    // ---- playlist ----
    function loadPlaylist(playlistId): void {
        if (!playlistId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _playlistProc.exec([root._runner, "playlist", playlistId]);
    }
    Process {
        id: _playlistProc
        stdout: StreamCollector { onFinished: (items) => { root.playlistPage = { tracks: items }; root.browseLoading = false; } }
    }

    // ---- library ----
    function loadLibrary(kind, force): void {
        if (!kind || !root.available || !root.authenticated) return;
        if (!force && (root.libraryLoaded[kind] ?? false)) return;
        root.error = "";
        root.libraryLoading = true;
        root._libraryRequestKind = kind;
        _libraryProc.exec([root._runner, "library", kind]);
    }
    Process {
        id: _libraryProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.libraryLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    const kind = d.kind || root._libraryRequestKind;
                    const pages = Object.assign({}, root.libraryPages);
                    const loaded = Object.assign({}, root.libraryLoaded);
                    pages[kind] = d.items || [];
                    loaded[kind] = true;
                    root.libraryPages = pages;
                    root.libraryLoaded = loaded;
                } catch (e) { root.error = "library parse error"; }
            }
        }
    }

    // ---- rating ----
    function rateSong(videoId, liked): void {
        if (!videoId || !root.available || !root.authenticated) return;
        _rateProc.exec([root._runner, "rate", videoId, liked ? "LIKE" : "INDIFFERENT"]);
    }
    Process {
        id: _rateProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) root.error = d.error;
                } catch (e) {}
            }
        }
    }

    // ---- home ----
    function loadHome(): void {
        if (!root.available) return;
        root.error = "";
        root.homeLoading = true;
        _homeProc.exec([root._runner, "home"]);
    }
    Process {
        id: _homeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.homeLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.homeShelves = d.shelves || [];
                } catch (e) { root.error = "home parse error"; }
            }
        }
    }

    // ---- artist ----
    function loadArtist(browseId): void {
        if (!browseId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _artistProc.exec([root._runner, "artist", browseId]);
    }
    Process {
        id: _artistProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.browseLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.artistPage = d;
                } catch (e) { root.error = "artist parse error"; }
            }
        }
    }

    // ---- album ----
    function loadAlbum(browseId): void {
        if (!browseId || !root.available) return;
        root.error = "";
        root.browseLoading = true;
        _albumProc.exec([root._runner, "album", browseId]);
    }
    Process {
        id: _albumProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.browseLoading = false;
                try {
                    const d = JSON.parse(this.text);
                    if (d.error) { root.error = d.error; return; }
                    root.albumPage = d;
                } catch (e) { root.error = "album parse error"; }
            }
        }
    }

    // ---- lyrics ----
    function loadLyrics(videoId, title, artist, duration): void {
        if (!videoId || !root.available) return;
        root.lyrics = ({});   // drop the previous song's lyrics immediately, even if the new fetch fails
        _lyricsProc.exec([root._runner, "lyrics", videoId,
                          title || "", artist || "", String(Math.round(duration || 0))]);
    }
    Process {
        id: _lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text);
                    if (!d.error) root.lyrics = d;
                } catch (e) {}
            }
        }
    }
}
