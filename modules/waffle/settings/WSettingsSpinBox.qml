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
            spacing: 8
            
            WBorderlessButton {
                implicitWidth: 32
                implicitHeight: 32
                enabled: root.value > root.from
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "subtract"
                    implicitSize: 14
                    color: parent.enabled ? Looks.colors.fg : Looks.colors.subfg
                }
                
                onClicked: root.value = Math.max(root.from, root.value - root.stepSize)
            }
            
            Rectangle {
                implicitWidth: 60
                implicitHeight: 32
                radius: Looks.radius.medium
                color: Looks.colors.inputBg
                border.width: 1
                border.color: Looks.colors.bg2Border
                
                WText {
                    anchors.centerIn: parent
                    text: root.value + root.suffix
                    font.pixelSize: Looks.font.pixelSize.normal
                }
            }
            
            WBorderlessButton {
                implicitWidth: 32
                implicitHeight: 32
                enabled: root.value < root.to
                
                contentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "add"
                    implicitSize: 14
                    color: parent.enabled ? Looks.colors.fg : Looks.colors.subfg
                }
                
                onClicked: root.value = Math.min(root.to, root.value + root.stepSize)
            }
        }
    }
}
