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
import qs.modules.iris.widgets

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
        style: "card", showMeta: true, rotateSeconds: 45,
        x: 100, y: 260
    })
    readonly property var rotateChoices: [
        { label: Translation.tr("15 s"), value: 15 },
        { label: Translation.tr("45 s"), value: 45 },
        { label: Translation.tr("2 min"), value: 120 },
        { label: Translation.tr("5 min"), value: 300 }
    ]

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 320)
        * root.scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round(Number(root._readConfigKey("contentHeight") ?? 92)
        * root.scaleFactor)
    irisFace: Component { IrisNewsFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    irisOptions: [
        { key: "showMeta", raw: true, label: Translation.tr("Source and time"), icon: "info", fallback: true },
        { key: "rotateSeconds", raw: true, label: Translation.tr("Change every"), fallback: 45,
            choices: root.rotateChoices }
    ]
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 72
    needsColText: true
    readonly property string tickerStyle: root._readConfigKey("style") ?? "card"
    readonly property bool instrument: root.tickerStyle === "instrument"
    readonly property bool showMeta: root._readConfigKey("showMeta") ?? true
    readonly property int rotateSeconds: {
        const value = Number(root._readConfigKey("rotateSeconds") ?? 45)
        return Number.isFinite(value) && value >= 5 ? Math.min(900, value) : 45
    }
    widgetSurfaceEnabled: !root.instrument

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
        interval: root.rotateSeconds * 1000
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
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.tickerStyle
                    model: [
                        { label: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Headlines")
                detail: root.articleCount > 0
                    ? ((root.headlineIndex % root.articleCount) + 1) + " / " + root.articleCount
                    : (NewsService.loading ? Translation.tr("Loading…") : Translation.tr("No news"))
                WidgetQuickChoices {
                    maxColumns: 5
                    isSelected: entry => entry.value === "pause" && root.rotationPaused
                    model: [
                        { value: "previous", icon: "chevron_left", tooltip: Translation.tr("Previous"), visible: root.articleCount > 1 },
                        { value: "pause", icon: root.rotationPaused ? "play_arrow" : "pause",
                            tooltip: root.rotationPaused ? Translation.tr("Resume") : Translation.tr("Pause") },
                        { value: "next", icon: "chevron_right", tooltip: Translation.tr("Next"), visible: root.articleCount > 1 },
                        { value: "refresh", icon: "refresh", tooltip: Translation.tr("Refresh"), visible: !NewsService.loading },
                        { value: "open", icon: "open_in_new", tooltip: Translation.tr("Open article"), visible: root.displayedArticle !== null }
                    ]
                    onPicked: value => {
                        if (value === "previous") root._moveHeadline(-1)
                        else if (value === "next") root._moveHeadline(1)
                        else if (value === "pause") root.rotationPaused = !root.rotationPaused
                        else if (value === "refresh") root._fetch(true)
                        else if (value === "open") root._openArticle()
                    }
                }
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "label"
                    label: Translation.tr("Source and time")
                    checked: root.showMeta
                    onToggled: root._setOutputValue("showMeta", !root.showMeta)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Change every")
                WidgetQuickChoices {
                    maxColumns: 4
                    current: root.rotateSeconds
                    model: root.rotateChoices
                    onPicked: value => root._setOutputValue("rotateSeconds", value)
                }
            }
        }
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
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
        shown: !root.irisFaced && !root.instrument && (root.backgroundOpacity > 0 || root.borderWidth > 0
            || root.effectiveBlur)
    }

    HoverHandler { id: newsHover }

    RowLayout {
        visible: !root.irisFaced
        anchors.fill: parent
        anchors.margins: Math.round(10 * root.scaleFactor)
        spacing: Math.round(9 * root.scaleFactor)

        MaterialShape {
            visible: !root.instrument
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
            visible: root.instrument
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Math.round(34 * root.scaleFactor)
            spacing: Math.round(3 * root.scaleFactor)

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.max(2, Math.round(2 * root.scaleFactor))
                Layout.preferredHeight: Math.round(28 * root.scaleFactor)
                color: root.widgetAccentVisible
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "WIRE"
                color: root.widgetInkMuted
                font.family: Appearance.font.family.monospace
                font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                font.weight: Font.DemiBold
                font.letterSpacing: Math.round(1 * root.scaleFactor)
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
                    visible: root.showMeta
                    text: root.articleMeta.length > 0
                        ? root.articleMeta : Translation.tr("News")
                    color: root.instrument ? root.widgetAccentVisible : root.widgetInkMuted
                    font.family: root.instrument ? Appearance.font.family.monospace : root.widgetBodyFamily
                    font.pixelSize: Math.round((root.instrument
                        ? Appearance.font.pixelSize.smallest : Appearance.font.pixelSize.smaller) * root.scaleFactor)
                    font.weight: root.instrument ? Font.DemiBold : Font.Normal
                    font.letterSpacing: root.instrument ? Math.round(0.8 * root.scaleFactor) : 0
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.articleCount > 1
                    text: ((root.headlineIndex % Math.max(1, root.articleCount)) + 1)
                        + "/" + root.articleCount
                    color: root.instrument ? root.widgetInkMuted : root.widgetInkSubtle
                    font.family: root.widgetNumbersFamily
                    font.pixelSize: Math.round(
                        Appearance.font.pixelSize.smallest * root.scaleFactor)
                }
            }

            StyledText {
                id: headlineText
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.displayedArticle?.title
                    ?? (!Network.online ? Network.offlineReason
                        : NewsService.loading ? Translation.tr("Loading…") : Translation.tr("No news"))
                color: root.widgetInk
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: root.widgetTitleFamily
                font.pixelSize: Math.round((root.instrument ? Appearance.font.pixelSize.normal
                    : Appearance.font.pixelSize.small * root.widgetTitleScale) * root.scaleFactor)
                font.weight: root.instrument ? Font.DemiBold : root.widgetTitleWeight
                font.letterSpacing: root.widgetTitleTracking
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
