pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

// How desktop widgets read in a family: their colours, type and shapes. One object for every widget, asked about the
// widget it is handed. A family says what it does differently through its part `widgetLook`, a WidgetLook; these are the
// plain generated tones and shell fonts for a family that says nothing.
QtObject {
    id: base

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

    // The sheet's keys, rows and labels, and the arranging guides
    property real density: 1
    property real labelSize: Appearance.font.pixelSize.smaller
    property real metaSize: Appearance.font.pixelSize.smallest
    property real valueSize: Appearance.font.pixelSize.smaller
    property real sheetTitleSize: Appearance.font.pixelSize.normal
    property int metaCapitalization: Font.AllUppercase
    property real metaSpacing: 1
    property color controlInk: Appearance.colors.colOnLayer2
    property color valueInk: Appearance.colors.colOnLayer2
    property color quietInk: Appearance.colors.colSubtext
    property int feedbackDuration: Appearance.animation.elementMoveFast.duration
    property real rowRadius: Appearance.rounding.small
    property bool tintedKeys: false
    property real chipEdge: 0
    property color chipEdgeColor: "transparent"
    property color tagFill: Appearance.colors.colPrimaryContainer
    property color tagInk: Appearance.colors.colOnPrimaryContainer
    property real tagSize: Appearance.font.pixelSize.smaller
    property real guideRadius: Appearance.rounding.small
    property color guideFill: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.08)
    function rowFill(hovered: bool): color { return ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, hovered ? 0.09 : 0.045) }
    function markRadius(size: real): real { return Appearance.rounding.small }
    function chipRadius(height: real): real { return height / 2 }
    function chipInk(selected: bool): color { return selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 }
    function chipGlyphInk(selected: bool): color { return base.chipInk(selected) }
    // The chosen key is the accent, as in Settings' button groups: the secondary container sat a hair off the idle keys.
    function chipFill(selected: bool, hovered: bool): color {
        return selected ? (hovered ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimary)
            : ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, hovered ? 0.1 : 0.055)
    }

    // What single widgets ask of a look: room inside a clipped frame, depth under raised shapes, an edge on a shaped pill,
    // what a player's glass reads as over the wallpaper.
    property real clipInset: 0
    property bool glassPlates: false
    property bool softDepth: true
    property bool tileDepth: true
    property bool flatFaces: false
    property color tagHover: Appearance.colors.colSecondaryContainerHover
    property color onAccentContainer: Appearance.colors.colOnPrimaryContainer
    property bool ornaments: true
    property string serifFamily: "serif"
    property real cardInset: 20
    property Component tilePlate: null
    property color pillRing: "transparent"
    property real pillRingWidth: 0
    function emphasisWeight(weight: int): int { return weight }
    function labelTracking(pixelSize: real): real { return pixelSize * 0.08 }
    function glassOver(backdrop: color): color { return Appearance.colors.colLayer0 }

    // What resetting a widget also clears, and the verbs over a shared widget material, where the family has one.
    function resetValues(widget: var): var { return ({}) }
    // Who stands on a plate until they say otherwise: the manifest's `bare`, and what the family adds to it.
    function plateByDefault(widget: var): bool { return !widget.bare }
    function materialAction(action: string): string { return "This family has no shared widget material" }

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
