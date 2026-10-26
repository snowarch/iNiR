import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.waffle.looks

// A card in Waffle's Widgets panel: Looks tokens and W* primitives, sizes through Looks.dp().
Item {
    id: root
    property string waffleSlot: ""
    implicitHeight: row.implicitHeight + Looks.dp(32)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Looks.dp(16)
        spacing: Looks.dp(12)
        FluentIcon { icon: "apps"; implicitSize: Looks.dp(24); color: Looks.colors.accent }
        WText {
            Layout.fillWidth: true
            text: DateTime.time
            font.pixelSize: Looks.font.pixelSize.xlarger
            font.weight: Font.DemiBold
        }
    }
}
