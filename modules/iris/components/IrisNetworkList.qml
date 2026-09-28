pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property var networks: (Network.wifiNetworks ?? []).slice()
        .sort((a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) || b.strength - a.strength)
        .slice(0, 8)
    spacing: 2 * root.d

    Component.onCompleted: if (Network.wifiEnabled) Network.rescanWifi()

    IrisText {
        visible: !Network.wifiEnabled || root.networks.length === 0
        Layout.fillWidth: true
        Layout.margins: 10 * root.d
        text: !Network.wifiEnabled ? Translation.tr("Wi-Fi is off")
            : Network.wifiScanning ? Translation.tr("Looking for networks…")
            : Translation.tr("No networks in range")
        role: IrisText.Meta
    }

    Repeater {
        model: Network.wifiEnabled ? root.networks : []
        IrisButton {
            id: networkRow
            required property var modelData
            Layout.fillWidth: true
            quiet: true
            implicitHeight: Math.round(40 * root.d)
            buttonRadius: IrisStyle.radiusTile
            onClicked: {
                if (networkRow.modelData.active) Network.disconnectWifiNetwork()
                else Network.connectToWifiNetwork(networkRow.modelData)
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10 * root.d
                anchors.rightMargin: 10 * root.d
                spacing: 10 * root.d
                MaterialSymbol {
                    text: networkRow.modelData.strength >= 75 ? "signal_wifi_4_bar"
                        : networkRow.modelData.strength >= 50 ? "network_wifi_3_bar"
                        : networkRow.modelData.strength >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                    iconSize: Math.round(19 * root.d)
                    color: networkRow.modelData.active ? IrisStyle.accent : IrisStyle.text
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2
                    IrisText {
                        Layout.fillWidth: true
                        text: networkRow.modelData.ssid
                        elide: Text.ElideRight
                        color: networkRow.modelData.active ? IrisStyle.accent : IrisStyle.text
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: networkRow.modelData.active
                        text: Translation.tr("Connected")
                        role: IrisText.Meta
                    }
                }
                MaterialSymbol {
                    visible: networkRow.modelData.isSecure
                    text: "lock"
                    iconSize: Math.round(13 * root.d)
                    color: IrisStyle.textTertiary
                }
            }
        }
    }
}
