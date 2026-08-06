pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

PanelSurface {
    id: root
    islandSkin: (Config.options?.controlPanel?.style ?? "panel") === "island"
    Layout.fillWidth: true
    implicitHeight: (Weather.enabled && Weather.data.temp && !Weather.data.temp.startsWith("--")) ? contentLayout.implicitHeight + 16 : 0
    visible: implicitHeight > 0

    Behavior on implicitHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool hideLocation: Config.options?.waffles?.widgetsPanel?.weatherHideLocation ?? false
    readonly property string weatherDescription: Weather.describeWeather(Weather.data?.wCode ?? "113")
    readonly property string locationText: Weather.visibleCity
    readonly property string secondaryText: locationText || root.weatherDescription

    elevation: 1
    radiusOverride: inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    AngelPartialBorder { targetRadius: root.radiusOverride; coverage: 0.45; visible: Appearance.angelEverywhere }

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
                     : root.auroraEverywhere ? Appearance.colors.colPrimary
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
                     : root.auroraEverywhere ? Appearance.colors.colOnSurface
                     : Appearance.colors.colOnLayer1
                Layout.alignment: Qt.AlignVCenter
            }

            Item {
                Layout.fillWidth: true
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
                onClicked: Config.setNestedValue("waffles.widgetsPanel.weatherHideLocation", !root.hideLocation)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.hideLocation ? "visibility_off" : "visibility"
                    iconSize: root.compactMode ? 14 : 16
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                         : root.inirEverywhere ? Appearance.inir.colTextSecondary
                         : root.auroraEverywhere ? Appearance.colors.colOnSurfaceVariant
                         : Appearance.colors.colSubtext
                    opacity: root.hideLocation ? 1 : 0.7
                }
                StyledToolTip { text: root.hideLocation ? Translation.tr("Show location") : Translation.tr("Hide location") }
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
                         : root.auroraEverywhere ? Appearance.colors.colOnSurfaceVariant
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
                 : root.auroraEverywhere ? Appearance.colors.colOnSurfaceVariant
                 : Appearance.colors.colSubtext
            elide: Text.ElideRight
        }
    }
}
