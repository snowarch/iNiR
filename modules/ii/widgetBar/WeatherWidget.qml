import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root
    
    color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
         : Appearance.colors.colLayer1
    border.width: Appearance.inirEverywhere ? 1 : 0
    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    radius: Appearance.rounding.normal
    implicitHeight: mainColumn.implicitHeight + 24
    
    readonly property bool hasData: Weather.data.temp !== "--°C" && Weather.data.temp !== "--°F"
    
    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 12
        
        // Current weather
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            
            // Weather icon
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"
                    iconSize: 32
                    color: Appearance.colors.colOnPrimaryContainer
                }
            }
            
            // Temperature and location
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                
                StyledText {
                    text: root.hasData ? Weather.data.temp : "--"
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                
                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "location_on"
                        iconSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Weather.data.city
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                }
            }
        }
        
        // Feels like
        StyledText {
            visible: root.hasData
            text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        
        // Metrics grid
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            visible: root.hasData
            
            WeatherMetric { icon: "humidity_percentage"; label: Translation.tr("Humidity"); value: Weather.data.humidity }
            WeatherMetric { icon: "air"; label: Translation.tr("Wind"); value: Weather.data.wind }
            WeatherMetric { icon: "wb_sunny"; label: Translation.tr("UV"); value: Weather.data.uv }
            WeatherMetric { icon: "readiness_score"; label: Translation.tr("Pressure"); value: Weather.data.press }
        }
        
        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
            visible: Weather.forecast.length > 0
        }
        
        // Forecast
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: Weather.forecast.length > 0
            
            Repeater {
                model: Weather.forecast
                
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: forecastColumn.implicitHeight + 12
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer2
                    
                    ColumnLayout {
                        id: forecastColumn
                        anchors {
                            fill: parent
                            margins: 6
                        }
                        spacing: 4
                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                const d = new Date(modelData.date + "T12:00:00")
                                const days = [Translation.tr("Sun"), Translation.tr("Mon"), Translation.tr("Tue"),
                                             Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat")]
                                return days[d.getDay()]
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: Icons.getWeatherIcon(modelData.wCode, false)
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnLayer2
                        }
                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.tempMax
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer2
                        }
                        
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.tempMin
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                        
                        // Rain chance
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 2
                            visible: modelData.chanceOfRain > 20
                            
                            MaterialSymbol {
                                text: "water_drop"
                                iconSize: 10
                                color: Appearance.colors.colPrimary
                            }
                            StyledText {
                                text: modelData.chanceOfRain + "%"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colPrimary
                            }
                        }
                    }
                }
            }
        }
        
        // Sunrise/Sunset
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            visible: root.hasData
            
            RowLayout {
                spacing: 4
                MaterialSymbol {
                    text: "wb_twilight"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: Weather.data.sunrise
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
            
            Item { Layout.fillWidth: true }
            
            RowLayout {
                spacing: 4
                MaterialSymbol {
                    text: "bedtime"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    text: Weather.data.sunset
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
    
    // Weather metric component
    component WeatherMetric: RowLayout {
        property string icon
        property string label
        property string value
        
        Layout.fillWidth: true
        spacing: 6
        
        MaterialSymbol {
            text: icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            
            StyledText {
                text: value
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                text: label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }
    }
}
