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
            spacing: 2
            
            WBorderlessButton {
                id: decrementBtn
                implicitWidth: 32
                implicitHeight: 32
                enabled: root.value > root.from
                radius: Looks.radius.medium
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "subtract"
                    implicitSize: 13
                    color: {
                        if (!decrementBtn.enabled) return Looks.colors.subfg
                        if (decrementBtn.hovered) return Looks.colors.accent
                        return Looks.colors.fg
                    }
                    opacity: decrementBtn.enabled ? 1 : 0.35
                    
                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 80 : 0 }
                    }
                }
                
                onClicked: root.value = Math.max(root.from, root.value - root.stepSize)
            }
            
            Rectangle {
                implicitWidth: Math.max(58, valueText.implicitWidth + 20)
                implicitHeight: 32
                radius: Looks.radius.medium
                color: Looks.colors.inputBg
                border.width: 1
                border.color: Looks.colors.bg2Border
                
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
                implicitWidth: 32
                implicitHeight: 32
                enabled: root.value < root.to
                radius: Looks.radius.medium
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "add"
                    implicitSize: 13
                    color: {
                        if (!incrementBtn.enabled) return Looks.colors.subfg
                        if (incrementBtn.hovered) return Looks.colors.accent
                        return Looks.colors.fg
                    }
                    opacity: incrementBtn.enabled ? 1 : 0.35
                    
                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 80 : 0 }
                    }
                }
                
                onClicked: root.value = Math.min(root.to, root.value + root.stepSize)
            }
        }
    }
}
