import QtQuick
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks

Button {
    id: root

    implicitHeight: 36

    property color colBackground: ColorUtils.transparentize(Looks.colors.bg1)
    property color colBackgroundHover: Looks.colors.interactiveSurfaceHover
    property color colBackgroundActive: Looks.colors.interactiveSurfaceActive
    property color color
    property color colForeground: Looks.colors.fg
    color: {
        if (!root.enabled) return colBackground;
        if (root.down) {
            return root.colBackgroundActive
        } else if ((root.hovered && !root.down) || root.checked) {
            return root.colBackgroundHover
        } else {
            return root.colBackground
        }
    }
    property alias radius: background.radius

    background: Rectangle {
        id: background
        radius: Looks.radius.medium
        color: root.color
        border.width: Looks.glassActive && ((root.hovered && !root.down) || root.checked) ? 1 : 0
        border.color: Looks.colors.tooltipBorder
        
        // Subtle scale on press for tactile feedback
        scale: root.down ? 0.97 : 1.0
        
        Behavior on color {
            ColorAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                easing.type: Easing.OutQuad
            }
        }
    }
}
