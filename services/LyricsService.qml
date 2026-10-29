pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services
import "root:modules/common/functions/LyricsMath.js" as LyricsMath

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    // Who holds it, not how many: across a reload the old holder's release reached the new instance and dropped the
    // new holder's claim (ResourceUsage froze every reading that way).
    property var _holders: []
    property int _anonymousHolders: 0
    readonly property int subscribers: root._holders.length + root._anonymousHolders
    readonly property bool active: root.subscribers > 0

    property var lyricsLines: []
    property int activeIndex: -1
    property string status: "idle"

    readonly property int before: 3
    readonly property int after: 3
    readonly property int total: 7
    property var slots: ["", "", "", "", "", "", ""]

    property int _requestSerial: 0
    property string _latestRequestId: ""
    property string _latestTrackKey: ""
    property string _publishedTrackKey: ""
    property var _pendingRequest: null
    property string _runningRequestId: ""
    property string _runningTrackKey: ""

    function subscribe(holder: var): void {
        if (!holder)
            root._anonymousHolders++;
        else if (!root._holders.includes(holder))
            root._holders = root._holders.concat([holder]);
    }

    function unsubscribe(holder: var): void {
        if (!holder)
            root._anonymousHolders = Math.max(0, root._anonymousHolders - 1);
        else
            root._holders = root._holders.filter(other => other !== holder);
    }

    function buildSlots(idx: int): var {
        const result = [];
        for (let i = 0; i < root.total; i++) {
            const lineIdx = idx - root.before + i;
            if (lineIdx >= 0 && lineIdx < root.lyricsLines.length)
                result.push(root.lyricsLines[lineIdx].text || "♪");
            else
                result.push("");
        }
        return result;
    }

    function _clearPublished(): void {
        root.lyricsLines = [];
        root.activeIndex = -1;
        root.slots = ["", "", "", "", "", "", ""];
        root._publishedTrackKey = "";
        root._lastReported = -1;
        root._reanchor(0);
    }

    function _snapshot(): var {
        const player = root.activePlayer;
        const title = MprisController.titleOf(player) ?? "";
        const artist = MprisController.artistOf(player) ?? "";
        const album = player?.trackAlbum ?? "";
        const duration = MprisController.lengthOf(player);
        const key = JSON.stringify([
            player?.dbusName ?? "",
            player?.uniqueId ?? 0,
            title,
            artist,
            album,
            Math.floor(duration)
        ]);
        return {
            key: key,
            title: title,
            artist: artist,
            album: album,
            duration: duration
        };
    }

    function _invalidateRequests(): void {
        root._requestSerial++;
        root._latestRequestId = String(root._requestSerial);
        root._pendingRequest = null;
        if (lyricsProc.running)
            lyricsProc.running = false;
    }

    function scheduleRefresh(): void {
        if (!root.active) {
            refreshTimer.stop();
            root._invalidateRequests();
            return;
        }
        refreshTimer.restart();
    }

    function _queueCurrentTrack(): void {
        if (!root.active)
            return;

        const snapshot = root._snapshot();
        const settled = root.status === "ok" || root.status === "not_found"
            || root.status === "no_info" || root.status === "error";
        const inFlight = lyricsProc.running || root._pendingRequest !== null;
        if (snapshot.key === root._latestTrackKey && (settled || inFlight))
            return;

        if (snapshot.key !== root._publishedTrackKey)
            root._clearPublished();

        root._requestSerial++;
        const requestId = String(root._requestSerial);
        root._latestRequestId = requestId;
        root._latestTrackKey = snapshot.key;

        if (!snapshot.title || !snapshot.artist) {
            root._pendingRequest = null;
            if (lyricsProc.running)
                lyricsProc.running = false;
            root._publishFailure(requestId, "no_info");
            return;
        }
        if (!Network.online) {
            root._pendingRequest = null;
            root._latestTrackKey = "";
            root._publishFailure(requestId, "offline");
            return;
        }

        root._pendingRequest = {
            requestId: requestId,
            trackKey: snapshot.key,
            title: snapshot.title,
            artist: snapshot.artist,
            album: snapshot.album,
            duration: snapshot.duration
        };
        root.status = "loading";

        if (lyricsProc.running)
            lyricsProc.running = false;
        else
            root._startPendingRequest();
    }

    function _startPendingRequest(): void {
        if (!root.active || root._pendingRequest === null || lyricsProc.running)
            return;

        const request = root._pendingRequest;
        if (request.requestId !== root._latestRequestId) {
            root._pendingRequest = null;
            return;
        }

        root._pendingRequest = null;
        root._runningRequestId = request.requestId;
        root._runningTrackKey = request.trackKey;
        lyricsProc.command = [
            `${Directories.scriptsPath}/lib/accel-run`,
            "lyrics",
            request.title,
            request.artist,
            request.album,
            String(Math.floor(request.duration)),
            request.requestId
        ];
        lyricsProc.running = true;
    }

    function _publishFailure(requestId: string, nextStatus: string): void {
        Qt.callLater(() => {
            if (!root.active || requestId !== root._latestRequestId)
                return;
            root.status = nextStatus;
            root._clearPublished();
        });
    }

    function _publishSuccess(requestId: string, lines: var): void {
        Qt.callLater(() => {
            if (!root.active || requestId !== root._latestRequestId)
                return;

            root.lyricsLines = lines;
            root.activeIndex = -1;
            root.slots = root.buildSlots(-1);
            root._lastReported = -1;
            const reported = MprisController.positionOf(root.activePlayer);
            root._reanchor(reported);
            root._publishedTrackKey = root._latestTrackKey;
            root.status = "ok";
        });
    }

    Connections {
        target: Network
        function onOnlineChanged() {
            if (Network.online && root.status === "offline") root.scheduleRefresh()
        }
    }

    onActiveChanged: root.scheduleRefresh()
    onActivePlayerChanged: root.scheduleRefresh()

    Timer {
        id: refreshTimer
        interval: 350
        repeat: false
        onTriggered: root._queueCurrentTrack()
    }

    property real _anchorPos: 0
    property real _anchorMs: 0
    property real _lastReported: -1
    // The last readings as position minus wall time, and one far behind the clock waiting to be believed.
    property var _readings: []
    property var _behind: null

    readonly property bool _playing: root.activePlayer?.isPlaying ?? false
    // The song's clock for faces that move with it: `clockPos` seconds at wall time `clockMs`, running while `playing`.
    readonly property real clockPos: root._anchorPos
    readonly property real clockMs: root._anchorMs
    readonly property bool playing: root._playing
    function clockAt(nowMs: real): real {
        return root._playing ? root._anchorPos + (nowMs - root._anchorMs) / 1000 : root._anchorPos;
    }

    function _reanchor(pos: real): void {
        root._readings = [];
        root._behind = null;
        root._anchorPos = pos;
        root._anchorMs = Date.now();
    }

    // A reading is only ever older than the truth, never newer: the clock follows the best of the last ten (SekaiPop's
    // LyricsMath.observe), not their average, which sagged and swung early, late, early with a slow player.
    function _observe(polled: real): void {
        const now = Date.now();
        if (!root._playing || root._readings.length === 0) {
            root._reanchor(polled);
            root._readings = [polled - now / 1000];
            return;
        }
        const o = polled - now / 1000;
        const d = o - (root._anchorPos - root._anchorMs / 1000);
        if (Math.abs(d) >= 1.5) {
            root._reanchor(polled);
            root._readings = [o];
            return;
        }
        if (d < -0.35) {
            // Behind: a late reading, or a seek back when enough in a row agree.
            const n = root._behind && Math.abs(o - root._behind.o) < 0.12 ? root._behind.n + 1 : 1;
            if (n >= (d > -0.8 ? 8 : 3)) {
                root._reanchor(polled);
                root._readings = [o];
            } else {
                root._behind = { o: o, n: n };
            }
            return;
        }
        const next = root._readings.concat([o]).slice(-10);
        root._readings = next;
        root._behind = null;
        root._anchorPos = Math.max(...next) + now / 1000;
        root._anchorMs = now;
    }

    function _estimatedPosition(): real {
        if (!root._playing)
            return root._anchorPos;
        return root._anchorPos + (Date.now() - root._anchorMs) / 1000;
    }

    // Pausing holds where the player says it stopped, not where the last reading left the clock.
    on_PlayingChanged: {
        root.activePlayer?.positionChanged();
        const reported = MprisController.positionOf(root.activePlayer);
        root._lastReported = reported;
        root._reanchor(reported > 0 ? reported : root._anchorPos);
    }

    Timer {
        id: syncTimer
        interval: 300
        repeat: true
        // Paused, nothing moves: the clock holds and the index with it.
        running: root.active && root._playing && root.status === "ok" && root.lyricsLines.length > 0
        triggeredOnStart: true
        onTriggered: {
            root.activePlayer?.positionChanged();
            const reported = MprisController.positionOf(root.activePlayer);
            if (reported !== root._lastReported) {
                root._lastReported = reported;
                if (reported > 0 || root._anchorPos === 0)
                    root._observe(reported);
            }

            const pos = root._estimatedPosition();
            let idx = -1;
            for (let i = 0; i < root.lyricsLines.length; i++) {
                if (root.lyricsLines[i].time <= pos)
                    idx = i;
                else
                    break;
            }
            if (idx !== root.activeIndex) {
                root.activeIndex = idx;
                root.slots = root.buildSlots(idx);
            }
        }
    }

    Process {
        id: lyricsProc
        running: false

        stdout: StdioCollector {
            id: lyricsCollector
            onStreamFinished: {
                const raw = lyricsCollector.text.trim();
                if (raw.length === 0)
                    return;

                let payload;
                try {
                    payload = JSON.parse(raw);
                } catch (e) {
                    if (root._runningRequestId !== ""
                            && root._runningRequestId === root._latestRequestId)
                        console.log("LyricsService: unparseable lyrics output:", raw.slice(0, 200));
                    return;
                }

                const requestId = String(payload.requestId ?? "");
                if (requestId === "" || requestId !== root._runningRequestId
                        || requestId !== root._latestRequestId)
                    return;

                if (payload.status !== "ok") {
                    if (payload.status === "error")
                        console.log("LyricsService:", payload.message ?? "unknown error");
                    root._publishFailure(requestId,
                        payload.status === "no_info" ? "no_info"
                            : payload.status === "error" ? "error" : "not_found");
                    return;
                }

                const lines = (payload.lines ?? [])
                    .filter(line => typeof line.t === "number")
                    .map(line => {
                        // Enhanced LRC keeps its word stamps out of the text.
                        const words = LyricsMath.readWords(line.text ?? "");
                        return { time: line.t, text: words.text, marks: words.marks };
                    });

                if (lines.length === 0) {
                    root._publishFailure(requestId, "not_found");
                    return;
                }

                root._publishSuccess(requestId, lines);
            }
        }

        onExited: {
            root._runningRequestId = "";
            root._runningTrackKey = "";
            Qt.callLater(root._startPendingRequest);
        }
    }

    Connections {
        target: root.activePlayer

        function onPostTrackChanged(): void {
            root.scheduleRefresh();
        }

        function onTrackTitleChanged(): void {
            root.scheduleRefresh();
        }

        function onTrackArtistChanged(): void {
            root.scheduleRefresh();
        }

        function onTrackAlbumChanged(): void {
            root.scheduleRefresh();
        }

        function onLengthChanged(): void {
            root.scheduleRefresh();
        }
    }
}
