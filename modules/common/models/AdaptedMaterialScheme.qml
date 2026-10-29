import QtQuick
import qs.modules.common
import qs.modules.common.functions

/**
 * Material color scheme adapted to a given color. It's incomplete but enough for what we need...
 */
QtObject {
    id: root
    required property color color
    readonly property bool colorIsDark: color.hslLightness < 0.5

    // The colour lends its hue; each role keeps the tone (CIELAB L*) it has in the scheme, so the pairs keep their
    // contrast. Mixed in plain RGB, a dark wallpaper or cover pulled a light panel to mid grey under dark ink (Aurora
    // light, 10-29: the sidebar's clock at 1.6:1) and a bright one lifted a dark panel toward its text.
    function adapted(base: color, amount: real): color {
        const mixed = ColorUtils.mix(base, root.color, amount)
        return base.a < 0.01 ? mixed : ColorUtils.atTone(mixed, ColorUtils.toneOf(base))
    }

    property color colLayer0: root.adapted(Appearance.colors.colLayer0, (colorIsDark && Appearance.m3colors.darkmode) ? 0.6 : 0.5)
    property color colLayer1: root.adapted(Appearance.colors.colLayer1, 0.5)
    property color colOnLayer0: root.adapted(Appearance.colors.colOnLayer0, 0.5)
    property color colOnLayer1: root.adapted(Appearance.colors.colOnLayer1, 0.5)
    property color colSubtext: root.adapted(Appearance.colors.colOnLayer1, 0.5)
    property color colPrimary: root.adapted(ColorUtils.adaptToAccent(Appearance.colors.colPrimary, root.color), 0.5)
    property color colPrimaryHover: root.adapted(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryHover, root.color), 0.3)
    property color colPrimaryActive: root.adapted(ColorUtils.adaptToAccent(Appearance.colors.colPrimaryActive, root.color), 0.3)
    property color colSecondary: root.adapted(ColorUtils.adaptToAccent(Appearance.colors.colSecondary, root.color), 0.5)
    property color colSecondaryContainer: root.adapted(Appearance.colors.colSecondaryContainer, 0.15)
    property color colSecondaryContainerHover: root.adapted(Appearance.colors.colSecondaryContainerHover, 0.3)
    property color colSecondaryContainerActive: root.adapted(Appearance.colors.colSecondaryContainerActive, 0.5)
    property color colOnPrimary: root.adapted(ColorUtils.adaptToAccent(Appearance.colors.colOnPrimary, root.color), 0.5)
    property color colOnSecondaryContainer: root.adapted(Appearance.colors.colOnSecondaryContainer, 0.5)
}
