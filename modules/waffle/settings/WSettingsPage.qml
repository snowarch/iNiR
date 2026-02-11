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
            topMargin: 32
            leftMargin: 32
            rightMargin: 32
            bottomMargin: 24
        }
        spacing: 12
        
        // Page header
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 6
            
            WText {
                text: root.pageTitle
                font.pixelSize: Looks.font.pixelSize.xlarger + 4
                font.weight: Looks.font.weight.strong
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
