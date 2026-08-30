pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root

    property color fillColor: Appearance.regalia.controlPlate
    property real radius: Appearance.regalia.controlRadius
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool focused: false

    readonly property bool _hasSurface: root.fillColor.a > 0.01
    readonly property color _fieldColor: root.pressed
        ? ColorUtils.mix(root.fillColor, Appearance.regalia.onColor, 0.84)
        : root.hovered ? ColorUtils.mix(root.fillColor, Appearance.regalia.onColor, 0.92)
        : root.fillColor

    Rectangle {
        anchors.fill: parent
        visible: root._hasSurface
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root.selected
                    ? ColorUtils.mix(Appearance.regalia.chassisLight, Appearance.regalia.hardwarePrimary, 0.86)
                    : Appearance.regalia.chassisLight
            }
            GradientStop { position: 0.46; color: Appearance.regalia.chassis1 }
            GradientStop { position: 1; color: Appearance.regalia.chassisShade }
        }
    }

    Rectangle {
        id: keyFace
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: Appearance.regalia.controlInset
        }
        visible: root._hasSurface || root.focused
        radius: Math.max(0, root.radius - Appearance.regalia.controlInset)
        color: root._hasSurface ? root._fieldColor : "transparent"
        border.width: root.focused ? 1 : 0
        border.color: Appearance.regalia.focus
        gradient: Gradient {
            GradientStop {
                position: 0
                color: root._hasSurface
                    ? ColorUtils.mix(root._fieldColor, Appearance.regalia.onColor,
                        root.pressed ? 0.985 : 0.955)
                    : "transparent"
            }
            GradientStop { position: 0.5; color: root._hasSurface ? root._fieldColor : "transparent" }
            GradientStop {
                position: 1
                color: root._hasSurface
                    ? ColorUtils.mix(root._fieldColor, Appearance.m3colors.m3shadow,
                        root.pressed ? 0.88 : 0.935)
                    : "transparent"
            }
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.regalia.stateDuration; easing.type: Easing.OutCubic }
        }
    }

}
