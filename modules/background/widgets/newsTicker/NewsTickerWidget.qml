pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

// Compact desktop headline surface backed by the shared NewsService. Articles
// only open from an explicit action, never from an incidental card click.
AbstractBackgroundWidget {
    id: root

    configEntryName: "newsTicker"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 320, contentHeight: 92,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 100, y: 260
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 320)
        * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 92)
        * root.scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 72
    needsColText: true

    property int headlineIndex: 0
    property var displayedArticle: null
    property bool rotationPaused: false
    readonly property int articleCount: NewsService.articles.length
    readonly property var article: root.articleCount > 0
        ? NewsService.articles[root.headlineIndex % root.articleCount] : null
    readonly property string articleMeta: root.displayedArticle
        ? [root.displayedArticle.source,
            NewsService.formatTime(root.displayedArticle.timestamp)]
            .filter(value => value && value.length > 0).join(" • ")
        : ""

    function _fetch(force: bool): void {
        const mode = Config.options?.sidebar?.news?.mode ?? "local"
        const topic = Config.options?.sidebar?.news?.topic ?? "WORLD"
        if (force)
            NewsService.refresh(mode, topic)
        else
            NewsService.fetch(mode, topic)
    }

    function _moveHeadline(direction: int): void {
        if (root.articleCount <= 0)
            return
        root.headlineIndex = (root.headlineIndex + direction
            + root.articleCount) % root.articleCount
    }

    function _openArticle(): void {
        if (root.displayedArticle)
            NewsService.openArticle(root.displayedArticle)
    }

    onArticleChanged: {
        if (!root.displayedArticle || !Appearance.animationsEnabled) {
            root.displayedArticle = root.article
            headlineText.opacity = 1
            return
        }
        headlineText.opacity = 0
        swapTimer.restart()
    }

    Connections {
        target: NewsService
        function onArticlesChanged(): void {
            if (root.articleCount <= 0) {
                root.headlineIndex = 0
                root.displayedArticle = null
                return
            }
            root.headlineIndex = Math.min(root.headlineIndex,
                root.articleCount - 1)
            if (!root.displayedArticle)
                root.displayedArticle = root.article
        }
    }

    Component.onCompleted: {
        root.displayedArticle = root.article
        root._fetch(false)
    }

    Timer {
        interval: 12000
        repeat: true
        running: root.visible && root.powerActive && !root.rotationPaused
            && root.articleCount > 1
        onTriggered: root._moveHeadline(1)
    }

    Timer {
        id: swapTimer
        interval: Math.max(1, Appearance.animation.elementMoveFast.duration)
        onTriggered: {
            root.displayedArticle = root.article
            headlineText.opacity = 1
        }
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                SelectionGroupButton {
                    width: 34; height: 32
                    horizontalPadding: 7
                    verticalPadding: 5
                    leftmost: true; rightmost: true
                    enabled: root.articleCount > 1
                    buttonIcon: "chevron_left"
                    onClicked: root._moveHeadline(-1)
                    StyledToolTip { text: Translation.tr("Previous") }
                }
                SelectionGroupButton {
                    height: 32
                    horizontalPadding: 9
                    verticalPadding: 5
                    leftmost: true; rightmost: true
                    toggled: root.rotationPaused
                    buttonIcon: root.rotationPaused ? "play_arrow" : "pause"
                    buttonText: root.rotationPaused
                        ? Translation.tr("Resume") : Translation.tr("Pause")
                    onClicked: root.rotationPaused = !root.rotationPaused
                }
                SelectionGroupButton {
                    width: 34; height: 32
                    horizontalPadding: 7
                    verticalPadding: 5
                    leftmost: true; rightmost: true
                    enabled: root.articleCount > 1
                    buttonIcon: "chevron_right"
                    onClicked: root._moveHeadline(1)
                    StyledToolTip { text: Translation.tr("Next") }
                }
                SelectionGroupButton {
                    width: 34; height: 32
                    horizontalPadding: 7
                    verticalPadding: 5
                    leftmost: true; rightmost: true
                    enabled: !NewsService.loading
                    buttonIcon: "refresh"
                    onClicked: root._fetch(true)
                    StyledToolTip { text: Translation.tr("Refresh") }
                }
                SelectionGroupButton {
                    width: 34; height: 32
                    horizontalPadding: 7
                    verticalPadding: 5
                    leftmost: true; rightmost: true
                    enabled: root.displayedArticle !== null
                    buttonIcon: "open_in_new"
                    onClicked: root._openArticle()
                    StyledToolTip { text: Translation.tr("Open article") }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 240
                horizontalAlignment: Text.AlignHCenter
                text: root.articleCount > 0
                    ? ((root.headlineIndex % root.articleCount) + 1) + " / "
                        + root.articleCount + (root.articleMeta.length > 0
                            ? " · " + root.articleMeta : "")
                    : (NewsService.loading
                        ? Translation.tr("Loading…") : Translation.tr("No news"))
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.NoWrap
                elide: Text.ElideMiddle
            }
        }
    }

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0
            || root.effectiveBlur
    }

    HoverHandler { id: newsHover }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(10 * root.scaleFactor)
        spacing: Math.round(9 * root.scaleFactor)

        MaterialShape {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: Math.round(32 * root.scaleFactor)
            shape: MaterialShape.Shape.Cookie4Sided
            color: ColorUtils.applyAlpha(root.widgetAccent, 0.15)

            MaterialSymbol {
                anchors.centerIn: parent
                text: "newspaper"
                iconSize: Math.round(17 * root.scaleFactor)
                color: root.widgetAccentVisible
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Math.round(2 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                StyledText {
                    Layout.fillWidth: true
                    text: root.articleMeta.length > 0
                        ? root.articleMeta : Translation.tr("News")
                    color: root.widgetInkMuted
                    font.pixelSize: Math.round(
                        Appearance.font.pixelSize.smaller * root.scaleFactor)
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.articleCount > 1
                    text: ((root.headlineIndex % Math.max(1, root.articleCount)) + 1)
                        + "/" + root.articleCount
                    color: root.widgetInkSubtle
                    font.family: Appearance.font.family.numbers
                    font.pixelSize: Math.round(
                        Appearance.font.pixelSize.smallest * root.scaleFactor)
                }
            }

            StyledText {
                id: headlineText
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.displayedArticle?.title
                    ?? (NewsService.loading
                        ? Translation.tr("Loading…") : Translation.tr("No news"))
                color: root.widgetInk
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.pixelSize: Math.round(
                    Appearance.font.pixelSize.small * root.scaleFactor)
                font.weight: Font.DemiBold
                opacity: 1
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            width: Math.round(32 * root.scaleFactor)
            height: width
            enabled: root.displayedArticle !== null && !GlobalStates.widgetEditMode
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.applyAlpha(root.widgetAccent, 0.08)
            colBackgroundHover: ColorUtils.applyAlpha(root.widgetAccent, 0.18)
            colRipple: ColorUtils.applyAlpha(root.widgetAccent, 0.24)
            opacity: newsHover.hovered ? 1 : 0.58
            downAction: root._openArticle

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "open_in_new"
                iconSize: Math.round(17 * root.scaleFactor)
                color: root.widgetAccentVisible
            }
            StyledToolTip { text: Translation.tr("Open article") }
        }
    }
}
