pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * User alarms: records, CRUD and persistence.
 *
 * Record shape (one plain object per alarm, persisted to Directories.alarmsPath):
 *
 *   id            int     Identity. Monotonic, never reused. Two alarms may share
 *                         a time; nothing here merges or deduplicates them.
 *   name          string  May be empty. The default shown for an unnamed alarm is
 *                         resolved at render time by displayName() — never stored,
 *                         so it follows a language change.
 *   hour          int     0-23, format-independent.
 *   minute        int     0-59.
 *   enabled       bool    Armed. Disarming keeps the record intact.
 *   mode          string  "next" | "repeat" | "date". Derived from the two
 *                         fields below and kept in the record for readers.
 *   repeatDays    int     Weekday bitmask, bit N = JS Date.getDay() N
 *                         (bit 0 = Sunday. bit 6 = Saturday). 0 in other modes.
 *   date          string  "YYYY-MM-DD" in dated mode, "" otherwise. The time comes
 *                         from hour/minute; a second copy of it here could diverge.
 *   sound         string? null = inherit sounds.events.alarmDone.
 *   snoozeMinutes int?    null = inherit alarms.snoozeMinutes.
 *   lastFiredAt   real    Epoch ms of the last ring, 0 = never. `real`, not `int`:
 *                         epoch ms overflows a 32-bit QML int.
 *   lastOccurrence real   Epoch ms of the scheduled occurrence that last ring
 *                         belonged to, 0 = never. The fired-once key — see
 *                         hasFired(). Not lastFiredAt, which a snooze moves.
 *   lastOutcome   string  "none" | "dismissed" | "missed". Missed is not dismissed
 *                         and the two must stay visibly distinct.
 *
 * null is the override sentinel on purpose: it is the only value that
 * distinguishes "not set" from "set to the same value the global happens to
 * have right now", which is exactly what the override rule needs to move the second alarm
 * and not the first when a global default changes.
 */
Singleton {
    id: root

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    readonly property string modeNext: "next"
    readonly property string modeRepeat: "repeat"
    readonly property string modeDate: "date"

    readonly property string outcomeNone: "none"
    readonly property string outcomeDismissed: "dismissed"
    readonly property string outcomeMissed: "missed"

    property string filePath: Directories.alarmsPath
    // Ordered by id, which is also the stable tie-break needed when two
    // alarms share a minute. Ids only increase, so append keeps it sorted.
    property list<var> list: []
    property int nextId: 1

    signal alarmAdded(int id)
    signal alarmRemoved(int id)
    signal alarmUpdated(int id)

    // True once the file has been read (or confirmed absent). Nothing may write
    // before that: a save against the still-empty default list would wipe every
    // alarm the user owns.
    property bool loaded: false

    // Set only while _settle() writes its own bookkeeping back through
    // updateAlarm, so that write is not mistaken for a user edit and does not
    // tear down the ring it is in the middle of settling. See updateAlarm.
    property bool _settling: false

    FileView {
        id: alarmsFileView
        path: Qt.resolvedUrl(root.filePath)
        // Deliberately NOT watched. Quickshell's FileView emits fileChanged on a
        // watched path but does not re-read it — a reload has to be asked for, as
        // Persistent.qml does with its debounced fileReloadTimer. Setting
        // watchChanges here without that wiring claimed a reload that never
        // happened, so the file is now unambiguously shell-owned: this process is
        // the only writer, and a hand edit lands on the next shell start (or an
        // explicit loadFromFile()). Adding the reload back would also have to
        // defend the ring, queue and snoozes the pipeline is holding against a
        // list that changed underneath them, which is a lot of machinery for a
        // file nothing else writes.
        // Narrows, but does not close, the window between this singleton being
        // constructed and the file arriving — measured, the load still lands a
        // turn later. The `loaded` guard below is what actually stops a save in
        // that window from overwriting every alarm the user owns.
        blockLoading: true
        onLoaded: {
            const fileContents = alarmsFileView.text();
            if (!fileContents || fileContents.trim() === "") {
                root.list = [];
                root.nextId = 1;
            } else
                try {
                    const data = JSON.parse(fileContents);
                    const loaded = (data.alarms ?? []).map(a => root._normalize(a));
                    root.list = loaded;
                    root.nextId = Math.max(data.nextId ?? 1, ...loaded.map(a => a.id + 1), 1);
                    root._log("[Alarms] Loaded", loaded.length, "alarms");
                } catch (e) {
                    console.warn("[Alarms] Failed to parse file:", e);
                    root.list = [];
                    root.nextId = 1;
                }
            // Last, never first: anything bound to `loaded` runs the moment this
            // is set, and a reader that sees loaded === true with an empty list
            // concludes the user owns no alarms. Measured — it cost a ring that
            // was recovering across a restart.
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                console.log("[Alarms] File not found, creating new file.");
                const parentDir = root.filePath.substring(0, root.filePath.lastIndexOf('/'));
                Quickshell.execDetached(["/usr/bin/mkdir", "-p", parentDir]);
                root.list = [];
                root.nextId = 1;
                root.loaded = true;
                root.saveToFile();
            } else {
                // Deliberately NOT marking loaded: an unreadable file must not
                // be replaced by an empty one on the next mutation.
                console.warn("[Alarms] Error loading file:", error);
            }
        }
    }

    // Coerce an arbitrary object into a well-formed record. Everything that
    // reaches the list goes through here, so a hand-edited file cannot produce
    // a shape the rest of the feature has to defend against.
    function _normalize(alarm: var): var {
        const date = String(alarm?.date ?? "");
        const repeatDays = Math.trunc(alarm?.repeatDays ?? 0) & 0x7F;
        // the modes are exclusive. If a record somehow carries both, the
        // date wins and the repeat set is dropped — deterministic beats clever.
        const mode = date !== "" ? root.modeDate : (repeatDays !== 0 ? root.modeRepeat : root.modeNext);
        const outcome = [root.outcomeDismissed, root.outcomeMissed].includes(alarm?.lastOutcome) ? alarm.lastOutcome : root.outcomeNone;
        return {
            id: Math.trunc(alarm?.id ?? 0),
            name: String(alarm?.name ?? ""),
            hour: Math.min(23, Math.max(0, Math.trunc(alarm?.hour ?? 0))),
            minute: Math.min(59, Math.max(0, Math.trunc(alarm?.minute ?? 0))),
            enabled: alarm?.enabled !== false,
            mode: mode,
            repeatDays: mode === root.modeRepeat ? repeatDays : 0,
            date: mode === root.modeDate ? date : "",
            // Written out explicitly rather than left undefined so the sentinel
            // is visible in the file and survives the JSON round trip.
            sound: alarm?.sound ?? null,
            snoozeMinutes: alarm?.snoozeMinutes ?? null,
            lastFiredAt: Number(alarm?.lastFiredAt ?? 0),
            // Occurrence the last ring belonged to, 0 = never. Distinct from
            // lastFiredAt on purpose: that is when the bell rang (a snooze
            // moves it), this is which scheduled moment was served, and only
            // the latter is a safe fired-once key across a DST shift.
            lastOccurrence: Number(alarm?.lastOccurrence ?? 0),
            lastOutcome: outcome
        };
    }

    function _indexOf(id: int): int {
        return root.list.findIndex(a => a.id === id);
    }

    function alarmById(id: int): var {
        const index = root._indexOf(id);
        return index === -1 ? null : root.list[index];
    }

    /**
     * Create an alarm. Name is optional and there is no cap on the
     * count. `options` may carry any other record field.
     * Returns the new id.
     */
    function addAlarm(hour: int, minute: int, name: string, options: var): int {
        if (!root.loaded)
            return -1;
        const alarm = root._normalize(Object.assign({
            hour: hour,
            minute: minute,
            name: name ?? "",
            enabled: true
        }, options ?? {}, {
            id: root.nextId
        }));
        const check = root.validateSchedule(alarm, Date.now());
        root.lastScheduleError = check.reason;
        if (!check.valid)
            return -1;
        root.nextId += 1;
        root.list = root.list.concat([alarm]);
        root.saveToFile();
        root.alarmAdded(alarm.id);
        return alarm.id;
    }

    function removeAlarm(id: int): bool {
        if (!root.loaded)
            return false;
        const index = root._indexOf(id);
        if (index === -1)
            return false;
        root.list = root.list.filter(a => a.id !== id);
        root.saveToFile();
        // No sound outlives its alarm. Without this the pipeline would
        // keep a ringingId pointing at a record that no longer exists, and
        // nothing could ever settle it.
        root.cancelAlarm(id);
        root.alarmRemoved(id);
        return true;
    }

    /**
     * Patch an existing alarm. `updates` carries only the fields that change.
     * Setting a date clears the repeat set and vice versa — enforced
     * here rather than in the editor so no caller can build a contradictory
     * schedule.
     */
    function updateAlarm(id: int, updates: var): bool {
        if (!root.loaded)
            return false;
        const index = root._indexOf(id);
        if (index === -1)
            return false;
        const patch = Object.assign({}, updates ?? {});
        if (patch.date !== undefined && String(patch.date) !== "")
            patch.repeatDays = 0;
        else if (patch.repeatDays !== undefined && (Math.trunc(patch.repeatDays) & 0x7F) !== 0)
            patch.date = "";
        // Deliberate: a missed marker lives on the record
        // until the alarm is next armed, edited, or fires again — no history
        // list and no timed expiry. The firing pipeline always names the
        // outcome it is writing, so anything that does not is an edit.
        if (patch.lastOutcome === undefined)
            patch.lastOutcome = root.outcomeNone;
        const updated = root._normalize(Object.assign({}, root.list[index], patch, {
            id: id
        }));
        if (root._touchesSchedule(patch)) {
            const check = root.validateSchedule(updated, Date.now());
            root.lastScheduleError = check.reason;
            if (!check.valid)
                return false;
        }
        const next = root.list.slice();
        next[index] = updated;
        root.list = next;
        root.saveToFile();
        // , in the one place every edit already passes through. An
        // alarm that is ringing, queued or snoozed under settings that just
        // changed must stop, and putting that here rather than in each caller
        // is what makes it impossible to bypass — the editor, the list's arm
        // toggle and anything added later all land on this line. removeAlarm
        // has the same call for the same reason.
        //
        // _settling excludes the pipeline's own bookkeeping write: _settle
        // records lastOccurrence/lastOutcome and disarms a one-shot AFTER it
        // has already decided the ring's fate, and must not be read as a user
        // edit that cancels it.
        if (!root._settling)
            root.cancelAlarm(id);
        root.alarmUpdated(id);
        return true;
    }

    // , one resolution rule for all three overridable settings: the
    // alarm's own value if it has one, otherwise the global default.
    function resolveSound(alarm: var): string {
        return (alarm?.sound ?? Config.options?.sounds?.events?.alarmDone) ?? "";
    }

    function resolveSnoozeMinutes(alarm: var): int {
        return (alarm?.snoozeMinutes ?? Config.options?.alarms?.snoozeMinutes) ?? 5;
    }

    // The default name for an unnamed alarm, resolved at render time so it
    // follows the current language.
    function displayName(alarm: var): string {
        const name = alarm?.name ?? "";
        return name !== "" ? name : Translation.tr("Alarm");
    }

    // ---- Scheduling engine -----------------------------
    // Everything that needs to know "when does this next fire" — the tab, the
    // bar indicator and the poll — calls nextOccurrence(). A second copy of
    // this arithmetic anywhere else is a bug waiting to happen.

    // Owner decision: a dated alarm may be set at most this far ahead.
    readonly property int dateHorizonYears: 1

    // Why the last addAlarm/updateAlarm rejection happened, for a caller that
    // did not pre-check with validateSchedule(). "" when the last call was fine.
    property string lastScheduleError: ""

    /**
     * Absolute epoch ms of a wall-clock time on a calendar day. `month` is
     * 0-based and `day` may be out of range — JS normalises both, which is how
     * the "+1 day" rollovers below stay a one-liner.
     *
     * DST, and the reason this is not just `new Date(.).getTime()`:
     *
     * The occurrence is defined as *the earliest instant whose local time is at
     * or after the requested one on that day*. That single definition settles
     * both transitions, and it is the thing to re-derive at 3am:
     *
     *  - Forward shift, requested time SKIPPED (02:30 where 02:00-03:00
     *    vanishes): the plain Date constructor is specified to resolve a
     *    non-existent local time using the offset in force *before* the shift,
     *    which lands on 03:30 — half an hour late and past the moment the user
     *    would have woken. The earliest instant at-or-after 02:30 local is the
     *    shift instant itself, rendering 03:00. So we walk back to it. The
     *    alarm fires once, at the shift, never skipped and never doubled.
     *  - Backward shift, requested time REPEATED (01:30 happening twice): the
     *    constructor already picks the earlier of the two offsets, so this
     *    returns the first 01:30 and the loop below exits immediately. Firing
     *    once is then the poll's job, not this function's — see hasFired(),
     *    which is keyed on the occurrence timestamp precisely so the second,
     *    numerically later 01:30 cannot re-trigger the same occurrence.
     */
    function _occurrenceMs(year: int, month: int, day: int, hour: int, minute: int): real {
        const exact = new Date(year, month, day, hour, minute, 0, 0);
        if (exact.getHours() === hour && exact.getMinutes() === minute)
            return exact.getTime();
        // The requested local time does not exist on this day. Walk back a
        // minute at a time to the shift instant. Bounded by the longest real
        // DST gap (one hour); the guard is only there so a pathological zone
        // cannot spin.
        const target = hour * 60 + minute;
        const dayOfMonth = exact.getDate();
        let ms = exact.getTime();
        for (let i = 0; i < 180; i++) {
            const prev = new Date(ms - 60000);
            if (prev.getDate() !== dayOfMonth || prev.getHours() * 60 + prev.getMinutes() < target)
                break;
            ms -= 60000;
        }
        return ms;
    }

    /**
     * The first occurrence of `alarm` at or after `fromMs`, in epoch ms, or -1
     * for "never fires again". Pure: the same arguments always give the
     * same answer, which is what makes an alarm created for the current minute
     * deterministic and what lets the self-check inject timestamps instead of
     * waiting for midnight.
     *
     * "At or after" is deliberate on both sides. The tab and the bar pass
     * Date.now() and get the future. The poll passes the last time it looked
     * and gets any occurrence that came due in between — including one that is
     * now in the past, which is what the grace window needs. A
     * function that only ever returned future instants could not express that.
     *
     * A disarmed alarm has no next occurrence.
     */
    function nextOccurrence(alarm: var, fromMs: real): real {
        if (!alarm || alarm.enabled === false)
            return -1;
        const hour = Math.trunc(alarm.hour ?? 0);
        const minute = Math.trunc(alarm.minute ?? 0);

        // Dated mode: that clock time on that date, and only then.
        const date = String(alarm.date ?? "");
        if (date !== "") {
            const parts = date.split("-").map(Number);
            if (parts.length !== 3 || parts.some(n => !isFinite(n)))
                return -1;
            const ms = root._occurrenceMs(parts[0], parts[1] - 1, parts[2], hour, minute);
            return ms >= fromMs ? ms : -1;
        }

        const repeatDays = Math.trunc(alarm.repeatDays ?? 0) & 0x7F;
        // Next-occurrence mode looks at today and tomorrow; repeating mode
        // walks a full week plus one so a set containing only today's weekday
        // still rolls to the same weekday next week. Offset 0 ("today") is
        // accepted only if the occurrence is still at or after fromMs, which
        // is also what makes an alarm at 00:00 land on the *following* day
        // rather than the one it was created on.
        const span = repeatDays === 0 ? 1 : 7;
        for (let offset = 0; offset <= span; offset++) {
            const day = new Date(fromMs);
            day.setHours(12, 0, 0, 0); // midday: immune to a midnight DST shift
            day.setDate(day.getDate() + offset);
            if (repeatDays !== 0 && (repeatDays & (1 << day.getDay())) === 0)
                continue;
            const ms = root._occurrenceMs(day.getFullYear(), day.getMonth(), day.getDate(), hour, minute);
            if (ms >= fromMs)
                return ms;
        }
        return -1;
    }

    /**
     * Armed alarms paired with their next occurrence, soonest first. Ties break
     * on id, so two alarms sharing a minute keep one stable order that survives
     * a restart — never list or iteration order.
     * Returns [{ alarm, at }].
     */
    function upcoming(fromMs: real): var {
        return root.list.map(a => ({
                    alarm: a,
                    at: root.nextOccurrence(a, fromMs)
                })).filter(e => e.at >= 0).sort((x, y) => x.at - y.at || x.alarm.id - y.alarm.id);
    }

    /**
     * What will actually RING next, soonest first. A pending snooze is that
     * alarm's next ring and outranks its scheduled slot: an alarm snoozed to
     * 08:35 rings at 08:35, not at tomorrow's 08:30.
     *
     * Separate from upcoming() on purpose. upcoming() answers the SCHEDULE and
     * the firing pipeline depends on that — _dueSince() feeds it to decide what
     * came due, and snoozes are drained by their own path, so an upcoming() that
     * knew about snoozes would serve the same re-ring twice. This one is for
     * display: anything showing a user "when does it go off" wants it.
     * Returns [{ alarm, at, snoozed }].
     */
    function upcomingRings(fromMs: real): var {
        const untilById = {};
        for (const entry of root.snoozed)
            untilById[entry.id] = entry.untilMs;
        return root.list.map(a => {
            const until = untilById[a.id];
            const snoozed = until !== undefined;
            return {
                alarm: a,
                // A snooze already overdue still sorts first — it is about to
                // ring, so clamping it to the future would hide exactly that.
                at: snoozed ? until : root.nextOccurrence(a, fromMs),
                snoozed: snoozed
            };
        }).filter(e => e.at >= 0).sort((x, y) => x.at - y.at || x.alarm.id - y.alarm.id);
    }

    /**
     * Has this alarm already rung for this occurrence? Keyed on the occurrence
     * timestamp, never on the clock time: during a backward DST shift the same
     * clock time comes round twice and a clock-time key would ring twice. The
     * comparison is <= rather than ===, so a clock moved backwards cannot
     * resurrect an occurrence that has already been served either.
     * another path owns writing lastOccurrence; this owns what it means.
     */
    function hasFired(alarm: var, occurrenceMs: real): bool {
        return occurrenceMs >= 0 && occurrenceMs <= Number(alarm?.lastOccurrence ?? 0);
    }

    /**
     * Returns { valid: bool, reason: string }; reason is "" when valid.
     * An object rather than a bool because a refusal the user cannot explain is
     * indistinguishable from a bug.
     *
     * Dated mode only. Next-occurrence and repeating alarms resolve forward by
     * construction and must never be rejected — an over-eager guard here
     * is exactly what steps 5 and 6 are looking for. A disarmed alarm is
     * likewise never rejected: has a fired dated alarm keep its now-past
     * date, and re-arming it is where the refusal belongs.
     */
    function validateSchedule(alarm: var, fromMs: real): var {
        if (!alarm)
            return {
                valid: false,
                reason: Translation.tr("No alarm to save.")
            };
        const date = String(alarm.date ?? "");
        if (date === "" || alarm.enabled === false)
            return {
                valid: true,
                reason: ""
            };
        const at = root.nextOccurrence(Object.assign({}, alarm, {
            enabled: true
        }), fromMs);
        if (at < 0)
            return {
                valid: false,
                reason: Translation.tr("That date and time has already passed.")
            };
        const horizon = new Date(fromMs);
        horizon.setFullYear(horizon.getFullYear() + root.dateHorizonYears);
        if (at > horizon.getTime())
            return {
                valid: false,
                reason: Translation.tr("An alarm cannot be set more than a year ahead.")
            };
        return {
            valid: true,
            reason: ""
        };
    }

    // Only a patch that moves the schedule — or re-arms it — gets validated.
    // Post-fire bookkeeping must be able to write through to an alarm whose
    // date is now in the past, or could never record the ring
    // that put it there.
    function _touchesSchedule(patch: var): bool {
        return patch.hour !== undefined || patch.minute !== undefined || patch.date !== undefined || patch.repeatDays !== undefined || patch.enabled === true;
    }
    // -------------------------------------------------------------------------

    // ---- Firing pipeline --------------
    //
    // One state machine, five states, and every one of them is a fact about the
    // wall clock rather than a countdown. Nothing here decrements: a ring, a
    // queue position and a snooze are all absolute timestamps, which is the only
    // reason any of them survives a restart.
    //
    //   idle     ── occurrence due, nothing ringing ──▶ ringing
    //   idle     ── occurrence due, something ringing ─▶ queued
    //   idle     ── due while the shell was away, in grace ──▶ queued
    //   idle     ── due while the shell was away, out of grace ─▶ settled(missed)
    //   queued   ── front of the queue, nothing ringing ─▶ ringing
    //   ringing  ── dismissAlarm() ──▶ settled(dismissed)
    //   ringing  ── snoozeAlarm() ───▶ snoozed        (the alarm is NOT settled)
    //   ringing  ── autoStopMinutes elapsed ─▶ settled(missed)
    //   snoozed  ── untilMs reached ─▶ queued (then ringing)
    //   any      ── cancelAlarm() ──▶ idle            (, no outcome)
    //
    // "Settled" is the only transition that writes lastOccurrence, and writing
    // it is what stops the poll re-firing the same moment — including the second
    // 01:30 of a backward DST shift, since hasFired() compares timestamps.
    //
    // Audio lives in AlarmAudio and the ringing surface in; both
    // hook ringStarted/ringStopped. Nothing below plays a sound, so the whole
    // machine is exercisable with no audio side effects.

    readonly property int pollIntervalMs: 60000
    // Owner decision: graceMinutes -1 means "unlimited", and unlimited is capped
    // here. A day-old alarm ambushing someone at login is a bug, not a feature.
    readonly property int graceCapMinutes: 720

    // Shell start. An occurrence earlier than this came due with nobody
    // watching, which is the one thing the grace window judges.
    property real startedAtMs: Date.now()

    readonly property var _state: Persistent.states?.timer?.alarms ?? null

    // Nothing may poll before both stores have answered: the alarm records
    // decide what is due, the persisted state decides what was already live.
    readonly property bool pollActive: root.loaded && Persistent.ready
    property bool _recovered: false

    /**
     * What the pipeline currently holds this alarm in:
     * "ringing" | "queued" | "snoozed" | "idle". The vocabulary the UI badges
     * and the audio hook both speak, kept in one place.
     */
    function alarmState(id: int): string {
        const state = root._state;
        if (!state)
            return "idle";
        if (state.ringingId === id)
            return "ringing";
        if (root._copyList(state.queued).some(e => e.id === id))
            return "queued";
        if (root._copyList(state.snoozed).some(e => e.id === id))
            return "snoozed";
        return "idle";
    }

    readonly property int ringingId: root._state?.ringingId ?? -1
    // The scheduled moment this ring belongs to — not when it started. A queued
    // or snoozed alarm rings late on purpose and has to be able to say so, and
    // say what its actual time was.
    readonly property real ringingDueMs: root._state?.ringingDueMs ?? 0
    readonly property real ringingSinceMs: root._state?.ringingSinceMs ?? 0
    readonly property var ringingAlarm: root.ringingId === -1 ? null : root.alarmById(root.ringingId)
    readonly property bool ringingLate: root.ringingId !== -1 && (root.ringingSinceMs - root.ringingDueMs) > root.pollIntervalMs
    // [{ id, dueMs }] waiting behind the ring, and [{ id, dueMs, untilMs }] in
    // snooze. Read-only views for the UI; every mutation goes through the
    // functions below so the one-ringing-at-a-time invariant has one owner.
    readonly property var queued: root._copyList(root._state?.queued)
    readonly property var snoozed: root._copyList(root._state?.snoozed)

    // A ring began. the audio service starts the loop here, the panel raises the surface.
    signal ringStarted(int id, real dueMs)
    // A ring ended. `reason` is "dismissed", "missed", "snoozed" or "cancelled"
    // the first two are also the record's lastOutcome, the last two are not
    // outcomes at all. the audio service stops the loop on any of them.
    signal ringStopped(int id, string reason)

    // Persistent's list<var> reads back array-like, but an element read out of
    // it stays a live view onto its slot: hold one across a write to the list
    // and it silently re-points at whatever moved into that slot — measured,
    // and it cost the front of the queue its identity. So this snapshots by
    // value. Whole-list assignment for the same reason: an in-place push does
    // not reliably reach the adapter's change signal.
    function _copyList(value: var): var {
        return JSON.parse(JSON.stringify(Array.prototype.slice.call(value ?? [])));
    }

    function _graceMs(): real {
        const minutes = Config.options?.alarms?.graceMinutes ?? 5;
        return (minutes < 0 ? root.graceCapMinutes : Math.min(minutes, root.graceCapMinutes)) * 60000;
    }

    function _autoStopMs(): real {
        return Math.max(1, Config.options?.alarms?.autoStopMinutes ?? 5) * 60000;
    }

    /**
     * Was nobody watching when this moment passed? Either the shell was not up
     * yet, or it was up but not polling — a suspended machine, which is the
     * case step 5 covers. Two poll intervals of slack, because a poll
     * legitimately notices an occurrence up to one interval after it passes.
     */
    function _isLate(occurrenceMs: real, nowMs: real): bool {
        return occurrenceMs < root.startedAtMs || (nowMs - occurrenceMs) > root.pollIntervalMs * 2;
    }

    // The grace window judges late occurrences and nothing else: an alarm
    // that comes due with the shell running rings whatever the window is set to,
    // including zero.
    function _withinGrace(occurrenceMs: real, nowMs: real): bool {
        return !root._isLate(occurrenceMs, nowMs) || (nowMs - occurrenceMs) <= root._graceMs();
    }

    /**
     * End of the road for one occurrence. Writes lastOccurrence — the
     * fired-once key hasFired() reads — and applies the post-fire rule for the
     * alarm's mode:
     *   next   → stays in the list, toggle off, name/time/options untouched
     *   date   → the same, and KEEPS ITS DATE. Nothing is cleared or rewritten;
     *            a now-past date is only refused on re-arm.
     *   repeat → stays armed, and rolls forward by itself because nextOccurrence
     *            resolves from now.
     * `rangAtMs` is 0 when the alarm never actually sounded — an occurrence
     * missed out of grace has no last-ring time to record.
     */
    function _settle(id: int, occurrenceMs: real, outcome: string, rangAtMs: real): void {
        const alarm = root.alarmById(id);
        if (!alarm)
            return;
        const updates = {
            lastOccurrence: occurrenceMs,
            lastOutcome: outcome
        };
        if (rangAtMs > 0)
            updates.lastFiredAt = rangAtMs;
        if (alarm.mode !== root.modeRepeat)
            updates.enabled = false;
        root._settling = true;
        root.updateAlarm(id, updates);
        root._settling = false;
        root._log("[Alarms] Settled", id, "occurrence", occurrenceMs, "as", outcome);
    }

    function _startRing(id: int, dueMs: real, nowMs: real): void {
        root._state.ringingId = id;
        root._state.ringingDueMs = dueMs;
        root._state.ringingSinceMs = nowMs;
        root.ringStarted(id, dueMs);
        root._log("[Alarms] Ringing", id, "for occurrence", dueMs);
    }

    function _stopRing(reason: string): void {
        const state = root._state;
        const id = state.ringingId;
        if (id === -1)
            return;
        state.ringingId = -1;
        state.ringingDueMs = 0;
        state.ringingSinceMs = 0;
        root.ringStopped(id, reason);
    }

    // never dropped, never merged, identity and name intact — the queue
    // stores ids, so the alarm it points at is the alarm that rings. Appended in
    // the order occurrences became due, which is upcoming()'s order within a
    // poll and chronological across polls; that is FIFO by due time without a
    // second sort key to disagree with.
    function _enqueue(id: int, dueMs: real): void {
        const queue = root._copyList(root._state.queued);
        queue.push({
            id: id,
            dueMs: dueMs
        });
        root._state.queued = queue;
    }

    // Exactly one alarm rings at a time. Called after every transition that
    // frees the ring.
    function _drain(nowMs: real): void {
        const state = root._state;
        if (!state || state.ringingId !== -1)
            return;
        const queue = root._copyList(state.queued);
        let entry = null;
        while (queue.length > 0 && !entry) {
            const candidate = queue.shift();
            if (root.alarmById(candidate.id))
                entry = candidate;
        }
        state.queued = queue;
        if (entry)
            root._startRing(entry.id, entry.dueMs, nowMs);
    }

    /**
     * Occurrences that fell due between `floorMs` and `nowMs`, at most one per
     * alarm, in upcoming()'s order. nextOccurrence() answers "at or
     * after", so passing it a floor in the past yields occurrences that are
     * already behind us — the mechanism the grace window is built on.
     */
    function _dueSince(floorMs: real, nowMs: real): var {
        return root.upcoming(floorMs).filter(e => e.at <= nowMs).map(e => ({
                    id: e.alarm.id,
                    alarm: e.alarm,
                    at: root._latestDueBefore(e.alarm, e.at, nowMs)
                })).filter(e => !root.hasFired(e.alarm, e.at));
    }

    // A shell that was down for days has several occurrences of a repeating
    // alarm behind it. Only the most recent one can still be worth ringing, and
    // settling it subsumes the older ones (hasFired compares <=), so walk
    // forward to it rather than ringing for a stale one and losing this
    // morning's. The bound is paranoia, not arithmetic.
    function _latestDueBefore(alarm: var, atMs: real, nowMs: real): real {
        let at = atMs;
        for (let i = 0; i < 500; i++) {
            const next = root.nextOccurrence(alarm, at + 60000);
            if (next < 0 || next > nowMs)
                break;
            at = next;
        }
        return at;
    }

    // Alarms the pipeline is already holding. Their occurrence has not been
    // settled yet — a snooze deliberately leaves lastOccurrence unwritten so the
    // chain can still end in a disarm — so this is what stops the poll
    // queueing the same alarm twice.
    function _liveIds(): var {
        const state = root._state;
        return [state.ringingId].concat(root._copyList(state.queued).map(e => e.id), root._copyList(state.snoozed).map(e => e.id));
    }

    /**
     * First poll after a start. Everything persisted was written by a shell that
     * is no longer running, so each live state re-earns its place against the
     * grace window. This and _dueSince() are the only two paths
     * that can produce a late ring.
     */
    function _recover(nowMs: real): void {
        const state = root._state;
        if (state.ringingId !== -1) {
            if (root.alarmById(state.ringingId) && root._withinGrace(state.ringingDueMs, nowMs)) {
                // a ring interrupted by a restart resumes, and its
                // auto-stop still counts from the original ring, because
                // ringingSinceMs was never a countdown.
                root.ringStarted(state.ringingId, state.ringingDueMs);
            } else {
                root._settle(state.ringingId, state.ringingDueMs, root.outcomeMissed, state.ringingSinceMs);
                root._stopRing(root.outcomeMissed);
            }
        }
        const queue = [];
        for (const entry of root._copyList(state.queued)) {
            if (!root.alarmById(entry.id))
                continue;
            if (root._withinGrace(entry.dueMs, nowMs))
                queue.push({
                    id: entry.id,
                    dueMs: entry.dueMs
                });
            else
                root._settle(entry.id, entry.dueMs, root.outcomeMissed, 0);
        }
        state.queued = queue;
        const snoozes = [];
        for (const entry of root._copyList(state.snoozed)) {
            if (!root.alarmById(entry.id))
                continue;
            // A snooze still ahead survives untouched: it is a wall-clock
            // target, so a restart can neither shorten nor lengthen it.
            // One that came round while the shell was down is judged like any
            // other late moment.
            if (entry.untilMs > nowMs || root._withinGrace(entry.untilMs, nowMs))
                snoozes.push({
                    id: entry.id,
                    dueMs: entry.dueMs,
                    untilMs: entry.untilMs
                });
            else
                root._settle(entry.id, entry.dueMs, root.outcomeMissed, 0);
        }
        state.snoozed = snoozes;
    }

    function _poll(nowMs: real): void {
        const state = root._state;
        if (!root.pollActive || !state)
            return;

        if (!root._recovered) {
            root._recovered = true;
            root._recover(nowMs);
        }

        // Also what stops a queue waiting forever behind someone who is
        // not home. Applies to a post-snooze ring identically — this does
        // not care how the ring started.
        if (state.ringingId !== -1 && (nowMs - state.ringingSinceMs) >= root._autoStopMs()) {
            root._settle(state.ringingId, state.ringingDueMs, root.outcomeMissed, state.ringingSinceMs);
            root._stopRing(root.outcomeMissed);
        }

        // A snooze that has come round joins the queue like any other due
        // moment, carrying the occurrence it is still serving.
        const stillSnoozed = [];
        for (const entry of root._copyList(state.snoozed)) {
            if (entry.untilMs > nowMs) {
                stillSnoozed.push(entry);
                continue;
            }
            if (!root.alarmById(entry.id))
                continue;
            if (root._withinGrace(entry.untilMs, nowMs))
                root._enqueue(entry.id, entry.dueMs);
            else
                root._settle(entry.id, entry.dueMs, root.outcomeMissed, 0);
        }
        state.snoozed = stillSnoozed;

        // Occurrences that fell due since the last look. On the first poll after
        // a start that floor is the persisted one, so it spans the whole time
        // the shell was away and the grace window gets its say.
        const floorMs = state.lastPollMs > 0 ? state.lastPollMs : nowMs;
        const live = root._liveIds();
        for (const entry of root._dueSince(floorMs, nowMs)) {
            if (live.includes(entry.id))
                continue;
            if (root._withinGrace(entry.at, nowMs))
                root._enqueue(entry.id, entry.at);
            else
                root._settle(entry.id, entry.at, root.outcomeMissed, 0);
        }

        root._drain(nowMs);
        state.lastPollMs = nowMs;
    }

    /**
     * Stop the ring and record it as handled. Returns false if that alarm
     * is not the one ringing, so a stale surface cannot dismiss its successor.
     */
    function dismissAlarm(id: int): bool {
        const state = root._state;
        if (!state || id === -1 || state.ringingId !== id)
            return false;
        const nowMs = Date.now();
        root._settle(id, state.ringingDueMs, root.outcomeDismissed, nowMs);
        root._stopRing(root.outcomeDismissed);
        root._drain(nowMs);
        return true;
    }

    /**
     * The re-ring is stored as a wall-clock target measured from this
     * press, never as remaining seconds, so a restart in between changes
     * nothing. Unlimited: nothing here counts snoozes.
     *
     * The occurrence is deliberately NOT settled. A one-time alarm snoozed
     * rather than dismissed is not yet disarmed — the
     * disarm belongs to whatever ends the chain — and the alarm's own schedule
     * is untouched, so a daily alarm snoozed at 07:00 still has tomorrow 07:00.
     */
    function snoozeAlarm(id: int): bool {
        const state = root._state;
        if (!state || id === -1 || state.ringingId !== id)
            return false;
        const alarm = root.alarmById(id);
        if (!alarm)
            return false;
        const nowMs = Date.now();
        const untilMs = nowMs + Math.max(1, root.resolveSnoozeMinutes(alarm)) * 60000;
        const snoozes = root._copyList(state.snoozed).filter(e => e.id !== id);
        snoozes.push({
            id: id,
            dueMs: state.ringingDueMs,
            untilMs: untilMs
        });
        state.snoozed = snoozes;
        root._stopRing("snoozed");
        root._drain(nowMs);
        return true;
    }

    /**
     * Drop every live state this alarm holds, without settling it — the hook
     *  need: editing, disarming or deleting an alarm that is ringing,
     * queued or snoozed must leave nothing sounding under settings that no
     * longer exist. Returns true if anything was actually live.
     */
    function cancelAlarm(id: int): bool {
        const state = root._state;
        if (!state)
            return false;
        let touched = false;
        if (state.ringingId === id) {
            root._stopRing("cancelled");
            touched = true;
        }
        const queue = root._copyList(state.queued);
        const remaining = queue.filter(e => e.id !== id);
        if (remaining.length !== queue.length) {
            state.queued = remaining;
            touched = true;
        }
        const snoozes = root._copyList(state.snoozed);
        const stillSnoozed = snoozes.filter(e => e.id !== id);
        if (stillSnoozed.length !== snoozes.length) {
            state.snoozed = stillSnoozed;
            touched = true;
        }
        if (touched)
            root._drain(Date.now());
        return touched;
    }

    function _pollNow(): void {
        root._poll(Date.now());
    }

    // Deferred, not immediate: this fires from inside the FileView's own load
    // callback, and a poll that settles an alarm writes that file straight back.
    onPollActiveChanged: if (root.pollActive)
        Qt.callLater(root._pollNow)

    Component.onCompleted: {
        // Land on the top of the minute and stay there; a faster tick
        // buys nothing when minute granularity is the promise.
        alignTimer.interval = root.pollIntervalMs - (Date.now() % root.pollIntervalMs);
        alignTimer.start();
        if (root.pollActive)
            Qt.callLater(root._pollNow);
    }

    Timer {
        id: alignTimer
        repeat: false
        onTriggered: {
            root._poll(Date.now());
            pollTimer.start();
        }
    }

    Timer {
        id: pollTimer
        interval: root.pollIntervalMs
        repeat: true
        onTriggered: root._poll(Date.now())
    }
    // -------------------------------------------------------------------------

    function saveToFile(): void {
        if (!root.loaded) {
            console.warn("[Alarms] Refusing to save before the file has loaded");
            return;
        }
        alarmsFileView.setText(JSON.stringify({
            nextId: root.nextId,
            alarms: root.list
        }, null, 2));
    }

    function loadFromFile(): void {
        alarmsFileView.reload();
    }

    // Scripting surface. Deliberately small: the six things worth binding a key
    // to or driving from a script. Everything richer (per-alarm sound, snooze
    // override, repeat sets, dates) belongs to the editor, where the choices are
    // discoverable — an IPC flag for each would be a second, worse UI.
    //
    // Every function returns a string: a one-line result for the shell, JSON for
    // list. A refusal is a message, never a silent no-op, because the caller has
    // no other way to find out.
    IpcHandler {
        target: "alarms"

        // Every alarm with what the pipeline currently holds it in and when it
        // will actually next ring — upcomingRings(), so a pending snooze shows
        // as the snooze, not as tomorrow's scheduled slot.
        function list(): string {
            const nowMs = Date.now();
            const rings = {};
            for (const entry of root.upcomingRings(nowMs))
                rings[entry.alarm.id] = entry;
            return JSON.stringify(root.list.map(alarm => {
                const ring = rings[alarm.id];
                return Object.assign({}, alarm, {
                    state: root.alarmState(alarm.id),
                    nextRingMs: ring ? ring.at : -1,
                    nextRing: ring ? new Date(ring.at).toISOString() : "",
                    snoozed: ring ? ring.snoozed : false
                });
            }), null, 2);
        }

        /**
         * Create an armed next-occurrence alarm at "HH:MM" (24-hour, always —
         * an IPC argument is not a display and must not depend on the user's
         * time format). Range-checked here rather than left to _normalize's
         * clamp: a script asking for 25:00 has a bug, and silently arming 23:59
         * hides it.
         */
        function add(time: string, name: string): string {
            const parts = /^(\d{1,2}):(\d{2})$/.exec(String(time ?? "").trim());
            if (!parts)
                return "usage: alarms add HH:MM <name> (24-hour; pass \"\" for the default name)";
            const hour = Number(parts[1]);
            const minute = Number(parts[2]);
            if (hour > 23 || minute > 59)
                return "time out of range: hours 0-23, minutes 0-59";
            const id = root.addAlarm(hour, minute, String(name ?? ""), {});
            if (id === -1)
                return root.lastScheduleError !== "" ? root.lastScheduleError : "could not add alarm";
            return "added alarm " + id;
        }

        function remove(id: int): string {
            return root.removeAlarm(id) ? "removed alarm " + id : "no alarm " + id;
        }

        function arm(id: int): string {
            if (!root.alarmById(id))
                return "no alarm " + id;
            if (root.updateAlarm(id, {
                enabled: true
            }))
                return "armed alarm " + id;
            // re-arming is where a dated alarm whose date has passed is
            // finally refused, so this is a real outcome, not a missing record.
            return root.lastScheduleError !== "" ? root.lastScheduleError : "could not arm alarm " + id;
        }

        function disarm(id: int): string {
            if (!root.alarmById(id))
                return "no alarm " + id;
            root.updateAlarm(id, {
                enabled: false
            });
            return "disarmed alarm " + id;
        }

        // No id argument on either: exactly one alarm rings at a time, so the
        // ringing one is never ambiguous, and a keybind cannot know an id.
        function dismiss(): string {
            const id = root.ringingId;
            return root.dismissAlarm(id) ? "dismissed alarm " + id : "nothing is ringing";
        }

        function snooze(): string {
            const id = root.ringingId;
            if (!root.snoozeAlarm(id))
                return "nothing is ringing";
            const entry = root.snoozed.find(e => e.id === id);
            return "snoozed alarm " + id + " until " + (entry ? new Date(entry.untilMs).toISOString() : "?");
        }
    }
}
