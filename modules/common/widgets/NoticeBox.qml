import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property alias materialIcon: icon.text
    property alias text: noticeText.text
    default property alias contentData: buttonRow.data

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
         : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colSurfaceContainer
    implicitWidth: mainRowLayout.implicitWidth + mainRowLayout.anchors.margins * 2
    implicitHeight: mainRowLayout.implicitHeight + mainRowLayout.anchors.margins * 2

    RowLayout {
        id: mainRowLayout
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        MaterialSymbol {
            id: icon
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignTop
            text: "info"
            iconSize: Appearance.font.pixelSize.huge
            color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                 : Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            StyledText {
                id: noticeText
                Layout.fillWidth: true
                text: "Notice message"
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                wrapMode: Text.WordWrap
            }

            RowLayout {
                id: buttonRow
                visible: children.length > 0
                Layout.fillWidth: true 
            }
        }
    }
}
