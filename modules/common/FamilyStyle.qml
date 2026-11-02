pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common.functions
import qs.services

// The look shared surfaces wear: the active family's when it hands one over (its plugin.json part `style`, an object
// whose `style` holds these names), Material's from Appearance otherwise. Shared code reads these and never imports a
// family; a family that wants shared surfaces in its face implements them.
Singleton {
    id: root

    FamilyPartLoader { id: provider; part: "style" }
    readonly property QtObject p: provider.item?.style ?? null
    // Which desktop widgets the family's worn Design prints its own face for.
    readonly property var facePrints: provider.item?.prints ?? ({})
    // The glyph set the family draws every glyph from (a Material Symbols cut); empty keeps Appearance's.
    readonly property string glyphFont: String(root.p?.glyphFont ?? "")
    readonly property var _c: Appearance.colors
    readonly property real _scale: Appearance.fontSizeScale ?? 1

    readonly property bool light: root.p ? root.p.light : !Appearance.m3colors.darkmode
    readonly property bool glassy: root.p ? root.p.glassy : false
    readonly property bool motionEnabled: root.p ? root.p.motionEnabled : Appearance.animationsEnabled
    readonly property real density: root.p ? root.p.density : 1

    readonly property color accent: root.p ? root.p.accent : root._c.colPrimary
    readonly property color secondaryAccent: root.p ? root.p.secondaryAccent : root._c.colSecondary
    readonly property color wallpaperLight: root.p ? root.p.wallpaperLight : root._c.colPrimary
    readonly property color text: root.p ? root.p.text : root._c.colOnLayer0
    readonly property color textStrong: root.p ? root.p.textStrong : root._c.colOnLayer0
    readonly property color textSecondary: root.p ? root.p.textSecondary : root._c.colSubtext
    readonly property color textTertiary: root.p ? root.p.textTertiary : ColorUtils.applyAlpha(root._c.colSubtext, 0.7)
    readonly property color subtext: root.p ? root.p.subtext : root._c.colSubtext
    readonly property color surface: root.p ? root.p.surface : root._c.colLayer0
    readonly property color bodySurface: root.p ? root.p.bodySurface : root._c.colLayer0
    readonly property color surfaceHigh: root.p ? root.p.surfaceHigh : root._c.colLayer2
    readonly property color surfaceHighest: root.p ? root.p.surfaceHighest : root._c.colLayer3
    readonly property color raised: root.p ? root.p.raised : root._c.colLayer2
    readonly property color fill: root.p ? root.p.fill : root._c.colLayer1
    readonly property color fillQuiet: root.p ? root.p.fillQuiet : ColorUtils.applyAlpha(root._c.colOnLayer0, 0.06)
    readonly property color fillHover: root.p ? root.p.fillHover : root._c.colLayer1Hover
    readonly property color fillActive: root.p ? root.p.fillActive : root._c.colLayer1Active
    readonly property color border: root.p ? root.p.border : root._c.colOutlineVariant
    readonly property color hairlineStrong: root.p ? root.p.hairlineStrong : root._c.colOutline
    readonly property color danger: root.p ? root.p.danger : root._c.colError
    readonly property color success: root.p ? root.p.success : root._c.colSuccess
    readonly property color inkOnAccent: root.p ? root.p.inkOnAccent : root._c.colOnPrimary
    readonly property color onTint: root.p ? root.p.onTint : "#ffffff"
    readonly property color inkOnLight: root.p ? root.p.inkOnLight : "#1d1d1f"
    readonly property color inkOnDark: root.p ? root.p.inkOnDark : "#f5f5f7"
    readonly property color onMedia: root.p ? root.p.onMedia : "#ffffff"
    readonly property color onMediaSecondary: root.p ? root.p.onMediaSecondary : ColorUtils.applyAlpha(root.onMedia, 0.72)
    readonly property color onMediaFill: root.p ? root.p.onMediaFill : ColorUtils.applyAlpha(root.onMedia, 0.2)
    readonly property color highlightOnMedia: root.p ? root.p.highlightOnMedia : root._c.colTertiary
    readonly property color dangerOnMedia: root.p ? root.p.dangerOnMedia : root._c.colError
    readonly property color veilStrong: root.p ? root.p.veilStrong : ColorUtils.applyAlpha(root._c.colLayer0Base, 0.62)
    readonly property color scrim: root.p ? root.p.scrim : root._c.colScrim
    readonly property color shadow: root.p ? root.p.shadow : root._c.colShadow
    readonly property color plateShadow: root.p ? root.p.plateShadow : root._c.colShadow
    readonly property var widgetPaletteNames: root.p ? root.p.widgetPaletteNames : ["system"]
    readonly property string toastSkin: root.p ? root.p.toastSkin : ""

    readonly property string fontMain: root.p ? root.p.fontMain : Appearance.font.family.main
    readonly property string fontNumbers: root.p ? root.p.fontNumbers : Appearance.font.family.numbers
    readonly property string fontTitle: root.p ? root.p.fontTitle : Appearance.font.family.title
    readonly property real typeScale: root.p ? root.p.typeScale : root._scale
    readonly property int typeFootnote: root.p ? root.p.typeFootnote : Math.round(11 * root._scale)
    readonly property int typeMeta: root.p ? root.p.typeMeta : Math.round(12 * root._scale)
    readonly property int typeLabel: root.p ? root.p.typeLabel : Math.round(14 * root._scale)
    readonly property int typeTitle: root.p ? root.p.typeTitle : Math.round(18 * root._scale)

    readonly property int radiusChip: root.p ? root.p.radiusChip : Appearance.rounding.verysmall
    readonly property int radiusRow: root.p ? root.p.radiusRow : Appearance.rounding.small
    readonly property int radiusTile: root.p ? root.p.radiusTile : Appearance.rounding.normal
    readonly property int radiusCard: root.p ? root.p.radiusCard : Appearance.rounding.normal
    readonly property int radiusPlate: root.p ? root.p.radiusPlate : Appearance.rounding.large
    readonly property int radiusSheet: root.p ? root.p.radiusSheet : Appearance.rounding.verylarge
    readonly property int radiusPanel: root.p ? root.p.radiusPanel : Appearance.rounding.windowRounding
    readonly property int spaceSmall: root.p ? root.p.spaceSmall : 6
    readonly property real shapeScale: root.p ? root.p.shapeScale : 1

    readonly property int revealDuration: root.p ? root.p.revealDuration : root.duration(140)
    readonly property int feedbackDuration: root.p ? root.p.feedbackDuration : root.duration(100)
    readonly property int moveDuration: root.p ? root.p.moveDuration : root.duration(350)
    readonly property int morphDuration: root.p ? root.p.morphDuration : root.duration(350)
    readonly property int emergeDuration: root.p ? root.p.emergeDuration : root.duration(300)
    readonly property int recedeDuration: root.p ? root.p.recedeDuration : root.duration(200)
    readonly property var moveCurve: root.p ? root.p.moveCurve : Appearance.animationCurves.expressiveDefaultSpatial
    readonly property var morphCurve: root.p ? root.p.morphCurve : Appearance.animationCurves.expressiveDefaultSpatial
    readonly property var emergeCurve: root.p ? root.p.emergeCurve : Appearance.animationCurves.emphasizedLastHalf
    readonly property var recedeCurve: root.p ? root.p.recedeCurve : Appearance.animationCurves.emphasizedFirstHalf
    readonly property int feedbackEasing: root.p ? root.p.feedbackEasing : Easing.OutCubic
    readonly property string morphName: root.p ? root.p.morphName : ""

    // The room the family's own chrome takes: at one edge of its frame, and on a screen ({ left, top, right, bottom }).
    function frameInset(edge: string): real { return provider.item?.frameInset ? provider.item.frameInset(edge) : 0 }
    function insets(screen: var): var { return provider.item?.insets ? provider.item.insets(screen) : ({ left: 0, top: 0, right: 0, bottom: 0 }) }

    function duration(ms: int): int { return root.p ? root.p.duration(ms) : root.motionEnabled ? Appearance.calcEffectiveDuration(ms) : 0 }
    function pressScale(base: real): real { return root.p ? root.p.pressScale(base) : base }
    function weight(base: int): int { return root.p ? root.p.weight(base) : base }
    function concentric(outer: real, inset: real, floor: real): int { return root.p ? root.p.concentric(outer, inset, floor) : Math.max(Math.round(floor), Math.round(outer - inset)) }
    function concentricPad(outer: real, floor: real): int { return root.p ? root.p.concentricPad(outer, floor) : Math.max(Math.round(floor), Math.round(outer * 0.3 + 7)) }
    function iconRadius(size: real): int { return root.p ? root.p.iconRadius(size) : Math.round(size * 0.26) }
    function tintFill(tint: color): color { return root.p ? root.p.tintFill(tint) : ColorUtils.applyAlpha(tint, 0.13) }
    function tintFillHover(tint: color): color { return root.p ? root.p.tintFillHover(tint) : ColorUtils.applyAlpha(tint, 0.2) }
    function tintBorder(tint: color): color { return root.p ? root.p.tintBorder(tint) : ColorUtils.applyAlpha(tint, 0.7) }
    function containerOf(c: color): color { return root.p ? root.p.containerOf(c) : ColorUtils.mix(root._c.colLayer0, c, 0.75) }
    function onTintFor(tint: color): color {
        if (root.p) return root.p.onTintFor(tint)
        return ColorUtils.contrastRatio(root.onTint, tint) >= ColorUtils.contrastRatio(root.inkOnLight, tint) ? root.onTint : root.inkOnLight
    }
    function onContainerOf(c: color): color { return root.p ? root.p.onContainerOf(c) : root.onTintFor(root.containerOf(c)) }
    function identityOf(c: color): color { return root.p ? root.p.identityOf(c) : c }
    function deepAccent(seed, fallback): color {
        if (root.p) return root.p.deepAccent(seed, fallback)
        const c = Qt.color(seed)
        return c.valid ? c : (fallback ?? root.inkOnLight)
    }
    function markOn(seed: color, sample: var, darkInk: bool, contrast: real): color {
        return root.p ? root.p.markOn(seed, sample, darkInk, contrast) : sample ? Lume.mark(seed, sample.level, sample.spread, darkInk, contrast) : seed
    }
    function legibleVeil(material: string, level: real, spread: real, strength: real): real { return root.p ? root.p.legibleVeil(material, level, spread, strength) : 0 }
    function widgetPalette(name: string, vibrance: real): var { return root.p ? root.p.widgetPalette(name, vibrance) : [root._c.colPrimary, root._c.colSecondary, root._c.colTertiary] }
}
