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
    // Medium and large: wide tiles as the Control Center's (a disc, the name and what it is doing), two a row.
    readonly property bool tiles: !root.small
    readonly property int columns: root.tiles ? 2 : 2
    readonly property real spacing: root.dp(root.small ? 14 : 12)
    readonly property real cell: (root.contentWidth - root.spacing * (root.columns - 1)) / root.columns
    readonly property real disc: Math.min(root.cell, root.dp(root.small ? 60 : root.medium ? 48 : 56))
    readonly property var monitor: Brightness.getMonitorForScreen(root.QsWindow?.window?.screen ?? null)
    // The keys the person kept, in their order: small and medium show the first four, large eight.
    readonly property var kept: ["wifi", "bluetooth", "focus", "nightLight", "awake", "gameMode", "mic", "darkMode"]
        .filter(key => Boolean(root.widget.irisOption("tile." + key, true)))
    function shows(key: string): bool {
        const at = root.kept.indexOf(key)
        return at >= 0 && at < (root.large ? 8 : 4)
    }
    readonly property bool sliders: Boolean(root.widget.irisOption("sliders", true))

    component Toggle: Item {
        id: toggle
        property string glyph: ""
        property string label: ""
        property bool on: false
        property color tint: root.accent
        property bool available: true
        property string status: toggle.on ? Translation.tr("On") : Translation.tr("Off")
        signal toggled()

        Layout.fillWidth: root.tiles
        Layout.preferredWidth: root.tiles ? 1 : root.cell
        Layout.preferredHeight: root.tiles ? root.dp(root.large ? 46 : 40) : root.disc
        opacity: toggle.available || discSkinned ? 1 : 0.4
        readonly property bool discSkinned: IrisDesign.has("controlTile")

        // The tile behind a wide control: the whole of it is the key.
        Rectangle {
            id: tilePlate
            visible: root.tiles
            anchors.fill: parent
            radius: Math.min(root.innerRadius, height / 2)
            // a chamfered Design cuts the tile with its die, as every plate on its bodies
            readonly property color fill: tap.pressed ? root.fillActive : hover.hovered ? root.fillHover : root.fillQuiet
            color: IrisStyle.fieldChamfer ? "transparent" : tilePlate.fill
            IrisCutPlate {
                anchors.fill: parent
                visible: IrisStyle.fieldChamfer
                color: tilePlate.fill
                cutLength: Math.round(parent.height * 0.28)
            }
            scale: tap.pressed ? IrisStyle.pressScale(0.97) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            ColumnLayout {
                anchors.left: parent.left
                anchors.leftMargin: disc.width + root.dp(14)
                anchors.right: parent.right
                anchors.rightMargin: root.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: toggle.label
                    size: 12
                    weight: Font.DemiBold
                    color: toggle.available ? root.ink : root.inkTertiary
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: toggle.available ? toggle.status : Translation.tr("Unavailable")
                    size: 10.5
                    color: toggle.on ? root.inkSecondary : root.inkTertiary
                }
            }
        }

        Rectangle {
            id: disc
            width: root.tiles ? parent.height - root.dp(12) : root.disc
            height: width
            x: root.tiles ? root.dp(6) : Math.round((parent.width - width) / 2)
            y: root.tiles ? Math.round((parent.height - height) / 2) : 0
            radius: IrisStyle.capsule(height)
            color: disc.skinned ? "transparent" : toggle.on ? toggle.tint : tap.pressed ? root.fillActive : hover.hovered ? root.fillHover : root.fill
            scale: tap.pressed && !disc.skinned ? IrisStyle.pressScale(0.94) : 1
            // A Design's control key (IrisDesign part `controlTile`) draws it, as it draws the Control Center's.
            readonly property bool skinned: discSkin.active
            readonly property bool hovered: hover.hovered
            readonly property bool down: tap.pressed
            readonly property bool visualFocus: false
            readonly property var skinData: ({ shape: "disc", control: ({ lit: toggle.on, ready: toggle.available, glyph: toggle.glyph,
                label: toggle.label, tint: toggle.tint }) })
            IrisSkin { id: discSkin; part: "controlTile"; host: disc }
            Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

            MaterialSymbol {
                visible: !disc.skinned
                anchors.centerIn: parent
                text: toggle.glyph
                fill: toggle.on ? 1 : 0
                iconSize: Math.round(disc.width * 0.46)
                color: toggle.on ? root.onFill(toggle.tint) : root.ink
            }
        }
        // On the whole control, not the disc: a tap on a tile's name did nothing.
        HoverHandler { id: hover; enabled: toggle.available; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; enabled: toggle.available; gesturePolicy: TapHandler.WithinBounds; onTapped: toggle.toggled() }

        Accessible.role: Accessible.CheckBox
        Accessible.name: toggle.label
        Accessible.checked: toggle.on
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.dp(root.large ? 14 : 12)

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: root.tiles
            Layout.fillHeight: root.small
            columns: root.columns
            columnSpacing: root.tiles ? root.dp(8) : root.spacing
            rowSpacing: root.dp(root.small ? 14 : 8)

            Toggle {
                visible: root.shows("wifi")
                glyph: Network.ethernet ? "lan" : Network.wifiEnabled ? "wifi" : "wifi_off"
                label: Network.ethernet ? Translation.tr("Ethernet") : (Network.networkName || Translation.tr("Wi-Fi"))
                on: Network.ethernet || Network.wifiEnabled
                status: Network.ethernet ? Translation.tr("Connected") : Network.wifiEnabled
                    ? (Network.networkName || Translation.tr("Not connected")) : Translation.tr("Off")
                tint: root.inked(IrisStyle.identity.blue)
                onToggled: Network.toggleWifi()
            }
            Toggle {
                visible: root.shows("bluetooth")
                glyph: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                label: root.tiles ? Translation.tr("Bluetooth") : (BluetoothStatus.activeDeviceSummary() || Translation.tr("Bluetooth"))
                status: !BluetoothStatus.enabled ? Translation.tr("Off") : (BluetoothStatus.activeDeviceSummary() || Translation.tr("On"))
                on: BluetoothStatus.enabled
                available: BluetoothStatus.available
                tint: root.inked(IrisStyle.identity.blue)
                onToggled: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
            }
            Toggle {
                visible: root.shows("focus")
                glyph: Notifications.manualDndActive ? "do_not_disturb_on" : "do_not_disturb_off"
                label: Translation.tr("Focus")
                on: Notifications.manualDndActive
                tint: root.inked(IrisStyle.identity.indigo)
                onToggled: Notifications.toggleSilent()
            }
            Toggle {
                visible: root.shows("nightLight")
                glyph: "nightlight"
                label: Translation.tr("Night light")
                on: Hyprsunset.active
                tint: root.inked(IrisStyle.identity.orange)
                onToggled: Hyprsunset.toggle()
            }
            Toggle {
                visible: root.shows("awake")
                glyph: "coffee"
                label: Translation.tr("Keep awake")
                on: Idle.inhibit
                tint: root.inked(IrisStyle.identity.yellow)
                onToggled: Idle.toggleInhibit()
            }
            Toggle {
                visible: root.shows("gameMode")
                glyph: "sports_esports"
                label: Translation.tr("Game mode")
                on: GameMode.active
                tint: root.inked(IrisStyle.identity.green)
                onToggled: GameMode.toggle()
            }
            Toggle {
                visible: root.shows("mic")
                glyph: Audio.micMuted ? "mic_off" : "mic"
                label: Translation.tr("Microphone")
                on: Audio.source !== null && !Audio.micMuted
                available: Audio.source !== null
                tint: root.inked(IrisStyle.identity.orange)
                onToggled: Audio.toggleMicMute()
            }
            Toggle {
                visible: root.shows("darkMode")
                glyph: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                label: Translation.tr("Dark mode")
                on: Appearance.m3colors.darkmode
                tint: root.inked(IrisStyle.identity.indigo)
                onToggled: Appearance.toggleDarkMode()
            }
        }

        IrisCapsuleSlider {
            visible: !root.small && root.sliders
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            muted: Audio.sink?.audio?.muted ?? false
            icon: muted ? "volume_off" : (Audio.value ?? 0) < 0.34 ? "volume_mute" : (Audio.value ?? 0) < 0.67 ? "volume_down" : "volume_up"
            value: Math.min(1, Audio.value ?? 0)
            // the level wears the person's accent, as the discs that are on do (Apple); Nothing keeps its ink
            fillColor: IrisStyle.wearsNothing(root) ? IrisStyle.text : IrisStyle.appleAccentFill
            inkOnFill: IrisStyle.wearsNothing(root) ? IrisStyle.surface : IrisStyle.appleInkOnAccentFill
            Accessible.name: Translation.tr("Volume")
            onMoved: next => Audio.setSinkVolume(next)
            onIconClicked: Audio.toggleMute()
        }
        IrisCapsuleSlider {
            visible: root.large && root.monitor !== null && root.sliders
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            icon: "light_mode"
            value: root.monitor?.brightness ?? 0
            fillColor: IrisStyle.wearsNothing(root) ? IrisStyle.text : IrisStyle.appleAccentFill
            inkOnFill: IrisStyle.wearsNothing(root) ? IrisStyle.surface : IrisStyle.appleInkOnAccentFill
            Accessible.name: Translation.tr("Brightness")
            onMoved: next => root.monitor?.setBrightness(next)
        }

        Item { Layout.fillHeight: root.large; visible: root.large }
    }
}
