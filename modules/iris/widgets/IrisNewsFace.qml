pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.services.deferred
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property int capacity: root.small ? 1 : root.medium ? 2 : 4
    readonly property var stories: {
        const all = Array.from(NewsService.articles ?? [])
        if (all.length === 0)
            return []
        const start = root.widget.headlineIndex % all.length
        return all.slice(start).concat(all.slice(0, start)).slice(0, root.capacity)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.dp(10)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "newspaper"
            text: Translation.tr("News")
            trailing: !Network.online && root.stories.length > 0 ? Translation.tr("Offline") : ""
            tint: root.accent
        }

        FaceText {
            face: root
            visible: root.stories.length === 0
            Layout.fillWidth: true
            text: !Network.online ? Network.offlineReason
                : NewsService.lastError.length > 0 && !NewsService.loading ? Translation.tr("Headlines didn't load (´・ω・`)")
                : Translation.tr("Fetching headlines…")
            color: root.inkTertiary
            size: 12.5
        }

        GridLayout {
            id: storyGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.medium ? 2 : 1
            columnSpacing: root.dp(20)
            rowSpacing: root.dp(10)
            readonly property real share: (storyGrid.height - storyGrid.rowSpacing * Math.max(0, root.stories.length - 1))
                / Math.max(1, root.stories.length + 1)

            Repeater {
                model: root.stories
                ColumnLayout {
                    id: story
                    required property var modelData
                    required property int index
                    readonly property bool lead: story.index === 0
                    readonly property bool fills: true
                    readonly property real band: storyGrid.share * (story.lead ? 2 : 1)
                    Layout.fillWidth: true
                    Layout.fillHeight: !root.large
                    Layout.minimumHeight: 0
                    Layout.preferredHeight: root.large ? story.band : -1
                    Layout.maximumHeight: root.large ? story.band : Number.POSITIVE_INFINITY
                    Layout.preferredWidth: root.medium ? (story.lead ? 3 : 2) : 1
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    clip: true
                    spacing: root.dp(4)

                    Rectangle {
                        visible: !story.lead && root.large
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.bottomMargin: root.dp(2)
                        color: root.hairline
                    }
                    RowLayout {
                        visible: root.widget.showMeta || storyHover.hovered
                        Layout.fillWidth: true
                        spacing: root.dp(6)
                        FaceText {
                            face: root
                            visible: root.widget.showMeta
                            Layout.fillWidth: true
                            text: String(story.modelData.source ?? "")
                            color: story.lead ? root.accent : root.inkSecondary
                            size: 10.5
                            weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: !root.widget.showMeta }
                        FaceText {
                            face: root
                            visible: root.widget.showMeta
                            text: NewsService.formatTime(story.modelData.timestamp)
                            color: root.inkTertiary
                            size: 10
                        }
                        MaterialSymbol {
                            visible: storyHover.hovered
                            text: "open_in_new"
                            iconSize: root.px(14)
                            color: openHover.hovered ? root.accent : root.inkTertiary
                            HoverHandler { id: openHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: NewsService.openArticle(story.modelData)
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr("Open article")
                        }
                    }
                    FaceText {
                        id: title
                        face: root
                        Layout.fillWidth: true
                        Layout.fillHeight: story.fills
                        Layout.minimumHeight: 0
                        Layout.preferredHeight: story.fills ? 0 : -1
                        text: String(story.modelData.title ?? "")
                        size: story.lead ? (root.small ? 16.5 : root.medium ? 15.5 : 20) : 13
                        font.family: story.lead ? IrisStyle.fontTitle : root.fontMain
                        weight: story.lead ? Font.Bold : Font.Medium
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignTop
                        lineHeight: 1.08
                        maximumLineCount: !story.lead ? 2 : root.small ? 4 : root.medium ? 5 : 3
                        color: openHover.hovered ? root.accent : root.ink
                    }
                    HoverHandler { id: storyHover }
                }
            }
        }
    }
}
