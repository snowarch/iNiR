#!/usr/bin/env node
// Self-check for the AlarmService scheduling engine (BR-1, BR-10, BR-18, BR-19).
//
// The functions under test are pure JS living inside services/AlarmService.qml;
// this pulls them straight out of that file and runs them, so there is exactly
// one copy of the scheduling arithmetic and this check cannot drift from it.
// Every case injects `fromMs` instead of reading the wall clock, so midnight,
// weekday and DST boundaries are all verifiable right now.
//
//   node scripts/alarm-schedule-check.js

"use strict";

// Fixed zone for the whole run: America/New_York has both DST transitions and
// the results below are hand-derived against it. Set before any Date is built.
process.env.TZ = "America/New_York";

const fs = require("fs");
const path = require("path");

const QML = path.join(__dirname, "..", "services", "AlarmService.qml");
const src = fs.readFileSync(QML, "utf8");

// ---- Pull the functions out of the QML ------------------------------------

function extract(name) {
    const start = src.indexOf(`function ${name}(`);
    if (start === -1) throw new Error(`${name}() not found in ${QML}`);
    const open = src.indexOf("(", start);
    let i = open, depth = 0, close = -1;
    for (; i < src.length; i++) {
        if (src[i] === "(") depth++;
        else if (src[i] === ")" && --depth === 0) { close = i; break; }
    }
    // "alarm: var, fromMs: real" -> ["alarm", "fromMs"]
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

// `root` and `Translation` are what the extracted bodies reference.
const Translation = { tr: (s) => s };
const root = {
    modeNext: "next", modeRepeat: "repeat", modeDate: "date",
    dateHorizonYears: 1,
    list: [],
};
for (const name of ["_occurrenceMs", "nextOccurrence", "upcoming", "hasFired", "validateSchedule"]) {
    const { params, body } = extract(name);
    root[name] = new Function("root", "Translation", `return function ${name}(${params.join(",")}) {${body}};`)(root, Translation);
}

// ---- Tiny assert harness ---------------------------------------------------

let failures = 0, checks = 0;
const assert = (cond, what) => {
    checks++;
    if (!cond) { failures++; console.error(`  FAIL  ${what}`); }
};
const local = (y, mo, d, h, mi) => new Date(y, mo - 1, d, h, mi, 0, 0).getTime();
const show = (ms) => ms < 0 ? "never" : new Date(ms).toString().slice(0, 24);
const at = (ms, expected, what) =>
    assert(ms === expected, `${what}\n          got ${show(ms)}\n          want ${show(expected)}`);

const alarm = (o) => Object.assign({
    id: 1, name: "", hour: 7, minute: 0, enabled: true,
    repeatDays: 0, date: "", lastOccurrence: 0
}, o);

const section = (s) => console.log(`\n${s}`);

// ---- BR-1: next-occurrence mode (TC-004) -----------------------------------

section("next-occurrence mode (BR-1, TC-004)");
{
    const now = local(2026, 7, 25, 14, 0); // Saturday 14:00
    at(root.nextOccurrence(alarm({ hour: 18, minute: 0 }), now),
        local(2026, 7, 25, 18, 0), "later today stays today");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0 }), now),
        local(2026, 7, 26, 9, 0), "earlier today rolls to tomorrow");
    at(root.nextOccurrence(alarm({ hour: 14, minute: 0 }), now),
        local(2026, 7, 25, 14, 0), "exactly now counts as still due");
    at(root.nextOccurrence(alarm({ hour: 14, minute: 0 }), now + 1),
        local(2026, 7, 26, 14, 0), "one ms past rolls to tomorrow");
    at(root.nextOccurrence(alarm({ hour: 18, minute: 0, enabled: false }), now),
        -1, "a disarmed alarm has no next occurrence");
}

// ---- BR-10 / TC-026: midnight and current-minute determinism ---------------

section("midnight rollover and determinism (BR-10, TC-026)");
{
    // 00:00 on the day it was created, half a minute in: the *next* occurrence
    // is the following day, never the one that just passed.
    at(root.nextOccurrence(alarm({ hour: 0, minute: 0 }), local(2026, 7, 25, 0, 0) + 30000),
        local(2026, 7, 26, 0, 0), "00:00 half a minute past rolls to the following day");
    at(root.nextOccurrence(alarm({ hour: 0, minute: 0 }), local(2026, 7, 25, 23, 59)),
        local(2026, 7, 26, 0, 0), "00:00 late in the evening is tomorrow");
    at(root.nextOccurrence(alarm({ hour: 0, minute: 0 }), local(2026, 7, 25, 0, 0)),
        local(2026, 7, 25, 0, 0), "00:00 at exactly 00:00 is now");

    // Created for the exact current minute, 20s in: same answer every time.
    const created = local(2026, 7, 25, 14, 30) + 20000;
    const answers = new Set();
    for (let i = 0; i < 50; i++) answers.add(root.nextOccurrence(alarm({ hour: 14, minute: 30 }), created));
    assert(answers.size === 1, "current-minute alarm resolves identically on every call");
    at([...answers][0], local(2026, 7, 26, 14, 30), "current minute already begun resolves to tomorrow");
}

section("same-minute stable order (BR-10, TC-026 steps 3-6)");
{
    const now = local(2026, 7, 25, 6, 0);
    // Deliberately out of id order in the list, and one of them is later.
    root.list = [alarm({ id: 9, hour: 7, minute: 0 }), alarm({ id: 2, hour: 7, minute: 0 }),
        alarm({ id: 5, hour: 7, minute: 0 }), alarm({ id: 4, hour: 8, minute: 0 })];
    const order = root.upcoming(now).map(e => e.alarm.id);
    assert(JSON.stringify(order) === JSON.stringify([2, 5, 9, 4]),
        `same-minute alarms order by id, later minute last (got ${order})`);
    // BR-11: identical times are not deduplicated.
    assert(root.upcoming(now).length === 4, "identical times all survive, nothing merged");
    // Disarmed drops out, everything else keeps its order.
    root.list = root.list.map(a => a.id === 5 ? Object.assign({}, a, { enabled: false }) : a);
    assert(JSON.stringify(root.upcoming(now).map(e => e.alarm.id)) === JSON.stringify([2, 9, 4]),
        "a disarmed alarm leaves the upcoming list");
    root.list = [];
}

// ---- BR-1: repeating mode (TC-005) -----------------------------------------

const DAY = { Sun: 1, Mon: 2, Tue: 4, Wed: 8, Thu: 16, Fri: 32, Sat: 64 };

section("repeating mode (BR-1, TC-005)");
{
    // 2026-07-28 is a Tuesday.
    const tue = local(2026, 7, 28, 10, 0);
    assert(new Date(tue).getDay() === 2, "fixture day really is a Tuesday");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: DAY.Mon | DAY.Thu }), tue),
        local(2026, 7, 30, 9, 0), "Mon+Thu from a Tuesday picks Thursday, not Monday");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: DAY.Mon | DAY.Wed | DAY.Thu }), tue),
        local(2026, 7, 29, 9, 0), "adding Wednesday moves it earlier");
    at(root.nextOccurrence(alarm({ hour: 11, minute: 0, repeatDays: DAY.Tue }), tue),
        local(2026, 7, 28, 11, 0), "today counts when the time is still ahead");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: DAY.Tue }), tue),
        local(2026, 8, 4, 9, 0), "today already past rolls a full week to the same weekday");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: 0x7F }), tue),
        local(2026, 7, 29, 9, 0), "all seven days, time past, is tomorrow");
    at(root.nextOccurrence(alarm({ hour: 11, minute: 0, repeatDays: 0x7F }), tue),
        local(2026, 7, 28, 11, 0), "all seven days, time ahead, is today");
    // Repeating never disarms itself: after Thursday's ring it rolls forward.
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: DAY.Mon | DAY.Thu }), local(2026, 7, 30, 9, 1)),
        local(2026, 8, 3, 9, 0), "after Thursday's ring it rolls to Monday");
    // Sunday is bit 0 — the bitmask convention itself.
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, repeatDays: DAY.Sun }), tue),
        local(2026, 8, 2, 9, 0), "bit 0 means Sunday");
}

// ---- BR-1: dated mode (TC-006) ---------------------------------------------

section("dated mode (BR-1, TC-006)");
{
    const now = local(2026, 7, 25, 14, 0);
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "2026-08-15" }), now),
        local(2026, 8, 15, 9, 0), "fires on its date");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "2026-07-24" }), now),
        -1, "a date already gone never fires again");
    at(root.nextOccurrence(alarm({ hour: 18, minute: 0, date: "2026-07-25" }), now),
        local(2026, 7, 25, 18, 0), "today's date later today");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "2026-07-25" }), now),
        -1, "today's date already past does not roll to tomorrow");
    // The poll (Task 4 grace window) asks from when it last looked and must
    // still see an occurrence that has since gone by.
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "2026-07-25" }), local(2026, 7, 25, 8, 55)),
        local(2026, 7, 25, 9, 0), "an occurrence between two polls is still reported");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "not-a-date" }), now),
        -1, "a malformed date never fires");
}

// ---- BR-18: mode exclusivity (TC-007) --------------------------------------

section("mode exclusivity (BR-18, TC-007)");
{
    const now = local(2026, 7, 28, 10, 0); // Tuesday
    // A record that somehow carries both resolves as dated, deterministically,
    // and never as some blend of the two.
    const both = alarm({ hour: 9, minute: 0, date: "2026-08-15", repeatDays: DAY.Mon | DAY.Wed });
    at(root.nextOccurrence(both, now), local(2026, 8, 15, 9, 0), "date wins over a stray repeat set");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "", repeatDays: DAY.Wed }), now),
        local(2026, 7, 29, 9, 0), "clearing the date leaves a repeating alarm");
    at(root.nextOccurrence(alarm({ hour: 9, minute: 0, date: "", repeatDays: 0 }), now),
        local(2026, 7, 29, 9, 0), "clearing both returns to next-occurrence mode");
}

// ---- BR-19: validation (TC-016) --------------------------------------------

section("validation (BR-19, TC-016)");
{
    const now = local(2026, 7, 25, 14, 0);
    const bad = (a, what) => {
        const r = root.validateSchedule(a, now);
        assert(!r.valid && r.reason !== "", `${what} (reason: ${JSON.stringify(r.reason)})`);
    };
    const ok = (a, what) => {
        const r = root.validateSchedule(a, now);
        assert(r.valid && r.reason === "", `${what} — unexpectedly refused: ${r.reason}`);
    };

    bad(alarm({ hour: 9, minute: 0, date: "2026-07-24" }), "step 1: yesterday is refused with a reason");
    bad(alarm({ hour: 13, minute: 0, date: "2026-07-25" }), "step 2: today already past is refused with a reason");
    ok(alarm({ hour: 14, minute: 1, date: "2026-07-25" }), "step 3: today plus one minute is accepted");
    ok(alarm({ hour: 14, minute: 0, date: "2026-07-25" }), "the saving minute itself is accepted");
    // Steps 5 and 6: the modes that resolve forward must never be rejected,
    // however far in the past their clock time is.
    ok(alarm({ hour: 0, minute: 0 }), "step 5: next-occurrence at a time long past is accepted");
    ok(alarm({ hour: 0, minute: 0, repeatDays: DAY.Mon }), "step 6: repeating at a time long past is accepted");
    ok(alarm({ hour: 9, minute: 0, date: "2026-07-24", enabled: false }),
        "a disarmed alarm may keep a past date (BR-3)");

    // Owner decision: one year ahead, refused through the same path.
    ok(alarm({ hour: 9, minute: 0, date: "2027-07-20" }), "just inside a year ahead is accepted");
    bad(alarm({ hour: 9, minute: 0, date: "2027-07-26" }), "beyond a year ahead is refused with a reason");
    const far = root.validateSchedule(alarm({ hour: 9, minute: 0, date: "2027-07-26" }), now);
    const past = root.validateSchedule(alarm({ hour: 9, minute: 0, date: "2026-07-24" }), now);
    assert(far.reason !== past.reason, "the horizon and the past give different explanations");
}

// ---- DST (TC-027) ----------------------------------------------------------

section("DST transitions (TC-027, owner decision)");
{
    // Spring forward: 2026-03-08, 02:00 EST -> 03:00 EDT. 02:00-02:59 vanishes.
    const beforeSpring = local(2026, 3, 7, 12, 0);
    const shiftInstant = Date.UTC(2026, 2, 8, 7, 0); // 02:00 EST == 03:00 EDT
    at(root.nextOccurrence(alarm({ hour: 2, minute: 30 }), beforeSpring), shiftInstant,
        "a skipped 02:30 fires at the shift instant, rendering 03:00");
    assert(new Date(root.nextOccurrence(alarm({ hour: 2, minute: 30 }), beforeSpring)).getHours() === 3,
        "and it really renders as 03:00 local");
    at(root.nextOccurrence(alarm({ hour: 2, minute: 0 }), beforeSpring), shiftInstant,
        "02:00 exactly also lands on the shift instant");
    at(root.nextOccurrence(alarm({ hour: 1, minute: 30 }), beforeSpring),
        local(2026, 3, 8, 1, 30), "01:30 is untouched by the shift");
    at(root.nextOccurrence(alarm({ hour: 3, minute: 30 }), beforeSpring),
        local(2026, 3, 8, 3, 30), "03:30 is untouched by the shift");

    // Once, not twice: the occurrence lands in one minute, so a poll that has
    // recorded it will not serve it again.
    const skipped = alarm({ hour: 2, minute: 30, lastOccurrence: shiftInstant });
    assert(root.hasFired(skipped, root.nextOccurrence(skipped, beforeSpring)),
        "the shifted occurrence is recognised as already fired");
    at(root.nextOccurrence(alarm({ hour: 2, minute: 30 }), shiftInstant + 1),
        local(2026, 3, 9, 2, 30), "the day after the shift, 02:30 exists again");

    // Fall back: 2026-11-01, 02:00 EDT -> 01:00 EST. 01:00-01:59 happens twice.
    const beforeFall = local(2026, 10, 31, 12, 0);
    const firstOneThirty = Date.UTC(2026, 10, 1, 5, 30); // 01:30 EDT
    const secondOneThirty = Date.UTC(2026, 10, 1, 6, 30); // 01:30 EST
    at(root.nextOccurrence(alarm({ hour: 1, minute: 30 }), beforeFall), firstOneThirty,
        "a repeated 01:30 resolves to the first one");
    // The second 01:30 must not re-trigger the occurrence already served. This
    // is exactly why the guard is keyed on the occurrence, not the clock time.
    const repeated = alarm({ hour: 1, minute: 30, lastOccurrence: firstOneThirty });
    assert(root.hasFired(repeated, root.nextOccurrence(repeated, beforeFall)),
        "the served 01:30 counts as fired");
    at(root.nextOccurrence(repeated, secondOneThirty), local(2026, 11, 2, 1, 30),
        "asking again during the repeated hour gives the next day, not a second 01:30");
    assert(!root.hasFired(repeated, root.nextOccurrence(repeated, secondOneThirty)),
        "and the next day's occurrence is not suppressed by the guard");
}

// ---- fired-once guard ------------------------------------------------------

section("fired-once guard");
{
    const occ = local(2026, 7, 26, 7, 0);
    assert(!root.hasFired(alarm({}), occ), "never fired means not fired");
    assert(root.hasFired(alarm({ lastOccurrence: occ }), occ), "the same occurrence is fired");
    assert(!root.hasFired(alarm({ lastOccurrence: occ }), occ + 86400000), "a later occurrence is not");
    assert(root.hasFired(alarm({ lastOccurrence: occ }), occ - 3600000),
        "an earlier occurrence counts as served — a clock moved back cannot resurrect it");
    assert(!root.hasFired(alarm({ lastOccurrence: occ }), -1), "never-fires is not 'already fired'");
}

// ---------------------------------------------------------------------------

console.log(`\n${checks - failures}/${checks} checks passed (TZ=${process.env.TZ})`);
if (failures) { console.error(`${failures} FAILED`); process.exit(1); }
