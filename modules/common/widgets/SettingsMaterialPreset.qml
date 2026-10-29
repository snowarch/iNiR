pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

// Material Settings' design: Android 16 Settings (M3 Expressive) made ours. A page is sections; a section is a
// sub-header in the accent over a segmented list where every setting is its own tile, 2 px apart, and only a run's
// outer corners round. Each Global Style keeps its surfaces and radii through these tokens.
QtObject {
    id: root

    readonly property bool dark: Appearance.m3colors.darkmode
    // aurora and angel draw the window on the blurred wallpaper: tiles are tinted glass, not paint
    readonly property bool glass: Appearance.auroraEverywhere && !Appearance.inirEverywhere

    // ── Page ──
    readonly property int pageSpacing: Math.round(28 * Appearance.fontSizeScale)
    // past this a row is read with the head, not the eyes: label and control drift too far apart
    readonly property int pageMaxWidth: Math.round(860 * Appearance.fontSizeScale)

    // ── Window ──
    readonly property color windowColor: Appearance.regaliaEverywhere ? Appearance.regalia.bg0
        : Appearance.editorialEverywhere ? Appearance.editorial.paper
        : Appearance.zzzEverywhere ? Appearance.zzz.bg0
        : Appearance.cookieEverywhere ? Appearance.cookie.bg0
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : root.glass ? ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerLow, root.dark ? 0.22 : 0.18)
        : root.dark ? Appearance.m3colors.m3surface : Appearance.m3colors.m3surfaceContainer
    readonly property int windowRadius: Appearance.regaliaEverywhere ? Appearance.regalia.panelRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.editorialEverywhere ? Appearance.rounding.verylarge
        : Math.round(28 * Appearance.rounding.scale)

    // ── Tiles ──
    readonly property int tileGap: 2
    readonly property int tileOuterRadius: Appearance.regaliaEverywhere ? Appearance.regalia.roundNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius + 1
        : Appearance.editorialEverywhere ? Appearance.editorial.radius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Math.round(20 * Appearance.rounding.scale)
    readonly property int tileInnerRadius: Math.min(root.tileOuterRadius, Math.max(2, Math.round(4 * Appearance.rounding.scale)))
    readonly property int tilePaddingX: Math.round(16 * Appearance.fontSizeScale)
    readonly property int tilePaddingY: Math.round(12 * Appearance.fontSizeScale)
    readonly property int rowMinHeight: Math.round(56 * Appearance.fontSizeScale)
    readonly property int iconSize: Math.round(24 * Appearance.fontSizeScale)
    readonly property color tileColor: Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlate
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(1)
        : Appearance.zzzEverywhere ? Appearance.zzz.bg1
        : Appearance.cookieEverywhere ? Appearance.cookie.bg1
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.angel.cardTransparentize * 0.7)
        : root.glass ? ColorUtils.transparentize(root.dark ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest,
            root.dark ? 0.45 : 0.3)
        : root.dark ? Appearance.m3colors.m3surfaceContainer : Appearance.m3colors.m3surfaceContainerLowest
    // M3 state layers: on-surface at 8 % hovered, 10 % pressed
    readonly property color tileHoverColor: Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlateHover
        : ColorUtils.mix(root.tileColor, Appearance.colors.colOnSurface, 0.92)
    readonly property color tilePressColor: Appearance.regaliaEverywhere ? Appearance.regalia.pressPlate
        : ColorUtils.mix(root.tileColor, Appearance.colors.colOnSurface, 0.9)
    // a control resting inside a tile (button group, stepper, field)
    readonly property color controlColor: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.zzzEverywhere ? Appearance.zzz.bg2
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : root.glass ? ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerHighest, root.dark ? 0.35 : 0.2)
        : Appearance.m3colors.m3surfaceContainerHighest
    readonly property color controlHoverColor: ColorUtils.mix(root.controlColor, Appearance.colors.colOnSurface, 0.92)

    // ── Text ──
    readonly property color subheaderColor: Appearance.editorialEverywhere ? Appearance.editorial.accent
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary
    readonly property color labelColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnSurface
    readonly property color supportingColor: Appearance.angelEverywhere ? Appearance.angel.colTextMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant
    readonly property int labelSize: Appearance.font.pixelSize.normal
    readonly property int supportingSize: Math.round(14 * Appearance.fontSizeScale)
    readonly property int subheaderSize: Math.round(14 * Appearance.fontSizeScale)

    // ── Older names the pages draw their own pieces with ──
    readonly property color accentColor: root.subheaderColor
    readonly property int cardRadius: root.tileOuterRadius
    readonly property int cardPadding: root.tilePaddingX
    readonly property color cardColor: root.tileColor
    readonly property color cardBorderColor: "transparent"
    readonly property int groupRadius: Math.round(12 * Appearance.rounding.scale)
    readonly property int groupPadding: root.tilePaddingY
    readonly property int groupSpacing: root.tileGap
    readonly property color groupColor: root.controlColor
    readonly property color groupBorderColor: "transparent"
    readonly property color headerHoverColor: root.tileHoverColor
    readonly property int headerPaddingX: root.tilePaddingX
    readonly property color iconExpandedColor: root.subheaderColor
    readonly property color iconCollapsedColor: root.supportingColor

    // Lays out every tile under a section by where it sits. Tiles in one group, or loose in the section, run on until
    // a caption or a group's edge; a run rounds only its first row's top and its last row's bottom. A subsection
    // holding no tiles is itself one tile, its label inside. Anything else loose in a run (a button group, a field,
    // a slider) is a "block": it gets a tile's padding here and the section paints its tile. Plain text is a
    // caption: lined up with the tiles' text, no tile. Returns the blocks with their corners for the section.
    function layoutTiles(container: Item): var {
        const blocks = []
        if (!container)
            return blocks
        const runs = []
        let run = []
        const flush = () => {
            if (run.length > 0)
                runs.push(run)
            run = []
        }
        const hasTiles = item => {
            const kids = item.children
            for (let i = 0; i < kids.length; ++i) {
                const c = kids[i]
                // a subsection is a tile itself or holds some
                if (c.visible && (c.settingsTileRole === "tile" || c.settingsTileRole === "subsection" || hasTiles(c)))
                    return true
            }
            return false
        }
        const isCaption = c => c.children.length === 0 && typeof c.text === "string" && c.font !== undefined
        // notes and previews that bring their own plate
        const hasOwnPlate = c => c.radius !== undefined && c.color !== undefined && c.color.a > 0.02
        // a caption right above a block names it: one tile holds both
        let caption = null
        const walk = item => {
            const kids = item.children
            for (let i = 0; i < kids.length; ++i) {
                const c = kids[i]
                if (!c.visible || c.height <= 0)
                    continue
                const role = c.settingsTileRole ?? ""
                const named = caption
                caption = null
                if (role === "group") {
                    flush()
                    walk(c)
                    flush()
                } else if (role === "caption") {
                    flush()
                } else if (role === "tile") {
                    run.push(c)
                } else if (role === "subsection") {
                    const own = !hasTiles(c)
                    c.tileActive = own
                    if (own)
                        run.push(c)
                    else
                        walk(c)
                } else if (hasTiles(c)) {
                    walk(c)
                } else if (isCaption(c)) {
                    flush()
                    c.Layout.leftMargin = root.tilePaddingX
                    c.Layout.rightMargin = root.tilePaddingX
                    caption = c
                } else if (hasOwnPlate(c)) {
                    flush()
                } else {
                    c.Layout.leftMargin = root.tilePaddingX
                    c.Layout.rightMargin = root.tilePaddingX
                    c.Layout.topMargin = named ? 6 : root.tilePaddingY
                    c.Layout.bottomMargin = root.tilePaddingY
                    if (named)
                        named.Layout.topMargin = root.tilePaddingY
                    const block = { item: c, caption: named, block: true, tileTop: true, tileBottom: true }
                    blocks.push(block)
                    run.push(block)
                }
            }
        }
        walk(container)
        flush()
        for (let r = 0; r < runs.length; ++r) {
            const tiles = runs[r]
            let top = Infinity
            let bottom = -Infinity
            const ys = []
            const hs = []
            for (let k = 0; k < tiles.length; ++k) {
                const t = tiles[k]
                const item = t.block ? t.item : t
                const pad = t.block ? root.tilePaddingY : 0
                const y = (t.caption ? t.caption : item).mapToItem(container, 0, 0).y - pad
                const end = item.mapToItem(container, 0, 0).y + item.height + pad
                ys.push(y)
                hs.push(end - y)
                top = Math.min(top, y)
                bottom = Math.max(bottom, end)
            }
            for (let k = 0; k < tiles.length; ++k) {
                tiles[k].tileTop = ys[k] < top + 1
                tiles[k].tileBottom = ys[k] + hs[k] > bottom - 1
            }
        }
        return blocks
    }
}
