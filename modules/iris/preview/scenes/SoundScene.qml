pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Sound as the Island's card holds it: where sound goes and what hears you, each with its level, and the apps playing
// now. Only what PipeWire has: a machine without speakers says so, as the page under it does, instead of a made-up
// "Speakers 60 %" over "No speakers or headphones found". The group being read lights its part.
PreviewScene {
    id: soundRoot
    readonly property real naturalWidth: Math.round(460 * soundRoot.d)
    readonly property real naturalHeight: Math.round(300 * soundRoot.d)
    narrowest: Math.round(340 * soundRoot.d)
    lowest: Math.round(230 * soundRoot.d)
    readonly property bool compact: soundRoot.preview.compact ?? false
    // Output, Input or Apps: the part the group under the pointer (or being read) changes.
    readonly property string focusPart: ({ "Output": "output", "Volume": "output", "Input": "input", "Apps playing": "apps" })[soundRoot.group] ?? ""
    function lit(part: string): real { return soundRoot.focusPart.length === 0 || soundRoot.focusPart === part ? 1 : 0.4 }

    readonly property var apps: (Audio.outputAppNodes ?? []).slice(0, 2).map(node => ({
        name: Audio.appNodeDisplayName(node), icon: MprisController.streamIconSource(node, "audio-x-generic"), glyph: "",
        level: Math.min(1, node?.audio?.volume ?? 0) }))
    // The apps that fit whole under the devices: a frame lower than the card drops a row instead of cutting the plate.
    readonly property real appRowHeight: Math.round(22 * soundRoot.d) + soundColumn.spacing
    readonly property int appsFit: Math.max(0, Math.min(2, Math.floor((soundRoot.height - soundPlate.y - outputDevice.height
        - inputDevice.height - 3 * soundColumn.spacing - 1 - Math.round(36 * soundRoot.d)) / soundRoot.appRowHeight)))
    readonly property var shownApps: soundRoot.apps.slice(0, soundRoot.appsFit)

    IslandPill { id: soundIsland; anchors.horizontalCenter: parent.horizontalCenter; y: IrisFrame.band }
    Plate {
        id: soundPlate
        surface: "cards"
        own: IrisStyle.identity.purple
        anchors.horizontalCenter: parent.horizontalCenter
        y: soundIsland.y + soundIsland.height + IrisStyle.weld
        width: Math.min(Math.round(400 * soundRoot.d), soundRoot.width - Math.round(32 * soundRoot.d))
        height: soundColumn.implicitHeight + Math.round(28 * soundRoot.d)
        radius: IrisStyle.radiusPlate
        ColumnLayout {
            id: soundColumn
            x: Math.round(14 * soundRoot.d); y: Math.round(14 * soundRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(10 * soundRoot.d)
            Device {
                id: outputDevice
                glyph: /head|bluez|airpod|buds/i.test(String(Audio.sink?.name ?? "") + String(Audio.sink?.description ?? "")) ? "headphones" : "speaker"
                present: !!Audio.sink
                name: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("No speakers or headphones found.")
                level: Audio.sink ? Math.min(1, Audio.value) : 0
                opacity: soundRoot.lit("output")
            }
            Device {
                id: inputDevice
                glyph: Audio.micMuted ? "mic_off" : "mic"
                present: !!Audio.source
                name: Audio.source ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("No microphone found.")
                level: Audio.source ? Math.min(1, Audio.micVolume) : 0
                opacity: soundRoot.lit("input")
            }
            Rectangle { visible: soundRoot.appsFit > 0; Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }
            IrisText {
                visible: soundRoot.appsFit > 0 && soundRoot.apps.length === 0
                Layout.fillWidth: true
                opacity: soundRoot.lit("apps")
                role: IrisText.Detail
                text: Translation.tr("Nothing playing")
            }
            Repeater {
                model: soundRoot.shownApps
                RowLayout {
                    id: appRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Math.round(10 * soundRoot.d)
                    opacity: soundRoot.lit("apps")
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    Item {
                        implicitWidth: Math.round(22 * soundRoot.d)
                        implicitHeight: implicitWidth
                        IrisImage {
                            anchors.fill: parent
                            visible: appRow.modelData.icon.length > 0
                            source: appRow.modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: appRow.modelData.icon.length === 0
                            text: appRow.modelData.glyph
                            fill: 1
                            iconSize: Math.round(18 * soundRoot.d)
                            color: IrisStyle.textSecondary
                        }
                    }
                    IrisText {
                        Layout.preferredWidth: Math.round(96 * soundRoot.d)
                        text: appRow.modelData.name
                        elide: Text.ElideRight
                    }
                    Level { value: appRow.modelData.level; tint: IrisStyle.text }
                }
            }
        }
    }
    component Device: ColumnLayout {
        id: device
        property string glyph: ""
        property string name: ""
        property real level: 0
        property bool present: true
        Layout.fillWidth: true
        spacing: Math.round(6 * soundRoot.d)
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * soundRoot.d)
            MaterialSymbol { text: device.glyph; fill: device.present ? 1 : 0; iconSize: Math.round(18 * soundRoot.d); color: device.present ? IrisStyle.text : IrisStyle.muted }
            IrisText { Layout.fillWidth: true; text: device.name; role: device.present ? IrisText.Name : IrisText.Detail; elide: Text.ElideRight }
            IrisText { visible: device.present; text: Math.round(device.level * 100) + " %"; role: IrisText.Value; tone: IrisStyle.accent }
        }
        Level { visible: device.present; value: device.level; tint: IrisStyle.accent }
    }
    Caption {
        glyph: "graphic_eq"
        text: [outputDevice.name, soundRoot.apps.length > 0 ? soundRoot.apps.map(app => app.name).join(", ") : Translation.tr("Nothing playing")].join(" · ")
    }
}
