import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Section divider — thin rule + label for visual grouping
Item {
    id: root
    
    required property string text
    property int fontSize: Appearance.font.pixelSize.smallest
    property int fontWeight: Font.Medium
    
    Layout.fillWidth: true
    implicitHeight: dividerCol.implicitHeight

    ColumnLayout {
        id: dividerCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.sizes.spacingSmall / 2

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            height: 1
            color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                : Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                : Appearance.colors.colOutlineVariant
            opacity: 0.35
        }

        StyledText {
            id: labelText
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
}
