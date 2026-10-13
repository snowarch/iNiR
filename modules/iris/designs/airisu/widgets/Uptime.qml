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
                    size: root.px(root.small ? 44 : 52)
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
    Column {
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
