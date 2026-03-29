import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

WButton {
    id: root

    colBackground: Looks.glassActive ? "transparent" : Looks.colors.bg1
    colBackgroundHover: Looks.colors.interactiveSurfaceHover
    colBackgroundActive: Looks.colors.interactiveSurfaceActive
    property color colBackgroundBorder
    property color color
    property alias border: background.border
    property alias shinyColor: background.borderColor

    colBackgroundBorder: Looks.glassActive
        ? ((root.checked || root.hovered || root.down) ? Looks.colors.tooltipBorder : "transparent")
        : ColorUtils.transparentize(color, (root.checked || root.hovered) ? Looks.backgroundTransparency : 0)
    color: {
        if (root.down) {
            return root.colBackgroundActive
        } else if ((root.hovered && !root.down) || root.checked) {
            return root.colBackgroundHover
        } else {
            return root.colBackground
        }
    }

    background: AcrylicRectangle {
        id: background
        shiny: ((root.hovered && !root.down) || root.checked)
        color: root.color
        radius: Looks.radius.medium
        border.width: 1
        border.color: root.colBackgroundBorder
        
        // Windows 11 style press feedback
        scale: root.down ? 0.96 : 1.0
        opacity: root.down ? 0.85 : 1.0

        Behavior on border.color {
            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0
                easing.type: Easing.OutQuad
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0
                easing.type: Easing.OutQuad
            }
        }
    }
}
