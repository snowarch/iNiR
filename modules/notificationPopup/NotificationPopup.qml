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

    Component.onCompleted: Notifications.ensureInitialized()

    PanelWindow {
        id: root
        // Hide during GameMode to avoid input interference
        visible: (Notifications.popupList.length > 0) && !GlobalStates.screenLocked && !(GameMode.active && GameMode.suppressNotifications)
        screen: CompositorService.isNiri
            ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen
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
        // Add height buffer to account for Wayland compositor resize delay
        // This prevents content clipping while the window catches up to new content size
        implicitHeight: Math.min(listview.contentHeight + edgeMargin * 2 + heightBuffer, screen?.height * 0.8 ?? 600)

        readonly property int edgeMargin: Config.options?.notifications?.edgeMargin ?? 4
        // Extra buffer so content isn't clipped during async Wayland resize
        readonly property int heightBuffer: 16

        NotificationListView {
            id: listview
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: root.edgeMargin
                leftMargin: root.edgeMargin
                rightMargin: root.edgeMargin
            }
            // Size to content — don't stretch to fill PanelWindow
            // The heightBuffer only enlarges the window (prevents Wayland clipping)
            // but the listview stays content-sized so no empty space is visible
            implicitHeight: contentHeight
            // Clip content to prevent overflow while PanelWindow resizes asynchronously
            clip: true
            popup: true
        }
    }
}
