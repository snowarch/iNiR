pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property var devices: (Bluetooth.defaultAdapter?.devices?.values ?? [])
        .filter(device => device && (device.paired || device.connected || device.trusted))
    spacing: 2 * root.d

    IrisText {
        visible: !BluetoothStatus.enabled
        Layout.fillWidth: true
        Layout.margins: 10 * root.d
        text: Translation.tr("Bluetooth is off")
        role: IrisText.Meta
    }
    IrisText {
        visible: BluetoothStatus.enabled && root.devices.length === 0
        Layout.fillWidth: true
        Layout.margins: 10 * root.d
        text: Translation.tr("No paired devices")
        role: IrisText.Meta
    }

    Repeater {
        model: BluetoothStatus.enabled ? root.devices : []
        IrisButton {
            id: deviceRow
            required property BluetoothDevice modelData
            Layout.fillWidth: true
            quiet: true
            implicitHeight: Math.round(40 * root.d)
            buttonRadius: IrisStyle.radiusTile
            onClicked: {
                if (deviceRow.modelData.connected) deviceRow.modelData.disconnect()
                else deviceRow.modelData.connect()
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10 * root.d
                anchors.rightMargin: 10 * root.d
                spacing: 10 * root.d
                MaterialSymbol {
                    text: BluetoothStatus._materialIconForDevice(deviceRow.modelData)
                    iconSize: Math.round(19 * root.d)
                    color: deviceRow.modelData.connected ? IrisStyle.accent : IrisStyle.text
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2
                    IrisText {
                        Layout.fillWidth: true
                        text: deviceRow.modelData.name ?? deviceRow.modelData.address
                        elide: Text.ElideRight
                        color: deviceRow.modelData.connected ? IrisStyle.accent : IrisStyle.text
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: deviceRow.modelData.connected
                        text: deviceRow.modelData.batteryAvailable
                            ? Translation.tr("Connected · %1%").arg(Math.round(deviceRow.modelData.battery * 100))
                            : Translation.tr("Connected")
                        role: IrisText.Meta
                    }
                }
            }
        }
    }
}
