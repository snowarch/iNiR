pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:modules/common/functions/md5.js" as MD5

Singleton {
    id: root
    property QtObject m3colors
    property QtObject animation
    property QtObject animationCurves
    property QtObject aurora
    property QtObject inir
    property QtObject angel
    property QtObject zzz
    property QtObject cookie
    property QtObject colors
    property QtObject rounding
    property QtObject font
    property QtObject sizes
    property string syntaxHighlightingTheme

    // Transparency. The quadratic functions were derived from analysis of hand-picked transparency values.
    ColorQuantizer {
        id: wallColorQuant
        property string wallpaperPath: Wallpapers.effectiveWallpaperPath
        property bool wallpaperIsVideo: wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm") || wallpaperPath.endsWith(".mkv") || wallpaperPath.endsWith(".avi") || wallpaperPath.endsWith(".mov")
        property string _videoImageSource: {
            if (!wallpaperIsVideo) return ""
            const _dep = Wallpapers.videoFirstFrames // reactive binding
            const ff = Wallpapers.getVideoFirstFramePath(wallpaperPath)
            // When first-frame becomes available, we add a cache-bust suffix so
            // ColorQuantizer reloads even if the path is identical.
            if (ff) return ff + "?ff=1"
            if (wallpaperPath) {
                Wallpapers.ensureVideoFirstFrame(wallpaperPath)
                const expected = Wallpapers._videoThumbDir + "/" + MD5.hash(wallpaperPath) + ".jpg"
                return expected + "?ff=0"
            }
            return ""
        }
        source: Qt.resolvedUrl(wallpaperIsVideo ? _videoImageSource : wallpaperPath)
        depth: 0 // 2^0 = 1 color
        rescaleSize: 10
    }
    readonly property color wallpaperDominantColor: wallColorQuant?.colors?.[0] ?? colors.colPrimary
    readonly property QtObject wallpaperBlendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor, root.colors.colPrimaryContainer, 0.8) || root.m3colors.m3secondaryContainer
    }
    property real wallpaperVibrancy: (wallColorQuant.colors[0]?.hslSaturation + wallColorQuant.colors[0]?.hslLightness) / 2
    property real autoBackgroundTransparency: { // y = 0.5768x^2 - 0.759x + 0.2896
        let x = wallpaperVibrancy
        let y = 0.5768 * (x * x) - 0.759 * (x) + 0.2896
        return Math.max(0, Math.min(0.22, y))
    }
    property real autoContentTransparency: 0.9
    
    // Transparency - respects enable toggle
    readonly property bool _transparencyEnabled: Config?.options?.appearance?.transparency?.enable ?? false
    readonly property bool _transparencyAutomatic: Config?.options?.appearance?.transparency?.automatic ?? true
    property real backgroundTransparency: _transparencyEnabled 
        ? (_transparencyAutomatic ? autoBackgroundTransparency : (Config?.options?.appearance?.transparency?.backgroundTransparency ?? 0)) 
        : 0
    property real contentTransparency: _transparencyEnabled 
        ? (_transparencyAutomatic ? autoContentTransparency : (Config?.options?.appearance?.transparency?.contentTransparency ?? 0)) 
        : 0

    // Global style - centralized style detection (reactive bindings)
    readonly property string globalStyle: Config?.options?.appearance?.globalStyle ?? "material"
    readonly property string iiMotionProfile: Config?.options?.appearance?.iiMotionProfile ?? "classic"
    readonly property bool contextualMotionProfile: iiMotionProfile === "contextual"
    readonly property bool inirEverywhere: globalStyle === "inir"
    // angelEverywhere - flagship neo-brutalism glass style (superset of aurora)
    readonly property bool angelEverywhere: globalStyle === "angel"
    // auroraEverywhere controls blur/glass backgrounds — angel inherits aurora blur
    readonly property bool auroraEverywhere: globalStyle === "aurora" || globalStyle === "angel"
    // zzzEverywhere - Zenless Zone Zero urban graphic identity (poster palette + sharp + bold)
    readonly property bool zzzEverywhere: globalStyle === "zzz"
    // cookieEverywhere - Material Expressive organic silhouettes and state morphing
    readonly property bool cookieEverywhere: globalStyle === "cookie"
    
    // Explicit surface dialects such as islands/Ricelin own their complete
    // surface. Otherwise the selected global worldview owns it. Consumers use
    // this once rather than mixing independent `island && zzz && aurora` flags.
    function surfaceDialectFor(explicitDialect: string): string {
        return explicitDialect.length > 0 ? explicitDialect : root.globalStyle
    }

    // Aurora light mode: when aurora + light theme, use ink-colored text for contrast
    // Ink colors are muted dark tones (not pure black) that work well over light/transparent backgrounds
    readonly property bool _auroraLightMode: auroraEverywhere && !(m3colors?.darkmode ?? true)

    // GameMode integration - disable effects/animations when fullscreen detected
    property bool _gameModeActive: GameMode?.active ?? false
    property bool _gameModeDisablesEffects: _gameModeActive && (GameMode?.disableEffects ?? true)
    property bool _gameModeDisablesAnimations: _gameModeActive && (GameMode?.disableAnimations ?? true)
    property bool _gameModeMinimalMode: _gameModeActive && (GameMode?.minimalMode ?? true)

    // Master switches for effects and animations
    property bool effectsEnabled: !Config.options?.performance?.lowPower && !_gameModeDisablesEffects
    property bool animationsEnabled: !_gameModeDisablesAnimations && !(Config.options?.performance?.reduceAnimations ?? false)
    property bool nativeBlurSupported: false

    Process {
        id: nativeBlurVersionProbe
        running: CompositorService?.isNiri ?? false
        command: ["niri", "--version"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/(\d+)\.(\d+)/)
                if (!match) {
                    root.nativeBlurSupported = false
                    return
                }
                const major = Number(match[1])
                const minor = Number(match[2])
                root.nativeBlurSupported = major > 26 || (major === 26 && minor >= 4)
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.nativeBlurSupported = false
        }
    }

    // Niri 26.04+ handles this request through ext-background-effect-v1. Only
    // surfaces that publish a shape-accurate Region may use this global capability.
    readonly property bool compositorBlurActive: effectsEnabled
        && (Config.options?.performance?.compositorBlur ?? true)
        && (CompositorService?.isNiri ?? false)
        && root.nativeBlurSupported

    // A surface must name the topology it actually publishes to Niri. This is
    // stronger than a boolean claim: diagnostics can identify the geometry and
    // future shapes cannot accidentally inherit compositor eligibility.
    readonly property var blurTopology: ({
        unsupported: "unsupported",
        rectangle: "rectangle",
        roundedRectangle: "rounded-rectangle",
        islandsUnion: "islands-union"
    })

    function blurTopologyExact(topology): bool {
        // Compatibility for third-party widgets written against the old helper.
        // Product call sites use the named topology values above.
        if (typeof topology === "boolean")
            return topology
        return topology === root.blurTopology.rectangle
            || topology === root.blurTopology.roundedRectangle
            || topology === root.blurTopology.islandsUnion
    }

    function blurBackendFor(area: string, topology): string {
        if (!effectsEnabled)
            return "off"
        const performance = Config.options?.performance ?? ({})
        const override = performance.blurAreas?.[area] ?? "inherit"
        const requested = override !== "inherit" ? override : (performance.blurBackend ?? "auto")
        const topologyExact = root.blurTopologyExact(topology)
        if (requested === "off" || requested === "wallpaper")
            return requested
        if (requested === "compositor")
            return compositorBlurActive && topologyExact ? "compositor" : "wallpaper"
        // Auto is fidelity-first. Native blur is an explicit backend choice,
        // never a reason to replace a style-owned wallpaper material.
        if (area === "islands" || area === "waffle")
            return "wallpaper"
        if (auroraEverywhere || angelEverywhere)
            return "wallpaper"
        if (zzzEverywhere && (Config.options?.appearance?.zzz?.glass ?? true))
            return "wallpaper"
        return "off"
    }

    function useCompositorBlur(area: string, topology): bool {
        return blurBackendFor(area, topology) === "compositor"
    }

    // Minimal mode: panels become transparent, no backgrounds, reduced visual weight
    // Components should check this to hide backgrounds/shadows during GameMode
    readonly property bool gameModeMinimal: _gameModeMinimalMode

    // ── Shell desaturation effect ──────────────────────────────────────────
    // User-toggled visual effect that desaturates/dims shell components
    readonly property var _desatConfig: Config.options?.appearance?.desaturation ?? ({})
    readonly property bool desaturationEnabled: Boolean(_desatConfig.enable)
    readonly property real desaturationSaturation: Number(_desatConfig.saturation ?? -0.7)
    readonly property real desaturationBrightness: Number(_desatConfig.brightness ?? -0.15)
    readonly property string desaturationScope: String(_desatConfig.scope ?? "all")
    // Per-component toggles (only checked when scope === "custom")
    readonly property bool desaturationBar: desaturationScope !== "custom" || Boolean(_desatConfig.bar ?? true)
    readonly property bool desaturationDock: desaturationScope !== "custom" || Boolean(_desatConfig.dock ?? true)
    readonly property bool desaturationSidebars: desaturationScope !== "custom" || Boolean(_desatConfig.sidebars ?? true)
    readonly property bool desaturationOverlays: desaturationScope !== "custom" || Boolean(_desatConfig.overlays ?? true)
    readonly property bool desaturationPopups: desaturationScope !== "custom" || Boolean(_desatConfig.popups ?? true)
    // Helper: should a given component apply the effect?
    function shouldDesaturate(component: string): bool {
        if (!desaturationEnabled) return false
        if (desaturationScope === "all") return true
        if (desaturationScope === "panels") return ["bar", "dock", "sidebars"].includes(component)
        // scope === "custom"
        switch (component) {
            case "bar": return desaturationBar
            case "dock": return desaturationDock
            case "sidebars": return desaturationSidebars
            case "overlays": return desaturationOverlays
            case "popups": return desaturationPopups
            default: return true
        }
    }

    // Style-aware hover/active fills. One source of truth so every component's hover matches the
    // active global style instead of re-implementing the zzz/angel/inir/aurora/material ternary.
    // zzz promotes one fill step (paper -> paperAlt) instead of a translucent mix, per its
    // separate-by-fill doctrine (was missing here; components used to hardcode zzz.paperAlt).
    // Cookie promotes one tonal step, like zzz: Expressive stacks plates, so a
    // hover is the next plate up, not a translucent wash of the ink over the
    // current one.
    readonly property color colLayer1Hover: cookieEverywhere ? cookie.bg2
        : zzzEverywhere ? zzz.paperAlt
        : angelEverywhere ? angel.colGlassCardHover
        : inirEverywhere ? inir.colLayer1Hover
        : auroraEverywhere ? aurora.colSubSurfaceHover
        : colors.colLayer1Hover
    readonly property color colLayer2Hover: cookieEverywhere ? cookie.bg3
        : zzzEverywhere ? zzz.bg3
        : angelEverywhere ? angel.colGlassElevatedHover
        : inirEverywhere ? inir.colLayer2Hover
        : auroraEverywhere ? aurora.colElevatedSurfaceHover
        : colors.colLayer2Hover
    // Active/pressed fills — did not exist at top level before, so click feedback
    // (RippleButton etc.) read straight from raw `colors.*`, skipping inir/zzz entirely.
    readonly property color colLayer1Active: cookieEverywhere ? cookie.bg3
        : zzzEverywhere ? zzz.bg3
        : angelEverywhere ? angel.colGlassCardActive
        : inirEverywhere ? inir.colLayer1Active
        : auroraEverywhere ? aurora.colSubSurfaceActive
        : colors.colLayer1Active

    onEffectsEnabledChanged: if (Qt.application.arguments.indexOf("--debug") !== -1) console.log("[Appearance] effectsEnabled:", effectsEnabled, "gameModeActive:", _gameModeActive)
    onAnimationsEnabledChanged: if (Qt.application.arguments.indexOf("--debug") !== -1) console.log("[Appearance] animationsEnabled:", animationsEnabled)

    // Per-category speed multipliers for the animation presets below, settings-driven.
    // 1.0 = default speed. Kept separate from raw calcEffectiveDuration(ms) call sites
    // elsewhere in the shell, which stay untouched at multiplier 1.0.
    readonly property QtObject animationSpeed: QtObject {
        readonly property real movement: Config.options?.appearance?.animationSpeed?.movement ?? 1.0
        readonly property real enterExit: Config.options?.appearance?.animationSpeed?.enterExit ?? 1.0
        readonly property real clickBounce: Config.options?.appearance?.animationSpeed?.clickBounce ?? 1.0
        readonly property real scroll: Config.options?.appearance?.animationSpeed?.scroll ?? 1.0
    }

    // Named, pickable curves for the per-category override below. Reuses the same
    // list<real> beziers the presets already fall back to — no new motion invented,
    // just made selectable. "default" (absent from this map) means: keep whatever
    // style/motion-profile-aware curve the preset already computes.
    readonly property var animationCurveLibrary: ({
        standard:          { type: Easing.BezierSpline, curve: animationCurves.standard },
        standardAccel:     { type: Easing.BezierSpline, curve: animationCurves.standardAccel },
        standardDecel:     { type: Easing.BezierSpline, curve: animationCurves.standardDecel },
        emphasized:        { type: Easing.BezierSpline, curve: animationCurves.emphasized },
        emphasizedAccel:   { type: Easing.BezierSpline, curve: animationCurves.emphasizedAccel },
        emphasizedDecel:   { type: Easing.BezierSpline, curve: animationCurves.emphasizedDecel },
        expressive:        { type: Easing.BezierSpline, curve: animationCurves.expressiveDefaultSpatial },
        expressiveEffects: { type: Easing.BezierSpline, curve: animationCurves.expressiveEffects },
        zzzOvershoot:      { type: Easing.BezierSpline, curve: animationCurves.zzzOvershoot },
        zzzSnap:           { type: Easing.BezierSpline, curve: animationCurves.zzzSnap },
        linear:            { type: Easing.Linear, curve: [] }
    })
    function _curveOverride(category) {
        const name = Config.options?.appearance?.animationCurve?.[category] ?? "default"
        return (name !== "default" && animationCurveLibrary[name]) ? animationCurveLibrary[name] : null
    }
    // defaultType/defaultCurve are what the preset would use with no override — the
    // style/motion-profile-aware pick already computed at each call site below.
    function resolveCurveType(category, defaultType) {
        const override = root._curveOverride(category)
        return override ? override.type : defaultType
    }
    function resolveCurveBezier(category, defaultCurve) {
        const override = root._curveOverride(category)
        return override ? override.curve : defaultCurve
    }

    // Helper for calculating effective animation duration. speedMultiplier is optional;
    // omitted for the ~80 raw calcEffectiveDuration(ms) call sites across the shell,
    // passed by the named presets in `animation` below for granular per-category control.
    function calcEffectiveDuration(baseDuration, speedMultiplier) {
        if (!animationsEnabled) return 0
        return Math.round(baseDuration * (speedMultiplier ?? 1.0))
    }

    // Concentric corner radius: a child inset by `inset` inside a `parentRadius`
    // corner must use parentRadius − inset to stay visually concentric with its
    // container (a selection highlight should echo the surface it sits on, not
    // invent its own silhouette). Clamped ≥ 0. Use this for every selected/active
    // plate that lives inside a rounded parent instead of a hand-picked radius.
    function concentricRadius(parentRadius, inset) {
        return Math.max(0, parentRadius - inset)
    }

    property QtObject motion: QtObject {
        property QtObject popupReveal: QtObject {
            // ZZZ generalizes the AiModelSelector reveal: every shared popup/menu
            // grows from its anchored origin with a punchy back-out. The enter
            // curve under zzz is already animationCurves.zzzOvershoot (see
            // elementMoveEnter), so a deeper closedScale reads as a console plate
            // snapping into place rather than a soft material fade.
            property bool enableFade: root.zzzEverywhere || root.contextualMotionProfile
            property bool enableScale: root.zzzEverywhere || root.contextualMotionProfile
            // 0.97 read as "barely there" in practice — bumped to match zzz's proven-visible
            // 0.90 pop so Classic (hard snap, no fade) vs Contextual (fade + grow) is unmistakable
            // on tray menu / context menu / combobox dropdown / widget gear menu.
            property real closedScale: root.zzzEverywhere ? 0.90
                : (root.contextualMotionProfile ? 0.90 : 1.0)
        }
    }

    m3colors: QtObject {
        property bool darkmode: true
        property bool transparent: false
        // Dark blue/grey background tuned for dark wallpapers
        property color m3background: "#06070b"
        property color m3onBackground: "#E3E6F0"
        property color m3surface: "#06070b"
        property color m3surfaceDim: "#05060a"
        property color m3surfaceBright: "#141825"
        property color m3surfaceContainerLowest: "#040508"
        property color m3surfaceContainerLow: "#0B0E16"
        property color m3surfaceContainer: "#111522"
        property color m3surfaceContainerHigh: "#161B28"
        property color m3surfaceContainerHighest: "#1B2233"
        property color m3onSurface: "#E3E6F0"
        property color m3surfaceVariant: "#3D455A"
        property color m3onSurfaceVariant: "#C3CAD9"
        property color m3inverseSurface: "#E3E6F0"
        property color m3inverseOnSurface: "#151822"
        property color m3outline: "#707894"
        property color m3outlineVariant: "#3D455A"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        // Primary accent shifted to an electric-ish blue
        property color m3surfaceTint: "#1F6CFF"
        property color m3primary: "#1F6CFF"
        property color m3onPrimary: "#0A1020"
        property color m3primaryContainer: "#12244A"
        property color m3onPrimaryContainer: "#C7D4FF"
        property color m3inversePrimary: "#8CACFF"
        property color m3secondary: "#9AA5C0"
        property color m3onSecondary: "#151925"
        property color m3secondaryContainer: "#242C40"
        property color m3onSecondaryContainer: "#D6DDF0"
        property color m3tertiary: "#d1c3c6"
        property color m3onTertiary: "#372e30"
        property color m3tertiaryContainer: "#31292b"
        property color m3onTertiaryContainer: "#c1b4b7"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3primaryFixed: "#e7e0e7"
        property color m3primaryFixedDim: "#cbc4cb"
        property color m3onPrimaryFixed: "#1d1b1f"
        property color m3onPrimaryFixedVariant: "#49454b"
        property color m3secondaryFixed: "#e6e1e4"
        property color m3secondaryFixedDim: "#cac5c8"
        property color m3onSecondaryFixed: "#1d1b1d"
        property color m3onSecondaryFixedVariant: "#484648"
        property color m3tertiaryFixed: "#eddfe1"
        property color m3tertiaryFixedDim: "#d1c3c6"
        property color m3onTertiaryFixed: "#211a1c"
        property color m3onTertiaryFixedVariant: "#4e4447"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color term0: "#EDE4E4"
        property color term1: "#B52755"
        property color term2: "#A97363"
        property color term3: "#AF535D"
        property color term4: "#A67F7C"
        property color term5: "#B2416B"
        property color term6: "#8D76AD"
        property color term7: "#272022"
        property color term8: "#0E0D0D"
        property color term9: "#B52755"
        property color term10: "#A97363"
        property color term11: "#AF535D"
        property color term12: "#A67F7C"
        property color term13: "#B2416B"
        property color term14: "#8D76AD"
        property color term15: "#221A1A"
    }

    colors: QtObject {
        // Ink colors for aurora light mode - sumi-e inspired (Japanese ink wash)
        // Warm, muted tones instead of pure gray/black
        readonly property color _inkPrimary: "#2b2622"      // Warm charcoal - main text
        readonly property color _inkSecondary: "#5c534a"    // Warm gray - secondary text
        readonly property color _inkMuted: "#8a7f73"        // Warm taupe - inactive/disabled

        // Aurora Mode Contrast Boost Logic
        // If we are in Aurora Dark mode (glass), we CANNOT use dark variants for text.
        // We must force lighter text to ensure readability against the blurred backdrop.
        readonly property bool _needsHighContrast: auroraEverywhere && !root._auroraLightMode
        
        // Base text colors from Material theme
        readonly property color _baseOnSurface: m3colors.m3onSurface
        readonly property color _baseOnSurfaceVariant: m3colors.m3onSurfaceVariant
        
        property color colSubtext: root.cookieEverywhere ? root.cookie.inkMuted : root.zzzEverywhere ? root.zzz.inkMuted : ColorUtils.readableSubtext(
            _needsHighContrast ? _baseOnSurface : (root._auroraLightMode ? _inkSecondary : m3colors.m3outline),
            colLayer1Base,
            0.75
        )
            
        // Layer 0
        property color colLayer0Base: root.cookieEverywhere ? root.cookie.bg0 : root.zzzEverywhere ? root.zzz.bg0 : (m3colors.transparent ? "transparent" : ColorUtils.mix(m3colors.m3background, m3colors.m3primary, Config?.options?.appearance?.extraBackgroundTint ? 0.99 : 1))
        property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)
        property color colOnLayer0: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : ColorUtils.ensureReadable(
            root._auroraLightMode ? _inkPrimary : _baseOnSurface,
            colLayer0Base,
            4.5
        )
        property color colLayer0Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.9), root.contentTransparency)
        property color colLayer0Active: ColorUtils.transparentize(ColorUtils.mix(colLayer0, colOnLayer0, 0.8), root.contentTransparency)
        property color colLayer0Border: root.cookieEverywhere ? root.cookie.hairline : root.zzzEverywhere ? root.zzz.borderColor : ColorUtils.mix(root.m3colors.m3outlineVariant, colLayer0, 0.4)
        // Layer 1
        property color colLayer1Base: root.cookieEverywhere ? root.cookie.bg1 : root.zzzEverywhere ? root.zzz.bg1 : m3colors.m3surfaceContainerLow
        property color colLayer1: auroraEverywhere ? ColorUtils.transparentize(m3colors.m3surfaceContainerLow, root.aurora.layerTransparentize) : ColorUtils.solveOverlayColor(colLayer0Base, colLayer1Base, 1 - root.contentTransparency)
        property color colOnLayer1: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : ColorUtils.ensureReadable(
            _needsHighContrast ? _baseOnSurface : (root._auroraLightMode ? _inkPrimary : _baseOnSurfaceVariant),
            colLayer1Base,
            4.5
        )
        property color colOnLayer1Inactive: ColorUtils.readableSubtext(colOnLayer1, colLayer1Base, 0.55)
        property color colLayer1Hover: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), root.contentTransparency)
        property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), root.contentTransparency)
        // Layer 2
        property color colLayer2Base: root.cookieEverywhere ? root.cookie.bg2 : root.zzzEverywhere ? root.zzz.bg2 : m3colors.m3surfaceContainer
        property color colLayer2: auroraEverywhere ? ColorUtils.transparentize(m3colors.m3surfaceContainer, root.aurora.layerTransparentize) : ColorUtils.solveOverlayColor(colLayer1Base, colLayer2Base, 1 - root.contentTransparency)
        property color colLayer2Hover: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.90), 1 - root.contentTransparency)
        property color colLayer2Active: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, colOnLayer2, 0.80), 1 - root.contentTransparency)
        property color colLayer2Disabled: ColorUtils.solveOverlayColor(colLayer1Base, ColorUtils.mix(colLayer2Base, m3colors.m3background, 0.8), 1 - root.contentTransparency)
        property color colOnLayer2: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : ColorUtils.ensureReadable(
            _needsHighContrast ? _baseOnSurface : (root._auroraLightMode ? _inkPrimary : _baseOnSurface),
            colLayer2Base,
            4.5
        )
        property color colOnLayer2Disabled: ColorUtils.readableSubtext(colOnLayer2, colLayer2Base, 0.4)
        // Layer 3
        property color colLayer3Base: root.cookieEverywhere ? root.cookie.bg3 : root.zzzEverywhere ? root.zzz.bg3 : m3colors.m3surfaceContainerHigh
        property color colLayer3: auroraEverywhere ? ColorUtils.transparentize(m3colors.m3surfaceContainerHigh, root.aurora.layerTransparentize) : ColorUtils.solveOverlayColor(colLayer2Base, colLayer3Base, 1 - root.contentTransparency)
        property color colLayer3Hover: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.90), 1 - root.contentTransparency)
        property color colLayer3Active: ColorUtils.solveOverlayColor(colLayer2Base, ColorUtils.mix(colLayer3Base, colOnLayer3, 0.80), 1 - root.contentTransparency)
        property color colOnLayer3: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : ColorUtils.ensureReadable(
            _needsHighContrast ? _baseOnSurface : (root._auroraLightMode ? _inkPrimary : _baseOnSurface),
            colLayer3Base,
            4.5
        )
        // Layer 4
        property color colLayer4Base: root.cookieEverywhere ? root.cookie.bg4 : root.zzzEverywhere ? root.zzz.bg4 : m3colors.m3surfaceContainerHighest
        property color colLayer4: ColorUtils.solveOverlayColor(colLayer3Base, colLayer4Base, 1 - root.contentTransparency)
        property color colLayer4Hover: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.90), 1 - root.contentTransparency)
        property color colLayer4Active: ColorUtils.solveOverlayColor(colLayer3Base, ColorUtils.mix(colLayer4Base, colOnLayer4, 0.80), 1 - root.contentTransparency)
        property color colOnLayer4: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : ColorUtils.ensureReadable(
            root._auroraLightMode ? _inkPrimary : _baseOnSurface,
            colLayer4Base,
            4.5
        )
        // Primary
        property color colPrimary: root.zzzEverywhere ? root.zzz.accent : m3colors.m3primary
        property color colOnPrimary: root.zzzEverywhere ? root.zzz.onAccent : m3colors.m3onPrimary
        property color colPrimaryHover: ColorUtils.mix(colors.colPrimary, colLayer1Hover, 0.87)
        property color colPrimaryActive: ColorUtils.mix(colors.colPrimary, colLayer1Active, 0.7)
        property color colPrimaryContainer: root.cookieEverywhere ? root.cookie.primaryFace : root.zzzEverywhere ? ColorUtils.mix(root.zzz.bg3, root.zzz.sticker, 0.20) : m3colors.m3primaryContainer
        property color colPrimaryContainerHover: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.9)
        property color colPrimaryContainerActive: ColorUtils.mix(colors.colPrimaryContainer, colors.colOnPrimaryContainer, 0.8)
        property color colOnPrimaryContainer: root.cookieEverywhere ? root.cookie.onFace : root.zzzEverywhere ? root.zzz.onColor : m3colors.m3onPrimaryContainer
        // Secondary
        property color colSecondary: root.zzzEverywhere ? root.zzz.secondary : m3colors.m3secondary
        property color colSecondaryHover: ColorUtils.mix(colSecondary, colLayer1Hover, 0.85)
        property color colSecondaryActive: ColorUtils.mix(colSecondary, colLayer1Active, 0.4)
        property color colOnSecondary: root.zzzEverywhere ? root.zzz.onSecondary : m3colors.m3onSecondary
        property color colSecondaryContainer: root.cookieEverywhere ? root.cookie.secondaryFace : root.zzzEverywhere ? ColorUtils.mix(root.zzz.bg3, root.zzz.secondary, 0.18) : m3colors.m3secondaryContainer
        property color colSecondaryContainerHover: ColorUtils.mix(colSecondaryContainer, colOnSecondaryContainer, 0.90)
        property color colSecondaryContainerActive: ColorUtils.mix(colSecondaryContainer, colOnSecondaryContainer, 0.54)
        property color colOnSecondaryContainer: root.cookieEverywhere ? root.cookie.onFace : root.zzzEverywhere ? root.zzz.onColor : m3colors.m3onSecondaryContainer
        // Tertiary
        property color colTertiary: root.zzzEverywhere ? root.zzz.tertiary : m3colors.m3tertiary
        property color colTertiaryHover: ColorUtils.mix(colTertiary, colLayer1Hover, 0.85)
        property color colTertiaryActive: ColorUtils.mix(colTertiary, colLayer1Active, 0.4)
        property color colTertiaryContainer: root.cookieEverywhere ? root.cookie.tertiaryFace : root.zzzEverywhere ? ColorUtils.mix(root.zzz.bg3, root.zzz.tertiary, 0.18) : m3colors.m3tertiaryContainer
        property color colTertiaryContainerHover: ColorUtils.mix(colTertiaryContainer, colOnTertiaryContainer, 0.90)
        property color colTertiaryContainerActive: ColorUtils.mix(colTertiaryContainer, colLayer1Active, 0.54)
        property color colOnTertiary: root.zzzEverywhere ? root.zzz.onAccent : m3colors.m3onTertiary
        property color colOnTertiaryContainer: root.cookieEverywhere ? root.cookie.onFace : root.zzzEverywhere ? root.zzz.onColor : m3colors.m3onTertiaryContainer
        // Surface
        property color colBackgroundSurfaceContainer: root.cookieEverywhere ? root.cookie.bg2 : root.zzzEverywhere ? root.zzz.bg2 : ColorUtils.transparentize(m3colors.m3surfaceContainer, root.backgroundTransparency)
        property color colSurfaceContainerLow: root.cookieEverywhere ? root.cookie.bg1 : root.zzzEverywhere ? root.zzz.bg1 : ColorUtils.solveOverlayColor(m3colors.m3background, m3colors.m3surfaceContainerLow, 1 - root.contentTransparency)
        property color colSurfaceContainer: root.cookieEverywhere ? root.cookie.bg2 : root.zzzEverywhere ? root.zzz.bg2 : ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerLow, m3colors.m3surfaceContainer, 1 - root.contentTransparency)
        property color colSurfaceContainerHigh: root.cookieEverywhere ? root.cookie.bg3 : root.zzzEverywhere ? root.zzz.bg3 : ColorUtils.solveOverlayColor(m3colors.m3surfaceContainer, m3colors.m3surfaceContainerHigh, 1 - root.contentTransparency)
        property color colSurfaceContainerHighest: root.cookieEverywhere ? root.cookie.bg4 : root.zzzEverywhere ? root.zzz.bg4 : ColorUtils.solveOverlayColor(m3colors.m3surfaceContainerHigh, m3colors.m3surfaceContainerHighest, 1 - root.contentTransparency)
        property color colSurfaceContainerHighestHover: ColorUtils.mix(colSurfaceContainerHighest, colOnSurface, 0.95)
        property color colSurfaceContainerHighestActive: ColorUtils.mix(colSurfaceContainerHighest, colOnSurface, 0.85)
        property color colOnSurface: root.cookieEverywhere ? root.cookie.onColor : root.zzzEverywhere ? root.zzz.onColor : m3colors.m3onSurface
        property color colOnSurfaceVariant: root.cookieEverywhere ? root.cookie.inkMuted : root.zzzEverywhere ? ColorUtils.applyAlpha(root.zzz.onColor, 0.78) : m3colors.m3onSurfaceVariant
        // Misc
        property color colTooltip: root.zzzEverywhere ? root.zzz.contrastPlate : m3colors.m3inverseSurface
        property color colOnTooltip: root.zzzEverywhere ? root.zzz.onContrastPlate : m3colors.m3inverseOnSurface
        property color colScrim: ColorUtils.transparentize(m3colors.m3scrim, 0.5)
        property color colShadow: m3colors.transparent ? "transparent" : ColorUtils.transparentize(m3colors.m3shadow, 0.7)
        property color colOutline: root.cookieEverywhere ? root.cookie.borderColor : root.zzzEverywhere ? root.zzz.borderColor : (_needsHighContrast ? ColorUtils.transparentize(m3colors.m3onSurface, 0.8) : m3colors.m3outline) // Brighter border in Aurora Dark
        property color colOutlineVariant: root.cookieEverywhere ? root.cookie.hairline : root.zzzEverywhere ? root.zzz.hairlineStrong : (_needsHighContrast ? ColorUtils.transparentize(m3colors.m3onSurface, 0.9) : m3colors.m3outlineVariant)
        property color colError: m3colors.m3error
        property color colErrorHover: ColorUtils.mix(m3colors.m3error, colLayer1Hover, 0.85)
        property color colErrorActive: ColorUtils.mix(m3colors.m3error, colLayer1Active, 0.7)
        property color colOnError: m3colors.m3onError
        property color colErrorContainer: m3colors.m3errorContainer
        property color colErrorContainerHover: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.90)
        property color colErrorContainerActive: ColorUtils.mix(m3colors.m3errorContainer, m3colors.m3onErrorContainer, 0.70)
        property color colOnErrorContainer: m3colors.m3onErrorContainer

        // Success and warning existed only on the aurora token set, but the
        // contrast badges in the theme editor and the colour picker read them
        // off `colors` — so under every other style they resolved to undefined
        // and each badge logged "Unable to assign [undefined] to QColor" on
        // every repaint. zzz keeps its own chip inks: a raw green or orange is
        // a hex dump in that doctrine, not a console chip.
        property color colSuccess: m3colors.m3success
        property color colOnSuccess: m3colors.m3onSuccess
        property color colSuccessContainer: m3colors.m3successContainer
        property color colOnSuccessContainer: m3colors.m3onSuccessContainer
        property color colWarning: m3colors.m3tertiary
        property color colWarningContainer: root.zzzEverywhere
            ? root.zzz.secondary : m3colors.m3tertiaryContainer
        property color colOnWarningContainer: root.zzzEverywhere
            ? root.zzz.onSecondary : m3colors.m3onTertiaryContainer
    }

    rounding: QtObject {
        // Dynamic rounding scalar based on theme metadata
        // Matrix -> 0, Zen Garden -> 1.5, Standard -> 1.0
        property real scale: root.zzzEverywhere ? 1.0 : (root._themeMeta.roundingScale ?? 1.0)

        property int unsharpen: root.cookieEverywhere ? 4 : root.zzzEverywhere ? 2 : Math.max(0, Math.round(2 * scale))
        property int unsharpenmore: root.cookieEverywhere ? 8 : root.zzzEverywhere ? 4 : Math.max(0, Math.round(6 * scale))
        property int verysmall: root.cookieEverywhere ? root.cookie.roundVerySmall : root.zzzEverywhere ? root.zzz.roundSmall : Math.max(0, Math.round(8 * scale))
        property int small: root.cookieEverywhere ? root.cookie.roundSmall : root.zzzEverywhere ? root.zzz.roundSmall : Math.max(0, Math.round(12 * scale))
        property int normal: root.cookieEverywhere ? root.cookie.roundNormal : root.zzzEverywhere ? root.zzz.roundNormal : Math.max(0, Math.round(17 * scale))
        property int large: root.cookieEverywhere ? root.cookie.roundLarge : root.zzzEverywhere ? root.zzz.roundLarge : Math.max(0, Math.round(23 * scale))
        property int verylarge: root.cookieEverywhere ? root.cookie.panelRadius : root.zzzEverywhere ? root.zzz.panelRadius : Math.max(0, Math.round(30 * scale))
        property int full: root.zzzEverywhere ? (root.zzz.round ? 9999 : root.zzz.controlRadius) : 9999
        property int screenRounding: large
        property int windowRounding: root.zzzEverywhere ? root.zzz.panelRadius : Math.max(0, Math.round(18 * scale))
    }

    // Typography scale factor from config
    property real fontSizeScale: Config.options?.appearance?.typography?.sizeScale ?? 1.0

    // Theme Metadata Logic
    readonly property var activeThemePreset: ThemePresets.getPreset(Config.options?.appearance?.theme ?? "auto")
    readonly property var _themeMeta: activeThemePreset.meta || {}
    
    // Font Strategy:
    // 1. Inir style -> Always Monospace (TUI feel)
    // 2. Theme requests mono (Matrix, Vesper) -> Monospace
    // 3. Theme requests serif (Angel) -> Serif (if mapped)
    // 4. Default -> Config Main Font
    readonly property bool _forceMono: globalStyle === "inir" || _themeMeta.fontStyle === "mono"
    readonly property string _angelFont: "Oxanium"
    readonly property bool _useAngelFont: globalStyle === "angel"
    // ZZZ uses Oxanium (poster geometric). Restored after Space Grotesk felt
    // thinner/less characteristic — Oxanium keeps the ZZZ identity.
    readonly property string _zzzFont: "Oxanium"
    readonly property bool _useZzzFont: globalStyle === "zzz"

    font: QtObject {
        property QtObject family: QtObject {
            property string main: root._useZzzFont ? root._zzzFont
                                : root._useAngelFont ? root._angelFont
                                : root._forceMono ? monospace
                                : (Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex")
            property string numbers: root._useZzzFont ? root._zzzFont
                                : root._useAngelFont ? root._angelFont : "Rubik"
            property string title: root._useZzzFont ? root._zzzFont
                                 : root._useAngelFont ? root._angelFont
                                 : root._forceMono ? monospace
                                 : (Config.options?.appearance?.typography?.titleFont ?? "Gabarito")
            property string iconMaterial: "Material Symbols Rounded"
            property string iconNerd: "JetBrains Mono NF"
            property string monospace: Config.options?.appearance?.typography?.monospaceFont ?? "JetBrainsMono Nerd Font"
            property string reading: "Readex Pro"
            property string expressive: "Space Grotesk"
        }
        property QtObject variableAxes: QtObject {
            // Roboto Flex is customized to feel geometric, unserious yet not overly kiddy
            property var main: ({
                "YTUC": 716,
                "YTFI": 716,
                "YTAS": 716,
                "YTLC": 490,
                "XTRA": 488,
                "wdth": Math.max(25, Math.min(151, Config.options?.appearance?.typography?.variableAxes?.wdth ?? 105)),
                "GRAD": Math.max(-200, Math.min(150, Config.options?.appearance?.typography?.variableAxes?.grad ?? 150)),
                "wght": Math.max(100, Math.min(1000, Config.options?.appearance?.typography?.variableAxes?.wght ?? 300)),
            })
            property var numbers: ({
                "wght": 400,
            })
            property var title: ({
                "wght": 900,
            })
        }
        property QtObject pixelSize: QtObject {
            property int smallest: Math.round(10 * root.fontSizeScale)
            property int smaller: Math.round(12 * root.fontSizeScale)
            property int smallie: Math.round(13 * root.fontSizeScale)
            property int small: Math.round(15 * root.fontSizeScale)
            property int normal: Math.round(16 * root.fontSizeScale)
            property int large: Math.round(17 * root.fontSizeScale)
            property int larger: Math.round(19 * root.fontSizeScale)
            property int huge: Math.round(22 * root.fontSizeScale)
            property int hugeass: Math.round(23 * root.fontSizeScale)
            property int title: huge
        }
    }

    animationCurves: QtObject {
        readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // Default, 350ms
        readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // Default, 500ms
        readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // Default, 650ms
        readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // Default, 200ms
        readonly property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedFirstHalf: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82]
        readonly property list<real> emphasizedLastHalf: [5 / 24, 0.82, 0.25, 1, 1, 1]
        readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        // ZZZ back-out "punch": overshoots past the target then settles, giving the
        // poster-console UI its snappy mechanical feel. Consumed by the enter/bounce
        // presets only when globalStyle === "zzz".
        readonly property list<real> zzzOvershoot: [0.34, 1.56, 0.64, 1.0, 1, 1]
        readonly property list<real> zzzSnap: [0.22, 1.0, 0.36, 1.0, 1, 1]
        // Cookie's spring. ShapeCanvas already overshoots at 1.67 when a
        // silhouette morphs; this is the same gesture pushed out to everything
        // else, so the shell moves like the shapes do instead of a bouncy shape
        // landing inside a shell that eases like material.
        readonly property list<real> cookieSpring: [0.34, 1.75, 0.36, 1.0, 1, 1]
        readonly property real expressiveFastSpatialDuration: 350
        readonly property real expressiveDefaultSpatialDuration: 500
        readonly property real expressiveSlowSpatialDuration: 650
        readonly property real expressiveEffectsDuration: 200
    }

    animation: QtObject {
        // State-layer colors must never use spatial overshoot. Overshooting a
        // color channel creates a dark/bright intermediate flash that reads as
        // a second hover animation, especially when entering from alpha zero.
        property QtObject stateChange: QtObject {
            property int duration: root.calcEffectiveDuration(180, root.animationSpeed.clickBounce)
            property int type: Easing.BezierSpline
            property list<real> bezierCurve: animationCurves.expressiveEffects
        }

        property QtObject elementMove: QtObject {
            property int duration: root.calcEffectiveDuration(animationCurves.expressiveDefaultSpatialDuration, root.animationSpeed.movement)
            property int type: root.resolveCurveType("movement", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("movement", animationCurves.expressiveDefaultSpatial)
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMove.duration
                    easing.type: root.animation.elementMove.type
                    easing.bezierCurve: root.animation.elementMove.bezierCurve
                }
            }
        }

        property QtObject elementMoveEnter: QtObject {
            property int duration: root.calcEffectiveDuration(root.cookieEverywhere ? root.cookie.springDuration : root.zzzEverywhere ? root.zzz.overshootDuration : (root.contextualMotionProfile ? 520 : 400), root.animationSpeed.enterExit)
            property int type: root.resolveCurveType("enterExit", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("enterExit", root.cookieEverywhere ? animationCurves.cookieSpring : root.zzzEverywhere ? animationCurves.zzzOvershoot : animationCurves.emphasizedDecel)
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveEnter.duration
                    easing.type: root.animation.elementMoveEnter.type
                    easing.bezierCurve: root.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        property QtObject elementMoveExit: QtObject {
            property int duration: root.calcEffectiveDuration(root.contextualMotionProfile ? 280 : 200, root.animationSpeed.enterExit)
            property int type: root.resolveCurveType("enterExit", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("enterExit", animationCurves.emphasizedAccel)
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementMoveExit.duration
                    easing.type: root.animation.elementMoveExit.type
                    easing.bezierCurve: root.animation.elementMoveExit.bezierCurve
                }
            }
        }

        property QtObject elementMoveFast: QtObject {
            // Cookie springs on click too. expressiveEffects does not overshoot,
            // so without this a cookie button's press felt like material even
            // while its silhouette was morphing expressively.
            property int duration: root.calcEffectiveDuration(root.cookieEverywhere ? 300 : (root.contextualMotionProfile ? 260 : animationCurves.expressiveEffectsDuration), root.animationSpeed.clickBounce)
            property int type: root.resolveCurveType("clickBounce", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("clickBounce", root.cookieEverywhere ? animationCurves.cookieSpring : animationCurves.expressiveEffects)
            property int velocity: 850
            property Component colorAnimation: Component { ColorAnimation {
                duration: root.animation.elementMoveFast.duration
                easing.type: root.animation.elementMoveFast.type
                easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
            property Component numberAnimation: Component { NumberAnimation {
                    duration: root.animation.elementMoveFast.duration
                    easing.type: root.animation.elementMoveFast.type
                    easing.bezierCurve: root.animation.elementMoveFast.bezierCurve
            }}
        }

        property QtObject elementResize: QtObject {
            property int duration: root.calcEffectiveDuration(root.contextualMotionProfile ? 380 : 300, root.animationSpeed.movement)
            property int type: root.resolveCurveType("movement", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("movement", animationCurves.emphasized)
            property int velocity: 650
            property Component numberAnimation: Component {
                NumberAnimation {
                    duration: root.animation.elementResize.duration
                    easing.type: root.animation.elementResize.type
                    easing.bezierCurve: root.animation.elementResize.bezierCurve
                }
            }
        }

        property QtObject clickBounce: QtObject {
            property int duration: root.calcEffectiveDuration(root.zzzEverywhere ? root.zzz.overshootDuration : 400, root.animationSpeed.clickBounce)
            property int type: root.resolveCurveType("clickBounce", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("clickBounce", root.zzzEverywhere ? animationCurves.zzzOvershoot : animationCurves.expressiveDefaultSpatial)
            property int velocity: 850
            property Component numberAnimation: Component { NumberAnimation {
                    duration: root.animation.clickBounce.duration
                    easing.type: root.animation.clickBounce.type
                    easing.bezierCurve: root.animation.clickBounce.bezierCurve
            }}
        }
        
        property QtObject scroll: QtObject {
            property int duration: root.calcEffectiveDuration(root.zzzEverywhere ? root.zzz.overshootDuration : 200, root.animationSpeed.scroll)
            property int type: root.resolveCurveType("scroll", Easing.BezierSpline)
            property list<real> bezierCurve: root.resolveCurveBezier("scroll", root.zzzEverywhere ? animationCurves.zzzSnap : animationCurves.standardDecel)
        }

        property QtObject menuDecel: QtObject {
            property int duration: root.calcEffectiveDuration(root.contextualMotionProfile ? 460 : 350, root.animationSpeed.scroll)
            // No override curve store here: menuDecel has no live consumers today, keeps
            // its own Easing.OutExpo baseline (see git history) rather than the bezier family.
            property int type: Easing.OutExpo
        }

        // Class B: physical, velocity-carrying motion for retargetable props (traveling indicators,
        // drag-follow, value bars). Gate Behaviors on animationsEnabled. See MORPH_ENGINE_DESIGN.md.
        property QtObject spatialFollow: QtObject {
            property real velocity: 1400
            property Component smoothedAnimation: Component {
                SmoothedAnimation { velocity: root.animation.spatialFollow.velocity }
            }
        }
        property QtObject spatialFollowFast: QtObject {
            property real velocity: 2600
            property Component smoothedAnimation: Component {
                SmoothedAnimation { velocity: root.animation.spatialFollowFast.velocity }
            }
        }
        property QtObject spatialSpring: QtObject {
            property real spring: 3.2
            property real damping: 0.28
            property real mass: 1.0
            property real epsilon: 0.25
            property Component springAnimation: Component {
                SpringAnimation {
                    spring: root.animation.spatialSpring.spring
                    damping: root.animation.spatialSpring.damping
                    mass: root.animation.spatialSpring.mass
                    epsilon: root.animation.spatialSpring.epsilon
                }
            }
        }
    }

    aurora: QtObject {
        // Aurora glass effect - configurable transparency
        // All values read from Config for live reactivity via Aurora Style Editor
        // Light mode: reduce transparency slightly for better contrast on light wallpapers
        readonly property real _lightFactor: root._auroraLightMode ? 0.75 : 1.0

        // Transparency levels — read from Config with revision dependency for live reactivity
        // Config.revision forces re-evaluation when setNestedValue writes (JS bracket notation
        // on nested JsonObjects doesn't trigger QML property notifications)
        readonly property var _cfg: { Config.revision; return Config.options?.appearance?.aurora?.transparency ?? null }
        readonly property real overlayTransparentize: (_cfg?.overlay ?? 0.30) * _lightFactor
        readonly property real subSurfaceTransparentize: (_cfg?.subSurface ?? 0.42) * _lightFactor
        readonly property real popupTransparentize: (_cfg?.popup ?? 0.32) * _lightFactor
        readonly property real tooltipTransparentize: (_cfg?.tooltip ?? 0.28) * _lightFactor
        readonly property real layerTransparentize: (_cfg?.layer ?? 0.32) * _lightFactor
        
        // === Main Panel Overlay (Layer 0) ===
        readonly property color colOverlay: ColorUtils.transparentize(root.colors.colLayer0Base, overlayTransparentize)
        readonly property color colOverlayHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer0Base, root.colors.colOnLayer0, 0.95), overlayTransparentize)
        
        // === Sub-Surface (Layer 1 - cards, groups within panels) ===
        readonly property color colSubSurface: ColorUtils.transparentize(root.colors.colLayer1Base, subSurfaceTransparentize)
        readonly property color colSubSurfaceHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer1Base, root.colors.colOnLayer1, 0.92), subSurfaceTransparentize)
        readonly property color colSubSurfaceActive: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer1Base, root.colors.colOnLayer1, 0.85), subSurfaceTransparentize)
        
        // === Elevated Surface (Layer 2 - elevated cards) ===
        readonly property color colElevatedSurface: ColorUtils.transparentize(root.colors.colLayer2Base, subSurfaceTransparentize * 0.9)
        readonly property color colElevatedSurfaceHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.92), subSurfaceTransparentize * 0.9)
        
        // === Popup Surface (menus, dialogs, floating elements) ===
        readonly property color colPopupSurface: ColorUtils.transparentize(root.colors.colLayer2Base, popupTransparentize)
        readonly property color colPopupSurfaceHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.92), popupTransparentize)
        readonly property color colPopupSurfaceActive: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.85), popupTransparentize)
        
        // === Tooltip Surface (high contrast for readability) ===
        readonly property color colTooltipSurface: ColorUtils.transparentize(root.colors.colLayer3Base, tooltipTransparentize)
        readonly property color colTooltipBorder: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer3Base, root.colors.colOnLayer3, 0.85), tooltipTransparentize * 0.8)
        
        // === Dialog Surface (modal dialogs) ===
        readonly property color colDialogSurface: ColorUtils.transparentize(root.colors.colLayer3Base, popupTransparentize * 0.85)
        
        // Missing properties for BarMediaPopup compatibility
        readonly property color colPopupBorder: ColorUtils.transparentize(root.colors.colOutline, 0.7)
        readonly property color colTextSecondary: ColorUtils.transparentize(root.colors.colOnLayer1, 0.3)
        
        // Legacy alias for backward compatibility
        readonly property real popupSurfaceTransparentize: popupTransparentize
    }

    inir: QtObject {
        // Inir style - Elegant terminal UI aesthetic
        
        // ═══════════════════════════════════════════════════════════════
        // LAYER SYSTEM
        // ═══════════════════════════════════════════════════════════════
        readonly property color colLayer0: root.m3colors.transparent ? "transparent" : root.m3colors.m3background
        readonly property color colLayer1: root.m3colors.transparent ? "transparent" : root.m3colors.m3surfaceContainerLow
        readonly property color colLayer2: root.m3colors.transparent ? "transparent" : root.m3colors.m3surfaceContainer
        readonly property color colLayer3: root.m3colors.transparent ? "transparent" : root.m3colors.m3surfaceContainerHigh
        
        readonly property color colOnLayer0: root.m3colors.m3onBackground
        readonly property color colOnLayer1: root.m3colors.m3onSurface
        readonly property color colOnLayer2: root.m3colors.m3onSurface
        readonly property color colOnLayer3: root.m3colors.m3onSurface
        
        // Hover states (very subtle, calm interactions)
        readonly property color colLayer1Hover: ColorUtils.mix(colLayer1, colOnLayer1, 0.94)
        readonly property color colLayer2Hover: ColorUtils.mix(colLayer2, colOnLayer2, 0.94)
        readonly property color colLayer3Hover: ColorUtils.mix(colLayer3, colOnLayer3, 0.94)
        
        // Active states (slightly more visible)
        readonly property color colLayer1Active: ColorUtils.mix(colLayer1, colOnLayer1, 0.88)
        readonly property color colLayer2Active: ColorUtils.mix(colLayer2, colOnLayer2, 0.88)
        readonly property color colLayer3Active: ColorUtils.mix(colLayer3, colOnLayer3, 0.88)
        
        // ═══════════════════════════════════════════════════════════════
        // BORDER SYSTEM (Elegant, subtle - refined appearance)
        // ═══════════════════════════════════════════════════════════════
        // Scale border width for themes like Matrix/Synthwave
        readonly property real borderScale: root._themeMeta.borderWidthScale ?? 1.0
        
        readonly property color colBorder: root.m3colors.m3outlineVariant ? ColorUtils.transparentize(root.m3colors.m3outlineVariant, 0.3) : "transparent"
        readonly property color colBorderHover: root.m3colors.m3outlineVariant
        readonly property color colBorderAccent: ColorUtils.transparentize(root.m3colors.m3primary, 0.6)
        readonly property color colBorderFocus: ColorUtils.transparentize(root.m3colors.m3primary, 0.3)
        readonly property color colBorderSubtle: ColorUtils.transparentize(root.m3colors.m3outlineVariant, 0.6)
        readonly property color colBorderMuted: ColorUtils.transparentize(root.m3colors.m3outline, 0.7)
        
        // ═══════════════════════════════════════════════════════════════
        // TEXT COLORS (refined hierarchy)
        // ═══════════════════════════════════════════════════════════════
        readonly property color colText: root.m3colors.m3onSurface
        readonly property color colTextSecondary: root.m3colors.m3onSurfaceVariant
        readonly property color colTextMuted: ColorUtils.transparentize(root.m3colors.m3onSurfaceVariant, 0.3)
        readonly property color colTextDisabled: ColorUtils.transparentize(root.m3colors.m3outline, 0.5)
        
        // Labels (subtle accent)
        readonly property color colLabel: root.m3colors.m3primary
        readonly property color colLabelSecondary: root.m3colors.m3secondary
        
        // ═══════════════════════════════════════════════════════════════
        // PRIMARY/ACCENT (calm, not overwhelming)
        // ═══════════════════════════════════════════════════════════════
        readonly property color colPrimary: root.m3colors.m3primary
        readonly property color colPrimaryHover: ColorUtils.mix(root.m3colors.m3primary, root.m3colors.m3onPrimary, 0.9)
        readonly property color colPrimaryActive: ColorUtils.mix(root.m3colors.m3primary, root.m3colors.m3onPrimary, 0.8)
        readonly property color colOnPrimary: root.m3colors.m3onPrimary
        
        // Containers (softer, more elegant)
        readonly property color colPrimaryContainer: ColorUtils.transparentize(root.m3colors.m3primaryContainer, 0.2)
        readonly property color colPrimaryContainerHover: root.m3colors.m3primaryContainer
        readonly property color colPrimaryContainerActive: ColorUtils.mix(root.m3colors.m3primaryContainer, root.m3colors.m3onPrimaryContainer, 0.85)
        readonly property color colOnPrimaryContainer: root.m3colors.m3onPrimaryContainer
        
        readonly property color colSecondary: root.m3colors.m3secondary
        readonly property color colSecondaryContainer: ColorUtils.transparentize(root.m3colors.m3secondaryContainer, 0.3)
        readonly property color colOnSecondaryContainer: root.m3colors.m3onSecondaryContainer
        
        readonly property color colTertiary: root.m3colors.m3tertiary
        
        // Accent alias for consistency with other styles
        readonly property color colAccent: root.m3colors.m3primary
        
        // ═══════════════════════════════════════════════════════════════
        // SELECTION (subtle, elegant highlighting)
        // ═══════════════════════════════════════════════════════════════
        readonly property color colSelection: ColorUtils.transparentize(root.m3colors.m3primaryContainer, 0.15)
        readonly property color colSelectionHover: root.m3colors.m3primaryContainer
        readonly property color colOnSelection: root.m3colors.m3onPrimaryContainer
        
        // ═══════════════════════════════════════════════════════════════
        // SEMANTIC COLORS (softer variants)
        // ═══════════════════════════════════════════════════════════════
        readonly property color colSuccess: root.m3colors.m3success
        readonly property color colOnSuccess: root.m3colors.m3onSuccess
        readonly property color colSuccessContainer: ColorUtils.transparentize(root.m3colors.m3successContainer, 0.3)
        readonly property color colOnSuccessContainer: root.m3colors.m3onSuccessContainer
        
        readonly property color colError: root.m3colors.m3error
        readonly property color colOnError: root.m3colors.m3onError
        readonly property color colErrorContainer: ColorUtils.transparentize(root.m3colors.m3errorContainer, 0.3)

        // ZZZ-aware success/warning/error plates so the contrast indicator and
        // form validation render as readable CONSOLE chips, not raw green/orange
        // hex dumps. The fill is the generated accent/signal scaled to chip range.
        readonly property color colWarning: root.m3colors.m3tertiary
        readonly property color colWarningContainer: ColorUtils.transparentize(
            Appearance.zzzEverywhere ? root.zzz.secondary : root.m3colors.m3tertiary, 0.42)
        readonly property color colOnWarningContainer: Appearance.zzzEverywhere
            ? root.zzz.onSecondary : root.m3colors.m3onTertiaryContainer
        readonly property color colInfo: root.m3colors.m3secondary
        
        // ═══════════════════════════════════════════════════════════════
        // COMPONENT ALIASES
        // ═══════════════════════════════════════════════════════════════
        readonly property color colSurface: colLayer2
        readonly property color colSurfaceHover: colLayer2Hover
        readonly property color colPopupSurface: colLayer3
        readonly property color colOverlay: colLayer1
        readonly property color colTooltip: colLayer3
        readonly property color colTooltipBorder: colBorder
        readonly property color colDialog: colLayer2
        readonly property color colDialogBorder: colBorder
        
        // Input fields
        readonly property color colInput: colLayer1
        readonly property color colInputBorder: colBorderMuted
        readonly property color colInputBorderFocus: colBorderFocus
        readonly property color colInputPlaceholder: colTextMuted
        
        // Scrollbar (very subtle)
        readonly property color colScrollbar: "transparent"
        readonly property color colScrollbarThumb: ColorUtils.transparentize(root.m3colors.m3outline, 0.6)
        readonly property color colScrollbarThumbHover: ColorUtils.transparentize(root.m3colors.m3outline, 0.4)
        
        // ═══════════════════════════════════════════════════════════════
        // ROUNDING (refined, slightly larger for elegance)
        // ═══════════════════════════════════════════════════════════════
        readonly property int roundingSmall: 6
        readonly property int roundingNormal: 8
        readonly property int roundingLarge: 12
    }

    // ═══════════════════════════════════════════════════════════════════
    // ANGEL — Flagship neo-brutalism glass style
    // Combines refined aurora blur with escalonado offset shadows,
    // partial accent borders, inset glow, and sharp corners.
    // Inspired by docs-site TUI aesthetic (glass-btn, feature-card).
    // Angel is a SUPERSET of aurora: auroraEverywhere=true when angel active.
    // ═══════════════════════════════════════════════════════════════════
    angel: QtObject {
        // All angel params read DIRECTLY from Config for live reactivity.
        // Do NOT use intermediate var references — QML can't detect nested var changes.

        // ─── BLUR SYSTEM ───
        readonly property real blurIntensity: Config.options?.appearance?.angel?.blur?.intensity ?? 0.35
        readonly property real blurSaturation: Config.options?.appearance?.angel?.blur?.saturation ?? 0.20
        readonly property real overlayOpacity: Config.options?.appearance?.angel?.blur?.overlayOpacity ?? 0.45
        readonly property real noiseOpacity: Config.options?.appearance?.angel?.blur?.noiseOpacity ?? 0.15
        readonly property real vignetteStrength: Config.options?.appearance?.angel?.blur?.vignetteStrength ?? 0.4

        // ─── GLASS TRANSPARENCY (higher = more see-through) ───
        // Light mode: reduce glass transparency for better contrast on light wallpapers
        readonly property real _lightFactor: root._auroraLightMode ? 0.75 : 1.0
        readonly property real panelTransparentize: (Config.options?.appearance?.angel?.transparency?.panel ?? 0.28) * _lightFactor
        readonly property real cardTransparentize: (Config.options?.appearance?.angel?.transparency?.card ?? 0.40) * _lightFactor
        readonly property real popupTransparentize: (Config.options?.appearance?.angel?.transparency?.popup ?? 0.28) * _lightFactor
        readonly property real tooltipTransparentize: (Config.options?.appearance?.angel?.transparency?.tooltip ?? 0.25) * _lightFactor

        // ─── LAYER SYSTEM (glass variants derived from m3colors) ───
        readonly property color colGlassPanel: ColorUtils.transparentize(
            root.colors.colLayer0Base, panelTransparentize)
        readonly property color colGlassCard: ColorUtils.transparentize(
            root.colors.colLayer1Base, cardTransparentize)
        readonly property color colGlassCardHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer1Base, root.colors.colOnLayer1, 0.88), cardTransparentize)
        readonly property color colGlassCardActive: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer1Base, root.colors.colOnLayer1, 0.78), cardTransparentize)
        readonly property color colGlassPopup: ColorUtils.transparentize(
            root.colors.colLayer2Base, popupTransparentize)
        readonly property color colGlassPopupHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.88), popupTransparentize)
        readonly property color colGlassPopupActive: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.78), popupTransparentize)
        readonly property color colGlassTooltip: ColorUtils.transparentize(
            root.colors.colLayer3Base, tooltipTransparentize)
        readonly property color colGlassDialog: ColorUtils.transparentize(
            root.colors.colLayer3Base, popupTransparentize * 0.85)
        readonly property color colGlassElevated: ColorUtils.transparentize(
            root.colors.colLayer2Base, cardTransparentize * 0.9)
        readonly property color colGlassElevatedHover: ColorUtils.transparentize(
            ColorUtils.mix(root.colors.colLayer2Base, root.colors.colOnLayer2, 0.92), cardTransparentize * 0.9)

        // ─── COLOR STRENGTH (multiplier for accent tint intensity) ───
        readonly property real colorStrength: Math.max(0.01, Config.options?.appearance?.angel?.colorStrength ?? 1.0)

        // ─── ESCALONADO SYSTEM (StyledRectangularShadow — 52+ usages, simple offset) ───
        readonly property int escalonadoOffsetX: Config.options?.appearance?.angel?.escalonado?.offsetX ?? 2
        readonly property int escalonadoOffsetY: Config.options?.appearance?.angel?.escalonado?.offsetY ?? 2
        readonly property int escalonadoHoverOffsetX: Config.options?.appearance?.angel?.escalonado?.hoverOffsetX ?? 7
        readonly property int escalonadoHoverOffsetY: Config.options?.appearance?.angel?.escalonado?.hoverOffsetY ?? 7
        readonly property real escalonadoOpacity: Config.options?.appearance?.angel?.escalonado?.opacity ?? 0.40
        readonly property real escalonadoBorderOpacity: Config.options?.appearance?.angel?.escalonado?.borderOpacity ?? 0.60
        readonly property real escalonadoHoverOpacity: Config.options?.appearance?.angel?.escalonado?.hoverOpacity ?? 0.60
        readonly property color colEscalonado: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, escalonadoOpacity / colorStrength))
        readonly property color colEscalonadoBorder: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, escalonadoBorderOpacity / colorStrength))
        readonly property color colEscalonadoHover: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, escalonadoHoverOpacity / colorStrength))

        // ─── ESCALONADO SHADOW (EscalonadoShadow — glass-backed, settings cards) ───
        readonly property int shadowOffsetX: Config.options?.appearance?.angel?.escalonadoShadow?.offsetX ?? 4
        readonly property int shadowOffsetY: Config.options?.appearance?.angel?.escalonadoShadow?.offsetY ?? 4
        readonly property int shadowHoverOffsetX: Config.options?.appearance?.angel?.escalonadoShadow?.hoverOffsetX ?? 10
        readonly property int shadowHoverOffsetY: Config.options?.appearance?.angel?.escalonadoShadow?.hoverOffsetY ?? 10
        readonly property real shadowOpacity: Config.options?.appearance?.angel?.escalonadoShadow?.opacity ?? 0.30
        readonly property real shadowBorderOpacity: Config.options?.appearance?.angel?.escalonadoShadow?.borderOpacity ?? 0.50
        readonly property real shadowHoverOpacity: Config.options?.appearance?.angel?.escalonadoShadow?.hoverOpacity ?? 0.50
        readonly property bool shadowGlass: Config.options?.appearance?.angel?.escalonadoShadow?.glass ?? true
        readonly property real shadowGlassBlur: Config.options?.appearance?.angel?.escalonadoShadow?.glassBlur ?? 0.15
        readonly property real shadowGlassOverlay: Config.options?.appearance?.angel?.escalonadoShadow?.glassOverlay ?? 0.50
        readonly property color colShadow: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, shadowOpacity / colorStrength))
        readonly property color colShadowBorder: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, shadowBorderOpacity / colorStrength))
        readonly property color colShadowHover: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, shadowHoverOpacity / colorStrength))

        // ─── PARTIAL BORDER SYSTEM ───
        readonly property real borderWidth: Config.options?.appearance?.angel?.border?.width ?? 1.5
        readonly property int accentBarHeight: Config.options?.appearance?.angel?.border?.accentBarHeight ?? 0
        readonly property int accentBarWidth: Config.options?.appearance?.angel?.border?.accentBarWidth ?? 0
        readonly property real borderCoverage: Config.options?.appearance?.angel?.border?.coverage ?? 0.0
        readonly property color colAccentBar: root.m3colors.m3primary
        readonly property real borderOpacity: Config.options?.appearance?.angel?.border?.opacity ?? 0.0
        readonly property real borderHoverOpacity: Config.options?.appearance?.angel?.border?.hoverOpacity ?? 0.0
        readonly property real borderActiveOpacity: Config.options?.appearance?.angel?.border?.activeOpacity ?? 0.0
        readonly property color colBorder: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (0.99 - borderOpacity) / colorStrength))
        readonly property color colBorderHover: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (0.99 - borderHoverOpacity) / colorStrength))
        readonly property color colBorderActive: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (0.99 - borderActiveOpacity) / colorStrength))
        readonly property color colBorderSubtle: ColorUtils.transparentize(
            root.m3colors.m3outlineVariant, 0.82)

        // ─── SURFACE BORDERS (panel/card inner borders) ───
        readonly property int panelBorderWidth: Config.options?.appearance?.angel?.surface?.panelBorderWidth ?? 0
        readonly property int cardBorderWidth: Config.options?.appearance?.angel?.surface?.cardBorderWidth ?? 1
        readonly property real panelBorderOpacity: Config.options?.appearance?.angel?.surface?.panelBorderOpacity ?? 0.0
        readonly property real cardBorderOpacity: Config.options?.appearance?.angel?.surface?.cardBorderOpacity ?? 0.30
        readonly property color colPanelBorder: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (0.99 - panelBorderOpacity) / colorStrength))
        readonly property color colCardBorder: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (0.99 - cardBorderOpacity) / colorStrength))

        // Inset glow — light-from-above effect on top edge
        readonly property real insetGlowOpacity: Config.options?.appearance?.angel?.border?.insetGlowOpacity ?? 0.0
        readonly property color colInsetGlow: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, (1.0 - insetGlowOpacity) / colorStrength))
        readonly property int insetGlowHeight: Config.options?.appearance?.angel?.border?.insetGlowHeight ?? 0

        // ─── GLOW SYSTEM ───
        readonly property real glowOpacity: Config.options?.appearance?.angel?.glow?.opacity ?? 0.80
        readonly property real glowStrongOpacity: Config.options?.appearance?.angel?.glow?.strongOpacity ?? 0.65
        readonly property color colGlow: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, glowOpacity / colorStrength))
        readonly property color colGlowStrong: ColorUtils.transparentize(
            root.m3colors.m3primary, Math.min(1, glowStrongOpacity / colorStrength))

        // ─── TEXT COLORS (light mode: use ink colors for warmth/contrast on glass) ───
        readonly property color colText: root._auroraLightMode ? root.colors._inkPrimary : root.m3colors.m3onSurface
        readonly property color colTextSecondary: root._auroraLightMode ? root.colors._inkSecondary : root.m3colors.m3onSurfaceVariant
        readonly property color colTextMuted: ColorUtils.transparentize(
            root._auroraLightMode ? root.colors._inkMuted : root.m3colors.m3onSurfaceVariant, 0.3)
        readonly property color colTextDim: ColorUtils.transparentize(
            root._auroraLightMode ? root.colors._inkMuted : root.m3colors.m3outline, 0.1)

        // ─── PRIMARY/ACCENT ───
        readonly property color colPrimary: root.m3colors.m3primary
        readonly property color colPrimaryHover: ColorUtils.mix(
            root.m3colors.m3primary, root.m3colors.m3onPrimary, 0.3)
        readonly property color colOnPrimary: root.m3colors.m3onPrimary
        readonly property color colSecondary: root.m3colors.m3secondary
        readonly property color colTertiary: root.m3colors.m3tertiary

        // ─── ROUNDING ───
        readonly property int roundingSmall: Config.options?.appearance?.angel?.rounding?.small ?? 10
        readonly property int roundingNormal: Config.options?.appearance?.angel?.rounding?.normal ?? 15
        readonly property int roundingLarge: Config.options?.appearance?.angel?.rounding?.large ?? 25
    }

    // ═══════════════════════════════════════════════════════════════════
    // ZZZ — generated-color urban graphic identity
    // Uses the wallpaper-generated Material palette as chroma, then forces it
    // through black/white graphic plates, thick strokes, tape textures, and
    // punchy motion. The global palette override lives in `colors`.
    // ═══════════════════════════════════════════════════════════════════
    zzz: QtObject {
        // ── Mode switch: ZZZ has two faces ──
        //   dark  → Hollow/HDD carbon HUD (stepped near-black, light text)
        //   light → New Eridu paper graphic (stepped off-white, ink text)
        // Both keep the generated chroma accent + comic stroke + sharp corners.
        readonly property bool dark: root.m3colors.darkmode

        // Surfaces — poster-console neutrals generated from the wallpaper hue.
        // Raw Material containers inherit too much local wallpaper brown/orange on
        // anime posters; ZZZ needs controlled black/white plates, with wallpaper
        // chroma reserved for signal accents and registration marks.
        readonly property real surfaceHue: root.m3colors.m3background.hslSaturation > 0.02
            ? root.m3colors.m3background.hslHue : root.m3colors.m3primary.hslHue
        // Saturation is held MODERATE on the structural plates: enough that the
        // wallpaper's hue reads through on cards (like material's tinted
        // surfaces) instead of flat carbon, but more restrained than raw
        // material so signal accents still pop. Earlier 0.10 cap killed the
        // wallpaper character and cards read as ugly near-black.
        // (Keeping the 16% / 9% lift factor so warm/anime wallpapers stay
        // tasteful — surfaceSat never reaches raw wallpaper saturation.)
        // Saturation lifted so the wallpaper hue genuinely READS on the plates —
        // at near-black lightness a low cap is invisible, leaving dead grey cards.
        // ZZZ derives its surfaces from the wallpaper like every other style; the
        // higher plates carry the most chroma (where lightness lets it show), the
        // base stays closer to carbon.
        // Carbon-first: surfaces lean near-black like the design-system cards so the
        // signal accents pop, instead of washing the plates with wallpaper hue.
        readonly property real surfaceSat: dark
            ? Math.min(0.14, Math.max(0.035, root.m3colors.m3primary.hslSaturation * 0.26))
            : Math.min(0.10, Math.max(0.03, root.m3colors.m3primary.hslSaturation * 0.16))
        // Dark ramp: base stays carbon (bg0/bg1 near-black for the panel/console
        // read) but the UPPER plates are lifted enough that (a) consecutive layers
        // separate and (b) the wallpaper hue becomes visible on cards/elevated
        // surfaces instead of flat black.
        readonly property color bg0: Qt.hsla(surfaceHue, surfaceSat * 0.7, dark ? 0.022 : 0.980, 1.0)
        readonly property color bg1: Qt.hsla(surfaceHue, surfaceSat * 0.85, dark ? 0.055 : 0.956, 1.0)
        readonly property color bg2: Qt.hsla(surfaceHue, surfaceSat, dark ? 0.092 : 0.926, 1.0)
        readonly property color bg3: Qt.hsla(surfaceHue, surfaceSat, dark ? 0.138 : 0.890, 1.0)
        readonly property color bg4: Qt.hsla(surfaceHue, surfaceSat * 1.08, dark ? 0.180 : 0.850, 1.0)

        // Text — generated on-surface roles, clamped so ZZZ always gets a confident
        // ink on carbon/paper instead of whatever muted onSurfaceVariant the
        // wallpaper pipeline happened to emit.
        readonly property real _inkL: dark ? 0.93 : 0.10
        readonly property color onColor: root.m3colors.m3primary.hslSaturation > 0.02
            ? Qt.hsla(surfaceHue, Math.min(0.18, root.m3colors.m3onSurface.hslSaturation * 0.6), _inkL, 1.0)
            : Qt.hsla(0, 0, _inkL, 1.0)
        // Solid muted ink (not alpha) so small labels stay crisp over textures.
        //
        // CONTRAST GROUND = bg4, NOT bg0. Two reasons, both measured:
        //  1. A constant blend fraction is not a constant contrast. The same 44-46%
        //     mix lands at 4.1:1 over the dark bg0 but 2.8:1 over the light one —
        //     WCAG luminance is far from linear near white.
        //  2. bg0 is the FRIENDLIEST surface in the ramp. Ink actually lands on
        //     panels (chrome at 0.84/0.88 alpha over the wallpaper) and on elevated
        //     cards (bg2..bg4). Guaranteeing contrast against bg0 guarantees it
        //     nowhere else: the bar's muted icons measured 1.65:1 on screen.
        // bg4 is the adverse end of the ramp in BOTH faces (lightest carbon /
        // darkest paper), so pinning the floor there holds everywhere above it.
        readonly property color onMuted: ColorUtils.ensureReadable(
            ColorUtils.mix(onColor, bg0, dark ? 0.46 : 0.44), bg4, 4.5)
        // Alias used by consumers writing text on the bg plate (= onColor on bg0).
        readonly property color onBg: ColorUtils.ensureReadable(onColor, bg0, 7.0)

        // ═══ Signal triad — PURE wallpaper chroma ═══
        // ZZZ uses ONLY the wallpaper-generated material palette. accent, secondary,
        // tertiary come straight from m3primary/m3secondary/m3tertiary (the
        // wallpaper's own triad), each pushed into a readable ZZZ band by
        // saturation/lightness — but the HUE is never rotated. No synthesized
        // greens/purples: the pops are exactly what the wallpaper gives.
        // When the wallpaper is near-grey we gently lift saturation, still on
        // the wallpaper's own hue.
        readonly property color _srcPrimary: root.m3colors.m3primary
        readonly property real _primarySat: _srcPrimary.hslSaturation
        // Signal relax: ZZZ leans ink-paper, so the pops are pulled back from raw
        // wallpaper chroma to a more sophisticated, less neon band. One factor
        // damps the whole triad together so they stay harmonious.
        readonly property real signalRelax: 0.80
        // Readable band: lighten accent for dark ground, deepen for light.
        // Ground is bg4 (the adverse end of the ramp) for the same reason onMuted
        // uses it: accents land on elevated cards and translucent panels, never on
        // the bare bg0 they used to be measured against.
        readonly property color accent: _primarySat > 0.05
            ? ColorUtils.ensureReadable(ColorUtils.adjustSaturation(ColorUtils.colorWithLightness(_srcPrimary, dark ? 0.60 : 0.46), signalRelax), bg4, 4.5)
            : ColorUtils.ensureReadable(ColorUtils.adjustSaturation(_srcPrimary, 1.05), bg4, 4.5)
        readonly property color onAccent: ColorUtils.ensureReadable(root.m3colors.m3onPrimary, accent, 4.5)
        // sticker = the filled/active plate (toggled buttons, active chips). A
        // confident accent at slightly deeper lightness so it reads as "active on"
        // without glare; NOT a muddy accent+ground mix.
        // The two bands used to be 0.46 (dark) and 0.50 (light) — four hundredths
        // apart, so a filled plate rendered the SAME colour in both faces and the
        // weather blob kept reading as dark mode on a light desktop. Now the
        // sticker moves away from its own ground: lighter than carbon, deeper than
        // paper.
        readonly property color sticker: ColorUtils.ensureReadable(
            _primarySat > 0.05 ? ColorUtils.adjustSaturation(ColorUtils.colorWithLightness(_srcPrimary, dark ? 0.58 : 0.40), signalRelax)
                              : ColorUtils.adjustSaturation(_srcPrimary, 1.0),
            bg4, 3.0)
        readonly property color onSticker: ColorUtils.ensureReadable(onAccent, sticker, 4.5)
        // Softer accent for LARGE filled areas (slider fills) so a big block of
        // signal colour reads as a calm console state, not a glare.
        readonly property color accentSoft: ColorUtils.adjustSaturation(ColorUtils.colorWithLightness(_srcPrimary, dark ? 0.50 : 0.52), signalRelax)
        readonly property color onAccentSoft: ColorUtils.ensureReadable(root.m3colors.m3onPrimary, accentSoft, 4.5)
        // secondary/tertiary derive from the wallpaper's own m3secondary/m3tertiary.
        readonly property color secondary: ColorUtils.ensureReadable(
            ColorUtils.adjustSaturation(ColorUtils.colorWithLightness(root.m3colors.m3secondary, dark ? 0.62 : 0.44), signalRelax), bg4, 3.0)
        readonly property color tertiary: ColorUtils.ensureReadable(
            ColorUtils.adjustSaturation(ColorUtils.colorWithLightness(root.m3colors.m3tertiary, dark ? 0.60 : 0.46), signalRelax), bg4, 3.0)
        readonly property color onSecondary: ColorUtils.ensureReadable(onColor, secondary, 4.5)
        readonly property color onTertiary: ColorUtils.ensureReadable(onColor, tertiary, 4.5)

        // Comic stroke — a mid tone between text and ground so it stays visible on
        // BOTH dark and light surfaces (a theme-deep outline went invisible on
        // carbon). Derived from generated roles, no literal colors.
        readonly property color borderColor: ColorUtils.mix(onColor, bg0, 0.36)
        // Subtle hairline for card edges where a full comic stroke is too loud.
        // Kept near-invisible on purpose: zzz plates separate by FILL contrast
        // (bg0..bg4), not outlines — bright edge strokes read as accent borders
        // on every card/button and were removed by maintainer decision.
        readonly property color hairline: ColorUtils.applyAlpha(onColor, 0.08)
        readonly property color hairlineStrong: ColorUtils.applyAlpha(onColor, 0.14)

        // ── Legacy aliases, now mode-aware so paper/ink consumers follow the mode ──
        readonly property color paper: bg1
        readonly property color paperAlt: bg2
        readonly property color ink: onColor
        readonly property color inkMuted: onMuted
        readonly property color chrome: Qt.hsla(surfaceHue, surfaceSat * 0.45, dark ? 0.018 : 0.968, 1.0)
        readonly property color chromeAlt: Qt.hsla(surfaceHue, surfaceSat * 0.52, dark ? 0.042 : 0.935, 1.0)
        // Lifted a touch in dark mode so cards sit clearly above the near-black
        // chrome panel (clean separation now the backdrop grid is gone).
        readonly property color tile: Qt.hsla(surfaceHue, surfaceSat * 0.62, dark ? 0.082 : 0.890, 1.0)
        readonly property color contrastPlate: Qt.hsla(surfaceHue, surfaceSat * 0.36, dark ? 0.860 : 0.085, 1.0)
        readonly property color onContrastPlate: ColorUtils.ensureReadable(onColor, contrastPlate, 4.5)
        readonly property color chromeStroke: ColorUtils.applyAlpha(onColor, dark ? 0.18 : 0.22)
        readonly property color quietStroke: ColorUtils.applyAlpha(onColor, dark ? 0.24 : 0.30)
        readonly property color signal: accent
        readonly property color onSignal: onAccent
        readonly property color posterWarm: secondary
        readonly property color posterCool: tertiary

        // Ornaments
        readonly property color ghostInk: ColorUtils.transparentize(onColor, dark ? 0.90 : 0.91)
        readonly property color hazardStripe1: accent
        readonly property color hazardStripe2: ColorUtils.mix(bg0, accent, dark ? 0.84 : 0.72)
        readonly property color registrationRail: ColorUtils.applyAlpha(onColor, dark ? 0.24 : 0.30)
        readonly property color registrationMark: accent
        readonly property color registrationMarkAlt: secondary
        readonly property color diagonalStripe: ColorUtils.transparentize(onColor, 0.94)
        readonly property color stickerAccentMagenta: secondary
        readonly property color stickerAccentCyan: tertiary

        // Industrial signal roles — the ZZZ "console" accents. NO hardcoded colours:
        // these are generated from the wallpaper hue plus harmonic offsets, so
        // every color theme keeps its own base while gaining the ZZZ pop range.
        // (Names kept for the consumers that reference them; values are generated.)
        readonly property color lemonLime: secondary
        readonly property color pureOrange: accent
        readonly property color limeInk: onSecondary
        readonly property color orangeInk: onAccent
        readonly property color limeReadable: ColorUtils.ensureReadable(lemonLime, bg0, 4.5)
        readonly property color orangeReadable: ColorUtils.ensureReadable(pureOrange, bg0, 4.5)
        readonly property color technicalGrid: ColorUtils.transparentize(onColor, dark ? 0.92 : 0.89)
        readonly property color technicalGridStrong: ColorUtils.transparentize(onColor, dark ? 0.74 : 0.70)
        readonly property color technicalMarker: accent
        readonly property color technicalWarning: secondary
        readonly property color metricTrack: ColorUtils.transparentize(onColor, dark ? 0.86 : 0.82)
        readonly property color metricFill: accent

        // Shape — poster UI: squared console surfaces with tiny manufactured
        // radii. No Material pills as the default ZZZ silhouette.
        // Shape — ZZZ personality axis. "square" = sharp console plates with
        // tiny manufactured radii and a cut-corner chamfer (classic ZZZ).
        // "round" = softer anime UI — pill controls, rounded panels, no chamfer.
        // Driven from config so the user flips the whole shell from settings.
        readonly property bool  round: (Config.options?.appearance?.zzz?.shape ?? "square") === "round"
        // ── Shape morph axis (cookie-clock feel, applied shell-wide) ──
        // `round` is the boolean source of truth from config; `shapeT` is its
        // ANIMATED real mirror in [0,1]. Every geometric token below is bound
        // to shapeT instead of to `round` directly, so flipping the shape in
        // settings morphs every radius/chamfer in the shell fluidly instead of
        // teleporting — one Behavior here, propagated through existing bindings
        // to every consumer. (Pill radius stays a step: animating 9999 is
        // nonsensical and pills are meant to read as full-or-not.) Gate the
        // Behavior on animationsEnabled; use the zzz back-out curve so the morph
        // carries the same mechanical punch as the cookie clock and popups.
        property real shapeT: round ? 1.0 : 0.0
        Behavior on shapeT {
            enabled: root.animationsEnabled && root.zzzEverywhere
            NumberAnimation {
                duration: root.zzz.overshootDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.animationCurves.zzzOvershoot
            }
        }
        // Stroke weight — a single 1px hairline in BOTH modes. The softer
        // round read comes from radius + the dropped chamfer, never from a
        // thicker line (a thick border in round mode reads cluttered, and the
        // earlier `borderThick: round ? 1 : 1` was a no-op anyway).
        readonly property int   borderThick: 1
        readonly property int   hairlineThick: 1
        // Base shape primitive. A SENSIBLE small radius in BOTH modes (was
        // `round ? 9999 : 2` — the 9999 turned every badge/card/tile/slider
        // handle that consumed it into a stadium pill and broke the round-
        // mode settings UI: each SettingsCardSection became impossible).
        // Now: 2 square (console) / 12 round (anime). Real pills use pillRadius.
        // Interpolated by shapeT so the flip morphs instead of stepping.
        readonly property real  cornerRadius: 2 + 10 * shapeT
        // Cards — square 3 / round 12 (calm plate, NOT a pill).
        readonly property real  cardRadius: 3 + 9 * shapeT
        // Controls (buttons/toggles/sliders) — square 3 / round 14.
        readonly property real  controlRadius: 3 + 11 * shapeT
        // Panels/surfaces — square 4 / round 18.
        readonly property real  panelRadius: 4 + 14 * shapeT
        // Chamfer cut — the ZZZ square signature; disabled in round (anime = soft).
        // Clamped at 0 so overshoot never drives it negative.
        readonly property real  cutCorner: Math.max(0, 18 * (1.0 - shapeT))
        readonly property int   markerLength: 16
        readonly property int   markerThickness: 2
        // Poster letter-spacing — the magazine/console crispness from the zzz
        // design-system cards. Absolute px (small, so it never overflows tight
        // layouts), and dropped in round mode where the soft anime read wants
        // tighter type. `tracking` = global body/label baseline applied centrally
        // in StyledText; `labelTracking` = stronger value for uppercase headers.
        readonly property real  tracking: 0.75 * (1.0 - shapeT)
        readonly property real  labelTracking: 1.6 * (1.0 - shapeT)
        // Actual pills (switch thumbs, circular badges, dot indicators). Square
        // mode keeps the console read (controlRadius), round mode = 9999 so
        // `Appearance.rounding.full` consumers become true circles/pills.
        readonly property int   pillRadius: round ? 9999 : Math.round(controlRadius)
        // Rounding ladder consumed via Appearance.rounding.* dispatch.
        readonly property real  roundSmall: 2 + 8 * shapeT
        readonly property real  roundNormal: 3 + 11 * shapeT
        readonly property real  roundLarge: 5 + 15 * shapeT
        readonly property bool  useHalftone: true
        readonly property bool  useDiagonals: true
        readonly property var   overshootCurve: [0.34, 1.56, 0.64, 1.0] // back-out punch
        readonly property int   overshootDuration: 320
    }

    // ═══════════════════════════════════════════════════════════════════
    // COOKIE — Material 3 Expressive
    //
    // Cookie's shapes shipped before its tokens did, so it read the whole
    // material palette and every material radius and only swapped some
    // rectangles for organic silhouettes. Shape alone is not an identity:
    // above CookieFace's aspect ceiling the silhouette falls back to a plain
    // rectangle, which is most of the screen, so the style WAS material.
    //
    // What actually separates Expressive from material is not the polygon, it
    // is colour and scale: tinted surfaces instead of near-neutral greys,
    // markedly larger radii, and motion that overshoots. That lives here.
    // ═══════════════════════════════════════════════════════════════════
    cookie: QtObject {
        readonly property bool dark: root.m3colors.darkmode

        // ── Surfaces: dough, not grey ──
        // Material's surfaceContainer roles are near-neutral by design. Cookie
        // bakes the theme hue into the plates instead, which is the single
        // change that stops it reading as material.
        //
        // Saturation is held well UNDER m3primaryContainer's, on purpose: the
        // cookie faces are painted in that container role, and if the plates
        // reached the same chroma the silhouettes would sink into their own
        // background and the style would lose the one thing it already had.
        readonly property real surfaceHue: root.m3colors.m3primary.hslSaturation > 0.02
            ? root.m3colors.m3primary.hslHue : root.m3colors.m3background.hslHue
        // Chroma is the seasoning, not the dish. The first pass ran the plates hot
        // enough that the shell read as tinted rather than as cookie; the identity
        // is carried by the LIGHTNESS spread below, so the tint can come down a
        // long way without costing the style anything.
        readonly property real surfaceSat: dark
            ? Math.min(0.15, Math.max(0.05, root.m3colors.m3primary.hslSaturation * 0.26))
            : Math.min(0.10, Math.max(0.035, root.m3colors.m3primary.hslSaturation * 0.19))

        // The ramp is the identity. Material's dark plates sit between L=0.03 and
        // L=0.15 — so compressed that bg0 against bg2 lands at a 1.11 contrast
        // ratio and the layers do not visually separate at all; depth comes from
        // borders and shadows instead. Expressive stacks tonal plates and expects
        // you to SEE the stack, so cookie lifts the floor and spreads the steps.
        readonly property color bg0: Qt.hsla(surfaceHue, surfaceSat * 0.80, dark ? 0.075 : 0.980, 1.0)
        readonly property color bg1: Qt.hsla(surfaceHue, surfaceSat * 0.90, dark ? 0.130 : 0.948, 1.0)
        readonly property color bg2: Qt.hsla(surfaceHue, surfaceSat, dark ? 0.190 : 0.912, 1.0)
        readonly property color bg3: Qt.hsla(surfaceHue, surfaceSat * 1.10, dark ? 0.260 : 0.868, 1.0)
        readonly property color bg4: Qt.hsla(surfaceHue, surfaceSat * 1.20, dark ? 0.330 : 0.818, 1.0)

        // ── Faces: the plate a silhouette is painted on ──
        // Lifting the ramp put the raw m3*Container roles at the same lightness as
        // the plates they sit on — measured at a 1.10 contrast ratio against bg2,
        // i.e. invisible. A cookie whose silhouettes sink into the panel would
        // lose the one thing the style already had, so the containers get their
        // own recipe: the theme's chroma at a lightness that clears the dough.
        readonly property real _faceL: dark ? 0.38 : 0.78
        function _face(seed: color): color {
            return Qt.hsla(seed.hslHue,
                Math.min(0.44, Math.max(0.20, seed.hslSaturation * 0.75)), _faceL, 1.0)
        }
        readonly property color primaryFace: _face(root.m3colors.m3primary)
        readonly property color secondaryFace: _face(root.m3colors.m3secondary)
        readonly property color tertiaryFace: _face(root.m3colors.m3tertiary)
        // One ink for all three: they share a lightness, so one clamp covers them.
        readonly property color onFace: ColorUtils.ensureReadable(
            dark ? Qt.hsla(surfaceHue, 0.10, 0.97, 1.0) : Qt.hsla(surfaceHue, 0.35, 0.10, 1.0),
            primaryFace, 4.5)

        // ── Ink ──
        readonly property real _inkL: dark ? 0.94 : 0.13
        readonly property color onColor: Qt.hsla(surfaceHue,
            Math.min(0.20, root.m3colors.m3onSurface.hslSaturation * 0.5), _inkL, 1.0)
        readonly property color inkMuted: ColorUtils.applyAlpha(onColor, dark ? 0.62 : 0.58)

        // ── Separation is by fill, not by outline ──
        // Expressive stacks tonal plates; a visible border on every surface
        // would fight the silhouettes. The hairline exists only for the cases
        // that genuinely need an edge (inputs, focus).
        readonly property color hairline: ColorUtils.applyAlpha(onColor, 0.08)
        readonly property color borderColor: ColorUtils.applyAlpha(onColor, 0.14)

        // ── Elevation: tonal first, short contact shadow second ──
        // Cookie surfaces separate primarily through the bg ramp. Floating
        // surfaces get a compact shadow so they read above the desktop without
        // inheriting Material's wide ambient haze. Dense settings cards use the
        // same color/offset as a cheap unblurred contact layer.
        readonly property color shadowColor: ColorUtils.applyAlpha(
            Qt.rgba(0, 0, 0, 1), dark ? 0.32 : 0.16)
        readonly property color cardShadowColor: ColorUtils.applyAlpha(
            Qt.rgba(0, 0, 0, 1), dark ? 0.18 : 0.10)
        readonly property real shadowBlur: 6
        readonly property real shadowOffset: 2
        readonly property real cardShadowOffset: 1.5
        readonly property real shadowSpread: 0

        // ── Radii: pill controls, pebble plates ──
        // Material lands on 8/12/17/23/30. Cookie is deliberately a step above
        // at every stop, so the roundness reads as a choice rather than as
        // material with the corners nudged.
        readonly property int roundVerySmall: 12
        readonly property int roundSmall: 16
        readonly property int roundNormal: 24
        readonly property int roundLarge: 32
        readonly property int panelRadius: 40
        // Controls are full pills. CookieFace already does this for the
        // silhouettes; the rectangle fallback has to agree or a button changes
        // shape the moment it grows past the aspect ceiling.
        readonly property int controlRadius: 9999

        // ── Motion: it has to bounce ──
        // The 1.67 overshoot lived only inside ShapeCanvas, so a shape morphed
        // expressively while everything around it moved on material's curves.
        // Cookie pushes the spring out to the whole shell.
        readonly property var spring: [0.34, 1.75, 0.36, 1.0, 1, 1]
        readonly property int springDuration: 420
    }

     sizes: QtObject {
         property real spacingSmall: Math.round(8 * root.fontSizeScale)
         property real spacingMedium: Math.round(12 * root.fontSizeScale)
         property real spacingLarge: Math.round(16 * root.fontSizeScale)
        property real baseBarHeight: Math.round(Math.max(24, Math.min(80, (Config.options?.bar?.height ?? 40))) * root.fontSizeScale)
        property real barHeight: (((Config.options?.bar?.cornerStyle ?? 0) === 1) || ((Config.options?.bar?.cornerStyle ?? 0) === 3)) ? 
            (baseBarHeight + root.sizes.hyprlandGapsOut * 2) : baseBarHeight
        property real barCenterSideModuleWidth: (Config.options?.bar?.verbose ?? true) ? Math.round(360 * root.fontSizeScale) : Math.round(140 * root.fontSizeScale)
        property real barCenterSideModuleWidthShortened: Math.round(280 * root.fontSizeScale)
        property real barCenterSideModuleWidthHellaShortened: Math.round(190 * root.fontSizeScale)
        property real barShortenScreenWidthThreshold: 1200 // Shorten if screen width is at most this value
        property real barHellaShortenScreenWidthThreshold: 1000 // Shorten even more...
        property real elevationMargin: Math.round(10 * root.fontSizeScale)
        property real fabShadowRadius: 5
        property real fabHoveredShadowRadius: 7
        property real hyprlandGapsOut: 5
        property real mediaControlsWidth: Math.round(380 * root.fontSizeScale)
        property real mediaControlsHeight: Math.round(150 * root.fontSizeScale)
        property real notificationPopupWidth: Math.round(410 * root.fontSizeScale)
        property real osdWidth: Math.round(180 * root.fontSizeScale)
        property real searchWidthCollapsed: Math.round(210 * root.fontSizeScale)
        property real searchWidth: Math.round(360 * root.fontSizeScale)
        property real sidebarWidth: Math.round(460 * root.fontSizeScale)
        property real sidebarWidthExtended: Math.round(750 * root.fontSizeScale)
        property real baseVerticalBarWidth: Math.round(46 * root.fontSizeScale)
        property real verticalBarWidth: (((Config.options?.bar?.cornerStyle ?? 0) === 1) || ((Config.options?.bar?.cornerStyle ?? 0) === 3)) ? 
            (baseVerticalBarWidth + root.sizes.hyprlandGapsOut * 2) : baseVerticalBarWidth
        // Legacy selector fixed-card sizing (kept for compatibility; skwd-wall selector computes layout internally)
        property real wallpaperSelectorWidth: 1200
        property real wallpaperSelectorHeight: 690
        property real wallpaperSelectorItemMargins: 8
        property real wallpaperSelectorItemPadding: 6
    }

    syntaxHighlightingTheme: root.m3colors.darkmode ? "Monokai" : "ayu Light"

    // Toggle dark mode - switches between light and dark variants of current theme
    function toggleDarkMode(): void {
        const newMode = !root.m3colors.darkmode
        // Update the custom theme darkmode setting
        Config.setNestedValue("appearance.customTheme.darkmode", newMode)
        // If using auto theme, regenerate from wallpaper with new mode
        if (ThemeService.isAutoTheme) {
            ThemeService.regenerateAutoTheme()
        } else {
            // For preset themes, just toggle the darkmode flag directly
            root.m3colors.darkmode = newMode
        }
    }
}
