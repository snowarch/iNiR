pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Battery: a charge running down. It warns at the low mark and again at the critical one, sleeps where it is set to;
// plugged in, a limited charge stops at its mark.
PreviewScene {
    id: batteryRoot
    readonly property real naturalWidth: Math.round(560 * batteryRoot.d)
    readonly property real naturalHeight: Math.round(280 * batteryRoot.d)
    narrowest: Math.round(380 * batteryRoot.d)
    lowest: Math.round(220 * batteryRoot.d)
    subject: Qt.rect(cell.x, cell.y, cell.width, cell.height)
    readonly property real low: Number(batteryRoot.opt("battery.low", 20)) / 100
    readonly property real critical: Number(batteryRoot.opt("battery.critical", 5)) / 100
    readonly property bool sleeps: batteryRoot.opt("battery.automaticSuspend", true) === true
    readonly property real sleepAt: Number(batteryRoot.opt("battery.suspend", 3)) / 100
    readonly property bool limited: batteryRoot.opt("battery.chargeLimit.enable", false) === true
    readonly property real limit: Number(batteryRoot.opt("battery.chargeLimit.threshold", 80)) / 100
    readonly property real ceiling: batteryRoot.limited ? batteryRoot.limit : 1
    property real t: 1
    Loop on t { running: batteryRoot.playing; rest: 1200 }
    // t falls: it drains; t rises: it charges back up to the top it may reach.
    readonly property real level: Math.max(batteryRoot.sleeps ? batteryRoot.sleepAt : 0.01, 0.02 + (batteryRoot.ceiling - 0.02) * batteryRoot.t)
    readonly property string alarm: batteryRoot.sleeps && batteryRoot.level <= batteryRoot.sleepAt + 0.005 ? "sleep"
        : batteryRoot.level <= batteryRoot.critical ? "critical" : batteryRoot.level <= batteryRoot.low ? "low" : ""

    Item {
        id: cell
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(54 * batteryRoot.d)
        width: Math.round(Math.min(batteryRoot.width * 0.72, 380 * batteryRoot.d))
        height: Math.round(92 * batteryRoot.d)
        Rectangle {
            id: shell
            width: parent.width - Math.round(12 * batteryRoot.d)
            height: parent.height
            radius: Math.round(22 * batteryRoot.d)
            color: IrisStyle.bodySurface
            border.width: Math.max(2, Math.round(2 * batteryRoot.d))
            border.color: IrisStyle.border
            Rectangle {
                id: charge
                x: Math.round(7 * batteryRoot.d); y: x
                height: parent.height - 2 * x
                width: (parent.width - 2 * x) * batteryRoot.level
                radius: Math.round(16 * batteryRoot.d)
                color: batteryRoot.alarm === "critical" || batteryRoot.alarm === "sleep" ? IrisStyle.danger
                    : batteryRoot.alarm === "low" ? IrisStyle.identity.orange : IrisStyle.identity.green
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
            }
            // The marks: low, critical, sleep, and the charge limit.
            Repeater {
                model: [{ at: batteryRoot.low, ink: IrisStyle.identity.orange, on: true },
                    { at: batteryRoot.critical, ink: IrisStyle.danger, on: true },
                    { at: batteryRoot.limit, ink: IrisStyle.identity.green, on: batteryRoot.limited }]
                Rectangle {
                    required property var modelData
                    visible: modelData.on
                    x: Math.round(7 * batteryRoot.d) + (shell.width - Math.round(14 * batteryRoot.d)) * modelData.at - width / 2
                    y: -Math.round(8 * batteryRoot.d)
                    width: Math.max(2, Math.round(2 * batteryRoot.d))
                    height: shell.height + Math.round(16 * batteryRoot.d)
                    radius: width / 2
                    color: modelData.ink
                    opacity: 0.85
                }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: batteryRoot.alarm === "sleep" ? "bedtime" : "bolt"
                fill: 1
                iconSize: Math.round(30 * batteryRoot.d)
                color: IrisStyle.text
                opacity: batteryRoot.alarm === "sleep" ? 1 : 0.2
            }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(8 * batteryRoot.d)
            height: Math.round(32 * batteryRoot.d)
            radius: Math.round(3 * batteryRoot.d)
            color: IrisStyle.border
        }
    }
    // The warning as it would show.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: cell.y + cell.height + Math.round(26 * batteryRoot.d)
        width: warnRow.implicitWidth + Math.round(30 * batteryRoot.d)
        height: Math.round(36 * batteryRoot.d)
        radius: height / 2
        color: IrisStyle.veilHeavy
        opacity: batteryRoot.alarm.length > 0 ? 1 : 0
        scale: batteryRoot.alarm.length > 0 ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        RowLayout {
            id: warnRow
            anchors.centerIn: parent
            spacing: Math.round(8 * batteryRoot.d)
            MaterialSymbol {
                text: batteryRoot.alarm === "sleep" ? "bedtime" : "battery_alert"
                fill: 1
                iconSize: Math.round(17 * batteryRoot.d)
                color: batteryRoot.alarm === "low" ? IrisStyle.identity.orange : IrisStyle.danger
            }
            IrisText {
                text: batteryRoot.alarm === "sleep" ? Translation.tr("Going to sleep") : batteryRoot.alarm === "critical" ? Translation.tr("Battery critical") : Translation.tr("Battery low")
                color: IrisStyle.onMedia
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }
    Caption {
        glyph: batteryRoot.limited ? "battery_saver" : "battery_full"
        text: [batteryRoot.sleeps ? Translation.tr("Sleeps when almost empty") : Translation.tr("Never sleeps on its own"),
            batteryRoot.limited ? Translation.tr("charge limited") : ""].filter(part => part.length > 0).join(" · ")
    }
}
