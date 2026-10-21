pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Sound › Apps playing: every app sending sound now, by its own icon and name, with its own volume and mute.
// The level shown is the stream's, so another mixer moving it moves the row too; a drag writes once a frame at most.
ColumnLayout {
    id: root

    property var spec: ({})
    readonly property real d: IrisStyle.settingsDensity
    readonly property var streams: Audio.outputAppNodes.filter(node => node?.audio)

    spacing: 0

    IrisText {
        visible: root.streams.length === 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(48 * root.d)
        verticalAlignment: Text.AlignVCenter
        text: Translation.tr("No app is playing sound.")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeBody
    }

    Repeater {
        // A stream coming or going keeps the other rows (a plain array rebuilt every delegate).
        model: ScriptModel { values: root.streams }
        Item {
            id: stream
            required property var modelData
            required property int index
            readonly property bool muted: stream.modelData?.audio?.muted ?? false
            readonly property real level: Number(stream.modelData?.audio?.volume ?? 0) || 0
            property real pending: -1
            Layout.fillWidth: true
            implicitHeight: Math.round(56 * root.d)

            Timer {
                id: flush
                interval: 16
                onTriggered: {
                    if (stream.pending >= 0 && stream.modelData?.audio) stream.modelData.audio.volume = stream.pending
                    stream.pending = -1
                }
            }

            IrisImage {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(32 * root.d)
                height: width
                source: stream.modelData ? MprisController.streamIconSource(stream.modelData, "audio-x-generic") : ""
                fillMode: Image.PreserveAspectFit
                opacity: stream.muted ? 0.45 : 1
            }
            IrisText {
                anchors.left: mark.right
                anchors.leftMargin: Math.round(12 * root.d)
                anchors.right: scrub.left
                anchors.rightMargin: Math.round(16 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                text: stream.modelData ? Audio.appNodeDisplayName(stream.modelData) : ""
                font.pixelSize: IrisStyle.typeBody
                elide: Text.ElideRight
            }
            IrisScrubber {
                id: scrub
                anchors.right: readout.left
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(260 * root.d)
                knob: true
                fillColor: stream.muted ? IrisStyle.muted : IrisStyle.accent
                value: Math.min(1, stream.level)
                Accessible.name: stream.modelData ? Audio.appNodeDisplayName(stream.modelData) : ""
                onMoved: next => { stream.pending = next; if (!flush.running) flush.start() }
            }
            IrisText {
                id: readout
                anchors.right: muteButton.left
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(52 * root.d)
                horizontalAlignment: Text.AlignRight
                text: Math.round(stream.level * 100) + " %"
                font.pixelSize: IrisStyle.typeBody
                font.weight: IrisStyle.weight(Font.DemiBold)
                font.features: { "tnum": 1 }
            }
            IrisIconButton {
                id: muteButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                materialIcon: stream.muted ? "volume_off" : "volume_up"
                selected: stream.muted
                Accessible.name: Translation.tr("Mute")
                onClicked: if (stream.modelData?.audio) stream.modelData.audio.muted = !stream.muted
            }
            Rectangle {
                visible: stream.index < root.streams.length - 1
                anchors.left: parent.left
                anchors.leftMargin: mark.width + Math.round(12 * root.d)
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: IrisStyle.hairline
            }
        }
    }
}
