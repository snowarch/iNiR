import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's Japanese type: a vertical bill (縦書き). The words stand in a column of heavy kanji, read from the top; the
// reading or the line beside them runs down a narrower column in the second ink; the seal's words are stamped in a
// square of shu at the foot like a hanko, its kanji cut out in the seal's ink; the footer and the dates lie along the
// foot in the data face over a rule. The engine's widget keeps the words and their options.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property string primary: String(root.widget?.primaryText ?? "")
    readonly property string secondary: String(root.widget?.secondaryText ?? "")
    readonly property string seal: String(root.widget?.sealText ?? "")
    readonly property real foot: (root.widget?.showFooter ?? true) ? root.dp(30) : 0
    readonly property real room: root.height - 2 * root.pad - root.foot
    readonly property real glyph: Math.max(12, Math.min(root.px(root.small ? 34 : 52), root.room / Math.max(1, root.primary.length)))
    readonly property string jp: "Noto Sans CJK JP"

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }
    Column {
        id: words
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.pad
        Repeater {
            model: root.primary.split("")
            Text {
                required property string modelData
                width: root.glyph * 1.1
                height: root.glyph * 1.02
                horizontalAlignment: Text.AlignHCenter
                font.family: root.jp
                font.weight: Font.Black
                font.pixelSize: root.glyph
                color: stock.ink
                text: modelData
            }
        }
    }
    Column {
        visible: (root.widget?.showSecondary ?? true) && !root.small
        anchors.right: words.left
        anchors.rightMargin: root.dp(8)
        y: root.pad + root.dp(4)
        Repeater {
            model: root.secondary.split("").slice(0, Math.floor(root.room / root.px(16)))
            Text {
                required property string modelData
                width: root.px(16)
                height: root.px(16)
                horizontalAlignment: Text.AlignHCenter
                font.family: root.jp
                font.weight: Font.Medium
                font.pixelSize: root.px(13)
                color: stock.inkSecond
                text: modelData
            }
        }
    }
    // The hanko.
    Rectangle {
        visible: (root.widget?.showSeal ?? true) && root.seal.length > 0
        x: root.pad
        y: root.pad + root.room - height
        width: Math.round(root.px(root.small ? 34 : 44))
        height: Math.max(width, sealWords.implicitHeight + root.dp(8))
        color: Airisu.seal
        antialiasing: false
        Column {
            id: sealWords
            anchors.centerIn: parent
            Repeater {
                model: root.seal.split("").slice(0, 4)
                Text {
                    required property string modelData
                    width: root.px(root.small ? 16 : 20)
                    horizontalAlignment: Text.AlignHCenter
                    font.family: root.jp
                    font.weight: Font.Black
                    font.pixelSize: root.px(root.small ? 14 : 18)
                    color: Airisu.inkOnSeal
                    text: modelData
                }
            }
        }
    }
    Column {
        visible: root.foot > 0
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        spacing: root.dp(3)
        Rectangle { width: parent.width; height: Airisu.hair; color: stock.inkThird; antialiasing: false }
        Item {
            width: parent.width
            height: footer.height
            AText {
                id: footer
                width: parent.width - dates.width - root.dp(6)
                voice: "mono"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: String(root.widget?.footerText ?? "")
            }
            AText {
                id: dates
                anchors.right: parent.right
                voice: "data"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: String(root.widget?.dateText ?? "")
            }
        }
    }
}
