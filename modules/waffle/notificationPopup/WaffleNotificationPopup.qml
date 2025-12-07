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
    
    // Position from shared notifications config
    readonly property string position: Config.options?.notifications?.position ?? "bottomRight"
    readonly property bool isTop: position.startsWith("top")
    readonly property bool isLeft: position.endsWith("Left")

    PanelWindow {
        id: panelWindow
        // Hide during GameMode to avoid input interference
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !GlobalStates.waffleNotificationCenterOpen && !GameMode.active

        screen: CompositorService.isNiri
            ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? Quickshell.screens[0]
            : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        WlrLayershell.namespace: "quickshell:wNotificationPopup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0
        
        // Only capture input on actual notification area
        mask: Region {
            item: listview
        }

        anchors {
            top: root.isTop
            bottom: !root.isTop
            left: root.isLeft
            right: !root.isLeft
        }

        color: "transparent"
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
