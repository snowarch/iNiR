import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: root
    property string irisSlot: ""
    property var targetScreen
    implicitWidth: compactRow.implicitWidth
    implicitHeight: Math.round(28 * IrisStyle.density)

    RowLayout {
        id: compactRow
        anchors.centerIn: parent
        spacing: IrisStyle.spaceSmall

        IrisMark { implicitSize: Math.round(14 * IrisStyle.density) }
        IrisText {
            text: DateTime.timeDisplay
            role: IrisText.Meta
            font.family: IrisStyle.fontNumbers
            color: IrisStyle.text
        }
    }
}
