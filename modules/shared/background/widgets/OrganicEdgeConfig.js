.pragma library

var path = "background.edgeWidgets.organic"
var defaults = {
    enable: false, edge: "bottom", edges: [], screenList: [],
    span: 70, position: 50, depth: 180, inset: 0, respectPanels: false,
    topScale: 100, rightScale: 100, bottomScale: 100, leftScale: 100,
    cornerRadius: 24, cornerBlend: 55, taper: 14, thickness: 22, detail: 42,
    style: "silk", shape: "flow", palette: "theme", colorMode: "flow", effectMode: "clean",
    joinMode: "auto",
    primaryColor: "#b5a0ff",
    secondaryColor: "#64dbcf", tertiaryColor: "#ffb2cf", colorSpeed: 35,
    hueShift: 0, colorIntensity: 100, effectStrength: 38,
    opacity: 100, bodyOpacity: 32, crestStrength: 90, glow: 52, glowSpread: 48,
    smoothing: 2, frequencyProfile: "flat", accentStrength: 70,
    sensitivity: 72, audioRange: 78, pulse: 90, beatGlow: 64, transientStrength: 90,
    bassDrive: 88, trebleDrive: 68, attack: 105, release: 82,
    compression: 12, motionSpeed: 100, idleMotion: 14, flowDirection: "clockwise",
    audioReactive: true, idleMode: "ambient", restPresence: 58
}

var compositionKeys = ["edges", "span", "position", "depth", "inset", "respectPanels",
    "topScale", "rightScale", "bottomScale", "leftScale", "cornerRadius", "cornerBlend",
    "taper", "joinMode"]
var materialKeys = ["style", "shape", "thickness", "detail", "bodyOpacity", "crestStrength",
    "glow", "glowSpread", "effectMode", "effectStrength"]
var colorKeys = ["palette", "colorMode", "primaryColor", "secondaryColor", "tertiaryColor",
    "colorSpeed", "hueShift", "colorIntensity"]
var motionKeys = ["motionSpeed", "idleMotion", "flowDirection"]
var idleKeys = ["idleMode", "restPresence"]
var responseKeys = ["frequencyProfile", "accentStrength", "sensitivity", "audioRange", "pulse",
    "beatGlow", "transientStrength", "bassDrive", "trebleDrive", "attack", "release",
    "compression", "smoothing"]

function defaultValues(keys) {
    var values = {}
    for (var i = 0; i < keys.length; ++i)
        values[keys[i]] = defaults[keys[i]]
    return values
}

var compositionPresets = [
    {name: "Horizon", icon: "horizontal_rule", description: "A broad lower ribbon with quiet tapered ends",
        values: {edges: ["bottom"], span: 88, position: 50, depth: 188, taper: 18,
            joinMode: "auto", cornerBlend: 55}},
    {name: "Twin Rails", icon: "view_week", description: "Balanced vertical rails with independent motion",
        values: {edges: ["left", "right"], span: 86, position: 50, depth: 190, taper: 20,
            joinMode: "separate", cornerBlend: 44}},
    {name: "Crown", icon: "border_top", description: "A restrained upper arc that leaves the desktop open",
        values: {edges: ["top"], span: 72, position: 50, depth: 152, taper: 26,
            joinMode: "auto", cornerBlend: 50}},
    {name: "Corner Drift", icon: "rounded_corner", description: "Two adjacent sides hand off through one continuous corner",
        values: {edges: ["right", "bottom"], span: 100, position: 50, depth: 186, taper: 0,
            joinMode: "auto", cornerBlend: 68}},
    {name: "Open Frame", icon: "bottom_panel_open", description: "A connected three-sided field with an open top",
        values: {edges: ["left", "bottom", "right"], span: 100, position: 50, depth: 164, taper: 0,
            joinMode: "auto", cornerBlend: 64}},
    {name: "Full Frame", icon: "select_all", description: "One continuous perimeter with shared corner energy",
        values: {edges: ["top", "right", "bottom", "left"], span: 100, position: 50,
            depth: 142, taper: 0, joinMode: "auto", cornerBlend: 62}}
]

var materialPresets = [
    {name: "Soft Silk", icon: "waves", description: "Translucent ribbon, subtle sheen and low visual noise",
        values: {style: "silk", shape: "ribbon", thickness: 20, detail: 32, bodyOpacity: 20,
            crestStrength: 88, glow: 42, glowSpread: 46, effectMode: "shimmer", effectStrength: 28}},
    {name: "Aurora Thread", icon: "flare", description: "Fine luminous strands where treble lives in the crest",
        values: {style: "aurora", shape: "filament", thickness: 14, detail: 74, bodyOpacity: 10,
            crestStrength: 112, glow: 74, glowSpread: 66, effectMode: "afterglow", effectStrength: 44}},
    {name: "Ink Contour", icon: "gesture", description: "A narrow readable line with almost no filled body",
        values: {style: "contour", shape: "flow", thickness: 10, detail: 26, bodyOpacity: 3,
            crestStrength: 106, glow: 24, glowSpread: 24, effectMode: "clean", effectStrength: 0}},
    {name: "Liquid Tide", icon: "water", description: "A denser organic body with music-driven internal caustics",
        values: {style: "liquid", shape: "flow", thickness: 27, detail: 56, bodyOpacity: 34,
            crestStrength: 94, glow: 58, glowSpread: 58, effectMode: "caustic", effectStrength: 48}},
    {name: "Pulse Glass", icon: "graphic_eq", description: "Discrete musical bulges with a restrained secondary echo",
        values: {style: "silk", shape: "cells", thickness: 21, detail: 44, bodyOpacity: 17,
            crestStrength: 100, glow: 52, glowSpread: 48, effectMode: "echo", effectStrength: 42}}
]

var scenePresets = [
    {name: "Quiet Horizon", icon: "water", description: "Soft adaptive ribbon that remains composed when the room is quiet",
        values: {edges: ["bottom"], span: 90, position: 50, depth: 182, taper: 20, joinMode: "auto",
            cornerBlend: 55, style: "silk", shape: "ribbon", palette: "adaptive", colorMode: "flow",
            effectMode: "shimmer", effectStrength: 24, thickness: 19, detail: 30, bodyOpacity: 18,
            crestStrength: 86, glow: 38, glowSpread: 44, sensitivity: 66, audioRange: 70, pulse: 58,
            beatGlow: 46, transientStrength: 58, bassDrive: 72, trebleDrive: 68, attack: 78, release: 62,
            compression: 10, smoothing: 4, frequencyProfile: "flat", motionSpeed: 66, idleMotion: 9,
            flowDirection: "clockwise", idleMode: "ambient", restPresence: 66, opacity: 92}},
    {name: "Aurora Rails", icon: "flare", description: "Two fine rails: bass bends the field, treble lights the threads",
        values: {edges: ["left", "right"], span: 100, position: 50, depth: 198, taper: 8,
            joinMode: "separate", cornerBlend: 45, style: "aurora", shape: "filament", palette: "wallpaper",
            colorMode: "spectrum", effectMode: "afterglow", effectStrength: 46, thickness: 14, detail: 72,
            bodyOpacity: 9, crestStrength: 110, glow: 72, glowSpread: 70, sensitivity: 72, audioRange: 78,
            pulse: 62, beatGlow: 74, transientStrength: 94, bassDrive: 68, trebleDrive: 118, attack: 118,
            release: 88, compression: 24, smoothing: 2, frequencyProfile: "smile", accentStrength: 82,
            motionSpeed: 62, idleMotion: 12, flowDirection: "clockwise", idleMode: "ambient",
            restPresence: 42, opacity: 88}},
    {name: "Album Tide", icon: "album", description: "Artwork colors carried by one connected liquid current",
        values: {edges: ["left", "bottom", "right"], span: 100, position: 50, depth: 204, taper: 0,
            joinMode: "auto", cornerBlend: 68, style: "liquid", shape: "flow", palette: "album",
            colorMode: "flow", effectMode: "caustic", effectStrength: 52, thickness: 26, detail: 54,
            bodyOpacity: 30, crestStrength: 92, glow: 54, glowSpread: 58, sensitivity: 72, audioRange: 82,
            pulse: 78, beatGlow: 58, transientStrength: 84, bassDrive: 92, trebleDrive: 76, attack: 96,
            release: 72, compression: 14, smoothing: 3, frequencyProfile: "warm", accentStrength: 58,
            motionSpeed: 74, idleMotion: 10, flowDirection: "clockwise", idleMode: "ambient",
            restPresence: 48, opacity: 90}},
    {name: "Pulse Gate", icon: "graphic_eq", description: "Opposing rails open on rhythm instead of constantly glowing",
        values: {edges: ["top", "bottom"], span: 92, position: 50, depth: 174, taper: 12,
            joinMode: "separate", cornerBlend: 44, style: "silk", shape: "cells", palette: "theme",
            colorMode: "pulse", effectMode: "echo", effectStrength: 44, thickness: 22, detail: 42,
            bodyOpacity: 14, crestStrength: 100, glow: 48, glowSpread: 44, sensitivity: 82, audioRange: 94,
            pulse: 116, beatGlow: 94, transientStrength: 118, bassDrive: 112, trebleDrive: 70, attack: 142,
            release: 96, compression: 16, smoothing: 2, frequencyProfile: "bass", accentStrength: 74,
            motionSpeed: 88, idleMotion: 4, flowDirection: "clockwise", idleMode: "hidden",
            restPresence: 24, opacity: 94}},
    {name: "Contour Frame", icon: "select_all", description: "A quiet perimeter that becomes articulate only when music arrives",
        values: {edges: ["top", "right", "bottom", "left"], span: 100, position: 50, depth: 128, taper: 0,
            joinMode: "auto", cornerBlend: 64, style: "contour", shape: "flow", palette: "adaptive",
            colorMode: "static", effectMode: "clean", effectStrength: 0, thickness: 10, detail: 28,
            bodyOpacity: 2, crestStrength: 102, glow: 24, glowSpread: 22, sensitivity: 70, audioRange: 72,
            pulse: 54, beatGlow: 38, transientStrength: 86, bassDrive: 62, trebleDrive: 96, attack: 112,
            release: 92, compression: 20, smoothing: 3, frequencyProfile: "flat", motionSpeed: 44,
            idleMotion: 0, flowDirection: "clockwise", idleMode: "still", restPresence: 52, opacity: 82}}
]

var legacyPresets = [
    {name: "Silk Horizon", icon: "waves", description: "Elegant music ribbon along the lower edge",
        values: {style: "silk", shape: "ribbon", palette: "adaptive", colorMode: "flow", effectMode: "shimmer", joinMode: "auto",
            effectStrength: 44, edges: ["bottom"], span: 88, depth: 184, thickness: 21, taper: 18,
            detail: 46, bodyOpacity: 24, crestStrength: 98, glow: 48, glowSpread: 48,
            audioRange: 82, sensitivity: 76, pulse: 90, beatGlow: 62, transientStrength: 92,
            bassDrive: 86, trebleDrive: 76, attack: 112, release: 78, compression: 14,
            motionSpeed: 84, idleMotion: 16, opacity: 92, colorSpeed: 30}},
    {name: "Aurora Rails", icon: "flare", description: "Two luminous rails with airy high-frequency motion",
        values: {style: "aurora", shape: "filament", palette: "wallpaper", colorMode: "spectrum", effectMode: "echo", joinMode: "auto",
            effectStrength: 54, edges: ["left", "right"], span: 100, depth: 224, thickness: 18,
            taper: 8, detail: 62, bodyOpacity: 17, crestStrength: 86, glow: 80, glowSpread: 80,
            audioRange: 72, sensitivity: 72, pulse: 70, beatGlow: 94, transientStrength: 76,
            bassDrive: 68, trebleDrive: 108, attack: 86, release: 64, compression: 20,
            motionSpeed: 64, idleMotion: 22, opacity: 84, colorSpeed: 22}},
    {name: "Neon Frame", icon: "select_all", description: "A complete reactive frame with crisp club-like light",
        values: {style: "contour", shape: "filament", palette: "vivid", colorMode: "pulse", effectMode: "prism", joinMode: "auto",
            effectStrength: 58, edges: ["top", "right", "bottom", "left"], span: 100, depth: 126,
            thickness: 15, taper: 0, detail: 44, bodyOpacity: 6, crestStrength: 124,
            glow: 58, glowSpread: 46, audioRange: 76, sensitivity: 78, pulse: 104, beatGlow: 112,
            transientStrength: 124, bassDrive: 82, trebleDrive: 112, attack: 142, release: 98,
            compression: 26, smoothing: 1, motionSpeed: 72, idleMotion: 8, opacity: 94, colorSpeed: 18}},
    {name: "Ember Pulse", icon: "local_fire_department", description: "Warm low-end pulses with a dense liquid crest",
        values: {style: "liquid", shape: "cells", palette: "warm", colorMode: "pulse", effectMode: "bloom", joinMode: "auto",
            effectStrength: 64, edges: ["bottom", "left"], span: 100, depth: 214, thickness: 24,
            taper: 8, detail: 66, bodyOpacity: 38, crestStrength: 102, glow: 72, glowSpread: 60,
            audioRange: 98, sensitivity: 84, pulse: 122, beatGlow: 104, transientStrength: 120,
            bassDrive: 132, trebleDrive: 56, attack: 132, release: 84, compression: 12,
            smoothing: 2, motionSpeed: 116, idleMotion: 18, opacity: 88, colorSpeed: 24}},
    {name: "Album Aura", icon: "album", description: "Artwork colors flow through a cinematic music ribbon",
        values: {style: "silk", shape: "ribbon", palette: "album", colorMode: "spectrum", effectMode: "shimmer", joinMode: "auto",
            effectStrength: 48, edges: ["bottom"], span: 94, depth: 224, thickness: 21,
            taper: 12, detail: 50, bodyOpacity: 20, crestStrength: 92, glow: 62, glowSpread: 68,
            audioRange: 78, sensitivity: 72, pulse: 80, beatGlow: 70, transientStrength: 84,
            bassDrive: 84, trebleDrive: 86, attack: 104, release: 74, compression: 16,
            smoothing: 2, motionSpeed: 72, idleMotion: 16, opacity: 88, colorSpeed: 20}},
    {name: "Spectrum Crown", icon: "multiline_chart", description: "Fine detail and treble shimmer across the top edge",
        values: {style: "aurora", shape: "filament", palette: "adaptive", colorMode: "spectrum", effectMode: "shimmer", joinMode: "auto",
            effectStrength: 70, edges: ["top"], span: 94, depth: 166, thickness: 14,
            taper: 14, detail: 82, bodyOpacity: 10, crestStrength: 112, glow: 62, glowSpread: 46,
            audioRange: 82, sensitivity: 76, pulse: 58, beatGlow: 78, transientStrength: 118,
            bassDrive: 48, trebleDrive: 142, attack: 148, release: 124, compression: 32,
            smoothing: 1, motionSpeed: 94, idleMotion: 10, opacity: 92, colorSpeed: 34}},
    {name: "Ghost Frame", icon: "filter_vintage", description: "Minimal ambient outline for quiet desktops",
        values: {style: "contour", shape: "ribbon", palette: "mono", colorMode: "static", effectMode: "echo", joinMode: "auto",
            effectStrength: 20, edges: ["top", "right", "bottom", "left"], span: 100, depth: 92,
            thickness: 11, taper: 0, detail: 24, bodyOpacity: 3, crestStrength: 72, glow: 24,
            glowSpread: 22, audioRange: 42, sensitivity: 54, pulse: 38, beatGlow: 26,
            transientStrength: 54, bassDrive: 54, trebleDrive: 70, attack: 84, release: 58,
            compression: 12, smoothing: 3, motionSpeed: 34, idleMotion: 5, opacity: 76, colorSpeed: 0}},
    {name: "Club Pulse", icon: "graphic_eq", description: "Fast bass-driven light for music-focused desktops",
        values: {style: "liquid", shape: "cells", palette: "vivid", colorMode: "pulse", effectMode: "bloom", joinMode: "auto",
            effectStrength: 82, edges: ["top", "bottom"], span: 100, depth: 178, thickness: 20,
            taper: 0, detail: 58, bodyOpacity: 22, crestStrength: 126, glow: 84, glowSpread: 64,
            audioRange: 108, sensitivity: 90, pulse: 138, beatGlow: 132, transientStrength: 138,
            bassDrive: 140, trebleDrive: 88, attack: 172, release: 118, compression: 20,
            smoothing: 1, motionSpeed: 128, idleMotion: 8, opacity: 94, colorSpeed: 44}},
    {name: "Wallpaper Tide", icon: "water", description: "Wallpaper-driven ribbon with liquid caustic motion",
        values: {style: "silk", shape: "ribbon", palette: "wallpaper", colorMode: "flow", effectMode: "caustic", joinMode: "auto",
            effectStrength: 58, edges: ["bottom", "right"], span: 100, depth: 206, thickness: 22,
            taper: 14, detail: 54, bodyOpacity: 22, crestStrength: 94, glow: 56, glowSpread: 62,
            audioRange: 88, sensitivity: 76, pulse: 82, beatGlow: 68, transientStrength: 92,
            bassDrive: 90, trebleDrive: 86, attack: 108, release: 72, compression: 16,
            smoothing: 2, motionSpeed: 78, idleMotion: 14, opacity: 90, colorSpeed: 26}},
    {name: "Afterglow Frame", icon: "blur_on", description: "A unified frame whose peaks leave a soft musical afterglow",
        values: {style: "contour", shape: "flow", palette: "adaptive", colorMode: "spectrum", effectMode: "afterglow", joinMode: "auto",
            effectStrength: 66, edges: ["top", "right", "bottom", "left"], span: 100, depth: 148,
            thickness: 14, taper: 0, detail: 48, bodyOpacity: 6, crestStrength: 118, glow: 66,
            glowSpread: 58, audioRange: 82, sensitivity: 78, pulse: 88, beatGlow: 116,
            transientStrength: 118, bassDrive: 72, trebleDrive: 118, attack: 142, release: 116,
            compression: 24, smoothing: 1, motionSpeed: 68, idleMotion: 7, opacity: 92, colorSpeed: 22}}
]

// Public IPC keeps the original preset semantics for existing names. Settings
// can expose newer curated scenes with the same display name without changing
// what an existing `applyOrganicEdgePreset` caller receives.
var legacyPresetNames = legacyPresets.map(p => p.name.toLowerCase())
var presets = legacyPresets.concat(scenePresets.filter(p =>
    legacyPresetNames.indexOf(p.name.toLowerCase()) === -1))

var palettes = [
    {name: "Adaptive", value: "adaptive"}, {name: "Wallpaper", value: "wallpaper"},
    {name: "Album", value: "album"}, {name: "Theme", value: "theme"},
    {name: "Vivid", value: "vivid"}, {name: "Iridescent", value: "iridescent"},
    {name: "Monochrome", value: "mono"}, {name: "Cool", value: "cool"},
    {name: "Warm", value: "warm"}, {name: "Custom", value: "custom"}
]

var shapes = [
    {name: "Flow", value: "flow"}, {name: "Ribbon", value: "ribbon"},
    {name: "Pulse cells", value: "cells"}, {name: "Filament", value: "filament"}
]

var colorModes = [
    {name: "Flow", value: "flow"}, {name: "Spectrum", value: "spectrum"},
    {name: "Beat", value: "pulse"}, {name: "Static", value: "static"}
]

var effects = [
    {name: "Clean", value: "clean"}, {name: "Harmonic shimmer", value: "shimmer"},
    {name: "Pulse echo", value: "echo"}, {name: "Spectral prism", value: "prism"},
    {name: "Bass bloom", value: "bloom"}, {name: "Liquid caustics", value: "caustic"},
    {name: "Peak afterglow", value: "afterglow"}
]

var responsePresets = [
    {name: "Velvet", icon: "water", values: {sensitivity: 62, audioRange: 68,
        pulse: 52, beatGlow: 42, transientStrength: 52, bassDrive: 72, trebleDrive: 66,
        attack: 68, release: 58, compression: 8, smoothing: 4}},
    {name: "Balanced", icon: "tune", values: {sensitivity: 72, audioRange: 78,
        pulse: 90, beatGlow: 64, transientStrength: 90, bassDrive: 88, trebleDrive: 68,
        attack: 105, release: 82, compression: 12, smoothing: 2}},
    {name: "Rhythmic", icon: "graphic_eq", values: {sensitivity: 82, audioRange: 94,
        pulse: 116, beatGlow: 94, transientStrength: 112, bassDrive: 112, trebleDrive: 72,
        attack: 140, release: 92, compression: 16, smoothing: 2}},
    {name: "Percussive", icon: "bolt", values: {sensitivity: 84, audioRange: 92,
        pulse: 96, beatGlow: 108, transientStrength: 142, bassDrive: 88, trebleDrive: 94,
        attack: 180, release: 128, compression: 22, smoothing: 1}},
    {name: "Fine detail", icon: "multiline_chart", values: {sensitivity: 74, audioRange: 80,
        pulse: 62, beatGlow: 54, transientStrength: 112, bassDrive: 54, trebleDrive: 136,
        attack: 142, release: 118, compression: 28, smoothing: 1}}
]

var geometry = [
    {key: "span", label: "Edge length", min: 10, max: 100, step: 5, unit: "%"},
    {key: "position", label: "Position along edge", min: 0, max: 100, step: 1, unit: "%"},
    {key: "depth", label: "Field depth", min: 24, max: 600, step: 4, unit: "px"},
    {key: "inset", label: "Screen inset", min: 0, max: 160, step: 2, unit: "px"},
    {key: "cornerRadius", label: "Screen corner radius", min: 0, max: 160, step: 2, unit: "px"},
    {key: "cornerBlend", label: "Corner handoff", min: 0, max: 100, step: 5, unit: "%"},
    {key: "taper", label: "Endpoint softness", min: 0, max: 50, step: 1, unit: "%"},
    {key: "topScale", label: "Top reach", min: 10, max: 200, step: 5, unit: "%"},
    {key: "rightScale", label: "Right reach", min: 10, max: 200, step: 5, unit: "%"},
    {key: "bottomScale", label: "Bottom reach", min: 10, max: 200, step: 5, unit: "%"},
    {key: "leftScale", label: "Left reach", min: 10, max: 200, step: 5, unit: "%"}
]
var materialBody = [
    {key: "thickness", label: "Body weight", min: 5, max: 70, step: 1, unit: "%"},
    {key: "bodyOpacity", label: "Body opacity", min: 0, max: 100, step: 5, unit: "%"},
    {key: "crestStrength", label: "Crest brightness", min: 0, max: 150, step: 5, unit: "%"},
    {key: "detail", label: "Contour detail", min: 0, max: 100, step: 5, unit: "%"},
    {key: "opacity", label: "Overall opacity", min: 0, max: 100, step: 5, unit: "%"}
]
var materialLight = [
    {key: "glow", label: "Glow intensity", min: 0, max: 100, step: 5, unit: "%"},
    {key: "glowSpread", label: "Glow spread", min: 0, max: 100, step: 5, unit: "%"},
    {key: "effectStrength", label: "Effect strength", min: 0, max: 100, step: 5, unit: "%"}
]
var colorTuning = [
    {key: "colorSpeed", label: "Color travel", min: 0, max: 100, step: 5, unit: "%"},
    {key: "hueShift", label: "Hue shift", min: -180, max: 180, step: 5, unit: "°"},
    {key: "colorIntensity", label: "Color intensity", min: 0, max: 150, step: 5, unit: "%"}
]
var motion = [
    {key: "motionSpeed", label: "Motion speed", min: 0, max: 250, step: 5, unit: "%"},
    {key: "idleMotion", label: "Ambient motion", min: 0, max: 100, step: 5, unit: "%"}
]
var idle = [
    {key: "restPresence", label: "Rest presence", min: 0, max: 100, step: 5, unit: "%"}
]
var audioDynamics = [
    {key: "sensitivity", label: "Audio sensitivity", min: 0, max: 200, step: 5, unit: "%"},
    {key: "audioRange", label: "Audio range", min: 0, max: 150, step: 5, unit: "%"},
    {key: "pulse", label: "Beat pulse", min: 0, max: 150, step: 5, unit: "%"},
    {key: "beatGlow", label: "Beat glow", min: 0, max: 150, step: 5, unit: "%"},
    {key: "transientStrength", label: "Transient punch", min: 0, max: 150, step: 5, unit: "%"},
    {key: "attack", label: "Attack speed", min: 20, max: 250, step: 5, unit: "%"},
    {key: "release", label: "Release speed", min: 20, max: 250, step: 5, unit: "%"},
    {key: "smoothing", label: "Audio smoothing", min: 0, max: 8, step: 1, unit: ""}
]
var audioTone = [
    {key: "bassDrive", label: "Bass drive", min: 0, max: 150, step: 5, unit: "%"},
    {key: "trebleDrive", label: "Treble shimmer", min: 0, max: 150, step: 5, unit: "%"},
    {key: "compression", label: "Frequency separation", min: 0, max: 100, step: 5, unit: "%"},
    {key: "accentStrength", label: "Frequency emphasis", min: 0, max: 100, step: 5, unit: "%"}
]

function selectedEdges(configured, legacy) {
    var allowed = ["top", "right", "bottom", "left"]
    var list = []
    if (configured && typeof configured.length === "number") {
        for (var i = 0; i < configured.length; ++i) {
            var edge = String(configured[i])
            if (allowed.indexOf(edge) >= 0 && list.indexOf(edge) < 0)
                list.push(edge)
        }
    }
    return list.length ? list : [allowed.indexOf(legacy) >= 0 ? legacy : "bottom"]
}

function paletteValue(value) {
    var name = String(value || "theme")
    if (name === "neon") return "vivid"
    if (name === "ocean") return "cool"
    if (name === "sunset") return "warm"
    if (name === "forest") return "wallpaper"
    return name
}
