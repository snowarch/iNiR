pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    property int subscribers: 0
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

    function subscribe(): void {
        root.subscribers++;
    }

    function unsubscribe(): void {
        root.subscribers = Math.max(0, root.subscribers - 1);
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
        const title = player?.trackTitle ?? "";
        const artist = player?.trackArtist ?? "";
        const album = player?.trackAlbum ?? "";
        const duration = player?.length ?? 0;
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
            "python3",
            `${Directories.scriptsPath}/lyrics/lyrics.py`,
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
            const reported = root.activePlayer?.position ?? 0;
            root._reanchor(reported);
            root._publishedTrackKey = root._latestTrackKey;
            root.status = "ok";
        });
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

    readonly property bool _playing: root.activePlayer?.isPlaying ?? false

    function _reanchor(pos: real): void {
        root._anchorPos = pos;
        root._anchorMs = Date.now();
    }

    function _estimatedPosition(): real {
        if (!root._playing)
            return root._anchorPos;
        return root._anchorPos + (Date.now() - root._anchorMs) / 1000;
    }

    on_PlayingChanged: root._reanchor(root._estimatedPosition())

    Timer {
        id: syncTimer
        interval: 300
        repeat: true
        running: root.active && root.status === "ok" && root.lyricsLines.length > 0
        onTriggered: {
            root.activePlayer?.positionChanged();
            const reported = root.activePlayer?.position ?? 0;
            if (reported !== root._lastReported) {
                root._lastReported = reported;
                if (reported > 0 || root._anchorPos === 0)
                    root._reanchor(reported);
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
                        console.log("LyricsService: unparseable output from lyrics.py:", raw.slice(0, 200));
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
                    .map(line => ({
                        time: line.t,
                        text: line.text ?? ""
                    }));

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
