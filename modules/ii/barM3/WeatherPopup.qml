import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    ColumnLayout {
        id: mainLayout
        implicitWidth: Math.max(370, Math.round(390 * Appearance.fontSizeScale))
        spacing: Appearance.sizes.spacingSmall

        Layout.topMargin: -8
        Layout.leftMargin: -8
        Layout.rightMargin: -8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(128, Math.round(132 * Appearance.fontSizeScale))

            topLeftRadius: Appearance.rounding.normal - 2
            topRightRadius: Appearance.rounding.normal - 2
            bottomLeftRadius: Appearance.rounding.normal
            bottomRightRadius: Appearance.rounding.normal

            gradient: Gradient {
                GradientStop { position: 0.0; color: Appearance.colors.colPrimaryContainer }
                GradientStop { position: 1.0; color: Appearance.colors.colSurfaceContainerLow }
            }

            Item {
                anchors.fill: parent
                anchors.margins: Math.max(16, Appearance.sizes.spacingLarge)

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: -6
                    spacing: -2

                    StyledText {
                        visible: Weather.showVisibleCity
                        text: Weather.visibleCity
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                    }

                    StyledText {
                        text: Weather.data?.description ?? "Cloudy"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -8
                    spacing: 4

                    StyledText {
                        text: Weather.data?.temp ?? "3"
                        font.pixelSize: 48
                        font.weight: Font.Light
                        color: Appearance.colors.colOnLayer0
                    }
                }

                MaterialShapeWrappedMaterialSymbol {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: -3
                    shape: MaterialShape.Shape.Sunny
                    text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
                    iconSize: 40
                    implicitSize: 64
                    color: Qt.alpha(Appearance.colors.colOnLayer0, 0.15)
                    colSymbol: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 6
                    anchors.bottomMargin: -1
                    spacing: -2

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignRight
                        MaterialSymbol {
                            text: "wb_twilight"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Weather.data?.sunrise ?? "07:34 AM"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Layout.alignment: Qt.AlignRight
                        MaterialSymbol {
                            text: "bedtime"
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: Weather.data?.sunset ?? "05:21 PM"
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer0
                            opacity: 0.8
                        }
                    }
                }
            }
        }

        GridLayout {
            id: gridLayout
            columns: 2
            rowSpacing: 6
            columnSpacing: 6
            uniformCellWidths: true

            Layout.leftMargin: 2
            Layout.rightMargin: 2
            Layout.bottomMargin: 2
            Layout.fillWidth: true

            WeatherCard {
                title: Translation.tr("Rain?")
                symbol: "rainy"
                value: Weather.data?.cr ?? "24%"
            }
            WeatherCard {
                title: Translation.tr("Wind")
                symbol: "air"
                value: `${Weather.data?.wind ?? "1.2 km/h"}`
            }
            WeatherCard {
                title: Translation.tr("Precipitation")
                symbol: "rainy_light"
                value: Weather.data?.precip ?? "10%"
            }
            WeatherCard {
                title: Translation.tr("Humidity")
                symbol: "humidity_low"
                value: Weather.data?.humidity ?? "65%"
            }
            WeatherCard {
                title: Translation.tr("Visibility")
                symbol: "visibility"
                value: Weather.data?.visib ?? "10 km"
            }
            WeatherCard {
                title: Translation.tr("Pressure")
                symbol: "readiness_score"
                value: Weather.data?.press ?? "720 hpa"
            }
        }
    }
}
