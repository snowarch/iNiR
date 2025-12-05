pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked

        screen: CompositorService.isNiri
            ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0]
            : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "quickshell:wNotificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        // Position: bottom-right for waffle (Windows 11 style)
        anchors {
            bottom: Config.options?.waffles?.bar?.bottom ?? true
            top: !(Config.options?.waffles?.bar?.bottom ?? true)
            right: true
        }

        color: "transparent"
        // Windows 11 toast width is 364px content + padding
        implicitWidth: 380
        implicitHeight: Math.min(listview.contentHeight + 16, (screen?.height ?? 800) * 0.7)

        WNotificationListView {
            id: listview
            anchors {
                fill: parent
                margins: 8
            }
        }
    }
}
