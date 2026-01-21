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
	
	property list<MprisPlayer> players: Mpris.players.values.filter(player => isRealPlayer(player));
	property MprisPlayer trackedPlayer: null;
	
	// Reactive counter that forces re-evaluation when any player's state changes
	property int _playbackStateVersion: 0
	
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
	
	function isRealPlayer(player) {
		if (!Config.options?.media?.filterDuplicatePlayers) return true;
		const name = player.dbusName ?? "";
		// Filter browser players when plasma-browser-integration is present
		if (hasPlasmaIntegration && name.startsWith('org.mpris.MediaPlayer2.firefox')) return false;
		if (hasPlasmaIntegration && name.startsWith('org.mpris.MediaPlayer2.chromium')) return false;
		if (hasPlasmaIntegration && name.startsWith('org.mpris.MediaPlayer2.chrome')) return false;
		// Filter playerctld (just a proxy)
		if (name.startsWith('org.mpris.MediaPlayer2.playerctld')) return false;
		// Filter plasma-browser-integration itself when we already have browser players
		if (name.includes('plasma-browser-integration')) return false;
		// Filter duplicate MPD instances
		if (name.endsWith('.mpd') && !name.endsWith('MediaPlayer2.mpd')) return false;
		// NOTE: Do NOT filter YtMusic's mpv player here!
		// It needs to be in the players list for MPRIS control to work.
		// Duplicate filtering happens in UI components (BarMediaPopup, etc.)
		// Filter media without title (likely GIFs or short videos)
		// But keep players that are actively playing (track may be changing)
		const isPlaying = player.playbackState === MprisPlaybackState.Playing;
		if (!player.trackTitle || player.trackTitle.length === 0) {
			// Keep if playing (track transition) or if it's a known media player
			if (!isPlaying) return false;
		}
		// Filter very short media (< 5 seconds) - likely GIFs
		if (player.length > 0 && player.length < 5) return false;
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
		if (id !== "mpv" && !id.includes("mpv") && entry !== "mpv" && !entry.includes("mpv")) return false;
		const trackUrl = player.metadata?.["xesam:url"] ?? "";
		return trackUrl.includes("youtube.com") || trackUrl.includes("youtu.be");
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
			}

			function onPlaybackStateChanged() {
				// Increment version to force activePlayer re-evaluation
				root._playbackStateVersion++;
				// Update tracked player if this one started playing
				if (modelData.isPlaying && root.trackedPlayer !== modelData) {
					root.trackedPlayer = modelData;
				}
			}
		}
	}

	Connections {
		target: activePlayer

		function onPostTrackChanged() {
			root.updateTrack();
		}

		function onTrackArtUrlChanged() {
			if (root.activePlayer.uniqueId == root.activeTrack.uniqueId && root.activePlayer.trackArtUrl != root.activeTrack.artUrl) {
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
		const targetPlayer = player ?? Mpris.players[0];
		console.log(`[Mpris] Active player ${targetPlayer} << ${activePlayer}`)

		if (targetPlayer && this.activePlayer) {
			this.__reverse = Mpris.players.indexOf(targetPlayer) < Mpris.players.indexOf(this.activePlayer);
		} else {
			this.__reverse = false;
		}

		this.trackedPlayer = targetPlayer;
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
