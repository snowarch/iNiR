#!/usr/bin/env node
// Self-check for the time picker's 12/24-hour arithmetic (BR-9, TC-023).
//
// The four conversion functions are pure JS living inside
// modules/common/widgets/TimeWheel.qml; this pulls them straight out of that
// file and runs them, so there is exactly one copy of the arithmetic and this
// check cannot drift from the picker. The trap this exists for is midnight and
// noon: 12:00 AM must store hour 0 and 12:00 PM must store hour 12, and no
// stored hour may move by twelve when the display format changes.
//
//   node scripts/alarm-timewheel-check.js

"use strict";

const fs = require("fs");
const path = require("path");

const QML = path.join(__dirname, "..", "modules", "common", "widgets", "TimeWheel.qml");
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
    // "h12: int, isPm: bool" -> ["h12", "isPm"]
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

// `root` is what the extracted bodies reference; each function is attached
// before the next one is built, so hourFromIndex finds root.from12.
const root = {};
for (const name of ["to12", "from12", "hourIndex", "hourFromIndex"]) {
    const { params, body } = extract(name);
    root[name] = new Function("root", `return function ${name}(${params.join(",")}) {${body}};`)(root);
}

// The label the 12-hour column shows at a row, taken from the same expression
// the QML builds its model with, so a relabelled column fails here too.
const labels12 = /hourLabels12:[\s\S]*?length: (\d+)[\s\S]*?\}, \(ignored, i\) => (.*?)\)\n/.exec(src);
if (!labels12) throw new Error("hourLabels12 model not found in " + QML);
const label12 = new Function("i", `return ${labels12[2]};`);
const columnRows = Number(labels12[1]);

// ---- Tiny assert harness ---------------------------------------------------

let failures = 0, checks = 0;
const assert = (cond, what) => {
    checks++;
    if (!cond) { failures++; console.error(`  FAIL  ${what}`); }
};
const eq = (got, want, what) =>
    assert(got === want, `${what}\n          got ${JSON.stringify(got)}\n          want ${JSON.stringify(want)}`);
const section = (s) => console.log(`\n${s}`);

// ---- The midnight/noon trap (TC-023 step 5) --------------------------------

section("midnight and noon (BR-9, TC-023 step 5)");
{
    eq(root.from12(12, false), 0, "12:00 AM stores hour 0, not 12");
    eq(root.from12(12, true), 12, "12:00 PM stores hour 12, not 0 and not 24");
    eq(root.to12(0).h12, 12, "hour 0 displays as 12");
    eq(root.to12(0).pm, false, "hour 0 displays as AM");
    eq(root.to12(12).h12, 12, "hour 12 displays as 12");
    eq(root.to12(12).pm, true, "hour 12 displays as PM");
    // The column route, not just the raw pair: row 0 is the twelve.
    eq(root.hourIndex(0), 0, "midnight sits on the first row");
    eq(root.hourIndex(12), 0, "noon sits on the same first row");
    eq(root.hourFromIndex(0, false), 0, "first row + AM is midnight");
    eq(root.hourFromIndex(0, true), 12, "first row + PM is noon");
}

// ---- No hour ever shifts by twelve (TC-023 steps 2-4) ----------------------

section("format is presentation only (BR-9, TC-023 steps 2-4)");
for (let h = 0; h < 24; h++) {
    const shown = root.to12(h);
    eq(root.from12(shown.h12, shown.pm), h, `hour ${h} survives a 24 -> 12 -> 24 round trip`);
    // And the same trip through the actual column geometry.
    eq(root.hourFromIndex(root.hourIndex(h), h >= 12), h,
        `hour ${h} survives the column's own row mapping`);
    assert(shown.h12 >= 1 && shown.h12 <= 12, `hour ${h} displays inside 1-12 (got ${shown.h12})`);
    // 7:00 AM must never come back as 19:00 (TC-023 step 4).
    assert(root.from12(shown.h12, shown.pm) !== (h + 12) % 24,
        `hour ${h} does not come back twelve hours out`);
}

// ---- The column shows what the arithmetic says (TC-023 steps 1-2) ----------

section("column labels match the arithmetic");
{
    eq(columnRows, 12, "the 12-hour column has twelve rows, not twenty-four");
    for (let h = 0; h < 24; h++) {
        eq(String(label12(root.hourIndex(h))), String(root.to12(h).h12),
            `hour ${h} is labelled with its own 12-hour value`);
    }
    // Every row is reachable and lands on a distinct hour in each meridiem.
    const am = new Set(), pm = new Set();
    for (let i = 0; i < columnRows; i++) {
        am.add(root.hourFromIndex(i, false));
        pm.add(root.hourFromIndex(i, true));
    }
    eq(am.size, 12, "the twelve AM rows give twelve distinct hours");
    eq(pm.size, 12, "the twelve PM rows give twelve distinct hours");
    eq([...am, ...pm].sort((a, b) => a - b).join(","),
        Array.from({ length: 24 }, (ignored, i) => i).join(","),
        "AM plus PM covers all 24 stored hours exactly once");
}

// ---------------------------------------------------------------------------

console.log(`\n${checks - failures}/${checks} checks passed`);
if (failures) { console.error(`${failures} FAILED`); process.exit(1); }
