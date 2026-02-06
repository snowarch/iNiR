pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs
import qs.modules.common

Singleton {
	id: root;
	
	// Raw filtered players - updated imperatively to avoid constant re-evaluation
	property list<MprisPlayer> players: []
	
	// Rebuild player list - called only on structural changes
	function _rebuildPlayerList(): void {
		let newList = [];
		for (const player of Mpris.players.values) {
			if (isRealPlayer(player)) {
				newList.push(player);
			}
		}
		players = newList;
	}
	
	// Display players with YtMusic duplicate filtering - USE THIS IN UI WIDGETS
	readonly property var displayPlayers: _filterYtMusicDuplicates(players)
	
	property MprisPlayer trackedPlayer: null;
	
	// Reactive counter that forces re-evaluation when any player's state changes
	property int _playbackStateVersion: 0
	
	// Grace period tracking - keeps players visible during track transitions
	property var _playerGrace: ({})  // dbusName -> timestamp
	
	// Prioritize playing players over paused ones
	// Uses _playbackStateVersion to force re-evaluation on state changes
	property MprisPlayer activePlayer: {
		// Touch version to create dependency
		const _ = _playbackStateVersion;
		// If tracked player is actively playing, use it
		if (trackedPlayer?.isPlaying) return trackedPlayer;
		// Otherwise, find any player that IS playing (iterate to ensure reactivity)
		for (let i = 0; i < players.length; i++) {
			if (players[i]?.isPlaying) return players[i];
		}
		// Fallback to tracked or first player (even if paused)
		return trackedPlayer ?? players[0] ?? null;
	}

	readonly property bool isYtMusicActive: {
		if (YtMusic.currentVideoId) return true;
		if (YtMusic.mpvPlayer) return true;
		if (!activePlayer) return false;
		return _isYtMusicMpv(activePlayer);
	}
	
	property bool hasPlasmaIntegration: false
	Process {
		id: plasmaIntegrationCheckProc
		running: false
		command: ["/usr/bin/bash", "-c", "command -v plasma-browser-integration-host"]
		onExited: (exitCode) => { root.hasPlasmaIntegration = (exitCode === 0); }
	}

	Timer {
		id: plasmaCheckDefer
		interval: 1200
		repeat: false
		onTriggered: plasmaIntegrationCheckProc.running = true
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

	function isRealPlayer(player) {
		if (!Config.options?.media?.filterDuplicatePlayers) return true;
		const name = player?.dbusName ?? "";
		if (!name) return false;
		
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
		// Don't filter browsers playing YouTube/YT Music content
		if (hasPlasmaIntegration) {
			const isBrowser = name.startsWith('org.mpris.MediaPlayer2.firefox') ||
				name.startsWith('org.mpris.MediaPlayer2.chromium') ||
				name.startsWith('org.mpris.MediaPlayer2.chrome');
			if (isBrowser) {
				const trackUrl = player.metadata?.["xesam:url"] ?? "";
				const isYouTube = trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be") || trackUrl.includes("music.youtube.com");
				if (!isYouTube) return false;
			}
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
		const trackLength = player.length ?? 0;
		
		// Filter very short media (< 5 seconds) - likely GIFs or ads
		if (trackLength > 0 && trackLength < 5) return false;
		
		// Filter known GIF/image hosting patterns
		if (trackUrl) {
			const urlLower = trackUrl.toLowerCase();
			// Common GIF/image hosts
			if (urlLower.includes("giphy.com")) return false;
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
		
		return true;
	}
	
	signal trackChanged(reverse: bool);

	property bool __reverse: false;

	property var activeTrack;

	function _isYtMusicMpv(player): bool {
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
	
	function _normTitle(s): string {
		return (s ?? "").toLowerCase().replace(/[\t\r\n|•·]+/g, " ").replace(/\s+/g, " ").trim();
	}
	
	// Check if player is related to YtMusic (for duplicate filtering)
	function _isYtMusicRelated(player): bool {
		if (!player) return false;
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
		
		const allPlayers = [...ytMusic, ...nonYtMusic];
		for (let i = 0; i < allPlayers.length; i++) {
			if (used.has(i)) continue;
			const p1 = allPlayers[i];
			let group = [i];
			
			for (let j = i + 1; j < allPlayers.length; j++) {
				if (used.has(j)) continue;
				const p2 = allPlayers[j];
				
				// Title similarity check
				const titleMatch = p1.trackTitle && p2.trackTitle && 
					(p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle));
				
				// Position/length similarity (same content, different players)
				const posMatch = p1.length > 0 && p2.length > 0 &&
					Math.abs(p1.position - p2.position) <= 3 && 
					Math.abs(p1.length - p2.length) <= 3;
				
				if (titleMatch || posMatch) {
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
				if (root.trackedPlayer == null || modelData.isPlaying) {
					root.trackedPlayer = modelData;
				}
				// Rebuild player list when new player is added
				root._updateMpvCache();
				root._rebuildPlayerList();
			}
			Component.onDestruction: {
				if (root.trackedPlayer === modelData) {
					root.trackedPlayer = null;
				}
				if (root.trackedPlayer == null || !root.trackedPlayer.isPlaying) {
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
				// Update tracked player if this one started playing
				if (modelData.isPlaying && root.trackedPlayer !== modelData) {
					root.trackedPlayer = modelData;
				}
				// Rebuild on playback state change (affects filtering)
				root._rebuildPlayerList();
			}
			
			// Rebuild when track title changes (affects isRealPlayer filter)
			function onTrackTitleChanged() {
				root._rebuildPlayerList();
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
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

	property bool canGoPrevious: this.activePlayer?.canGoPrevious ?? false;
	function previous(): void {
		if (root.isYtMusicActive && YtMusic.currentVideoId) {
			this.__reverse = true;
			YtMusic.playPrevious();
		} else if (this.canGoPrevious) {
			this.__reverse = true;
			this.activePlayer.previous();
		}
	}

	property bool canGoNext: this.activePlayer?.canGoNext ?? false;
	function next(): void {
		if (root.isYtMusicActive && YtMusic.currentVideoId) {
			this.__reverse = false;
			YtMusic.playNext();
		} else if (this.canGoNext) {
			this.__reverse = false;
			this.activePlayer.next();
		}
	}

	property bool canChangeVolume: this.activePlayer && this.activePlayer.volumeSupported && this.activePlayer.canControl;

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
		const players = Mpris.players.values
		const targetPlayer = player ?? players[0] ?? null;

		if (targetPlayer && this.activePlayer) {
			this.__reverse = players.indexOf(targetPlayer) < players.indexOf(this.activePlayer);
		} else {
			this.__reverse = false;
		}

		this.trackedPlayer = targetPlayer;
	}

	// Sanitize art URL to prevent invalid URLs from breaking image loading
	function sanitizeArtUrl(url): string {
		if (!url) return "";
		const urlStr = url.toString();
		// Filter out data URIs that are too large (can cause crashes)
		if (urlStr.startsWith("data:") && urlStr.length > 100000) return "";
		return urlStr;
	}

	IpcHandler {
		target: "mpris"

		function pauseAll(): void {
			for (const player of Mpris.players.values) {
				if (player.canPause) player.pause();
			}
		}

		function playPause(): void {
			if (root.isYtMusicActive && YtMusic.currentVideoId) {
				YtMusic.togglePlaying();
			} else {
				root.togglePlaying();
			}
			GlobalStates.osdMediaAction = root.isPlaying ? "pause" : "play";
			GlobalStates.osdMediaOpen = true;
		}
		function previous(): void {
			root.previous();
			GlobalStates.osdMediaAction = "previous";
			GlobalStates.osdMediaOpen = true;
		}
		function next(): void {
			root.next();
			GlobalStates.osdMediaAction = "next";
			GlobalStates.osdMediaOpen = true;
		}
	}
}
