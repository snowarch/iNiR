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
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "monthCalendar"
    defaultConfig: ({
        placementStrategy: "free",
        
        weekStart: 1, showAdjacentDays: true, style: "card", instrumentRule: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.14, borderWidth: 1, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 420, y: 120
    })

    irisFacePart: "calendar"
    visibleWhenLocked: true
    needsColText: true
    resizeMinWidth: 252
    resizeMinHeight: 290
    resizeMaxWidth: 520
    resizeMaxHeight: 620

    property int monthShift: 0
    readonly property int weekStart: Number(root._readConfigKey("weekStart") ?? 1)
    readonly property bool showAdjacentDays: Boolean(root._readConfigKey("showAdjacentDays") ?? true)
    readonly property bool instrument: String(root._readConfigKey("style") ?? "card") === "instrument"
    readonly property bool instrumentRule: Boolean(root._readConfigKey("instrumentRule") ?? true)
    readonly property date today: DateTime.clock.date
    readonly property date viewingDate: {
        const date = new Date(root.today)
        date.setDate(1)
        date.setMonth(date.getMonth() + root.monthShift)
        return date
    }
    readonly property var weeks: root.getMonthMatrix(root.viewingDate)
    readonly property color accentFace: root.widgetPrimaryMark.fill
    readonly property color accentInk: root.widgetPrimaryMark.ink
    // With no plate under it (Instrument, or the card turned off) it reads on the wallpaper: sampled ink.
    readonly property color ink: root.widgetInk
    readonly property color inkMuted: root.widgetHasSurface
        ? ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.58) : root.widgetInkMuted
    // Today is the accent's solid fill on a plate too: the container sank into Aurora's, Regalia's and Editorial's
    // plates. Off a plate the mark already picks whichever stands 3:1 off the wallpaper.
    readonly property var primarySet: root.widgetSemanticSet(root.widgetPrimaryRole)
    readonly property color todayFace: root.widgetHasSurface ? root.primarySet.color : root.accentFace
    readonly property color todayInk: root.widgetHasSurface ? root.primarySet.onColor : root.accentInk
    readonly property color accentMark: root.instrument ? root.widgetAccentVisible : root.todayFace
    readonly property color accentMarkInk: root.instrument ? root.widgetAccentVisible : root.todayInk
    // a picked day is tonal, a step under today's accent
    readonly property color pickFace: root.instrument ? ColorUtils.applyAlpha(root.widgetAccentVisible, 0.16)
        : root.widgetSemanticContainer(root.widgetSecondaryRole)
    readonly property color pickInk: root.instrument ? root.widgetAccentVisible : root.widgetSemanticOnContainer(root.widgetSecondaryRole)

    // A day with something on it keeps a dot under its number (Lucid's month view).
    function hasEvents(year: int, month: int, day: int): bool {
        const date = new Date(year, month, day)
        if (typeof Events !== "undefined" && (Events.getAllEventsForDate(date) ?? []).length > 0) return true
        return typeof CalendarSync !== "undefined" && (CalendarSync.getEventsForDate(date) ?? []).length > 0
    }

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
                date: new Date(year, month, day),
                currentMonth: true,
                marked: root.hasEvents(year, month, day),
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

    // Small: the month in initials; Medium: this week and the next under the header.
    readonly property bool compact: root.isSmall
    readonly property bool strip: root.sizeClass === "medium"
    // in the shell's language: hardcoded English initials sat under a month named in the system's
    function weekdayLabels(): var {
        const start = root.weekStart === 0 ? 0 : 1
        const labels = []
        for (let i = 0; i < 7; ++i) {
            const day = (start + i) % 7
            labels.push(root.compact ? Translation.locale.standaloneDayName(day, Locale.NarrowFormat).toUpperCase()
                : Translation.locale.standaloneDayName(day, Locale.ShortFormat).replace(/\.$/, "").slice(0, 2).replace(/^./, c => c.toUpperCase()))
        }
        return labels
    }

    function monthCells(): var {
        const cells = []
        if (root.strip) {
            const start = new Date(root.today)
            start.setDate(start.getDate() - (start.getDay() - root.weekStart + 7) % 7)
            for (let i = 0; i < 14; ++i) {
                const day = new Date(start)
                day.setDate(start.getDate() + i)
                cells.push({ day: day.getDate(), date: day, currentMonth: day.getMonth() === root.today.getMonth(),
                    marked: root.hasEvents(day.getFullYear(), day.getMonth(), day.getDate()),
                    isToday: i === (root.today.getDay() - root.weekStart + 7) % 7 })
            }
            return cells
        }
        for (const week of root.weeks) {
            // Only the weeks the month reaches: a sixth row of next month's days took a row's height from every week.
            if (!week.some(cell => cell.currentMonth))
                continue
            for (const cell of week)
                cells.push(cell)
        }
        return cells
    }
    // A tapped day is read in the line under the month (what is on it, or that nothing is), as the iRiS face does;
    // the same day again, the today key or another month lets it go.
    property var picked: null
    readonly property bool picks: !root.compact && !GlobalStates.widgetEditMode
    function samePicked(date: var): bool {
        return Boolean(root.picked) && Boolean(date) && root.picked.getFullYear() === date.getFullYear()
            && root.picked.getMonth() === date.getMonth() && root.picked.getDate() === date.getDate()
    }
    function pick(date: var): void {
        root.picked = root.samePicked(date) ? null : new Date(date)
    }
    readonly property string pickedLine: {
        if (!root.picked)
            return ""
        const events = Array.from(typeof Events !== "undefined" ? Events.getAllEventsForDate(root.picked) ?? [] : [])
            .concat(Array.from(typeof CalendarSync !== "undefined" ? CalendarSync.getEventsForDate(root.picked) ?? [] : []))
            .sort((a, b) => new Date(a.dateTime || a.startDate) - new Date(b.dateTime || b.startDate))
        const day = root.picked.toLocaleDateString(Translation.locale, "ddd d")
        if (events.length === 0)
            return day + " · " + Translation.tr("Nothing on this day")
        const first = events[0]
        const when = first.allDay ? Translation.tr("All day") : Qt.formatTime(new Date(first.dateTime || first.startDate), "HH:mm")
        const more = events.length > 1 ? " · " + Translation.tr("+%1 more").arg(events.length - 1) : ""
        return day + " · " + (first.title || Translation.tr("Untitled")) + ", " + when + more
    }
    onMonthShiftChanged: root.picked = null
    onCompactChanged: if (root.compact || root.strip) root.monthShift = 0
    onStripChanged: if (root.compact || root.strip) root.monthShift = 0

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

    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.irisFaced && !root.instrument
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.irisFaced
        sourceComponent: Item {
            ColumnLayout {
                visible: !root.irisFaced
                anchors.fill: parent
                anchors.margins: Math.round((root.compact ? 12 : 14) * root.scaleFactor)
                spacing: Math.round((root.compact ? 4 : 8) * root.scaleFactor)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(5 * root.scaleFactor)

                    // its texts fill too: a nested layout is never wider than its children allow, which left the keys mid-card
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        InstrumentLabel {
                            Layout.fillWidth: true
                            visible: root.instrument
                            text: Translation.tr("Calendar / %1").arg(root.viewingDate.getFullYear())
                            color: root.widgetAccentVisible
                            scaleFactor: root.scaleFactor
                            strong: true
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.viewingDate.toLocaleDateString(Translation.locale, "MMMM")
                            font.capitalization: Font.Capitalize
                            color: root.ink
                            font.family: root.widgetTitleFamily
                            font.pixelSize: Math.round((root.compact ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.larger)
                                * root.widgetTitleScale * root.scaleFactor)
                            font.weight: root.widgetTitleWeight
                            font.letterSpacing: root.widgetTitleTracking
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: !root.instrument && !root.compact
                            text: root.pickedLine.length > 0 ? root.pickedLine
                                : root.strip ? root.today.toLocaleDateString(Translation.locale, "dddd d") : String(root.viewingDate.getFullYear())
                            elide: Text.ElideRight
                            font.capitalization: root.pickedLine.length > 0 ? Font.MixedCase : Font.Capitalize
                            color: root.inkMuted
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            font.family: root.widgetNumbersFamily
                        }
                    }

                    Repeater {
                        model: root.compact || root.strip ? [] : [
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
                                root.picked = null
                                if (modelData.delta === 0) root.monthShift = 0
                                else root.monthShift += modelData.delta
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: Math.round((root.instrument ? 15 : 17) * root.scaleFactor)
                                color: modelData.delta === 0 && root.monthShift === 0
                                    ? (root.instrument ? root.accentMarkInk : root.accentInk) : root.ink
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
                            required property int index
                            // Saturday and Sunday take the accent (Lucid): the week's shape reads before its numbers.
                            readonly property bool weekend: !root.instrument && [0, 6].includes((index + root.weekStart) % 7)
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: weekend ? root.widgetAccentVisible : root.inkMuted
                            font.pixelSize: Math.round((root.compact ? Appearance.font.pixelSize.smallest : Appearance.font.pixelSize.smaller) * root.scaleFactor)
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
                    columnSpacing: Math.round((root.compact ? 0 : 2) * root.scaleFactor)
                    rowSpacing: Math.round((root.compact ? 0 : 3) * root.scaleFactor)

                    Repeater {
                        model: root.monthCells()
                        Item {
                            id: dayCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            // hidden, not gone: a layout closes the gap of an invisible cell and the 1st slid to Monday
                            opacity: dayCell.modelData.currentMonth || root.showAdjacentDays ? 1 : 0
                            readonly property bool pickable: root.picks && Boolean(dayCell.modelData.date)
                            readonly property bool chosen: root.samePicked(dayCell.modelData.date)

                            HoverHandler {
                                id: dayHover
                                enabled: dayCell.pickable
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                enabled: dayCell.pickable
                                onTapped: root.pick(dayCell.modelData.date)
                            }
                            // chosen is the tonal fill, hover the M3 state layer; today keeps its own shape
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height, Math.round(36 * root.scaleFactor))
                                height: width
                                radius: width / 2
                                visible: !dayCell.modelData.isToday && (dayCell.chosen || dayHover.hovered)
                                color: dayCell.chosen ? root.pickFace : ColorUtils.applyAlpha(root.ink, 0.08)
                            }

                            // Today wears one of M3 Expressive's shapes, filled in the accent.
                            MaterialShape {
                                anchors.centerIn: parent
                                visible: !root.instrument && dayCell.modelData.isToday
                                // a size over the cell reads round, but a gapless small month has no room for it
                                implicitSize: Math.round(Math.min(parent.width, parent.height, Math.round(36 * root.scaleFactor)) * (root.compact ? 1 : 1.1))
                                shape: MaterialShape.Shape.Pentagon
                                color: root.todayFace
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height, Math.round(36 * root.scaleFactor))
                                height: width
                                radius: Appearance.rounding.full
                                // Instrument: today is a signal mark — hairline accent
                                // ring with accent ink, not a filled pill.
                                color: "transparent"
                                border.width: root.instrument && dayCell.modelData.isToday
                                    ? Math.max(1.5, Math.round(1.5 * root.scaleFactor)) : 0
                                border.color: root.accentMark

                                StyledText {
                                    id: dayNumber
                                    anchors.centerIn: parent
                                    text: dayCell.modelData.day
                                    // the next month's days step back to the quiet ink (3:1 on the wallpaper), not to 32 %
                                    color: dayCell.modelData.isToday ? root.accentMarkInk
                                        : dayCell.chosen ? root.pickInk
                                        : dayCell.modelData.currentMonth ? root.ink : root.widgetInkSubtle
                                    font.pixelSize: Math.round((root.compact ? Appearance.font.pixelSize.smaller
                                        : root.strip ? Appearance.font.pixelSize.large : Appearance.font.pixelSize.small) * root.scaleFactor)
                                    font.weight: dayCell.modelData.isToday ? Font.Bold : Font.Normal
                                    font.family: root.widgetNumbersFamily
                                }
                                Rectangle {
                                    visible: dayCell.modelData.marked === true
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    // under the figures' baseline: pinned to the cell's foot, a small month's dot sat on the 31
                                    y: dayNumber.y + dayNumber.baselineOffset + Math.max(2, Math.round(2 * root.scaleFactor))
                                    width: Math.max(3, Math.round(4 * root.scaleFactor))
                                    height: width
                                    radius: width / 2
                                    color: dayCell.modelData.isToday ? root.accentMarkInk : dayCell.chosen ? root.pickInk : root.widgetAccentVisible
                                    opacity: dayCell.modelData.currentMonth ? 1 : 0.32
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
