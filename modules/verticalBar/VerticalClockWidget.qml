import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.bar as Bar

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitHeight: clockColumn.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    ColumnLayout {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 0

        Repeater {
            model: DateTime.timeDisplay.split(/[: ]/)
            delegate: StyledText {
                required property string modelData
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: modelData.match(/am|pm/i) ? 
                    Appearance.font.pixelSize.smaller // Smaller "am"/"pm" text
                    : Appearance.font.pixelSize.large
                font.weight: Appearance.editorialEverywhere ? Appearance.editorial.titleWeight : Font.Normal
                font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
                font.features: { "tnum": 1 }
                color: Appearance.editorialEverywhere ? Appearance.editorial.accent : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                text: modelData.padStart(2, "0")
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        Bar.ClockWidgetTooltip {
            hoverTarget: mouseArea
        }
    }
}
