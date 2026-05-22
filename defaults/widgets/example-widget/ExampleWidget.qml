pragma ComponentBehavior: Bound
// Quick Glance — example widget showing how to use iNiR's services and components.
// Copy this to ~/.config/inir/widgets/example-widget/ to use it.
// Full SDK docs: defaults/widgets/WIDGET-SDK.md

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "custom.example-widget"
    defaultConfig: ({
        placementStrategy: "free",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showTime: true, showWeather: true, showBattery: true,
        showNetwork: true, showVolume: true,
        surfaceStyle: "pill", showLabels: false, padding: 10, spacing: 10, fontScale: 100,
        x: 300, y: 300
    })

    implicitWidth: contentRow.implicitWidth + pad * 2
    implicitHeight: contentRow.implicitHeight + pad * 2
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 120
    resizeMinHeight: 36

    readonly property string cfgSurfaceStyle: _readConfigKey("surfaceStyle") ?? "pill"
    readonly property bool cfgShowLabels: _readConfigKey("showLabels") ?? false
    readonly property int pad: Math.round(Number(_readConfigKey("padding") ?? 10) * scaleFactor)
    readonly property int itemSpacing: Math.round(Number(_readConfigKey("spacing") ?? 10) * scaleFactor)
    readonly property real textScale: Math.max(0.7, Math.min(1.6, Number(_readConfigKey("fontScale") ?? 100) / 100))
    readonly property real ico: Math.round(16 * scaleFactor)
    readonly property real fs: Math.round(Appearance.font.pixelSize.small * scaleFactor * textScale)

    // Read config values (null-safe, with fallbacks)
    readonly property bool cfgTime: _readConfigKey("showTime") ?? true
    readonly property bool cfgWeather: _readConfigKey("showWeather") ?? true
    readonly property bool cfgBattery: _readConfigKey("showBattery") ?? true
    readonly property bool cfgNetwork: _readConfigKey("showNetwork") ?? true
    readonly property bool cfgVolume: _readConfigKey("showVolume") ?? true

    // Edit mode quick controls — toggle each section
    editPopoverContent: Component {
        GridLayout {
            columns: 3
            columnSpacing: 4
            rowSpacing: 4
            Repeater {
                model: [
                    { label: "Time", icon: "schedule", key: "showTime", on: root.cfgTime },
                    { label: "Weather", icon: "wb_sunny", key: "showWeather", on: root.cfgWeather },
                    { label: "Battery", icon: "battery_full", key: "showBattery", on: root.cfgBattery },
                    { label: "Network", icon: "wifi", key: "showNetwork", on: root.cfgNetwork },
                    { label: "Volume", icon: "volume_up", key: "showVolume", on: root.cfgVolume }
                ]
                SelectionGroupButton {
                    required property var modelData
                    Layout.fillWidth: true
                    leftmost: true; rightmost: true
                    buttonIcon: modelData.icon
                    buttonText: modelData.label
                    toggled: modelData.on
                    onClicked: Config.setNestedValue(
                        "background.widgets.custom.example-widget." + modelData.key, !modelData.on)
                }
            }
        }
    }

    // Card background — uses inherited card control properties
    Rectangle {
        anchors.fill: parent
        radius: root.cfgSurfaceStyle === "pill" ? Appearance.rounding.full : (root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : Appearance.rounding.small)
        color: root.cfgSurfaceStyle === "minimal" || root.cfgSurfaceStyle === "outline" ? "transparent"
            : ColorUtils.applyAlpha(root.colText, root.cfgSurfaceStyle === "card" ? Math.max(root.backgroundOpacity, 0.10) : Math.max(root.backgroundOpacity, 0.06))
        border.width: root.cfgSurfaceStyle === "outline" ? Math.max(1, root.borderWidth) : 0
        border.color: ColorUtils.applyAlpha(root.colText, Math.max(root.borderOpacity, 0.16))
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.itemSpacing

        // Time — uses DateTime service
        Row {
            visible: root.cfgTime
            spacing: Math.round(4 * root.scaleFactor)
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol { text: "schedule"; iconSize: root.ico; color: root.colText; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                visible: root.cfgShowLabels
                text: "Time"
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor * root.textScale)
                color: ColorUtils.applyAlpha(root.colText, 0.55); anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: DateTime.time
                font { pixelSize: root.fs; family: Appearance.font.family.numbers }
                color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Weather — uses Weather service (only shows when data is available)
        Row {
            visible: root.cfgWeather && Weather.enabled && Weather.data.temp !== undefined
            spacing: Math.round(4 * root.scaleFactor)
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol {
                text: Weather.isNightNow() ? "nights_stay" : "wb_sunny"
                iconSize: root.ico; color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: root.cfgShowLabels
                text: "Weather"
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor * root.textScale)
                color: ColorUtils.applyAlpha(root.colText, 0.55); anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: Weather.data.temp ?? "--"
                font.pixelSize: root.fs; color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Battery — uses Battery service (only shows on laptops)
        Row {
            visible: root.cfgBattery && Battery.available
            spacing: Math.round(4 * root.scaleFactor)
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol {
                text: Battery.isCharging ? "battery_charging_full"
                    : Battery.percentage > 0.8 ? "battery_full"
                    : Battery.percentage > 0.5 ? "battery_3_bar"
                    : Battery.percentage > 0.2 ? "battery_2_bar" : "battery_alert"
                iconSize: root.ico
                color: Battery.isCritical ? Appearance.colors.colError : root.colText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: root.cfgShowLabels
                text: "Battery"
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor * root.textScale)
                color: ColorUtils.applyAlpha(root.colText, 0.55); anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: Math.round(Battery.percentage * 100) + "%"
                font { pixelSize: root.fs; family: Appearance.font.family.numbers }
                color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Network status — uses Network service
        Row {
            visible: root.cfgNetwork
            spacing: Math.round(4 * root.scaleFactor)
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol { text: Network.materialSymbol; iconSize: root.ico; color: root.colText; anchors.verticalCenter: parent.verticalCenter }
            StyledText {
                visible: root.cfgShowLabels
                text: "Network"
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor * root.textScale)
                color: ColorUtils.applyAlpha(root.colText, 0.55); anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: Network.wifi
                text: Network.networkName || "WiFi"
                font.pixelSize: root.fs; color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Volume — uses Audio service
        Row {
            visible: root.cfgVolume && Audio.ready
            spacing: Math.round(4 * root.scaleFactor)
            anchors.verticalCenter: parent.verticalCenter
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off"
                    : Audio.value > 0.5 ? "volume_up"
                    : Audio.value > 0 ? "volume_down" : "volume_mute"
                iconSize: root.ico; color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                visible: root.cfgShowLabels
                text: "Volume"
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor * root.textScale)
                color: ColorUtils.applyAlpha(root.colText, 0.55); anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: Math.round((Audio.value ?? 0) * 100) + "%"
                font { pixelSize: root.fs; family: Appearance.font.family.numbers }
                color: root.colText; anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
