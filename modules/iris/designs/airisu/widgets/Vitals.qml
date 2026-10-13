pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.iris.style
import "../components"

// AIRISU's vitals: a lacquer case holding one tier per reading Settings watches, in Settings' order (below). Nothing
// else: no grid, no scale, no trace.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property var channels: Array.from(root.widget?._resourceModel ?? [])
    readonly property bool small: root.face?.small ?? false
    readonly property bool large: root.face?.large ?? false
    function dp(value: real): real { return root.face ? root.face.dp(value) : Math.round(value) }
    function px(value: real): real { return root.face ? root.face.px(value) : Math.round(value) }

    function level(key: string): real {
        return Math.max(0, Math.min(1, Number(root.widget?._getValue(key)) || 0))
    }
    function figure(key: string): string {
        return String(root.widget?._getDisplayText(key) ?? "").replace(/[%°C]/g, "").trim()
    }
    // A degree alone shrinks to a dot at a unit's size; with its scale it reads as one.
    function unit(key: string): string { return key === "temp" || key === "gpuTemp" ? "°C" : "%" }
    function label(channel: var): string {
        return channel.key === "temp" ? Translation.tr("CPU heat") : channel.key === "gpuTemp" ? Translation.tr("GPU heat")
            : String(channel.label ?? "")
    }
    // A tier's fill: the widget's accent (Settings › Widgets › Tint) for every reading, told apart by name and place
    // rather than by hue; one past 85 % fills in the caution pigment.
    function seed(key: string): color {
        return root.level(key) >= 0.85 ? Airisu.pigment("caution") : root.face?.accent ?? Airisu.pigment("energy")
    }

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "energy"
    }

    AText {
        visible: root.channels.length === 0
        anchors.centerIn: parent
        size: IrisStyle.typeLabel
        color: stock.inkSecond
        text: Translation.tr("Choose what to watch")
    }

    readonly property int pad: root.dp(root.small ? 8 : 10)
    readonly property int gap: root.dp(4)
    // The readings are the tiers of a jūbako, stacked in the case: each a drawer sunk into the lacquer and filled with
    // its pigment as far as the reading goes, the fill's edge cut at the die's 45°. Its name and figure lie over both
    // coats in whichever ink reads on both, so a reading is told by how much of its tier is coloured before it is read.
    Column {
        id: stripes
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        spacing: root.gap
        readonly property real each: root.channels.length > 0
            ? Math.floor((root.height - 2 * root.pad - (root.channels.length - 1) * root.gap) / root.channels.length) : 0
        Repeater {
            model: root.channels
            Item {
                id: stripe
                required property var modelData
                required property int index
                readonly property string key: String(stripe.modelData.key)
                readonly property real value: root.level(stripe.key)
                readonly property bool hot: stripe.value >= 0.85
                readonly property color sunk: ColorUtils.mix(stock.lacquer, Airisu.base, 0.62) // iris-literal: a drawer, a shade deeper than its case
                readonly property color fill: stripe.hot ? Airisu.vivid(Airisu.pigment("caution")) : Airisu.vivid(root.seed(stripe.key))
                // Each word takes the ink of the coat under it, measured at its middle height since the fill's edge leans
                // 45°; a word the edge crosses takes the ink that reads on both.
                function inkAt(x0: real, x1: real): color {
                    const edge = stripe.value * (stripe.width + stripe.height) - stripe.height / 2
                    return edge >= x1 ? Airisu.inkOver(stripe.fill, stripe.fill)
                        : edge <= x0 ? Airisu.inkOver(stripe.sunk, stripe.sunk) : Airisu.inkOver(stripe.sunk, stripe.fill)
                }
                width: stripes.width
                height: stripes.each
                ALacquer {
                    anchors.fill: parent
                    cut: Math.min(Airisu.chamfer, Math.round(stripe.height / 4))
                    cutTopRight: stripe.index === 0
                    cutBottomLeft: stripe.index === root.channels.length - 1
                    lacquer: stripe.sunk
                    coat: stripe.fill
                    share: stripe.value
                    travel: Airisu.snap
                    moving: root.face?.moving ?? false
                }
                AText {
                    id: name
                    x: root.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, stripe.width * 0.5)
                    size: root.px(root.small ? IrisStyle.typeCaption : IrisStyle.typeLabel)
                    font.weight: Font.Bold
                    color: stripe.inkAt(name.x, name.x + name.width)
                    text: root.label(stripe.modelData)
                }
                Row {
                    id: reading
                    anchors.right: parent.right
                    anchors.rightMargin: root.dp(10)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.dp(2)
                    AText {
                        id: value
                        voice: "figure"
                        lean: Airisu.lean
                        size: Math.max(IrisStyle.typeLabel, Math.min(root.px(root.large ? 40 : 30), Math.round(stripe.height * 0.62)))
                        color: stripe.inkAt(reading.x, reading.x + reading.width)
                        text: root.figure(stripe.key)
                    }
                    AText {
                        y: Math.round(value.baselineOffset - baselineOffset)
                        size: Math.max(IrisStyle.typeCaption, Math.round(value.size * 0.4))
                        font.weight: Font.Bold
                        color: stripe.inkAt(reading.x, reading.x + reading.width)
                        text: root.unit(stripe.key)
                    }
                }
            }
        }
    }
}
