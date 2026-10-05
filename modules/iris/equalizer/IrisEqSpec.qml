pragma Singleton

import QtQuick
import qs.services
import qs.modules.common

// The EasyEffects v8.3.0 parameter floor for the iRiS equalizer panel.
// Keys are PRESET-JSON kebab-case, exactly as IrisAudio.setParam expects.
// Ranges/defaults/units transcribed from the panel spec §3 (authoritative
// from wwmm/easyeffects @ v8.3.0 src/*_preset.cpp + kcfg).
//
// If the bridge ever returns a `spec` map, prefer it at the call site and
// keep this file as the fallback. Nothing here touches the engine.
QtObject {
    id: root

    // Band editor assumptions (NOT in the spec tables — EasyEffects UI
    // values). Flagged so they can be corrected against the bridge later.
    readonly property real bandGainMin: -24
    readonly property real bandGainMax: 24
    readonly property real bandQDefault: 4.36

    // Band type/mode vocabulary. These are the labels EasyEffects STORES, not
    // the ones its manual renders. The Equalizer stores "Hi-pass"/"Lo-shelf"/
    // "Allpass"; the manual shows "High Pass"/"Low Shelf"/"All Pass". The Filter
    // plugin carries a third set ("Low-pass"/"High-pass"/"All-pass") that also
    // exists in the same binary — do not cross-contaminate the three.
    //
    // Verified against the binary rather than the docs: EasyEffects does not
    // validate enums when you write them, so a write that appears to succeed
    // proves nothing. The daemon rejects any label absent from this list, so
    // these strings are the contract.
    readonly property var bandTypes: ["Off", "Bell", "Hi-pass", "Hi-shelf", "Lo-pass",
        "Lo-shelf", "Notch", "Resonance", "Allpass", "Bandpass", "Ladder-pass", "Ladder-rej"]
    readonly property var bandModes: ["RLC (BT)", "RLC (MT)", "BWC (BT)", "BWC (MT)",
        "LRX (BT)", "LRX (MT)", "APO (DR)"]
    // Gain does nothing for these types: EasyEffects disables its own gain
    // control for lo-pass, hi-pass and notch; Off disables the band.
    readonly property var bandTypesNoGain: ["Off", "Lo-pass", "Hi-pass", "Notch"]
    function bandGainInert(typeName: string): bool {
        return root.bandTypesNoGain.includes(String(typeName))
    }
    // BWC and LRX do not affect Resonance and Notch filters.
    function bandModeNulled(typeName: string): bool {
        const t = String(typeName)
        return t === "Resonance" || t === "Notch"
    }
    function bandModeDisabled(typeName: string, modeName: string): bool {
        if (!root.bandModeNulled(typeName)) return false
        const m = String(modeName)
        return m.indexOf("BWC") === 0 || m.indexOf("LRX") === 0
    }

    // Module cards in chain order: id, display label, glyph, one-line
    // detail shown beside the switch, and whether the card is special.
    readonly property var moduleOrder: [
        { id: "bass_enhancer", label: Translation.tr("Bass Enhancer"), glyph: "speaker", detail: Translation.tr("Low-end harmonics") },
        { id: "crystalizer", label: Translation.tr("Crystalizer"), glyph: "auto_awesome", detail: Translation.tr("Top-end lift, 13 bands"), special: "crystalizer" },
        { id: "exciter", label: Translation.tr("Exciter"), glyph: "bolt", detail: Translation.tr("Top-end harmonics") },
        { id: "limiter", label: Translation.tr("Limiter"), glyph: "compress", detail: Translation.tr("Ceiling for loud peaks") },
        { id: "autogain", label: Translation.tr("Autogain"), glyph: "graphic_eq", detail: Translation.tr("Even loudness (LUFS)") }
    ]

    function moduleMeta(id: string): var {
        for (const entry of root.moduleOrder) {
            if (entry.id === id) return entry
        }
        return { id: id, label: id, glyph: "tune", detail: "" }
    }

    // Each entry: { key, label, min, max, def, unit, kind }
    // kind is "slider" | "bool" | "enum" | "int". `simple` is the handful
    // shown without opening the disclosure; `advanced` hides behind it.
    // Limiter sidechain routing lives in advanced on purpose.
    readonly property var params: ({
        bass_enhancer: {
            simple: [
                { key: "amount", label: Translation.tr("Amount"), min: -100, max: 36, def: 0, unit: "dB", kind: "slider" },
                { key: "harmonics", label: Translation.tr("Harmonics"), min: 0.1, max: 10, def: 8.5, unit: "×", kind: "slider" },
                { key: "scope", label: Translation.tr("Scope"), min: 10, max: 250, def: 100, unit: "Hz", kind: "slider" }
            ],
            advanced: [
                { key: "floor", label: Translation.tr("Floor"), min: 10, max: 120, def: 20, unit: "Hz", kind: "slider" },
                { key: "floor-active", label: Translation.tr("Floor limit"), kind: "bool", def: false },
                { key: "blend", label: Translation.tr("Blend"), min: -10, max: 10, def: 0, unit: "", kind: "slider" },
                { key: "input-gain", label: Translation.tr("Input gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" },
                { key: "output-gain", label: Translation.tr("Output gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" }
            ]
        },
        exciter: {
            simple: [
                { key: "amount", label: Translation.tr("Amount"), min: -100, max: 36, def: 0, unit: "dB", kind: "slider" },
                { key: "harmonics", label: Translation.tr("Harmonics"), min: 0.1, max: 10, def: 8.5, unit: "×", kind: "slider" },
                { key: "scope", label: Translation.tr("Scope"), min: 2000, max: 12000, def: 7500, unit: "Hz", kind: "slider" }
            ],
            advanced: [
                { key: "ceil", label: Translation.tr("Ceiling"), min: 10000, max: 20000, def: 16000, unit: "Hz", kind: "slider" },
                { key: "ceil-active", label: Translation.tr("Ceiling limit"), kind: "bool", def: false },
                { key: "blend", label: Translation.tr("Blend"), min: -10, max: 10, def: 0, unit: "", kind: "slider" },
                { key: "input-gain", label: Translation.tr("Input gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" },
                { key: "output-gain", label: Translation.tr("Output gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" }
            ]
        },
        limiter: {
            simple: [
                { key: "threshold", label: Translation.tr("Threshold"), min: -48, max: 0, def: 0, unit: "dB", kind: "slider" },
                { key: "attack", label: Translation.tr("Attack"), min: 0.25, max: 20, def: 5, unit: "ms", kind: "slider" },
                { key: "release", label: Translation.tr("Release"), min: 0.25, max: 20, def: 5, unit: "ms", kind: "slider" },
                { key: "lookahead", label: Translation.tr("Lookahead"), min: 0.1, max: 20, def: 5, unit: "ms", kind: "slider" }
            ],
            advanced: [
                { key: "stereo-link", label: Translation.tr("Stereo link"), min: 0, max: 100, def: 100, unit: "%", kind: "slider" },
                { key: "gain-boost", label: Translation.tr("Gain boost"), kind: "bool", def: true },
                { key: "alr", label: Translation.tr("Adaptive release"), kind: "bool", def: false },
                { key: "alr-attack", label: Translation.tr("ALR attack"), min: 0.1, max: 200, def: 5, unit: "ms", kind: "slider" },
                { key: "alr-release", label: Translation.tr("ALR release"), min: 10, max: 1000, def: 50, unit: "ms", kind: "slider" },
                { key: "alr-knee", label: Translation.tr("ALR knee"), min: -12, max: 12, def: 0, unit: "dB", kind: "slider" },
                { key: "sidechain-type", label: Translation.tr("Sidechain"), kind: "enum", def: "Internal",
                    options: ["Internal", "External", "Link"] },
                { key: "mode", label: Translation.tr("Mode"), kind: "enum", def: "Herm Thin",
                    options: ["Herm Thin", "Herm Wide", "Herm Tail", "Herm Duck", "Exp Thin", "Exp Wide",
                        "Exp Tail", "Exp Duck", "Line Thin", "Line Wide", "Line Tail", "Line Duck"] },
                { key: "oversampling", label: Translation.tr("Oversampling"), kind: "enum", def: "None",
                    options: ["None", "Half x2/16 bit", "Half x2/24 bit", "Half x3/16 bit", "Half x3/24 bit",
                        "Half x4/16 bit", "Half x4/24 bit", "Half x6/16 bit", "Half x6/24 bit", "Half x8/16 bit",
                        "Half x8/24 bit", "Full x2/16 bit", "Full x2/24 bit", "Full x3/16 bit", "Full x3/24 bit",
                        "Full x4/16 bit", "Full x4/24 bit", "Full x6/16 bit", "Full x6/24 bit", "Full x8/16 bit",
                        "Full x8/24 bit", "True Peak/16 bit", "True Peak/24 bit"] },
                { key: "dithering", label: Translation.tr("Dithering"), kind: "enum", def: "None",
                    options: ["None", "7bit", "8bit", "11bit", "12bit", "15bit", "16bit", "23bit", "24bit"] }
            ]
        },
        autogain: {
            simple: [
                { key: "target", label: Translation.tr("Loudness goal"), min: -100, max: 0, def: -23, unit: "LUFS", kind: "slider" },
                { key: "silence-threshold", label: Translation.tr("Silence below"), min: -100, max: 0, def: -70, unit: "dB", kind: "slider" },
                { key: "maximum-history", label: Translation.tr("Memory"), min: 6, max: 3600, def: 15, unit: "s", kind: "int" }
            ],
            advanced: [
                { key: "reference", label: Translation.tr("Moment"), kind: "enum", def: "Geometric Mean (MSI)",
                    options: ["Momentary", "Shortterm", "Integrated", "Geometric Mean (MSI)",
                        "Geometric Mean (MS)", "Geometric Mean (MI)", "Geometric Mean (SI)"] },
                { key: "force-silence", label: Translation.tr("Stay silent in silence"), kind: "bool", def: false },
                { key: "input-gain", label: Translation.tr("Input gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" },
                { key: "output-gain", label: Translation.tr("Output gain"), min: -36, max: 36, def: 0, unit: "dB", kind: "slider" }
            ]
        }
    })

    // Crystalizer top-level keys (the 13 bands are addressed separately).
    readonly property var crystalizerTop: [
        { key: "transition-band", label: Translation.tr("Crossover"), min: 10, max: 1000, def: 120, unit: "Hz", kind: "slider" },
        { key: "oversampling-quality", label: Translation.tr("Oversampling"), min: 0, max: 10, def: 5, unit: "", kind: "int" },
        { key: "adaptive-intensity", label: Translation.tr("Follow the music"), kind: "bool", def: true },
        { key: "fixed-quantum", label: Translation.tr("Fixed quantum"), kind: "bool", def: false },
        { key: "oversampling", label: Translation.tr("Oversample"), kind: "bool", def: true }
    ]

    // Factory per-module presets: name + partial kebab-case params.
    // Applied with one setParam per key; instant, no preset reload.
    readonly property var factoryPresets: ({
        bass_enhancer: [
            { name: Translation.tr("Gentle"), params: { "amount": 6, "harmonics": 6, "scope": 90 } },
            { name: Translation.tr("Deep"), params: { "amount": 12, "harmonics": 8.5, "scope": 120 } },
            { name: Translation.tr("Club"), params: { "amount": 20, "harmonics": 9.5, "scope": 150 } }
        ],
        exciter: [
            { name: Translation.tr("Air"), params: { "amount": 5, "harmonics": 6, "scope": 8000 } },
            { name: Translation.tr("Shine"), params: { "amount": 10, "harmonics": 8.5, "scope": 7500 } },
            { name: Translation.tr("Crisp"), params: { "amount": 16, "harmonics": 9, "scope": 6000 } }
        ],
        limiter: [
            { name: Translation.tr("Safety net"), params: { "threshold": -3, "attack": 5, "release": 40, "lookahead": 5 } },
            { name: Translation.tr("Loud"), params: { "threshold": -6, "attack": 2, "release": 60, "lookahead": 8 } }
        ],
        autogain: [
            { name: Translation.tr("Music (−23)"), params: { "target": -23, "silence-threshold": -70, "maximum-history": 15 } },
            { name: Translation.tr("Quiet night (−30)"), params: { "target": -30, "silence-threshold": -70, "maximum-history": 30 } },
            { name: Translation.tr("Podcasts (−19)"), params: { "target": -19, "silence-threshold": -60, "maximum-history": 10 } }
        ],
        crystalizer: [
            { name: Translation.tr("Subtle"), sparkle: 2 },
            { name: Translation.tr("Bright"), sparkle: 6 },
            { name: Translation.tr("Brilliant"), sparkle: 10 }
        ]
    })

    // Historical whole-chain curves from the retired modules/equalizer panel
    // (scripts/audio/easyeffects-eq.sh:preset_values, 10 bands at
    // 32 64 125 250 500 1000 2000 4000 8000 16000 Hz). Bands-only: applying
    // one retunes the band gains (batched into a single write, no preset
    // reload) and leaves every module exactly as it was.
    readonly property var legacyFreqs: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var factoryChain: [
        { name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        { name: "Bass", gains: [5, 7, 5, 2, 1, 0, 0, 0, 1, 2] },
        { name: "Treble", gains: [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6] },
        { name: "Vocal", gains: [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0] },
        { name: "Pop", gains: [2, 4, 2, 0, 1, 2, 4, 2, 1, 2] },
        { name: "Rock", gains: [5, 4, 2, -1, -2, -1, 2, 4, 5, 6] },
        { name: "Jazz", gains: [3, 3, 1, 1, 1, 1, 2, 1, 2, 3] },
        { name: "Classic", gains: [0, 1, 2, 2, 2, 2, 1, 2, 3, 4] }
    ]

    // One legacy curve voiced at an arbitrary live band frequency:
    // log-frequency linear interpolation between the 10 legacy bands,
    // clamped at the edges, rounded to 0.1 dB.
    function chainGainAt(freq: real, gains: var): real {
        if (!gains || gains.length < 10 || !Number.isFinite(freq) || freq <= 0) return 0
        const x = Math.log(freq)
        const xs = root.legacyFreqs.map(v => Math.log(v))
        if (x <= xs[0]) return Number(gains[0])
        if (x >= xs[9]) return Number(gains[9])
        for (let i = 0; i < 9; ++i) {
            if (x <= xs[i + 1]) {
                const t = (x - xs[i]) / (xs[i + 1] - xs[i])
                return Math.round((Number(gains[i]) + (Number(gains[i + 1]) - Number(gains[i])) * t) * 10) / 10
            }
        }
        return Number(gains[9])
    }

    // Coherent profiles. A profile is not a curve: it is a loudness target,
    // a curve and a set of module states that make sense together, applied
    // in one atomic bundle so the chain never passes through a half-applied
    // state. The LUFS numbers are the published standards for the material,
    // not invented taste: -16 is the spoken-word target, -14 the streaming
    // one. Night pairs a lower target WITH the limiter, because a quieter
    // target on its own only lowers the average and leaves peaks alone.
    //
    // `curve` is a legacy name and is voiced through chainGainAt(), so a
    // profile applies to whatever band count is live. The bridge knows
    // nothing about profiles; it takes the resolved gains as a bundle.
    readonly property var profiles: [
        {
            id: "transparent",
            label: "Transparent",
            detail: Translation.tr("Nothing shaped. −16 LUFS"),
            target: -16,
            curve: "Flat",
            modules: { autogain: true }
        },
        {
            id: "voice",
            label: "Voice",
            detail: Translation.tr("Speech forward. −16 LUFS"),
            target: -16,
            curve: "Vocal",
            modules: { autogain: true }
        },
        {
            id: "music",
            label: "Music",
            detail: Translation.tr("Level with the streams. −14 LUFS"),
            target: -14,
            curve: "Flat",
            modules: { autogain: true }
        },
        {
            id: "night",
            label: "Night",
            detail: Translation.tr("Quieter, peaks held. −20 LUFS"),
            target: -20,
            curve: "Flat",
            modules: { autogain: true, limiter: true }
        },
        {
            id: "bass",
            label: "Bass",
            detail: Translation.tr("Low end lifted. −14 LUFS"),
            target: -14,
            curve: "Bass",
            modules: { autogain: true, bass_enhancer: true }
        }
    ]

    function profileById(id: string): var {
        const list = root.profiles ?? []
        for (let i = 0; i < list.length; ++i)
            if (list[i].id === id) return list[i]
        return null
    }

    // The 10 legacy gains a profile names, so the caller can voice them at
    // the live band count with chainGainAt() instead of trusting a hardcoded
    // array length.
    function profileLegacyGains(profile: var): var {
        const list = root.factoryChain ?? []
        const name = String(profile?.curve ?? "")
        for (let i = 0; i < list.length; ++i)
            if (list[i].name === name) return list[i].gains
        return null
    }

    // Read one param out of the live modules map with schema fallback.
    function paramOf(modules: var, moduleId: string, key: string, fallback: var): var {
        const entry = (modules ?? {})[moduleId] ?? {}
        // The bridge sends a FLAT param map, so read it directly. Only the
        // optimistic setModuleActive path adds a nested `params` sub-object, on
        // top of the flat keys — so the nested read is the fallback, not the
        // primary.
        const direct = entry[key]
        if (direct !== undefined && direct !== null) return direct
        const params = entry.params ?? {}
        const nested = params[key]
        return nested === undefined || nested === null ? fallback : nested
    }

    // Whether a module is running, read the way the engine actually reports it.
    // The bridge NEVER sends an `active` field: grepping it finds `active` only
    // inside cmd_set_module. Bypass is what exists, and active is its inverse.
    // Prefer a real boolean when one is present, since the optimistic update
    // path writes `active` into the entry as well.
    function moduleActive(modules: var, moduleId: string): bool {
        const entry = (modules ?? {})[moduleId] ?? null
        if (!entry) return false
        if (typeof entry.active === "boolean") return entry.active
        if (typeof entry.bypass === "boolean") return !entry.bypass
        return false
    }

    function formatValue(value: real, unit: string): string {
        if (!Number.isFinite(value)) return Translation.tr("—")
        const rounded = Math.abs(value) >= 100 ? Math.round(value) : Math.round(value * 10) / 10
        return unit.length > 0 ? "%1 %2".arg(rounded).arg(unit) : String(rounded)
    }
}
