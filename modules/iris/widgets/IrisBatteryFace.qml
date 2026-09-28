pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.bar.island

IrisWidgetFace {
    id: root

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
        return list.slice(0, 4)
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

    component Gauge: ColumnLayout {
        id: gauge
        required property var device
        property real diameter: root.dp(56)
        spacing: root.dp(5)
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: gauge.diameter
            Layout.preferredHeight: gauge.diameter
            ProgressRing {
                anchors.fill: parent
                progress: gauge.device.level
                tint: root.tint(gauge.device)
                stroke: Math.max(3, gauge.diameter * 0.1)
            }
            Row {
                anchors.centerIn: parent
                spacing: root.dp(1)
                FaceFigure {
                    id: percentage
                    face: root
                    text: Math.round(gauge.device.level * 100)
                    size: gauge.diameter / root.k * 0.29
                }
                FaceText {
                    face: root
                    anchors.baseline: percentage.baseline
                    text: "%"
                    size: Math.max(8, gauge.diameter / root.k * 0.14)
                    color: root.inkSecondary
                }
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: root.cellWidth
            spacing: root.dp(4)
            MaterialSymbol {
                text: gauge.device.charging ? "bolt" : gauge.device.glyph
                fill: 1
                iconSize: root.px(14)
                color: gauge.device.charging ? root.tint(gauge.device) : root.inkSecondary
            }
            FaceText {
                face: root
                visible: !root.small
                Layout.fillWidth: true
                text: gauge.device.name
                size: 10.5
                color: root.inkSecondary
            }
        }
    }

    ColumnLayout {
        visible: root.devices.length === 0
        anchors.centerIn: parent
        width: parent.width
        spacing: root.dp(6)
        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "power"
            fill: 1
            iconSize: root.px(30)
            color: root.accent
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("On power")
            size: 13.5
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("No batteries to watch")
            color: root.inkSecondary
            size: 12
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
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: root.dp(8)
            Layout.preferredHeight: root.dp(9)
            radius: height / 2
            color: root.fill
            Rectangle {
                width: parent.width * (root.devices[0]?.level ?? 0)
                height: parent.height
                radius: height / 2
                color: root.devices.length > 0 ? root.tint(root.devices[0]) : "transparent"
            }
        }
    }

    ColumnLayout {
        visible: root.devices.length > 1 || (root.devices.length === 1 && !root.small)
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
}
