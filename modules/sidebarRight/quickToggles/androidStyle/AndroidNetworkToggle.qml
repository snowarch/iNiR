import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

AndroidQuickToggleButton {
    id: root
    
    name: Translation.tr("Internet")
    statusText: {
        if (Network.wifiStatus === "limited") return Translation.tr("No internet");
        if (Network.wifiStatus === "connecting") return Translation.tr("Connecting…");
        if (Network.wifiStatus === "disconnected") return Translation.tr("Disconnected");
        if (Network.wifiStatus === "disabled") return Translation.tr("Disabled");
        return Network.networkName || Translation.tr("Not connected");
    }

    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    mainAction: () => Network.toggleWifi()
    altAction: () => root.openMenu()
    StyledToolTip {
        text: {
            if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is disabled");
            if (Network.ethernet) return Translation.tr("Ethernet connected");
            if (Network.wifiStatus === "disconnected" || (!Network.wifi && !Network.ethernet))
                return Translation.tr("Not connected | Right-click to configure");
            if (Network.wifiStatus === "connecting")
                return Translation.tr("Connecting… | Right-click to configure");
            if (Network.wifiStatus === "disabled")
                return Translation.tr("Wi-Fi is disabled");
            if (!Network.networkName) return Translation.tr("Not connected | Right-click to configure");
            let info = Network.networkName;
            if (Network.wifiStatus === "limited")
                info += " (⚠ no internet)";
            if (Network.active) {
                info += " (" + Network.networkStrength + "%)"
                if (Network.active.rate) info += " | " + Network.active.rate;
                if (Network.active.frequency) {
                    let ghz = Network.active.frequency > 5900 ? "6 GHz" : (Network.active.frequency > 4000 ? "5 GHz" : "2.4 GHz");
                    info += " | " + ghz;
                }
            }
            return Translation.tr("%1 | Right-click to configure").arg(info);
        }
    }
}
