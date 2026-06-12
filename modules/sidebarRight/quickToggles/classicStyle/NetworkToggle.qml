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
