pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root
    Layout.fillWidth: true
    implicitHeight: visible ? contentLayout.implicitHeight + 16 : 0
    visible: Weather.enabled && Weather.data.temp && !Weather.data.temp.startsWith("--")
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool hideLocation: Config.options?.waffles?.widgetsPanel?.weatherHideLocation ?? false
    readonly property string weatherDescription: Weather.describeWeather(Weather.data?.wCode ?? "113")
    readonly property string locationText: Weather.visibleCity
    readonly property string secondaryText: locationText || root.weatherDescription

    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : inirEverywhere ? Appearance.inir.colLayer1
         : auroraEverywhere ? Appearance.aurora.colSubSurface
         : Appearance.colors.colLayer1
    border.width: Appearance.angelEverywhere ? 0 : (inirEverywhere ? 1 : 0)
    border.color: Appearance.angelEverywhere ? "transparent"
        : inirEverywhere ? Appearance.inir.colBorder : "transparent"

    AngelPartialBorder { targetRadius: parent.radius; coverage: 0.45 }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: root.compactMode ? 6 : 8
        spacing: root.compactMode ? 2 : 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                iconSize: root.compactMode ? 26 : 32
                color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                     : root.inirEverywhere ? Appearance.inir.colPrimary
                     : root.auroraEverywhere ? Appearance.m3colors.m3primary
                     : Appearance.colors.colPrimary
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: Weather.data?.temp ?? "--°"
                font.pixelSize: root.compactMode ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                font.family: Appearance.font.family.numbers
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    text: root.hideLocation ? "visibility_off" : "visibility"
                    iconSize: 14
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                         : root.inirEverywhere ? Appearance.inir.colTextSecondary
                         : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                         : Appearance.colors.colSubtext
                    opacity: root.hideLocation ? 1 : 0.7
                }

                StyledSwitch {
                    id: privacySwitch
                    checked: root.hideLocation
                    scale: 0.6
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: Config.setNestedValue("waffles.widgetsPanel.weatherHideLocation", checked)
                    StyledToolTip {
                        text: Translation.tr("Hide weather location")
                    }
                }
            }

            RippleButton {
                implicitWidth: root.compactMode ? 24 : 28
                implicitHeight: root.compactMode ? 24 : 28
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                    : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : root.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colLayer2Hover
                onClicked: Weather.forceRefresh()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: root.compactMode ? 14 : 16
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                         : root.inirEverywhere ? Appearance.inir.colTextSecondary
                         : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                         : Appearance.colors.colSubtext
                }
                StyledToolTip { text: Translation.tr("Refresh") }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: root.compactMode ? 34 : 42
            text: root.secondaryText
            font.pixelSize: root.hideLocation ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smallest
            color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                 : root.inirEverywhere ? Appearance.inir.colTextSecondary
                 : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                 : Appearance.colors.colSubtext
            elide: Text.ElideRight
        }
    }
}
