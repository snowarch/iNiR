import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    
    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 8

        // Header
        Row {
            id: header
            spacing: 8

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: LenovoService.isActive ? "shield_with_heart" : "shield"
                iconSize: Appearance.font.pixelSize.large
                color: LenovoService.isActive 
                    ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                    : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Conservation Mode")
                font {
                    weight: Font.Medium
                    pixelSize: Appearance.font.pixelSize.normal
                }
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        // Status description
        StyledText {
            Layout.fillWidth: true
            text: !LenovoService.functional
                ? Translation.tr("Control node not found. Ensure the 'ideapad_laptop' kernel module is loaded.")
                : (LenovoService.isActive 
                    ? Translation.tr("Battery protection is active.\nCharging is limited to extend lifespan.") 
                    : Translation.tr("Standard charging mode.\nBattery will charge to 100%."))
            color: !LenovoService.functional ? Appearance.colors.colError : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
            Layout.maximumWidth: 200
        }
        
        // Hint
        StyledText {
            visible: LenovoService.functional
            text: Translation.tr("Click to toggle")
            font.italic: true
            font.pixelSize: 10
            color: Appearance.colors.colSubtext
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
