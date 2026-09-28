pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property bool labelled: !root.small
    readonly property int columns: root.small ? 2 : 4
    readonly property real spacing: root.dp(root.small ? 14 : 12)
    readonly property real cell: (root.contentWidth - root.spacing * (root.columns - 1)) / root.columns
    readonly property real disc: Math.min(root.cell, root.dp(root.small ? 60 : root.medium ? 48 : 56))
    readonly property var monitor: Brightness.getMonitorForScreen(root.QsWindow?.window?.screen ?? null)

    component Toggle: Item {
        id: toggle
        property string glyph: ""
        property string label: ""
        property bool on: false
        property color tint: root.accent
        property bool available: true
        signal toggled()

        Layout.preferredWidth: root.cell
        Layout.preferredHeight: root.disc + (root.labelled ? root.dp(20) : 0)
        opacity: toggle.available ? 1 : 0.4

        Rectangle {
            id: disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.disc
            height: root.disc
            radius: height / 2
            color: toggle.on ? toggle.tint : tap.pressed ? root.fillActive : hover.hovered ? root.fillHover : root.fill
            scale: tap.pressed ? IrisStyle.pressScale(0.94) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: toggle.glyph
                fill: toggle.on ? 1 : 0
                iconSize: Math.round(root.disc * 0.42)
                color: toggle.on ? root.onFill(toggle.tint) : root.ink
            }
            HoverHandler { id: hover; enabled: toggle.available; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: tap; enabled: toggle.available; gesturePolicy: TapHandler.WithinBounds; onTapped: toggle.toggled() }
        }
        FaceText {
            face: root
            visible: root.labelled
            anchors.top: disc.bottom
            anchors.topMargin: root.dp(5)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: toggle.label
            color: toggle.on ? root.ink : root.inkSecondary
            size: 11
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: toggle.label
        Accessible.checked: toggle.on
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.dp(root.large ? 14 : 12)

        Item { Layout.fillHeight: root.large; visible: root.large }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: root.small
            columns: root.columns
            columnSpacing: root.spacing
            rowSpacing: root.dp(root.small ? 14 : 10)

            Toggle {
                glyph: Network.ethernet ? "lan" : Network.wifiEnabled ? "wifi" : "wifi_off"
                label: Network.ethernet ? Translation.tr("Ethernet") : (Network.networkName || Translation.tr("Wi-Fi"))
                on: Network.ethernet || Network.wifiEnabled
                tint: IrisStyle.identity.blue
                onToggled: Network.toggleWifi()
            }
            Toggle {
                glyph: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                label: BluetoothStatus.activeDeviceSummary() || Translation.tr("Bluetooth")
                on: BluetoothStatus.enabled
                available: BluetoothStatus.available
                tint: IrisStyle.identity.blue
                onToggled: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
            }
            Toggle {
                glyph: Notifications.manualDndActive ? "do_not_disturb_on" : "do_not_disturb_off"
                label: Translation.tr("Focus")
                on: Notifications.manualDndActive
                tint: IrisStyle.identity.indigo
                onToggled: Notifications.toggleSilent()
            }
            Toggle {
                glyph: "nightlight"
                label: Translation.tr("Night light")
                on: Hyprsunset.active
                tint: IrisStyle.identity.orange
                onToggled: Hyprsunset.toggle()
            }
            Toggle {
                visible: root.large
                glyph: "coffee"
                label: Translation.tr("Keep awake")
                on: Idle.inhibit
                tint: IrisStyle.identity.yellow
                onToggled: Idle.toggleInhibit()
            }
            Toggle {
                visible: root.large
                glyph: "sports_esports"
                label: Translation.tr("Game mode")
                on: GameMode.active
                tint: IrisStyle.identity.green
                onToggled: GameMode.toggle()
            }
            Toggle {
                visible: root.large
                glyph: Audio.micMuted ? "mic_off" : "mic"
                label: Translation.tr("Microphone")
                on: Audio.source !== null && !Audio.micMuted
                available: Audio.source !== null
                tint: IrisStyle.identity.orange
                onToggled: Audio.toggleMicMute()
            }
            Toggle {
                visible: root.large
                glyph: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                label: Translation.tr("Dark mode")
                on: Appearance.m3colors.darkmode
                tint: IrisStyle.identity.indigo
                onToggled: Appearance.toggleDarkMode()
            }
        }

        IrisCapsuleSlider {
            visible: !root.small
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            muted: Audio.sink?.audio?.muted ?? false
            icon: muted ? "volume_off" : (Audio.value ?? 0) < 0.34 ? "volume_mute" : (Audio.value ?? 0) < 0.67 ? "volume_down" : "volume_up"
            value: Math.min(1, Audio.value ?? 0)
            Accessible.name: Translation.tr("Volume")
            onMoved: next => Audio.setSinkVolume(next)
            onIconClicked: Audio.toggleMute()
        }
        IrisCapsuleSlider {
            visible: root.large && root.monitor !== null
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            icon: "light_mode"
            value: root.monitor?.brightness ?? 0
            Accessible.name: Translation.tr("Brightness")
            onMoved: next => root.monitor?.setBrightness(next)
        }

        Item { Layout.fillHeight: root.large; visible: root.large }
    }
}
