pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
AbstractBackgroundWidget {
    id: root
    configEntryName: "dateBadge"
    defaultConfig: ({ placementStrategy: "free", contentWidth: 220, contentHeight: 140,
        style: "ticket", showYear: true, showWeekday: true, showOrdinal: true,
        instrumentMarks: true, widgetScale: 100, widgetOpacity: 100,
        colorMode: "auto", dim: 0, showBackground: true, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, useBlur: false, x: 260, y: 80 })
    implicitWidth: root.irisFaced ? root.irisFaceWidth : root.materialSized ? root.materialWidth : Math.max(140, Number(root._readConfigKey("contentWidth") ?? 220)) * scaleFactor
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.materialSized ? root.materialHeight : Math.max(120, Number(root._readConfigKey("contentHeight") ?? 140)) * scaleFactor
    irisFacePart: "date"
    irisSizes: ["small", "medium", "large"]
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
        && !root.materialLarge
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
        y: root.horizontal ? (root.height - height) / 2 : root.height * (root.materialLarge ? 0.08 : 0.14)
        width: root.horizontal ? root.width * 0.36 : root.width
        height: root.height * (root.materialLarge ? 0.4 : 0.45)
        text: Qt.locale().toString(root.today, "d")
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        color: root.horizontal ? root.widgetSemanticOnContainer(root.widgetPrimaryRole)
            : root.widgetAccentVisible
        font.family: root.widgetNumbersFamily
        font.pixelSize: Math.min(height, (root.materialLarge ? 170 : 80) * root.scaleFactor)
        font.weight: root.widgetTitleWeight
        fontSizeMode: Text.Fit
        minimumPixelSize: 16
    }

    ColumnLayout {
        visible: !root.irisFaced && !root.instrument
        x: root.horizontal ? root.width * 0.36 + 24 * root.scaleFactor : root.width * 0.14
        y: root.horizontal ? (root.height - implicitHeight) / 2 : root.height * (root.materialLarge ? 0.49 : 0.59)
        width: root.horizontal ? root.width - x - 14 * root.scaleFactor : root.width * 0.72
        spacing: 2 * root.scaleFactor

        StyledText {
            Layout.fillWidth: true
            visible: root.showWeekday
            text: Translation.locale.toString(root.today, "dddd")
            horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
            color: root.widgetInk
            font.pixelSize: Appearance.font.pixelSize.small * root.scaleFactor
            font.weight: root.widgetLabelWeight
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.locale.toString(root.today, root.showYear ? "MMM yyyy" : "MMMM")
            horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
            color: root.widgetInkMuted
            font.pixelSize: Appearance.font.pixelSize.smallest * root.scaleFactor
            elide: Text.ElideRight
        }
    }

    // Large adds the week the day sits in (the region's first weekday), today in the accent's fill, and where the
    // day falls in the year.
    ColumnLayout {
        visible: !root.irisFaced && !root.instrument && root.materialLarge
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(16 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showOrdinal
            text: Translation.tr("Day") + " " + root.dayOfYear + " / " + root.daysInYear
            color: root.widgetInkMuted
            font.family: root.widgetNumbersFamily
            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
            font.features: ({ "tnum": 1 })
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(4 * root.scaleFactor)
            Repeater {
                model: root.materialLarge ? 7 : 0
                Rectangle {
                    id: weekDay
                    required property int index
                    readonly property int lead: (root.today.getDay() - Qt.locale().firstDayOfWeek + 7) % 7
                    readonly property date day: new Date(root.today.getFullYear(), root.today.getMonth(),
                        root.today.getDate() - weekDay.lead + weekDay.index)
                    readonly property bool isToday: weekDay.index === weekDay.lead
                    readonly property color dayInk: weekDay.isToday ? root.widgetSemanticOnColor(root.widgetPrimaryRole) : root.widgetInk
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: dayColumn.implicitHeight + Math.round(14 * root.scaleFactor)
                    radius: Math.min(root.widgetControlRadius, width / 2)
                    color: weekDay.isToday ? root.widgetSemanticColor(root.widgetPrimaryRole) : "transparent"
                    ColumnLayout {
                        id: dayColumn
                        anchors.centerIn: parent
                        spacing: Math.round(2 * root.scaleFactor)
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.locale.standaloneDayName(weekDay.day.getDay(), Locale.NarrowFormat).toUpperCase()
                            color: weekDay.isToday ? weekDay.dayInk : root.widgetInkMuted
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                            font.weight: Font.Medium
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: String(weekDay.day.getDate())
                            color: weekDay.dayInk
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                            font.weight: weekDay.isToday ? Font.Bold : Font.Medium
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
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

        // small sets the day over its month: side by side the month ran past the card
        GridLayout {
            anchors.fill: parent
            anchors.margins: Math.round(12 * root.scaleFactor)
            columns: root.materialSmall ? 1 : 2
            columnSpacing: Math.round(12 * root.scaleFactor)
            rowSpacing: Math.round(6 * root.scaleFactor)

            Item {
                id: dateIndexHero
                Layout.preferredWidth: root.materialSmall ? -1 : Math.max(Math.round(74 * root.scaleFactor), parent.width * 0.42)
                Layout.fillWidth: root.materialSmall
                Layout.preferredHeight: root.materialSmall ? parent.height * 0.5 : -1
                Layout.fillHeight: !root.materialSmall

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
                    text: root.widgetCase(Translation.locale.toString(root.today, "dddd"))
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
                    text: root.widgetCase(Translation.locale.toString(root.today, "MMMM"))
                    elide: Text.ElideRight
                    color: root.widgetInk
                    fontSizeMode: Text.Fit
                    minimumPixelSize: Math.round(12 * root.scaleFactor)
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
                        text: root.materialSmall ? root.dayOfYear + "/" + root.daysInYear : Translation.tr("Day") + " " + root.dayOfYear + " / " + root.daysInYear
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
                    model: [
                        { label: Translation.tr("Weekday"), icon: "calendar_view_week", key: "showWeekday", fallback: true },
                        { label: Translation.tr("Day of the year"), icon: "tag", key: "showOrdinal", fallback: true }
                    ].concat(root.instrument ? [{ label: Translation.tr("Marks"), icon: "crop_free", key: "instrumentMarks", fallback: true }] : [])
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
