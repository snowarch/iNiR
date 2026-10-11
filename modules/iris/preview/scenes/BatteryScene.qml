pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// The battery as the warnings read it: a charge falling past the low and critical marks you set, the limit it charges to,
// and where suspend steps in.
PreviewScene {
    id: batteryRoot
    readonly property real low: Math.max(1, Number(batteryRoot.opt("battery.low", 20)))
    readonly property real critical: Math.max(1, Number(batteryRoot.opt("battery.critical", 5)))
    readonly property bool suspends: batteryRoot.opt("battery.automaticSuspend", true) === true
    readonly property real suspendAt: Number(batteryRoot.opt("battery.suspend", 3))
    readonly property bool limited: batteryRoot.opt("battery.chargeLimit.enable", false) === true
    readonly property real limit: Number(batteryRoot.opt("battery.chargeLimit.threshold", 80))
    readonly property real naturalWidth: Math.round(600 * batteryRoot.d)
    readonly property real naturalHeight: Math.round(280 * batteryRoot.d)
    property real drain: 0
    Loop on drain { running: batteryRoot.playing; rest: 1400 }
    readonly property real level: Math.round((batteryRoot.limited ? batteryRoot.limit : 100) - batteryRoot.drain * ((batteryRoot.limited ? batteryRoot.limit : 100) - batteryRoot.critical + 1))
    readonly property color state: batteryRoot.level <= batteryRoot.critical ? IrisStyle.danger
        : batteryRoot.level <= batteryRoot.low ? IrisStyle.warning : IrisStyle.success

    Plate {
        surface: "cards"
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.7)
        height: batteryColumn.implicitHeight + Math.round(36 * batteryRoot.d)
        radius: IrisStyle.radiusPlate
        ColumnLayout {
            id: batteryColumn
            x: Math.round(20 * batteryRoot.d)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * x
            spacing: Math.round(16 * batteryRoot.d)
            RowLayout {
                spacing: Math.round(14 * batteryRoot.d)
                IrisBatteryMark {
                    markHeight: Math.round(30 * batteryRoot.d)
                    level: batteryRoot.level / 100
                    tint: batteryRoot.state
                }
                IrisText {
                    text: batteryRoot.level + "%"
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: IrisStyle.typeDisplay
                    font.weight: IrisStyle.weight(Font.Bold)
                    color: batteryRoot.state
                }
            }
            // The scale of 0–100 with the marks the warnings sit on.
            Item {
                Layout.fillWidth: true
                implicitHeight: Math.round(30 * batteryRoot.d)
                Rectangle {
                    id: track
                    width: parent.width
                    height: Math.round(6 * batteryRoot.d)
                    radius: height / 2
                    color: IrisStyle.trackOf(batteryRoot.state)
                    Rectangle {
                        width: Math.round(track.width * batteryRoot.level / 100)
                        height: parent.height
                        radius: height / 2
                        color: batteryRoot.state
                    }
                }
                Repeater {
                    model: [{ at: batteryRoot.critical, tint: IrisStyle.danger, label: Translation.tr("Critical battery") },
                        { at: batteryRoot.low, tint: IrisStyle.warning, label: Translation.tr("Low battery") },
                        { at: batteryRoot.limited ? batteryRoot.limit : -1, tint: IrisStyle.success, label: Translation.tr("Stop at") }].filter(mark => mark.at >= 0)
                    Item {
                        required property var modelData
                        x: Math.round(track.width * modelData.at / 100)
                        y: 0
                        Rectangle { x: -1; y: -Math.round(3 * batteryRoot.d); width: 2; height: Math.round(12 * batteryRoot.d); radius: 1; color: parent.modelData.tint }
                        IrisText {
                            x: -Math.round(width / 2)
                            y: Math.round(12 * batteryRoot.d)
                            text: Math.round(parent.modelData.at) + "%"
                            color: parent.modelData.tint
                            font.family: IrisStyle.fontNumbers
                            font.pixelSize: IrisStyle.typeFootnote
                        }
                    }
                }
            }
        }
    }

    Caption {
        glyph: "battery_alert"
        text: [Translation.tr("Low battery") + " " + Math.round(batteryRoot.low) + "%", Translation.tr("Critical battery") + " " + Math.round(batteryRoot.critical) + "%",
            batteryRoot.limited ? Translation.tr("Stop at") + " " + Math.round(batteryRoot.limit) + "%" : ""].filter(part => part.length > 0).join(" · ")
    }
}
