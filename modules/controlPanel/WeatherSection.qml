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
    implicitHeight: visible ? weatherRow.implicitHeight + 16 : 0
    visible: Weather.enabled && Weather.data.temp && !Weather.data.temp.startsWith("--")
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

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

    RowLayout {
        id: weatherRow
        anchors.fill: parent
        anchors.margins: 8
        spacing: 10

        MaterialSymbol {
            text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: 32
            color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                 : root.inirEverywhere ? Appearance.inir.colPrimary
                 : root.auroraEverywhere ? Appearance.m3colors.m3primary
                 : Appearance.colors.colPrimary
        }

        StyledText {
            text: Weather.data.temp
            font.pixelSize: Appearance.font.pixelSize.huge
            font.weight: Font.Medium
            font.family: Appearance.font.family.numbers
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                 : root.inirEverywhere ? Appearance.inir.colText
                 : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                 : Appearance.colors.colOnLayer1
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: Weather.data.description || ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            StyledText {
                text: Weather.data.city
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                     : root.inirEverywhere ? Appearance.inir.colTextSecondary
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                     : Appearance.colors.colSubtext
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        RippleButton {
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                : Appearance.colors.colLayer2Hover
            onClicked: Weather.fetchWeather()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "refresh"
                iconSize: 16
                color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                     : root.inirEverywhere ? Appearance.inir.colTextSecondary
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurfaceVariant
                     : Appearance.colors.colSubtext
            }
            StyledToolTip { text: Translation.tr("Refresh") }
        }
    }
}
