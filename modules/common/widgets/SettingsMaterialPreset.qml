pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

QtObject {
    id: root

    readonly property bool unified:
        (Config.options?.settingsUi?.overlayStyle ?? "rail") === "unified"

    // ── Page layout ──
    readonly property int pageSpacing: unified ? Math.round(12 * Appearance.fontSizeScale)
        : Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.tileGap
        : Appearance.editorialEverywhere ? 14 * Appearance.editorial.spacing : 12) * Appearance.fontSizeScale)

    // ── Card (SettingsCardSection) ──
    readonly property int cardRadius: unified ? Math.round(12 * Appearance.fontSizeScale)
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius + 1
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.editorialEverywhere ? Appearance.editorial.radius : Appearance.rounding.normal
    readonly property int cardPadding: unified ? Math.round(14 * Appearance.fontSizeScale)
        : Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.tilePadding
        : Appearance.editorialEverywhere ? 16 * Appearance.editorial.spacing : 14) * Appearance.fontSizeScale)

    // ── Card header ──
    readonly property int headerRadius: unified ? Math.round(8 * Appearance.fontSizeScale)
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.editorialEverywhere ? Math.max(4, Math.round(Appearance.editorial.radius * 0.7)) : Appearance.rounding.small
    readonly property int headerPaddingX: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal
        : Appearance.editorialEverywhere ? 14 * Appearance.editorial.spacing : 12) * Appearance.fontSizeScale)
    readonly property int headerPaddingY: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingVertical
        : Appearance.editorialEverywhere ? 8 * Appearance.editorial.spacing : 7) * Appearance.fontSizeScale)

    // ── Group (SettingsGroup) ──
    readonly property int groupRadius: unified ? Math.round(8 * Appearance.fontSizeScale)
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
        : Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.editorialEverywhere ? Math.max(4, Math.round(Appearance.editorial.radius * 0.7)) : Appearance.rounding.small
    readonly property int groupPadding: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.tilePadding
        : Appearance.editorialEverywhere ? 14 * Appearance.editorial.spacing : 12) * Appearance.fontSizeScale)
    readonly property int groupSpacing: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.tileGap
        : Appearance.editorialEverywhere ? 8 * Appearance.editorial.spacing : 7) * Appearance.fontSizeScale)

    // ── Colors ──
    // In angel/aurora, cards are more transparent to let the content area's
    // GlassBackground blur show through (like Overlay widgets do).
    readonly property color cardColor: unified ? "transparent"
        : Appearance.angelEverywhere
        ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.angel.cardTransparentize * 0.7)
        // bg3 (not tile): the content field sits at bg2 now, so cards must lift a
        // clear step above it instead of matching it — depth by layer, not stroke.
        // ZZZ: transparent so the card complements the window/console ground
        // (dark or light) instead of stacking another dark plate. Definition comes
        // from the diagonal pattern + accent bar, not a filled surface + line.
        : Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlate
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(1)
        : Appearance.zzzEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, 0.85)
        : Appearance.colors.colLayer1
    readonly property color cardBorderColor: unified ? "transparent"
        : Appearance.angelEverywhere
        ? Appearance.angel.colCardBorder
        : Appearance.regaliaEverywhere ? "transparent"
        : Appearance.editorialEverywhere ? Appearance.editorial.rule
        : Appearance.zzzEverywhere ? Appearance.zzz.hairline
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border

    readonly property color groupColor: unified ? Appearance.colors.colLayer1
        : Appearance.angelEverywhere
        ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, Appearance.angel.popupTransparentize * 0.6)
        : Appearance.regaliaEverywhere ? "transparent"
        : Appearance.editorialEverywhere ? Appearance.editorial.layer(2)
        : Appearance.zzzEverywhere ? "transparent"
        : Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colLayer2, 0.45)
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, 0.88)
        : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.4)
    readonly property color groupBorderColor: unified ? Appearance.colors.colLayer0Border
        : Appearance.angelEverywhere
        ? Appearance.angel.colBorderSubtle
        : Appearance.regaliaEverywhere ? "transparent"
        : Appearance.editorialEverywhere ? Appearance.editorial.rule
        : Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border

    // ── Header hover ──
    readonly property color headerHoverColor: unified ? Appearance.colors.colLayer1Hover
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardHover
        : Appearance.regaliaEverywhere ? Appearance.regalia.surfacePlateHover
        : Appearance.editorialEverywhere ? Appearance.editorial.field
        : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer1Hover

    // ── Accent bar (left edge on expanded section) ──
    readonly property color accentColor: unified ? Appearance.colors.colPrimary
        : Appearance.angelEverywhere
        ? Appearance.angel.colPrimary
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.editorialEverywhere ? Appearance.editorial.accent
        : Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary

    // ── Section title colors ──
    readonly property color titleExpandedColor: unified ? Appearance.colors.colOnSurface
        : Appearance.angelEverywhere
        ? Appearance.angel.colText
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.editorialEverywhere ? Appearance.editorial.ink
        : Appearance.zzzEverywhere ? Appearance.zzz.onColor
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnSecondaryContainer
    readonly property color titleCollapsedColor: unified ? Appearance.colors.colOnSurface
        : Appearance.angelEverywhere
        ? Appearance.angel.colText
        : Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.editorialEverywhere ? Appearance.editorial.ink
        : Appearance.zzzEverywhere ? Appearance.colors.colOnLayer1
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnSurface

    // ── Icon colors ──
    // ZZZ: the card header icon rides a ZzzGlyphBadge plate (sticker when
    // expanded, secondary when collapsed); the INK on that plate must be the
    // corresponding on-plate ink, not a raw accent (which can compute near-
    // black on a low-chroma wallpaper and render as a black glyph).
    readonly property color iconExpandedColor: unified ? Appearance.colors.colPrimary
        : Appearance.angelEverywhere
        ? Appearance.angel.colPrimary
        : Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.editorialEverywhere ? Appearance.editorial.accent
        : Appearance.zzzEverywhere ? Appearance.zzz.onSticker
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary
    readonly property color iconCollapsedColor: unified ? Appearance.colors.colOnSurfaceVariant
        : Appearance.angelEverywhere
        ? Appearance.angel.colTextMuted
        : Appearance.regaliaEverywhere ? Appearance.regalia.hardwareSecondary
        : Appearance.editorialEverywhere ? Appearance.editorial.muted
        : Appearance.zzzEverywhere ? Appearance.zzz.onSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant

    // ── Navigation rail ──
    readonly property int navWidth: unified ? 200 : 180
    readonly property int navItemHeight: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.controlHeight
        : Appearance.editorialEverywhere ? 36 * Appearance.editorial.spacing : 34) * Appearance.fontSizeScale)
    readonly property int navCategorySpacing: Math.round((Appearance.regaliaEverywhere ? Appearance.regalia.tileGap + Appearance.regalia.controlGap
        : Appearance.editorialEverywhere ? 12 * Appearance.editorial.spacing : 10) * Appearance.fontSizeScale)
    readonly property int navItemSpacing: Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 2
}
