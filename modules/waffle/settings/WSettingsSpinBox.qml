pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// SpinBox setting row - Windows 11 style
WSettingsRow {
    id: root
    
    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property string suffix: ""
    
    control: Component {
        RowLayout {
            spacing: Looks.dp(2)
            
            WBorderlessButton {
                id: decrementBtn
                implicitWidth: Looks.dp(32)
                implicitHeight: Looks.dp(32)
                enabled: root.value > root.from
                radius: Looks.settings.radiusMedium
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "subtract"
                    implicitSize: Looks.dp(13)
                    color: {
                        if (!decrementBtn.enabled) return Looks.colors.subfg
                        if (decrementBtn.hovered) return Looks.colors.accent
                        return Looks.colors.fg
                    }
                    opacity: decrementBtn.enabled ? 1 : 0.35
                    
                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
                
                onClicked: root.value = Math.max(root.from, root.value - root.stepSize)
            }
            
            Rectangle {
                implicitWidth: Math.max(Looks.dp(58), valueText.implicitWidth + Looks.dp(20))
                implicitHeight: Looks.dp(32)
                radius: Looks.settings.radiusLarge
                color: Looks.colors.inputBg
                border.width: 1
                border.color: Looks.settings.strokeStrong
                
                WText {
                    id: valueText
                    anchors.centerIn: parent
                    text: root.value + root.suffix
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.family: Looks.font.family.ui
                    font.weight: Looks.font.weight.strong
                }
            }
            
            WBorderlessButton {
                id: incrementBtn
                implicitWidth: Looks.dp(32)
                implicitHeight: Looks.dp(32)
                enabled: root.value < root.to
                radius: Looks.settings.radiusMedium
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "add"
                    implicitSize: Looks.dp(13)
                    color: {
                        if (!incrementBtn.enabled) return Looks.colors.subfg
                        if (incrementBtn.hovered) return Looks.colors.accent
                        return Looks.colors.fg
                    }
                    opacity: incrementBtn.enabled ? 1 : 0.35
                    
                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }
                }
                
                onClicked: root.value = Math.min(root.to, root.value + root.stepSize)
            }
        }
    }
}
