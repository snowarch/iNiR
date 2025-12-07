pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.waffle.looks

// Card component for grouping settings - Windows 11 style
Rectangle {
    id: root
    
    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: false
    default property alias content: contentColumn.data
    
    Layout.fillWidth: true
    implicitHeight: mainColumn.implicitHeight
    radius: Looks.radius.large
    color: Looks.colors.bgPanelFooter
    border.width: 1
    border.color: Looks.colors.bg2Border
    
    ColumnLayout {
        id: mainColumn
        anchors {
            left: parent.left
            right: parent.right
        }
        spacing: 0
        
        // Header
        Item {
            visible: root.title !== ""
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight + 20
            
            MouseArea {
                anchors.fill: parent
                enabled: root.collapsible
                cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (root.collapsible) root.expanded = !root.expanded
            }
            
            RowLayout {
                id: headerRow
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 16
                    rightMargin: 16
                }
                spacing: 12
                
                FluentIcon {
                    visible: root.icon !== ""
                    icon: root.icon
                    implicitSize: 20
                    color: Looks.colors.fg
                }
                
                WText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Looks.font.pixelSize.large
                    font.weight: Looks.font.weight.regular
                }
                
                FluentIcon {
                    visible: root.collapsible
                    icon: root.expanded ? "chevron-up" : "chevron-down"
                    implicitSize: 16
                    color: Looks.colors.subfg
                }
            }
        }
        
        // Separator
        Rectangle {
            visible: root.title !== "" && root.expanded && contentColumn.children.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            height: 1
            color: Looks.colors.bg2Border
        }
        
        // Content
        ColumnLayout {
            id: contentColumn
            visible: root.expanded
            Layout.fillWidth: true
            Layout.margins: 16
            Layout.topMargin: root.title !== "" ? 12 : 16
            spacing: 8
        }
    }
}
