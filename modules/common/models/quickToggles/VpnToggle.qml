import QtQuick
import qs.services
import qs.modules.common

QuickToggleModel {
    id: root
    name: Translation.tr("VPN")

    available: Vpn.available
    toggled: Vpn.connected
    icon: Vpn.connected ? "vpn_lock" : "vpn_key_off"
    statusText: Vpn.connected ? Vpn.activeName : ""
    hasStatusText: true
    tooltipText: Vpn.connected
        ? Translation.tr("On through %1").arg(Vpn.activeName)
        : Translation.tr("Not connected")

    mainAction: () => Vpn.toggle()
    altAction: () => Vpn.refresh()

    Component.onCompleted: Vpn.refresh()
}
