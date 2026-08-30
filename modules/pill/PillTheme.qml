pragma Singleton

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Pill palette, mapped onto iNiR's generated Material scheme. Token names are
 * kept exactly as the upstream pill chrome expects them (verm/cream/cardTop/…)
 * so the ported components bind without rewrites; only the sources change.
 *
 * The accent ramp follows colPrimary, the text family follows the layer-0 ink,
 * and the surfaces follow the container ramp, so the pill breathes with the
 * wallpaper like the rest of the shell.
 */
Singleton {
    id: root

    readonly property color accent: Appearance.colors.colPrimary
    readonly property color ink: Appearance.colors.colOnLayer0

    /**
     * Canvas gradient stops take raw hex strings only: a color property
     * serializes to #aarrggbb, which addColorStop parses as #rrggbbaa and
     * silently corrupts the ramp. Rebuild a strict 6-digit hex from the channels
     * instead of relying on toString().
     *
     * OPAQUE ONLY. Six digits carry no alpha, so passing an alpha-bearing token
     * (hair, hairSoft, sheen, threadBg, frameBg, frameBorder, creamMenu) through
     * here paints it fully opaque — a 0.13 cream hairline becomes a solid cream
     * band. Use `canvasColor` for anything that is not a gradient stop.
     */
    function hex(c) {
        const f = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return "#" + f(c.r) + f(c.g) + f(c.b);
    }

    /**
     * Alpha-preserving colour for ctx.strokeStyle/fillStyle. Qt's Context2D
     * documents Qt.rgba() as a valid — and the fastest — style value, since it
     * is already a QColor and skips string parsing, so the alpha channel of a
     * token survives the assignment. Only CanvasGradient.addColorStop needs the
     * string form from `hex`.
     */
    function canvasColor(c) {
        return Qt.rgba(c.r, c.g, c.b, c.a);
    }

    readonly property color onGlow: accent

    readonly property color verm: Qt.darker(accent, 1.18)
    readonly property color vermLit: accent
    readonly property color vermDeep: Appearance.colors.colPrimaryContainer
    readonly property color vermDim: Qt.darker(accent, 1.5)
    readonly property color vermDimDeep: Qt.darker(accent, 2.2)
    readonly property color vermBurn: Qt.darker(Appearance.colors.colPrimaryContainer, 1.1)

    readonly property color cream: ink
    readonly property color bright: Appearance.colors.colOnLayer1
    readonly property color dim: Appearance.colors.colSubtext
    readonly property color subtle: Appearance.colors.colOnLayer2
    readonly property color faint: Appearance.colors.colOnLayer2Disabled
    readonly property color iconDim: Appearance.colors.colOnLayer1

    readonly property color cardTop: Appearance.colors.colLayer3
    readonly property color cardBot: Appearance.colors.colLayer1
    readonly property color tileBg: Appearance.colors.colLayer2
    readonly property color ghost: Appearance.colors.colLayer2Active
    readonly property color border: Appearance.colors.colLayer0Border

    readonly property color hair: Qt.alpha(cream, 0.13)
    readonly property color hairSoft: Qt.alpha(cream, 0.08)
    readonly property color sheen: Qt.alpha(cream, 0.07)
    readonly property color threadBg: Qt.alpha(cream, 0.13)
    readonly property color frameBg: Qt.alpha(cream, 0.055)
    readonly property color frameBorder: Qt.alpha(cream, 0.10)
    readonly property color creamMenu: Qt.alpha(cream, 0.82)

    readonly property color tickRest: Appearance.colors.colOnLayer2
    readonly property color todayWarm: onGlow
    readonly property color flameCore: Qt.lighter(onGlow, 1.03)
    readonly property color flameGlow: onGlow

    readonly property string flameInk: root.hex(accent)
    readonly property string flameEmber: root.hex(Appearance.colors.colPrimaryContainer)
    readonly property string flameBurn: root.hex(Qt.darker(Appearance.colors.colPrimaryContainer, 1.1))
    readonly property string flameTip: root.hex(Appearance.colors.colOnPrimaryContainer)

    readonly property color shadow: Qt.rgba(0, 0, 0, 0.55)
    readonly property real shadowOpacity: 0.5

    /** Shared Ricelin material. Pill and every Island surface read one owner. */
    readonly property real islandRadius: Config.options?.appearance?.island?.radius ?? 18
    readonly property bool islandShadow: Config.options?.appearance?.island?.shadow ?? true
    readonly property bool islandSheen: Config.options?.appearance?.island?.sheen ?? true
    readonly property bool islandGlass: Config.options?.appearance?.island?.glass ?? true
    readonly property real islandGlassBlur: Config.options?.appearance?.island?.glassBlur ?? 1
    readonly property real islandOpacity: Config.options?.appearance?.island?.opacity ?? 1

    /**
     * Global-style character. Ricelin keeps its own deliberate radius ladder
     * (card 18 / open 22 / tile 13 / chip 7) under every style that is itself
     * soft — inheriting Appearance.rounding wholesale would erase the dialect.
     * ZZZ is the one style whose identity is hard chrome, and it already exposes
     * a square/round personality axis, so square ZZZ collapses the ladder to a
     * near-sharp edge while round ZZZ leaves Ricelin alone.
     */
    readonly property bool sharpChrome: Appearance.zzzEverywhere && !(Appearance.zzz?.round ?? false)
    readonly property real cornerScale: sharpChrome ? 0.12 : 1

    /** Body corner in unscaled px: the user's skin radius, in the style's character. */
    readonly property real cardCorner: Math.max(0, Math.round(islandRadius * cornerScale))
    /** Open surfaces sit one step softer than the resting body, as upstream did. */
    readonly property real openCorner: Math.max(0, Math.round((islandRadius + 4) * cornerScale))

    readonly property real pillOpacity: islandOpacity
    readonly property bool showGlyphs: Config.options?.bar?.pill?.showGlyphs ?? true
    readonly property bool clockSeconds: Config.options?.bar?.pill?.clockSeconds ?? false
    readonly property bool time12h: Config.options?.bar?.pill?.time12h ?? false

    readonly property string font: Appearance.font.family.main
    readonly property string fontJp: "Zen Kaku Gothic New"

    /**
     * Surface glyphs, centralised so users can swap any of the Japanese
     * characters for their own (bar.pill.glyphs.<key> — any short string,
     * kanji or not). Empty/missing override falls back to the stock glyph.
     */
    readonly property var glyphDefaults: ({
        clock: "時", media: "奏", mediaPaused: "休", link: "繋", notify: "報",
        clear: "払", dnd: "静", sysmon: "系", glance: "今", clipboard: "掃",
        recorder: "録", power: "電", battery: "蓄", calendar: "暦", mixer: "調",
        launcher: "探", clipboardSearch: "控", workspaces: "場", settings: "設"
    })
    function glyph(key) {
        const o = Config.options?.bar?.pill?.glyphs?.[key];
        return (o !== undefined && o !== null && String(o).length > 0)
            ? String(o) : (glyphDefaults[key] ?? "");
    }

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a plain
     * string from others (Spotify); calling join on the string throws and kills
     * the whole binding.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
