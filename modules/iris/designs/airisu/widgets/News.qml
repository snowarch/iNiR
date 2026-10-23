pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.services.deferred
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's news: a newspaper's front page set in columns. The masthead is a ruby in the data face's capitals over a
// heavy rule; each story stands in its own column parted by a hairline: its paper and age in the data face, its headline
// in the text face, as many lines as the column holds. A tap on a story opens it. The engine's face keeps the stories.
Item {
    id: root
    property var face
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property var stories: root.face?.stories ?? []
    readonly property int columns: Math.max(1, Math.min(root.stories.length, root.small ? 1 : 2))

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "message"
    }
    Item {
        id: mast
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        height: root.dp(18)
        AText {
            anchors.verticalCenter: parent.verticalCenter
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: Translation.tr("News")
        }
        AText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !Network.online && root.stories.length > 0
            voice: "data"
            size: IrisStyle.typeCaption
            color: Airisu.caution
            text: Translation.tr("Offline")
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Airisu.strong
            color: stock.ink
            antialiasing: false
        }
    }
    ABlank {
        readonly property bool offline: !Network.online
        readonly property bool failed: !offline && NewsService.lastError.length > 0 && !NewsService.loading
        visible: root.stories.length === 0
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        face: root.face
        stock: stock
        label: offline ? Translation.tr("Offline") : failed ? Translation.tr("Headlines didn't load") : Translation.tr("Fetching headlines…")
        line: offline ? Network.offlineReason : failed ? Translation.tr("The feed did not answer") : ""
        action: failed ? Translation.tr("Try again") : ""
        onActivated: root.face?.widget._fetch(true)
    }
    Grid {
        id: page
        x: root.pad
        y: mast.y + mast.height + root.dp(8)
        width: root.width - 2 * root.pad
        height: root.height - y - root.pad
        columns: root.columns
        readonly property real column: page.width / root.columns
        readonly property int rows: Math.max(1, Math.ceil(root.stories.length / root.columns))
        Repeater {
            model: root.stories
            Item {
                id: story
                required property var modelData
                required property int index
                width: page.column
                height: page.height / page.rows
                Rectangle {
                    visible: story.index % root.columns > 0
                    width: Airisu.hair
                    height: parent.height
                    color: stock.inkThird
                    antialiasing: false
                }
                Column {
                    x: story.index % root.columns > 0 ? root.dp(10) : 0
                    width: parent.width - x - (story.index % root.columns < root.columns - 1 ? root.dp(10) : 0)
                    height: parent.height
                    spacing: root.dp(3)
                    AText {
                        width: parent.width
                        voice: "data"
                        size: IrisStyle.typeCaption
                        color: stock.inkThird
                        text: [String(story.modelData.source ?? ""), NewsService.formatTime(story.modelData.timestamp)].filter(t => t.length > 0).join(" · ")
                    }
                    AText {
                        width: parent.width
                        size: root.small ? IrisStyle.typeLabel : IrisStyle.typeHeadline
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: Math.max(1, Math.floor((parent.height - root.dp(20)) / (font.pixelSize * 1.25)))
                        lineHeight: 1.05
                        color: stock.ink
                        font.underline: hover.hovered
                        text: String(story.modelData.title ?? "")
                    }
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: NewsService.openArticle(story.modelData) }
            }
        }
    }
}
