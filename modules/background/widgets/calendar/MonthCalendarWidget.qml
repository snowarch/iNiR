pragma ComponentBehavior: Bound

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
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "monthCalendar"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 300, contentHeight: 340,
        weekStart: 1, showAdjacentDays: true, style: "card", instrumentRule: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.14, borderWidth: 1, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 420, y: 120
    })

    implicitWidth: root.irisFaced ? root.irisFaceWidth : Math.round(Number(root._readConfigKey("contentWidth") ?? 300) * root.scaleFactor)
    implicitHeight: root.irisFaced ? root.irisFaceHeight : Math.round(Number(root._readConfigKey("contentHeight") ?? 340) * root.scaleFactor)
    irisFace: Component { IrisCalendarFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    visibleWhenLocked: true
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 252
    resizeMinHeight: 290
    resizeMaxWidth: 520
    resizeMaxHeight: 620

    property int monthShift: 0
    readonly property int weekStart: Number(root._readConfigKey("weekStart") ?? 1)
    readonly property bool showAdjacentDays: Boolean(root._readConfigKey("showAdjacentDays") ?? true)
    readonly property bool instrument: String(root._readConfigKey("style") ?? "card") === "instrument"
    readonly property bool instrumentRule: Boolean(root._readConfigKey("instrumentRule") ?? true)
    widgetSurfaceEnabled: !root.instrument
    readonly property date today: DateTime.clock.date
    readonly property date viewingDate: {
        const date = new Date(root.today)
        date.setDate(1)
        date.setMonth(date.getMonth() + root.monthShift)
        return date
    }
    readonly property var weeks: root.getMonthMatrix(root.viewingDate)
    readonly property color accentFace: root.widgetSemanticContainer(root.widgetPrimaryRole)
    readonly property color accentInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
    // Instrument reads on the wallpaper: sampled ink instead of surface ink.
    readonly property color ink: root.instrument ? root.widgetInk : root.widgetSurfaceInk
    readonly property color inkMuted: root.instrument
        ? root.widgetInkMuted : ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.58)
    readonly property color accentMark: root.instrument ? root.widgetAccentVisible : root.accentFace
    readonly property color accentMarkInk: root.instrument ? root.widgetAccentVisible : root.accentInk

    function getMonthMatrix(date): var {
        const year = date.getFullYear()
        const month = date.getMonth()
        const first = new Date(year, month, 1)
        const startOffset = (first.getDay() - root.weekStart + 7) % 7
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const daysInPrevMonth = new Date(year, month, 0).getDate()
        const cells = []

        for (let i = 0; i < startOffset; ++i) {
            cells.push({
                day: daysInPrevMonth - startOffset + i + 1,
                currentMonth: false,
                isToday: false
            })
        }
        for (let day = 1; day <= daysInMonth; ++day) {
            cells.push({
                day: day,
                currentMonth: true,
                isToday: year === root.today.getFullYear()
                    && month === root.today.getMonth()
                    && day === root.today.getDate()
            })
        }
        let nextDay = 1
        while (cells.length < 42)
            cells.push({ day: nextDay++, currentMonth: false, isToday: false })

        const rows = []
        for (let i = 0; i < cells.length; i += 7)
            rows.push(cells.slice(i, i + 7))
        return rows
    }

    function weekdayLabels(): var {
        const sundayFirst = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        const start = root.weekStart === 0 ? 0 : 1
        const labels = []
        for (let i = 0; i < 7; ++i)
            labels.push(sundayFirst[(start + i) % 7])
        return labels
    }

    function monthCells(): var {
        const cells = []
        for (const week of root.weeks) {
            for (const cell of week)
                cells.push(cell)
        }
        return cells
    }

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 14
            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    current: root.instrument ? "instrument" : "card"
                    model: [
                        { label: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Week starts on")
                WidgetQuickChoices {
                    current: root.weekStart
                    model: [
                        { label: Translation.tr("Monday"), value: 1 },
                        { label: Translation.tr("Sunday"), value: 0 }
                    ]
                    onPicked: value => root._setOutputValue("weekStart", value)
                }
            }
            WidgetQuickSection {
                title: Translation.tr("Show")
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "date_range"
                    label: Translation.tr("Adjacent days")
                    checked: root.showAdjacentDays
                    onToggled: root._setOutputValue("showAdjacentDays", !root.showAdjacentDays)
                }
                WidgetQuickToggle {
                    visible: root.instrument
                    Layout.fillWidth: true
                    iconName: "horizontal_rule"
                    label: Translation.tr("Header rule")
                    checked: root.instrumentRule
                    onToggled: root._setOutputValue("instrumentRule", !root.instrumentRule)
                }
            }
        }
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        anchors.fill: parent
        regionBrightness: root.regionBrightness
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
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
        shown: !root.irisFaced && !root.instrument
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    ColumnLayout {
        visible: !root.irisFaced
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(8 * root.scaleFactor)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(5 * root.scaleFactor)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                InstrumentLabel {
                    visible: root.instrument
                    text: Translation.tr("Calendar / %1").arg(root.viewingDate.getFullYear())
                    color: root.widgetAccentVisible
                    scaleFactor: root.scaleFactor
                    strong: true
                }
                StyledText {
                    text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM")
                    font.capitalization: Font.Capitalize
                    color: root.ink
                    font.family: root.widgetTitleFamily
                    font.pixelSize: Math.round(Appearance.font.pixelSize.larger
                        * root.widgetTitleScale * root.scaleFactor)
                    font.weight: root.widgetTitleWeight
                    font.letterSpacing: root.widgetTitleTracking
                }
                StyledText {
                    visible: !root.instrument
                    text: String(root.viewingDate.getFullYear())
                    color: root.inkMuted
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.family: root.widgetNumbersFamily
                }
            }

            Repeater {
                model: [
                    { icon: "chevron_left", delta: -1, tip: "Previous month" },
                    { icon: "today", delta: 0, tip: "Today" },
                    { icon: "chevron_right", delta: 1, tip: "Next month" }
                ]
                RippleButton {
                    required property var modelData
                    Layout.preferredWidth: Math.round((root.instrument ? 28 : 32) * root.scaleFactor)
                    Layout.preferredHeight: Math.round((root.instrument ? 28 : 32) * root.scaleFactor)
                    buttonRadius: root.instrument ? root.widgetControlRadius : Appearance.rounding.full
                    colBackground: modelData.delta === 0 && root.monthShift === 0
                        ? (root.instrument
                            ? ColorUtils.applyAlpha(root.accentMark, 0.16) : root.accentFace)
                        : "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(root.ink, 0.08)
                    colRipple: ColorUtils.applyAlpha(root.ink, 0.12)
                    releaseAction: () => {
                        if (modelData.delta === 0) root.monthShift = 0
                        else root.monthShift += modelData.delta
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: Math.round((root.instrument ? 15 : 17) * root.scaleFactor)
                        color: modelData.delta === 0 && root.monthShift === 0
                            ? root.accentMarkInk : root.ink
                    }
                    StyledToolTip { text: Translation.tr(modelData.tip) }
                }
            }
        }

        // Instrument hairline rule: the header reads as a measured caption
        // over the grid, not a card header.
        Rectangle {
            Layout.fillWidth: true
            visible: root.instrument && root.instrumentRule
            height: Math.max(1, Math.round(1 * root.scaleFactor))
            color: ColorUtils.applyAlpha(root.ink, 0.16)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: root.weekdayLabels()
                StyledText {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: root.inkMuted
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: Font.DemiBold
                    font.capitalization: root.instrument && !root.widgetIris ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: root.instrument
                        ? Math.round(1.4 * root.scaleFactor) : 0
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: Math.round(2 * root.scaleFactor)
            rowSpacing: Math.round(3 * root.scaleFactor)

            Repeater {
                model: root.monthCells()
                Item {
                    id: dayCell
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: dayCell.modelData.currentMonth || root.showAdjacentDays

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height, Math.round(36 * root.scaleFactor))
                        height: width
                        radius: Appearance.rounding.full
                        // Instrument: today is a signal mark — hairline accent
                        // ring with accent ink, not a filled pill.
                        color: !root.instrument && dayCell.modelData.isToday
                            ? root.accentFace : "transparent"
                        border.width: root.instrument && dayCell.modelData.isToday
                            ? Math.max(1.5, Math.round(1.5 * root.scaleFactor)) : 0
                        border.color: root.accentMark

                        StyledText {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day
                            color: dayCell.modelData.isToday
                                ? root.accentMarkInk : root.ink
                            opacity: dayCell.modelData.currentMonth ? 1 : 0.32
                            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            font.weight: dayCell.modelData.isToday ? Font.Bold : Font.Normal
                            font.family: root.widgetNumbersFamily
                        }
                    }
                }
            }
        }
    }
}
