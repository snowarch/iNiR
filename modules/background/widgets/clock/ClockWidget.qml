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
        placementStrategy: "leastBusy", style: "cookie",
        fontFamily: "Space Grotesk", timeFormat: "system",
        showSeconds: false, showDate: true, dateStyle: "long",
        timeScale: 100, dateScale: 100, showShadow: true, dim: 55,
        "digital.animateChange": true, "digital.fontWeight": 600,
        "digital.spacing": 6, "digital.preset": "default",
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        x: 100, y: 100
    })

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth
    // Digital mode resizes via timeScale, cookie via cookie.size — avoids scaleFactor churn
    resizableAxes: root.clockStyle === "cookie" ? ({ uniform: "cookie.size" }) : ({ uniform: "timeScale" })
    resizeMinWidth: 80
    resizeMinHeight: 40

    editPopoverContent: Component {
        Column {
            spacing: 6
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                Repeater {
                    model: [
                        { label: "Digital", icon: "digital_out_of_home", value: "digital" },
                        { label: "Cookie", icon: "circle", value: "cookie" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
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
                visible: root.clockStyle === "digital"
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
                        buttonText: modelData.label
                        toggled: root.timeFormat === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.clock.timeFormat", modelData.value)
                    }
                }
            }
        }
    }

    property string clockStyle: Config.getNestedValue("background.widgets.clock.style", "cookie")
    property bool forceCenter: (GlobalStates.screenLocked && (Config.options?.lock?.centerClock ?? false))
    property bool wallpaperSafetyTriggered: false
    needsColText: true
    visibleWhenLocked: true

    // --- Clock customization config ---
    property string clockFontFamily: Config.getNestedValue("background.widgets.clock.fontFamily", "Space Grotesk")
    property string timeFormat: Config.getNestedValue("background.widgets.clock.timeFormat", "system")
    property bool showSeconds: Config.getNestedValue("background.widgets.clock.showSeconds", false)
    property bool showDate: Config.getNestedValue("background.widgets.clock.showDate", true)
    property string dateStyle: Config.getNestedValue("background.widgets.clock.dateStyle", "long")
    property int timeScale: Config.getNestedValue("background.widgets.clock.timeScale", 100)
    property int dateScale: Config.getNestedValue("background.widgets.clock.dateScale", 100)
    property bool showShadow: Config.getNestedValue("background.widgets.clock.showShadow", true)
    property int digitalFontWeight: Config.getNestedValue("background.widgets.clock.digital.fontWeight", 600)
    property int digitalSpacing: Config.getNestedValue("background.widgets.clock.digital.spacing", 6)

    // ── Style-dispatched accent colors ──
    readonly property color accentPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primary
        : Appearance.colors.colPrimary
    readonly property color accentSecondary: Appearance.angelEverywhere ? Appearance.angel.colSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colSecondary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3secondary
        : Appearance.colors.colSecondary
    readonly property color accentTertiary: Appearance.angelEverywhere ? Appearance.angel.colTertiary
        : Appearance.inirEverywhere ? Appearance.inir.colTertiary
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3tertiary
        : Appearance.colors.colTertiary
    readonly property color accentPrimaryContainer: Appearance.angelEverywhere ? Appearance.angel.colPrimaryContainer
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.auroraEverywhere ? Appearance.m3colors.m3primaryContainer
        : Appearance.colors.colPrimaryContainer

    // Local clock with seconds precision when needed
    SystemClock {
        id: displayClock
        precision: root.showSeconds || GlobalStates.screenLocked ? SystemClock.Seconds : SystemClock.Minutes
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
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

    // Per-clock dim factor (0..1), independent from wallpaper dim
    property real dimFactor: {
        const v = Config.getNestedValue("background.widgets.clock.dim", 0);
        const n = Number(v);
        return Math.max(0, Math.min(1, Number.isFinite(n) ? n / 100 : 0));
    }

    // Effective text color for clock based on palette + dim
    property color clockTextColor: {
        const dark = Qt.rgba(0, 0, 0, 1);
        return ColorUtils.mix(root.colText, dark, dimFactor);
    }

    // Card background (mainly for digital mode)
    WidgetSurface {
        anchors.fill: parent
        anchors.margins: -Math.round(8 * root.scaleFactor)
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.colText
        surfaceUseBlur: root.useBlur
        screenX: root.x + Math.round(8 * root.scaleFactor)
        screenY: root.y + Math.round(8 * root.scaleFactor)
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: (root.backgroundOpacity > 0 || root.borderWidth > 0) && root.clockStyle === "digital"
    }

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Math.round(6 * root.scaleFactor)

        FadeLoader {
            id: cookieClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "cookie"
            sourceComponent: Column {
                CookieClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    scaleFactor: root.scaleFactor
                    colBackground: root.accentPrimaryContainer
                    colOnBackground: ColorUtils.mix(root.accentSecondary, root.accentPrimaryContainer, 0.15)
                    colBackgroundInfo: ColorUtils.mix(root.accentPrimary, root.accentPrimaryContainer, 0.55)
                    colHourHand: root.accentPrimary
                    colMinuteHand: root.accentTertiary
                    colSecondHand: root.accentPrimary
                }
                FadeLoader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    shown: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")) !== ""
                    sourceComponent: CookieQuote {}
                }
            }
        }

        FadeLoader {
            id: digitalClockLoader
            anchors.horizontalCenter: parent.horizontalCenter
            shown: root.clockStyle === "digital"
            sourceComponent: ColumnLayout {
                id: clockColumn
                spacing: Math.round(root.digitalSpacing * root.scaleFactor)

                ClockText {
                    font.pixelSize: Math.round(90 * Appearance.fontSizeScale * root.timeScale / 100 * root.scaleFactor)
                    text: root.timeText
                }
                ClockText {
                    visible: root.showDate
                    Layout.topMargin: Math.round(-5 * root.scaleFactor)
                    font.pixelSize: Math.round(20 * root.dateScale / 100 * root.scaleFactor)
                    text: root.dateText
                }
                StyledText {
                    // Somehow gets fucked up if made a ClockText???
                    visible: (Config.getNestedValue("background.widgets.clock.quote.enable", false))
                        && (Config.getNestedValue("background.widgets.clock.quote.text", "")).length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: root.textHorizontalAlignment
                    font {
                        pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                        weight: 350
                    }
                    color: root.clockTextColor
                    style: root.showShadow ? Text.Raised : Text.Normal
                    styleColor: Appearance.colors.colShadow
                    text: Config.getNestedValue("background.widgets.clock.quote.text", "")
                }
            }
        }
        Item {
            id: statusText
            anchors.horizontalCenter: parent.horizontalCenter
            implicitHeight: statusTextBg.implicitHeight
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
                color: ColorUtils.transparentize(root.accentPrimaryContainer, root.clockStyle === "cookie" ? 0 : 1)

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
        color: root.clockTextColor
        style: root.showShadow ? Text.Raised : Text.Normal
        styleColor: Appearance.colors.colShadow
        animateChange: Config.getNestedValue("background.widgets.clock.digital.animateChange", false)
    }
    component ClockStatusText: Row {
        id: statusTextRow
        property alias statusIcon: statusIconWidget.text
        property alias statusText: statusTextWidget.text
        property bool shown: true
        property color textColor: {
            const base = root.clockStyle === "cookie" ? root.accentPrimary : root.colText;
            const dark = Qt.rgba(0, 0, 0, 1);
            return ColorUtils.mix(base, dark, root.dimFactor);
        }
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
            styleColor: Appearance.colors.colShadow
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
            styleColor: Appearance.colors.colShadow
        }
    }
}
