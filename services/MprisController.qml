pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs
import qs.modules.common
import qs.modules.common.functions

Singleton {
	id: root;
	
	// Raw filtered players - updated imperatively to avoid constant re-evaluation
	property list<MprisPlayer> players: []
	// Display players with YtMusic duplicate filtering - USE THIS IN UI WIDGETS.
	// Kept imperative as well: metadata changes can re-evaluate duplicate
	// filtering without changing player identity, and a fresh array here makes
	// Repeater-based popups destroy/recreate delegates mid-track transition.
	property list<MprisPlayer> displayPlayers: []
	
	// Debounce timer for _rebuildPlayerList to coalesce rapid signal bursts
	Timer {
		id: _rebuildDebounce
		interval: 50
		repeat: false
		onTriggered: root._doRebuildPlayerList(false)
	}

	Timer {
		id: _emptyListGraceTimer
		interval: 1800
		repeat: false
		onTriggered: root._doRebuildPlayerList(true)
	}

	// Schedule a debounced rebuild
	function _rebuildPlayerList(): void {
		_rebuildDebounce.restart();
	}

	// Actual rebuild logic (called by debounce timer)
	function _doRebuildPlayerList(forceEmpty: bool): void {
		let newList = [];
		for (const player of Mpris.players.values) {
			if (isRealPlayer(player)) {
				newList.push(player);
			}
		}
		const allowEmpty = forceEmpty === true;
		if (!allowEmpty && newList.length === 0 && (displayPlayers?.length ?? 0) > 0) {
			_emptyListGraceTimer.restart();
			return;
		}
		if (newList.length > 0)
			_emptyListGraceTimer.stop();
		// Only reassign on real membership/order changes: a fresh array with the
		// same players cascades into displayPlayers and makes every Repeater-based
		// player UI destroy and recreate its delegates (visible flash on track
		// change, since title changes schedule rebuilds).
		if (!_samePlayerOrder(newList, players)) players = newList;

		const nextDisplayPlayers = _filterYtMusicDuplicates(newList);
		if (!_samePlayerOrder(nextDisplayPlayers, displayPlayers)) displayPlayers = nextDisplayPlayers;

		// Keep trackedPlayer consistent with filtered list
		if (trackedPlayer && !players.includes(trackedPlayer)) {
			_manualPlayerSelection = false;
			trackedPlayer = players[0] ?? null;
		}
	}

	function _samePlayerOrder(a, b): bool {
		if ((a?.length ?? 0) !== (b?.length ?? 0)) return false;
		for (let i = 0; i < a.length; i++) {
			if (a[i] !== b[i]) return false;
		}
		return true;
	}
	
	property MprisPlayer trackedPlayer: null;
	property bool _manualPlayerSelection: false;
	property var _streamMetadataById: ({})

	Timer {
		id: _streamMetadataRefresh
		interval: 120
		repeat: false
		onTriggered: {
			if (!_streamMetadataProc.running)
				_streamMetadataProc.running = true
		}
	}

	Process {
		id: _streamMetadataProc
		command: ["pw-dump"]
		stdout: StdioCollector { id: _streamMetadataCollector }
		onExited: (exitCode, _exitStatus) => {
			if (exitCode !== 0) return
			try {
				const data = JSON.parse(_streamMetadataCollector.text ?? "[]")
				const next = {}
				for (const item of data) {
					if (item?.type !== "PipeWire:Interface:Node") continue
					const props = item?.info?.props ?? {}
					if (props["media.class"] !== "Stream/Output/Audio") continue
					const id = Number(item?.id ?? 0)
					if (!Number.isFinite(id) || id <= 0) continue
					next[id] = {
						appName: props["application.name"] ?? "",
						appId: props["application.id"] ?? "",
						binary: props["application.process.binary"] ?? "",
						nodeName: props["node.name"] ?? "",
						mediaName: props["media.name"] ?? "",
						state: item?.info?.state ?? ""
					}
				}
				root._streamMetadataById = next
			} catch (e) {
				console.warn("[MprisController] Failed to parse PipeWire stream metadata:", e)
			}
		}
	}

	Connections {
		target: Audio
		function onOutputAppNodesChanged(): void { _streamMetadataRefresh.restart() }
	}
	
	// Reactive counter that forces re-evaluation when any player's state changes
	property int _playbackStateVersion: 0
	
	// Grace period tracking - keeps players visible during track transitions
	property var _playerGrace: ({})  // dbusName -> timestamp
	
	// Prioritize manual selection, then playing players over paused ones
	// Uses _playbackStateVersion to force activePlayer re-evaluation on state changes
	property MprisPlayer activePlayer: {
		// Touch version to create dependency
		const _ = _playbackStateVersion;
		const visiblePlayers = displayPlayers ?? [];
		// Only consider tracked if it survived display filtering
		const trackedVisible = visiblePlayers.includes(trackedPlayer) ? trackedPlayer : null;
		if (_manualPlayerSelection && trackedVisible) return trackedVisible;
		// Prefer the same deduped/art-capable player set used by popup surfaces
		for (let i = 0; i < visiblePlayers.length; i++) {
			if (visiblePlayers[i]?.isPlaying) return visiblePlayers[i];
		}
		if (trackedVisible) return trackedVisible;
		if (visiblePlayers.length > 0) return visiblePlayers[0];

		// Raw fallback only for transient gaps while filtered players rebuild
		const trackedRaw = players.includes(trackedPlayer) ? trackedPlayer : null;
		if (_manualPlayerSelection && trackedRaw) return trackedRaw;
		for (let i = 0; i < players.length; i++) {
			if (players[i]?.isPlaying) return players[i];
		}
		if (trackedRaw) return trackedRaw;
		return players[0] ?? null;
	}

	readonly property bool isYtMusicActive: {
		if (!(Config.options?.sidebar?.ytmusic?.enable ?? false)) return false;
		if (activePlayer) return _isYtMusicMpv(activePlayer);
		// Fallback only during transient gaps where activePlayer is momentarily null
		// while YtMusic is still playing/initializing.
		if (!YtMusic.currentVideoId) return false;
		return !!YtMusic.mpvPlayer || !!YtMusic.isPlaying;
	}
	
	property bool hasPlasmaIntegration: false
	property bool hasWtype: false
	Process {
		id: plasmaIntegrationCheckProc
		running: false
		command: ["/usr/bin/bash", "-c", "command -v plasma-browser-integration-host >/dev/null; plasma=$?; command -v wtype >/dev/null; wtype=$?; exit $((plasma + wtype * 10))"]
		onExited: (exitCode) => {
			root.hasPlasmaIntegration = (exitCode % 10) === 0;
			root.hasWtype = Math.floor(exitCode / 10) === 0;
		}
	}

	Timer {
		id: plasmaCheckDefer
		interval: 1200
		repeat: false
		onTriggered: plasmaIntegrationCheckProc.running = true
	}

	Component.onCompleted: {
		_streamMetadataRefresh.start()
		plasmaCheckDefer.start()
	}

	Connections {
		target: Config
		function onReadyChanged() {
			if (Config.ready) plasmaCheckDefer.start()
		}
	}
	
	// Check if player is in grace period (recently had valid metadata)
	function _isInGracePeriod(player): bool {
		const name = player?.dbusName ?? "";
		if (!name) return false;
		const graceTime = _playerGrace[name];
		if (!graceTime) return false;
		return (Date.now() - graceTime) < 2000; // 2 second grace period
	}
	
	// Update grace period for a player with valid metadata
	function _updateGrace(player): void {
		const name = player?.dbusName ?? "";
		if (!name) return;
		if (player.trackTitle || player.isPlaying) {
			let nextGrace = Object.assign({}, _playerGrace);
			nextGrace[name] = Date.now();
			_playerGrace = nextGrace;
		}
	}
	
	// Cache for mpv instance check to avoid repeated iteration
	property var _mpvInstanceCache: ({ hasMpvInstance: false, hasMpvBase: false })
	
	Connections {
		target: Config
		function onConfigChanged() {
			root._updateMpvCache();
			root._rebuildPlayerList();
		}
	}
	
	onHasPlasmaIntegrationChanged: {
		root._updateMpvCache();
		root._rebuildPlayerList();
	}
	
	Connections {
		target: YtMusic
		function onMpvPlayerChanged() {
			root._updateMpvCache();
			root._rebuildPlayerList();
		}
		function onCurrentVideoIdChanged() {
			root._rebuildPlayerList();
		}
		function onCurrentTitleChanged() {
			root._rebuildPlayerList();
		}
	}
	
	function _updateMpvCache(): void {
		let hasMpvInstance = false;
		let hasMpvBase = false;
		for (const p of Mpris.players.values) {
			const name = p?.dbusName ?? "";
			if (name.startsWith("org.mpris.MediaPlayer2.mpv.instance")) hasMpvInstance = true;
			if (name === "org.mpris.MediaPlayer2.mpv") hasMpvBase = true;
		}
		_mpvInstanceCache = { hasMpvInstance, hasMpvBase };
	}

	// Check if a URL belongs to a known streaming/media site (not just YouTube)
	function _isStreamingSite(url): bool {
		if (!url) return false;
		const u = url.toLowerCase();
		// Video platforms
		if (u.includes("youtube.com") || u.includes("youtu.be")) return true;
		if (u.includes("music.youtube.com")) return true;
		if (u.includes("twitch.tv")) return true;
		if (u.includes("vimeo.com")) return true;
		if (u.includes("dailymotion.com")) return true;
		if (u.includes("crunchyroll.com")) return true;
		if (u.includes("netflix.com")) return true;
		if (u.includes("disneyplus.com")) return true;
		if (u.includes("hbomax.com") || u.includes("max.com")) return true;
		if (u.includes("primevideo.com") || u.includes("amazon.com/gp/video")) return true;
		if (u.includes("hulu.com")) return true;
		if (u.includes("peacocktv.com")) return true;
		if (u.includes("bilibili.com")) return true;
		if (u.includes("niconico.jp") || u.includes("nicovideo.jp")) return true;
		// Audio/music platforms
		if (u.includes("soundcloud.com")) return true;
		if (u.includes("bandcamp.com")) return true;
		if (u.includes("deezer.com")) return true;
		if (u.includes("tidal.com")) return true;
		if (u.includes("music.apple.com")) return true;
		if (u.includes("pandora.com")) return true;
		if (u.includes("mixcloud.com")) return true;
		// Podcasts
		if (u.includes("podcasts.google.com")) return true;
		if (u.includes("open.spotify.com")) return true;
		if (u.includes("podcasts.apple.com")) return true;
		return false;
	}

	function _isYoutubeUrl(url): bool {
		const value = (url ?? "").toString().toLowerCase();
		return value.includes("youtube.com") || value.includes("youtu.be");
	}

	function _extractYoutubeVideoId(url): string {
		const value = (url ?? "").toString();
		if (!value) return "";
		let match = value.match(/[?&]v=([A-Za-z0-9_-]{11})/);
		if (match?.[1]) return match[1];
		match = value.match(/youtu\.be\/([A-Za-z0-9_-]{11})/);
		if (match?.[1]) return match[1];
		match = value.match(/youtube\.com\/(?:shorts|live)\/([A-Za-z0-9_-]{11})/);
		return match?.[1] ?? "";
	}

	function isRealPlayer(player) {
		if (!Config.options?.media?.filterDuplicatePlayers) return true;
		const name = player?.dbusName ?? "";
		if (!name) return false;
		
		const ytMusicEnabled = Config.options?.sidebar?.ytmusic?.enable ?? false;
		if (!ytMusicEnabled && _isYtMusicMpvRaw(player)) return false;

		// Explicitly drop X/Twitter media noise early (url/title/album)
		const rawUrl = player?.metadata?.["xesam:url"] ?? "";
		const lowerUrl = rawUrl.toLowerCase();
		const lowerTitle = (player?.trackTitle ?? "").toLowerCase();
		const lowerAlbum = (player?.trackAlbum ?? "").toLowerCase();
		// YouTube hover previews inherit the browser MPRIS service, but their
		// page URL has no playable video id. Reject them before the streaming
		// branches below can accept isPlaying/length as sufficient evidence.
		if (root._isBrowserPlayer(player) && root._isYoutubeUrl(rawUrl)
				&& root._extractYoutubeVideoId(rawUrl).length === 0) {
			return false;
		}
		if (lowerUrl.includes("x.com") || lowerUrl.includes("twitter.com") ||
			lowerTitle.includes("x.com") || lowerTitle.includes("twitter.com") ||
			lowerAlbum.includes("x.com") || lowerAlbum.includes("twitter.com")) {
			return false;
		}
		// Additional heuristic: browser titles like "... on X: ..." or "... / X" (no url present)
		const isBrowserPlayerName = name.includes("firefox") || name.includes("chrome") || name.includes("chromium") ||
			name.includes("brave") || name.includes("vivaldi") || name.includes("opera");
		if (isBrowserPlayerName) {
			if (lowerTitle.includes(" on x:") || lowerTitle.includes(" / x")) {
				return false;
			}
		}
		
		// mpv handling - prefer YtMusic.mpvPlayer when available
		if (name === "org.mpris.MediaPlayer2.mpv" || name.startsWith("org.mpris.MediaPlayer2.mpv.instance")) {
			if (YtMusic.mpvPlayer) return player === YtMusic.mpvPlayer;
			// Use cached values instead of iterating
			if (name === "org.mpris.MediaPlayer2.mpv" && _mpvInstanceCache.hasMpvInstance) return false;
			// Drop ghost mpv.instance entries when base mpv exists
			if (name.startsWith("org.mpris.MediaPlayer2.mpv.instance")) {
				const hasAnyMeta = !!(player.trackTitle || player.trackArtist || (player.metadata?.["xesam:url"] ?? ""));
				if (_mpvInstanceCache.hasMpvBase && !player.isPlaying && !hasAnyMeta) return false;
			}
		}
		
		// Filter playerctld proxy
		if (name.startsWith('org.mpris.MediaPlayer2.playerctld')) return false;
		
		// Handle plasma-browser-integration (KDE Plasma)
		// Accept browsers playing real media content (YouTube, streaming sites, long-form audio/video)
		if (hasPlasmaIntegration) {
			const isBrowser = name.startsWith('org.mpris.MediaPlayer2.firefox') ||
				name.startsWith('org.mpris.MediaPlayer2.chromium') ||
				name.startsWith('org.mpris.MediaPlayer2.chrome');
			if (isBrowser) {
				const trackUrl = player.metadata?.["xesam:url"] ?? "";
				const hasProgress = (player.position ?? 0) > 0 || (player.length ?? 0) > 0;
				if (!player.isPlaying && !hasProgress) return false;
				// Accept known streaming sites
				if (_isStreamingSite(trackUrl)) return true;
				// Accept any browser media with sufficient length (> 30s = real content)
				if ((player.length ?? 0) >= 30) return true;
				// Accept if actively playing — live streams/TV (Twitch, etc.) never
				// report position/length, so isPlaying alone is the reliable signal.
				// The guard above already dropped the true noise case (not playing
				// and no progress), so this can't let hover-preview junk through.
				if (player.isPlaying) return true;
				// Otherwise filter (likely noise)
				return false;
			}
		}
		// plasma-browser-integration publishes its own name
		if (name === 'org.mpris.MediaPlayer2.plasma-browser-integration') {
			const trackUrl = player.metadata?.["xesam:url"] ?? "";
			const hasProgress = (player.position ?? 0) > 0 || (player.length ?? 0) > 0;
			if (!player.isPlaying && !hasProgress) return false;

			// KDE can leave a generic paused bridge (for example "(1) YouTube")
			// beside Chromium's real, actively playing MPRIS object. Keeping both
			// creates a duplicate media card and an extra effects tree. Drop only
			// that generic bridge while another browser player is actually playing.
			const genericTitle = root._normTitle(player.trackTitle)
				.replace(/^\(\d+\)\s*/, "")
			const genericBridge = genericTitle === "youtube"
				|| genericTitle === "chromium"
				|| genericTitle === "google chrome"
				|| genericTitle === "firefox"
			if (!player.isPlaying && genericBridge && root._hasOtherPlayingBrowserPlayer(player))
				return false;

			// During a YouTube thumbnail preview Plasma can publish the preview
			// title while retaining the current video's URL and clearing its art.
			// The native browser provider still carries the coherent title for that
			// same URL, so prefer it until Plasma finishes the metadata handoff.
			if (!(player.trackArtUrl ?? "").length
					&& root._hasConflictingBrowserPeer(player))
				return false;

			if (_isStreamingSite(trackUrl)) return true;
			if ((player.length ?? 0) >= 30) return true;
			// Live streams/TV never report position/length — isPlaying is enough
			// once the noise guard above has already run.
			if (player.isPlaying) return true;
			return false;
		}
		
		// Filter duplicate MPD instances
		if (name.endsWith('.mpd') && !name.endsWith('MediaPlayer2.mpd')) return false;
		
		// Track transition handling - keep player visible during metadata changes
		const isPlaying = player.playbackState === MprisPlaybackState.Playing;
		const hasTitle = player.trackTitle && player.trackTitle.length > 0;
		
		if (!hasTitle) {
			// Keep if playing (track loading)
			if (isPlaying) {
				_updateGrace(player);
				return true;
			}
			// Keep if in grace period (recently had valid metadata)
			if (_isInGracePeriod(player)) return true;
			// Otherwise filter out
			return false;
		}
		
		// Update grace period for valid players
		_updateGrace(player);
		
		// Enhanced GIF/short media detection
		const trackUrl = player.metadata?.["xesam:url"] ?? "";
		const mimeType = player.metadata?.["xesam:mimeType"] ?? "";
		const trackLength = player.length ?? 0;
		
		// Filter very short media (< 5 seconds) - likely GIFs or ads
		if (trackLength > 0 && trackLength < 5) return false;
		// Block explicit image/gif mime types even if length unknown
		const mimeLower = mimeType.toLowerCase();
		if (mimeLower.includes("image/gif") || mimeLower.includes("image/webp")) return false;
		
		// Filter known GIF/image hosting patterns
		if (trackUrl) {
			const urlLower = trackUrl.toLowerCase();
			// Explicit extensions
			if (urlLower.match(/\.(gif|gifv|webp)(\?|#|$)/)) return false;
			// Common GIF/image hosts
			if (urlLower.includes("giphy.com")) return false;
			if (urlLower.includes("x.com")) return false;
			if (urlLower.includes("tenor.com")) return false;
			if (urlLower.includes("imgur.com") && (urlLower.endsWith(".gif") || urlLower.endsWith(".gifv"))) return false;
			if (urlLower.includes("gfycat.com")) return false;
			if (urlLower.includes("redgifs.com")) return false;
			// Twitter/X embedded media (often auto-playing videos)
			if (urlLower.includes("video.twimg.com") && trackLength < 30) return false;
			if (urlLower.includes("pbs.twimg.com")) return false;
		}
		
		// Filter browser players with very short content (likely embedded videos/GIFs)
		const isBrowserPlayer = name.includes("firefox") || name.includes("chrome") || name.includes("chromium") || 
		                        name.includes("brave") || name.includes("vivaldi") || name.includes("opera");
		if (isBrowserPlayer && trackLength > 0 && trackLength < 15 && !trackUrl.includes("youtube.com") && !trackUrl.includes("youtu.be")) {
			return false;
		}
		// Ignore YouTube hover cards with zero progress (no playback yet)
		if (isBrowserPlayer && root._isYoutubeUrl(trackUrl)) {
			if (root._extractYoutubeVideoId(trackUrl).length === 0) return false;
			if (!player.isPlaying) {
				const hasProgress = (player.position ?? 0) > 0 || (player.length ?? 0) > 0;
				if (!hasProgress) return false;
			}
		}
		
		return true;
	}
	
	signal trackChanged(reverse: bool);

	property bool __reverse: false;

	property var activeTrack;

	function _isYtMusicMpvRaw(player): bool {
		if (!player) return false;
		if (YtMusic.mpvPlayer && player === YtMusic.mpvPlayer) return true;
		const id = (player.identity ?? "").toLowerCase();
		const entry = (player.desktopEntry ?? "").toLowerCase();
		const isMpv = (id === "mpv" || id.includes("mpv") || entry === "mpv" || entry.includes("mpv"));
		if (!isMpv) return false;
		const trackUrl = player.metadata?.["xesam:url"] ?? "";
		if (trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be")) return true;
		// Fallback: match by title when YtMusic is active
		if (YtMusic.currentVideoId || YtMusic.currentTitle) {
			const ytTitle = _normTitle(YtMusic.currentTitle);
			const pTitle = _normTitle(player.trackTitle);
			if (ytTitle && pTitle && (pTitle.includes(ytTitle) || ytTitle.includes(pTitle))) return true;
		}
		return false;
	}

	function _isYtMusicMpv(player): bool {
		if (!(Config.options?.sidebar?.ytmusic?.enable ?? false)) return false;
		return _isYtMusicMpvRaw(player);
	}
	
	function _normTitle(s): string {
		return (s ?? "").toLowerCase().replace(/[\t\r\n|•·]+/g, " ").replace(/\s+/g, " ").trim();
	}

	function _isBrowserPlayer(player): bool {
		if (!player) return false;
		const name = (player.dbusName ?? "").toLowerCase();
		const identity = (player.identity ?? "").toLowerCase();
		const entry = (player.desktopEntry ?? "").toLowerCase();
		return name.includes("plasma-browser-integration") || name.includes("firefox") ||
			name.includes("chrome") || name.includes("chromium") || name.includes("brave") ||
			name.includes("vivaldi") || name.includes("opera") || identity.includes("firefox") ||
			identity.includes("zen") || entry.includes("zen") || entry.includes("firefox");
	}

	function _hasOtherPlayingBrowserPlayer(excludedPlayer): bool {
		for (const candidate of Mpris.players.values) {
			if (candidate !== excludedPlayer && candidate?.isPlaying && root._isBrowserPlayer(candidate))
				return true;
		}
		return false;
	}

	function _hasConflictingBrowserPeer(player): bool {
		const url = (player?.metadata?.["xesam:url"] ?? "").toString();
		const title = root._normTitle(player?.trackTitle)
			.replace(/\s+-\s+youtube$/, "");
		if (!url.length || !title.length) return false;

		for (const candidate of Mpris.players.values) {
			if (candidate === player || !root._isBrowserPlayer(candidate)) continue;
			const candidateUrl = (candidate?.metadata?.["xesam:url"] ?? "").toString();
			if (candidateUrl !== url) continue;
			const candidateTitle = root._normTitle(candidate?.trackTitle)
				.replace(/\s+-\s+youtube$/, "");
			if (candidateTitle.length > 0 && !title.includes(candidateTitle)
					&& !candidateTitle.includes(title))
				return true;
		}
		return false;
	}

	function _isBrowserYoutubePlayer(player): bool {
		if (!player) return false;
		const url = (player.metadata?.["xesam:url"] ?? "").toLowerCase();
		const title = (player.trackTitle ?? "").toLowerCase();
		return root._isBrowserPlayer(player)
			&& (url.includes("youtube.com") || url.includes("youtu.be") || title.includes("youtube"));
	}

	function _matchingBrowserWindow(player) {
		if (!CompositorService.isNiri || !player)
			return null;

		const playerTitle = root._normTitle(player.trackTitle).replace(/\s+-\s+youtube$/, "");
		const wins = NiriService.windows ?? [];
		let bestWindow = null;
		let bestScore = 0;
		for (let i = 0; i < wins.length; i++) {
			const win = wins[i];
			const appId = (win.app_id ?? "").toLowerCase();
			const winTitle = root._normTitle(win.title);
			let score = 0;
			if (appId.includes("zen") || appId.includes("firefox") || appId.includes("brave") ||
				appId.includes("chrome") || appId.includes("chromium") || appId.includes("vivaldi") ||
				appId.includes("opera") || appId.includes("librewolf") || appId.includes("floorp") ||
				appId.includes("waterfox"))
				score += 2;
			if (playerTitle.length > 0 && winTitle.length > 0 && (winTitle.includes(playerTitle) || playerTitle.includes(winTitle)))
				score += 5;
			if (winTitle.includes("youtube"))
				score += 2;
			if (win.is_focused)
				score += 1;
			if (score > bestScore) {
				bestScore = score;
				bestWindow = win;
			}
		}
		return bestScore >= 5 ? bestWindow : null;
	}

	function _canUseBrowserNavigationFallback(player): bool {
		return root.hasWtype && !GlobalStates.screenLocked && CompositorService.isNiri && root._isBrowserYoutubePlayer(player) && root._matchingBrowserWindow(player) !== null;
	}

	function _navigateBrowserYoutube(player, direction: string): void {
		const win = root._matchingBrowserWindow(player);
		if (!win)
			return;

		const restoreWindow = NiriService.activeWindow;
		const restoreId = restoreWindow && restoreWindow.id !== win.id ? String(restoreWindow.id) : "";
		const key = direction === "previous" ? "p" : "n";
		Quickshell.execDetached(["/usr/bin/bash", "-c", `
			target="$1"
			restore="$2"
			key="$3"
			command -v niri >/dev/null 2>&1 || exit 0
			command -v wtype >/dev/null 2>&1 || exit 0
			niri msg action focus-window --id "$target" >/dev/null 2>&1 || exit 0
			sleep 0.08
			wtype -M shift -k "$key" >/dev/null 2>&1 || true
			sleep 0.05
			if [ -n "$restore" ] && [ "$restore" != "$target" ]; then
				niri msg action focus-window --id "$restore" >/dev/null 2>&1 || true
			fi
		`, "_", String(win.id), restoreId, key]);
	}

	function canGoPreviousForPlayer(player): bool {
		if (_isYtMusicMpv(player) && YtMusic.currentVideoId)
			return YtMusic.canGoPrevious;
		return (player?.canGoPrevious ?? false) || root._canUseBrowserNavigationFallback(player);
	}

	function canGoNextForPlayer(player): bool {
		if (_isYtMusicMpv(player) && YtMusic.currentVideoId)
			return YtMusic.canGoNext;
		return (player?.canGoNext ?? false) || root._canUseBrowserNavigationFallback(player);
	}

	function _showUserMediaAction(action: string): void {
		if (Config.options?.osd?.mediaEnabled ?? true)
			GlobalStates.showMediaAction(action);
	}

	function previousForPlayer(player, showFeedback = true): bool {
		let accepted = false;
		if (_isYtMusicMpv(player) && YtMusic.currentVideoId && YtMusic.canGoPrevious) {
			YtMusic.playPrevious();
			accepted = true;
		} else if (player?.canGoPrevious ?? false) {
			player.previous();
			accepted = true;
		} else if (root._canUseBrowserNavigationFallback(player)) {
			root._navigateBrowserYoutube(player, "previous");
			accepted = true;
		}
		if (accepted && showFeedback)
			root._showUserMediaAction("previous");
		return accepted;
	}

	function nextForPlayer(player, showFeedback = true): bool {
		let accepted = false;
		if (_isYtMusicMpv(player) && YtMusic.currentVideoId && YtMusic.canGoNext) {
			YtMusic.playNext();
			accepted = true;
		} else if (player?.canGoNext ?? false) {
			player.next();
			accepted = true;
		} else if (root._canUseBrowserNavigationFallback(player)) {
			root._navigateBrowserYoutube(player, "next");
			accepted = true;
		}
		if (accepted && showFeedback)
			root._showUserMediaAction("next");
		return accepted;
	}
	
	// Check if player is related to YtMusic (for duplicate filtering)
	function _isYtMusicRelated(player): bool {
		if (!player) return false;
		if (!(Config.options?.sidebar?.ytmusic?.enable ?? false)) return false;
		if (_isYtMusicMpv(player)) return true;
		// Only consider browser YouTube players as YtMusic-related if titles match closely
		if (!YtMusic.currentVideoId && !YtMusic.currentTitle) return false;
		const trackUrl = player.metadata?.["xesam:url"] ?? "";
		const isYouTube = trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be");
		if (!isYouTube) return false;
		// Check if titles match (same video playing in browser and YtMusic)
		const ytTitle = _normTitle(YtMusic.currentTitle);
		const pTitle = _normTitle(player.trackTitle);
		if (!ytTitle || !pTitle) return false;
		// Consider related if titles are very similar (one contains the other)
		return pTitle.includes(ytTitle) || ytTitle.includes(pTitle);
	}
	
	// Filter YtMusic duplicates - keep only one YtMusic-related player
	function _filterYtMusicDuplicates(playerList) {
		if (!playerList || playerList.length === 0) return [];
		
		let nonYtMusic = [];
		let ytMusic = [];
		
		for (const p of playerList) {
			if (_isYtMusicRelated(p)) {
				ytMusic.push(p);
			} else {
				nonYtMusic.push(p);
			}
		}
		
		// If multiple YtMusic players, keep only the preferred one
		if (ytMusic.length > 1) {
			// Prefer YtMusic.mpvPlayer, then first playing, then first with art
			let chosen = ytMusic.find(p => YtMusic.mpvPlayer && p === YtMusic.mpvPlayer);
			if (!chosen) chosen = ytMusic.find(p => p.isPlaying);
			if (!chosen) chosen = ytMusic.find(p => p.trackArtUrl);
			if (!chosen) chosen = ytMusic[0];
			ytMusic = [chosen];
		}
		
		// Filter title/position duplicates from non-YtMusic players
		let filtered = [];
		let used = new Set();
		
		const allPlayers = [...ytMusic, ...nonYtMusic].filter(player => player);
		for (let i = 0; i < allPlayers.length; i++) {
			if (used.has(i)) continue;
			const p1 = allPlayers[i];
			if (!p1) continue;
			let group = [i];
			
			for (let j = i + 1; j < allPlayers.length; j++) {
				if (used.has(j)) continue;
				const p2 = allPlayers[j];
				if (!p2) continue;
				
				// Title similarity check
				const titleMatch = p1.trackTitle && p2.trackTitle &&
					(p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle));

				// Position/length similarity (same content, different players)
				const posMatch = p1.length > 0 && p2.length > 0 &&
					Math.abs(p1.position - p2.position) <= 3 &&
					Math.abs(p1.length - p2.length) <= 3;

				// Same source URL (e.g. a browser's native MPRIS player and
				// plasma-browser-integration both registering the same Twitch/
				// live-TV tab under different titles and no shared duration).
				const url1 = p1.metadata?.["xesam:url"] ?? "";
				const url2 = p2.metadata?.["xesam:url"] ?? "";
				const urlMatch = url1.length > 0 && url1 === url2;

				if (titleMatch || posMatch || urlMatch) {
					group.push(j);
				}
			}
			
			// Choose player with cover art, or first one
			let chosenIdx = group.find(idx => allPlayers[idx].trackArtUrl?.length > 0);
			if (chosenIdx === undefined) chosenIdx = group[0];
			filtered.push(allPlayers[chosenIdx]);
			group.forEach(idx => used.add(idx));
		}

		return filtered;
	}

	Instantiator {
		model: Mpris.players;

		Connections {
			required property MprisPlayer modelData;
			target: modelData;

			Component.onCompleted: {
				// Only track if it's a real player
				if (!root._manualPlayerSelection && isRealPlayer(modelData) && (root.trackedPlayer == null || modelData.isPlaying)) {
					root.trackedPlayer = modelData;
				}
				// Rebuild player list when new player is added
				root._updateMpvCache();
				root._rebuildPlayerList();
			}
			Component.onDestruction: {
				if (root.trackedPlayer === modelData) {
					root.trackedPlayer = null;
					root._manualPlayerSelection = false;
				}
				if (!root._manualPlayerSelection && (root.trackedPlayer == null || !root.trackedPlayer.isPlaying)) {
					for (const player of Mpris.players.values) {
						if (player.isPlaying) {
							root.trackedPlayer = player;
							break;
						}
					}
					if (root.trackedPlayer == null && Mpris.players.values.length != 0) {
						root.trackedPlayer = Mpris.players.values[0];
					}
				}
				// Rebuild player list when player is removed (deferred to avoid accessing destroyed object)
				Qt.callLater(() => {
					root._updateMpvCache();
					root._rebuildPlayerList();
				});
			}

			function onPlaybackStateChanged() {
				// Increment version to force activePlayer re-evaluation
				root._playbackStateVersion++;
				_streamMetadataRefresh.restart();
				// Update tracked player if this one started playing
				if (!root._manualPlayerSelection && modelData.isPlaying && root.trackedPlayer !== modelData && isRealPlayer(modelData)) {
					root.trackedPlayer = modelData;
				}
				// Rebuild on playback state change (affects filtering)
				root._rebuildPlayerList();
			}
			
			// Rebuild when track title changes (affects isRealPlayer filter)
			function onTrackTitleChanged() {
				root._rebuildPlayerList();
			}

			function onTrackArtUrlChanged() {
				root._rebuildPlayerList();
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
			root.updateTrack();
		}

		function onTrackTitleChanged() {
			root.updateTrack();
			_streamMetadataRefresh.restart();
		}

		function onTrackArtistChanged() {
			root.updateTrack();
		}

		function onTrackAlbumChanged() {
			root.updateTrack();
		}

		function onTrackArtUrlChanged() {
			if ((root.activePlayer?.uniqueId ?? 0) === (root.activeTrack?.uniqueId ?? 0)
				&& (root.activePlayer?.trackArtUrl ?? "") !== (root.activeTrack?.artUrl ?? "")) {
				const r = root.__reverse;
				root.updateTrack();
				root.__reverse = r;
			}
		}
	}

	onActivePlayerChanged: this.updateTrack();

	function updateTrack() {
		this.activeTrack = {
			uniqueId: this.activePlayer?.uniqueId ?? 0,
			artUrl: this.activePlayer?.trackArtUrl ?? "",
			title: this.activePlayer?.trackTitle || Translation.tr("Unknown Title"),
			artist: this.activePlayer?.trackArtist || Translation.tr("Unknown Artist"),
			album: this.activePlayer?.trackAlbum || Translation.tr("Unknown Album"),
		};

		this.trackChanged(__reverse);
		this.__reverse = false;
	}

	property bool isPlaying: this.activePlayer && this.activePlayer.isPlaying;
	property bool canTogglePlaying: this.activePlayer?.canTogglePlaying ?? false;
	function togglePlaying(): void {
		if (root.isYtMusicActive && YtMusic.currentVideoId) {
			YtMusic.togglePlaying();
		} else if (this.canTogglePlaying) {
			this.activePlayer.togglePlaying();
		}
	}

	property bool canGoPrevious: (root.isYtMusicActive && YtMusic.currentVideoId)
		? YtMusic.canGoPrevious
		: root.canGoPreviousForPlayer(this.activePlayer);
	function previous(): bool {
		let accepted = false;
		if (root.isYtMusicActive && YtMusic.currentVideoId && YtMusic.canGoPrevious) {
			this.__reverse = true;
			YtMusic.playPrevious();
			accepted = true;
		} else if (root.canGoPreviousForPlayer(this.activePlayer)) {
			this.__reverse = true;
			accepted = root.previousForPlayer(this.activePlayer, false);
		}
		if (accepted)
			root._showUserMediaAction("previous");
		return accepted;
	}

	property bool canGoNext: (root.isYtMusicActive && YtMusic.currentVideoId)
		? YtMusic.canGoNext
		: root.canGoNextForPlayer(this.activePlayer);
	function next(): bool {
		let accepted = false;
		if (root.isYtMusicActive && YtMusic.currentVideoId && YtMusic.canGoNext) {
			this.__reverse = false;
			YtMusic.playNext();
			accepted = true;
		} else if (root.canGoNextForPlayer(this.activePlayer)) {
			this.__reverse = false;
			accepted = root.nextForPlayer(this.activePlayer, false);
		}
		if (accepted)
			root._showUserMediaAction("next");
		return accepted;
	}

	function _volumeKey(value): string {
		return String(value ?? "").toLowerCase().replace(/[^a-z0-9]+/g, "");
	}

	function _volumeTokens(value): var {
		return String(value ?? "").toLowerCase().split(/[^a-z0-9]+/g)
			.filter(token => token.length >= 3);
	}

	// Returns {identity, total}. `identity` is the real name/title overlap
	// between player and PipeWire stream node; `total` adds a running/idle
	// state bonus used only as a tiebreaker among identity-matched candidates.
	// The state bonus MUST NOT contribute to the match threshold on its own:
	// otherwise every running stream matches the only running MPRIS player
	// (e.g. a browser tab) and the mixer labels every app with that player's
	// desktop entry name.
	function _streamMatchScore(player: MprisPlayer, node): var {
		if (!player || !node) return {identity: 0, total: 0};
		const props = node.properties ?? {};
		const meta = root._streamMetadataById[Number(node.id ?? 0)] ?? {};
		const mediaName = String(meta.mediaName ?? props["media.name"] ?? "");
		const title = String(player.trackTitle ?? "");
		const titleKey = root._volumeKey(title);
		const mediaKey = root._volumeKey(mediaName);
		let identity = 0;
		if (titleKey.length >= 4 && mediaKey.length >= 4) {
			if (titleKey === mediaKey) identity += 120;
			else if (titleKey.includes(mediaKey) || mediaKey.includes(titleKey)) identity += 80;
		}

		const playerValues = [
			player.identity,
			player.desktopEntry,
			String(player.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "")
		];
		const nodeValues = [
			meta.appName,
			meta.appId,
			meta.binary,
			meta.nodeName,
			node.name,
			node.description,
			node.nickname,
			props["application.name"],
			props["application.id"],
			props["application.process.binary"],
			props["node.name"]
		];
		for (const pv of playerValues) {
			const pk = root._volumeKey(pv);
			if (!pk) continue;
			const pt = root._volumeTokens(pv);
			let candidateScore = 0;
			for (const nv of nodeValues) {
				const nk = root._volumeKey(nv);
				if (!nk) continue;
				if (pk === nk) candidateScore = Math.max(candidateScore, 60);
				else if (pk.length >= 4 && nk.length >= 4 && (pk.includes(nk) || nk.includes(pk)))
					candidateScore = Math.max(candidateScore, 45);
				const nt = root._volumeTokens(nv);
				let overlap = 0;
				for (const token of pt) if (nt.includes(token)) overlap++;
				if (overlap > 0) candidateScore = Math.max(candidateScore, overlap * 12);
			}
			identity += candidateScore;
		}
		const stateBonus = meta.state === "running" ? 20 : (meta.state === "idle" ? -20 : 0);
		return {identity: identity, total: identity + stateBonus};
	}

	function _streamIsBound(node): bool {
		return !!(node && node.ready !== false && node.audio);
	}

	function streamNodeForPlayer(player: MprisPlayer): var {
		if (!player) return null;
		let best = null;
		let bestTotal = 0;
		for (const node of Audio.outputAppNodes ?? []) {
			if (!root._streamIsBound(node)) continue;
			const s = root._streamMatchScore(player, node);
			if (s.identity < 12) continue;
			if (best === null || s.total > bestTotal
					|| (s.total === bestTotal && root._streamIsMoreAudible(node, best))) {
				if (s.total > bestTotal) bestTotal = s.total;
				best = node;
			}
		}
		return best;
	}

	function _streamIsMoreAudible(candidate, current): bool {
		const cBound = root._streamIsBound(candidate);
		const curBound = root._streamIsBound(current);
		if (cBound !== curBound)
			return cBound;
		const cMeta = root._streamMetadataById[Number(candidate?.id ?? 0)] ?? {};
		const curMeta = root._streamMetadataById[Number(current?.id ?? 0)] ?? {};
		const cRunning = cMeta.state === "running";
		const curRunning = curMeta.state === "running";
		if (cRunning !== curRunning)
			return cRunning;
		const candidateVolume = Number(candidate?.audio?.volume ?? 0);
		const currentVolume = Number(current?.audio?.volume ?? 0);
		if (Math.abs(candidateVolume - currentVolume) > 0.01)
			return candidateVolume > currentVolume;
		return Boolean(current?.audio?.muted) && !Boolean(candidate?.audio?.muted);
	}

	function _streamAppKey(node): string {
		const props = node?.properties ?? {};
		const meta = root._streamMetadataById[Number(node?.id ?? 0)] ?? {};
		const key = root._volumeKey(meta.binary || props["application.process.binary"]
			|| meta.appId || props["application.id"]
			|| meta.appName || props["application.name"]
			|| node?.name || "");
		return key.length > 0 ? key : String(node?.id ?? "");
	}

	function streamIsActive(node): bool {
		if (!root._streamIsBound(node)) return false;
		const meta = root._streamMetadataById[Number(node?.id ?? 0)];
		return !meta || meta.state === "running";
	}

	readonly property var mixerAppNodes: {
		const nodes = (Audio.outputAppNodes ?? []).filter(node => root._streamIsBound(node));
		const byKey = ({});
		const order = [];
		for (const node of nodes) {
			const key = root._streamAppKey(node);
			if (!byKey[key]) {
				byKey[key] = node;
				order.push(key);
			} else if (root._streamIsMoreAudible(node, byKey[key])) {
				byKey[key] = node;
			}
		}
		return order.map(key => byKey[key]);
	}

	function playerForStreamNode(node): MprisPlayer {
		if (!node) return null;
		let best = null;
		let bestTotal = 0;
		for (const player of root.displayPlayers ?? []) {
			const s = root._streamMatchScore(player, node);
			if (s.identity >= 12 && (best === null || s.total > bestTotal)) {
				bestTotal = s.total;
				best = player;
			}
		}
		return best;
	}

	function _serviceNameFromUrl(value): string {
		const match = String(value ?? "").trim().match(/^[a-z][a-z0-9+.-]*:\/\/([^\/:?#]+)/i);
		if (!match?.[1]) return "";
		const labels = match[1].toLowerCase().replace(/^www\./, "").split(".").filter(Boolean);
		if (labels.length < 2) return "";
		let stem = labels[labels.length - 2];
		if (["co", "com", "net", "org"].includes(stem) && labels.length >= 3)
			stem = labels[labels.length - 3];
		return stem.split(/[-_]+/).filter(Boolean)
			.map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(" ");
	}

	function _cleanDisplayName(value): string {
		return String(value ?? "").replace(/\s+/g, " ").trim()
			.replace(/\s+\((?:v?\d)[^)]*\)\s*$/i, "");
	}

	function _genericBrowserName(value): bool {
		const key = root._volumeKey(value);
		return ["chromium", "googlechrome", "chrome", "firefox", "zen", "brave", "vivaldi", "opera", "librewolf", "floorp", "waterfox"].includes(key);
	}

	function _desktopEntryForHint(value): var {
		const hint = root._cleanDisplayName(value);
		if (!hint.length) return null;
		const direct = AppSearch.lookupDesktopEntry(hint);
		if (direct) return direct;
		const hintKey = root._volumeKey(hint);
		const hintTokens = root._volumeTokens(hint);
		let best = null;
		let bestScore = 0;
		for (const entry of DesktopEntries.applications.values ?? []) {
			if (!entry || entry.noDisplay) continue;
			const command = Array.from(entry.command ?? []);
			const values = [entry.id, entry.name, entry.genericName, entry.startupClass, command.length > 0 ? command[0] : ""];
			let score = 0;
			for (const candidate of values) {
				const candidateKey = root._volumeKey(candidate);
				if (!candidateKey) continue;
				if (candidateKey === hintKey) score = Math.max(score, 100);
				else if (hintKey.length >= 5 && candidateKey.length >= 5
						&& (hintKey.includes(candidateKey) || candidateKey.includes(hintKey)))
					score = Math.max(score, 60);
				const candidateTokens = root._volumeTokens(candidate);
				let overlap = 0;
				for (const token of hintTokens) {
					if (candidateTokens.includes(token)
							|| candidateTokens.some(other => token.length >= 4 && other.length >= 4
								&& (token.includes(other) || other.includes(token))))
						overlap++;
				}
				score = Math.max(score, overlap * 18);
			}
			if (score > bestScore) {
				bestScore = score;
				best = entry;
			}
		}
		return bestScore >= 36 ? best : null;
	}

	function playerDisplayName(player): string {
		if (!player) return "";
		if (root._isBrowserPlayer(player)) {
			const service = root._serviceNameFromUrl(player.metadata?.["xesam:url"] ?? "");
			if (service.length > 0) return service;
		}
		const entryId = String(player.desktopEntry ?? "").trim();
		const entry = entryId.length > 0 ? root._desktopEntryForHint(entryId) : null;
		if (entry?.name) return root._cleanDisplayName(entry.name);
		const identity = root._cleanDisplayName(player.identity);
		if (identity.length > 0) {
			const identityEntry = root._desktopEntryForHint(identity);
			if (identityEntry?.name) return root._cleanDisplayName(identityEntry.name);
			return identity;
		}
		const tail = String(player.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "").split(".").pop() ?? "";
		return tail.length > 0 ? tail.charAt(0).toUpperCase() + tail.slice(1) : "";
	}

	function streamDesktopEntry(node): var {
		if (!node) return null;
		const props = node.properties ?? {};
		const binary = root._cleanDisplayName(props["application.process.binary"]);
		if (binary.length > 0 && !root._genericBrowserName(binary)) {
			const binaryEntry = root._desktopEntryForHint(binary);
			if (binaryEntry) return binaryEntry;
		}
		const player = root.playerForStreamNode(node);
		if (player) {
			const playerHints = [player.desktopEntry, player.identity];
			for (const hint of playerHints) {
				const entry = root._desktopEntryForHint(hint);
				if (entry) return entry;
			}
		}
		const ids = [props["application.id"], binary, props["application.name"]];
		for (const id of ids) {
			const entry = root._desktopEntryForHint(id);
			if (entry) return entry;
		}
		return null;
	}

	function streamDisplayName(node): string {
		if (!node) return "";
		const entry = root.streamDesktopEntry(node);
		if (entry?.name) return root._cleanDisplayName(entry.name);
		const player = root.playerForStreamNode(node);
		if (player) {
			const playerName = root.playerDisplayName(player);
			if (playerName.length > 0 && !root._genericBrowserName(playerName)) return playerName;
		}
		const props = node.properties ?? {};
		return root._cleanDisplayName(props["application.name"] || node.description || node.name || Translation.tr("Unknown"));
	}

	function streamIconName(node): string {
		const entry = root.streamDesktopEntry(node);
		if (entry?.icon) return String(entry.icon);
		const props = node?.properties ?? {};
		const hints = [props["application.icon-name"], props["application.id"], props["application.process.binary"], props["node.name"]];
		for (const hint of hints) {
			const icon = AppSearch.guessIcon(String(hint ?? ""));
			if (AppSearch.iconExists(icon)) return icon;
		}
		return "application-x-executable";
	}

	function compactStreamDisplayName(node, maxChars: int): string {
		const value = root.streamDisplayName(node);
		const limit = Math.max(8, maxChars);
		return value.length > limit ? value.slice(0, limit - 1).replace(/\s+$/, "") + "…" : value;
	}

	readonly property var activePlayerStreamNode: root.streamNodeForPlayer(root.activePlayer)
	readonly property real volume: {
		if (root.isYtMusicActive && YtMusic.currentVideoId)
			return YtMusic.getVolume();
		const node = root.activePlayerStreamNode;
		if (root._streamIsBound(node)) {
			const nodeVolume = node.audio.volume;
			if (nodeVolume !== undefined && nodeVolume !== null)
				return Math.max(0, Math.min(1, nodeVolume));
		}
		if (root.activePlayer && root.activePlayer.volumeSupported && root.activePlayer.canControl)
			return Math.max(0, Math.min(1, root.activePlayer.volume));
		return 0;
	}
	readonly property bool canChangeVolume: (root.isYtMusicActive && YtMusic.currentVideoId)
		|| root._streamIsBound(root.activePlayerStreamNode)
		|| !!(root.activePlayer && root.activePlayer.volumeSupported && root.activePlayer.canControl);

	function getVolume(): real {
		return root.volume;
	}

	function setVolume(vol: real): void {
		const clamped = Math.max(0, Math.min(1, vol));
		if (root.isYtMusicActive && YtMusic.currentVideoId) {
			YtMusic.setVolume(clamped);
			return;
		}
		const node = root.activePlayerStreamNode;
		if (root._streamIsBound(node)) {
			node.audio.volume = clamped;
			const nodeId = Number(node.id ?? 0);
			if (Number.isFinite(nodeId) && nodeId > 0)
				Quickshell.execDetached(["wpctl", "set-volume", String(nodeId), String(clamped)]);
			return;
		}
		_streamMetadataRefresh.restart();
		if (root.activePlayer && root.activePlayer.volumeSupported && root.activePlayer.canControl)
			root.activePlayer.volume = clamped;
	}

	property bool loopSupported: this.activePlayer && this.activePlayer.loopSupported && this.activePlayer.canControl;
	property var loopState: this.activePlayer?.loopState ?? MprisLoopState.None;
	function setLoopState(loopState: var): void {
		if (this.loopSupported) {
			this.activePlayer.loopState = loopState;
		}
	}

	property bool shuffleSupported: this.activePlayer && this.activePlayer.shuffleSupported && this.activePlayer.canControl;
	property bool hasShuffle: this.activePlayer?.shuffle ?? false;
	function setShuffle(shuffle: bool): void {
		if (this.shuffleSupported) {
			this.activePlayer.shuffle = shuffle;
		}
	}

	function setActivePlayer(player: MprisPlayer): void {
		// Only allow players that survived filtering
		const filtered = (displayPlayers?.length ?? 0) > 0 ? displayPlayers : players;
		let targetPlayer = player;
		if (!targetPlayer || !filtered.includes(targetPlayer)) {
			targetPlayer = filtered[0] ?? null;
		}

		if (targetPlayer && this.activePlayer) {
			this.__reverse = filtered.indexOf(targetPlayer) < filtered.indexOf(this.activePlayer);
		} else {
			this.__reverse = false;
		}

		this.trackedPlayer = targetPlayer;
		this._manualPlayerSelection = targetPlayer !== null;
	}

	// Sanitize art URL to prevent invalid URLs from breaking image loading
	function sanitizeArtUrl(url): string {
		if (!url) return "";
		const urlStr = url.toString();
		// Filter out data URIs that are too large (can cause crashes)
		if (urlStr.startsWith("data:") && urlStr.length > 100000) return "";
		return urlStr;
	}

	// Streaming sites (Twitch, live TV, etc.) rarely publish mpris:artUrl —
	// fall back to the site's favicon, same fetch-and-cache service already
	// used for AI chat source chips (Favicon.qml).
	function faviconArtUrl(player): string {
		const trackUrl = player?.metadata?.["xesam:url"] ?? "";
		if (!trackUrl) return "";
		const domain = StringUtils.getDomain(trackUrl);
		if (!domain) return "";
		return `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
	}

	// Preferred art source for a player: real MPRIS art if present, else a
	// favicon fallback derived from the track's site URL.
	function effectiveArtUrl(player): string {
		const direct = player?.trackArtUrl ?? "";
		if (direct.length > 0) return direct;
		const videoId = root._extractYoutubeVideoId(
			player?.metadata?.["xesam:url"] ?? "");
		if (videoId.length > 0)
			return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
		return root.faviconArtUrl(player);
	}

	IpcHandler {
		target: "mpris"

		function pauseAll(): void {
			for (const player of Mpris.players.values) {
				if (player.canPause) player.pause();
			}
		}

		function playPause(): void {
			const wasPlaying = root.isPlaying
			if (root.isYtMusicActive && YtMusic.currentVideoId) {
				YtMusic.togglePlaying();
			} else {
				root.togglePlaying();
			}
			if (Config.options?.osd?.mediaEnabled ?? true) {
				GlobalStates.showMediaAction(wasPlaying ? "pause" : "play");
			}
		}
		function previous(): void {
			root.previous();
		}
		function next(): void {
			root.next();
		}
	}
}
