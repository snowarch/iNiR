pragma Singleton

import QtQuick
import qs.modules.common
import qs.modules.common.functions

QtObject {
    readonly property bool angelStyle: Appearance.angelEverywhere
    readonly property bool inirStyle: Appearance.inirEverywhere
    readonly property bool auroraStyle: Appearance.auroraEverywhere && !angelStyle
    readonly property bool neutralDialect: angelStyle || inirStyle || auroraStyle

    readonly property color surface: angelStyle ? Appearance.angel.colGlassPanel
        : inirStyle ? Appearance.inir.colLayer0
        : auroraStyle ? Appearance.aurora.colOverlay
        : Appearance.colors.colLayer0
    readonly property color surfaceContainerLow: angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer1
        : auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSurfaceContainerLow
    readonly property color surfaceContainer: angelStyle ? Appearance.angel.colGlassCard
        : inirStyle ? Appearance.inir.colLayer2
        : auroraStyle ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSurfaceContainer
    readonly property color surfaceContainerHigh: angelStyle ? Appearance.angel.colGlassElevated
        : inirStyle ? Appearance.inir.colLayer3
        : auroraStyle ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colSurfaceContainerHigh
    readonly property color surfaceContainerHighest: surfaceContainerHigh
    readonly property color _surfaceForegroundCandidate: angelStyle ? Appearance.angel.colText
        : inirStyle ? Appearance.inir.colText
        : Appearance.colors.colOnSurface
    readonly property color surfaceForeground: ColorUtils.ensureReadable(
        _surfaceForegroundCandidate, surface, 4.5)
    readonly property color _surfaceVariantForegroundCandidate: angelStyle ? Appearance.angel.colTextSecondary
        : inirStyle ? Appearance.inir.colTextSecondary
        : Appearance.colors.colOnSurfaceVariant
    readonly property color surfaceVariantForeground: ColorUtils.ensureReadable(
        _surfaceVariantForegroundCandidate, surfaceContainer, 3.0)
    readonly property color outlineVariant: angelStyle ? Appearance.angel.colCardBorder
        : inirStyle ? Appearance.inir.colBorder
        : auroraStyle ? Appearance.aurora.colTooltipBorder
        : Appearance.colors.colOutlineVariant
    readonly property color primary: Appearance.colors.colPrimary
    readonly property color primaryForeground: ColorUtils.ensureReadable(
        Appearance.colors.colOnPrimary, primary, 4.5)
    readonly property color primaryContainer: neutralDialect ? surfaceContainerLow : Appearance.colors.colPrimaryContainer
    readonly property color primaryContainerForeground: ColorUtils.ensureReadable(
        neutralDialect ? surfaceForeground : Appearance.colors.colOnPrimaryContainer,
        primaryContainer, 4.5)
    readonly property color secondaryContainer: neutralDialect ? surfaceContainer : Appearance.colors.colSecondaryContainer
    readonly property color secondaryContainerForeground: ColorUtils.ensureReadable(
        neutralDialect ? surfaceForeground : Appearance.colors.colOnSecondaryContainer,
        secondaryContainer, 4.5)
    readonly property color tertiary: Appearance.colors.colTertiary
    readonly property color tertiaryContainer: neutralDialect ? surfaceContainerHigh : Appearance.colors.colTertiaryContainer
    readonly property color tertiaryForeground: ColorUtils.ensureReadable(
        Appearance.colors.colOnTertiary, tertiary, 4.5)
    readonly property color tertiaryContainerForeground: ColorUtils.ensureReadable(
        neutralDialect ? surfaceForeground : Appearance.colors.colOnTertiaryContainer,
        tertiaryContainer, 4.5)
    readonly property color tooltip: surfaceContainerHighest
    readonly property color tooltipForeground: ColorUtils.ensureReadable(
        surfaceForeground, tooltip, 4.5)
    readonly property color error: Appearance.colors.colError
    readonly property color errorForeground: ColorUtils.ensureReadable(
        Appearance.colors.colOnError, error, 4.5)

    readonly property color primaryContainerHover: ColorUtils.mix(primaryContainer, primaryContainerForeground, 0.90)
    readonly property color primaryContainerActive: ColorUtils.mix(primaryContainer, primaryContainerForeground, 0.80)
    readonly property color secondaryContainerHover: ColorUtils.mix(secondaryContainer, secondaryContainerForeground, 0.90)
    readonly property color secondaryContainerActive: ColorUtils.mix(secondaryContainer, secondaryContainerForeground, 0.80)

    function pillContainer(name: string): color {
        if ((Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3)
            return primaryContainer

        if (neutralDialect) {
            switch (name) {
            case "media":
            case "sysTray":
            case "sidebarToggle":
                return secondaryContainer
            case "resources":
                return tertiaryContainer
            default:
                return primaryContainer
            }
        }

        switch (name) {
        case "media":
        case "sysTray":
        case "sidebarToggle":
            return secondaryContainer
        case "resources":
            return tertiaryContainer
        case "systemIcons":
            return primary
        default:
            return primaryContainer
        }
    }

    function pillInk(name: string): color {
        if ((Config.options?.bar?.m3?.cornerStyle ?? 0) !== 3)
            return primaryContainerForeground

        if (neutralDialect) {
            if (name === "resources")
                return ColorUtils.adaptAccent(tertiary, pillContainer(name), 4.0, 0.42, 0.18, 0.84)
            return ColorUtils.ensureReadable(surfaceForeground, pillContainer(name), 4.5)
        }

        switch (name) {
        case "media":
        case "sysTray":
        case "sidebarToggle":
            return ColorUtils.ensureReadable(secondaryContainerForeground, pillContainer(name), 4.5)
        case "resources":
            return ColorUtils.ensureReadable(tertiaryContainerForeground, pillContainer(name), 4.5)
        case "systemIcons":
            return ColorUtils.ensureReadable(primaryForeground, pillContainer(name), 4.5)
        default:
            return ColorUtils.ensureReadable(primaryContainerForeground, pillContainer(name), 4.5)
        }
    }

    function pillAccent(name: string, accent: color): color {
        return ColorUtils.adaptAccent(accent, pillContainer(name), 3.0, 0.38, 0.18, 0.84)
    }
}
