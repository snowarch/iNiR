import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

BarButton {
    id: root

    leftInset: 8
    rightInset: 8
    implicitWidth: contentRow.implicitWidth + leftInset + rightInset + 8
    readonly property string locationText: Weather.visibleCity
    readonly property string secondaryText: locationText || root.weatherDescription

    onClicked: {
        Weather.getData()
        GlobalStates.waffleWidgetsOpen = !GlobalStates.waffleWidgetsOpen
    }

    contentItem: RowLayout {
        id: contentRow
        spacing: 8
        anchors.centerIn: parent

        MaterialSymbol {
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: 20
            color: Looks.colors.fg
            Layout.alignment: Qt.AlignVCenter
        }

        Column {
            width: 92
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            WText {
                width: parent.width
                text: Weather.data?.temp ?? "--°"
                font.pixelSize: Looks.font.pixelSize.normal
                font.weight: Font.Medium
                color: Looks.colors.fg
                elide: Text.ElideRight
            }

            WText {
                width: parent.width
                text: root.secondaryText
                font.pixelSize: Looks.font.pixelSize.tiny
                color: Looks.colors.subfg
                elide: Text.ElideRight
            }
        }
    }

    // Weather description based on code
    readonly property string weatherDescription: Weather.describeWeather(Weather.data?.wCode ?? "113")

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip
        text: Weather.showVisibleCity ? Weather.visibleCity : root.weatherDescription
    }
}
