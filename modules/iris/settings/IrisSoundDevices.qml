pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Sound › Output or Input (spec.input): every device by its name, the one in use checked, a click to move
// the sound there, and the volume of the one in use under them. The output volume goes through Audio.setSinkVolume,
// so ear protection holds here like everywhere else.
ColumnLayout {
    id: root

    property var spec: ({})
    readonly property bool input: root.spec?.input === true
    readonly property real d: IrisStyle.settingsDensity
    readonly property var devices: root.input ? Audio.inputDevices : Audio.outputDevices
    readonly property var current: root.input ? Audio.source : Audio.defaultSink
    readonly property bool muted: root.input ? Audio.micMuted : (Audio.sink?.audio?.muted ?? false)
    readonly property real level: root.input ? Audio.micVolume : Audio.value

    // A drag writes once a frame at most; the level shown is PipeWire's, so another mixer moves it too.
    property real pending: -1
    Timer {
        id: flush
        interval: 16
        onTriggered: {
            if (root.pending >= 0) root.input ? Audio.setSourceVolume(root.pending) : Audio.setSinkVolume(root.pending)
            root.pending = -1
        }
    }

    spacing: 0

    Repeater {
        model: ScriptModel { values: root.devices }
        IrisButton {
            id: deviceRow
            required property var modelData
            readonly property bool chosen: root.current?.id === deviceRow.modelData?.id
            Layout.fillWidth: true
            implicitHeight: Math.round(48 * root.d)
            quiet: true
            buttonRadius: IrisStyle.radiusTile
            Accessible.name: Audio.friendlyDeviceName(deviceRow.modelData)
            onClicked: root.input ? Audio.setDefaultSource(deviceRow.modelData) : Audio.setDefaultSink(deviceRow.modelData)
            RowLayout {
                anchors.fill: parent
                spacing: Math.round(12 * root.d)
                MaterialSymbol {
                    Layout.preferredWidth: Math.round(24 * root.d)
                    horizontalAlignment: Text.AlignHCenter
                    text: root.input ? "mic"
                        : /head|bluez|airpod|buds/i.test(String(deviceRow.modelData?.name ?? "") + String(deviceRow.modelData?.description ?? "")) ? "headphones" : "speaker"
                    iconSize: Math.round(20 * root.d)
                    color: deviceRow.chosen ? IrisStyle.accent : IrisStyle.muted
                }
                IrisText {
                    Layout.fillWidth: true
                    text: Audio.friendlyDeviceName(deviceRow.modelData)
                    font.pixelSize: IrisStyle.typeBody
                    elide: Text.ElideRight
                }
                MaterialSymbol {
                    visible: deviceRow.chosen
                    text: "check"
                    iconSize: Math.round(20 * root.d)
                    color: IrisStyle.accent
                }
            }
        }
    }

    IrisText {
        visible: root.devices.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(48 * root.d)
        verticalAlignment: Text.AlignVCenter
        text: root.input ? Translation.tr("No microphone found.") : Translation.tr("No speakers or headphones found.")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeBody
    }

    Rectangle {
        visible: root.current !== null
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(36 * root.d)
        implicitHeight: 1
        color: IrisStyle.hairline
    }

    RowLayout {
        visible: root.current !== null
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(52 * root.d)
        spacing: Math.round(12 * root.d)
        IrisText {
            Layout.leftMargin: Math.round(36 * root.d)
            text: Translation.tr("Volume")
            font.pixelSize: IrisStyle.typeBody
        }
        Item { Layout.fillWidth: true }
        IrisScrubber {
            Layout.preferredWidth: Math.round(260 * root.d)
            knob: true
            stepSize: 0.05
            fillColor: root.muted ? IrisStyle.muted : IrisStyle.accent
            value: Math.min(1, root.level)
            Accessible.name: Translation.tr("Volume")
            onMoved: next => { root.pending = next; if (!flush.running) flush.start() }
        }
        IrisText {
            Layout.preferredWidth: Math.round(52 * root.d)
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.level * 100) + " %"
            font.pixelSize: IrisStyle.typeBody
            font.weight: IrisStyle.weight(Font.DemiBold)
            font.features: { "tnum": 1 }
        }
        IrisIconButton {
            materialIcon: root.input ? (root.muted ? "mic_off" : "mic") : (root.muted ? "volume_off" : "volume_up")
            selected: root.muted
            Accessible.name: Translation.tr("Mute")
            onClicked: root.input ? Audio.toggleMicMute() : Audio.toggleMute()
        }
    }
}
