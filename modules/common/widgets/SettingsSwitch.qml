import qs.modules.common
import qs.modules.common.widgets

ConfigSwitch {
    colBackground: SettingsMaterialPreset.groupColor
    colBackgroundHover: SettingsMaterialPreset.unified ? Appearance.colors.colLayer1Hover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colLayer2Hover
    colRipple: SettingsMaterialPreset.unified ? Appearance.colors.colLayer1Active
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
}
