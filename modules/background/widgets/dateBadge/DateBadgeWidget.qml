pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "dateBadge"
    defaultConfig: ({ placementStrategy: "free", contentWidth: 220, contentHeight: 140,
        style: "ticket", showYear: true, showWeekday: true, showOrdinal: true,
        instrumentMarks: true, widgetScale: 100, widgetOpacity: 100,
        colorMode: "auto", dim: 0, showBackground: true, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, useBlur: false, x: 260, y: 80 })
    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.max(140, Number(root._readConfigKey("contentWidth") ?? 220)) * scaleFactor
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.max(120, Number(root._readConfigKey("contentHeight") ?? 140)) * scaleFactor
    irisFace: Component { IrisDateFace { widget: root } }
    irisOptions: [
        { key: "showWeekday", raw: true, label: Translation.tr("Weekday"), icon: "calendar_view_week", fallback: true },
        { key: "showYear", raw: true, label: Translation.tr("Year"), icon: "event", fallback: true },
        { key: "showOrdinal", raw: true, label: Translation.tr("Day of the year"), icon: "linear_scale", fallback: true }
    ]
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 140
    resizeMinHeight: 120
    needsColText: true
    readonly property string badgeStyle: String(root._readConfigKey("style") ?? "ticket")
    readonly property bool showYear: Boolean(root._readConfigKey("showYear") ?? true)
    readonly property bool showWeekday: Boolean(root._readConfigKey("showWeekday") ?? true)
    readonly property bool showOrdinal: Boolean(root._readConfigKey("showOrdinal") ?? true)
    readonly property bool instrumentMarks: Boolean(root._readConfigKey("instrumentMarks") ?? true)
    readonly property bool instrument: root.badgeStyle === "instrument"
    widgetSurfaceEnabled: !root.instrument
    readonly property date today: DateTime.clock.date
    readonly property bool horizontal: root.badgeStyle === "ticket" && root.width >= 200 * root.scaleFactor
    readonly property int dayOfYear: {
        // Calendar ordinal must not drift by one when the local timezone crosses
        // a DST boundary. Compare UTC midnights, not elapsed local milliseconds.
        const year = root.today.getFullYear()
        const current = Date.UTC(year, root.today.getMonth(), root.today.getDate())
        const start = Date.UTC(year, 0, 0)
        return Math.floor((current - start) / 86400000)
    }
    readonly property int daysInYear: {
        const year = root.today.getFullYear()
        return ((year % 4 === 0 && year % 100 !== 0) || year % 400 === 0) ? 366 : 365
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        anchors.fill: parent
        shown: !root.irisFaced && root.badgeStyle !== "seal" && !root.instrument
        regionBrightness: root.regionBrightness
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x; screenY: root.y
        screenWidth: root.scaledScreenWidth; screenHeight: root.scaledScreenHeight
    }

    MaterialShape {
        anchors.centerIn: parent
        implicitSize: Math.min(root.width, root.height)
        visible: !root.irisFaced && root.badgeStyle === "seal"
        shape: MaterialShape.Shape.Cookie12Sided
        color: ColorUtils.applyAlpha(root.widgetPlateColor, root.backgroundOpacity)
        strokeColor: ColorUtils.applyAlpha(root.widgetAccent, root.borderOpacity)
        strokeWidth: root.borderWidth
    }

    Rectangle {
        visible: !root.irisFaced && root.badgeStyle === "ticket" && root.horizontal
        x: 10 * root.scaleFactor
        y: 10 * root.scaleFactor
        width: root.width * 0.36
        height: root.height - 20 * root.scaleFactor
        radius: Math.min(root.widgetCardRadius, width / 2)
        color: root.widgetSemanticContainer(root.widgetPrimaryRole)
    }

    Rectangle {
        visible: !root.irisFaced && root.badgeStyle === "stacked" && root.showBackground
        x: 16 * root.scaleFactor
        y: 12 * root.scaleFactor
        width: root.width - 32 * root.scaleFactor
        height: 4 * root.scaleFactor
        radius: height / 2
        color: root.widgetAccentVisible
    }

    StyledText {
        id: dayNumber
        visible: !root.irisFaced && !root.instrument
        x: root.horizontal ? 10 * root.scaleFactor : 0
        y: root.horizontal ? (root.height - height) / 2 : root.height * 0.14
        width: root.horizontal ? root.width * 0.36 : root.width
        height: root.height * 0.45
        text: Qt.locale().toString(root.today, "d")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.horizontal ? root.widgetSemanticOnContainer(root.widgetPrimaryRole)
            : root.widgetAccentVisible
        font.family: root.widgetNumbersFamily
        font.pixelSize: Math.min(height, 80 * root.scaleFactor)
        font.weight: root.widgetTitleWeight
        fontSizeMode: Text.Fit
        minimumPixelSize: 16
    }

    ColumnLayout {
        visible: !root.irisFaced && !root.instrument
        x: root.horizontal ? root.width * 0.36 + 24 * root.scaleFactor : root.width * 0.14
        y: root.horizontal ? (root.height - implicitHeight) / 2 : root.height * 0.59
        width: root.horizontal ? root.width - x - 14 * root.scaleFactor : root.width * 0.72
        spacing: 2 * root.scaleFactor

        StyledText {
            Layout.fillWidth: true
            text: Qt.locale().toString(root.today, "dddd")
            horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
            color: root.widgetInk
            font.pixelSize: Appearance.font.pixelSize.small * root.scaleFactor
            font.weight: root.widgetLabelWeight
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: Qt.locale().toString(root.today, root.showYear ? "MMM yyyy" : "MMMM")
            horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
            color: root.widgetInkMuted
            font.pixelSize: Appearance.font.pixelSize.smallest * root.scaleFactor
            elide: Text.ElideRight
        }
    }

    // Instrument: a borderless calendar index/almanac. The date is treated as
    // an address in the year, not another progress gauge or clock face.
    Item {
        anchors.fill: parent
        visible: !root.irisFaced && opacity > 0
        opacity: root.instrument ? 1 : 0
        enabled: root.instrument
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(12 * root.scaleFactor)
            spacing: Math.round(12 * root.scaleFactor)

            Item {
                id: dateIndexHero
                Layout.preferredWidth: Math.max(Math.round(74 * root.scaleFactor), parent.width * 0.42)
                Layout.fillHeight: true

                // Two registration corners frame the hero without becoming a card.
                Item {
                    visible: root.instrumentMarks
                    anchors.fill: parent
                    opacity: 0.9

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: Math.round(18 * root.scaleFactor)
                        height: Math.max(2, Math.round(2 * root.scaleFactor))
                        color: root.widgetAccentVisible
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        width: Math.max(2, Math.round(2 * root.scaleFactor))
                        height: Math.round(18 * root.scaleFactor)
                        color: root.widgetAccentVisible
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: Math.round(18 * root.scaleFactor)
                        height: Math.max(2, Math.round(2 * root.scaleFactor))
                        color: root.widgetAccentVisible
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: Math.max(2, Math.round(2 * root.scaleFactor))
                        height: Math.round(18 * root.scaleFactor)
                        color: root.widgetAccentVisible
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    width: parent.width * 0.86
                    height: parent.height * 0.8
                    text: Qt.locale().toString(root.today, "dd")
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.widgetInk
                    font.family: root.widgetNumbersFamily
                    font.pixelSize: Math.round(parent.height * 0.7)
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                    fontSizeMode: Text.Fit
                    minimumPixelSize: 24
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(2 * root.scaleFactor)

                StyledText {
                    Layout.fillWidth: true
                    visible: root.showWeekday
                    text: root.widgetCase(Qt.locale().toString(root.today, "dddd"))
                    elide: Text.ElideRight
                    color: root.widgetAccentVisible
                    font {
                        family: root.widgetBodyFamily
                        pixelSize: Math.max(9, Math.round(10 * root.scaleFactor))
                        weight: Font.DemiBold
                        letterSpacing: root.widgetIris ? 0 : Math.round(1.5 * root.scaleFactor)
                        capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    text: root.widgetCase(Qt.locale().toString(root.today, "MMMM"))
                    elide: Text.ElideRight
                    color: root.widgetInk
                    fontSizeMode: Text.Fit
                    minimumPixelSize: Math.round(16 * root.scaleFactor)
                    font {
                        family: root.widgetTitleFamily
                        pixelSize: Math.round(30 * root.scaleFactor)
                        weight: root.widgetTitleWeight
                        letterSpacing: -0.4
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * root.scaleFactor)

                    StyledText {
                        visible: root.showYear
                        text: String(root.today.getFullYear())
                        color: root.widgetInkMuted
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(11 * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        visible: root.showOrdinal
                        text: Translation.tr("Day") + " " + root.dayOfYear + " / " + root.daysInYear
                        color: root.widgetInkMuted
                        font {
                            family: root.widgetBodyFamily
                            pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                            weight: Font.DemiBold
                            letterSpacing: root.widgetIris ? 0 : Math.round(1.0 * root.scaleFactor)
                            capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                        }
                    }
                }
            }
        }
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.badgeStyle
                    model: [
                        { value: "ticket", icon: "confirmation_number", label: Translation.tr("Ticket") },
                        { value: "stacked", icon: "view_day", label: Translation.tr("Stacked") },
                        { value: "seal", icon: "verified", label: Translation.tr("Seal") },
                        { value: "instrument", icon: "avg_pace", label: Translation.tr("Instrument") }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Show")
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "event"
                    label: Translation.tr("Year")
                    checked: root.showYear
                    onToggled: root._setOutputValue("showYear", !root.showYear)
                }
                Repeater {
                    model: root.instrument ? [
                        { label: Translation.tr("Weekday"), icon: "calendar_view_week", key: "showWeekday", fallback: true },
                        { label: Translation.tr("Day of the year"), icon: "tag", key: "showOrdinal", fallback: true },
                        { label: Translation.tr("Marks"), icon: "crop_free", key: "instrumentMarks", fallback: true }
                    ] : []
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
        }
    }
}
