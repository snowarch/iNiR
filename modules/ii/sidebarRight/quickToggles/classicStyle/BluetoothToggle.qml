import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

QuickToggleButton {
    id: root
    visible: BluetoothStatus.available
    toggled: BluetoothStatus.enabled
    buttonIcon: BluetoothStatus.activeIcon
    onClicked: {
        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter?.enabled
    }
    // altAction is set by parent (ClassicQuickPanel opens dialog, others may open external app)
    StyledToolTip {
        text: Translation.tr("%1 | Right-click to configure").arg(
            (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth"))
            + (BluetoothStatus.activeDeviceCount > 1 ? ` +${BluetoothStatus.activeDeviceCount - 1}` : "")
            )
    }
}
