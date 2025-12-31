import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Reusable card container for widgets
Rectangle {
    id: root
    
    property alias contentItem: contentLoader.sourceComponent
    property string title: ""
    property string icon: ""
    property bool showHeader: title.length > 0
    property real contentPadding: 12
    
    color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
         : Appearance.colors.colLayer1
    border.width: Appearance.inirEverywhere ? 1 : 0
    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    radius: Appearance.rounding.normal
    
    implicitHeight: mainLayout.implicitHeight + contentPadding * 2
    
    ColumnLayout {
        id: mainLayout
        anchors {
            fill: parent
            margins: root.contentPadding
        }
        spacing: 8
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            visible: root.showHeader
            spacing: 8
            
            MaterialSymbol {
                visible: root.icon.length > 0
                text: root.icon
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
        
        // Content
        Loader {
            id: contentLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
