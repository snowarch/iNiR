import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: notificationPopup
    
    // Position from config: topRight, topLeft, bottomRight, bottomLeft
    readonly property string position: Config.options?.notifications?.position ?? "topRight"
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isLeft: position.endsWith("Left")

    PanelWindow {
        id: root
        // Hide during GameMode to avoid input interference
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !GameMode.active
        screen: CompositorService.isNiri 
            ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0]
            : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

        WlrLayershell.namespace: "quickshell:notificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0
        
        // Only capture input on actual notification area
        mask: Region {
            item: listview
        }

        anchors {
            top: notificationPopup.isTop
            bottom: !notificationPopup.isTop
            left: notificationPopup.isLeft
            right: !notificationPopup.isLeft
        }

        color: "transparent"
        implicitWidth: Appearance.sizes.notificationPopupWidth
        implicitHeight: Math.min(listview.contentHeight + 8, screen?.height * 0.8 ?? 600)

        NotificationListView {
            id: listview
            anchors {
                fill: parent
                margins: 4
            }
            popup: true
        }
    }
}
