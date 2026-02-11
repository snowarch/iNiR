pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.waffle.looks

// Text field setting row - Windows 11 style
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string description: ""
    property string placeholderText: ""
    property string text: ""

    signal textEdited(string newText)

    Layout.fillWidth: true
    Layout.leftMargin: 16
    Layout.rightMargin: 16
    implicitHeight: contentColumn.implicitHeight + 16

    ColumnLayout {
        id: contentColumn
        anchors {
            fill: parent
            leftMargin: 12
            rightMargin: 12
            topMargin: 8
            bottomMargin: 8
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            FluentIcon {
                visible: root.icon !== ""
                icon: root.icon
                implicitSize: 16
                color: Looks.colors.subfg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                WText {
                    Layout.fillWidth: true
                    text: root.label
                    font.pixelSize: Looks.font.pixelSize.normal
                    elide: Text.ElideRight
                }

                WText {
                    visible: root.description !== ""
                    Layout.fillWidth: true
                    text: root.description
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Looks.radius.small
            color: Looks.colors.inputBg
            border.width: textField.activeFocus ? 2 : 1
            border.color: textField.activeFocus ? Looks.colors.accent : Looks.colors.bg1Border

            TextInput {
                id: textField
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                verticalAlignment: TextInput.AlignVCenter
                font.family: Looks.font.family.ui
                font.pixelSize: Looks.font.pixelSize.normal
                color: Looks.colors.fg
                selectByMouse: true
                clip: true
                text: root.text

                onTextEdited: root.textEdited(text)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: root.placeholderText
                    color: Looks.colors.subfg
                    font: textField.font
                    visible: !textField.text && !textField.activeFocus
                }
            }
        }
    }
}
