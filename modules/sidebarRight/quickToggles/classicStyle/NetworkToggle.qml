import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight.quickToggles
import qs
import QtQuick
import Quickshell
import Quickshell.Io

QuickToggleButton {
    id: root
    toggled: Network.wifiStatus !== "disabled"
    buttonIcon: Network.materialSymbol
    onClicked: Network.toggleWifi()
    // altAction is set by parent (ClassicQuickPanel opens dialog, others may open external app)
    StyledToolTip {
        text: {
            if (!Network.wifiEnabled) return Translation.tr("Wi-Fi is disabled");
            if (Network.ethernet) return Translation.tr("Ethernet connected");
            // Show special states clearly
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
                info += " (" + Network.networkStrength + "%)";
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
