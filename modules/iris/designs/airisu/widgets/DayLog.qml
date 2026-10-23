pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's screen time: a day's log (日報). The day's total as the hero figure leaning, then the twenty-four hours as a
// row of bars as tall as each hour's use, the hour that is now in the seal (the only shu on it), with 0, 6, 12, 18 under
// them in the data face; given room, the apps that took the day as rows of a sheet, each with its share as a run. Off,
// it says what it would show and offers the key that turns it on. The engine's face keeps the log.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    readonly property bool large: root.face?.large ?? false
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property bool on: root.face?.on ?? false
    readonly property var hourly: root.face?.hourly ?? []
    readonly property real peak: Number(root.face?.hourPeak ?? 900)
    readonly property int hourNow: Number(root.face?.hourNow ?? 0)
    readonly property var apps: root.face?.topApps ?? []
    // On, but under a minute today: the day is said in words instead of a 0m over an empty axis.
    readonly property bool idle: root.on && (root.face?.idle ?? false)
    readonly property bool logging: root.on && !root.idle

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "system"
    }
    AText {
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        voice: "mono"
        size: IrisStyle.typeCaption
        color: stock.inkSecond
        text: Translation.tr("Screen Time")
    }

    // Off.
    Column {
        visible: !root.on
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        spacing: root.dp(8)
        AText {
            width: parent.width
            size: IrisStyle.typeLabel
            font.weight: Font.Bold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            color: stock.ink
            text: Translation.tr("See where your day goes")
        }
        Item {
            width: Math.min(parent.width, word.implicitWidth + root.dp(24))
            height: root.dp(28)
            AKey {
                id: plate
                anchors.fill: parent
                lacquer: Airisu.seal
                hovered: hover.hovered
                pressed: tap.pressed
            }
            AText {
                id: word
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: plate.shift
                anchors.verticalCenterOffset: plate.shift
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: Airisu.inkOnSeal
                text: Translation.tr("Turn on")
            }
            Accessible.role: Accessible.Button
            Accessible.name: word.text
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: tap; onTapped: Config.setNestedValue("sidebar.screenTime.enable", true) }
        }
    }

    // On.
    ABlank {
        visible: root.idle
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        face: root.face
        stock: stock
        label: Translation.tr("Nothing yet today")
        line: Translation.tr("Your hours show up here as you use the computer")
    }
    AText {
        id: total
        visible: root.logging
        x: root.pad
        y: root.pad + root.dp(16)
        voice: "figure"
        lean: Airisu.lean
        size: root.px(root.small ? 30 : 40)
        color: stock.ink
        text: root.face ? root.face.shortDuration(Number(root.face.total ?? 0)) : ""
    }
    Item {
        id: log
        visible: root.logging
        x: root.pad
        y: total.y + total.height + root.dp(8)
        width: (root.large ? root.width : root.small ? root.width : Math.round(root.width * 0.55)) - 2 * root.pad
        height: (root.large ? Math.round(root.height * 0.4) : root.height - (total.y + total.height + root.dp(8))) - root.pad
        readonly property real pitch: log.width / 24
        Repeater {
            model: 24
            Rectangle {
                required property int index
                readonly property real share: Math.min(1, Number(root.hourly[index] ?? 0) / Math.max(1, root.peak))
                x: Math.round(index * log.pitch)
                width: Math.max(1, Math.round(log.pitch) - Math.max(1, root.dp(2)))
                height: Math.max(1, Math.round((log.height - hours.height - root.dp(4)) * share))
                y: log.height - hours.height - root.dp(4) - height
                color: index === root.hourNow ? Airisu.seal : share > 0 ? stock.ink : Airisu.slot
                antialiasing: false
            }
        }
        Item {
            id: hours
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.dp(12)
            Repeater {
                model: [0, 6, 12, 18]
                AText {
                    required property int modelData
                    x: Math.round(modelData * log.pitch)
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: stock.inkThird
                    text: modelData
                }
            }
        }
    }
    Column {
        visible: root.logging && !root.small && root.apps.length > 0
        x: root.large ? root.pad : log.x + log.width + root.dp(12)
        y: root.large ? log.y + log.height + root.dp(10) : root.pad + root.dp(16)
        width: root.large ? root.width - 2 * root.pad : root.width - x - root.pad
        spacing: root.dp(4)
        Repeater {
            model: root.apps
            Column {
                id: app
                required property var modelData
                width: parent.width
                spacing: root.dp(2)
                Item {
                    width: parent.width
                    height: name.height
                    AText {
                        id: name
                        width: parent.width - span.width - root.dp(6)
                        size: IrisStyle.typeFootnote
                        font.weight: Font.Bold
                        color: stock.ink
                        text: String(app.modelData.name ?? "")
                    }
                    AText {
                        id: span
                        anchors.right: parent.right
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkSecond
                        text: root.face ? root.face.shortDuration(Number(app.modelData.seconds ?? 0)) : ""
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(2, root.dp(3))
                    color: Airisu.slot
                    antialiasing: false
                    Rectangle {
                        width: parent.width * Math.min(1, Number(app.modelData.seconds ?? 0) / Math.max(1, Number(root.apps[0]?.seconds ?? 1)))
                        height: parent.height
                        color: stock.ink
                        antialiasing: false
                    }
                }
            }
        }
    }
}
