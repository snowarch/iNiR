pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

QtObject {
    id: root

    // ── Page layout ──
    readonly property int pageSpacing: 14

    // ── Card (SettingsCardSection) ──
    readonly property int cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.rounding.normal
    readonly property int cardPadding: 16

    // ── Card header ──
    readonly property int headerRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.small
    readonly property int headerPaddingX: 12
    readonly property int headerPaddingY: 8

    // ── Group (SettingsGroup) ──
    readonly property int groupRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.rounding.small
    readonly property int groupPadding: 14
    readonly property int groupSpacing: 8

    // ── Colors ──
    readonly property color cardColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassCard : Appearance.colors.colLayer1
    readonly property color cardBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colBorder : Appearance.colors.colLayer0Border

    readonly property color groupColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassPopup : Appearance.colors.colLayer2
    readonly property color groupBorderColor: Appearance.angelEverywhere
        ? Appearance.angel.colBorderSubtle : Appearance.colors.colLayer0Border

    // ── Navigation rail ──
    readonly property int navWidth: 180
    readonly property int navItemHeight: 40
    readonly property int navCategorySpacing: 12
    readonly property int navItemSpacing: 2
}
