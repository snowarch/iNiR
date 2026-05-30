pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

QtObject {
    id: root

    // ── Page layout ──
    readonly property int pageSpacing: Math.round(12 * Appearance.fontSizeScale)

    // ── Card (SettingsCardSection) ──
    readonly property int cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    readonly property int cardPadding: Math.round(14 * Appearance.fontSizeScale)

    // ── Card header ──
    readonly property int headerRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small
    readonly property int headerPaddingX: Math.round(12 * Appearance.fontSizeScale)
    readonly property int headerPaddingY: Math.round(7 * Appearance.fontSizeScale)

    // ── Group (SettingsGroup) ──
    readonly property int groupRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small
    readonly property int groupPadding: Math.round(12 * Appearance.fontSizeScale)
    readonly property int groupSpacing: Math.round(7 * Appearance.fontSizeScale)

    // ── Colors ──
    // In angel/aurora, cards are more transparent to let the content area's
    // GlassBackground blur show through (like Overlay widgets do).
    readonly property color cardColor: Appearance.angelEverywhere
        ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, Appearance.angel.cardTransparentize * 0.7)
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Base, 0.85)
        : Appearance.colors.colLayer1
    readonly property color cardBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border

    readonly property color groupColor: Appearance.angelEverywhere
        ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, Appearance.angel.popupTransparentize * 0.6)
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2Base, 0.80)
        : Appearance.colors.colLayer2
    readonly property color groupBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border

    // ── Header hover ──
    readonly property color headerHoverColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer1Hover

    // ── Accent bar (left edge on expanded section) ──
    readonly property color accentColor: Appearance.angelEverywhere
        ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.m3colors.m3primary

    // ── Section title colors ──
    readonly property color titleExpandedColor: Appearance.angelEverywhere
        ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnSecondaryContainer
    readonly property color titleCollapsedColor: Appearance.angelEverywhere
        ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant

    // ── Icon colors ──
    readonly property color iconExpandedColor: Appearance.angelEverywhere
        ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.m3colors.m3primary
    readonly property color iconCollapsedColor: Appearance.angelEverywhere
        ? Appearance.angel.colTextMuted
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant

    // ── Navigation rail ──
    readonly property int navWidth: 180
    readonly property int navItemHeight: Math.round(34 * Appearance.fontSizeScale)
    readonly property int navCategorySpacing: Math.round(10 * Appearance.fontSizeScale)
    readonly property int navItemSpacing: 2
}
