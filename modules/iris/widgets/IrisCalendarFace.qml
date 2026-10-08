pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property var today: DateTime.clock.date
    readonly property var viewing: root.widget.viewingDate
    readonly property bool browsing: root.widget.monthShift !== 0
    readonly property bool adjacent: root.widget.showAdjacentDays
    readonly property var upcoming: IrisFaceData.upcomingEvents(root.today, 7)
    readonly property var nextEvent: root.upcoming[0] ?? null
    readonly property string weekday: IrisFaceData.capitalized(Translation.locale.toString(root.today, "dddd"))
    readonly property string monthName: IrisFaceData.capitalized(Translation.locale.standaloneMonthName(root.viewing.getMonth()))

    component MonthGrid: ColumnLayout {
        id: grid
        property real cellText: 10.5
        property bool dots: false
        property bool header: true
        spacing: root.dp(2)

        RowLayout {
            visible: grid.header
            Layout.fillWidth: true
            spacing: root.dp(4)
            FaceText {
                face: root
                text: root.monthName
                color: root.highlight
                size: grid.cellText + 2
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.viewing.getFullYear() !== root.today.getFullYear()
                text: root.viewing.getFullYear()
                color: root.inkTertiary
                size: grid.cellText + 2
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0
            Repeater {
                model: 7
                FaceText {
                    required property int index
                    face: root
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.locale.dayName((root.widget.weekStart + index) % 7, Locale.NarrowFormat).toUpperCase()
                    color: root.inkTertiary
                    size: grid.cellText - 1
                    weight: Font.DemiBold
                }
            }
            Repeater {
                model: root.widget.monthCells()
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var date: new Date(root.viewing.getFullYear(), root.viewing.getMonth()
                        + (cell.modelData.currentMonth ? 0 : cell.index < 7 ? -1 : 1), cell.modelData.day)
                    readonly property bool busy: grid.dots && cell.modelData.currentMonth
                        && IrisFaceData.hasEvents(cell.date)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.9
                        height: width
                        radius: width / 2
                        visible: cell.modelData.isToday
                        color: root.highlight
                    }
                    FaceText {
                        face: root
                        anchors.centerIn: parent
                        visible: cell.modelData.currentMonth || root.adjacent
                        text: cell.modelData.day
                        color: cell.modelData.isToday ? root.onFill(root.highlight)
                            : cell.modelData.currentMonth ? root.ink : root.inkTertiary
                        size: grid.cellText
                        weight: cell.modelData.isToday ? Font.Bold : Font.Medium
                        font.family: root.fontNumbers
                        font.features: ({ "tnum": 1 })
                    }
                    Rectangle {
                        visible: cell.busy && !cell.modelData.isToday
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: root.dp(4)
                        height: width
                        radius: width / 2
                        color: root.accent
                    }
                }
            }
        }
    }

    component EventLine: RowLayout {
        id: line
        property var event: null
        spacing: root.dp(8)
        Rectangle {
            Layout.preferredWidth: root.dp(3)
            Layout.fillHeight: true
            radius: width / 2
            color: IrisFaceData.eventTint(line.event, root.accent)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.eventTitle(line.event)
                size: 12.5
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.eventWhen(line.event, root.today)
                color: root.inkSecondary
                size: 11.5
            }
        }
    }

    MonthGrid {
        visible: root.small
        anchors.fill: parent
        cellText: 10
    }

    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(14)

        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.36
            Layout.maximumWidth: root.contentWidth * 0.36
            Layout.fillHeight: true
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.weekday
                color: root.highlight
                size: 13
                weight: Font.DemiBold
            }
            FaceFigure {
                face: root
                Layout.fillWidth: true
                text: root.today.getDate()
                size: 46
            }
            Item { Layout.fillHeight: true }
            EventLine {
                visible: root.nextEvent !== null
                Layout.fillWidth: true
                event: root.nextEvent
            }
            FaceText {
                face: root
                visible: root.nextEvent === null
                Layout.fillWidth: true
                text: Translation.tr("No events this week")
                color: root.inkTertiary
                size: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }
        }
        MonthGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellText: 10
            dots: true
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(8)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(4)
            FaceText {
                face: root
                text: root.monthName
                color: root.highlight
                size: 18
                weight: Font.Bold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.viewing.getFullYear()
                color: root.inkTertiary
                size: 18
                weight: Font.Medium
            }
            Repeater {
                model: [
                    { glyph: "today", shift: 0, shown: root.browsing, name: Translation.tr("Today") },
                    { glyph: "chevron_left", shift: -1, shown: true, name: Translation.tr("Previous month") },
                    { glyph: "chevron_right", shift: 1, shown: true, name: Translation.tr("Next month") }
                ]
                Rectangle {
                    id: navButton
                    required property var modelData
                    visible: navButton.modelData.shown
                    Layout.preferredWidth: root.dp(28)
                    Layout.preferredHeight: root.dp(28)
                    radius: width / 2
                    color: navHover.hovered ? root.fillHover : root.fillQuiet
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: navButton.modelData.glyph
                        iconSize: root.px(18)
                        color: root.inkSecondary
                    }
                    HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.widget.monthShift = navButton.modelData.shift === 0 ? 0
                            : root.widget.monthShift + navButton.modelData.shift
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: navButton.modelData.name
                }
            }
        }
        MonthGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            header: false
            cellText: 13.5
            dots: true
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.hairline
        }
        EventLine {
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            visible: root.nextEvent !== null
            event: root.nextEvent
        }
        FaceText {
            face: root
            visible: root.nextEvent === null
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            text: Translation.tr("No events this week")
            color: root.inkTertiary
            size: 12.5
        }
    }
}
