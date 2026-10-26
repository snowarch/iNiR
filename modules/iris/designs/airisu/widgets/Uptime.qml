import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's uptime widget: a spec sheet (仕様書) for this session. The name as a ruby in the data face's capitals over the
// session's length as the hero figure (each unit set small after its number, as a plate's figures are), then the facts
// as rows of a sheet parted by hairlines, each in the data face. The engine's face keeps the data and the stock.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var parts: root.face?.parts ?? []
    readonly property var rows: [
        (root.widget?.showSince ?? true) ? Translation.tr("Since %1").arg(root.widget?.bootLabel ?? "") : "",
        (root.widget?.showBreakdown ?? true) && (root.widget?.sessionDay ?? 0) > 1 ? Translation.tr("Day %1 of this session").arg(root.widget.sessionDay) : ""
    ].filter(row => row.length > 0)
    // Large: the session day by day (the last week of it at most), each day's share of 24 h it ran: the first from boot,
    // the last up to now.
    readonly property var days: {
        const boot = root.widget?.bootDate
        if (root.small || !boot) return []
        const now = DateTime.clock.date
        const out = []
        const day = new Date(boot.getFullYear(), boot.getMonth(), boot.getDate())
        while (day <= now) {
            const next = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
            const from = Math.max(day.getTime(), boot.getTime())
            const to = Math.min(next.getTime(), now.getTime())
            out.push({ name: Translation.locale.toString(day, "ddd"), share: Math.max(0, to - from) / 86400000, today: next > now })
            day.setDate(day.getDate() + 1)
        }
        return out.slice(-7)
    }

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
        text: Translation.tr("Uptime")
    }
    Row {
        id: figures
        x: root.pad
        y: root.pad + root.dp(18)
        spacing: root.dp(6)
        Repeater {
            model: root.parts
            Row {
                required property var modelData
                spacing: root.dp(2)
                AText {
                    id: value
                    voice: "figure"
                    lean: Airisu.lean
                    size: root.px(root.small ? 44 : 64)
                    color: stock.ink
                    text: modelData.value
                }
                AText {
                    anchors.baseline: value.baseline
                    voice: "data"
                    size: IrisStyle.typeLabel
                    color: stock.inkSecond
                    text: modelData.unit
                }
            }
        }
    }
    // Each day a ruled column filled from the foot for the hours it ran; today's in the vivid ink, its weekday under it.
    Row {
        id: strip
        visible: root.days.length > 0 && strip.height >= root.dp(56)
        x: root.pad
        y: figures.y + figures.height + root.dp(20)
        width: root.width - 2 * root.pad
        height: Math.max(0, facts.y - y - root.dp(16))
        spacing: root.dp(6)
        Repeater {
            model: root.days
            Item {
                id: dayColumn
                required property var modelData
                width: (strip.width - (root.days.length - 1) * strip.spacing) / root.days.length
                height: strip.height
                Item {
                    id: well
                    width: parent.width
                    height: parent.height - dayName.height - root.dp(6)
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: Airisu.hair
                        border.color: stock.inkThird
                        antialiasing: false
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.round(parent.height * dayColumn.modelData.share)
                        color: dayColumn.modelData.today ? stock.vivid : Qt.alpha(stock.inkThird, 0.4)
                        antialiasing: false
                    }
                }
                AText {
                    id: dayName
                    anchors.bottom: parent.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    voice: "mono"
                    size: IrisStyle.typeCaption
                    color: dayColumn.modelData.today ? stock.ink : stock.inkSecond
                    text: dayColumn.modelData.name
                }
            }
        }
    }
    Column {
        id: facts
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        Repeater {
            model: root.rows
            Item {
                required property string modelData
                width: parent.width
                height: line.height + root.dp(8)
                Rectangle { width: parent.width; height: Airisu.hair; color: stock.inkThird; antialiasing: false }
                AText {
                    id: line
                    y: root.dp(4)
                    width: parent.width
                    voice: "data"
                    size: IrisStyle.typeCaption
                    color: stock.inkSecond
                    text: modelData
                }
            }
        }
    }
}
