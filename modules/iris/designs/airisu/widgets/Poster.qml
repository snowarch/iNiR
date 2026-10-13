import QtQuick
import qs.modules.iris.style
import "../components"

// AIRISU's editorial widget: a printed bill. Poster sets the caption as a ruby in the data face's capitals, the title as
// the hero in the figure voice, and the footer in the data face over a heavy rule; Quote sets the title in the text face
// between Japanese corner quotes 「」, the marks a Japanese page quotes with; Label runs a bar of the seal down its side
// and sets everything small, as a label is. The engine's widget keeps the words.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(16)
    readonly property string composition: String(root.widget?.composition ?? "poster")
    function said(key: string, fallback: string): string { return String(root.widget?._readConfigKey(key) ?? fallback) }

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }
    Rectangle {
        visible: root.composition === "label"
        x: root.pad
        y: root.pad
        width: Math.max(2, root.dp(4))
        height: root.height - 2 * root.pad
        color: Airisu.seal
        antialiasing: false
    }
    Column {
        x: root.composition === "label" ? root.pad + root.dp(14) : root.pad
        y: root.pad
        width: root.width - x - root.pad
        spacing: root.dp(4)
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.said("caption", "A LITTLE EVERY DAY")
        }
        AText {
            width: parent.width
            // As large as the room between the caption and the foot allows, never over the foot.
            height: root.height - 2 * root.pad - root.dp(60)
            fontSizeMode: Text.Fit
            minimumPixelSize: IrisStyle.typeLabel
            verticalAlignment: Text.AlignTop
            voice: root.composition === "poster" ? "figure" : "text"
            size: root.composition === "poster" ? root.px(34) : root.composition === "quote" ? root.px(24) : IrisStyle.typeHeadline
            font.weight: root.composition === "quote" ? Font.Medium : Font.ExtraBold
            wrapMode: Text.Wrap
            maximumLineCount: 5
            lineHeight: 0.95
            color: stock.ink
            text: root.composition === "quote" ? "「" + root.said("title", "Make room for wonder.") + "」" : root.said("title", "Make room for wonder.")
        }
    }
    Column {
        x: root.composition === "label" ? root.pad + root.dp(14) : root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - x - root.pad
        spacing: root.dp(4)
        Rectangle { width: parent.width; height: Airisu.strong; color: stock.ink; antialiasing: false }
        AText {
            width: parent.width
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.said("footer", "YOUR OWN PERSPECTIVE")
        }
    }
}
