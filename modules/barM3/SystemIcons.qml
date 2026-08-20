import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3

    implicitWidth: root.vertical ? 32 : flow.implicitWidth + 4
    implicitHeight: root.vertical ? flow.implicitHeight + 4 : 32

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton)
                Audio.sink.audio.muted = !Audio.sink.audio.muted;
            else
                GlobalStates.toggleSidebarRight(root.QsWindow.window?.screen?.name ?? "");
        }

        property real wheelAccum: 0
        onWheel: event => {
            wheelAccum += event.angleDelta.y;
            while (wheelAccum >= 120) {
                wheelAccum -= 120;
                Audio.incrementVolume();
            }
            while (wheelAccum <= -120) {
                wheelAccum += 120;
                Audio.decrementVolume();
            }
            event.accepted = true;
        }
    }

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: isMaterial ? 2 : 10

        Revealer {
            reveal: true
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            MaterialSymbol {
                text: "mic_off"
                iconSize: Appearance.font.pixelSize.larger
                color: root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1
            }
        }
        Loader {
            id: xkbLoader
            // Sized like notifLoader below: inside a Flow the inner indicator's
            // Layout.preferredWidth does nothing, so releasing Caps Lock left the
            // reserved width behind.
            active: KeyboardIndicators.hasPanelIndicators
            visible: active
            width: active ? item?.implicitWidth ?? 0 : 0
            height: active ? item?.implicitHeight ?? 0 : 0
            source: "HyprlandXkbIndicator.qml"
            onLoaded: {
                if (item)
                    item.color = Qt.binding(() => root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1)
            }
        }
        MaterialSymbol {
            text: Network.materialSymbol ?? "signal_wifi_off"
            iconSize: Appearance.font.pixelSize.larger
            color: root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1
        }
        MaterialSymbol {
            visible: BluetoothStatus.available
            text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            iconSize: Appearance.font.pixelSize.larger
            color: root.isMaterial ? M3Palette.pillInk("systemIcons") : Appearance.colors.colOnLayer1
        }
        Loader {
            id: notifLoader
            active: Notifications.silent || Notifications.unread > 0
            visible: active
            width: active ? item?.implicitWidth ?? 0 : 0
            height: active ? item?.implicitHeight ?? 0 : 0
            source: "NotificationUnreadCount.qml"
            onLoaded: {
                if (item)
                    item.embeddedInSystemIcons = true
            }
        }
    }
}
