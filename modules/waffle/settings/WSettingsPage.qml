pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Base page component for Windows 11 style settings
Flickable {
    id: root
    
    property string pageTitle: ""
    property string pageIcon: ""
    property string pageDescription: ""
    default property alias content: contentColumn.data
    
    // Settings search context
    property int settingsPageIndex: -1
    property string settingsPageName: pageTitle
    
    clip: true
    contentHeight: contentColumn.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds
    
    ScrollBar.vertical: WScrollBar {}
    
    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 24
        }
        spacing: 16
        
        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 8
            spacing: 4
            
            RowLayout {
                spacing: 12
                
                FluentIcon {
                    visible: root.pageIcon !== ""
                    icon: root.pageIcon
                    implicitSize: 28
                    color: Looks.colors.fg
                }
                
                WText {
                    text: root.pageTitle
                    font.pixelSize: Looks.font.pixelSize.larger + 4
                    font.weight: Looks.font.weight.strong
                }
            }
            
            WText {
                visible: root.pageDescription !== ""
                Layout.fillWidth: true
                text: root.pageDescription
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.subfg
                wrapMode: Text.WordWrap
            }
        }
    }
}
