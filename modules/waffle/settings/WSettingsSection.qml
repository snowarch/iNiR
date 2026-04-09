pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.waffle.looks

// Section header for grouping settings — subtle chapter divider between card groups
Item {
    id: root

    property string title: ""
    property string description: ""

    Layout.fillWidth: true
    Layout.topMargin: 14
    Layout.bottomMargin: 4
    implicitHeight: sectionColumn.implicitHeight

    ColumnLayout {
        id: sectionColumn
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 4
        }
        spacing: 2

        WText {
            text: root.title
            font.pixelSize: Looks.font.pixelSize.normal
            font.weight: Looks.font.weight.strong
            color: Looks.colors.subfg
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
