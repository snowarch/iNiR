pragma ComponentBehavior: Bound

import qs.modules.common.widgets
import qs.modules.waffle.looks

ShellLayoutEditorWindow {
    family: "waffle"
    styleKey: "waffle"
    accentColor: Looks.colors.accent
    surfaceColor: Looks.colors.bg0
    elevatedSurfaceColor: Looks.colors.bg2
    textColor: Looks.colors.fg
    secondaryTextColor: Looks.colors.subfg
    borderColor: Looks.colors.bg2Border
    fontFamily: Looks.font.family.ui
    titlePixelSize: Looks.font.pixelSize.large
    bodyPixelSize: Looks.font.pixelSize.normal
    smallPixelSize: Looks.font.pixelSize.small
    panelRadius: Looks.radius.large
    controlRadius: Looks.radius.medium
    animationDuration: Looks.transition.enabled
        ? Looks.transition.duration.fast : 0
}
