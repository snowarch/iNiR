import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarRight.quickToggles
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
        text: Translation.tr("%1 | Right-click to configure").arg(Network.connectionTooltip())
    }
}
