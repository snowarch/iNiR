pragma ComponentBehavior: Bound
import qs.modules.common.widgets
import qs.modules.waffle.looks

// Waffle skin for the shared MascotPoseGallery. The gallery itself is
// family-neutral and defaults to the ii/Material tokens; this wrapper dresses
// it in the settings kit's language (foreground-derived plates and hairlines,
// accent selection) so the mascot pages stop showing Material chrome inside a
// waffle card. Same recipe as WSettingsCard/WSettingsChoiceGroup — bg1/bg2
// cannot be used because they collapse under useMaterialColors.
MascotPoseGallery {
    surfaceRadius: Looks.radius.large
    cellRadius: Looks.radius.large

    surfaceColor: Qt.alpha(Looks.colors.fg, 0.05)
    surfaceHoverColor: Qt.alpha(Looks.colors.fg, 0.09)
    surfacePressedColor: Qt.alpha(Looks.colors.fg, 0.12)
    thumbBackdropColor: Qt.alpha(Looks.colors.fg, 0.08)

    selectedColor: Qt.alpha(Looks.colors.accent, 0.22)
    selectedBorderColor: Looks.colors.accent
    cellBorderColor: Qt.alpha(Looks.colors.fg, 0.10)

    textColor: Looks.colors.fg
    subTextColor: Looks.colors.subfg
    iconColor: Looks.colors.fg
    selectedTextColor: Looks.colors.fg
}
