import QtQuick
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

WButton {
    id: root

    colBackground: Looks.glassActive ? "transparent" : Looks.colors.bg2
    colBackgroundHover: Looks.colors.popupSurfaceHover
    colBackgroundActive: Looks.colors.popupSurfaceActive
    property color colBorder: Looks.glassActive ? Looks.colors.tooltipBorder : Looks.colors.bg2Border
    property color colBorderToggled: Looks.colors.accent
    border.color: checked ? colBorderToggled : colBorder
    border.width: root.pressed ? 2 : 1
}
