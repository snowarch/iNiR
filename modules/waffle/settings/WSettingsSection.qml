pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

// Section header for grouping settings — subtle chapter divider between card groups
// Supports an optional icon with accent pill, matching WSettingsCard header style
Item {
    id: root

    property string title: ""
    property string icon: ""
    property string description: ""

    Layout.fillWidth: true
    Layout.topMargin: Looks.dp(14)
    Layout.bottomMargin: Looks.dp(4)
    implicitHeight: sectionRow.implicitHeight

    RowLayout {
        id: sectionRow
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: Looks.settings.panelPadding
        }
        spacing: Looks.dp(8)

        Rectangle {
            visible: root.icon !== ""
            implicitWidth: Looks.dp(24)
            implicitHeight: Looks.dp(24)
            radius: Looks.settings.radiusSmall
            color: Qt.alpha(Looks.colors.accent, 0.12)
            Layout.alignment: Qt.AlignTop

            FluentIcon {
                anchors.centerIn: parent
                icon: root.icon
                implicitSize: Looks.dp(13)
                color: Looks.colors.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Looks.dp(2)

            WText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Looks.font.pixelSize.normal
                font.weight: Looks.font.weight.strong
                color: Looks.colors.fg
            }

            WText {
                visible: root.description !== ""
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: Looks.font.pixelSize.small
                color: Looks.colors.subfg
                wrapMode: Text.WordWrap
                opacity: 0.7
                lineHeight: 1.2
            }
        }
    }
}
