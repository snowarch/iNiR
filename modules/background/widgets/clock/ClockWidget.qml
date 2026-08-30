import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "clock"
    defaultConfig: ({
        placementStrategy: "free", style: "digital",
        fontFamily: "Space Grotesk", timeFormat: "system",
        showSeconds: false, showDate: true, dateStyle: "long",
        timeScale: 100, dateScale: 100, showShadow: true, dim: 70,
        "digital.adaptToWallpaper": true,
        "digital.animateChange": true, "digital.fontWeight": 600,
        "digital.spacing": 6, "digital.preset": "default",
        "cookie.aiStyling": false, "cookie.constantlyRotate": false,
        "cookie.dateInClock": true, "cookie.dateStyle": "bubble",
        "cookie.dialNumberStyle": "full", "cookie.hourHandStyle": "hollow",
        "cookie.hourMarks": false, "cookie.minuteHandStyle": "hide",
        "cookie.secondHandStyle": "hide", "cookie.sides": 15,
        "cookie.timeIndicators": false, "cookie.useSineCookie": false,
        "cookie.size": 230, "cookie.preset": "default",
        "quote.enable": false, "quote.text": "",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: false, useBlur: false, showBorder: false,
        backgroundOpacity: 0, borderWidth: 0, borderOpacity: 0.08,
        cornerRadius: -1, x: 100, y: 100
    })

    readonly property real activeClockWidth: root.clockStyle === "cookie"
        ? cookieClockLoader.width
        : root.clockStyle === "androidStacked"
            ? androidStackedClockLoader.width : digitalClockLoader.width
    readonly property real activeClockHeight: root.clockStyle === "cookie"
        ? cookieClockLoader.height
        : root.clockStyle === "androidStacked"
            ? androidStackedClockLoader.height : digitalClockLoader.height
    readonly property bool statusShown: root.wallpaperSafetyTriggered
        || (GlobalStates.screenLocked && (Config.options?.lock?.showLockedText ?? false))
    implicitHeight: root.activeClockHeight
        + (root.statusShown ? contentColumn.spacing + statusText.implicitHeight : 0)
    implicitWidth: Math.max(root.activeClockWidth,
        root.statusShown ? statusText.implicitWidth : 0)
    // Digital mode resizes via timeScale, cookie via cookie.size — avoids scaleFactor churn
    resizableAxes: root.clockStyle === "cookie" ? ({ uniform: "cookie.size" }) : ({ uniform: "timeScale" })
    resizeMinWidth: root.clockStyle === "cookie" ? 120 : 80
    resizeMinHeight: root.clockStyle === "cookie" ? 120
        : root.clockStyle === "androidStacked" ? 80 : 40

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: "Digital", icon: "digital_out_of_home", value: "digital" },
                        { label: "Android", icon: "android", value: "androidStacked" },
                        { label: "Cookie", icon: "circle", value: "cookie" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.clockStyle === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.clock.style", modelData.value)
                    }
                }
            }
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                visible: root.textClockStyle
                Repeater {
                    model: [
                        { label: "System", icon: "settings", value: "system" },
                        { label: "24h", icon: "schedule", value: "24h" },
                        { label: "12h", icon: "nest_clock_farsight_analog", value: "12h" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.timeFormat === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.clock.timeFormat", modelData.value)
                    }
                }
            }
        }
    }

    property string clockStyle: Config.getNestedValue("background.widgets.clock.style", "digital")
    readonly property bool textClockStyle: root.clockStyle === "digital"
        || root.clockStyle === "androidStacked"
    property bool adaptDigitalToWallpaper: Config.getNestedValue("background.widgets.clock.digital.adaptToWallpaper", true)
    property bool forceCenter: (GlobalStates.screenLocked && (Config.options?.lock?.centerClock ?? false))
    property bool wallpaperSafetyTriggered: false
    property bool debugRegionActive: false
    property color debugRegionColor: "transparent"
    property real debugRegionBrightness: -1
    property real debugRegionSpread: 0
    property string cookieDiagnostics: "{}"
    needsColText: root.textClockStyle && (root.adaptDigitalToWallpaper || root.widgetHasSurface)
    liveColorTracking: root.textClockStyle && root.adaptDigitalToWallpaper && !root.widgetHasSurface
    visibleWhenLocked: true

    // --- Clock customization config ---
    property string clockFontFamily: Config.getNestedValue("background.widgets.clock.fontFamily", "Space Grotesk")
    property string timeFormat: Config.getNestedValue("background.widgets.clock.timeFormat", "system")
    property bool showSeconds: Config.getNestedValue("background.widgets.clock.showSeconds", false)
    property bool showDate: Config.getNestedValue("background.widgets.clock.showDate", true)
    property string dateStyle: Config.getNestedValue("background.widgets.clock.dateStyle", "long")
    property int timeScale: Number(root._readConfigKey("timeScale") ?? 100)
    property int dateScale: Config.getNestedValue("background.widgets.clock.dateScale", 100)
    property bool showShadow: Config.getNestedValue("background.widgets.clock.showShadow", true)
    property int digitalFontWeight: Config.getNestedValue("background.widgets.clock.digital.fontWeight", 600)
    property int digitalSpacing: Config.getNestedValue("background.widgets.clock.digital.spacing", 6)

    // ── Accent colors ── from the shared desktop-widget identity (AbstractBackgroundWidget)
    // so the clock reads as the same family as weather/sysmon/etc., wallpaper-generated.
    readonly property color accentPrimary: root.widgetAccent
    readonly property color accentSecondary: root.widgetAccent2
    readonly property color accentTertiary: root.widgetAccent3
    // One semantic palette for both renderers. Global-style dispatch already
    // happens in Appearance; ZZZ must keep its primary-container sticker face,
    // not fall back to the near-black chrome used by rectangular plates.
    readonly property color cookieFace: root.widgetSemanticContainer(root.widgetPrimaryRole)
    readonly property color cookieBaseInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
    function supportingOnFace(strongInk: color, face: color): color {
        for (let weight = 0.72; weight <= 1.001; weight += 0.04) {
            const candidate = ColorUtils.mix(strongInk, face, weight);
            if (ColorUtils.contrastRatio(candidate, face) >= 4.5)
                return candidate;
        }
        return strongInk;
    }
    // Hands use the configured semantic accents directly; the face is the matching
    // generated container, so no local hue/lightness rewrite is needed.
    readonly property color handPrimary: root.accentPrimary
    readonly property color handTertiary: root.accentTertiary
    // Marks/numbers use the strong on-face ink. Supporting information remains
    // solid (not alpha-composited) so small text keeps an AA contrast floor.
    readonly property color cookieInk: root.cookieBaseInk
    readonly property color cookieInfo: root.supportingOnFace(root.cookieInk, root.cookieFace)

    // Local clock with seconds precision when needed (and power is active)
    SystemClock {
        id: displayClock
        // Drop to minutes precision when power is reduced to save CPU
        precision: (root.showSeconds || GlobalStates.screenLocked) && root.powerActive
            ? SystemClock.Seconds : SystemClock.Minutes
    }

    // --- Resolved format patterns (reactive) ---
    property string _timePattern: {
        const fmt = root.timeFormat;
        const sec = root.showSeconds;
        if (fmt === "24h") return sec ? "HH:mm:ss" : "HH:mm";
        if (fmt === "12h") return sec ? "hh:mm:ss AP" : "hh:mm AP";
        // "system" — use global config format, smart seconds append
        const base = Config.options?.time?.format ?? "hh:mm";
        if (sec && !base.includes("s")) {
            const apIdx = base.indexOf(" AP");
            if (apIdx >= 0) return base.slice(0, apIdx) + ":ss" + base.slice(apIdx);
            return base + ":ss";
        }
        return base;
    }
    property string _datePattern: {
        const style = root.dateStyle;
        if (style === "weekday") return "dddd";
        if (style === "numeric") return Config.options?.time?.shortDateFormat ?? "dd/MM";
        if (style === "minimal") return "ddd, d MMM";
        // "long" or default
        return Config.options?.time?.dateFormat ?? "dddd, dd/MM";
    }

    property string timeText: Qt.locale().toString(displayClock.date, root._timePattern)
    property string dateText: Qt.locale().toString(displayClock.date, root._datePattern)

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

    property var textHorizontalAlignment: {
        if (root.forceCenter)
            return Text.AlignHCenter;
        if (root.x < root.scaledScreenWidth / 3)
            return Text.AlignLeft;
        if (root.x > root.scaledScreenWidth * 2 / 3)
            return Text.AlignRight;
        return Text.AlignHCenter;
    }

    // ── Style tokens ──
    readonly property real cardRadius: root.widgetCardRadius

    // What the digital text actually sits on: the card plate when one renders,
    // the analyzed wallpaper region otherwise (theme surface until the analysis
    // lands, so nothing re-tones on first paint).
    readonly property bool _digitalCard: root.textClockStyle && root.widgetHasSurface
    readonly property bool _digitalHasBrightness: root.debugRegionActive
        ? root.debugRegionBrightness >= 0 : root._hasBrightness
    readonly property color _digitalRegionColor: root.debugRegionActive
        ? root.debugRegionColor : root.dominantColor
    readonly property real _digitalRegionBrightness: root.debugRegionActive
        ? root.debugRegionBrightness : root.regionBrightness
    readonly property color _digitalRegionBg: {
        const dominant = Qt.color(root._digitalRegionColor);
        if (!root._digitalHasBrightness) return dominant;
        return Qt.hsla(dominant.hslHue, dominant.hslSaturation,
            root._digitalRegionBrightness, 1.0);
    }
    readonly property color _inkBackdrop: root._digitalCard ? root.widgetPlateColor
        : root._digitalHasBrightness ? root._digitalRegionBg
        : Appearance.colors.colLayer0
    readonly property color _digitalBackdrop: root.adaptDigitalToWallpaper
        ? root._inkBackdrop : Appearance.colors.colLayer0
    // Digital text may switch between generated tokens for contrast, but never
    // synthesizes a region-specific hue. Each line maps to one configurable slot.
    readonly property color digitalTimeColor: root.widgetSemanticForeground(
        root.widgetPrimaryRole, root._digitalBackdrop, 4.5)
    readonly property color digitalDateColor: root.widgetSemanticForeground(
        root.widgetSecondaryRole, root._digitalBackdrop, 4.5)
    readonly property color digitalMetaColor: root.widgetSemanticForeground(
        root.widgetTertiaryRole, root._digitalBackdrop, 4.5)
    readonly property color digitalStatusColor: root.widgetSemanticForeground(
        root.widgetSignalRole, root._digitalBackdrop, 4.5)

    readonly property string debugPaletteReport: JSON.stringify({
        style: root.clockStyle,
        globalStyle: Appearance.globalStyle,
        adaptive: root.adaptDigitalToWallpaper,
        appearance: {
            colorMode: root.colorMode,
            dimAmount: root.dimAmount,
            widgetOpacity: root.widgetOpacity,
            effectiveOpacity: root.opacity,
            useBlur: root.useBlur,
            blurAvailable: root.blurAvailable,
            effectiveBlur: root.effectiveBlur,
            hasSurface: root.widgetHasSurface,
            plate: String(root.widgetPlateColor),
            surfaceInk: String(root.widgetSurfaceInk),
            surface: JSON.parse(clockSurface.surfaceReport)
        },
        region: {
            injected: root.debugRegionActive,
            dominant: String(root._digitalRegionColor),
            regionBackdrop: String(root._inkBackdrop),
            displayBackdrop: String(root._digitalBackdrop),
            brightness: root._digitalRegionBrightness
        },
        cookie: {
            face: String(root.cookieFace),
            ink: String(root.cookieInk),
            info: String(root.cookieInfo),
            hourHand: String(root.handPrimary),
            minuteHand: String(root.handTertiary),
            inkContrast: ColorUtils.contrastRatio(root.cookieInk, root.cookieFace),
            infoContrast: ColorUtils.contrastRatio(root.cookieInfo, root.cookieFace),
            renderer: root.cookieDiagnostics
        },
        digital: {
            time: String(root.digitalTimeColor),
            date: String(root.digitalDateColor),
            quote: String(root.digitalMetaColor),
            status: String(root.digitalStatusColor),
            timeContrast: ColorUtils.contrastRatio(root.digitalTimeColor, root._digitalBackdrop),
            dateContrast: ColorUtils.contrastRatio(root.digitalDateColor, root._digitalBackdrop),
            quoteContrast: ColorUtils.contrastRatio(root.digitalMetaColor, root._digitalBackdrop),
            statusContrast: ColorUtils.contrastRatio(root.digitalStatusColor, root._digitalBackdrop)
        }
    })

    // Card background (mainly for digital mode)
    WidgetSurface {
        id: clockSurface
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        anchors.margins: -Math.round(8 * root.scaleFactor)
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetPlateColor
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x + Math.round(8 * root.scaleFactor)
        screenY: root.y + Math.round(8 * root.scaleFactor)
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.textClockStyle
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        spacing: Math.round(6 * root.scaleFactor)

        FadeLoader {
            id: cookieClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: root.clockStyle === "cookie"
            width: item?.desiredImplicitWidth ?? 0
            height: item?.desiredImplicitHeight ?? 0
            sourceComponent: Column {
                id: cookieColumn
                readonly property real desiredImplicitWidth: Math.max(
                    cookieClock.implicitWidth, cookieQuote.implicitWidth)
                readonly property real desiredImplicitHeight: cookieClock.implicitHeight
                    + (cookieQuote.shown ? cookieQuote.implicitHeight : 0)

                CookieClock {
                    id: cookieClock
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitSize: Math.round(Number(root._readConfigKey("cookie.size") ?? 230)
                        * root.scaleFactor)
                    scaleFactor: root.scaleFactor
                    powerActive: root.powerActive
                    colBackground: root.cookieFace
                    colOnBackground: root.cookieInk
                    colBackgroundInfo: root.cookieInfo
                    colHourHand: root.handPrimary
                    colMinuteHand: root.handTertiary
                    colSecondHand: root.cookieInk
                    onDiagnosticReportChanged: root.cookieDiagnostics = diagnosticReport
                }
                FadeLoader {
                    id: cookieQuote
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")) !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: root.clockStyle === "digital"
            width: item?.desiredImplicitWidth ?? 0
            height: item?.desiredImplicitHeight ?? 0
            sourceComponent: ColumnLayout {
                id: clockColumn
                spacing: Math.round(root.digitalSpacing * root.scaleFactor)
                readonly property real desiredImplicitWidth: Math.ceil(Math.max(
                    timeLabel.implicitWidth,
                    dateLabel.visible ? dateLabel.implicitWidth : 0,
                    quoteLabel.visible ? quoteLabel.implicitWidth : 0))
                readonly property real desiredImplicitHeight: Math.ceil(
                    timeLabel.implicitHeight
                    + (dateLabel.visible
                        ? dateLabel.implicitHeight
                            + dateLabel.Layout.topMargin + clockColumn.spacing : 0)
                    + (quoteLabel.visible
                        ? quoteLabel.implicitHeight + clockColumn.spacing : 0))

                ClockText {
                    id: timeLabel
                    color: root.digitalTimeColor
                    font.pixelSize: Math.round(90 * Appearance.fontSizeScale * root.timeScale / 100 * root.scaleFactor)
                    text: root.timeText
                }
                ClockText {
                    id: dateLabel
                    visible: root.showDate
                    color: root.digitalDateColor
                    Layout.topMargin: Math.round(-5 * root.scaleFactor)
                    font.pixelSize: Math.round(20 * root.dateScale / 100 * root.scaleFactor)
                    text: root.dateText
                }
                StyledText {
                    id: quoteLabel
                    // Somehow gets fucked up if made a ClockText???
                    visible: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")).length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: root.textHorizontalAlignment
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        weight: 350
                    }
                    color: root.digitalMetaColor
                    style: root.showShadow ? Text.Raised : Text.Normal
                    styleColor: root.colHalo
                    text: Config.getNestedValue("background.widgets.clock.quote.text", "")
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.standardDecel
                        }
                    }
                }
            }
        }

        FadeLoader {
            id: androidStackedClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: root.clockStyle === "androidStacked"
            width: item?.desiredImplicitWidth ?? 0
            height: item?.desiredImplicitHeight ?? 0
            sourceComponent: AndroidStackedClock {
                currentDate: displayClock.date
                timeText: root.timeText
                timeColor: root.digitalTimeColor
                dateColor: root.digitalDateColor
                haloColor: root.colHalo
                fontFamily: root.clockFontFamily
                scaleFactor: root.scaleFactor
                timeScale: root.timeScale / 100
                dateScale: root.dateScale / 100
                showDate: root.showDate
                showShadow: root.showShadow
                animateChange: Config.getNestedValue("background.widgets.clock.digital.animateChange", false)
                horizontalAlignment: root.textHorizontalAlignment
            }
        }
        Item {
            id: statusText
            x: Math.round((parent.width - width) / 2)
            visible: root.statusShown
            implicitHeight: root.statusShown ? statusTextBg.implicitHeight : 0
            implicitWidth: statusTextBg.implicitWidth
            StyledRectangularShadow {
                target: statusTextBg
                visible: statusTextBg.visible && root.clockStyle === "cookie"
                opacity: statusTextBg.opacity
            }
            Rectangle {
                id: statusTextBg
                anchors.centerIn: parent
                clip: true
                opacity: (safetyStatusText.shown || lockStatusText.shown) ? 1 : 0
                visible: opacity > 0
                implicitHeight: statusTextRow.implicitHeight + 5 * 2
                implicitWidth: statusTextRow.implicitWidth + 5 * 2
                radius: Appearance.rounding.small
                color: ColorUtils.transparentize(root.cookieFace, root.clockStyle === "cookie" ? 0 : 1)

                Behavior on implicitWidth {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on implicitHeight {
                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }
                Behavior on opacity {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                RowLayout {
                    id: statusTextRow
                    anchors.centerIn: parent
                    spacing: 14
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignLeft
                        implicitWidth: 1
                    }
                    ClockStatusText {
                        id: safetyStatusText
                        shown: root.wallpaperSafetyTriggered
                        statusIcon: "hide_image"
                        statusText: Translation.tr("Wallpaper safety enforced")
                    }
                    ClockStatusText {
                        id: lockStatusText
                        shown: GlobalStates.screenLocked && (Config.options?.lock?.showLockedText ?? false)
                        statusIcon: "lock"
                        statusText: Translation.tr("Locked")
                    }
                    Item {
                        Layout.fillWidth: root.textHorizontalAlignment !== Text.AlignRight
                        implicitWidth: 1
                    }
                }
            }
        }
    }

    component ClockText: StyledText {
        Layout.fillWidth: true
        horizontalAlignment: root.textHorizontalAlignment
        font {
            family: root.clockFontFamily
            pixelSize: 20
            weight: root.digitalFontWeight
        }
        color: root.digitalTimeColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: root.colHalo
        animateChange: Config.getNestedValue("background.widgets.clock.digital.animateChange", false)
        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.standardDecel
            }
        }
    }
    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        // Cookie status sits on the same face plate; digital status sits directly
        // on the wallpaper and therefore uses its own adapted supporting role.
        property color textColor: root.clockStyle === "cookie"
            ? root.cookieInk : root.digitalStatusColor
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        spacing: 4
        MaterialSymbol {
            id: statusIconWidget
            anchors.verticalCenter: statusTextRow.verticalCenter
            iconSize: Appearance.font.pixelSize.huge
            color: statusTextRow.textColor
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.colHalo
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.standardDecel
                }
            }
        }
        ClockText {
            id: statusTextWidget
            color: statusTextRow.textColor
            anchors.verticalCenter: statusTextRow.verticalCenter
            font {
                pixelSize: Appearance.font.pixelSize.large
                weight: Font.Normal
            }
            style: root.showShadow ? Text.Raised : Text.Normal
            styleColor: root.colHalo
        }
    }
}
