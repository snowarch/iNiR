pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Navigation item for Windows 11 style settings sidebar
Button {
    id: root
    
    property string navIcon: ""
    property bool selected: false
    property bool expanded: true
    
    implicitHeight: Looks.dp(44)
    implicitWidth: expanded ? Looks.dp(220) : Looks.dp(48)
    
    background: Rectangle {
        radius: Looks.settings.radiusLarge
        color: {
            if (root.selected)
                return Looks.colors.selection
            if (root.down)
                return Looks.settings.tilePressed
            if (root.hovered)
                return Looks.settings.tileHover
            return "transparent"
        }
        scale: root.down ? 0.96 : 1.0

        // Selection indicator - Win11 pill style
        Rectangle {
            visible: root.selected
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: Looks.dp(3.5)
            height: root.down ? Looks.dp(8) : Looks.dp(20)
            radius: Looks.dp(2)
            color: Looks.colors.accent

            Behavior on height {
                animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }
        }

        Behavior on color {
            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
        Behavior on scale {
            animation: NumberAnimation { duration: Looks.transition.enabled ? Looks.transition.duration.ultraFast : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
        }
    }
    
    contentItem: RowLayout {
        spacing: root.expanded ? Looks.dp(12) : 0
        
        Rectangle {
            implicitWidth: Looks.dp(28)
            implicitHeight: Looks.dp(28)
            radius: Looks.settings.radiusLarge
            Layout.leftMargin: root.expanded ? Looks.dp(12) : 0
            Layout.fillWidth: !root.expanded
            Layout.alignment: root.expanded ? Qt.AlignVCenter : Qt.AlignCenter

            color: root.selected
                ? Looks.colors.accent
                : (root.hovered ? Looks.colors.selection : Looks.settings.tile)

            Behavior on color {
                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
            }

            FluentIcon {
                anchors.centerIn: parent
                icon: root.navIcon
                implicitSize: Looks.dp(16)
                color: root.selected
                    ? Looks.colors.accentFg
                    : (root.hovered ? Looks.colors.accent : Looks.colors.fg)

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }
            }
        }

        WText {
            visible: root.expanded
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: Looks.font.pixelSize.large
            font.weight: root.selected ? Looks.font.weight.strong : Looks.font.weight.regular
            color: Looks.colors.fg
            opacity: root.selected ? 1 : (root.hovered ? 0.95 : 0.78)
            elide: Text.ElideRight

            Behavior on opacity {
                animation: NumberAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.OutQuad }
            }
        }
    }
    
    WToolTip {
        visible: !root.expanded && root.hovered
        text: root.text
    }
}
