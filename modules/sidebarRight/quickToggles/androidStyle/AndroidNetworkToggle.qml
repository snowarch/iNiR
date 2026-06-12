import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick

AndroidQuickToggleButton {
    id: root
    
    name: Translation.tr("Internet")
    statusText: Network.networkName

    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    mainAction: () => Network.toggleWifi()
    altAction: () => root.openMenu()
    StyledToolTip {
        text: {
            if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is disabled");
            if (Network.ethernet) return Translation.tr("Ethernet connected");
            if (!Network.networkName) return Translation.tr("Not connected");
            let info = Network.networkName;
            if (Network.active) {
                info += " (" + Network.networkStrength + "%)";
                if (Network.active.rate) info += " | " + Network.active.rate;
                if (Network.active.frequency) {
                    let ghz = Network.active.frequency > 4000 ? "5 GHz" : "2.4 GHz";
                    info += " | " + ghz;
                }
            }
            return Translation.tr("%1 | Right-click to configure").arg(info);
        }
    }
}

