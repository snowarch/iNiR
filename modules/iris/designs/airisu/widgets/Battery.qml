pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's batteries: a meter for each thing that runs on one. The first (this computer, or what is there) is the hero:
// its name as a ruby in the data face's capitals, its charge as the figure leaning, how long it has as data, and a
// ladder of steps for the charge; the others are rows of the same ladder, smaller. A low charge prints its ladder's
// lit steps in yamabuki (caution), charging marks its sign with a bolt; nothing else takes colour. The engine's face keeps
// the devices.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var devices: root.face?.devices ?? []
    readonly property var lead: root.devices[0] ?? null
    readonly property var rest: root.devices.slice(1, root.small ? 1 : 4)

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "energy"
    }
    component Meter: ASteps {
        property var device
        rising: false
        zoned: false
        value: Number(device?.level ?? 0)
        ink: device?.low && !device?.charging ? Airisu.tape : stock.ink
    }
    Column {
        visible: root.lead !== null
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.dp(2)
        Row {
            spacing: root.dp(4)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: (root.lead?.charging ?? false) ? "bolt" : (root.lead?.glyph ?? "battery_full")
                iconSize: root.px(14)
                fill: 1
                color: stock.inkSecond
            }
            AText {
                anchors.verticalCenter: parent.verticalCenter
                voice: "mono"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: String(root.lead?.name ?? "")
            }
        }
        Row {
            spacing: root.dp(2)
            AText {
                id: figure
                voice: "figure"
                lean: Airisu.lean
                size: root.px(root.small ? 44 : 52)
                color: stock.ink
                text: Math.round(Number(root.lead?.level ?? 0) * 100)
            }
            AText {
                anchors.baseline: figure.baseline
                voice: "data"
                size: IrisStyle.typeLabel
                color: stock.inkSecond
                text: "%"
            }
        }
        AText {
            width: parent.width
            visible: text.length > 0
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: String(root.widget?.timeLabel ?? "").length > 0 ? root.widget.timeLabel
                : (root.lead?.charging ?? false) ? Translation.tr("Charging") : ""
        }
    }
    Meter {
        x: root.pad
        width: root.width - 2 * root.pad
        height: root.dp(12)
        anchors.bottom: others.top
        anchors.bottomMargin: root.dp(8)
        device: root.lead
    }
    Column {
        id: others
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        spacing: root.dp(4)
        Repeater {
            model: root.rest
            Item {
                id: row
                required property var modelData
                width: parent.width
                height: root.dp(16)
                MaterialSymbol {
                    id: sign
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.charging ? "bolt" : row.modelData.glyph
                    iconSize: root.px(13)
                    color: stock.inkSecond
                }
                Meter {
                    x: sign.width + root.dp(6)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - level.width - root.dp(6)
                    height: root.dp(8)
                    device: row.modelData
                }
                AText {
                    id: level
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: stock.ink
                    text: Math.round(Number(row.modelData.level ?? 0) * 100) + "%"
                }
            }
        }
    }
}
