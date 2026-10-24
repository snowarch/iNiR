pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetBattery")

    readonly property var glyphs: ({
        mouse: "mouse", keyboard: "keyboard", headset: "headset_mic", headphones: "headphones",
        phone: "smartphone", tablet: "tablet", gaminginput: "stadia_controller", pen: "stylus",
        touchpad: "touchpad_mouse", speakers: "speaker", wearable: "watch"
    })
    readonly property var devices: {
        const list = []
        if (Battery.available)
            list.push({ name: Translation.tr("This computer"), glyph: "laptop", level: Battery.percentage,
                charging: Battery.isCharging, low: Battery.isLow })
        for (const device of UPower.devices.values) {
            if (!device || device.isLaptopBattery || !device.isPresent || device.type === UPowerDeviceType.LinePower)
                continue
            const kind = UPowerDeviceType.toString(device.type).toLowerCase().replace(/\s/g, "")
            if (!root.glyphs[kind])
                continue
            list.push({ name: device.model || UPowerDeviceType.toString(device.type), glyph: root.glyphs[kind],
                level: device.percentage, charging: device.state === UPowerDeviceState.Charging,
                low: device.percentage <= 0.2 })
        }
        return list.slice(0, root.large ? 5 : 4)
    }

    function tint(device: var): color {
        return device.low && !device.charging ? root.danger
            : device.charging ? root.warm : root.accent
    }

    readonly property int columns: root.small ? Math.min(2, root.devices.length) : root.devices.length
    readonly property int rows: Math.ceil(root.devices.length / Math.max(1, root.columns))
    readonly property real cellWidth: (root.contentWidth - root.dp(12) * (root.columns - 1)) / Math.max(1, root.columns)
    readonly property real diameter: Math.min(root.dp(root.small ? 78 : 94), root.cellWidth,
        (root.height - root.padding * 2 - root.dp(10) * (root.rows - 1)) / Math.max(1, root.rows) - root.dp(21))

    // One device: its glyph on its colour (charging warm, low in danger), the charge as the figure under it. A ring
    // around the figure said the same charge twice.
    component Gauge: ColumnLayout {
        id: gauge
        required property var device
        property real diameter: root.dp(56)
        readonly property color tint: gauge.device.low || gauge.device.charging ? root.tint(gauge.device) : root.inkSecondary
        spacing: root.dp(4)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.round(gauge.diameter * 0.5)
            Layout.preferredHeight: Layout.preferredWidth
            radius: IrisStyle.capsule(width)
            color: gauge.device.low || gauge.device.charging ? IrisStyle.tintFill(gauge.tint) : root.fill
            MaterialSymbol {
                anchors.centerIn: parent
                text: gauge.device.charging ? "bolt" : gauge.device.glyph
                fill: 1
                iconSize: Math.round(parent.width * 0.5)
                color: gauge.tint
            }
        }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.dp(1)
            FaceFigure {
                id: percentage
                face: root
                text: Math.round(gauge.device.level * 100)
                size: root.small ? 24 : 28
                tone: gauge.device.low && !gauge.device.charging ? root.danger : root.ink
            }
            FaceText {
                face: root
                anchors.baseline: percentage.baseline
                text: "%"
                size: root.small ? 11 : 13
                weight: Font.DemiBold
                color: root.inkSecondary
            }
        }
        FaceText {
            face: root
            visible: !root.small
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.cellWidth
            text: gauge.device.name
            size: 11
            color: root.inkSecondary
        }
    }

    ColumnLayout {
        visible: root.devices.length === 1 && root.small
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: root.devices[0]?.glyph ?? "battery_full"
            text: root.devices[0]?.name ?? ""
            tint: root.inkSecondary
        }
        Item { Layout.fillHeight: true }
        Row {
            spacing: root.dp(2)
            FaceFigure {
                id: charge
                face: root
                text: Math.round((root.devices[0]?.level ?? 0) * 100)
                size: 48
            }
            FaceText {
                face: root
                anchors.baseline: charge.baseline
                text: "%"
                size: 22
                color: root.inkSecondary
            }
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: root.widget.timeLabel.length > 0 ? root.widget.timeLabel
                : (root.devices[0]?.charging ?? false) ? Translation.tr("Charging") : ""
            color: root.inkSecondary
            size: 12
        }
    }

    ColumnLayout {
        visible: !root.large && (root.devices.length > 1 || (root.devices.length === 1 && !root.small))
        anchors.centerIn: parent
        spacing: root.dp(10)
        Repeater {
            model: root.rows
            RowLayout {
                id: row
                required property int index
                Layout.alignment: Qt.AlignHCenter
                spacing: root.dp(12)
                Repeater {
                    model: root.devices.slice(row.index * root.columns, (row.index + 1) * root.columns)
                    Gauge {
                        required property var modelData
                        device: modelData
                        diameter: root.diameter
                        Layout.preferredWidth: root.cellWidth
                    }
                }
            }
        }
    }

    // Nothing to measure: a desktop with no battery and nothing wireless awake. It says what will show and when.
    ColumnLayout {
        visible: root.devices.length === 0
        anchors.fill: parent
        spacing: root.dp(4)
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "battery_full"
            text: Translation.tr("Batteries")
            tint: root.inked(IrisStyle.identity.green)
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Large: right under the head, where the first device would be; smaller faces have no room to spare.
            FaceBlank {
                face: root
                y: root.large ? root.dp(28) : Math.round((parent.height - height) / 2)
                width: parent.width
                glyph: "power"
                glyphFill: true
                tint: root.inked(IrisStyle.identity.green)
                title: Translation.tr("On power")
                detail: Translation.tr("Devices you pair show up here")
            }
        }
    }

    // Large: one row per device, its glyph on its colour, the name and what it is doing, the charge leading.
    ColumnLayout {
        visible: root.large && root.devices.length > 0
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            Layout.bottomMargin: root.dp(6)
            glyph: "battery_full"
            text: Translation.tr("Batteries")
            tint: root.inked(IrisStyle.identity.green)
        }
        Repeater {
            model: root.large ? root.devices : []
            ColumnLayout {
                id: device
                required property var modelData
                required property int index
                readonly property color tint: root.tint(device.modelData)
                Layout.fillWidth: true
                spacing: 0
                Rectangle {
                    visible: device.index > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.leftMargin: root.dp(52)
                    color: root.hairline
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: root.dp(10)
                    Layout.bottomMargin: root.dp(10)
                    spacing: root.dp(12)
                    Rectangle {
                        Layout.preferredWidth: root.dp(40)
                        Layout.preferredHeight: root.dp(40)
                        radius: IrisStyle.capsule(width)
                        color: IrisStyle.tintFill(device.tint)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: device.modelData.charging ? "bolt" : device.modelData.glyph
                            fill: 1
                            iconSize: root.px(20)
                            color: device.tint
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            text: device.modelData.name
                            size: 13.5
                            weight: Font.DemiBold
                        }
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: device.modelData.charging ? Translation.tr("Charging")
                                : device.modelData.level >= 0.995 ? Translation.tr("Fully charged")
                                : device.modelData.low ? Translation.tr("Low") : ""
                            color: device.modelData.low && !device.modelData.charging ? root.danger : root.inkSecondary
                            size: 12
                        }
                    }
                    Row {
                        spacing: root.dp(1)
                        FaceFigure {
                            id: level
                            face: root
                            text: Math.round(device.modelData.level * 100)
                            size: 26
                            tone: device.modelData.low && !device.modelData.charging ? root.danger : root.ink
                        }
                        FaceText {
                            face: root
                            anchors.baseline: level.baseline
                            text: "%"
                            size: 13
                            color: root.inkSecondary
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
