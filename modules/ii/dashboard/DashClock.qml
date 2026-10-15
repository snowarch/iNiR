import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Big clock card: each character of the time rendered in its own huge digit
 * block (Dank-style split-digit display), full date underneath. Splitting by
 * character rather than assuming "hh:mm" keeps this correct for any
 * Config.options.time.format the user has set.
 */
DashCard {
    id: root

    readonly property real digitSize: Appearance.font.pixelSize.title * (root.zzzEverywhere ? 2.3 : 2)
    readonly property var timeChars: DateTime.time.split("")

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        spacing: 2

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            Repeater {
                model: root.timeChars
                delegate: StyledText {
                    required property string modelData
                    readonly property bool isDigit: /[0-9]/.test(modelData)
                    text: modelData
                    width: isDigit ? Math.round(root.digitSize * 0.62) : implicitWidth
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: root.digitSize
                    font.family: Appearance.font.family.numbers
                    font.weight: root.zzzEverywhere ? Font.Black : Font.DemiBold
                    font.italic: root.zzzEverywhere
                    color: root.colAccent
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.zzzEverywhere ? DateTime.date.toUpperCase() : DateTime.date
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: root.zzzEverywhere ? Font.Bold : Font.Normal
            color: root.colSubtext
            elide: Text.ElideRight
        }
    }
}
