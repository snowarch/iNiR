import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Clean section divider - just text with subtle styling, no lines
Item {
    id: root
    
    required property string text
    property int fontSize: Appearance.font.pixelSize.smallest
    property int fontWeight: Font.Medium
    
    Layout.fillWidth: true
    implicitHeight: labelText.implicitHeight + 8
    
    StyledText {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        font.letterSpacing: 0.5
        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
            : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
            : Appearance.colors.colSubtext
        opacity: 0.8
    }
}
