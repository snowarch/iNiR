#!/usr/bin/env node
// Self-check for the alarm sound fallback chain (BR-8's second hop, BR-16).
//
// _urlsFor() and _chainFor() are pure JS living inside services/AlarmAudio.qml;
// this pulls them straight out of that file and runs them, so there is exactly
// one copy of the resolution rules and this check cannot drift from them. What
// it actually guards is the promise that an alarm never goes silent because of
// a sound problem: every chain below has to end somewhere playable, whatever
// the user configured.
//
//   node scripts/alarm-audio-check.js

"use strict";

const fs = require("fs");
const path = require("path");

const QML = path.join(__dirname, "..", "services", "AlarmAudio.qml");
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

// The last-resort URL is read out of the QML too rather than restated, so a
// change to it fails here instead of quietly weakening the final rung.
const lastResortMatch = src.match(/readonly property string lastResortUrl:\s*"([^"]+)"/);
if (!lastResortMatch) throw new Error(`lastResortUrl not found in ${QML}`);
const LAST_RESORT = lastResortMatch[1];

// What the extracted bodies reference.
const Config = { options: { sounds: { events: { alarmDone: "" } } } };
const Audio = { audioTheme: "freedesktop", soundEvents: { alarmDone: "alarm-clock-elapsed" } };
const root = { lastResortUrl: LAST_RESORT };
for (const name of ["_urlsFor", "_chainFor"]) {
    const { params, body } = extract(name);
    root[name] = new Function("root", "Config", "Audio",
        `return function ${name}(${params.join(",")}) {${body}};`)(root, Config, Audio);
}

const themeUrl = (name, ext) => `file:///usr/share/sounds/${Audio.audioTheme}/stereo/${name}.${ext}`;

// ---- Tiny assert harness ---------------------------------------------------

let failures = 0, checks = 0;
const assert = (cond, what) => {
    checks++;
    if (!cond) { failures++; console.error(`  FAIL  ${what}`); }
};
const same = (got, want, what) =>
    assert(JSON.stringify(got) === JSON.stringify(want),
        `${what}\n          got  ${JSON.stringify(got)}\n          want ${JSON.stringify(want)}`);

const section = (s) => console.log(`\n${s}`);

// ---- The three input shapes Audio.playEvent() recognises -------------------

section("sound value shapes (same rules as Audio.playEvent)");
{
    same(root._urlsFor(""), [], "an empty value contributes nothing");
    same(root._urlsFor("bell"), [themeUrl("bell", "oga"), themeUrl("bell", "ogg")],
        "a bare name is a theme sound, .oga then .ogg");
    same(root._urlsFor("/home/u/ring.wav"), ["file:///home/u/ring.wav"],
        "an absolute path is played directly");
    same(root._urlsFor("file:///home/u/ring.wav"), ["file:///home/u/ring.wav"],
        "a file:// URL is passed through unchanged");
    assert(!root._urlsFor("/home/u/ring.wav")[0].startsWith("file://file://"),
        "an absolute path is not double-prefixed");
}

// ---- BR-16: per-alarm -> global default -> anything that works -------------

section("fallback chain (BR-16)");
{
    // Default install: no per-alarm sound, no global override. AlarmService
    // .resolveSound() hands "" through, and the theme default carries it.
    same(root._chainFor(""),
        [themeUrl("alarm-clock-elapsed", "oga"), themeUrl("alarm-clock-elapsed", "ogg")],
        "the default install resolves to the theme's alarm sound");

    // The per-alarm override leads, and the default follows it as the fallback.
    same(root._chainFor("/gone/custom.oga"),
        ["file:///gone/custom.oga",
            themeUrl("alarm-clock-elapsed", "oga"), themeUrl("alarm-clock-elapsed", "ogg")],
        "a per-alarm sound leads, the default follows behind it");

    Config.options.sounds.events.alarmDone = "/gone/global.oga";
    // The last resort is the same file as the theme rung while the theme is the
    // base one, so it dedupes away — a rung that already failed is not worth
    // retrying.
    same(root._chainFor("/gone/custom.oga"),
        ["file:///gone/custom.oga", "file:///gone/global.oga",
            themeUrl("alarm-clock-elapsed", "oga"), themeUrl("alarm-clock-elapsed", "ogg")],
        "a broken global default is still only the second hop, not the last");

    Audio.audioTheme = "brokentheme";
    const chain = root._chainFor("/gone/custom.oga");
    assert(chain[chain.length - 1] === LAST_RESORT,
        "with theme, global and per-alarm all broken the chain still ends somewhere real");
    Audio.audioTheme = "freedesktop";
    Config.options.sounds.events.alarmDone = "";
}

section("every chain ends somewhere playable");
{
    // The one property that BR-16 actually promises. If any input can produce a
    // chain whose last rung is not the base-theme file, an alarm can go silent.
    for (const sound of ["", "bell", "/gone/x.oga", "file:///gone/x.oga", "alarm-clock-elapsed"]) {
        const chain = root._chainFor(sound);
        assert(chain.length > 0, `chain for ${JSON.stringify(sound)} is not empty`);
        assert(chain.includes(LAST_RESORT) || chain.includes(themeUrl("alarm-clock-elapsed", "oga")),
            `chain for ${JSON.stringify(sound)} reaches a base-theme sound`);
        assert(new Set(chain).size === chain.length,
            `chain for ${JSON.stringify(sound)} has no duplicate rung to retry`);
        assert(chain.every(u => u.startsWith("file://")),
            `every rung of the chain for ${JSON.stringify(sound)} is a file URL`);
    }
}

// ---- Report ----------------------------------------------------------------

console.log(`\n${checks - failures}/${checks} checks passed`);
process.exit(failures === 0 ? 0 : 1);
