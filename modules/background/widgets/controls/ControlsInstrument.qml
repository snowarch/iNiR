pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.background.widgets.instrument

// Controls as an Instrument patch panel: numbered channels with a lamp and their state in words,
// and volume and brightness as scales you click to set. Size decides how many channels show.
Item {
    id: root

    required property var widget
    readonly property real s: root.widget.scaleFactor
    readonly property color ink: root.widget.widgetInk
    readonly property color muted: root.widget.widgetInkMuted
    readonly property color accent: root.widget.widgetAccentVisible
    readonly property var monitor: Brightness.getMonitorForScreen(root.QsWindow?.window?.screen ?? null)
    readonly property string size: String(root.widget.irisSize ?? "medium")

    readonly property var channels: {
        const list = [
            { glyph: Network.ethernet ? "lan" : "wifi", label: Network.ethernet ? Translation.tr("Ethernet") : Translation.tr("Wi-Fi"),
              detail: Network.ethernet ? Translation.tr("Wired") : (Network.networkName || ""), on: Network.ethernet || Network.wifiEnabled,
              available: true, toggle: () => Network.toggleWifi() },
            { glyph: "bluetooth", label: Translation.tr("Bluetooth"), detail: BluetoothStatus.activeDeviceSummary() || "",
              on: BluetoothStatus.enabled, available: BluetoothStatus.available,
              toggle: () => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled } },
            { glyph: "do_not_disturb_on", label: Translation.tr("Focus"), detail: "", on: Notifications.manualDndActive,
              available: true, toggle: () => Notifications.toggleSilent() },
            { glyph: "nightlight", label: Translation.tr("Night light"), detail: "", on: Hyprsunset.active,
              available: true, toggle: () => Hyprsunset.toggle() }
        ]
        if (root.size === "large") list.push(
            { glyph: "coffee", label: Translation.tr("Keep awake"), detail: "", on: Idle.inhibit, available: true, toggle: () => Idle.toggleInhibit() },
            { glyph: "sports_esports", label: Translation.tr("Game mode"), detail: "", on: GameMode.active, available: true, toggle: () => GameMode.toggle() },
            { glyph: "mic", label: Translation.tr("Microphone"), detail: "", on: Audio.source !== null && !Audio.micMuted,
              available: Audio.source !== null, toggle: () => Audio.toggleMicMute() },
            { glyph: "dark_mode", label: Translation.tr("Dark mode"), detail: "", on: Appearance.m3colors.darkmode,
              available: true, toggle: () => Appearance.toggleDarkMode() })
        return list
    }

    implicitWidth: Math.round((root.size === "small" ? 220 : 300) * root.s)
    implicitHeight: column.implicitHeight + Math.round(24 * root.s)

    component Channel: MouseArea {
        id: channel
        required property var modelData
        required property int index
        Layout.fillWidth: true
        implicitHeight: Math.round(26 * root.s)
        enabled: channel.modelData.available
        opacity: enabled ? 1 : 0.4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: channel.modelData.toggle()
        Accessible.role: Accessible.CheckBox
        Accessible.name: channel.modelData.label
        Accessible.checked: channel.modelData.on

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -Math.round(4 * root.s)
            anchors.rightMargin: -Math.round(4 * root.s)
            radius: Math.round(4 * root.s)
            color: ColorUtils.applyAlpha(root.accent, channel.pressed ? 0.2 : 0.1)
            visible: channel.containsMouse
        }
        RowLayout {
            anchors.fill: parent
            spacing: Math.round(8 * root.s)
            InstrumentLabel {
                text: String(channel.index + 1).padStart(2, "0")
                color: root.muted
                scaleFactor: root.s
            }
            MaterialSymbol {
                text: channel.modelData.glyph
                iconSize: Math.round(15 * root.s)
                fill: channel.modelData.on ? 1 : 0
                color: channel.modelData.on ? root.ink : root.muted
            }
            StyledText {
                Layout.fillWidth: true
                text: channel.modelData.detail.length > 0 && root.size !== "small"
                    ? channel.modelData.label + "  ·  " + channel.modelData.detail : channel.modelData.label
                color: channel.modelData.on ? root.ink : root.muted
                elide: Text.ElideRight
                font.pixelSize: Math.round(12 * root.s)
                font.weight: channel.modelData.on ? Font.DemiBold : Font.Normal
            }
            InstrumentLabel {
                text: channel.modelData.on ? Translation.tr("On") : Translation.tr("Off")
                color: channel.modelData.on ? root.accent : root.muted
                scaleFactor: root.s
                strong: channel.modelData.on
            }
            Rectangle {
                implicitWidth: Math.round(6 * root.s)
                implicitHeight: implicitWidth
                color: channel.modelData.on ? root.accent : "transparent"
                border.width: channel.modelData.on ? 0 : 1
                border.color: root.muted
            }
        }
    }

    component Level: ColumnLayout {
        id: level
        property string label: ""
        property real value: 0
        property bool muted: false
        signal picked(real value)
        Layout.fillWidth: true
        spacing: Math.round(3 * root.s)
        RowLayout {
            Layout.fillWidth: true
            InstrumentLabel { Layout.fillWidth: true; text: level.label; color: root.muted; scaleFactor: root.s }
            InstrumentLabel {
                text: level.muted ? Translation.tr("Muted") : Math.round(level.value * 100) + "%"
                color: root.ink
                scaleFactor: root.s
                strong: true
            }
        }
        InstrumentScale {
            id: levelScale
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(10 * root.s)
            divisions: 32
            fraction: level.muted ? 0 : level.value
            ink: root.ink
            accent: root.accent
            animated: root.widget.animationsActive
            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -Math.round(4 * root.s)
                anchors.bottomMargin: -Math.round(4 * root.s)
                cursorShape: Qt.PointingHandCursor
                function pick(x: real): void { level.picked(Math.max(0, Math.min(1, x / Math.max(1, width)))) }
                onPressed: mouse => pick(mouse.x)
                onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.s)
        spacing: Math.round(4 * root.s)

        InstrumentLabel {
            Layout.fillWidth: true
            Layout.bottomMargin: Math.round(4 * root.s)
            text: Translation.tr("Controls / %1 on").arg(root.channels.filter(entry => entry.on).length)
            color: root.accent
            scaleFactor: root.s
            strong: true
        }

        Repeater {
            model: root.channels
            Channel {}
        }

        Level {
            visible: root.size !== "small"
            Layout.topMargin: Math.round(8 * root.s)
            label: Translation.tr("Volume")
            value: Math.min(1, Audio.value ?? 0)
            muted: Audio.sink?.audio?.muted ?? false
            onPicked: value => Audio.setSinkVolume(value)
        }
        Level {
            visible: root.size === "large" && root.monitor !== null
            Layout.topMargin: Math.round(6 * root.s)
            label: Translation.tr("Brightness")
            value: root.monitor?.brightness ?? 0
            onPicked: value => root.monitor?.setBrightness(value)
        }
    }
}
