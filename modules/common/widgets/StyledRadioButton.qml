import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Pipewire

RadioButton {
    id: root
    padding: 4
    implicitHeight: contentItem.implicitHeight + padding * 2
    property string description
    property color activeColor: Appearance.colors.colPrimary
    property color inactiveColor: Appearance.colors.colOnSurfaceVariant

    PointingHandInteraction {}

    indicator: Item{}
    
    contentItem: RowLayout {
        id: contentItem
        Layout.fillWidth: true
        spacing: 12
        Rectangle {
            id: radio
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            width: Appearance.regaliaEverywhere ? 24 : 20
            height: width
            radius: Appearance.regaliaEverywhere ? Appearance.regalia.roundVerySmall : Appearance?.rounding.full
            border.color: checked ? root.activeColor : root.inactiveColor
            border.width: Appearance.regaliaEverywhere ? 0 : 2
            color: "transparent"

            RegaliaControlFace {
                anchors.fill: parent
                visible: Appearance.regaliaEverywhere
                fillColor: root.checked ? Appearance.regalia.primaryPlate : Appearance.regalia.controlPlate
                radius: radio.radius
                hovered: root.hovered
                pressed: root.down
                selected: root.checked
                focused: root.visualFocus
            }

            // Checked indicator
            Rectangle {
                anchors.centerIn: parent
                width: Appearance.regaliaEverywhere ? 8 : (checked ? 10 : 4)
                height: width
                radius: Appearance.regaliaEverywhere ? 2 : Appearance?.rounding.full
                color: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary : Appearance?.colors.colPrimary
                opacity: checked ? 1 : 0

                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on width {
                    enabled: Appearance.animationsEnabled && !Appearance.regaliaEverywhere
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on height {
                    enabled: Appearance.animationsEnabled && !Appearance.regaliaEverywhere
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

            }

            // Hover
            Rectangle {
                anchors.centerIn: parent
                visible: !Appearance.regaliaEverywhere
                width: root.hovered ? 40 : 20
                height: root.hovered ? 40 : 20
                radius: Appearance?.rounding.full
                color: Appearance.colors.colOnSurface
                opacity: root.hovered ? 0.1 : 0

                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on width {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on height {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
            }
        }

        StyledText {
            text: root.description
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colOnSurface
        }
    }
}
