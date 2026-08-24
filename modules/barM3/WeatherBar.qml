pragma ComponentBehavior: Bound
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool hovered: false
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3

    implicitWidth: vertical ? 32 : (contentLoader.item?.implicitWidth ?? 0)
    implicitHeight: vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    readonly property bool clickForDetails: Config.options?.bar?.m3?.tooltips?.clickToShow ?? false
    hoverEnabled: true

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton && root.clickForDetails)
            weatherPopup.active = !weatherPopup.active
    }

    onPressed: mouse => {
        if (mouse.button === Qt.RightButton) {
            Weather.getData();
            Quickshell.execDetached(["notify-send",
                Translation.tr("Weather"),
                Translation.tr("Refreshing (manually triggered)"),
                "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 6

            MaterialSymbol {
                visible: !root.isMaterial
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: !root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: M3Palette.pillAccent("weatherBar", M3Palette.primary)
                text: Weather.data?.temp ?? "--°"
                Layout.alignment: Qt.AlignVCenter
                leftPadding: 5
            }

            Rectangle {
                visible: root.isMaterial
                width: 25
                height: 25
                radius: Appearance.rounding.full
                color: M3Palette.primary

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 0
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: Appearance.font.pixelSize.normal
                    color: M3Palette.primaryForeground
                }
            }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: root.isMaterial ? 2 : 0

            MaterialSymbol {
                visible: !root.isMaterial
                fill: 0
                text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                visible: !root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                visible: root.isMaterial
                font.pixelSize: Appearance.font.pixelSize.small
                color: M3Palette.pillAccent("weatherBar", M3Palette.primary)
                text: (Weather.data?.temp ?? "--°").replace(/[CF]$/, "")
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 3
            }

            Rectangle {
                visible: root.isMaterial
                width: 25
                height: 25
                radius: Appearance.rounding.full
                color: M3Palette.primary
                Layout.alignment: Qt.AlignHCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 0
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: Appearance.font.pixelSize.normal
                    color: M3Palette.primaryForeground
                }
            }
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
        hoverActivates: !root.clickForDetails
        closeOnOutsideClick: root.clickForDetails
        onRequestClose: active = false
    }
}
