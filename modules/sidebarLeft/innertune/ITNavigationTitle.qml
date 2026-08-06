import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// Literal translation of NavigationTitle.kt — section header.
// Row(spacedBy 12, pad h12/v16): optional thumbnail, label (labelLarge) over
// title (titleLarge Bold primary), optional forward chevron when clickable.
Item {
    id: root
    property string title: ""
    property string label: ""
    property bool clickable: false
    implicitWidth: parent ? parent.width : 0
    implicitHeight: rowLayout.implicitHeight + 32   // v16 top + v16 bottom

    signal clicked()

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 16
        anchors.bottomMargin: 16
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                visible: root.label !== ""
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.family: Appearance.font.family.title
                font.pixelSize: Appearance.font.pixelSize.title
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
                maximumLineCount: 1
                elide: Text.ElideRight
            }
        }

        MaterialSymbol {
            visible: root.clickable
            text: "arrow_forward"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colPrimary
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
