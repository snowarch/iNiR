pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

// Material Settings' design: Android 16 Settings (M3 Expressive) made ours. A page is sections; a section is a
// sub-header in the accent over a segmented list where every setting is its own tile, 2 px apart, and only a run's
// outer corners round. Each Global Style keeps its surfaces and radii through these tokens.
// `classic` is v2.33's Settings, kept for who prefers it: every section one bordered card with its icon and title,
// the settings plain rows inside it. A family's Settings chrome sets it from its own option (Material:
// `material.settingsUi.design`); everything here reads the same tokens either way.
QtObject {
    id: root

    property bool classic: false

    readonly property bool dark: Appearance.m3colors.darkmode
    // aurora and angel draw the window on the blurred wallpaper: tiles are tinted glass, not paint
    readonly property bool glass: Appearance.auroraEverywhere && !Appearance.inirEverywhere

    // ── Page ──
    readonly property int pageSpacing: Math.round((root.classic ? 12 : 24) * Appearance.fontSizeScale)
    // past this a row is read with the head, not the eyes: label and control drift too far apart
    // classic fills its panel as v2.33 did, up to a wide window's worth
    readonly property int pageMaxWidth: Math.round((root.classic ? 1180 : 860) * Appearance.fontSizeScale)

    // ── Window ──
    readonly property color windowColor: root.classic && !root.glass && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
            && !Appearance.zzzEverywhere && !Appearance.cookieEverywhere && !Appearance.inirEverywhere ? Appearance.m3colors.m3background
        : Appearance.regaliaEverywhere ? Appearance.regalia.bg0
        : Appearance.editorialEverywhere ? Appearance.editorial.paper
        : Appearance.zzzEverywhere ? Appearance.zzz.bg0
        : Appearance.cookieEverywhere ? Appearance.cookie.bg0
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : root.glass ? ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerLow, root.dark ? 0.22 : 0.18)
        // the 2025 dark ladder starts at tone 4: a window there read as black, the tiles barely off it
        : root.dark ? Appearance.m3colors.m3surfaceContainerLow : Appearance.m3colors.m3surfaceContainer
    readonly property int windowRadius: Appearance.regaliaEverywhere ? Appearance.regalia.panelRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.editorialEverywhere ? Appearance.rounding.verylarge
        : root.classic ? Appearance.rounding.windowRounding
        : Math.round(28 * Appearance.rounding.scale)

    // ── Tiles ──
    // classic: what a page draws as a tile on its own (Home's cards, Hub's rows) is a plate apart from its neighbours
    readonly property int tileGap: root.classic ? 6 : 2
    readonly property int tileOuterRadius: root.classic ? root.cardRadius
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius + 1
        : Appearance.editorialEverywhere ? Appearance.editorial.radius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Math.round(20 * Appearance.rounding.scale)
    readonly property int tileInnerRadius: root.classic ? root.tileOuterRadius
        : Math.min(root.tileOuterRadius, Math.max(2, Math.round(4 * Appearance.rounding.scale)))
    readonly property int tilePaddingX: Math.round(16 * Appearance.fontSizeScale)
    // desktop density: Android's 56 px phone rows looked zoomed in on a 1320 px window
    readonly property int tilePaddingY: Math.round(10 * Appearance.fontSizeScale)
    readonly property int rowMinHeight: Math.round(48 * Appearance.fontSizeScale)
    readonly property int iconSize: Math.round(20 * Appearance.fontSizeScale)
    // regalia's window is chassis1: its tiles step up one chassis, their controls one more
    // classic: a page's own plate (Home, Hub) steps up from the page panel, which wears colLayer1 as v2.33's cards did
    readonly property color tileColor: root.classic ? root.classicPlateColor
        : Appearance.regaliaEverywhere ? Appearance.regalia.chassis2
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(1)
        : Appearance.zzzEverywhere ? Appearance.zzz.bg1
        : Appearance.cookieEverywhere ? Appearance.cookie.bg1
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.angel.cardTransparentize * 0.7)
        : root.glass ? ColorUtils.transparentize(root.dark ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest,
            root.dark ? 0.45 : 0.3)
        : root.dark ? Appearance.m3colors.m3surfaceContainerHigh : Appearance.m3colors.m3surfaceContainerLowest
    // M3 state layers: on-surface at 8 % hovered, 10 % pressed
    readonly property color tileHoverColor: ColorUtils.mix(root.tileColor, Appearance.colors.colOnSurface, 0.92)
    readonly property color classicPlateColor: Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, Appearance.angel.popupTransparentize * 0.6)
        : Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlate
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(2)
        : Appearance.zzzEverywhere ? Appearance.zzz.bg2
        : Appearance.cookieEverywhere ? Appearance.cookie.bg2
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, 0.6)
        : Appearance.colors.colLayer2
    readonly property color tilePressColor: Appearance.regaliaEverywhere ? Appearance.regalia.pressPlate
        : ColorUtils.mix(root.tileColor, Appearance.colors.colOnSurface, 0.9)
    // a control resting inside a tile (button group, stepper, field)
    readonly property color controlColor: Appearance.regaliaEverywhere ? Appearance.regalia.chassis4
        : Appearance.zzzEverywhere ? Appearance.zzz.bg2
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : root.glass ? ColorUtils.transparentize(Appearance.m3colors.m3surfaceContainerHighest, root.dark ? 0.35 : 0.2)
        : root.dark ? Appearance.m3colors.m3surfaceBright : Appearance.m3colors.m3surfaceContainerHighest
    readonly property color controlHoverColor: ColorUtils.mix(root.controlColor, Appearance.colors.colOnSurface, 0.92)

    // ── Rows: one setting (a switch, a stepper, a fold) ──
    // Expressive: each row is its own tile. Classic: rows lie plain on their section's card, a hover plate under them.
    readonly property color rowColor: root.classic ? "transparent" : root.tileColor
    readonly property color rowHoverColor: root.classic ? root.headerHoverColor : root.tileHoverColor
    readonly property color rowPressColor: root.classic ? ColorUtils.mix(root.headerHoverColor, Appearance.colors.colOnSurface, 0.92) : root.tilePressColor
    readonly property int rowOuterRadius: root.classic ? root.headerRadius : root.tileOuterRadius
    readonly property int rowInnerRadius: root.classic ? root.headerRadius : root.tileInnerRadius
    readonly property int rowGap: 2

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
    // angel's muted ink is see-through: on its glass it fell to 1.4:1; colSubtext is made readable on the glass floor
    readonly property color supportingColor: Appearance.angelEverywhere ? Appearance.colors.colSubtext
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant
    readonly property int labelSize: Appearance.font.pixelSize.small
    readonly property int supportingSize: Math.round(13 * Appearance.fontSizeScale)
    readonly property int subheaderSize: Math.round(13 * Appearance.fontSizeScale)

    // ── Cards (classic sections) and the older names the pages draw their own pieces with ──
    // classic values are v2.33's
    readonly property color accentColor: root.subheaderColor
    readonly property int cardRadius: !root.classic ? root.tileOuterRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius + 1
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.editorialEverywhere ? Appearance.editorial.radius : Appearance.rounding.normal
    readonly property int cardPadding: root.classic ? Math.round(8 * Appearance.fontSizeScale) : root.tilePaddingX
    readonly property color cardColor: !root.classic ? root.tileColor
        : Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.angel.cardTransparentize * 0.7)
        : Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlate
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(1)
        : Appearance.zzzEverywhere ? Appearance.zzz.bg1
        : Appearance.cookieEverywhere ? Appearance.cookie.bg1
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, 0.85)
        : Appearance.colors.colLayer1
    readonly property color cardBorderColor: !root.classic ? "transparent"
        : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.regaliaEverywhere ? "transparent"
        : Appearance.editorialEverywhere ? Appearance.editorial.rule
        : Appearance.zzzEverywhere ? Appearance.zzz.hairline
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border
    // v2.33's card edge: a hairline on Material, Cards, Aurora and Inir; the other styles draw the card by colour alone
    readonly property int cardBorderWidth: !root.classic || Appearance.angelEverywhere || Appearance.regaliaEverywhere
        || Appearance.zzzEverywhere || Appearance.cookieEverywhere || Appearance.editorialEverywhere ? 0 : 1
    // v2.33's rule under a classic page header: outline-variant at half strength
    readonly property color ruleColor: ColorUtils.transparentize(Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : Appearance.m3colors.m3outlineVariant, 0.5)
    // a classic section's title: on-secondary-container beside its icon in the accent
    readonly property color cardTitleColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.editorialEverywhere ? Appearance.editorial.ink
        : Appearance.zzzEverywhere ? Appearance.zzz.onColor
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnSecondaryContainer
    readonly property int headerRadius: !root.classic ? root.tileOuterRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.editorialEverywhere ? Math.max(4, Math.round(Appearance.editorial.radius * 0.7)) : Appearance.rounding.small
    readonly property int groupRadius: Math.round(12 * Appearance.rounding.scale)
    readonly property int groupPadding: root.tilePaddingY
    readonly property int groupSpacing: root.tileGap
    readonly property color groupColor: root.controlColor
    readonly property color groupBorderColor: "transparent"
    readonly property color headerHoverColor: !root.classic ? ColorUtils.mix(root.tileColor, Appearance.colors.colOnSurface, 0.92)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlateHover
        : Appearance.editorialEverywhere ? Appearance.editorial.field
        : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer1Hover
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
