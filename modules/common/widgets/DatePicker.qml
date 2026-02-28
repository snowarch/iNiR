pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    // API
    property date selectedDate: new Date()
    signal dateSelected(date date)

    // Internal
    property int monthShift: 0
    property var viewingDate: {
        const d = new Date()
        d.setMonth(d.getMonth() + root.monthShift)
        d.setDate(1)
        return d
    }

    property var locale: {
        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }

    property int firstDayOfWeek: locale?.firstDayOfWeek ?? 1

    // Calendar layout calculation
    property var calendarLayout: {
        const dateObj = root.viewingDate
        const highlight = root.monthShift === 0
        const fdow = root.firstDayOfWeek
        
        const weekday = (dateObj.getDay() - fdow + 7) % 7
        const day = dateObj.getDate()
        const month = dateObj.getMonth() + 1
        const year = dateObj.getFullYear()
        const weekdayOfMonthFirst = (weekday + 35 - (day - 1)) % 7
        const daysInMonth = new Date(year, month, 0).getDate()
        const daysInPrevMonth = new Date(year, month - 1, 0).getDate()
        
        const calendar = [...Array(6)].map(() => Array(7))
        let toFill, dim, monthDiff
        
        if (weekdayOfMonthFirst === 0) {
            toFill = 1
            dim = daysInMonth
            monthDiff = 0
        } else {
            toFill = daysInPrevMonth - (weekdayOfMonthFirst - 1)
            dim = daysInPrevMonth
            monthDiff = -1
        }
        
        const selectedDay = root.selectedDate.getDate()
        const selectedMonth = root.selectedDate.getMonth() + 1
        const selectedYear = root.selectedDate.getFullYear()
        
        for (let i = 0; i < 6; i++) {
            for (let j = 0; j < 7; j++) {
                const isSelected = toFill === selectedDay && monthDiff === 0 && 
                    month === selectedMonth && year === selectedYear
                const isToday = toFill === new Date().getDate() && monthDiff === 0 && highlight
                
                calendar[i][j] = {
                    day: toFill,
                    isCurrentMonth: monthDiff === 0,
                    isToday: isToday,
                    isSelected: isSelected,
                    month: monthDiff === 0 ? month : (monthDiff === -1 ? month - 1 || 12 : month + 1),
                    year: monthDiff === 0 ? year : (monthDiff === -1 ? (month === 1 ? year - 1 : year) : (month === 12 ? year + 1 : year))
                }
                
                toFill++
                if (toFill > dim) {
                    monthDiff++
                    if (monthDiff === 0) dim = daysInMonth
                    else if (monthDiff === 1) dim = new Date(year, month + 1, 0).getDate()
                    toFill = 1
                }
            }
        }
        return calendar
    }

    property list<var> weekDaysModel: {
        const fdow = root.firstDayOfWeek
        const days = []
        for (let i = 0; i < 7; i++) {
            const d = new Date(2024, 0, fdow + i + 1) // Use a known week
            days.push(locale.toString(d, "ddd"))
        }
        return days
    }

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colOnPrimary: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color colLayer2: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.colors.colLayer2
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    implicitWidth: calendarColumn.implicitWidth + 16
    implicitHeight: calendarColumn.implicitHeight + 16

    ColumnLayout {
        id: calendarColumn
        anchors.fill: parent
        spacing: 8

        // Header with month/year and navigation
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Month/Year
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: locale.toString(root.viewingDate, "MMMM yyyy")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.colText
                }
            }

            // Navigation
            RowLayout {
                spacing: 4

                // Today button
                Rectangle {
                    visible: root.monthShift !== 0
                    implicitWidth: todayBtn.implicitWidth + 8
                    implicitHeight: 28
                    radius: root.radius
                    color: todayBtnMA.containsMouse ? root.colLayer2 : "transparent"

                    StyledText {
                        id: todayBtn
                        anchors.centerIn: parent
                        text: Translation.tr("Today")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.colPrimary
                    }

                    MouseArea {
                        id: todayBtnMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthShift = 0
                    }
                }

                // Prev/Next buttons
                Repeater {
                    model: [{ icon: "chevron_left", action: -1 }, { icon: "chevron_right", action: 1 }]

                    delegate: Rectangle {
                        id: navButton
                        required property var modelData
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: root.radius
                        color: navMA.containsMouse ? root.colLayer2 : "transparent"

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: navButton.modelData.icon
                            iconSize: 18
                            color: root.colTextSecondary
                        }

                        MouseArea {
                            id: navMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift += navButton.modelData.action
                        }
                    }
                }
            }
        }

        // Week days header
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Repeater {
                model: root.weekDaysModel

                delegate: StyledText {
                    required property string modelData
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: root.colTextSecondary
                }
            }
        }

        // Calendar grid
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Repeater {
                model: 6

                delegate: RowLayout {
                    required property int index
                    property int weekRow: index
                    spacing: 2

                    Repeater {
                        model: 7

                        delegate: Rectangle {
                            required property int index
                            property var cellData: root.calendarLayout?.[parent.weekRow]?.[index] ?? {}

                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16

                            color: {
                                if (cellData.isSelected) return root.colPrimary
                                if (cellData.isToday) return root.colLayer2
                                return "transparent"
                            }

                            border.width: cellData.isToday && !cellData.isSelected ? 1 : 0
                            border.color: root.colPrimary

                            StyledText {
                                anchors.centerIn: parent
                                text: cellData.day
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: cellData.isToday || cellData.isSelected ? Font.DemiBold : Font.Normal
                                color: {
                                    if (cellData.isSelected) return root.colOnPrimary
                                    if (!cellData.isCurrentMonth) return root.colTextSecondary
                                    return root.colText
                                }
                                opacity: cellData.isCurrentMonth ? 1 : 0.5
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    const newDate = new Date(cellData.year, cellData.month - 1, cellData.day)
                                    root.selectedDate = newDate
                                    root.dateSelected(newDate)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
