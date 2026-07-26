#!/usr/bin/env node
// Self-check for the live-alarm teardown guard (BR-12, BR-13, BR-14) and the
// firing transitions that must survive it.
//
// "No sound outlives its alarm" is enforced in ONE place — updateAlarm() calls
// cancelAlarm() unless the pipeline is settling — precisely so no UI caller can
// bypass it. That is a single line whose whole value is that it fires for edits
// and does NOT fire for the pipeline's own bookkeeping write, so it is worth a
// check that would notice either half breaking.
//
// The functions are pulled straight out of services/AlarmService.qml, so this
// cannot drift from the implementation.
//
//   node scripts/alarm-teardown-check.js

"use strict";

const fs = require("fs");
const path = require("path");

const QML = path.join(__dirname, "..", "services", "AlarmService.qml");
const src = fs.readFileSync(QML, "utf8");

// Same extractor the sibling checks use: find `function name(`, take the
// parameter names without their QML types, then the balanced body.
function extract(name) {
    const start = src.indexOf(`function ${name}(`);
    if (start === -1) throw new Error(`${name}() not found in ${QML}`);
    const open = src.indexOf("(", start);
    let i = open, depth = 0, close = -1;
    for (; i < src.length; i++) {
        if (src[i] === "(") depth++;
        else if (src[i] === ")" && --depth === 0) { close = i; break; }
    }
    const params = src.slice(open + 1, close).split(",")
        .map(p => p.split(":")[0].trim()).filter(Boolean);
    const bodyStart = src.indexOf("{", close);
    depth = 0;
    let bodyEnd = -1;
    for (i = bodyStart; i < src.length; i++) {
        if (src[i] === "{") depth++;
        else if (src[i] === "}" && --depth === 0) { bodyEnd = i; break; }
    }
    return { params, body: src.slice(bodyStart + 1, bodyEnd) };
}

const EXTRACTED = [
    "_indexOf", "alarmById", "_copyList", "_touchesSchedule",
    "updateAlarm", "removeAlarm", "cancelAlarm",
    "_settle", "_startRing", "_stopRing", "_enqueue", "_drain",
    "dismissAlarm", "snoozeAlarm"
];

let events = [];
let root;

function freshRoot() {
    events = [];
    root = {
        modeNext: "next", modeRepeat: "repeat", modeDate: "date",
        outcomeNone: "none", outcomeDismissed: "dismissed", outcomeMissed: "missed",
        loaded: true,
        _settling: false,
        lastScheduleError: "",
        list: [],
        _state: { ringingId: -1, ringingDueMs: 0, ringingSinceMs: 0, queued: [], snoozed: [] },
        // Not under test here: the schedule engine (alarm-schedule-check.js),
        // persistence and Config lookups.
        _normalize: a => Object.assign({}, a),
        validateSchedule: () => ({ valid: true, reason: "" }),
        resolveSnoozeMinutes: () => 5,
        saveToFile: () => {},
        _log: () => {},
        alarmAdded: id => events.push(["added", id]),
        alarmRemoved: id => events.push(["removed", id]),
        alarmUpdated: id => events.push(["updated", id]),
        ringStarted: (id, dueMs) => events.push(["ringStarted", id, dueMs]),
        ringStopped: (id, reason) => events.push(["ringStopped", id, reason])
    };
    for (const name of EXTRACTED) {
        const { params, body } = extract(name);
        root[name] = new Function("root", `return function ${name}(${params.join(",")}) {${body}};`)(root);
    }
    return root;
}

function alarm(id, mode) {
    return { id, hour: 7, minute: 0, name: "", enabled: true, mode: mode ?? "next", repeatDays: 0, date: "", lastOccurrence: 0, lastOutcome: "none" };
}

let failures = 0, checks = 0;
const assert = (cond, what) => {
    checks++;
    if (!cond) { failures++; console.error(`  FAIL  ${what}`); }
};
const stops = () => events.filter(e => e[0] === "ringStopped");

const DUE = Date.parse("2024-03-01T07:00:00Z");

// ---- BR-12: editing a ringing alarm stops it -------------------------------
{
    freshRoot();
    root.list = [alarm(1)];
    root._startRing(1, DUE, DUE);
    root.updateAlarm(1, { name: "Renamed" });
    assert(root._state.ringingId === -1, "editing a ringing alarm stops the ring");
    assert(stops().length === 1 && stops()[0][2] === "cancelled", "the stop reason is 'cancelled', not an outcome");
    assert(root.alarmById(1).name === "Renamed", "the edit itself still lands");
    assert(root.alarmById(1).lastOutcome === "none", "a cancelled ring records no outcome");
}

// ---- BR-13: disarming a QUEUED alarm drops it from the queue ---------------
{
    freshRoot();
    root.list = [alarm(1), alarm(2)];
    root._startRing(1, DUE, DUE);
    root._enqueue(2, DUE);
    root.updateAlarm(2, { enabled: false });
    assert(root._copyList(root._state.queued).length === 0, "disarming a queued alarm removes it from the queue");
    assert(root._state.ringingId === 1, "and leaves the alarm that is actually ringing alone");
}

// ---- BR-12: editing a SNOOZED alarm drops the snooze -----------------------
{
    freshRoot();
    root.list = [alarm(1)];
    root._startRing(1, DUE, DUE);
    root.snoozeAlarm(1);
    assert(root._copyList(root._state.snoozed).length === 1, "snooze is recorded");
    root.updateAlarm(1, { hour: 8 });
    assert(root._copyList(root._state.snoozed).length === 0, "editing a snoozed alarm drops the snooze");
}

// ---- BR-14: deleting a ringing alarm stops it ------------------------------
{
    freshRoot();
    root.list = [alarm(1)];
    root._startRing(1, DUE, DUE);
    root.removeAlarm(1);
    assert(root._state.ringingId === -1, "deleting a ringing alarm stops the ring");
    assert(stops().length === 1, "exactly one stop, not one per teardown hook");
}

// ---- The guard must NOT eat the pipeline's own writes -----------------------
// _settle() writes lastOccurrence/lastOutcome and disarms a one-shot through
// updateAlarm. If that were read as an edit, dismiss would report "cancelled",
// the outcome would never reach the record, and the badge in the alarms list
// would be wrong for every alarm that ever fired.
{
    freshRoot();
    root.list = [alarm(1)];
    root._startRing(1, DUE, DUE);
    assert(root.dismissAlarm(1) === true, "dismiss succeeds");
    assert(stops().length === 1 && stops()[0][2] === "dismissed", "dismiss reports 'dismissed', not 'cancelled'");
    assert(root.alarmById(1).lastOutcome === "dismissed", "the outcome reaches the record");
    assert(root.alarmById(1).lastOccurrence === DUE, "the fired-once key reaches the record");
    assert(root.alarmById(1).enabled === false, "a one-time alarm disarms itself after firing");
    assert(root._settling === false, "the settling flag is cleared again");
}

// A repeat alarm settles without disarming, and the next queued alarm takes over.
{
    freshRoot();
    root.list = [alarm(1, "repeat"), alarm(2)];
    root._startRing(1, DUE, DUE);
    root._enqueue(2, DUE);
    root.dismissAlarm(1);
    assert(root.alarmById(1).enabled === true, "a repeating alarm stays armed after firing");
    assert(root._state.ringingId === 2, "the queue drains into the freed ring");
    assert(root._copyList(root._state.queued).length === 0, "and the queue is emptied");
}

// ---- BR-4 / TC-010: snooze defers the disarm, it does not cancel it ---------
{
    freshRoot();
    root.list = [alarm(1)];
    root._startRing(1, DUE, DUE);
    const before = Date.now();
    root.snoozeAlarm(1);
    const entry = root._copyList(root._state.snoozed)[0];
    assert(root.alarmById(1).enabled === true, "a snoozed one-time alarm is not disarmed yet");
    assert(root.alarmById(1).lastOutcome === "none", "and is not settled");
    assert(entry.dueMs === DUE, "the snooze keeps the original occurrence");
    assert(entry.untilMs >= before + 5 * 60000, "the re-ring is measured from the press, not from the due time");
    assert(root.alarmById(1).hour === 7 && root.alarmById(1).minute === 0, "the schedule itself is untouched");
    // Repeatable without limit: snoozing again replaces, never stacks.
    root._startRing(1, DUE, Date.now());
    root.snoozeAlarm(1);
    assert(root._copyList(root._state.snoozed).length === 1, "snoozing again replaces the entry rather than stacking");
}

// ---- Settling one alarm must not disturb another's live state --------------
{
    freshRoot();
    root.list = [alarm(1), alarm(2)];
    root._startRing(1, DUE, DUE);
    root._enqueue(2, DUE);
    root._settle(2, DUE, "missed", 0);
    assert(root._copyList(root._state.queued).length === 1, "settling does not tear down live state");
    assert(root._state.ringingId === 1, "and does not disturb the ring");
}

console.log(`\n${checks - failures}/${checks} checks passed`);
if (failures) { console.error(`${failures} FAILED`); process.exit(1); }
