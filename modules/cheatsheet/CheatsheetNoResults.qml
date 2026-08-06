import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * No results message following M3 typography and color patterns.
 */
Item {
    id: root
    signal clearSearchRequested()
    
    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight
    
    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        spacing: 10
        
        MascotImage {
            id: noResultsMascot
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            surface: "cheatsheet"
            pose: "fisheye-inspect"
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            visible: !noResultsMascot.active
            text: "search_off"
            iconSize: 40
            color: Appearance.colors.colSubtext
        }
        
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("No matches found")
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurface
        }
        
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Translation.tr("Try a different search term")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        
        // M3 action button (Section 4.3)
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            implicitWidth: clearContent.implicitWidth + 20
            implicitHeight: 32
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSurfaceContainer
            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
            colRipple: Appearance.colors.colSurfaceContainerHighest
            onClicked: root.clearSearchRequested()
            
            contentItem: RowLayout {
                id: clearContent
                anchors.centerIn: parent
                spacing: 4
                
                MaterialSymbol {
                    text: "backspace"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurface
                }
                
                StyledText {
                    text: Translation.tr("Clear search")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurface
                }
            }
        }
    }
}
