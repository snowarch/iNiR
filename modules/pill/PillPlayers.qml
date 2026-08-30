pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Adapter that presents iNiR's MprisController through the shape the ported pill
 * surfaces expect. The island's media card and bud were written against a player
 * facade with `has`/`title`/`artist`/`artUrl`/`pickable`, and MprisController
 * exposes the same facts under different names.
 *
 * This is a read-mostly view: selection writes straight back into
 * MprisController's tracked player, so the island and the rest of the shell never
 * disagree about which player is current. MprisController stays untouched
 * (singletons here are add-only).
 */
Singleton {
    id: root

    readonly property var list: MprisController.players ?? []

    /** Players worth offering in the picker: real ones carrying any metadata. */
    readonly property var pickable: root.list.filter(p => p && (p.trackTitle || p.trackArtist))

    readonly property var active: MprisController.activePlayer
    readonly property bool has: active !== null && active !== undefined
    readonly property bool playing: MprisController.isPlaying

    readonly property string title: has ? (active.trackTitle || root.labelOf(active)) : ""
    readonly property string artist: has ? PillTheme.joinArtists(active.trackArtists, active.trackArtist) : ""
    readonly property string artUrl: root.artUrlFor(active)

    readonly property real lengthSec: (has && active.length > 0) ? active.length : 0

    /** A stream has no meaningful length, or one absurdly long (radio, YouTube live). */
    readonly property bool live: has && (lengthSec <= 0 || lengthSec > 86400)

    readonly property string serviceLabel: has ? root.labelOf(active) : ""

    /** Semantic identity of the current track, shared by duplicate browser MPRIS providers. */
    readonly property string trackKey: root.identityFor(active)

    function select(p) {
        if (!p)
            return;
        MprisController._manualPlayerSelection = true;
        MprisController.trackedPlayer = p;
    }

    /**
     * A player started carrying a new track. The OSD listens so a track that
     * begins behind your music still gets its own flash.
     */
    signal announce(var player)

    property string _lastAnnouncedKey: ""

    onTrackKeyChanged: announceTimer.restart()

    Timer {
        id: announceTimer
        interval: 400
        onTriggered: {
            if (!root.has || root.trackKey.length === 0 || root.trackKey === root._lastAnnouncedKey)
                return;
            root._lastAnnouncedKey = root.trackKey;
            root.announce(root.active);
        }
    }

    function identityFor(p) {
        if (!p)
            return "";
        const url = String(p.metadata?.["xesam:url"] ?? "").trim().replace(/#.*$/, "");
        if (url.length > 0)
            return "url|" + url;
        const rawTitle = String(p.trackTitle ?? "").trim();
        if (rawTitle.length === 0)
            return "";
        const cleanTitle = root.refineTitle(p, rawTitle).toLowerCase().replace(/\s+/g, " ");
        const cleanArtist = PillTheme.joinArtists(p.trackArtists, p.trackArtist).toLowerCase().trim().replace(/\s+/g, " ");
        return "meta|" + cleanTitle + "|" + cleanArtist;
    }

    /**
     * Strip the noise players append to titles (" - YouTube", " | Spotify") so the
     * OSD and media card show the track, not the browser tab.
     */
    function refineTitle(p, fallback) {
        let t = String(fallback ?? "");
        t = t.replace(/\s*[-|–—]\s*(YouTube|YouTube Music|Spotify|SoundCloud|Twitch)\s*$/i, "");
        t = t.replace(/^\(\d+\)\s*/, "");
        return t.trim().length > 0 ? t.trim() : String(fallback ?? "");
    }

    /** Icon path for the player's own app, for the OSD's corner badge. */
    function appIconFor(p) {
        if (!p)
            return "";
        const names = [p.desktopEntry ?? "", String(p.identity ?? "").toLowerCase()];
        for (let i = 0; i < names.length; i++) {
            if (!names[i].length)
                continue;
            const path = Quickshell.iconPath(names[i], true);
            if (path.length)
                return path;
        }
        return "";
    }

    /** Stable per-track key, used to bust cached artwork URLs. */
    function keyFor(p) {
        if (!p)
            return "";
        return root.labelOf(p) + "|" + (p.trackTitle ?? "");
    }

    function labelOf(p) {
        if (!p)
            return "";
        return MprisController.playerDisplayName(p);
    }

    function artUrlFor(p) {
        return (p && p.trackArtUrl) ? String(p.trackArtUrl) : "";
    }

    function nowPlayingFor(p) {
        if (!p)
            return "";
        const t = p.trackTitle ?? "";
        const a = PillTheme.joinArtists(p.trackArtists, p.trackArtist);
        return a.length > 0 ? (t + " — " + a) : t;
    }
}
