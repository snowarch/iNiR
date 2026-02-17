import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    property string displayText: ""
    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: languageRow.implicitWidth
        implicitHeight: languageText.implicitHeight
        RowLayout {
            id: languageRow
            anchors.centerIn: parent
            spacing: 0
            StyledText {
                id: languageText
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 5
                text: root.displayText
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
            }
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: Appearance.font.pixelSize.hugeass
                text: "arrow_drop_down"
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
            }
        }
    }
}
