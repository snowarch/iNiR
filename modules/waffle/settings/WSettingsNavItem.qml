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
    
    implicitHeight: 36
    implicitWidth: expanded ? 220 : 48
    
    background: Rectangle {
        radius: Looks.radius.medium
        color: {
            if (root.selected) return Looks.colors.bg2Hover
            if (root.down) return Looks.colors.bg2Active
            if (root.hovered) return Looks.colors.bg2Hover
            return "transparent"
        }
        
        // Selection indicator - Win11 pill style
        Rectangle {
            visible: root.selected
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: root.down ? 8 : 16
            radius: 1.5
            color: Looks.colors.accent
            
            Behavior on height {
                animation: Looks.transition.press.createObject(this)
            }
        }
        
        Behavior on color {
            animation: Looks.transition.color.createObject(this)
        }
    }
    
    contentItem: RowLayout {
        spacing: 10
        
        Item {
            implicitWidth: 20
            implicitHeight: 20
            Layout.leftMargin: root.expanded ? 12 : 14
            
            FluentIcon {
                anchors.centerIn: parent
                icon: root.navIcon
                implicitSize: 16
                color: root.selected ? Looks.colors.accent : Looks.colors.subfg
                
                Behavior on color {
                    animation: Looks.transition.color.createObject(this)
                }
            }
        }
        
        WText {
            visible: root.expanded
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: Looks.font.pixelSize.normal
            font.weight: root.selected ? Looks.font.weight.regular : Looks.font.weight.thin
            color: root.selected ? Looks.colors.fg : Looks.colors.subfg
            elide: Text.ElideRight
            
            Behavior on color {
                animation: Looks.transition.color.createObject(this)
            }
        }
    }
}
