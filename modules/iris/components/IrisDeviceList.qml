pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

ColumnLayout {
    id: root

    property bool outputs: true
    property bool inputs: true
    readonly property bool headings: root.outputs && root.inputs
    readonly property real d: IrisStyle.density
    spacing: 2 * root.d

    Repeater {
        model: [
            { input: false, title: Translation.tr("Output"), devices: Audio.outputDevices },
            { input: true, title: Translation.tr("Input"), devices: Audio.inputDevices }
        ].filter(group => group.input ? root.inputs : root.outputs)
        ColumnLayout {
            id: deviceGroup
            required property var modelData
            Layout.fillWidth: true
            spacing: 2 * root.d
            IrisText {
                visible: root.headings
                Layout.leftMargin: 10 * root.d
                Layout.topMargin: 4 * root.d
                text: deviceGroup.modelData.title
                role: IrisText.Meta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            Repeater {
                model: deviceGroup.modelData.devices
                IrisButton {
                    id: deviceRow
                    required property var modelData
                    readonly property bool input: deviceGroup.modelData.input
                    readonly property bool current: (deviceRow.input ? Audio.source?.id : Audio.defaultSink?.id) === modelData.id
                    Layout.fillWidth: true
                    quiet: true
                    implicitHeight: Math.round(36 * root.d)
                    buttonRadius: IrisStyle.radiusTile
                    onClicked: {
                        if (deviceRow.input) Audio.setDefaultSource(deviceRow.modelData)
                        else Audio.setDefaultSink(deviceRow.modelData)
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10 * root.d
                        anchors.rightMargin: 10 * root.d
                        spacing: 10 * root.d
                        MaterialSymbol {
                            text: deviceRow.input ? "mic"
                                : /head|bluez|airpod|buds/i.test(String(deviceRow.modelData.name ?? "") + String(deviceRow.modelData.description ?? "")) ? "headphones" : "speaker"
                            iconSize: Math.round(18 * root.d)
                            color: deviceRow.current ? IrisStyle.accent : IrisStyle.subtext
                        }
                        IrisText {
                            Layout.fillWidth: true
                            text: Audio.friendlyDeviceName(deviceRow.modelData)
                            elide: Text.ElideRight
                            font.pixelSize: IrisStyle.typeLabel
                        }
                        MaterialSymbol {
                            visible: deviceRow.current
                            text: "check"
                            iconSize: Math.round(18 * root.d)
                            color: IrisStyle.accent
                        }
                    }
                }
            }
        }
    }
}
