pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services

import QtQuick
import QtMultimedia
import Quickshell

/**
 * Looping, stoppable alarm audio.
 *
 * Audio.playEvent() cannot serve a ring: it ends in Quickshell.execDetached(),
 * which hands back no handle, so the sound can neither loop nor be stopped. Its
 * other callers want exactly that fire-and-forget behaviour, so this keeps a
 * retained MediaPlayer of its own instead of changing it. Same resolution rules
 * as Audio.playEvent — "" = theme default, bare name = a sound from the current
 * theme, absolute path or file:// played directly, volume from sounds.volume —
 * a different playback mechanism underneath them.
 *
 * The coupling to AlarmService is one-directional on purpose: this observes
 * ringStarted/ringStopped, and the service knows nothing about audio. That is
 * what keeps its state machine testable without side effects, and it is also
 * why a sound problem can never stop a ring: the ringing surface hangs off
 * AlarmService.ringingId, which nothing in this file can reach.
 */
Singleton {
    id: root

    // The last rung of the chain. freedesktop is the base theme every
    // desktop pulls in, and an absolute path skips a broken sounds.theme
    // setting. If even this is missing the machine has no sounds at all, and
    // soundUnavailable is then the honest answer rather than a bug.
    readonly property string lastResortUrl: "file:///usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"

    // A preview is a sample, not a ring: loops is 1 so it cannot repeat, and
    // this caps a user-supplied file that turns out to be a whole song.
    readonly property int previewCapMs: 10000

    // every candidate failed to load. The ring is unaffected — only the
    // noise is gone — so this is how the ringing surface tells the user the
    // alarm went off and the sound did not.
    property bool soundUnavailable: false
    // What was asked for, so that message can name it.
    property string requestedSound: ""

    /**
     * , stated plainly: an alarm cannot be made audible over a muted system,
     * which is why there is no force-audible option to promise otherwise.
     *
     * A stream is mixed INTO a sink; muting the sink zeroes that mix, and
     * per-stream volume is applied upstream of it, so no stream at any volume
     * survives. Neither PipeWire nor PulseAudio offers a client any way to opt
     * out of its sink's mute. Verified on this stack (PipeWire 1.6.8), where
     * `wpctl set-mute @DEFAULT_AUDIO_SINK@ 1` reaches the card's own ALSA
     * playback switch — but the outcome is the same wherever mute lives, and
     * unmuting the user's system is not the shell's to do.
     *
     * So an alarm on a muted system rings, raises its surface, and says it is
     * silenced — the difference between a user who knows and one who slept in.
     */
    readonly property bool systemMuted: Audio.sink?.audio?.muted ?? false
    readonly property bool ringing: AlarmService.ringingId !== -1
    readonly property bool silencedBySystem: root.ringing && root.systemMuted

    readonly property bool previewing: root._mode === "preview"

    property string _mode: "" // "" | "ring" | "preview"
    property list<string> _candidates: []
    property int _candidateIndex: 0

    // Absolute file URLs to try for one configured sound value, in order.
    function _urlsFor(sound: string): var {
        if (!sound || sound.length === 0)
            return [];
        if (sound.startsWith("file://"))
            return [sound];
        if (sound.startsWith("/"))
            return ["file://" + sound];
        // Audio.playSystemSound tries.oga then.ogg because themes ship one or
        // the other. There that is a shell `||`; here the player already walks a
        // candidate list on error, so they are simply two more entries.
        const base = `file:///usr/share/sounds/${Audio.audioTheme}/stereo/${sound}`;
        return [base + ".oga", base + ".ogg"];
    }

    /**
     * 's fallback chain: per-alarm sound, then the global default, then
     * anything that works. `sound` arrives from AlarmService.resolveSound(),
     * which has already collapsed per-alarm → global; re-adding the global here
     * is a deduped no-op in the common case and the real second hop when the
     * per-alarm override points at a file that is gone.
     */
    function _chainFor(sound: string): var {
        const urls = root._urlsFor(sound).concat(root._urlsFor(Config.options?.sounds?.events?.alarmDone ?? ""), root._urlsFor(Audio.soundEvents?.alarmDone ?? "alarm-clock-elapsed"), [root.lastResortUrl]);
        return urls.filter((url, i) => urls.indexOf(url) === i);
    }

    /**
     * Start a ring for `sound`, looping until stop(). Driven by AlarmService's
     * ringStarted below; exposed so a caller that already knows what it wants
     * (a test, a future re-ring) does not have to fake a signal.
     */
    function playRing(sound: string): void {
        root._start("ring", sound);
    }

    /**
     * Never loops, always stoppable, and refused outright while an alarm
     * is ringing — a preview that sounds identical to the ring is a preview the
     * user will act on. Returns whether it started, so a settings UI can say why
     * nothing happened.
     */
    function preview(sound: string): bool {
        if (root.ringing)
            return false;
        root._start("preview", sound);
        previewCap.restart();
        return true;
    }

    function stopPreview(): void {
        if (root._mode === "preview")
            root.stop();
    }

    function stop(): void {
        previewCap.stop();
        player.stop();
        root._mode = "";
        root._candidates = [];
        root._candidateIndex = 0;
    }

    function _start(mode: string, sound: string): void {
        previewCap.stop();
        root._mode = mode;
        root.requestedSound = sound;
        root.soundUnavailable = false;
        root._candidates = root._chainFor(sound);
        root._candidateIndex = 0;
        root._playCandidate();
    }

    function _playCandidate(): void {
        if (root._candidateIndex >= root._candidates.length) {
            root.soundUnavailable = true;
            root._mode = "";
            player.stop();
            console.warn("[AlarmAudio] No playable sound for", JSON.stringify(root.requestedSound), "- alarm still ringing, silently");
            return;
        }
        player.stop();
        player.source = root._candidates[root._candidateIndex];
        player.play();
    }

    MediaPlayer {
        id: player

        // Infinite while ringing: an alarm the user has not answered must not
        // fall quiet on its own. AlarmService's autoStopMinutes decides when it
        // ends, and it ends it through ringStopped.
        loops: root._mode === "ring" ? MediaPlayer.Infinite : 1

        audioOutput: AudioOutput {
            volume: Config.options?.sounds?.volume ?? 0.5
        }

        // A preview that has simply finished is over. EndOfMedia and not
        // playbackState, because stop() and the error walk below both stop the
        // player too and would recurse back into here.
        onMediaStatusChanged: {
            if (player.mediaStatus === MediaPlayer.EndOfMedia && root._mode === "preview")
                root.stop();
        }

        // The walk. A missing or unplayable file lands here, so the
        // fallback chain and the.oga/.ogg probe share one mechanism.
        onErrorOccurred: (error, errorString) => {
            console.warn("[AlarmAudio] Sound failed:", player.source, "-", errorString);
            root._candidateIndex += 1;
            root._playCandidate();
        }
    }

    Timer {
        id: previewCap
        interval: root.previewCapMs
        onTriggered: root.stopPreview()
    }

    Connections {
        target: AlarmService

        function onRingStarted(id: int, dueMs: real): void {
            const alarm = AlarmService.alarmById(id);
            root.playRing(AlarmService.resolveSound(alarm));
            if (root.systemMuted)
                console.log("[AlarmAudio] Alarm", id, "is ringing while the system sink is muted - silent by design");
        }

        // "dismissed", "missed", "snoozed" or "cancelled" — every one of them
        // ends the noise. Nothing here cares which.
        function onRingStopped(id: int, reason: string): void {
            root.stop();
        }
    }
}
