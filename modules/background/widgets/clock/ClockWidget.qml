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
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "clock"
    defaultConfig: ({
        placementStrategy: "free", style: "digital",
        fontFamily: "Space Grotesk", timeFormat: "system",
        showSeconds: false, showDate: true, dateStyle: "long",
        instrumentTrail: true, instrumentTrailLength: 6, instrumentNumerals: true,
        timeScale: 100, dateScale: 100, showShadow: true, dim: 70,
        "digital.adaptToWallpaper": true,
        "digital.animateChange": true, "digital.fontWeight": 600,
        "digital.spacing": 6, "digital.preset": "default",
        "pixel.orientation": "horizontal",
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
        : root.clockStyle === "pixel"
            ? pixelClockLoader.width
        : root.clockStyle === "instrument"
            ? instrumentClockLoader.width
        : root.clockStyle === "androidStacked"
            ? androidStackedClockLoader.width : digitalClockLoader.width
    readonly property real activeClockHeight: root.clockStyle === "cookie"
        ? cookieClockLoader.height
        : root.clockStyle === "pixel"
            ? pixelClockLoader.height
        : root.clockStyle === "instrument"
            ? instrumentClockLoader.height
        : root.clockStyle === "androidStacked"
            ? androidStackedClockLoader.height : digitalClockLoader.height
    readonly property bool statusShown: root.wallpaperSafetyTriggered
        || (root.shellLocked && (Config.options?.lock?.showLockedText ?? false))
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.activeClockHeight
        + (root.statusShown ? contentColumn.spacing + statusText.implicitHeight : 0)
    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.max(root.activeClockWidth,
        root.statusShown ? statusText.implicitWidth : 0)
    irisFace: Component { IrisClockFace { widget: root } }
    irisSizes: ["small", "medium"]
    irisOptions: [
        { key: "face", label: Translation.tr("Face"), fallback: "analog", choices: [
            { label: Translation.tr("Analog"), icon: "schedule", value: "analog" },
            { label: Translation.tr("Digital"), icon: "timer_10", value: "digital" }] },
        { key: "seconds", label: Translation.tr("Second hand"), icon: "avg_pace", fallback: true }
    ]
    // Digital mode resizes via timeScale, cookie via cookie.size — avoids scaleFactor churn
    resizableAxes: root.clockStyle === "cookie" ? ({ uniform: "cookie.size" })
        : ({ uniform: "timeScale" })
    resizeMinWidth: root.clockStyle === "cookie" ? 120
        : root.clockStyle === "instrument" ? 120 : 80
    resizeMinHeight: root.clockStyle === "cookie" ? 120
        : root.clockStyle === "instrument" ? 120
        : root.clockStyle === "androidStacked" ? 80 : 40

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14

            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.clockStyle
                    model: [
                        { value: "digital", icon: "digital_out_of_home", label: Translation.tr("Digital") },
                        { value: "androidStacked", icon: "android", label: Translation.tr("Android") },
                        { value: "cookie", icon: "circle", label: Translation.tr("Cookie") },
                        { value: "pixel", icon: "view_comfy_alt", label: Translation.tr("Pixel") },
                        { value: "instrument", icon: "avg_pace", label: Translation.tr("Instrument") }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }

            WidgetQuickSection {
                visible: root.clockStyle === "pixel"
                title: Translation.tr("Orientation")
                WidgetQuickChoices {
                    current: root.pixelOrientation
                    model: [
                        { value: "horizontal", icon: "view_week", label: Translation.tr("Horizontal") },
                        { value: "vertical", icon: "view_agenda", label: Translation.tr("Vertical") }
                    ]
                    onPicked: value => root._setOutputValue("pixel.orientation", value)
                }
            }

            WidgetQuickSection {
                visible: root.textClockStyle
                title: Translation.tr("Time format")
                WidgetQuickChoices {
                    current: root.timeFormat
                    model: [
                        { value: "system", icon: "settings", label: Translation.tr("System") },
                        { value: "24h", icon: "schedule", label: Translation.tr("24h") },
                        { value: "12h", icon: "nest_clock_farsight_analog", label: Translation.tr("12h") }
                    ]
                    onPicked: value => root._setOutputValue("timeFormat", value)
                }
            }

            WidgetQuickSection {
                visible: root.clockStyle === "instrument"
                title: Translation.tr("Show")
                Repeater {
                    model: [
                        { label: Translation.tr("Seconds"), icon: "timelapse", key: "showSeconds", fallback: false },
                        { label: Translation.tr("Date"), icon: "calendar_today", key: "showDate", fallback: true },
                        { label: Translation.tr("Numerals"), icon: "pin", key: "instrumentNumerals", fallback: true }
                    ]
                    WidgetQuickToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        iconName: modelData.icon
                        label: modelData.label
                        checked: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                        onToggled: root._setOutputValue(modelData.key, !checked)
                    }
                }
            }

            WidgetQuickSection {
                visible: root.clockStyle === "instrument"
                title: Translation.tr("Second hand trail")
                WidgetQuickChoices {
                    isSelected: entry => entry.enabled === root.instrumentTrail
                        && (!entry.enabled || (entry.length <= 6 ? root.instrumentTrailLength <= 7 : root.instrumentTrailLength > 7))
                    model: [
                        { value: "clean", label: Translation.tr("Clean"), icon: "horizontal_rule", enabled: false, length: 0 },
                        { value: "trace", label: Translation.tr("Trace"), icon: "blur_on", enabled: true, length: 5 },
                        { value: "long", label: Translation.tr("Long trace"), icon: "blur_linear", enabled: true, length: 11 }
                    ]
                    onPicked: (value, entry) => {
                        const updates = { instrumentTrail: entry.enabled }
                        if (entry.enabled)
                            updates.instrumentTrailLength = entry.length
                        root._setOutputValues(updates)
                    }
                }
            }
        }
    }

    property string clockStyle: root._readConfigKey("style") ?? "digital"
    widgetSurfaceEnabled: root.clockStyle !== "instrument"
    readonly property bool textClockStyle: root.clockStyle === "digital"
        || root.clockStyle === "androidStacked"
    property bool adaptDigitalToWallpaper: root._readConfigKey("digital.adaptToWallpaper") ?? true
    readonly property bool shellLocked: GlobalStates.screenLocked && Config.options?.panelFamily !== "iris"
    property bool forceCenter: (root.shellLocked && (Config.options?.lock?.centerClock ?? false))
    property bool wallpaperSafetyTriggered: false
    property bool debugRegionActive: false
    property color debugRegionColor: "transparent"
    property real debugRegionBrightness: -1
    property real debugRegionSpread: 0
    property string cookieDiagnostics: "{}"
    needsColText: root.clockStyle === "instrument"
        || (root.textClockStyle && (root.adaptDigitalToWallpaper || root.widgetHasSurface))
    visibleWhenLocked: true

    // --- Clock customization config ---
    property string clockFontFamily: root._readConfigKey("fontFamily") ?? "Space Grotesk"
    property string timeFormat: root._readConfigKey("timeFormat") ?? "system"
    property bool showSeconds: root._readConfigKey("showSeconds") ?? false
    property bool showDate: root._readConfigKey("showDate") ?? true
    property bool instrumentTrail: root._readConfigKey("instrumentTrail") ?? true
    property int instrumentTrailLength: Math.max(2, Math.min(15,
        Number(root._readConfigKey("instrumentTrailLength") ?? 6)))
    property bool instrumentNumerals: root._readConfigKey("instrumentNumerals") ?? true
    property string dateStyle: root._readConfigKey("dateStyle") ?? "long"
    property int timeScale: Number(root._readConfigKey("timeScale") ?? 100)
    property int dateScale: Number(root._readConfigKey("dateScale") ?? 100)
    property bool showShadow: root._readConfigKey("showShadow") ?? true
    property int digitalFontWeight: Number(root._readConfigKey("digital.fontWeight") ?? 600)
    property int digitalSpacing: Number(root._readConfigKey("digital.spacing") ?? 6)
    readonly property string pixelOrientation: root._readConfigKey("pixel.orientation") ?? "horizontal"

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
        precision: !root.irisFaced && (root.showSeconds || root.clockStyle === "instrument"
            || GlobalStates.screenLocked) && root.powerActive
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
        irisPresentation: root.widgetIris
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
        shown: !root.irisFaced && root.textClockStyle
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    Column {
        id: contentColumn
        visible: !root.irisFaced
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.implicitHeight
        spacing: Math.round(6 * root.scaleFactor)

        FadeLoader {
            id: cookieClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: !root.irisFaced && root.clockStyle === "cookie"
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
                    shown: Boolean(root._readConfigKey("quote.enable") ?? false)
                        && String(root._readConfigKey("quote.text") ?? "") !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: !root.irisFaced && root.clockStyle === "digital"
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
                    visible: Boolean(root._readConfigKey("quote.enable") ?? false)
                        && String(root._readConfigKey("quote.text") ?? "").length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: root.textHorizontalAlignment
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        weight: 350
                    }
                    color: root.digitalMetaColor
                    style: root.showShadow ? Text.Raised : Text.Normal
                    styleColor: root.colHalo
                    text: String(root._readConfigKey("quote.text") ?? "")
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
            id: instrumentClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: !root.irisFaced && root.clockStyle === "instrument"
            // Known before Loader construction: no zero-size frame on entry.
            width: Math.round(230 * root.scaleFactor * root.timeScale / 100)
            height: width
            sourceComponent: Item {
                id: dialClock
                // Precision time instrument: a live minute track surrounds a
                // typographic readout. It is intentionally not an analog clock.
                readonly property real side: Math.round(230 * root.scaleFactor * root.timeScale / 100)
                readonly property real desiredImplicitSize: side
                readonly property real minutePosition: displayClock.date.getMinutes()
                    + displayClock.date.getSeconds() / 60
                readonly property bool secondsLive: root.showSeconds && root.powerActive
                readonly property real trackRadius: side / 2 - Math.max(12,
                    Math.round(18 * root.scaleFactor))
                implicitWidth: side
                implicitHeight: side

                // Sixty precision marks. Only the recent minutes form the trail;
                // disabling it leaves a neutral track plus the current locator.
                Repeater {
                    model: 60

                    Item {
                        id: minuteTick
                        required property int index
                        readonly property bool quarter: index % 15 === 0
                        readonly property bool fiveMinute: index % 5 === 0 && !quarter
                        readonly property real distanceBehind: (dialClock.minutePosition - index + 60) % 60
                        readonly property bool current: index === Math.floor(dialClock.minutePosition) % 60
                        readonly property bool inTrail: root.instrumentTrail && !current
                            && distanceBehind > 0 && distanceBehind <= root.instrumentTrailLength
                        readonly property real trailStrength: inTrail
                            ? 1 - distanceBehind / Math.max(1, root.instrumentTrailLength) : 0

                        anchors.centerIn: parent
                        width: dialClock.side
                        height: dialClock.side
                        rotation: index * 6

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -dialClock.trackRadius
                            width: minuteTick.current ? Math.max(3, Math.round(3 * root.scaleFactor))
                                : minuteTick.inTrail ? Math.max(2, Math.round(2 * root.scaleFactor))
                                : minuteTick.quarter ? Math.max(2, Math.round(2 * root.scaleFactor)) : 1
                            height: minuteTick.current ? Math.round(16 * root.scaleFactor)
                                : minuteTick.inTrail
                                    ? Math.round((6 + minuteTick.trailStrength * 7) * root.scaleFactor)
                                : minuteTick.quarter ? Math.round(12 * root.scaleFactor)
                                : minuteTick.fiveMinute ? Math.round(8 * root.scaleFactor)
                                : Math.round(5 * root.scaleFactor)
                            radius: width / 2
                            color: minuteTick.current ? root.widgetAccentVisible
                                : minuteTick.inTrail
                                    ? ColorUtils.applyAlpha(root.widgetAccent3Visible,
                                        0.42 + minuteTick.trailStrength * 0.58)
                                    : ColorUtils.applyAlpha(root.widgetInk,
                                        minuteTick.quarter ? 0.5
                                            : minuteTick.fiveMinute ? 0.3 : 0.18)
                            Behavior on color {
                                enabled: root.animationsActive
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }
                }

                Repeater {
                    model: [
                        { text: "12", angle: -Math.PI / 2, hero: true },
                        { text: "3", angle: 0, hero: false },
                        { text: "6", angle: Math.PI / 2, hero: false },
                        { text: "9", angle: Math.PI, hero: false }
                    ]

                    StyledText {
                        required property var modelData
                        readonly property real labelRadius: dialClock.trackRadius
                            - Math.round(20 * root.scaleFactor)
                        visible: root.instrumentNumerals
                        text: modelData.text
                        x: dialClock.width / 2 + labelRadius * Math.cos(modelData.angle) - width / 2
                        y: dialClock.height / 2 + labelRadius * Math.sin(modelData.angle) - height / 2
                        color: modelData.hero ? root.widgetAccentVisible : root.widgetInkMuted
                        font {
                            family: root.widgetNumbersFamily
                            pixelSize: Math.round(dialClock.side * (modelData.hero ? 0.08 : 0.052))
                            weight: modelData.hero ? Font.Bold : Font.DemiBold
                            features: ({ "tnum": 1 })
                        }
                    }
                }

                // Seconds index: a small accent dot riding the tick track.
                Item {
                    visible: dialClock.secondsLive
                    anchors.centerIn: parent
                    width: dialClock.side
                    height: dialClock.side
                    rotation: displayClock.date.getSeconds() * 6

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -dialClock.trackRadius
                        width: Math.max(5, Math.round(6 * root.scaleFactor))
                        height: width
                        radius: width / 2
                        color: root.widgetAccentVisible
                    }
                }

                // Hero readout: the time owns the dial center.
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: dialClock.side * 0.62
                        text: root.timeText
                        color: root.widgetInk
                        fontSizeMode: Text.Fit
                        minimumPixelSize: Math.round(16 * root.scaleFactor)
                        font {
                            family: root.widgetNumbersFamily
                            pixelSize: Math.round(dialClock.side * 0.175)
                            weight: Font.Bold
                            features: ({ "tnum": 1 })
                            letterSpacing: -0.5
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Math.round(6 * root.scaleFactor)
                        visible: root.showDate
                        Layout.maximumWidth: dialClock.side * 0.64
                        text: root.widgetCase(Qt.locale().toString(displayClock.date, "ddd d MMM"))
                        elide: Text.ElideRight
                        color: root.widgetInkMuted
                        font {
                            family: root.widgetBodyFamily
                            pixelSize: Math.round(Math.max(9, dialClock.side * 0.048))
                            weight: root.widgetLabelWeight
                            letterSpacing: root.widgetIris ? 0 : Math.max(1, Math.round(1.6 * root.scaleFactor))
                            capitalization: root.widgetCapitalization
                        }
                    }
                }
            }
        }

        FadeLoader {
            id: androidStackedClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: !root.irisFaced && root.clockStyle === "androidStacked"
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
                animateChange: Boolean(root._readConfigKey("digital.animateChange") ?? false)
                horizontalAlignment: root.textHorizontalAlignment
            }
        }
        FadeLoader {
            id: pixelClockLoader
            x: Math.round((parent.width - width) / 2)
            shown: !root.irisFaced && root.clockStyle === "pixel"
            width: item?.desiredImplicitWidth ?? 0
            height: item?.desiredImplicitHeight ?? 0
            sourceComponent: PixelClock {
                currentDate: displayClock.date
                orientation: root.pixelOrientation
                scaleFactor: root.scaleFactor * root.timeScale / 100
                softColor: root.widgetSemanticContainer(root.widgetPrimaryRole)
                boldColor: root.widgetAccent
                showShadow: root.showShadow
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
                        shown: root.shellLocked && (Config.options?.lock?.showLockedText ?? false)
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
        animateChange: Boolean(root._readConfigKey("digital.animateChange") ?? false)
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
