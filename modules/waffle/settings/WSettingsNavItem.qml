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
    
    implicitHeight: 40
    implicitWidth: expanded ? 220 : 48
    
    background: Rectangle {
        radius: Looks.radius.medium
        color: {
            if (root.selected) return Looks.colors.bg2
            if (root.down) return Looks.colors.bg2Active
            if (root.hovered) return Looks.colors.bg2Hover
            return "transparent"
        }
        
        // Selection indicator
        Rectangle {
            visible: root.selected
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: 16
            radius: 2
            color: Looks.colors.accent
        }
        
        Behavior on color {
            animation: Looks.transition.color.createObject(this)
        }
    }
    
    contentItem: RowLayout {
        spacing: 12
        
        Item {
            implicitWidth: 24
            implicitHeight: 24
            Layout.leftMargin: root.expanded ? 8 : 12
            
            FluentIcon {
                anchors.centerIn: parent
                icon: root.navIcon
                implicitSize: 20
                color: root.selected ? Looks.colors.accent : Looks.colors.fg
            }
        }
        
        WText {
            visible: root.expanded
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: Looks.font.pixelSize.normal
            font.weight: root.selected ? Looks.font.weight.regular : Looks.font.weight.thin
            color: Looks.colors.fg
            elide: Text.ElideRight
        }
    }
}
