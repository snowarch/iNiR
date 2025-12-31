import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Rectangle {
    id: root
    
    color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
         : Appearance.colors.colLayer1
    border.width: Appearance.inirEverywhere ? 1 : 0
    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    radius: Appearance.rounding.normal
    implicitHeight: mainColumn.implicitHeight + 20
    
    property var locale: {
        const envLocale = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (envLocale.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }
    
    property int monthShift: 0
    property var viewingDate: getDateInXMonthsTime(monthShift)
    property var calendarLayout: getCalendarLayout(viewingDate, monthShift === 0)
    
    function getDateInXMonthsTime(months) {
        const now = new Date()
        return new Date(now.getFullYear(), now.getMonth() + months, 1)
    }
    
    function getCalendarLayout(date, isCurrentMonth) {
        const fdow = locale?.firstDayOfWeek ?? Qt.locale().firstDayOfWeek
        const year = date.getFullYear()
        const month = date.getMonth()
        const firstDay = new Date(year, month, 1)
        const lastDay = new Date(year, month + 1, 0)
        const today = new Date()
        
        let startOffset = firstDay.getDay() - fdow
        if (startOffset < 0) startOffset += 7
        
        const layout = []
        let currentDate = new Date(firstDay)
        currentDate.setDate(1 - startOffset)
        
        for (let week = 0; week < 6; week++) {
            const weekDays = []
            for (let day = 0; day < 7; day++) {
                const isInCurrentMonth = currentDate.getMonth() === month
                const isToday = isInCurrentMonth && 
                    currentDate.getDate() === today.getDate() &&
                    currentDate.getMonth() === today.getMonth() &&
                    currentDate.getFullYear() === today.getFullYear()
                
                weekDays.push({
                    day: currentDate.getDate(),
                    today: isToday ? 1 : 0,
                    dimmed: !isInCurrentMonth
                })
                currentDate.setDate(currentDate.getDate() + 1)
            }
            layout.push(weekDays)
        }
        return layout
    }
    
    property list<var> weekDaysModel: {
        const fdow = locale?.firstDayOfWeek ?? Qt.locale().firstDayOfWeek
        const first = DateUtils.getFirstDayOfWeek(new Date(), fdow)
        const days = []
        for (let i = 0; i < 7; i++) {
            const d = new Date(first)
            d.setDate(first.getDate() + i)
            days.push({
                label: locale.toString(d, "ddd").substring(0, 2),
                today: DateUtils.sameDate(d, DateTime.clock.date)
            })
        }
        return days
    }
    
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            if (event.angleDelta.y > 0) monthShift--
            else if (event.angleDelta.y < 0) monthShift++
        }
    }
    
    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            
            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                downAction: () => root.monthShift--
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
            
            Item { Layout.fillWidth: true }
            
            StyledText {
                text: (monthShift !== 0 ? "• " : "") + locale.toString(viewingDate, "MMMM yyyy")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: monthShift !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (monthShift !== 0) monthShift = 0
                }
            }
            
            Item { Layout.fillWidth: true }
            
            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2
                downAction: () => root.monthShift++
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        
        // Week days header
        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            
            Repeater {
                model: weekDaysModel
                
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.Medium
                        color: modelData.today ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    }
                }
            }
        }
        
        // Calendar grid
        Repeater {
            model: 6
            
            RowLayout {
                required property int index
                Layout.fillWidth: true
                spacing: 2
                
                Repeater {
                    model: 7
                    
                    Rectangle {
                        required property int index
                        property var dayData: root.calendarLayout[parent.index]?.[index] ?? { day: 0, today: 0, dimmed: true }
                        
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                        radius: width / 2
                        color: dayData.today ? Appearance.colors.colPrimary : "transparent"
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: dayData.day
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: dayData.today ? Font.Bold : Font.Normal
                            color: {
                                if (dayData.today) return Appearance.colors.colOnPrimary
                                if (dayData.dimmed) return Appearance.colors.colOutline
                                return Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }
    }
}
