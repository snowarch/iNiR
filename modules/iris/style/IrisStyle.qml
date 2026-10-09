pragma Singleton

import QtQuick
import QtQml
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.services

QtObject {
    id: root

    readonly property var options: Config.options?.iris ?? ({})
    readonly property var appearance: root.options?.appearance ?? ({})

    readonly property bool island: true

    // --- Recompose: one clock for structural change -------------------------
    // An option that changes what a surface is *made of* (the Island's
    // composition, its clock, its bubbles, a panel's sections) is never applied
    // while the shapes are visible: every such value is published here, latched,
    // and swapped at the bottom of one shared dip. Consumers read the latched
    // value and multiply their content by `recompose`, so a recomposition is one
    // transition for the whole family instead of one animation per part racing
    // the others. Geometry still springs across the swap: the silhouette is
    // continuous, its contents are replaced.
    readonly property var structuralPaths: ["bar.composition", "bar.clockStyle", "bar.trailing",
        "bar.auxiliary", "bar.pieces", "bar.fullStart", "bar.fullCenter", "bar.fullEnd", "bar.navItems", "bar.desktopBlocks", "bar.mediaBlocks",
        "controlCenter.sections", "controlCenter.controls"]
    function readPath(path: string): var {
        let node = root.options
        for (const part of path.split(".")) {
            if (node === undefined || node === null) return undefined
            node = node[part]
        }
        return node
    }
    readonly property var structuralSource: {
        const out = {}
        for (const path of root.structuralPaths) {
            const value = root.readPath(path)
            out[path] = value === undefined ? null : (Array.isArray(value) ? Array.from(value) : value)
        }
        return out
    }
    readonly property string structuralKey: JSON.stringify(root.structuralSource)
    property var structure: root.structuralSource
    property real recomposeValue: 1
    readonly property real recompose: root.recomposeValue
    readonly property bool recomposing: root.recomposeValue < 0.999
    function structuralValue(path: string, fallback: var): var {
        const value = root.structure?.[path]
        return value === undefined || value === null ? fallback : value
    }
    onStructuralKeyChanged: {
        if (!root.motionEnabled) { root.structure = root.structuralSource; return }
        root.recomposeIn.stop()
        root.recomposeOut.restart()
    }
    readonly property NumberAnimation recomposeOut: NumberAnimation {
        target: root; property: "recomposeValue"; to: 0
        duration: root.duration(80); easing.type: Easing.OutQuad
        onFinished: {
            root.structure = root.structuralSource
            root.recomposeIn.restart()
        }
    }
    readonly property NumberAnimation recomposeIn: NumberAnimation {
        target: root; property: "recomposeValue"; to: 1
        duration: root.duration(200); easing.type: Easing.BezierSpline; easing.bezierCurve: root.emergeCurve
    }

    readonly property bool cluster: String(root.structuralValue("bar.composition", "unified")) === "cluster"

    readonly property real density: Math.max(0.8, Math.min(1.35, Number(root.appearance?.density ?? 1.0)))
    // Density scales geometry only; type has its own scale.
    readonly property real typeScale: Math.max(0.75, Math.min(1.6, (Appearance.fontSizeScale ?? 1.0) * root.tweak("text", 0.85, 1.25)))
    readonly property int typeCaption: Math.round(10 * root.typeScale)
    readonly property int typeFootnote: Math.round(11 * root.typeScale)
    readonly property int typeMeta: Math.round(12 * root.typeScale)
    readonly property int typeLabel: Math.round(13 * root.typeScale)
    readonly property int typeBody: Math.round(14 * root.typeScale)
    readonly property int typeHeadline: Math.round(15 * root.typeScale)
    readonly property int typeTitle: Math.round(17 * root.typeScale)
    readonly property int typeTitleLarge: Math.round(21 * root.typeScale)
    readonly property int typeDisplay: Math.round(28 * root.typeScale)
    // Inter's optical tracking (a + b·e^(c·size) em) in whole pixels: 0 to 25 px, −1 from 26, −2 from 68.
    function tracking(px: real): int {
        return Math.round(px * (-0.0223 + 0.185 * Math.exp(-0.1745 * px)))
    }

    readonly property var theme: root.appearance?.theme ?? ({})
    function wrapHue(hue, fallback: real): real {
        const value = Number(hue)
        return (((isNaN(value) ? fallback : value) % 360) + 360) % 360 / 360
    }
    function hueOf(name: string, fallback: int): real {
        return root.wrapHue(root.theme?.[name], fallback)
    }
    // `theme` is rebuilt on every Config write; the tweaks reach consumers through a string that only
    // changes when one of their values does, so a write elsewhere re-evaluates nothing downstream.
    readonly property var tweakNames: ["text", "fill", "lines", "contrast", "shadow", "shape", "melt", "press",
        "bounce", "contentTiming", "lightReach", "openTime", "moveTime"]
    readonly property string tweakKey: JSON.stringify(root.tweakNames.map(name => root.theme?.[name] ?? 100))
    readonly property var tweaks: {
        const values = JSON.parse(root.tweakKey)
        const out = {}
        root.tweakNames.forEach((name, index) => out[name] = values[index])
        return out
    }
    function tweak(name: string, low: real, high: real): real {
        const tweaks = root.tweaks ?? {}
        const value = Number((name in tweaks ? tweaks[name] : root.theme?.[name]) ?? 100)
        return Math.max(low, Math.min(high, (isNaN(value) ? 100 : value) / 100 * IrisMood.factor(name)))
    }
    function surfaceRadius(id: string, fallback: int): int {
        const radius = Number(root.appearance?.surfaces?.[id]?.radius ?? 0)
        if (radius > 0) return Math.round(radius * root.density)
        if (id === "cards" && Number(root.cardDesign.radius ?? 0) > 0)
            return Math.round(Number(root.cardDesign.radius) * root.density)
        return fallback
    }
    function surfaceLight(id: string, light: color): color {
        let mode = String(root.appearance?.surfaces?.[id]?.light ?? "inherit")
        if (id === "cards" && mode === "inherit") mode = String(root.cardDesign.light ?? "inherit")
        return mode === "off" ? Qt.color("transparent") : mode === "wallpaper" ? root.wallpaperLight : light
    }

    // A card design is a named bundle of the knobs below it. Anything the user sets
    // explicitly still wins: 0 and "inherit" mean "whatever the design says".
    readonly property var cardDesigns: ({
        welded:   { label: "Welded",   gap: 0,  radius: 0,  light: "inherit",   pad: 100, grabber: false },
        floating: { label: "Floating", gap: 12, radius: 0,  light: "inherit",   pad: 100, grabber: true },
        plain:    { label: "Plain",    gap: 0,  radius: 14, light: "off",       pad: 88,  grabber: false },
        vibrant:  { label: "Vibrant",  gap: 0,  radius: 0,  light: "wallpaper", pad: 118, grabber: false }
    })
    readonly property var cardDesign: root.cardDesigns[String(root.appearance?.surfaces?.cards?.design ?? "welded")]
        ?? root.cardDesigns.welded
    readonly property real cardGap: {
        const own = Number(root.appearance?.surfaces?.cards?.gap ?? 0)
        return Math.round((own > 0 ? own : Number(root.cardDesign.gap ?? 0)) * root.density)
    }
    // A card fuses with its opener only when asked to and when its design leaves no air.
    readonly property bool cardJoins: (root.appearance?.surfaces?.cards?.joinOrigin ?? false) && root.cardGap === 0
    readonly property real cardPad: {
        const own = Number(root.appearance?.surfaces?.cards?.pad ?? 0)
        const percent = own > 0 ? own : Number(root.cardDesign.pad ?? 100)
        return Math.round(16 * root.density * Math.max(0.5, Math.min(1.6, percent / 100)))
    }
    readonly property bool cardGrabber: {
        const own = String(root.appearance?.surfaces?.cards?.grabber ?? "auto")
        return own === "auto" ? Boolean(root.cardDesign.grabber ?? false) : own === "on"
    }
    readonly property int radius: Math.round(Math.max(16, Math.min(40, Number(root.appearance?.expandedRadius ?? 28))) * root.density)
    readonly property int radiusSmall: Math.max(4, Math.round(root.radius * 0.58))
    readonly property int radiusTiny: Math.max(3, Math.round(root.radius * 0.36))
    readonly property int gap: Math.max(4, Math.round(8 * root.density))
    readonly property int gapLarge: Math.max(8, Math.round(14 * root.density))
    readonly property int spaceSmall: Math.max(4, Math.round(6 * root.density))
    readonly property int spaceMedium: Math.max(6, Math.round(10 * root.density))
    readonly property int spaceLarge: Math.max(10, Math.round(16 * root.density))

    readonly property var presets: ({
        iris: { fill: 1.0, shape: 1.0, textStrong: 0.82, textSecondary: 0.62, textTertiary: 0.40,
            subtext: "#aeaeb2", muted: "#8e8e93", hairline: "#262628", hairlineStrong: "#48484a" },
        soft: { fill: 0.78, shape: 1.22, textStrong: 0.78, textSecondary: 0.58, textTertiary: 0.36,
            subtext: "#a1a1a6", muted: "#838388", hairline: "#1f1f21", hairlineStrong: "#3a3a3c" },
        crisp: { fill: 1.12, shape: 0.7, textStrong: 0.86, textSecondary: 0.66, textTertiary: 0.42,
            subtext: "#b4b4b9", muted: "#929297", hairline: "#2c2c2e", hairlineStrong: "#545456" },
        round: { fill: 0.9, shape: 1.5, textStrong: 0.8, textSecondary: 0.6, textTertiary: 0.38,
            subtext: "#a8a8ad", muted: "#8a8a8f", hairline: "#222224", hairlineStrong: "#404042" },
        angular: { fill: 1.08, shape: 0.42, textStrong: 0.86, textSecondary: 0.64, textTertiary: 0.42,
            subtext: "#b0b0b5", muted: "#909095", hairline: "#2a2a2c", hairlineStrong: "#505052" },
        contrast: { fill: 1.6, shape: 1.0, textStrong: 0.94, textSecondary: 0.8, textTertiary: 0.6,
            subtext: "#d1d1d6", muted: "#aeaeb2", hairline: "#3a3a3c", hairlineStrong: "#6c6c70" }
    })
    readonly property string presetName: root.presets[root.appearance?.preset ?? ""] ? root.appearance.preset : "iris"
    readonly property var preset: root.presets[root.presetName]

    readonly property Instantiator bundledFaces: Instantiator {
        model: ["Light", "Regular", "Medium", "SemiBold", "Bold"].map(weight => `inter/Inter-${weight}`)
            .concat(["Light", "Regular", "Medium", "SemiBold", "Bold"].map(weight => `inter/InterDisplay-${weight}`))
            .concat(["Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold", "Black"].map(weight => `rubik/Rubik-${weight}`))
            .concat(["Light", "Regular", "Medium", "SemiBold", "Bold"].map(weight => `montserrat/Montserrat-${weight}`))
        delegate: FontLoader {
            required property string modelData
            source: Quickshell.shellPath(`assets/fonts/${modelData}.ttf`)
        }
    }
    readonly property string faceText: "Inter"
    readonly property string faceTitle: "Inter Display"
    readonly property string faceFigures: "Rubik"
    readonly property var defaultFaces: ({
        "iris.appearance.fontFamily": root.faceText,
        "iris.appearance.titleFontFamily": root.faceTitle,
        "iris.appearance.numbersFontFamily": root.faceFigures
    })
    function face(path: string, value: var): string {
        const configured = String(value ?? "")
        return configured.length > 0 ? configured : (root.defaultFaces[path] ?? root.faceText)
    }
    readonly property string fontMain: root.face("iris.appearance.fontFamily", root.appearance?.fontFamily)
    readonly property string fontTitle: root.face("iris.appearance.titleFontFamily", root.appearance?.titleFontFamily)
    // 220 font.weight bindings hang off this one. Read straight through `theme`, it is recomputed
    // every time Config is reloaded — which is every write of any key — and drags all 220 with it,
    // measured at six dropped frames per write. The name changes only when the weight really does.
    readonly property string weightName: String(root.theme?.weight ?? "regular")
    readonly property int weightShift: ({ light: -1, bold: 1 })[root.weightName] ?? 0
    readonly property var weightSteps: [Font.Light, Font.Normal, Font.Medium, Font.DemiBold, Font.Bold, Font.ExtraBold]
    function weight(base: int): int {
        const steps = root.weightSteps
        const at = steps.reduce((best, w, i) => Math.abs(w - base) < Math.abs(steps[best] - base) ? i : best, 0)
        return steps[Math.max(0, Math.min(steps.length - 1, at + root.weightShift))]
    }
    readonly property int figureWeight: ({ light: Font.Light, regular: Font.Normal })[root.appearance?.figureWeight ?? "bold"] ?? Font.Bold
    readonly property string fontNumbers: root.face("iris.appearance.numbersFontFamily", root.appearance?.numbersFontFamily)

    readonly property color canvas: Appearance.colors.colLayer0Base
    // iRiS is dark by construction. The light scheme turns its material and ink over; Ink sits between them, washi
    // and sumi, softer than white. Auto follows the system (dark or light); each scheme is tuned on its own.
    readonly property string schemeChoice: String(root.appearance?.scheme ?? "auto")
    // The colour theme in use, when the person chose one that is not the wallpaper's: it is what the apps wear.
    readonly property string colourTheme: String(ThemeService.currentTheme ?? "auto")
    // Auto: the system's dark or light, and Ink when the apps wear the Ink theme.
    readonly property string scheme: ["dark", "ink", "light"].includes(root.schemeChoice) ? root.schemeChoice
        : root.colourTheme === "iris-ink" ? "ink" : Appearance.m3colors.darkmode ? "dark" : "light"
    // With a colour theme chosen and the shell asked to match it, the accent, the highlight and the material are the theme's.
    readonly property bool followsTheme: root.colourTheme !== "auto" && Boolean(root.appearance?.followTheme ?? true)
    // A paper scheme: the material is light and the ink dark.
    readonly property bool light: root.scheme !== "dark"
    readonly property bool ink: root.scheme === "ink"
    readonly property var tuneOptions: root.appearance?.tune ?? ({})
    // What the person tuned for the scheme in use, as primitives so a config write that changes none does not re-run bindings.
    // Tone, colour strength and widget colour are solved into the palette (IrisWashi); these remain for what is not colour.
    readonly property int tone: Math.max(-30, Math.min(30, Number(root.tuneOptions?.[root.scheme]?.tone ?? 0)))
    readonly property bool lumeOn: Boolean(root.tuneOptions?.[root.scheme]?.lume ?? (root.scheme !== "dark"))
    // How colourful the desktop widgets read in this scheme, 40..160 %: their data colours (solved) and their glass.
    readonly property real widgetColour: Math.max(40, Math.min(160, Number(root.tuneOptions?.[root.scheme]?.widgets ?? (root.ink ? 120 : root.light ? 110 : 100)))) / 100
    function toned(c: color): color {
        if (root.tone === 0) return c
        return Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, Math.max(0, Math.min(1, c.hslLightness + root.tone / 100)), c.a)
    }

    // --- The palette ------------------------------------------------------------------------------------------------
    // Every colour role below comes from one solve (scripts/colors/washi through IrisWashi): papers, ink, accent,
    // highlight, status, identity and widget data for each scheme, each held to its contrast on every ground of the
    // material in use. Surfaces consume these roles as they are; glass and Lume only decide how thick the paper is.
    readonly property var washi: IrisWashi.palette(root.scheme)
    readonly property var washiDark: IrisWashi.palette("dark")
    readonly property var washiLight: IrisWashi.palette("light")
    function role(name: string, fallback: string): color { return Qt.color(root.washi?.[name] ?? fallback) }

    // A tonal container of any colour and the same hue as ink on it (Material's filled tonal): the calm way to say "on".
    function containerOf(c: color): color { return ColorUtils.mix(root.surfaceOpaque, c, root.light ? 0.8 : 0.72) }
    function onContainerOf(c: color): color {
        return Lume.mark(c, Math.pow(ColorUtils.relativeLuminance(root.containerOf(c)), 1 / 2.2), 0, root.light, 4.5)
    }
    // Any colour a widget or a section names stands for one of the identity hues: the nearest, as this scheme solved it.
    function identityOf(c: color): color {
        const seed = Qt.color(c)
        if (!seed.valid || seed.hslHue < 0 || seed.hslSaturation < 0.1) return root.identity.gray
        let best = "blue", bestDistance = 2
        for (const name in root.identityHues) {
            const d = Math.abs(root.identityHues[name] - seed.hslHue)
            const distance = Math.min(d, 1 - d)
            if (distance < bestDistance) { bestDistance = distance; best = name }
        }
        return root.identity[best]
    }
    // iris-literal: the HSL hue each identity colour is known by, to map a named colour onto the palette.
    readonly property var identityHues: ({ red: 0.01, orange: 0.09, yellow: 0.14, green: 0.37, teal: 0.52, sky: 0.55,
        blue: 0.6, indigo: 0.67, purple: 0.78, pink: 0.95 })
    function materialSwatch(name: string): color { return Qt.color(root.washi?.materials?.[name] ?? "#000000") }
    readonly property string materialName: root.followsTheme ? "theme" : String(root.theme?.surface ?? "black")
    // What each scheme calls its materials (Settings, the previews): the three stored names stay black, graphite, midnight.
    readonly property var materialLabels: root.ink ? ({ black: "Washi", graphite: "Kraft", midnight: "Mist" })
        : root.light ? ({ black: "Snow", graphite: "Silver", midnight: "Sky" }) : ({ black: "Black", graphite: "Graphite", midnight: "Midnight" })
    function materialLabel(name: string): string {
        return root.materialLabels[name] ?? (name === "wallpaper" ? "Wallpaper" : name === "theme" ? "Theme" : name)
    }
    readonly property color surfaceOpaque: root.role("surface", "#000000")
    readonly property color darkSurfaceOpaque: Qt.color(root.washiDark?.materials?.[root.materialName] ?? "#000000")
    readonly property bool plainBlack: root.materialName === "black"
    readonly property color surfaceHighOpaque: root.role("surfaceHigh", "#1c1c1e")
    readonly property color surfaceHighestOpaque: root.role("surfaceHighest", "#2c2c2e")
    readonly property real tintAmount: Math.max(0, Math.min(1, Number(root.appearance?.tint ?? 0) / 100))
    readonly property color tintSeed: root.accent
    function tinted(base: color, strength: real): color {
        return root.tintAmount <= 0 ? base : ColorUtils.mix(base, root.tintSeed, 1 - strength * root.tintAmount)
    }
    readonly property color surface: root.surfaceOpaque
    readonly property color bodySurface: root.surfaceOpaque

    readonly property var glassOptions: root.appearance?.glass ?? ({})
    // Lume: with it on for the scheme, bodies are frost the wallpaper shows through, as thick as reading needs, unless the
    // person keeps them solid. A Glass mode they chose stands.
    readonly property string glassRequested: ["wallpaper", "compositor"].includes(String(root.glassOptions?.mode ?? ""))
        ? root.glassOptions.mode : root.lumeOn ? "wallpaper" : "off"
    readonly property bool glassy: root.glassRequested !== "off" && Appearance.effectsEnabled
    readonly property bool menuCompact: String(root.appearance?.surfaces?.menus?.density ?? "compact") === "compact"
    readonly property bool glassCompositor: root.glassy && root.glassRequested === "compositor" && Appearance.compositorBlurActive
        && IrisCompositorBlur.usable
    readonly property bool glassWallpaper: root.glassy && !root.glassCompositor
    readonly property real glassBlurAmount: Math.max(0, Math.min(1, Number(root.glassOptions?.blur ?? 100) / 100))
    // Solved at the panel's 7:1 so secondary ink still reads on the worst part; the chosen tint is a floor.
    readonly property real wallpaperGlassTint: {
        const chosen = Math.max(0.12, Math.min(0.96, Number(root.glassOptions?.tint ?? 58) / 100))
        const needed = IrisMood.sampled ? root.legibleVeil("panel", IrisMood.luminance, IrisMood.contrast * 0.5, 1) : 0
        return Math.max(chosen, Math.min(0.9, needed))
    }
    // Under Blur with windows on the workspace what is behind is theirs: read as a mixed desktop, as Places do. The apps
    // and the accent keep the wallpaper's tint, or every window opened would regenerate every app theme. 4.5:1 there,
    // not 7: an always-thick Blur left nothing to see through.
    readonly property bool bodiesCovered: root.glassCompositor && Lume.covered(root.placeOutput)
    readonly property real glassTint: root.bodiesCovered
        ? Math.max(root.wallpaperGlassTint, Math.min(0.9, root.legibleVeil("glass", 0.72, 0.18, 1))) : root.wallpaperGlassTint
    // What the apps wear: the paper itself, solved with the shell's palette (IrisWashi `apps`). Frost over the wallpaper
    // changes with every window behind it; an app window is opaque, so it wears the paper the frost is held to.
    readonly property string appsOutput: String(Quickshell.screens[0]?.name ?? "")
    readonly property bool appsSurfaceReady: true
    readonly property color appsSurface: root.surfaceOpaque
    readonly property color bodyTint: root.glassy ? ColorUtils.applyAlpha(root.surfaceOpaque, root.glassTint) : root.bodySurface
    readonly property color bodyFill: root.glassy ? Qt.color("transparent") : root.bodySurface
    readonly property color bodyScrim: root.bodyTint
    // iris-literal: the field paints every body with its own soft edge; an opaque chassis on top drew a harder, stair-stepped one. Not 0: a transparent ClippingRectangle stops painting.
    readonly property color bodyClip: Qt.rgba(0, 0, 0, 0.004)
    readonly property color placeSurface: root.glassy ? ColorUtils.applyAlpha(root.surfaceOpaque, root.glassTint) : root.surface
    readonly property real glassLip: 0
    readonly property bool afterglow: String(root.appearance?.texture ?? "solid") === "afterglow"
    readonly property var afterglowOptions: root.appearance?.afterglow ?? ({})
    function afterglowPercent(name: string, fallback: real): real {
        const value = Number(root.afterglowOptions?.[name] ?? fallback)
        return Math.max(0, Math.min(100, isNaN(value) ? fallback : value)) / 100
    }
    // iris-literal: each grade is a fixed colour grade (shadow hue, key light, bloom), not a theme colour.
    readonly property var afterglowGrades: ({
        dusk: { label: "Dusk", shadow: "#0f4a42", light: "#ffbe73", bloom: "#ff9442" },
        cyber: { label: "Cyber", shadow: "#0d2f66", light: "#cfefff", bloom: "#55c8ff" },
        fog: { label: "Fog", shadow: "#33402a", light: "#e6efc4", bloom: "#bcd98c" }
    })
    readonly property string afterglowGrade: ["dusk", "cyber", "fog", "wallpaper"].includes(String(root.afterglowOptions?.grade ?? ""))
        ? root.afterglowOptions.grade : "dusk"
    function afterglowColours(grade: string): var {
        if (grade !== "wallpaper") return root.afterglowGrades[grade] ?? root.afterglowGrades.dusk
        const seed = Qt.color(Appearance.wallpaperDominantColor)
        const hue = seed.hslHue < 0 ? 0.5 : seed.hslHue
        return { shadow: Qt.hsla((hue + 0.5) % 1, 0.62, 0.17, 1), light: Qt.hsla(hue, 0.85, 0.8, 1),
            bloom: root.vividHighlight(seed, root.afterglowGrades.dusk.bloom) }
    }
    readonly property var afterglowPalette: root.afterglowColours(root.afterglowGrade)
    readonly property real afterglowAtmosphere: root.afterglowPercent("atmosphere", 60)
    readonly property real afterglowChrome: root.afterglowPercent("chrome", 65)
    readonly property real afterglowBloom: root.afterglowPercent("bloom", 50)
    readonly property real afterglowSignal: root.afterglowPercent("signal", 35)
    readonly property real afterglowBloomRadius: Math.round(9 * root.density)
    // How far past a silhouette the field draws: the bloom's tail.
    readonly property real afterglowReach: root.afterglow && !root.light && root.afterglowBloom > 0 ? 3.5 * root.afterglowBloomRadius : 0
    readonly property bool afterglowWallpaper: root.afterglow && (root.afterglowOptions?.wallpaper ?? true)
    function colourVector(c: color, w: real): vector4d { return Qt.vector4d(c.r, c.g, c.b, w) }
    readonly property vector4d afterglowMix: Qt.vector4d(root.afterglow ? 1 : 0, root.afterglowChrome, root.afterglowBloom, root.afterglowSignal)
    readonly property vector4d afterglowShadow: root.colourVector(Qt.color(root.afterglowPalette.shadow), root.light ? 1 : 0)
    readonly property vector4d afterglowLight: root.colourVector(Qt.color(root.afterglowPalette.light), root.afterglowAtmosphere)
    readonly property vector4d afterglowBloomInk: root.colourVector(Qt.color(root.afterglowPalette.bloom), root.afterglowBloomRadius)
    readonly property vector4d afterglowShape: Qt.vector4d(Math.round(8 * root.density), 3, 1.25 * root.density, 0)
    // Light leak (DESIGN §0.3): analog light on film. One light per output exposes the bodies (a grain gradient of the
    // grade inside, a burn on the rim it enters by), the plates the field does not draw (IrisLeakPlate) and the wallpaper
    // (IrisLeakWallpaper), so all of it is one exposure.
    readonly property bool leak: String(root.appearance?.texture ?? "solid") === "leak"
    // The field draws the material with a texture: groups and fills go sheer so it shows through them.
    readonly property bool textured: root.afterglow || root.leak
    readonly property var leakOptions: root.appearance?.leak ?? ({})
    function leakPercent(name: string, fallback: real): real {
        const value = Number(root.leakOptions?.[name] ?? fallback)
        return Math.max(0, Math.min(100, isNaN(value) ? fallback : value)) / 100
    }
    // iris-literal: each grade is a fixed film colour: five stops from its warm end to its cool end, the white its
    // hottest light runs to, and the glow that stands for it (wallpaperLight).
    readonly property var leakGrades: ({
        prism: { label: "Prism", core: "#fff6ea", glow: "#b48cff", stops: ["#ff5a3c", "#ffcf6b", "#d8fbff", "#4f86ff", "#a35dff"] },
        ember: { label: "Ember", core: "#fff0d4", glow: "#ff9a3c", stops: ["#fff0d4", "#ffb25a", "#f2581f", "#a3241a", "#3d0f0f"] },
        orchid: { label: "Orchid", core: "#ffe6f5", glow: "#ff5fb8", stops: ["#ffd0ee", "#ff6cc4", "#e0369c", "#7a3dff", "#2b2bd0"] },
        polaroid: { label: "Polaroid", core: "#fff4dc", glow: "#ff9e7a", stops: ["#fff4dc", "#ffbf78", "#ff6aa0", "#55cfff", "#3567e0"] }
    })
    readonly property string leakGrade: ["prism", "ember", "orchid", "polaroid", "accent", "wallpaper"].includes(String(root.leakOptions?.grade ?? ""))
        ? root.leakOptions.grade : "prism"
    function leakColours(grade: string): var {
        if (grade === "accent") {
            // The highlight's hue at the warm end, the accent's at the cool end, the arc between them pale in the middle:
            // the film takes the theme's two colours at fixed strengths, so it reads the same in every scheme.
            const a = Qt.color(root.accent)
            const h = Qt.color(root.secondaryAccent)
            const cool = a.hslHue < 0 ? 0.62 : a.hslHue
            const warm = h.hslHue < 0 ? (cool + 0.12) % 1 : h.hslHue
            const arc = ((cool - warm + 1.5) % 1) - 0.5
            const hue = (t, s, l) => Qt.hsla((warm + arc * t + 1) % 1, s, l, 1)
            return { core: hue(0, 0.7, 0.95), glow: hue(1, 0.85, 0.66),
                stops: [hue(0, 0.9, 0.62), hue(0.15, 0.9, 0.74), hue(0.5, 0.55, 0.88), hue(1, 0.82, 0.62), hue(1.1, 0.75, 0.46)] }
        }
        if (grade !== "wallpaper") return root.leakGrades[grade] ?? root.leakGrades.prism
        // The wallpaper's hue spread into a spectrum: warmer and paler beside it, its complement at the cool end.
        const seed = Qt.color(Appearance.wallpaperDominantColor)
        const hue = seed.hslHue < 0 ? 0.08 : seed.hslHue
        const at = (shift, s, l) => Qt.hsla((hue + shift + 1) % 1, s, l, 1)
        return { core: at(0.02, 0.7, 0.95), glow: root.vividHighlight(seed, root.leakGrades.prism.glow),
            stops: [at(-0.07, 0.9, 0.58), at(0, 0.9, 0.7), at(0.04, 0.6, 0.88), at(0.45, 0.8, 0.62), at(0.6, 0.7, 0.5)] }
    }
    readonly property var leakPalette: root.leakColours(root.leakGrade)
    // iris-literal: where the light falls, as three soft shapes: centre in the output's uv and radii in output heights
    // (`at`), rotation, intensity, a ring's width (0: filled) and how much brighter its top is (`form`), and where on the
    // grade it sits: offset, by distance, by height, across (`hue`). Each is one of the textures it comes from: Lens the
    // prismatic eye over a hot horizon, Burn a corner of film burnt by the light, Orbs grain-gradient spheres, Beam a
    // spectrum falling down one side under a stroke of light.
    readonly property var leakShapes: ({
        lens: [{ at: [0.5, 0.47, 0.6, 0.3], form: [0, 0.95, 0, 0.2], hue: [0.22, 0.62, 0.18, 0] },
            { at: [0.5, 0.53, 0.72, 0.022], form: [0, 1.4, 0, 0], hue: [0.06, 0.14, 0, 0] },
            { at: [0.5, 0.5, 0.95, 0.55], form: [0, 0.22, 0, 0], hue: [0.85, 0, 0, 0] }],
        burn: [{ at: [0.72, 0.85, 1.1, 0.32], form: [-0.45, 1.5, 0, 0], hue: [0, 0.62, 0, 0] },
            { at: [0.95, 0.15, 0.5, 0.4], form: [0.3, 0.6, 0, 0], hue: [0.35, 0.4, 0, 0] },
            { at: [0.1, 0, 0.7, 0.45], form: [0, 0.35, 0, 0], hue: [0.7, 0.25, 0, 0] }],
        orbs: [{ at: [0.36, 0.48, 0.42, 0.42], form: [0, 1.15, 0, 0], hue: [0.18, 0.7, 0, 0] },
            { at: [0.68, 0.66, 0.2, 0.2], form: [0, 0.95, 0, 0], hue: [0.15, 0.7, 0, 0] },
            { at: [0.62, 0.18, 0.3, 0.22], form: [0, 0.45, 0, 0], hue: [0.55, 0.4, 0, 0] }],
        beam: [{ at: [0.8, 0.45, 0.06, 1.0], form: [0.05, 1.3, 0, 0], hue: [0.3, 0.1, 0, 0.5] },
            { at: [0.28, 0.09, 0.42, 0.05], form: [-0.06, 1.1, 0, 0], hue: [0.5, 0, 0, 0.45] },
            { at: [0.22, 1.0, 0.6, 0.28], form: [0, 0.8, 0, 0], hue: [0.1, 0.5, 0, 0.25] }]
    })
    readonly property string leakShapeName: ["lens", "burn", "orbs", "beam"].includes(String(root.leakOptions?.shape ?? ""))
        ? root.leakOptions.shape : "lens"
    readonly property var leakSources: root.leakShapes[root.leakShapeName]
    // Where the person moved the light (Light leak › Position, or a drag in its preview): the whole shape shifts, in
    // fractions of the output, so a preset keeps its composition.
    function leakAxis(name: string): real {
        const value = Number(root.leakOptions?.[name] ?? 0)
        return Math.max(-50, Math.min(50, isNaN(value) ? 0 : value)) / 100
    }
    // Transient, never persisted: the light where a drag in the Settings preview holds it, so the desktop follows the
    // drag; the preview writes x/y once on release and clears it.
    property var leakHeld: null
    readonly property real leakOffsetX: root.leakHeld ? root.leakHeld.x : root.leakAxis("x")
    readonly property real leakOffsetY: root.leakHeld ? root.leakHeld.y : root.leakAxis("y")
    function leakSource(index: int, key: string): vector4d {
        const v = root.leakSources[index][key]
        return key === "at" ? Qt.vector4d(v[0] + root.leakOffsetX, v[1] + root.leakOffsetY, v[2], v[3])
            : Qt.vector4d(v[0], v[1], v[2], v[3])
    }
    readonly property real leakLight: root.leakPercent("light", 60)
    readonly property real leakSpill: root.leakPercent("spill", 55)
    readonly property real leakPrism: root.leakPercent("prism", 50)
    readonly property real leakGrain: root.leakPercent("grain", 55)
    readonly property real leakStreaks: root.leakPercent("streaks", 15)
    readonly property real leakWallpaperAmount: root.leakPercent("wallpaper", 50)
    // How strongly the frame's band is exposed (blended into the bodies welded to it) and the desktop widgets' plates.
    readonly property real leakFrame: root.leakPercent("frame", 100)
    readonly property real leakWidgets: root.leakPercent("widgets", 100)
    // The film's grain in pixels before density; dust and bokeh 0..2 (1 as designed); the lens's corners and the film
    // gate on or off; a new picture developing as a Polaroid does.
    readonly property real leakGrainSize: {
        const value = Number(root.leakOptions?.grainSize ?? 1.6)
        return Math.max(1, Math.min(4, isNaN(value) ? 1.6 : value))
    }
    readonly property real leakDust: {
        const value = Number(root.leakOptions?.dust ?? 100)
        return Math.max(0, Math.min(200, isNaN(value) ? 100 : value)) / 100
    }
    readonly property real leakGate: (root.leakOptions?.gate ?? true) ? 1 : 0
    readonly property bool leakDevelop: root.leakOptions?.develop ?? true
    // Picture: the wallpaper exposed by the leak. Light: the darkroom and the light alone, the texture itself.
    readonly property string leakBackdrop: String(root.leakOptions?.backdrop ?? "picture") === "light" ? "light" : "picture"
    readonly property bool leakWallpaper: root.leak && (root.leakBackdrop === "light" || root.leakWallpaperAmount > 0)
    // IrisLeakWallpaper's leakMix: x how much of the picture shows, y how strongly it is exposed.
    readonly property vector4d leakWallpaperMix: Qt.vector4d(root.leakBackdrop === "light" ? 0 : 1, root.leakWallpaperAmount,
        root.leakSpill, root.leakPrism)
    readonly property real leakSpillRadius: Math.round(14 * root.density)
    // How far past a silhouette the field draws: where the spill's window ends (IrisField.frag).
    readonly property real leakReach: root.leak && root.leakSpill > 0 ? Math.ceil(3.8 * root.leakSpillRadius) : 0
    readonly property vector4d leakMix: Qt.vector4d(root.leak ? 1 : 0, root.leakLight, root.leakSpill, root.leakPrism)
    readonly property vector4d leakFilm: Qt.vector4d(root.leakGrain, root.leakStreaks, Math.max(1, root.leakGrainSize * root.density), root.leakSpillRadius)
    // IrisField's leakShape: x the burn's depth at the rim facing the light (one for every body), y the band's share of
    // the spill, z the frame's exposure.
    readonly property vector4d leakBody: Qt.vector4d(Math.round(6 * root.density), 0.6, root.leakFrame, 0)
    readonly property vector4d leakStop0: root.colourVector(Qt.color(root.leakPalette.stops[0]), root.light ? 1 : 0)
    readonly property vector4d leakStop1: root.colourVector(Qt.color(root.leakPalette.stops[1]), 0)
    readonly property vector4d leakStop2: root.colourVector(Qt.color(root.leakPalette.stops[2]), 0)
    readonly property vector4d leakStop3: root.colourVector(Qt.color(root.leakPalette.stops[3]), 0)
    readonly property vector4d leakStop4: root.colourVector(Qt.color(root.leakPalette.stops[4]), 0)
    readonly property vector4d leakCore: root.colourVector(Qt.color(root.leakPalette.core), 0)
    readonly property vector4d leakAt0: root.leakSource(0, "at")
    readonly property vector4d leakAt1: root.leakSource(1, "at")
    readonly property vector4d leakAt2: root.leakSource(2, "at")
    readonly property vector4d leakForm0: root.leakSource(0, "form")
    readonly property vector4d leakForm1: root.leakSource(1, "form")
    readonly property vector4d leakForm2: root.leakSource(2, "form")
    readonly property vector4d leakHue0: root.leakSource(0, "hue")
    readonly property vector4d leakHue1: root.leakSource(1, "hue")
    readonly property vector4d leakHue2: root.leakSource(2, "hue")
    // The cut edge of Blur glass (IrisField.frag): lit where it faces up, a line elsewhere.
    readonly property real glassEdgeLight: Math.max(0, Math.min(1, Number(root.glassOptions?.edgeLight ?? 34) / 100))
    readonly property real glassEdgeLine: Math.max(0, Math.min(0.6, Number(root.glassOptions?.edgeLine ?? 10) / 100))
    readonly property real glassEdgeWidth: Math.max(0.5, Math.min(3, Number(root.glassOptions?.edgeWidth ?? 1.5)))
    readonly property color glassEdgeColour: {
        const name = String(root.glassOptions?.edgeColour ?? "scene")
        if (name === "white") return Qt.rgba(1, 1, 1, 1)
        if (name === "accent") return root.accent
        if (name === "highlight") return root.secondaryAccent
        const l = root.wallpaperLight
        return Qt.rgba(l.r * 0.45 + 0.55, l.g * 0.45 + 0.55, l.b * 0.45 + 0.55, 1)
    }
    readonly property real wallpaperVeil: IrisMood.sampled
        ? Math.max(0.22, Math.min(0.72, root.legibleVeil("glass", IrisMood.luminance, IrisMood.contrast * 0.5, 0.6))) : 0.22
    // A lit layer on glass: on paper, lit is lighter than the frost (the bleached washi of Light), never a grey film over it.
    readonly property color litLayer: root.light ? ColorUtils.mix(root.surfaceOpaque, Qt.color(root.washiLight?.materials?.black ?? "#ffffff"), root.ink ? 0.45 : 0.25) : root.fillInk
    // On paper a group is a faint well of the ink, the same step the solid ramp takes (washi darkens, it never greys);
    // at night a faint lift of the ink. Sheer over glass and over a textured material (Afterglow, Light leak).
    readonly property bool paperWhite: root.light && root.surfaceOpaque.hslLightness > 0.93
    readonly property color surfaceHigh: root.glassy || root.textured
        ? ColorUtils.applyAlpha(root.light ? root.text : root.fillInk, root.fillAlpha(root.light ? 0.06 : 0.07))
        : root.tinted(root.surfaceHighOpaque, 0.16)
    readonly property color surfaceHighest: root.glassy || root.textured
        ? ColorUtils.applyAlpha(root.light ? root.text : root.fillInk, root.fillAlpha(root.light ? 0.1 : 0.12))
        : root.tinted(root.surfaceHighestOpaque, 0.2)
    // What sits raised on a group (a segmented thumb): the brighter step in the dark, a lit plate on paper.
    readonly property color raised: root.light ? ColorUtils.applyAlpha(root.litLayer, root.glassy ? 0.86 : 1) : root.fillHover
    readonly property color field: root.surfaceHighest
    // Sumi on paper, paper white at night: the paper's own hue, 7:1 on its deepest group.
    readonly property color text: root.role("text", "#f5f5f7")
    readonly property color quietInk: root.text
    readonly property color subtext: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.78, root.preset.textStrong - 0.02), 0.9))
    readonly property color muted: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.64, root.preset.textSecondary + 0.04), 0.8))
    // A group's caption: secondary ink, as every other caption.
    readonly property color label: root.subtext
    // A colour picked from a wallpaper or artwork for light and glow (never for text): saturated and mid-bright.
    function vividHighlight(seed, fallback): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.1) return fallback
        return Qt.hsla(c.hslHue, Math.max(0.62, Math.min(0.95, c.hslSaturation + 0.2)),
            Math.max(0.54, Math.min(0.66, c.hslLightness)), 1)
    }
    // The paper's level as Lume reads it: what a colour blended at runtime (anime palettes, a tint) is solved against.
    readonly property real markLevel: Math.pow(ColorUtils.relativeLuminance(root.surfaceHighestOpaque), 1 / 2.2)
    function readableAccent(c: color): color { return Lume.mark(c, root.markLevel, 0, root.light, 4.5) }
    function readableHighlight(c: color): color { return Lume.mark(c, root.markLevel, 0, root.light, 3) }
    readonly property var widgetPaletteNames: ["wallpaper", "system", "spectrum", "mono"]
    // Data in widgets (rings, bars, figures): three colours of the identity band, solved with the palette. The
    // vibrance setting is part of the solve (iris.widgets.vibrance).
    function widgetPalette(name: string, vibrance: real): var {
        const set = root.washi?.widgets?.[name] ?? root.washi?.widgets?.wallpaper ?? []
        return [0, 1, 2].map(i => Qt.color(set[i] ?? root.accent))
    }
    // Swatches for Settings: each choice as this scheme would solve it.
    readonly property var accents: root.washi?.accents ?? ({})
    readonly property var highlights: root.washi?.highlights ?? ({})
    // A choice as this scheme would solve it, for previews of looks that are not in use (saved themes).
    // A custom hue other than the one in use is not in the palette: Lume solves it the same way, close to the solver.
    function accentFrom(choice: string, hue: real): color {
        if (choice === "custom" && Number(hue) !== Number(root.appearance?.theme?.accentHue ?? 212))
            return root.readableAccent(Qt.hsla(root.wrapHue(hue, 212), 0.7, 0.5, 1))
        return Qt.color(root.accents[choice] ?? root.accents.blue ?? "#a8c7fa")
    }
    function highlightFrom(choice: string, hue: real, accent: color): color {
        if (choice === "accent") return accent
        if (choice === "custom" && Number(hue) !== Number(root.appearance?.theme?.highlightHue ?? 32))
            return root.readableHighlight(Qt.hsla(root.wrapHue(hue, 32), 0.92, 0.58, 1))
        return Qt.color(root.highlights[choice] ?? root.highlights.orange ?? "#ff9f0a")
    }
    readonly property var animePalettes: ({
        sakura: { label: "Sakura", accent: "#f2a7d6", highlight: "#ff86b4" },
        "neo-tokyo": { label: "Neo Tokyo", accent: "#4fd8ec", highlight: "#ff4fa3" },
        "unit-01": { label: "Unit-01", accent: "#b39ddb", highlight: "#8fd06a" },
        "magical-girl": { label: "Magical Girl", accent: "#ff6b8a", highlight: "#ffca5c" },
        "spirit-forest": { label: "Spirit Forest", accent: "#5fd39a", highlight: "#f0b95c" }
    })
    readonly property string animeDefaultPalette: "sakura"
    function animePaletteEntry(palette: string): var {
        const name = String(palette ?? "")
        return Object.prototype.hasOwnProperty.call(root.animePalettes, name)
            ? root.animePalettes[name] : root.animePalettes[root.animeDefaultPalette]
    }
    // An anime palette pulls the solved colour toward its own, then is solved again: it never costs legibility.
    function animeBlend(base: color, seed: color, strength: real): color {
        const raw = Number(strength)
        const t = isNaN(raw) ? 0 : Math.max(0, Math.min(1, raw))
        return t <= 0 ? base : ColorUtils.mix(base, seed, 1 - t)
    }
    function animeAccent(base: color, palette: string, strength: real): color {
        return root.readableAccent(root.animeBlend(base, Qt.color(root.animePaletteEntry(palette).accent), strength))
    }
    function animeHighlight(base: color, palette: string, strength: real): color {
        return root.readableHighlight(root.animeBlend(base, Qt.color(root.animePaletteEntry(palette).highlight), strength))
    }
    readonly property var animeLayer: root.appearance?.anime ?? ({})
    readonly property bool animeEnabled: Boolean(root.animeLayer?.enabled ?? false)
    readonly property string animePaletteName: {
        const name = String(root.animeLayer?.palette ?? root.animeDefaultPalette)
        return Object.prototype.hasOwnProperty.call(root.animePalettes, name) ? name : root.animeDefaultPalette
    }
    readonly property real animeStrength: {
        const raw = Number(root.animeLayer?.strength ?? 0)
        return isNaN(raw) ? 0 : Math.max(0, Math.min(1, raw / 100))
    }
    readonly property bool animeHighlightOn: Boolean(root.animeLayer?.highlight ?? false)
    // The accent: actions, selection, links, live marks. 4.5:1 on every ground, and on paper a fill under white ink.
    readonly property color baseAccent: root.accentFrom(root.followsTheme ? "theme" : String(root.appearance?.accent ?? "blue"), root.appearance?.theme?.accentHue ?? 212)
    readonly property color accent: root.animeEnabled
        ? root.animeAccent(root.baseAccent, root.animePaletteName, root.animeStrength) : root.baseAccent
    readonly property color inkOnAccent: root.animeEnabled ? root.onTintFor(root.accent) : root.role("onAccent", "#101318")
    // Colour over imagery (the lock, artwork veils), which stays dark in every scheme: the night palette's roles.
    readonly property color accentOnMedia: root.animeEnabled ? Lume.mark(root.accent, 0.35, 0, false, 3) : Qt.color(root.washiDark?.accent ?? "#a8c7fa")
    readonly property color highlightOnMedia: Qt.color(root.washiDark?.highlight ?? "#ff9f0a")
    // Where you are: the accent's tonal container, and the accent's hue as ink on it.
    // A filled accent under the pointer: a tenth of its own ink over it.
    readonly property color accentHover: ColorUtils.mix(root.accent, root.inkOnAccent, 0.9)
    // The lit top of a tile's gradient (squircle icons, section marks): one step for every tile.
    function tileTop(c: color): color { return Qt.lighter(c, 1.18) }
    readonly property color accentContainer: root.role("accentContainer", "#1f3a5f")
    readonly property color inkOnAccentContainer: root.role("onAccentContainer", "#d6e3ff")
    // The highlight: the glanced detail (a clock separator, a day number, a timer). A figure: 3:1 on every ground.
    readonly property color baseSecondaryAccent: root.highlightFrom(root.followsTheme ? "theme" : String(root.appearance?.highlight ?? "orange"), root.appearance?.theme?.highlightHue ?? 32, root.baseAccent)
    readonly property color secondaryAccent: {
        const base = root.baseSecondaryAccent
        return root.animeEnabled && root.animeHighlightOn
            ? root.animeHighlight(base, root.animePaletteName, root.animeStrength) : base
    }
    // A wallpaper or theme accent already is the apps' palette.
    readonly property bool appsShareAccent: !root.followsTheme && Boolean(root.appearance?.accentForApps ?? true)
        && !["theme", "wallpaper"].includes(String(root.appearance?.accent ?? "blue"))
    readonly property color appsAccent: root.baseAccent
    readonly property string auraName: ["off", "subtle", "vivid"].includes(root.appearance?.aura ?? "")
        ? root.appearance.aura : "subtle"
    readonly property real auraStrength: ({ off: 0, subtle: 0.2, vivid: 0.36 })[root.auraName]
    readonly property color wallpaperLight: root.afterglow ? root.vividHighlight(Qt.color(root.afterglowPalette.bloom), root.accent)
        : root.leak ? root.vividHighlight(Qt.color(root.leakPalette.glow), root.accent)
        : root.vividHighlight(Appearance.wallpaperDominantColor, root.vividHighlight(Appearance.colors.colPrimary, root.accent))
    function surfaceWidth(id: string, fallback: int): int {
        const width = Number(root.appearance?.surfaces?.[id]?.width ?? 0)
        return width > 0 ? Math.round(width * root.density) : fallback
    }
    readonly property int lightContour: Math.max(4, Math.round(6 * root.density))
    readonly property int lightJoinContour: root.lightContour + Math.round(Math.min(root.fuseDeep, 30 * root.density) / 3)
    readonly property int lightReach: Math.round(92 * root.density * root.tweak("lightReach", 0.5, 3))
    function aura(light: color): color { return ColorUtils.applyAlpha(light, root.auraStrength * light.a) }
    function auraFading(light: color): color { return ColorUtils.applyAlpha(light, root.auraStrength * light.a * 0.35) }
    function skyLight(glyph: string): color {
        switch (glyph) {
        case "clear_day": return root.identity.orange
        case "partly_cloudy_day": return root.identity.sky
        case "cloud": case "foggy": return root.identity.gray
        case "rainy": return root.identity.blue
        case "thunderstorm": return root.identity.purple
        case "weather_snowy": case "cloudy_snowing": case "weather_hail": return root.identity.sky
        case "bedtime": case "partly_cloudy_night": return root.identity.indigo
        default: return root.wallpaperLight
        }
    }
    readonly property string badgeStyle: String(root.theme?.badge ?? "alert")
    readonly property color badge: root.badgeStyle === "accent" ? root.accent
        : root.badgeStyle === "highlight" ? root.secondaryAccent
        : root.badgeStyle === "neutral" ? root.surfaceHighestOpaque
        : root.dangerFill
    readonly property color inkOnBadge: root.badgeStyle === "alert" ? root.inkOnDangerFill
        : root.badgeStyle === "neutral" ? root.text
        : root.badgeStyle === "highlight" ? root.onTintFor(root.secondaryAccent) : root.inkOnAccent
    readonly property color badgeInk: root.badgeStyle === "alert" ? root.danger
        : root.badgeStyle === "neutral" ? root.text : root.badge
    // Status: done and alert read as text (4.5:1), a warning as a mark (3:1); the same hues in every scheme.
    readonly property color success: root.role("success", "#8de0a3")
    readonly property color warning: root.role("warning", "#ffb340")
    readonly property color danger: root.role("danger", "#ff6961")
    // The night palette's red: a veil over imagery stays dark in every scheme.
    readonly property color dangerOnMedia: Qt.color(root.washiDark?.danger ?? "#ff6961")
    readonly property color inkOnDanger: root.role("onDanger", "#160000")
    // A filled alert (a badge): the shu pigment with its own ink; `danger` stays the red that reads as text.
    readonly property color dangerFill: root.role("dangerFill", "#e57766")
    readonly property color inkOnDangerFill: root.role("onDangerFill", "#22110d")
    function line(base: color): color {
        const t = root.tweak("lines", 0, 2)
        return t <= 1 ? ColorUtils.mix(base, root.surfaceOpaque, t) : ColorUtils.mix(root.text, base, (t - 1) * 0.35)
    }
    function ruleOf(reference: color): color {
        const k = Math.max(0, Math.min(1, (reference.r + reference.g + reference.b) / 3 / 0.96))
        return ColorUtils.mix(root.text, root.surfaceOpaque, k)
    }
    readonly property color hairline: root.glassy ? ColorUtils.applyAlpha(root.text, Math.min(0.3, 0.08 * root.tweak("lines", 0, 2)))
        : root.line(root.ruleOf(Qt.color(root.preset.hairline)))
    readonly property color hairlineStrong: root.glassy ? ColorUtils.applyAlpha(root.text, Math.min(0.45, 0.14 * root.tweak("lines", 0, 2)))
        : root.line(root.ruleOf(Qt.color(root.preset.hairlineStrong)))
    readonly property color selection: root.accentContainer
    readonly property color selectionHover: root.tintFillHover(root.accent)
    readonly property color selectionText: root.inkOnAccentContainer
    readonly property color scrim: Appearance.colors.colScrim

    function fillAlpha(level: real): real { return Math.min(0.5, level * root.preset.fill * root.tweak("fill", 0.3, 2)) }
    // Fills are the ink itself at low alpha: sumi in the paper's hue darkens paper in its own colour, never a grey film.
    readonly property color fillInk: root.afterglow && !root.light
        ? ColorUtils.mix(Qt.color(root.afterglowPalette.light), root.text, 0.5 * root.afterglowAtmosphere)
        : root.tinted(Qt.color(root.washi?.fillInk ?? root.text), 0.22)
    readonly property color fillQuiet: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.08))
    readonly property color fill: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.12))
    readonly property color fillHover: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.18))
    readonly property color fillActive: ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.26))
    // A strong fill (a slider's level, a scrubber) is ink, not a film: the body's hue at 60 % turned paper's levels brown.
    // On paper the strong fill is ink: at the night's 0.6 it read as a dark grey slab beside the controls; 0.46 is a pencil line.
    // A level's fill (sliders, scrubbers, the Island's levels). Dark at 0.6 read as a disabled grey beside lit tiles.
    readonly property color fillStrong: ColorUtils.applyAlpha(root.light ? root.text : root.fillInk, Math.min(0.9, (root.light ? 0.46 : 0.82) * root.preset.fill * root.tweak("fill", 0.3, 2)))
    // The palette solves the accent as text on this wash (washi.go): it stays within that, whatever Fills says.
    function tintFill(tint: color): color { return ColorUtils.applyAlpha(tint, Math.min(0.15, root.fillAlpha(0.13))) }
    // The unread part of a reading (rings, gauges): the reading's own colour, faint but present on every material.
    function trackOf(tint: color): color { return ColorUtils.applyAlpha(tint, root.fillAlpha(0.38)) }
    function tintFillHover(tint: color): color { return ColorUtils.applyAlpha(tint, root.fillAlpha(0.2)) }
    function tintBorder(tint: color): color { return ColorUtils.applyAlpha(tint, 0.7) }

    function textLevel(level: real): real { return Math.min(1, level * root.tweak("contrast", 0.6, 1.5)) }
    function inkLevel(level: real, glassFloor: real): real { return Math.max(root.textLevel(level), root.glassy ? glassFloor : 0) }
    readonly property color textStrong: ColorUtils.applyAlpha(root.text, root.textLevel(root.preset.textStrong))
    readonly property color textSecondary: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.66, root.preset.textSecondary), 0.8))
    readonly property color textTertiary: ColorUtils.applyAlpha(root.quietInk, root.inkLevel(Math.max(0.5, root.preset.textTertiary), 0.6))
    function strongOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.textLevel(root.preset.textStrong)) }
    function secondaryOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.inkLevel(Math.max(0.66, root.preset.textSecondary), 0.8)) }
    function tertiaryOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.inkLevel(Math.max(0.5, root.preset.textTertiary), 0.6)) }
    readonly property color border: ColorUtils.applyAlpha(root.text, Math.min(0.5, 0.14 * root.preset.fill * root.tweak("lines", 0, 2)))
    readonly property color borderStrong: ColorUtils.applyAlpha(root.text, Math.min(0.6, 0.28 * root.preset.fill * root.tweak("lines", 0, 2)))
    readonly property string rimTint: String(root.theme?.rimTint ?? "neutral")
    // Glass keeps its lit edge whatever this is: without it glass vanishes over a dark desktop.
    readonly property string edgeStyle: !(root.theme?.rim ?? true) || root.afterglow ? "none"
        : String(root.theme?.edges ?? "line") === "light" ? "light" : "line"
    readonly property bool edgeLit: root.edgeStyle === "light" && (root.glassEdgeLight > 0 || root.glassEdgeLine > 0)
    readonly property color rim: root.edgeStyle !== "line" ? Qt.color("transparent")
        : root.rimTint === "accent" ? ColorUtils.applyAlpha(root.accent, Math.min(0.9, 0.3 + 0.3 * root.tweak("lines", 0, 2)))
        : root.rimTint === "highlight" ? ColorUtils.applyAlpha(root.secondaryAccent, Math.min(0.9, 0.3 + 0.3 * root.tweak("lines", 0, 2)))
        : root.border
    readonly property int rimWidth: Math.max(1, Math.round(Math.max(1, Math.min(3, Number(root.theme?.rimWidth ?? 1))) * root.density))
    readonly property real glow: Math.max(0, Math.min(1, Number(root.theme?.glow ?? 0) / 100))
    readonly property color onTint: "#ffffff"
    readonly property color inkOnPale: "#101318"
    // Ink on any filled colour: white or near-black, whichever reads more (lightness alone sent white onto yellow).
    function onTintFor(tint: color): color {
        return ColorUtils.contrastRatio(root.onTint, tint) >= ColorUtils.contrastRatio(root.inkOnPale, tint) ? root.onTint : root.inkOnPale
    }

    // Content on a light backdrop (a widget over a bright wallpaper): the Island's ink turned over.
    // Near-black ink, frost instead of veil, and each accent's own hue taken deep enough to read.
    readonly property color inkOnLight: Qt.color(root.washiLight?.text ?? "#1d1d1f")
    readonly property color inkOnLightSoft: ColorUtils.applyAlpha(root.inkOnLight, 0.78)
    readonly property color inkOnLightMuted: ColorUtils.applyAlpha(root.inkOnLight, 0.62)
    readonly property color inkOnLightFaint: ColorUtils.applyAlpha(root.inkOnLight, 0.42)
    readonly property color frost: Qt.color(root.washiLight?.materials?.black ?? "#f5f5f7")
    // The light ink of a bare widget over a dark wallpaper: it does not follow the scheme, the wallpaper decides.
    readonly property color inkOnDark: Qt.color(root.washiDark?.text ?? "#f5f5f7")
    readonly property real frostShadow: 0.5
    // A colour on a light backdrop Lume has not read: its hue at 3:1 on the light frost, as every mark on paper is solved.
    function deepAccent(seed, fallback): color {
        const c = Qt.color(seed)
        if (!c.valid || c.hslHue < 0 || c.hslSaturation < 0.1) return fallback ?? root.inkOnLight
        return Lume.mark(c, Math.pow(ColorUtils.relativeLuminance(root.frost), 1 / 2.2), 0, true, 3)
    }
    // A coloured mark (state, identity, alert) on a bare backdrop Lume has read: its hue, held at `contrast` (3 for glyphs, 4.5 for figures).
    function markOn(seed: color, sample: var, darkInk: bool, contrast: real): color {
        return sample ? Lume.mark(seed, sample.level, sample.spread, darkInk, contrast) : seed
    }
    function fillQuietOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.fillAlpha(0.08)) }
    function fillOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.fillAlpha(0.12)) }
    function fillHoverOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.fillAlpha(0.18)) }
    function fillActiveOf(ink: color): color { return ColorUtils.applyAlpha(ink, root.fillAlpha(0.26)) }
    function hairlineOf(ink: color): color { return ColorUtils.applyAlpha(ink, Math.min(0.3, 0.14 * root.tweak("lines", 0, 2))) }
    // The frost a light-backdrop widget needs so its darkest patches still carry dark ink: the same
    // solve as legibleVeil, mirrored (4.5:1 glass, 3:1 transparent, floor scaled by the opacity).
    function legibleFrost(material: string, level: real, spread: real, strength: real): real {
        const legible = Lume.frost(level, spread, root.materialSpread[material] ?? 1, root.frost, root.inkOnLight,
            root.materialContrast[material] ?? 4.5, (root.materialVeil[material] ?? 0.3) * strength, 0.86)
        if (!root.light || level < 0 || strength <= 0) return legible
        return Math.max(legible, root.paperFloor(root.frost, level, strength), material === "clear" ? 0 : root.paperGlass * strength)
    }
    // A paper scheme's frost stays a light paper over a dark region (a thinner one is a grey film or takes the wallpaper's
    // hue), but it is still glass: the composite may sit a step under the paper and the frost never passes Lume's 0.86
    // cap, so the blurred wallpaper always shows. Held at the paper itself (0.95) it read as solid.
    // Glass on paper reads as frosted paper whatever the wallpaper: the least frost a legible solve allows (0.17 over a
    // mid wallpaper) left a clear pane glowing with the wallpaper's colour instead of a light widget.
    readonly property real paperGlass: 0.66
    function paperFloor(paper: color, level: real, strength: real): real {
        const paperLevel = Math.pow(ColorUtils.relativeLuminance(paper), 1 / 2.2)
        const target = (paperLevel - 0.06) * Math.min(1, strength)
        return level < target ? Math.min(0.86, (target - level) / Math.max(0.001, paperLevel - level)) : 0
    }

    readonly property color veilLight: ColorUtils.applyAlpha(root.darkSurfaceOpaque, 0.22)
    readonly property color veil: ColorUtils.applyAlpha(root.darkSurfaceOpaque, 0.42)
    readonly property color veilStrong: ColorUtils.applyAlpha(root.darkSurfaceOpaque, 0.62)
    readonly property color veilHeavy: ColorUtils.applyAlpha(root.darkSurfaceOpaque, 0.76)
    // Blurred artwork under surface text (the media tiles): the veil takes the scheme, so their ink still reads.
    readonly property color artVeil: root.light ? ColorUtils.applyAlpha(root.surfaceOpaque, 0.56) : root.veil
    readonly property color artVeilHeavy: root.light ? ColorUtils.applyAlpha(root.surfaceOpaque, 0.84) : root.veilHeavy
    function glowing(alpha: real): color {
        const ink = ColorUtils.mix(root.accent, Qt.color("black"), root.glow)
        return ColorUtils.applyAlpha(ink, Math.min(0.9, alpha * (1 + 0.4 * root.glow)))
    }
    readonly property real shadowThrough: root.glassy ? 0.4 : 1
    readonly property real shadowLight: root.ink ? 0.5 : root.light ? 0.55 : 1
    readonly property color shadow: root.glowing(Math.min(0.9, 0.55 * root.tweak("shadow", 0, 1.6)) * root.shadowThrough * root.shadowLight)
    readonly property color material: ColorUtils.applyAlpha(root.surfaceHigh, 0.68)
    readonly property color onMedia: "#ffffff"
    readonly property color onMediaSecondary: ColorUtils.applyAlpha(root.onMedia, 0.72)
    // The visualizer's one look (Now Playing › Visualizer): its drawing, how many bands, and whose colour.
    readonly property var visualizerOptions: Config.options?.iris?.player?.visualizer ?? ({})
    readonly property string visualizerStyle: ["capsules", "rise", "dots", "wave", "ring"].includes(String(root.visualizerOptions?.style ?? ""))
        ? String(root.visualizerOptions.style) : "capsules"
    readonly property int visualizerBars: Math.max(3, Math.min(9, Math.round(Number(root.visualizerOptions?.bars ?? 5))))
    readonly property string visualizerColour: String(root.visualizerOptions?.colour ?? "art")
    // The artwork's colour as a mark: its most colourful swatch, lifted to read on the Island; ink when the art has none.
    function artTintOf(colors): color {
        let best = null
        let bestScore = -1
        for (const c of (colors ?? [])) {
            const score = Math.max(0, c.hslSaturation) * (1 - Math.abs(c.hslLightness - 0.5))
            if (score > bestScore) { bestScore = score; best = c }
        }
        if (!best || best.hslSaturation < 0.14 || best.hslHue < 0) return root.text
        return Qt.hsla(best.hslHue, Math.max(0.5, best.hslSaturation), Math.max(0.64, Math.min(0.76, best.hslLightness + 0.22)), 1)
    }
    // `art` is the host's own colour (the artwork's tint on the Island), the rest are iRiS's.
    function visualizerTint(art: color): color {
        return root.visualizerColour === "accent" ? root.accent : root.visualizerColour === "highlight" ? root.secondaryAccent
            : root.visualizerColour === "ink" ? root.text : art
    }
    readonly property color onMediaTertiary: ColorUtils.applyAlpha(root.onMedia, 0.56)
    readonly property color onMediaFill: ColorUtils.applyAlpha(root.onMedia, 0.2)
    readonly property color onMediaFillHover: ColorUtils.applyAlpha(root.onMedia, 0.3)
    readonly property color mediaScrim: Qt.rgba(0, 0, 0, 0.34)
    readonly property color mediaGlass: Qt.rgba(0, 0, 0, 0.16)
    readonly property color mediaHairline: ColorUtils.applyAlpha(root.onMedia, 0.16)
    readonly property color plateShadow: root.glowing(Math.min(0.9, 0.36 * root.tweak("shadow", 0, 1.6)) * root.shadowLight)
    // A grey sky is no light: it only greyed the face. On paper the wash is half as strong, a tint and not a film.
    // On paper a face's colour is a faint pigment wash, never a lamp behind it.
    function skyWash(light: color): color { return ColorUtils.applyAlpha(light, light.hslSaturation < 0.15 ? 0 : root.light ? 0.1 : 0.46) }
    function skyWashFade(light: color): color { return ColorUtils.applyAlpha(light, 0.05) }
    readonly property color glassShadow: Qt.rgba(0, 0, 0, Math.min(0.6, 0.22 * root.tweak("shadow", 0, 1.6)) * root.shadowLight)
    readonly property real glassBlur: 1
    readonly property real glassWash: 0.55
    readonly property color clearRim: ColorUtils.applyAlpha(root.text, 0.07)
    readonly property int glassBlurMax: 48
    readonly property real glassSaturation: 0.3
    // The glass a widget shows the wallpaper through gains or loses colour with the scheme's Widget colour.
    // On paper the frost is light: a saturation boost under it glows (a lit pane of the wallpaper's colour), so it stays neutral.
    readonly property real widgetGlassSaturation: root.light ? Math.min(0, (root.widgetColour - 1) * 0.5)
        : Math.max(-1, Math.min(1, root.glassSaturation + (root.widgetColour - 1) * 0.5))
    readonly property var materialVeil: ({ glass: 0.3, clear: 0.04, panel: 0.3 })
    // "panel": a surface that is mostly reading (Settings): 7:1 for its main ink so secondary ink still reads.
    readonly property var materialContrast: ({ glass: 4.5, clear: 3, panel: 7 })
    readonly property var materialSpread: ({ glass: 1.0, clear: 1.2, panel: 1.2 })
    // Lume solves the veil (services/Lume.qml); the materials' contrast targets and floors are iRiS's.
    function legibleVeil(material: string, level: real, spread: real, strength: real): real {
        const contrast = root.materialContrast[material] ?? 4.5
        const floor = (root.materialVeil[material] ?? 0.3) * strength
        // Light: the backing is a frost and the ink dark, so the solve is the mirrored one.
        return root.light ? Math.max(Lume.frost(level, spread, root.materialSpread[material] ?? 1, root.surfaceOpaque, root.text, contrast, floor, 0.86),
                level < 0 || strength <= 0 || material === "clear" ? 0 : root.paperFloor(root.surfaceOpaque, Math.max(0, level - spread), strength),
                material === "clear" || strength <= 0 ? 0 : root.paperGlass * strength)
            : Lume.veil(level, spread, root.materialSpread[material] ?? 1, root.surfaceOpaque, root.text, contrast, floor, 0.86)
    }
    // A Place over imagery (Session) keeps its dark veil and onMedia ink in every scheme (§0.3); Lume solves how thick,
    // at the reading contrast so the secondary ink still holds. `veil` is the floor: a dark wallpaper looks as before.
    function mediaVeil(level: real, spread: real): real {
        return Lume.veil(level, spread, root.materialSpread.panel, root.darkSurfaceOpaque, root.onMedia,
            root.materialContrast.panel, root.veil.a, 0.86)
    }

    // Lume for Places: a Place keeps the glass tint the person chose and plates only its reading surfaces
    // (sidebar, cards), as thick as what sits behind it on the focused output needs. Under Blur with windows
    // open that is unknown, so it is read as a mixed desktop of windows.
    readonly property string placeOutput: String(GlobalStates.focusedScreen?.name ?? "")
    readonly property bool placeCovered: root.glassCompositor && Lume.covered(root.placeOutput)
    readonly property real placePlate: {
        if (!root.glassy) return 0
        let level = 0.72, spread = 0.18
        if (!root.placeCovered) {
            const screen = Lume.screenNamed(root.placeOutput)
            const sample = screen ? Lume.read(root.placeOutput, screen.width * 0.2, screen.height * 0.12,
                screen.width * 0.6, screen.height * 0.76) : null
            if (!sample) return 0
            level = sample.level
            spread = sample.spread
        }
        return Lume.plateOver(root.glassTint, root.legibleVeil("glass", level, spread, 0))
    }
    readonly property color readingPlate: ColorUtils.applyAlpha(root.surfaceOpaque, root.placePlate)
    readonly property color readingCard: root.glassy ? Lume.stack(root.readingPlate, root.surfaceHigh) : root.surfaceHigh
    readonly property color readingSidebar: root.glassy
        ? ColorUtils.applyAlpha(root.surfaceOpaque, Math.max(root.wallpaperVeil, root.placePlate)) : root.surfaceHigh

    // Fixed meanings (a category, a section, today): one band of lightness and chroma for every hue, solved per scheme.
    readonly property var identitySet: root.washi?.identity ?? ({})
    readonly property QtObject identity: QtObject {
        readonly property color blue: Qt.color(root.identitySet.blue ?? "#0a84ff")
        readonly property color sky: Qt.color(root.identitySet.sky ?? "#64d2ff")
        readonly property color teal: Qt.color(root.identitySet.teal ?? "#30b0c7")
        readonly property color green: Qt.color(root.identitySet.green ?? "#34c759")
        readonly property color yellow: Qt.color(root.identitySet.yellow ?? "#e0a800")
        readonly property color orange: Qt.color(root.identitySet.orange ?? "#ff9f0a")
        readonly property color red: Qt.color(root.identitySet.red ?? "#ff453a")
        readonly property color pink: Qt.color(root.identitySet.pink ?? "#ff375f")
        readonly property color indigo: Qt.color(root.identitySet.indigo ?? "#5e5ce6")
        readonly property color purple: Qt.color(root.identitySet.purple ?? "#bf5af2")
        readonly property color lavender: Qt.color(root.identitySet.lavender ?? "#b4a0ff")
        readonly property color gray: Qt.color(root.identitySet.gray ?? "#8e8e93")
    }

    function identityColor(name: string): color { return root.identity[name] ?? root.identity.lavender }

    readonly property real shapeScale: root.preset.shape * root.tweak("shape", 0.3, 1.6)
    // Large containers stop growing well before a pill, so content keeps a concentric margin.
    function corner(px: real): int {
        const cap = px >= 18 ? 1.3 : px >= 10 ? 1.4 : 1.6
        return Math.max(2, Math.round(px * Math.min(root.shapeScale, cap) * root.density))
    }
    function concentricPad(outerRadius: real, floor: real): int {
        return Math.max(Math.round(floor), Math.round(outerRadius * 0.3 + 7 * root.density))
    }
    readonly property int radiusPanel: root.corner(30)   // Control Center, Settings frame
    readonly property int radiusSheet: root.corner(26)   // Spotlight, media card, wallpaper picker
    readonly property int radiusPlate: root.corner(22)   // widget and lock plates, dialogs, blocks
    readonly property int radiusCard: root.corner(18)    // side-panel sections, menus
    readonly property int radiusTile: root.corner(14)    // grouped cards, tiles, results
    readonly property int radiusRow: root.corner(10)     // list rows, menu items, small buttons
    readonly property int radiusChip: root.corner(7)     // chips, thumbnails, small marks
    readonly property int radiusMicro: root.corner(4)    // bars inside skeletons, swatches
    readonly property real meltDepth: {
        const t = root.tweak("melt", 0, 2)
        return t <= 1 ? t : 1 + (t - 1) * 0.5
    }
    readonly property int fuse: Math.max(2, Math.round(8 * root.density * root.meltDepth))
    readonly property int fuseDeep: Math.max(4, Math.round(30 * root.density * root.meltDepth))
    readonly property real islandBandScale: Math.max(32, Math.min(64, Number(root.options?.bar?.height ?? 42))) / 42
    readonly property int fuseEdge: Math.max(8, Math.round(56 * root.density * root.islandBandScale
        * Math.max(0.2, Math.min(2, Number(root.options?.bar?.notchCurve ?? 100) / 100))))
    readonly property int weld: Math.max(2, Math.round(3 * root.density))
    function edgeFuseFor(size: real, curve: real): int {
        const scale = Math.max(32, Math.min(64, size / root.density)) / 42
        return Math.max(8, Math.round(56 * root.density * scale * Math.max(0.2, Math.min(2, curve / 100))))
    }
    readonly property string pieceShape: String(root.theme?.pieceShape ?? "circle")
    readonly property string controlPlate: {
        const value = String(root.appearance?.controlPlate ?? "none")
        return ["veil", "glass", "solid"].includes(value) ? value : "none"
    }
    readonly property bool controlPlated: root.controlPlate !== "none"
    // On paper the veil darkens in the body's ink: the dark media veil left dark plates under dark ink.
    function plateFillFor(material: string): color {
        if (material === "veil") return root.light ? ColorUtils.applyAlpha(root.fillInk, root.fillAlpha(0.2)) : root.veil
        return material === "solid" ? root.readingCard : root.fill
    }
    function profileRadius(profile: string, size: real): real {
        const half = size / 2
        if (profile === "squircle") return Math.min(half, size * 0.34 * Math.max(0.6, root.shapeScale))
        if (profile === "square") return Math.min(half, size * 0.22 * Math.max(0.6, root.shapeScale))
        return half
    }
    function pieceRadius(size: real): real { return root.profileRadius(root.pieceShape, size) }
    // Auto is what the Island and the Dock always did: a capsule when melted into the edge, the bubbles' shape when floating.
    // Linked, both take the bubbles' shape whatever their own choice.
    readonly property bool linkShapes: Boolean(root.theme?.linkShapes ?? false)
    readonly property string linkedShape: root.pieceShape === "circle" ? "round" : root.pieceShape
    readonly property string barShape: root.linkShapes ? root.linkedShape : String(root.options?.bar?.shape ?? "auto")
    readonly property string dockShape: root.linkShapes ? root.linkedShape : String(root.options?.dock?.shape ?? "auto")
    function bodyProfile(shape: string, notched: bool): string {
        if (shape === "round") return "circle"
        if (shape === "squircle" || shape === "square") return shape
        return notched ? "circle" : root.pieceShape
    }
    // A primitive, so bindings that read the open Island's corners do not re-run on every config write.
    readonly property int islandOpenCorners: Math.round(Number(root.appearance?.surfaces?.island?.radius ?? 0) * root.density)
    // An open body's corners step down with its resting ones, so a square Island opens square; a size chosen wins.
    function openedRadius(shape: string, base: real): real {
        if (root.islandOpenCorners > 0) return root.islandOpenCorners
        return shape === "square" ? base * 0.45 : shape === "squircle" ? base * 0.75 : base
    }
    function iconRadius(size: real): int { return Math.round(size * 0.26 * Math.min(1.2, root.shapeScale)) }
    // The tile pack's plates: the black and the white a plate can wear, the glyph carrying the colour.
    readonly property color plateBlackTop: root.toned("#2e2e34")
    readonly property color plateBlackBase: root.toned("#18181b")
    readonly property color plateWhiteTop: root.toned("#f8f8fb")
    readonly property color plateWhiteBase: root.toned("#e6e6ec")

    readonly property real panelPadding: Math.round(24 * root.density)
    readonly property real sectionGap: Math.round(24 * root.density)
    readonly property real controlHeight: Math.round(38 * root.density)
    readonly property real compactControlHeight: Math.round(32 * root.density)
    readonly property real headerHeight: Math.round(54 * root.typeScale)
    readonly property real accentRuleWidth: Math.round(24 * root.density)
    readonly property real accentRuleHeight: Math.max(2, Math.round(3 * root.density))

    readonly property bool motionEnabled: (root.appearance?.motion ?? true) && Appearance.animationsEnabled

    // --- Arrival: the family grows inward once the shell has its first frame ------------------
    // Boot, a reload and a family switch all end in shellEntryReady; the chassis rides this one
    // value in from slightly past the screen edges. Reduced motion arrives at once.
    property real arrival: 0
    readonly property bool arriving: root.arrival < 1
    readonly property NumberAnimation arrive: NumberAnimation {
        target: root; property: "arrival"; from: 0; to: 1
        duration: root.duration(Math.round(root.emergeDuration * 1.25))
        easing.type: Easing.BezierSpline; easing.bezierCurve: root.emergeCurve
    }
    function startArrival(): void {
        root.arrive.stop()
        if (!root.motionEnabled) { root.arrival = 1; return }
        root.arrival = 0
        root.arrive.start()
    }
    readonly property Connections arrivalGate: Connections {
        target: GlobalStates
        function onShellEntryReadyChanged(): void {
            if (GlobalStates.shellEntryReady) root.startArrival()
            else { root.arrive.stop(); root.arrival = 0 }
        }
    }
    Component.onCompleted: if (GlobalStates.shellEntryReady) root.startArrival()
    function duration(ms: int): int {
        return root.motionEnabled ? Appearance.calcEffectiveDuration(ms) : 0
    }

    readonly property var curves: ({ expressive: [0.16, 1, 0.3, 1], standard: [0.2, 0, 0, 1], gentle: [0.4, 0, 0.2, 1], swift: [0.3, 0.9, 0.2, 1], fold: [0.3, 0, 0.2, 1] })
    readonly property var directCurve: {
        const name = String(root.theme?.curve ?? "expressive")
        if (name !== "custom") return root.curves[name] ?? root.curves.expressive
        const p = root.theme?.curvePoints ?? []
        const at = (i, low, high, fallback) => Math.max(low, Math.min(high, Number(p[i] ?? fallback)))
        return [at(0, 0, 1, 0.16), at(1, -0.5, 1.5, 1), at(2, 0, 1, 0.3), at(3, -0.5, 1.5, 1)]
    }
    readonly property var morphStyles: ({
        direct: { curve: true, emerge: { response: 1.8 }, recede: { response: 1.2, curve: "fold" }, move: { response: 1 },
            rise: 0.3, span: 0.35, fall: 0.12, reveal: "drop" },
        liquid: { emerge: { response: 1.9, bounce: 0.22 }, recede: { response: 1.3, bounce: 0 }, move: { response: 1.15, bounce: 0.08 },
            rise: 0.34, span: 0.42, fall: 0.24, reveal: "drop" },
        glide: { emerge: { response: 2.1, bounce: 0 }, recede: { response: 1.5, bounce: 0 }, move: { response: 1.35, bounce: 0 },
            rise: 0.3, span: 0.5, fall: 0.28, reveal: "drop" },
        snap: { emerge: { response: 1.25, bounce: 0.06 }, recede: { response: 0.95, bounce: 0 }, move: { response: 0.85, bounce: 0 },
            rise: 0.18, span: 0.34, fall: 0.2, reveal: "fade" },
        elastic: { emerge: { response: 2.2, bounce: 0.34 }, recede: { response: 1.4, bounce: 0 }, move: { response: 1.5, bounce: 0.24 },
            rise: 0.36, span: 0.4, fall: 0.28, reveal: "inflate" },
        instant: { emerge: { response: 1, bounce: 0 }, recede: { response: 1, bounce: 0 }, move: { response: 1, bounce: 0 },
            rise: 0.01, span: 0.01, fall: 0.01, reveal: "fade" }
    })
    readonly property string morphName: root.morphStyles[root.appearance?.morph ?? ""] ? root.appearance.morph : "direct"
    readonly property var morph: root.morphStyles[root.morphName]

    readonly property string revealName: String(root.morph?.reveal ?? "curtain")
    readonly property real absorbShare: 0.55
    readonly property real pullLag: 1.8
    readonly property real dropRise: Math.max(0, Math.min(0.7, 0.06 + 0.4 * (root.tweak("contentTiming", 0.3, 1.7) - 1)))
    readonly property real dropSpan: 0.3
    readonly property bool revealDrops: root.revealName === "drop" && root.motionEnabled
    readonly property bool revealInflates: root.revealName === "inflate" && root.motionEnabled
    readonly property bool revealFades: root.revealName === "fade" || !root.motionEnabled

    readonly property int baseDuration: Math.max(100, Math.min(400, Number(root.appearance?.motionDuration ?? 220)))
    function resolveStyleSpring(style: var, entry: var, fallbackResponse: real, timeTweak: string): var {
        const response = Math.round(root.baseDuration * Math.max(0.2, Number(entry?.response ?? fallbackResponse)) * root.tweak(timeTweak, 0.4, 2.5))
        const bounce = Number(entry?.bounce ?? 0) * root.tweak("bounce", 0, 2)
        const curve = !style?.curve ? null : entry?.curve ? root.curves[entry.curve] : root.directCurve
        return { response: root.duration(response), bounce: curve ? 0 : Math.max(0, Math.min(0.6, bounce)), curve: curve }
    }
    function resolveSpring(entry: var, fallbackResponse: real, timeTweak: string): var {
        return root.resolveStyleSpring(root.morph, entry, fallbackResponse, timeTweak)
    }
    // A surface may move in a style of its own ("" follows the family). It changes timing only:
    // how content arrives stays the family's.
    function surfaceMorph(id: string): string {
        const name = String(root.appearance?.surfaces?.[id]?.morph ?? "")
        return name.length > 0 && name !== root.morphName && root.morphStyles[name] ? name : ""
    }
    readonly property var emergeSpring: root.resolveSpring(root.morph?.emerge, 1.9, "openTime")
    readonly property var recedeSpring: root.resolveSpring(root.morph?.recede, 1.3, "openTime")
    readonly property var moveSpring: root.resolveSpring(root.morph?.move, 1.15, "moveTime")
    // A surface's own material: "" follows the family's glass, "solid" or "glass" override it.
    function surfaceMaterial(id: string): string {
        const name = String(root.appearance?.surfaces?.[id]?.material ?? "")
        return name === "solid" || name === "glass" ? name : ""
    }
    // The field's per-shape `glass` value for a surface.
    function surfaceGlass(id: string): string {
        const name = root.surfaceMaterial(id)
        return name === "solid" ? "solid" : name === "glass" ? (root.glassCompositor ? "compositor" : "wallpaper") : "inherit"
    }
    function surfaceSpeed(id: string): real {
        return id.length === 0 ? 1 : Math.max(0.4, Math.min(2.5, Number(root.appearance?.surfaces?.[id]?.speed ?? 100) / 100))
    }
    function springFor(intent: string, surface: string): var {
        const own = root.surfaceMorph(surface)
        // A surface set to None appears and leaves on the next frame (IrisSpring jumps on a zero response).
        if (own === "instant") return { response: 0, bounce: 0 }
        const style = own.length > 0 ? root.morphStyles[own] : null
        const base = style
            ? (intent === "move" ? root.resolveStyleSpring(style, style.move, 1.15, "moveTime")
                : intent === "emerge" ? root.resolveStyleSpring(style, style.emerge, 1.9, "openTime")
                : root.resolveStyleSpring(style, style.recede, 1.3, "openTime"))
            : intent === "move" ? root.moveSpring : intent === "emerge" ? root.emergeSpring : root.recedeSpring
        const speed = root.surfaceSpeed(surface)
        return speed === 1 ? base : Object.assign({}, base, { response: Math.round(base.response / speed) })
    }
    function pressScale(base: real): real { return 1 - (1 - base) * root.tweak("press", 0, 2) }

    function springState(t: real, bounce: real): var {
        const w = 2 * Math.PI
        const zeta = 1 - bounce
        if (zeta < 0.9999) {
            const wd = w * Math.sqrt(1 - zeta * zeta)
            const e = Math.exp(-zeta * w * t)
            const b = -zeta * w / wd
            const c = Math.cos(wd * t), s = Math.sin(wd * t)
            const d = e * (-c + b * s)
            return { y: 1 + d, v: -zeta * w * d + e * (wd * s + b * wd * c) }
        }
        const e = Math.exp(-w * t)
        return { y: 1 - (1 + w * t) * e, v: w * w * t * e }
    }
    function springSettle(bounce: real): real {
        let last = 0
        for (let t = 0; t < 4; t += 0.004)
            if (Math.abs(root.springState(t, bounce).y - 1) >= 0.002) last = t
        return Math.max(0.4, last)
    }
    // At most ten segments: Qt 6.11 segfaults on a 12-segment BezierSpline.
    function springCurve(bounce: real): var {
        const segments = 8
        const settle = root.springSettle(bounce)
        const points = []
        for (let i = 0; i < segments; ++i) {
            const u0 = i / segments, u1 = (i + 1) / segments, h = 1 / segments
            const a = root.springState(u0 * settle, bounce)
            const last = i === segments - 1
            const b = last ? { y: 1, v: 0 } : root.springState(u1 * settle, bounce)
            points.push(u0 + h / 3, a.y + a.v * settle * h / 3, u1 - h / 3, b.y - b.v * settle * h / 3, u1, b.y)
        }
        return points
    }
    function curveOf(spring: var): var {
        return spring.curve ? spring.curve.concat([1, 1]) : root.springCurve(spring.bounce)
    }
    function durationOf(spring: var): int {
        return spring.curve ? spring.response : Math.round(spring.response * root.springSettle(spring.bounce))
    }
    function cubicBezier(curve: var, x: real): real {
        if (x <= 0) return 0
        if (x >= 1) return 1
        const cx = 3 * curve[0], bx = 3 * (curve[2] - curve[0]) - cx, ax = 1 - cx - bx
        const cy = 3 * curve[1], by = 3 * (curve[3] - curve[1]) - cy, ay = 1 - cy - by
        let t = x
        for (let i = 0; i < 8; ++i) {
            const fx = ((ax * t + bx) * t + cx) * t - x
            const d = (3 * ax * t + 2 * bx) * t + cx
            if (Math.abs(fx) < 1e-5 || Math.abs(d) < 1e-6) break
            t = Math.max(0, Math.min(1, t - fx / d))
        }
        return ((ay * t + by) * t + cy) * t
    }
    readonly property var emergeCurve: root.curveOf(root.emergeSpring)
    readonly property var recedeCurve: root.curveOf(root.recedeSpring)
    readonly property var moveCurve: root.curveOf(root.moveSpring)
    readonly property int emergeDuration: root.durationOf(root.emergeSpring)
    readonly property int recedeDuration: root.durationOf(root.recedeSpring)
    readonly property int moveDuration: root.durationOf(root.moveSpring)
    readonly property real contentRise: Math.min(0.95, Number(root.morph?.rise ?? 0.34) * root.tweak("contentTiming", 0.3, 1.7))
    readonly property real contentSpan: Math.max(0.01, Number(root.morph?.span ?? 0.42))
    readonly property real contentFall: Math.max(0.02, Number(root.morph?.fall ?? 0.24))
    function ramp(t: real, rise: real, span: real): real {
        return Math.max(0, Math.min(1, (t - rise) / Math.max(0.01, span)))
    }
    function contentAt(t: real): real { return root.ramp(t, root.contentRise, root.contentSpan) }
    // A floating body's shadow arrives with its settle, never under a shape that is still growing.
    function shadowAt(t: real): real { return Math.pow(Math.max(0, Math.min(1, t)), 4) }

    readonly property int morphDuration: root.moveDuration
    readonly property int settleDuration: root.emergeDuration
    readonly property int revealDuration: duration(140)
    readonly property int feedbackDuration: duration(100)
    readonly property int feedbackEasing: Easing.OutCubic
    readonly property var morphCurve: root.moveCurve

    // `inir iris tokens`: each key pair's contrast on the body as it is seen; over glass the worst of the wallpaper's
    // mean, darkest and brightest reading (and, under Blur, a mixed desktop of windows). Afterglow's shading is not modelled.
    function audit(): var {
        const over = (fg, bg) => Qt.rgba(fg.r * fg.a + bg.r * (1 - fg.a), fg.g * fg.a + bg.g * (1 - fg.a), fg.b * fg.a + bg.b * (1 - fg.a), 1)
        const grey = level => Qt.rgba(level, level, level, 1)
        const screen = Lume.screenNamed(root.appsOutput)
        const sample = screen ? Lume.read(root.appsOutput, 0, 0, screen.width, screen.height) : null
        const bodies = {}
        if (!root.glassy || !sample) bodies.solid = root.surfaceOpaque
        else {
            bodies.mean = over(root.bodyTint, sample.color)
            bodies.dark = over(root.bodyTint, grey(Math.max(0, sample.level - sample.spread)))
            bodies.bright = over(root.bodyTint, grey(Math.min(1, sample.level + sample.spread)))
            if (root.bodiesCovered) {
                bodies.windowsDark = over(root.bodyTint, grey(0.54))
                bodies.windowsBright = over(root.bodyTint, grey(0.9))
            }
        }
        // [ink, what it sits on (null: the body), contrast it needs]
        const pairs = {
            text: [root.text, null, 7], textSecondary: [root.textSecondary, null, 4.5], textTertiary: [root.textTertiary, null, 3],
            subtext: [root.subtext, null, 4.5], muted: [root.muted, null, 3], label: [root.label, null, 4.5],
            accentText: [root.accent, null, 4.5], highlight: [root.secondaryAccent, null, 3], success: [root.success, null, 3],
            danger: [root.danger, null, 3], textOnGroup: [root.text, root.surfaceHigh, 7],
            secondaryOnGroup: [root.textSecondary, root.surfaceHigh, 4.5], accentOnGroup: [root.accent, root.surfaceHigh, 4.5],
            accentOnTint: [root.accent, root.tintFill(root.accent), 4.5], inkOnAccent: [root.inkOnAccent, root.accent, 4.5],
            textOnReadingCard: [root.text, root.readingCard, 7], secondaryOnReadingCard: [root.textSecondary, root.readingCard, 4.5],
            inkOnBadge: [root.inkOnBadge, root.badge, 3],
            accentFill: [root.accent, null, 3], group: [root.surfaceHigh, null, 1.1], fill: [root.fill, null, 1.1],
            fillHover: [root.fillHover, null, 1.2], raised: [root.raised, root.surfaceHigh, 1.1], border: [root.border, null, 1.3],
            hairline: [root.hairline, null, 1.15]
        }
        const contrast = {}
        const fails = []
        for (const name in pairs) {
            const [ink, under, need] = pairs[name]
            let worst = 99
            for (const key in bodies) {
                const bg = under ? over(under, bodies[key]) : bodies[key]
                worst = Math.min(worst, ColorUtils.contrastRatio(over(ink, bg), bg))
            }
            contrast[name] = Math.round(worst * 100) / 100
            if (worst < need) fails.push(name + " " + contrast[name] + " < " + need)
        }
        const out = {}
        for (const key in bodies) out[key] = bodies[key].toString()
        return {
            scheme: root.scheme, material: root.materialName, glass: root.glassy ? (root.glassCompositor ? "compositor" : "wallpaper") : "off",
            texture: root.afterglow ? "afterglow:" + root.afterglowGrade : root.leak ? "leak:" + root.leakGrade + "/" + root.leakShapeName : "solid", accent: String(root.appearance?.accent ?? "blue"),
            preset: root.presetName, glassTint: Math.round(root.glassTint * 100) / 100, bodies: out, fails: fails, contrast: contrast,
            tokens: { surface: root.surfaceOpaque.toString(), surfaceHigh: root.surfaceHigh.toString(), accent: root.accent.toString(),
                highlight: root.secondaryAccent.toString(), text: root.text.toString(), textSecondary: root.textSecondary.toString(),
                fill: root.fill.toString(), border: root.border.toString(), hairline: root.hairline.toString(), readingCard: root.readingCard.toString(), appsSurface: root.appsSurface.toString(),
                appsAccent: root.appsShareAccent ? root.appsAccent.toString() : "" }
        }
    }
}
