pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: card.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
             : Appearance.colors.colLayer0
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : Appearance.auroraEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        implicitHeight: contentRow.implicitHeight + contentRow.anchors.topMargin + contentRow.anchors.bottomMargin

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 20
                topMargin: 9
                bottomMargin: 9
            }
            spacing: 12

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: KeyboardIndicators.popupMaterialIcon
                    iconSize: Appearance.font.pixelSize.hugeass
                    fill: 1
                    color: KeyboardIndicators.popupActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: KeyboardIndicators.popupText
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : Appearance.inirEverywhere ? Appearance.inir.colText
                     : Appearance.colors.colOnLayer0
            }
        }
    }
}
