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

AbstractBackgroundWidget {
    id: root

    configEntryName: "monthCalendar"
    defaultConfig: ({
        placementStrategy: "free",
        contentWidth: 300, contentHeight: 340,
        weekStart: 1, showAdjacentDays: true,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.14, borderWidth: 1, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 420, y: 120
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 300) * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 340) * root.scaleFactor)
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
            spacing: 6
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4
                Repeater {
                    model: [
                        { label: "Monday", value: 1 },
                        { label: "Sunday", value: 0 }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: Translation.tr(modelData.label)
                        toggled: root.weekStart === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.monthCalendar.weekStart", modelData.value)
                    }
                }
            }
            SelectionGroupButton {
                Layout.alignment: Qt.AlignHCenter
                leftmost: true; rightmost: true
                buttonIcon: "date_range"
                buttonText: Translation.tr("Adjacent days")
                toggled: root.showAdjacentDays
                onClicked: Config.setNestedValue("background.widgets.monthCalendar.showAdjacentDays", !root.showAdjacentDays)
            }
        }
    }

    WidgetSurface {
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
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(8 * root.scaleFactor)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(5 * root.scaleFactor)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM")
                    color: root.widgetSurfaceInk
                    font.pixelSize: Math.round(Appearance.font.pixelSize.larger * root.scaleFactor)
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: String(root.viewingDate.getFullYear())
                    color: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.58)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
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
                    Layout.preferredWidth: Math.round(32 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(32 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: modelData.delta === 0 && root.monthShift === 0
                        ? root.accentFace : "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.08)
                    colRipple: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.12)
                    releaseAction: () => {
                        if (modelData.delta === 0) root.monthShift = 0
                        else root.monthShift += modelData.delta
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: Math.round(17 * root.scaleFactor)
                        color: modelData.delta === 0 && root.monthShift === 0
                            ? root.accentInk : root.widgetSurfaceInk
                    }
                    StyledToolTip { text: Translation.tr(modelData.tip) }
                }
            }
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
                    color: ColorUtils.applyAlpha(root.widgetSurfaceInk, 0.56)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: Font.DemiBold
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
                        color: dayCell.modelData.isToday ? root.accentFace : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: dayCell.modelData.day
                            color: dayCell.modelData.isToday ? root.accentInk : root.widgetSurfaceInk
                            opacity: dayCell.modelData.currentMonth ? 1 : 0.32
                            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                            font.weight: dayCell.modelData.isToday ? Font.Bold : Font.Normal
                            font.family: Appearance.font.family.numbers
                        }
                    }
                }
            }
        }
    }
}
