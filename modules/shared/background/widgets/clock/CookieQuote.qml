import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Qt5Compat.GraphicalEffects


Item {
    id: root

    readonly property string quoteText: Config.getNestedValue("background.widgets.clock.quote.text", "")

    implicitWidth: quoteBox.implicitWidth
    implicitHeight: quoteBox.implicitHeight

    anchors.bottom: parent.bottom
    anchors.bottomMargin: -24

    DropShadow {
        source: quoteBox 
        anchors.fill: quoteBox
        visible: Appearance.effectsEnabled
        horizontalOffset: 0
        verticalOffset: 2
        radius: Appearance.effectsEnabled ? Appearance.rounding.small : 0
        samples: radius * 2 + 1
        color: Appearance.colors.colShadow
        transparentBorder: true
    }
    
    Rectangle {
        id: quoteBox

        implicitWidth: quoteStyledText.width + 16 // for spacing on both sides
        implicitHeight: quoteStyledText.height + 8 
        radius: Appearance.rounding.small
        color: Appearance.colors.colSecondaryContainer

        Row {
            anchors.centerIn: parent
            spacing: 0
            StyledText {
                id: quoteStyledText
                horizontalAlignment: Text.AlignLeft
                text: root.quoteText
                color: Appearance.colors.colOnSecondaryContainer
                font {
                    family: Appearance.font.family.reading
                    pixelSize: Appearance.font.pixelSize.large
                    weight: Font.Normal
                }
            }
        }
    }
}