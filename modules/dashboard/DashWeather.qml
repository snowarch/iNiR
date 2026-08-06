import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Weather card: current conditions plus a short daily forecast.
 * Relies on the Weather service (enabled via bar.weather.enable).
 */
DashCard {
    id: root

    readonly property bool hasData: Weather.enabled && (Weather.data?.temp ?? "").length > 0 && !(Weather.data?.temp ?? "--").startsWith("--")
    readonly property var forecast: (Weather.data?.forecast ?? []).slice(0, 3)

    // Disabled / loading hint
    ColumnLayout {
        visible: !root.hasData
        Layout.fillWidth: true
        spacing: 6

        MascotImage {
            id: weatherMascot
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            surface: "dashboard"
            pose: "weather-umbrella"
        }

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            visible: !weatherMascot.active
            text: "partly_cloudy_day"
            shape: MaterialShape.Shape.Puffy
            padding: 10
            iconSize: 32
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Weather.enabled ? Translation.tr("Waiting for weather data…")
                                  : Translation.tr("Enable weather in Settings › Bar")
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colSubtext
            wrapMode: Text.WordWrap
        }
    }

    // Current conditions — vertical centered stack (same as welcome/github).
    ColumnLayout {
        visible: root.hasData
        Layout.fillWidth: true
        spacing: 2

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: 44
            color: root.colAccent
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: Weather.showVisibleCity
            text: Weather.visibleCity
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: root.colText
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Weather.data?.temp ?? "--°"
            font.pixelSize: Appearance.font.pixelSize.huge
            font.family: Appearance.font.family.numbers
            font.weight: root.zzzEverywhere ? Font.Black : Font.Medium
            font.italic: root.zzzEverywhere
            color: root.colText
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Weather.describeWeather(Weather.data?.wCode ?? "113")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colSubtext
            elide: Text.ElideRight
        }
    }

    // Daily forecast — a compact 3-day group. No fillWidth: like the rest of the
    // card, we let DashCard's auto-center place this row (AlignHCenter). fillWidth
    // made the row keep its full width while the days bunched at the left edge.
    RowLayout {
        visible: root.hasData && root.forecast.length > 0
        // Explicit, not relying on DashCard's one-shot auto-center: this row
        // starts invisible (no data yet) so the auto-center loop skips it.
        Layout.alignment: Qt.AlignHCenter
        spacing: 18

        Repeater {
            model: root.forecast
            delegate: ColumnLayout {
                required property var modelData
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: modelData?.dayName ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                    color: root.colText
                }
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: Icons.getWeatherIcon(modelData?.code, false) ?? "cloud"
                    iconSize: Appearance.font.pixelSize.huge
                    color: root.colAccent
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `${modelData?.lo ?? "--"} / ${modelData?.hi ?? "--"}`
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colSubtext
                }
            }
        }
    }
}
