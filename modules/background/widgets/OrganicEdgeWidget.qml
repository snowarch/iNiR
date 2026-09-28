pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models
import qs.modules.common.widgets
import "OrganicEdgeConfig.js" as EdgeConfig

Item {
    id: root
    property string screenName: ""
    readonly property string configPath: EdgeConfig.path
    function value(key: string): var {
        return Config.getNestedValue(root.configPath + "." + key, EdgeConfig.defaults[key])
    }
    function number(key: string, low: real, high: real): real {
        const n = Number(root.value(key))
        return Math.max(low, Math.min(high, Number.isFinite(n) ? n : EdgeConfig.defaults[key]))
    }
    readonly property bool configuredEnabled: Boolean(root.value("enable"))
    readonly property var configuredScreens: root.value("screenList") ?? []
    readonly property bool outputAllowed: configuredScreens.length === 0
        || configuredScreens.indexOf(root.screenName) >= 0
    readonly property var selectedEdges: EdgeConfig.selectedEdges(root.value("edges"), root.value("edge"))
    readonly property bool audioReactive: Boolean(root.value("audioReactive"))
    readonly property string idleMode: String(root.value("idleMode"))
    readonly property real restPresence: root.number("restPresence", 0, 100) / 100
    readonly property bool renderAllowed: configuredEnabled && outputAllowed
        && !(Config.options?.panelFamily === "iris" && (Config.options?.iris?.surround?.enable ?? false)
            && String(Config.options?.iris?.surround?.music ?? "widget") === "frame")
        && !GlobalStates.screenLocked && !GameMode.visualizersSuppressed
        && !Appearance.gameModeMinimal && WidgetPowerManager.widgetsActiveForOutput(root.screenName)
    // Same rule as a live wallpaper: behind fullscreen or tiled windows spanning the output it holds still.
    readonly property bool motionAllowed: Wallpapers.videoMotionAllowedOn(root.screenName)
    readonly property var insets: root.value("respectPanels")
        ? ShellLayoutController.desktopInsets(root.screenName) : ({left: 0, top: 0, right: 0, bottom: 0})
    readonly property real margin: root.number("inset", 0, 160)
    readonly property string palette: EdgeConfig.paletteValue(root.value("palette"))
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property real audioPresence: root.audioReactive
        ? Math.min(1, (fieldLoader.item?.energy ?? 0) * 1.5)
        : 1
    readonly property real idlePresence: root.audioReactive
        ? (root.idleMode === "hidden" ? root.audioPresence
            : root.restPresence + (1 - root.restPresence) * root.audioPresence)
        : 1
    function visualColor(value, fallback, saturationFloor, saturationBoost, hueShift) {
        const source = Qt.color(value)
        const safe = source.valid ? source : Qt.color(fallback)
        const fallbackColor = Qt.color(fallback)
        let hue = safe.hslHue >= 0 ? safe.hslHue
            : (fallbackColor.hslHue >= 0 ? fallbackColor.hslHue : 0)
        hue = (hue + hueShift / 360 + 1) % 1
        const saturation = Math.max(0, Math.min(1,
            Math.max(saturationFloor, safe.hslSaturation * saturationBoost)))
        const minLightness = Appearance.m3colors.darkmode ? 0.45 : 0.30
        const maxLightness = Appearance.m3colors.darkmode ? 0.72 : 0.62
        return Qt.hsla(hue, saturation,
            Math.max(minLightness, Math.min(maxLightness, safe.hslLightness)), 1)
    }
    function customColor(key: string, fallback: color): color {
        const configured = String(root.value(key))
        return /^#(?:[0-9a-f]{6}|[0-9a-f]{8})$/i.test(configured) ? configured : fallback
    }
    function iridescentColor(offset: real): color {
        const accent = Appearance.colors.colPrimary
        const hue = accent.hslHue >= 0 ? accent.hslHue : 0.72
        return Qt.hsla((hue + offset) % 1, Math.max(0.55, accent.hslSaturation), 0.68, 1)
    }
    function tuneColor(base: color): color {
        const shift = root.number("hueShift", -180, 180) / 360
        const intensity = root.number("colorIntensity", 0, 150) / 100
        const hue = base.hslHue >= 0 ? base.hslHue : 0
        const saturation = Math.max(0, Math.min(1, base.hslSaturation * intensity))
        const lightness = Math.max(0.08, Math.min(0.92,
            0.5 + (base.hslLightness - 0.5) * (0.82 + intensity * 0.18)))
        return Qt.hsla((hue + shift + 1) % 1, saturation, lightness, 1)
    }
    function albumColor(index: int, fallback: color): color {
        const colors = albumArtworkQuantizer?.colors ?? []
        if (colors.length === 0)
            return fallback
        return root.visualColor(colors[Math.min(index, colors.length - 1)],
            fallback, 0.34, 1.24, 0)
    }
    AdaptedMaterialScheme {
        id: wallpaperScheme
        color: Appearance.wallpaperDominantColor
    }
    readonly property var wallpaperPalette: [
        root.visualColor(wallpaperScheme.colPrimary, Appearance.colors.colPrimary, 0.30, 1.18, 0),
        root.visualColor(wallpaperScheme.colSecondary, Appearance.colors.colSecondary, 0.28, 1.12, 0),
        root.visualColor(ColorUtils.mix(Appearance.wallpaperDominantColor,
            Appearance.colors.colTertiary, 0.42), Appearance.colors.colTertiary, 0.30, 1.16, 0)
    ]
    readonly property bool albumPaletteAvailable: (albumArtworkQuantizer?.colors?.length ?? 0) > 0
    readonly property var adaptivePalette: root.albumPaletteAvailable
        ? [root.albumColor(0, root.wallpaperPalette[0]),
            root.albumColor(1, root.wallpaperPalette[1]),
            root.albumColor(2, root.wallpaperPalette[2])]
        : root.wallpaperPalette
    function sourceColor(index: int): color {
        const palette = root.palette === "album"
            ? (root.albumPaletteAvailable ? root.adaptivePalette : root.wallpaperPalette)
            : root.palette === "theme"
                ? [Appearance.colors.colPrimary, Appearance.colors.colSecondary, Appearance.colors.colTertiary]
                : root.palette === "adaptive" ? root.adaptivePalette : root.wallpaperPalette
        return palette[Math.min(index, palette.length - 1)]
    }
    function hueDistance(first: color, second: color): real {
        if (first.hslHue < 0 || second.hslHue < 0)
            return 0
        const delta = Math.abs(first.hslHue - second.hslHue)
        return Math.min(delta, 1 - delta)
    }
    function profiledColor(index: int): color {
        const source = root.sourceColor(index)
        if (root.palette === "adaptive") {
            const anchor = root.sourceColor(0)
            const shift = index > 0 && root.hueDistance(anchor, source) < 0.065
                ? (index === 1 ? 26 : -32) : 0
            const fallback = index === 0 ? Appearance.colors.colPrimary
                : index === 1 ? Appearance.colors.colSecondary : Appearance.colors.colTertiary
            return root.visualColor(source, fallback, 0.36, 1.22, shift)
        }
        if (root.palette === "vivid")
            return root.visualColor(source, Appearance.colors.colPrimary, 0.82, 1.75,
                index === 0 ? -28 : index === 2 ? 34 : 0)
        if (root.palette === "cool")
            return root.visualColor(source, Appearance.colors.colPrimary, 0.42, 1.20,
                index === 0 ? -14 : index === 2 ? 12 : -4)
        if (root.palette === "warm")
            return root.visualColor(source, Appearance.colors.colTertiary, 0.46, 1.28,
                index === 0 ? 12 : index === 2 ? -10 : 4)
        return source
    }
    readonly property color rawPrimary: root.palette === "iridescent" ? root.iridescentColor(0)
        : root.palette === "custom" ? root.customColor("primaryColor", Appearance.colors.colPrimary)
        : root.palette === "mono" ? root.sourceColor(0)
        : root.profiledColor(0)
    readonly property color rawSecondary: root.palette === "iridescent" ? root.iridescentColor(0.16)
        : root.palette === "custom" ? root.customColor("secondaryColor", Appearance.colors.colSecondary)
        : root.palette === "mono" ? root.rawPrimary
        : root.profiledColor(1)
    readonly property color rawTertiary: root.palette === "iridescent" ? root.iridescentColor(0.86)
        : root.palette === "custom" ? root.customColor("tertiaryColor", Appearance.colors.colTertiary)
        : root.palette === "mono" ? root.rawPrimary
        : root.profiledColor(2)
    readonly property color primary: root.tuneColor(root.rawPrimary)
    readonly property color secondary: root.tuneColor(root.rawSecondary)
    readonly property color tertiary: root.tuneColor(root.rawTertiary)

    MediaArtworkResolver {
        id: albumArtworkResolver
        sourceUrl: root.palette === "album" || root.palette === "adaptive"
            ? MprisController.effectiveArtUrl(root.activePlayer) : ""
        title: root.activePlayer?.trackTitle ?? ""
        artist: root.activePlayer?.trackArtist ?? ""
        album: root.activePlayer?.trackAlbum ?? ""
    }

    ColorQuantizer {
        id: albumArtworkQuantizer
        source: root.palette === "album" || root.palette === "adaptive"
            ? albumArtworkResolver.displaySource : ""
        depth: 2
        rescaleSize: 24
    }

    function diagnostics(): var {
        return {output: root.screenName, enabled: root.configuredEnabled,
            allowed: root.outputAllowed, renderAllowed: root.renderAllowed,
            edges: root.selectedEdges, palette: root.palette,
            shape: String(root.value("shape")), joinMode: String(root.value("joinMode")),
            colorMode: String(root.value("colorMode")), effectMode: String(root.value("effectMode")),
            flowDirection: String(root.value("flowDirection")),
            idleMode: root.idleMode, restPresence: root.restPresence,
            audioPresence: root.audioPresence, idlePresence: root.idlePresence,
            paletteColors: [String(root.primary), String(root.secondary), String(root.tertiary)],
            albumColorCount: root.palette === "album" || root.palette === "adaptive"
                ? (albumArtworkQuantizer?.colors?.length ?? 0) : 0,
            audioSubscribed: cava.held,
            frame: {x: fieldLoader.x, y: fieldLoader.y, width: fieldLoader.width, height: fieldLoader.height},
            loaded: fieldLoader.item !== null, opacity: fieldLoader.opacity,
            material: {
                bodyOpacity: root.number("bodyOpacity", 0, 100),
                crestStrength: root.number("crestStrength", 0, 150),
                glow: root.number("glow", 0, 100),
                glowSpread: root.number("glowSpread", 0, 100)
            },
            response: {
                sensitivity: root.number("sensitivity", 0, 200),
                audioRange: root.number("audioRange", 0, 150),
                pulse: root.number("pulse", 0, 150),
                beatGlow: root.number("beatGlow", 0, 150),
                transient: root.number("transientStrength", 0, 150),
                bass: root.number("bassDrive", 0, 150),
                treble: root.number("trebleDrive", 0, 150),
                attack: root.number("attack", 20, 250),
                release: root.number("release", 20, 250)
            },
            shaderStatus: fieldLoader.item?.shaderStatus ?? -1,
            shaderLog: fieldLoader.item?.shaderLog ?? "",
            motionPhase: fieldLoader.item?.motionPhase ?? -1,
            effectiveMotionSpeed: fieldLoader.item?.effectiveMotionSpeed ?? -1,
            audioActive: cava.audioSignalActive,
            energy: fieldLoader.item?.energy ?? 0}
    }

    visible: renderAllowed
    enabled: false
    CavaProcess {
        id: cava
        active: root.renderAllowed && root.audioReactive && root.motionAllowed
        sampleCount: 96
    }
    Loader {
        id: fieldLoader
        x: (root.insets.left ?? 0) + root.margin
        y: (root.insets.top ?? 0) + root.margin
        width: Math.max(0, root.width - x - (root.insets.right ?? 0) - root.margin)
        height: Math.max(0, root.height - y - (root.insets.bottom ?? 0) - root.margin)
        opacity: root.number("opacity", 0, 100) / 100 * root.idlePresence
        active: root.renderAllowed && width > 0 && height > 0
            && (!root.audioReactive || root.idleMode !== "hidden"
                || cava.audioSignalActive || root.audioPresence > 0.003)
        sourceComponent: OrganicScreenEdge {
            id: edgeField
            active: root.renderAllowed
            animate: Appearance.animationsEnabled && root.motionAllowed
                && (cava.audioSignalActive || edgeField.energy > 0.005
                    || (root.idleMode === "ambient" && root.number("idleMotion", 0, 100) > 0))
            points: root.audioReactive ? cava.points : []
            normalizationCeiling: cava.normalizationCeiling
            mirroredStereo: false
            edges: Qt.vector4d(root.selectedEdges.includes("top") ? 1 : 0,
                root.selectedEdges.includes("right") ? 1 : 0,
                root.selectedEdges.includes("bottom") ? 1 : 0,
                root.selectedEdges.includes("left") ? 1 : 0)
            depths: Qt.vector4d(
                Math.min(height * 0.45, root.number("depth", 24, 600) * root.number("topScale", 10, 200) / 100),
                Math.min(width * 0.45, root.number("depth", 24, 600) * root.number("rightScale", 10, 200) / 100),
                Math.min(height * 0.45, root.number("depth", 24, 600) * root.number("bottomScale", 10, 200) / 100),
                Math.min(width * 0.45, root.number("depth", 24, 600) * root.number("leftScale", 10, 200) / 100))
            span: root.number("span", 10, 100) / 100
            position: root.number("position", 0, 100) / 100
            taper: root.number("taper", 0, 50) / 100
            cornerRadius: root.number("cornerRadius", 0, 160)
            cornerBlend: root.number("cornerBlend", 0, 100) / 100
            flowDirection: String(root.value("flowDirection")) === "counterclockwise" ? -1 : 1
            thickness: root.number("thickness", 5, 70) / 100
            detail: root.number("detail", 0, 100) / 100
            material: Math.max(0, ["silk", "aurora", "contour", "liquid"].indexOf(String(root.value("style"))))
            primaryColor: root.primary
            secondaryColor: root.secondary
            tertiaryColor: root.tertiary
            colorSpeed: root.number("colorSpeed", 0, 100) / 100
            glow: root.number("glow", 0, 100) / 100
            colorMode: Math.max(0, ["flow", "spectrum", "pulse", "static"].indexOf(String(root.value("colorMode"))))
            effectMode: Math.max(0, ["clean", "shimmer", "echo", "prism", "bloom", "caustic", "afterglow"].indexOf(String(root.value("effectMode"))))
            effectStrength: root.number("effectStrength", 0, 100) / 100
            shapeMode: Math.max(0, ["flow", "ribbon", "cells", "filament"].indexOf(String(root.value("shape"))))
            joinConnected: String(root.value("joinMode")) !== "separate"
            bodyOpacity: root.number("bodyOpacity", 0, 100) / 100
            crestStrength: root.number("crestStrength", 0, 150) / 100
            glowSpread: root.number("glowSpread", 0, 100) / 100
            audioRange: root.number("audioRange", 0, 150) / 100
            bassDrive: root.number("bassDrive", 0, 150) / 100
            trebleDrive: root.number("trebleDrive", 0, 150) / 100
            transientStrength: root.number("transientStrength", 0, 150) / 100
            beatGlow: root.number("beatGlow", 0, 150) / 100
            smoothing: root.number("smoothing", 0, 8)
            frequencyProfile: String(root.value("frequencyProfile"))
            accentStrength: root.number("accentStrength", 0, 100) / 100
            sensitivity: root.number("sensitivity", 0, 200) / 100
            pulseStrength: root.number("pulse", 0, 150) / 100
            compression: root.number("compression", 0, 100) / 100
            motionSpeed: root.number("motionSpeed", 0, 250) / 100
            idleMotion: root.number("idleMotion", 0, 100) / 100
            attackScale: root.number("attack", 20, 250) / 100
            releaseScale: root.number("release", 20, 250) / 100
            smoothTuning: Appearance.animationsEnabled
            tuningDuration: 150
        }
    }
}
