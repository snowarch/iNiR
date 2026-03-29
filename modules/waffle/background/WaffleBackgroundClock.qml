pragma ComponentBehavior: Bound

import qs
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.waffle.looks
import qs.services

AbstractWidget {
    id: root

    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    required property string wallpaperPath

    readonly property var clockConfig: Config.options?.waffles?.background?.widgets?.clock ?? {}
    readonly property bool clockEnabled: clockConfig.enable ?? false
    readonly property string placementStrategy: clockConfig.placementStrategy ?? "leastBusy"
    readonly property string clockStyle: String(clockConfig.style ?? "hero")
    readonly property string timeFormatMode: String(clockConfig.timeFormat ?? "system")
    readonly property string dateDisplayStyle: String(clockConfig.dateStyle ?? "long")
    readonly property string colorMode: String(clockConfig.colorMode ?? "adaptive")
    readonly property bool forceCenter: GlobalStates.screenLocked && (Config.options?.lock?.centerClock ?? false)
    readonly property bool showDate: clockConfig.showDate ?? true
    readonly property bool showSeconds: clockConfig.showSeconds ?? false
    readonly property bool showShadow: clockConfig.showShadow ?? true
    readonly property bool showLockStatus: clockConfig.showLockStatus ?? true
    readonly property real dimFactor: {
        const value = Number(clockConfig.dim ?? 55)
        return Math.max(0, Math.min(1, Number.isFinite(value) ? value / 100 : 0))
    }
    readonly property string resolvedFontFamily: {
        const configured = String(clockConfig.fontFamily ?? "")
        return configured.length > 0 ? configured : "Segoe UI Variable Display"
    }
    readonly property bool animateDigits: clockConfig.digital?.animateChange ?? true
    readonly property real timeScaleFactor: {
        const configured = Number(clockConfig.timeScale ?? 100)
        return Math.max(0.65, Math.min(1.6, Number.isFinite(configured) ? configured / 100 : 1))
    }
    readonly property real dateScaleFactor: {
        const configured = Number(clockConfig.dateScale ?? 100)
        return Math.max(0.65, Math.min(1.6, Number.isFinite(configured) ? configured / 100 : 1))
    }
    readonly property real timeStyleMultiplier: clockStyle === "minimal" ? 0.72 : clockStyle === "balanced" ? 0.86 : 1.0
    readonly property real dateStyleMultiplier: clockStyle === "minimal" ? 0.82 : clockStyle === "balanced" ? 0.9 : 1.0
    readonly property int contentSpacing: Math.round((clockStyle === "minimal" ? 2 : clockStyle === "balanced" ? 4 : 6) * root.localScale)
    readonly property int dateTopMargin: Math.round((clockStyle === "hero" ? -6 : clockStyle === "balanced" ? -2 : 0) * root.localScale)
    property real targetX: Math.max(0, Math.min(Number(clockConfig.x ?? 100), scaledScreenWidth - width))
    property real targetY: Math.max(0, Math.min(Number(clockConfig.y ?? 100), scaledScreenHeight - height))
    readonly property real localScale: Math.max(0.92, Math.min(1.12, Math.min(screenWidth, screenHeight) / 1080))
    readonly property color dominantColor: _dominantColor
    readonly property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    readonly property color colText: Appearance.colors.colOnLayer0
    readonly property color clockTextColor: {
        const dark = Qt.rgba(0, 0, 0, 1)
        const accent = Looks.colors.accent
        if (colorMode === "accent")
            return ColorUtils.mix(accent, dark, Math.min(1, dimFactor * 0.7))
        if (colorMode === "plain")
            return ColorUtils.mix(colText, dark, dimFactor)

        const onBlurredLock = GlobalStates.screenLocked && (Config.options?.lock?.blur?.enable ?? false)
        const adaptiveBase = onBlurredLock ? colText : ColorUtils.mix(colText, accent, dominantColorIsDark ? 0.22 : 0.12)
        return ColorUtils.mix(adaptiveBase, dark, dimFactor)
    }
    readonly property int timePixelSize: Math.round(96 * Looks.fontScale * localScale * timeStyleMultiplier * timeScaleFactor)
    readonly property int datePixelSize: Math.round(26 * Looks.fontScale * localScale * dateStyleMultiplier * dateScaleFactor)
    readonly property int statusPixelSize: Math.round((clockStyle === "minimal" ? 14 : 16) * Looks.fontScale * localScale)
    readonly property string timeText: Qt.locale().toString(displayClock.date, root.resolveTimePattern())
    readonly property string dateText: Qt.locale().toString(displayClock.date, root.resolveDatePattern())

    property color _dominantColor: Looks.colors.accent

    function resolveTimePattern(): string {
        if (timeFormatMode === "24h")
            return showSeconds ? "HH:mm:ss" : "HH:mm"
        if (timeFormatMode === "12h")
            return showSeconds ? "hh:mm:ss AP" : "hh:mm AP"

        const configured = String(Config.options?.time?.format ?? "hh:mm")
        if (!showSeconds)
            return configured
        if (configured.indexOf("s") >= 0)
            return configured
        if (configured.indexOf("H") >= 0)
            return "HH:mm:ss"
        return configured.indexOf("AP") >= 0 || configured.indexOf("ap") >= 0 ? "hh:mm:ss AP" : "hh:mm:ss"
    }

    function resolveDatePattern(): string {
        if (dateDisplayStyle === "weekday")
            return "dddd"
        if (dateDisplayStyle === "numeric")
            return Config.options?.time?.shortDateFormat ?? "dd/MM"
        if (dateDisplayStyle === "minimal")
            return "ddd, d MMM"
        return Config.options?.time?.dateFormat ?? "dddd, dd/MM"
    }

    implicitWidth: contentColumn.implicitWidth
    implicitHeight: contentColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight
    draggable: placementStrategy === "free" && !GlobalStates.screenLocked && !GlobalStates.overviewOpen
    visible: opacity > 0
    opacity: clockEnabled ? 1 : 0
    enabled: clockEnabled && !GlobalStates.screenLocked && !GlobalStates.overviewOpen

    Binding {
        target: root
        property: "x"
        value: root.targetX
        when: root.placementStrategy !== "free" && !root.forceCenter
    }
    Binding {
        target: root
        property: "y"
        value: root.targetY
        when: root.placementStrategy !== "free" && !root.forceCenter
    }
    Binding {
        target: root
        property: "x"
        value: (root.screenWidth - root.width) / 2
        when: root.forceCenter
    }
    Binding {
        target: root
        property: "y"
        value: (root.screenHeight - root.height) / 2
        when: root.forceCenter
    }

    onReleased: {
        if (GlobalStates.screenLocked || placementStrategy !== "free")
            return
        root.targetX = root.x
        root.targetY = root.y
        Config.setNestedValue("waffles.background.widgets.clock.x", Math.round(root.x))
        Config.setNestedValue("waffles.background.widgets.clock.y", Math.round(root.y))
    }

    function syncFreePositionFromConfig(): void {
        if (!Config.ready || placementStrategy !== "free" || forceCenter)
            return
        root.targetX = Math.max(0, Math.min(Number(clockConfig.x ?? 100), scaledScreenWidth - width))
        root.targetY = Math.max(0, Math.min(Number(clockConfig.y ?? 100), scaledScreenHeight - height))
        root.x = root.targetX
        root.y = root.targetY
    }

    function refreshPlacementIfNeeded(): void {
        if (!Config.ready || !clockEnabled || placementStrategy === "free" || forceCenter || !wallpaperPath || wallpaperPath.length === 0)
            return
        leastBusyRegionProc.running = false
        leastBusyRegionProc.running = true
    }

    onWallpaperPathChanged: refreshPlacementIfNeeded()
    onPlacementStrategyChanged: {
        syncFreePositionFromConfig()
        refreshPlacementIfNeeded()
    }
    onWidthChanged: refreshPlacementIfNeeded()
    onHeightChanged: refreshPlacementIfNeeded()
    onClockEnabledChanged: {
        syncFreePositionFromConfig()
        refreshPlacementIfNeeded()
    }

    Connections {
        target: Config
        function onReadyChanged() {
            root.syncFreePositionFromConfig()
            root.refreshPlacementIfNeeded()
        }
    }

    SystemClock {
        id: displayClock
        precision: root.showSeconds || GlobalStates.screenLocked ? SystemClock.Seconds : SystemClock.Minutes
    }

    Process {
        id: leastBusyRegionProc
        property int contentWidth: Math.max(260, Math.round(root.width))
        property int contentHeight: Math.max(180, Math.round(root.height))
        property int horizontalPadding: Math.max(90, Math.round(root.screenWidth * 0.08))
        property int verticalPadding: Math.max(90, Math.round(root.screenHeight * 0.08))
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh"),
            "--screen-width", Math.round(root.scaledScreenWidth),
            "--screen-height", Math.round(root.scaledScreenHeight),
            "--width", contentWidth,
            "--height", contentHeight,
            "--horizontal-padding", horizontalPadding,
            "--vertical-padding", verticalPadding,
            root.wallpaperPath,
            ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text
                if (!output || output.length === 0)
                    return
                const parsedContent = JSON.parse(output)
                root._dominantColor = parsedContent.dominant_color || Looks.colors.accent
                root.targetX = parsedContent.center_x * root.wallpaperScale - root.width / 2
                root.targetY = parsedContent.center_y * root.wallpaperScale - root.height / 2
            }
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.centerIn: parent
        spacing: root.contentSpacing

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.timeText
            animateChange: root.animateDigits
            color: root.clockTextColor
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.showShadow ? Appearance.colors.colShadow : "transparent"
            font {
                family: root.resolvedFontFamily
                pixelSize: root.timePixelSize
                weight: root.clockStyle === "minimal" ? Font.Medium : Font.DemiBold
            }
        }

        StyledText {
            visible: root.showDate
            Layout.fillWidth: true
            Layout.topMargin: root.dateTopMargin
            horizontalAlignment: Text.AlignHCenter
            text: root.dateText
            animateChange: root.animateDigits
            color: root.clockTextColor
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.showShadow ? Appearance.colors.colShadow : "transparent"
            font {
                family: root.resolvedFontFamily
                pixelSize: root.datePixelSize
                weight: Font.Normal
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showLockStatus && GlobalStates.screenLocked && (Config.options?.lock?.showLockedText ?? false)
            spacing: 6

            MaterialSymbol {
                iconSize: root.statusPixelSize + 2
                text: "lock"
                color: root.clockTextColor
                style: root.showShadow ? Text.Raised : Text.Normal
                styleColor: root.showShadow ? Appearance.colors.colShadow : "transparent"
            }

            StyledText {
                text: Translation.tr("Locked")
                color: root.clockTextColor
                style: root.showShadow ? Text.Raised : Text.Normal
                styleColor: root.showShadow ? Appearance.colors.colShadow : "transparent"
                font {
                    family: root.resolvedFontFamily
                    pixelSize: root.statusPixelSize
                    weight: Font.Normal
                }
            }
        }
    }
}
