pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// How desktop widgets read in a family: their colours, type and shapes. One object for every widget, asked about the
// widget it is handed. A family says what it does differently through its part `widgetLook`, a WidgetLook; these are the
// plain generated tones and shell fonts for a family that says nothing.
QtObject {
    // Over the wallpaper
    property bool adaptsToWallpaper: true
    property bool schemeInk: false
    property bool legibleAlways: false
    property bool shadowsBare: false
    property bool unreadIsLight: !Appearance.m3colors.darkmode
    property color unreadInk: Appearance.colors.colOnLayer0
    property color restBackdrop: Appearance.colors.colLayer0
    property color inkLight: Appearance.m3colors.darkmode ? Appearance.colors.colOnLayer0
        : ColorUtils.mix(Appearance.m3colors.m3inverseOnSurface, Qt.rgba(1, 1, 1, 1), 0.3)
    property color inkDark: Appearance.m3colors.darkmode
        ? ColorUtils.mix(Appearance.m3colors.m3inverseOnSurface, Qt.rgba(0, 0, 0, 1), 0.55)
        : Appearance.colors.colOnLayer0

    // Type
    property bool editorial: false
    function bodyFamily(widget: var): string { return Appearance.font.family.main }
    function numbersFamily(widget: var): string { return Appearance.font.family.numbers }
    function titleFamily(widget: var): string { return Appearance.font.family.main }
    function titleWeight(widget: var): int { return Font.DemiBold }
    function titleTracking(widget: var): real { return 0 }
    function titleScale(widget: var): real { return 1 }
    function spacingScale(widget: var): real { return 1 }
    function labelWeight(widget: var): int { return Font.Medium }
    function metadataTracking(widget: var): real { return 0 }
    function capitalization(widget: var): int { return Font.AllUppercase }
    function caseOf(widget: var, text: string): string { return text.toUpperCase() }

    // Shape and plate
    function controlRadius(widget: var): real { return Appearance.rounding.normal }
    function cardRadius(widget: var): real { return Appearance.rounding.extralarge }
    function blurAvailable(widget: var): bool { return false }
    function plated(widget: var): bool { return widget.widgetHasSurface && (widget.backgroundOpacity > 0 || widget.effectiveBlur) }
    function readsRegion(widget: var): bool { return false }
    function plateColor(widget: var): color { return widget.widgetSemanticContainer(widget.widgetSurfaceRole) }

    // What a palette role resolves to: { color, onColor, container, onContainer }.
    function semanticSet(widget: var, role: string): var { return plainSet(widget, role) }
    function plainSet(widget: var, role: string): var {
        const c = Appearance.colors
        // Bare on a light region in a dark theme, an accent takes its container tone: the same
        // generated hue, deep enough to read on the wallpaper instead of the pastel meant for dark.
        const deep = widget.inkOnLight && !widget.widgetHasSurface && Appearance.m3colors.darkmode
        switch (role) {
        case "secondary":
            return { color: deep ? c.colSecondaryContainer : c.colSecondary, onColor: c.colOnSecondary,
                container: c.colSecondaryContainer, onContainer: c.colOnSecondaryContainer }
        case "tertiary":
            return { color: deep ? c.colTertiaryContainer : c.colTertiary, onColor: c.colOnTertiary,
                container: c.colTertiaryContainer, onContainer: c.colOnTertiaryContainer }
        case "warning":
            return { color: deep ? c.colWarningContainer : c.colWarning, onColor: c.colOnTertiary,
                container: c.colWarningContainer, onContainer: c.colOnWarningContainer }
        case "signal":
            return { color: deep ? c.colErrorContainer : c.colError, onColor: c.colOnError,
                container: c.colErrorContainer, onContainer: c.colOnErrorContainer }
        case "surface":
            return { color: c.colOnSurfaceVariant, onColor: c.colLayer2, container: c.colLayer1, onContainer: c.colOnLayer1 }
        default:
            return { color: deep ? c.colPrimaryContainer : c.colPrimary, onColor: c.colOnPrimary,
                container: c.colPrimaryContainer, onContainer: c.colOnPrimaryContainer }
        }
    }
}
