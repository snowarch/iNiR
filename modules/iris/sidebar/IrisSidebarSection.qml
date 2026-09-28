pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

Loader {
    id: root
    required property string kind
    property bool contentActive: true
    property bool expanded: false
    property bool bare: false
    property bool morphing: false
    readonly property real d: IrisStyle.density
    signal navigate()
    signal toggleRequested()
    sourceComponent: {
        switch (root.kind) {
        case "media": return mediaComponent
        case "tasks": return tasksComponent
        case "notes": return notesComponent
        case "calendar": return calendarComponent
        case "weather": return weatherComponent
        case "notifications": return notificationsComponent
        case "focus": return focusComponent
        case "mixer": return mixerComponent
        case "system": return systemComponent
        default: return null
        }
    }

    component EmptyLabel: IrisText {
        Layout.fillWidth: true
        color: IrisStyle.muted
        wrapMode: Text.WordWrap
        font.pixelSize: IrisStyle.typeMeta
    }

    component Section: Rectangle {
        id: section
        property string title
        property string detail: ""
        property string glyph: ""
        property color tint: IrisStyle.accent
        property color ink: IrisStyle.text
        property bool expandable: true
        readonly property bool open: !section.expandable || root.expanded || root.bare
        default property alias content: body.data
        property alias summary: summaryColumn.data
        property alias actions: actionRow.data
        readonly property real pad: Math.round(14 * root.d)
        readonly property real gap: Math.round(10 * root.d)
        readonly property real innerHeight: section.open ? body.implicitHeight : summaryColumn.implicitHeight
        property real shownHeight: header.height + section.pad * 2 + (section.innerHeight > 0 ? section.gap + section.innerHeight : 0)
        property bool animate: false
        Component.onCompleted: Qt.callLater(() => section.animate = true)
        Behavior on shownHeight {
            enabled: section.animate
            NumberAnimation { id: morph; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }
        Binding { target: root; property: "morphing"; value: morph.running }
        implicitHeight: section.shownHeight
        radius: root.bare ? 0 : IrisStyle.radiusCard
        color: root.bare ? "transparent" : IrisStyle.surfaceHigh
        clip: true

        MouseArea {
            id: header
            x: section.pad
            y: section.pad
            width: section.width - section.pad * 2
            height: Math.round(26 * root.d)
            enabled: section.expandable && !root.bare
            cursorShape: section.expandable && !root.bare ? Qt.PointingHandCursor : Qt.ArrowCursor
            Accessible.role: Accessible.Button
            Accessible.name: section.title
            onClicked: root.toggleRequested()
            RowLayout {
                anchors.fill: parent
                spacing: 8 * root.d
                Rectangle {
                    visible: section.glyph.length > 0
                    implicitWidth: Math.round(24 * root.d)
                    implicitHeight: implicitWidth
                    radius: IrisStyle.iconRadius(width)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(section.tint, 1.2) }
                        GradientStop { position: 1; color: section.tint }
                    }
                    MaterialSymbol { anchors.centerIn: parent; text: section.glyph; fill: 1; iconSize: Math.round(15 * root.d); color: IrisStyle.onTint }
                }
                IrisText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: section.title
                    color: section.ink
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    font.pixelSize: IrisStyle.typeBody
                    elide: Text.ElideRight
                }
                IrisText {
                    visible: text.length > 0
                    text: section.detail
                    color: IrisStyle.secondaryOf(section.ink)
                    font.family: IrisStyle.fontNumbers
                    font.pixelSize: IrisStyle.typeMeta
                }
                RowLayout {
                    id: actionRow
                    spacing: 0
                    visible: section.open
                }
                MaterialSymbol {
                    visible: section.expandable && !root.bare
                    text: "keyboard_arrow_down"
                    iconSize: Math.round(18 * root.d)
                    color: IrisStyle.secondaryOf(section.ink)
                    rotation: section.open ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                }
            }
        }
        ColumnLayout {
            id: summaryColumn
            x: section.pad
            y: header.y + header.height + section.gap
            width: section.width - section.pad * 2
            spacing: 6 * root.d
            opacity: section.open ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(section.open ? 90 : 180); easing.type: IrisStyle.feedbackEasing } }
        }
        ColumnLayout {
            id: body
            x: section.pad
            y: header.y + header.height + section.gap
            width: section.width - section.pad * 2
            spacing: 10 * root.d
            opacity: section.open ? 1 : 0
            visible: opacity > 0
            enabled: section.open
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(section.open ? 200 : 90); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    component NoticeCard: Rectangle {
        id: notice
        required property var notification
        property int hidden: 0
        signal unfold()
        implicitHeight: noticeBody.implicitHeight + 20 * root.d
        radius: IrisStyle.radiusRow
        color: IrisStyle.surfaceHighest

        TapHandler {
            enabled: notice.hidden > 0
            onTapped: notice.unfold()
        }
        HoverHandler {
            enabled: notice.hidden > 0
            cursorShape: Qt.PointingHandCursor
        }

        ColumnLayout {
            id: noticeBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10 * root.d
            spacing: 3 * root.d
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.d
                IrisNotificationIcon {
                    size: Math.round(22 * root.d)
                    showImage: false
                    appName: String(notice.notification?.appName ?? "")
                    appIcon: String(notice.notification?.appIcon ?? "")
                    summary: String(notice.notification?.summary ?? "")
                    critical: String(notice.notification?.urgency ?? "") === "critical"
                }
                IrisText { Layout.fillWidth: true; text: String(notice.notification?.appName ?? ""); role: IrisText.Meta; elide: Text.ElideRight }
                Rectangle {
                    visible: notice.hidden > 0
                    implicitHeight: Math.round(20 * root.d)
                    implicitWidth: Math.max(implicitHeight, moreLabel.implicitWidth + Math.round(12 * root.d))
                    radius: height / 2
                    color: IrisStyle.fillHover
                    IrisText {
                        id: moreLabel
                        anchors.centerIn: parent
                        text: "+" + notice.hidden
                        font.family: IrisStyle.fontNumbers
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
                IrisIconButton {
                    materialIcon: "close"
                    iconSize: Math.round(15 * root.d)
                    Accessible.name: Translation.tr("Dismiss notification")
                    onClicked: Notifications.discardNotification(notice.notification.notificationId)
                }
            }
            IrisText { Layout.fillWidth: true; text: String(notice.notification?.summary ?? ""); textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; font.weight: IrisStyle.weight(Font.DemiBold) }
            IrisText { Layout.fillWidth: true; visible: text.length > 0; text: String(notice.notification?.body ?? ""); textFormat: Text.PlainText; wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight; role: IrisText.Meta }
            Flow {
                Layout.fillWidth: true
                visible: (notice.notification?.actions ?? []).length > 0
                spacing: 4 * root.d
                Repeater {
                    model: notice.notification?.actions ?? []
                    IrisButton {
                        required property var modelData
                        text: modelData.identifier === "default" ? Translation.tr("Open") : modelData.text
                        implicitHeight: 30 * root.d
                        onClicked: { Notifications.attemptInvokeAction(notice.notification.notificationId, modelData.identifier); root.navigate() }
                    }
                }
            }
        }
    }

    component NoticeStack: ColumnLayout {
        id: stack
        required property string appName
        property bool unfolded: false
        signal toggle()
        readonly property var items: (Notifications.groupsByAppName[stack.appName]?.notifications ?? []).slice().reverse()
        readonly property int count: stack.items.length
        readonly property bool folded: stack.count > 1 && !stack.unfolded
        spacing: 6 * root.d

        RowLayout {
            visible: stack.count > 1 && stack.unfolded
            Layout.fillWidth: true
            Layout.leftMargin: 4 * root.d
            spacing: 4 * root.d
            IrisText { Layout.fillWidth: true; text: stack.appName; font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeLabel; elide: Text.ElideRight }
            IrisButton {
                text: Translation.tr("Show less")
                quiet: true
                implicitHeight: 26 * root.d
                onClicked: stack.toggle()
            }
            IrisIconButton {
                materialIcon: "clear_all"
                iconSize: Math.round(16 * root.d)
                Accessible.name: Translation.tr("Clear %1").arg(stack.appName)
                onClicked: Notifications.discardNotificationsForApp(stack.appName)
            }
        }

        Repeater {
            model: stack.folded ? stack.items.slice(0, 1) : stack.items
            NoticeCard {
                required property var modelData
                Layout.fillWidth: true
                notification: modelData
                hidden: stack.folded ? stack.count - 1 : 0
                onUnfold: stack.toggle()
            }
        }

        // Only what shows below the card is drawn: under a translucent material a plate tucked behind
        // the card reads through it and the stack looks mixed into the card.
        Item {
            visible: stack.folded
            clip: true
            Layout.fillWidth: true
            Layout.topMargin: -stack.spacing
            implicitHeight: Math.round((stack.count > 2 ? 12 : 6) * root.d)
            Rectangle {
                visible: stack.count > 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width - Math.round(28 * root.d)
                height: IrisStyle.radiusRow * 2
                radius: IrisStyle.radiusRow
                color: ColorUtils.mix(IrisStyle.surfaceHighest, IrisStyle.surfaceHigh, 0.7)
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: stack.count > 2 ? Math.round(6 * root.d) : 0
                width: parent.width - Math.round(14 * root.d)
                height: IrisStyle.radiusRow * 2
                radius: IrisStyle.radiusRow
                color: ColorUtils.mix(IrisStyle.surfaceHighest, IrisStyle.surfaceHigh, 0.4)
            }
            TapHandler { onTapped: stack.toggle() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    component GaugeRing: Shape {
        id: gaugeRing
        property real progress: 0
        property color tint: IrisStyle.accent
        property real stroke: Math.round(5 * root.d)
        property real start: -90
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.tintFill(gaugeRing.tint)
            strokeWidth: gaugeRing.stroke
            fillColor: "transparent"
            PathAngleArc { centerX: gaugeRing.width / 2; centerY: gaugeRing.height / 2; radiusX: gaugeRing.width / 2 - gaugeRing.stroke / 2; radiusY: gaugeRing.width / 2 - gaugeRing.stroke / 2; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: gaugeRing.tint
            strokeWidth: gaugeRing.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: gaugeRing.width / 2; centerY: gaugeRing.height / 2; radiusX: gaugeRing.width / 2 - gaugeRing.stroke / 2; radiusY: gaugeRing.width / 2 - gaugeRing.stroke / 2; startAngle: gaugeRing.start; sweepAngle: 360 * Math.max(0, Math.min(1, gaugeRing.progress)) }
        }
    }

    Component {
        id: mediaComponent
        Item {
            id: mediaHost
            property bool animate: false
            Component.onCompleted: Qt.callLater(() => mediaHost.animate = true)
            implicitHeight: mediaCard.implicitHeight
            Behavior on implicitHeight {
                enabled: mediaHost.animate
                NumberAnimation { id: mediaMorph; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
            }
            Binding { target: root; property: "morphing"; value: mediaMorph.running }
            clip: true
            IrisMediaCard {
                id: mediaCard
                width: parent.width
                active: root.contentActive
                showBackground: true
                compact: !root.expanded
            }
            MouseArea {
                visible: !root.expanded
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * 0.55
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: Translation.tr("Full player")
                onClicked: root.toggleRequested()
            }
            IrisIconButton {
                visible: root.expanded
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8 * root.d
                materialIcon: "unfold_less"
                iconSize: Math.round(16 * root.d)
                Accessible.name: root.expanded ? Translation.tr("Compact player") : Translation.tr("Full player")
                onClicked: root.toggleRequested()
            }
        }
    }

    Component {
        id: tasksComponent
        Section {
            id: tasks
            property bool showCompleted: false
            readonly property var pending: Todo.list.map((task, index) => ({ task: task, index: index })).filter(entry => !entry.task.done)
            readonly property var entries: Todo.list.map((task, index) => ({ task: task, index: index }))
                .filter(entry => tasks.showCompleted || !entry.task.done)
            title: Translation.tr("Tasks")
            glyph: "checklist"
            tint: IrisStyle.identity.orange
            detail: tasks.pending.length > 0 ? String(tasks.pending.length) : ""
            actions: IrisIconButton {
                materialIcon: "done_all"
                selected: tasks.showCompleted
                Accessible.name: Translation.tr("Show completed tasks")
                onClicked: tasks.showCompleted = !tasks.showCompleted
            }
            summary: [
                EmptyLabel { visible: tasks.pending.length === 0; text: Translation.tr("A clear list.") },
                Repeater {
                    model: tasks.pending.slice(0, 2)
                    RowLayout {
                        id: pendingRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8 * root.d
                        Rectangle {
                            implicitWidth: Math.round(12 * root.d)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: "transparent"
                            border.width: Math.max(1, Math.round(1.5 * root.d))
                            border.color: IrisStyle.identity.orange
                        }
                        IrisText { Layout.fillWidth: true; text: pendingRow.modelData.task.content; textFormat: Text.PlainText; elide: Text.ElideRight; font.pixelSize: IrisStyle.typeLabel }
                    }
                }
            ]
            RowLayout {
                Layout.fillWidth: true
                IrisField {
                    id: taskInput
                    Layout.fillWidth: true
                    implicitHeight: 38 * root.d
                    topPadding: 8 * root.d
                    bottomPadding: 8 * root.d
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: Translation.tr("Add a task…")
                    font.pixelSize: IrisStyle.typeLabel
                    onAccepted: { if (text.trim()) { Todo.addTask(text.trim()); clear() } }
                }
                IrisIconButton {
                    materialIcon: "add"
                    enabled: taskInput.text.trim().length > 0
                    Accessible.name: Translation.tr("Add task")
                    onClicked: { Todo.addTask(taskInput.text.trim()); taskInput.clear(); taskInput.forceActiveFocus() }
                }
            }
            EmptyLabel { visible: tasks.entries.length === 0; text: Translation.tr("A clear list. Room for what matters next.") }
            Repeater {
                model: tasks.entries
                RowLayout {
                    id: taskRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 8 * root.d
                    IrisIconButton {
                        materialIcon: taskRow.modelData.task.done ? "check_circle" : "radio_button_unchecked"
                        selected: taskRow.modelData.task.done
                        Accessible.name: taskRow.modelData.task.content
                        onClicked: {
                            if (taskRow.modelData.task.done) Todo.markUnfinished(taskRow.modelData.index)
                            else Todo.markDone(taskRow.modelData.index)
                        }
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: taskRow.modelData.task.content
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.pixelSize: IrisStyle.typeLabel
                        font.strikeout: taskRow.modelData.task.done
                        color: taskRow.modelData.task.done ? IrisStyle.muted : IrisStyle.text
                    }
                }
            }
        }
    }

    Component {
        id: notesComponent
        Section {
            id: notes
            property bool loadingTab: false
            function loadTab(): void {
                notes.loadingTab = true
                noteEditor.text = Notepad.text
                noteTitle.text = Notepad.tabs[Notepad.currentTab]?.title ?? ""
                notes.loadingTab = false
            }
            Component.onCompleted: notes.loadTab()
            Connections {
                target: Notepad
                function onCurrentTabChanged(): void { notes.loadTab() }
                function onTabsChanged(): void { if (noteEditor.text !== Notepad.text) notes.loadTab() }
            }
            title: Translation.tr("Notes")
            glyph: "sticky_note_2"
            tint: IrisStyle.identity.yellow
            detail: Notepad.tabs.length > 1 ? String(Notepad.tabs.length) : ""
            actions: IrisIconButton {
                materialIcon: "add"
                Accessible.name: Translation.tr("New note")
                onClicked: { Notepad.addTab(""); noteEditor.forceActiveFocus() }
            }
            summary: [
                IrisText {
                    Layout.fillWidth: true
                    text: Notepad.tabs[Notepad.currentTab]?.title || Translation.tr("Untitled")
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    font.pixelSize: IrisStyle.typeLabel
                    elide: Text.ElideRight
                },
                IrisText {
                    Layout.fillWidth: true
                    text: String(Notepad.text ?? "").trim() || Translation.tr("Write something to keep…")
                    textFormat: Text.PlainText
                    color: IrisStyle.muted
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeMeta
                }
            ]
            Flickable {
                Layout.fillWidth: true
                visible: Notepad.tabs.length > 1
                implicitHeight: tabs.implicitHeight
                contentWidth: tabs.implicitWidth
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Row {
                    id: tabs
                    spacing: 4 * root.d
                    Repeater {
                        model: Notepad.tabs
                        IrisButton {
                            required property var modelData
                            required property int index
                            text: modelData.title
                            selected: index === Notepad.currentTab
                            implicitHeight: 30 * root.d
                            onClicked: Notepad.switchTab(index)
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: noteSheet.implicitHeight
                radius: IrisStyle.radiusRow
                color: IrisStyle.field
                border.width: noteTitle.activeFocus || noteEditor.activeFocus ? 1 : 0
                border.color: IrisStyle.hairlineStrong
                ColumnLayout {
                    id: noteSheet
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0
                    TextInput {
                        id: noteTitle
                        Layout.fillWidth: true
                        Layout.topMargin: 11 * root.d
                        Layout.leftMargin: 12 * root.d
                        Layout.rightMargin: 12 * root.d
                        Layout.bottomMargin: 8 * root.d
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        selectedTextColor: IrisStyle.onAccentContainer
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeBody
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        clip: true
                        Accessible.name: Translation.tr("Note title")
                        onEditingFinished: if (text.trim()) Notepad.setTabTitle(Notepad.currentTab, text.trim())
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: noteTitle.text.length === 0
                            text: Translation.tr("Title")
                            color: IrisStyle.muted
                            font: noteTitle.font
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12 * root.d
                        implicitHeight: 1
                        color: IrisStyle.hairline
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        implicitHeight: 150 * root.d
                        TextArea {
                            id: noteEditor
                            placeholderText: Translation.tr("Write something to keep…")
                            placeholderTextColor: IrisStyle.muted
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            selectedTextColor: IrisStyle.onAccentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: IrisStyle.typeLabel
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.PlainText
                            leftPadding: 12 * root.d
                            rightPadding: 12 * root.d
                            topPadding: 9 * root.d
                            bottomPadding: 10 * root.d
                            background: null
                            onTextChanged: if (!notes.loadingTab && activeFocus && text !== Notepad.text) Notepad.setTextValue(text)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: calendarComponent
        Section {
            id: calendar
            property date selectedDate: DateTime.clock.date
            property bool composing: false
            readonly property date month: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
            readonly property int weekStart: Qt.locale().firstDayOfWeek % 7
            readonly property int offset: (month.getDay() - calendar.weekStart + 7) % 7
            function eventsOn(date): var {
                Events.list; CalendarSync.events
                return Events.getAllEventsForDate(date)
                    .concat(CalendarSync.getEventsForDate(date))
                    .sort((a, b) => new Date(a.dateTime ?? a.startDate) - new Date(b.dateTime ?? b.startDate))
            }
            function timeOf(entry): string {
                return entry.allDay ? Translation.tr("All day") : Qt.formatTime(new Date(entry.dateTime ?? entry.startDate), "hh:mm")
            }
            readonly property var entries: calendar.eventsOn(calendar.selectedDate)
            readonly property var todayEntries: calendar.eventsOn(DateTime.clock.date)
            function moveMonth(delta: int): void {
                calendar.selectedDate = new Date(calendar.month.getFullYear(), calendar.month.getMonth() + delta, 1)
            }
            onOpenChanged: if (!open) calendar.composing = false

            title: Qt.locale().toString(calendar.open ? calendar.month : DateTime.clock.date, "MMMM yyyy")
            glyph: "calendar_month"
            tint: IrisStyle.identity.red
            detail: !calendar.open && calendar.todayEntries.length > 0 ? String(calendar.todayEntries.length) : ""
            actions: [
                IrisIconButton { materialIcon: "chevron_left"; Accessible.name: Translation.tr("Previous month"); onClicked: calendar.moveMonth(-1) },
                IrisIconButton { materialIcon: "today"; Accessible.name: Translation.tr("Today"); onClicked: calendar.selectedDate = DateTime.clock.date },
                IrisIconButton { materialIcon: "chevron_right"; Accessible.name: Translation.tr("Next month"); onClicked: calendar.moveMonth(1) }
            ]

            summary: [
                Row {
                    id: weekStrip
                    Layout.fillWidth: true
                    readonly property date start: {
                        const today = DateTime.clock.date
                        const shift = (today.getDay() - calendar.weekStart + 7) % 7
                        return new Date(today.getFullYear(), today.getMonth(), today.getDate() - shift)
                    }
                    Repeater {
                        model: 7
                        Column {
                            id: stripDay
                            required property int index
                            readonly property date date: new Date(weekStrip.start.getFullYear(), weekStrip.start.getMonth(), weekStrip.start.getDate() + stripDay.index)
                            readonly property bool today: stripDay.date.toDateString() === DateTime.clock.date.toDateString()
                            width: weekStrip.width / 7
                            spacing: 3 * root.d
                            IrisText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.locale().dayName(stripDay.date.getDay(), Locale.ShortFormat).slice(0, 2)
                                color: stripDay.today ? IrisStyle.identity.red : IrisStyle.muted
                                font.pixelSize: IrisStyle.typeFootnote
                                font.weight: stripDay.today ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(28 * root.d)
                                height: width
                                radius: width / 2
                                color: stripDay.today ? IrisStyle.identity.red : "transparent"
                                IrisText {
                                    anchors.centerIn: parent
                                    text: String(stripDay.date.getDate())
                                    color: stripDay.today ? IrisStyle.onTint : IrisStyle.text
                                    font.family: IrisStyle.fontNumbers
                                    font.pixelSize: IrisStyle.typeLabel
                                    font.weight: stripDay.today ? Font.Bold : Font.Medium
                                }
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(4 * root.d)
                                height: width
                                radius: width / 2
                                color: calendar.eventsOn(stripDay.date).length > 0 ? IrisStyle.secondaryAccent : "transparent"
                            }
                        }
                    }
                },
                IrisText {
                    Layout.fillWidth: true
                    text: calendar.todayEntries.length === 0 ? Translation.tr("Nothing scheduled today")
                        : calendar.timeOf(calendar.todayEntries[0]) + "  ·  " + (calendar.todayEntries[0].title ?? "")
                    color: calendar.todayEntries.length === 0 ? IrisStyle.muted : IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            ]

            GridLayout {
                id: monthGrid
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 0
                rowSpacing: 2 * root.d
                Repeater {
                    model: 7
                    Item {
                        id: weekday
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: weekdayLabel.implicitHeight
                        IrisText {
                            id: weekdayLabel
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.locale().dayName((calendar.weekStart + weekday.index) % 7, Locale.ShortFormat).slice(0, 2)
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeFootnote
                        }
                    }
                }
                Repeater {
                    model: 42
                    MouseArea {
                        id: day
                        required property int index
                        readonly property date date: new Date(calendar.month.getFullYear(), calendar.month.getMonth(), day.index - calendar.offset + 1)
                        readonly property bool today: day.date.toDateString() === DateTime.clock.date.toDateString()
                        readonly property bool chosen: day.date.toDateString() === calendar.selectedDate.toDateString()
                        readonly property bool inMonth: day.date.getMonth() === calendar.month.getMonth()
                        readonly property bool hasEvents: day.inMonth && calendar.eventsOn(day.date).length > 0
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: Math.round(34 * root.d)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Qt.formatDate(day.date, "dddd, d MMMM yyyy")
                        onClicked: calendar.selectedDate = day.date
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.round(30 * root.d)
                            height: width
                            radius: width / 2
                            color: day.today ? IrisStyle.identity.red
                                : day.chosen ? IrisStyle.tintFillHover(IrisStyle.accent)
                                : day.containsMouse ? IrisStyle.fillHover : "transparent"
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                        }
                        IrisText {
                            anchors.centerIn: parent
                            text: String(day.date.getDate())
                            color: day.today ? IrisStyle.onTint : day.chosen ? IrisStyle.accent : IrisStyle.text
                            opacity: day.inMonth ? 1 : 0.32
                            font.family: IrisStyle.fontNumbers
                            font.pixelSize: IrisStyle.typeLabel
                            font.weight: day.today || day.chosen ? Font.Bold : Font.Medium
                        }
                        Rectangle {
                            visible: day.hasEvents && !day.today
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            width: Math.round(4 * root.d)
                            height: width
                            radius: width / 2
                            color: IrisStyle.secondaryAccent
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }

            RowLayout {
                Layout.fillWidth: true
                IrisText {
                    Layout.fillWidth: true
                    text: Qt.locale().toString(calendar.selectedDate, "dddd d MMMM")
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    font.pixelSize: IrisStyle.typeLabel
                    elide: Text.ElideRight
                }
                IrisText {
                    visible: CalendarSync.fetching || (CalendarSync.enabled && CalendarSync.sources.length > 0 && !Network.online)
                    text: CalendarSync.fetching ? Translation.tr("Syncing…") : Translation.tr("Offline")
                    role: IrisText.Meta
                }
                IrisButton {
                    visible: !calendar.composing
                    text: Translation.tr("New event")
                    implicitHeight: Math.round(28 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    onClicked: { calendar.composing = true; eventTitle.forceActiveFocus() }
                }
            }
            EmptyLabel { visible: calendar.entries.length === 0 && !calendar.composing; text: Translation.tr("Nothing scheduled for this day.") }
            Repeater {
                model: calendar.entries
                RowLayout {
                    id: entryRow
                    required property var modelData
                    readonly property bool local: entryRow.modelData.dateTime !== undefined && entryRow.modelData.id !== undefined
                    Layout.fillWidth: true
                    spacing: 10 * root.d
                    IrisText {
                        Layout.preferredWidth: Math.round(44 * root.d)
                        text: calendar.timeOf(entryRow.modelData)
                        color: IrisStyle.subtext
                        font.family: IrisStyle.fontNumbers
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    Rectangle { implicitWidth: 3 * root.d; implicitHeight: Math.round(20 * root.d); radius: width / 2; color: entryRow.modelData.color || IrisStyle.secondaryAccent }
                    IrisText { Layout.fillWidth: true; text: entryRow.modelData.title ?? ""; elide: Text.ElideRight; font.weight: IrisStyle.weight(Font.Medium) }
                    IrisIconButton {
                        visible: entryRow.local
                        materialIcon: "close"
                        iconSize: Math.round(15 * root.d)
                        Accessible.name: Translation.tr("Remove event")
                        onClicked: Events.removeEvent(entryRow.modelData.id)
                    }
                }
            }

            ColumnLayout {
                id: eventSheet
                Layout.fillWidth: true
                visible: calendar.composing
                spacing: 12 * root.d
                readonly property var reminders: [
                    { label: Translation.tr("No alert"), minutes: 0 },
                    { label: "5 min", minutes: 5 },
                    { label: "15 min", minutes: 15 },
                    { label: "1 h", minutes: 60 }
                ]
                property int reminder: 15
                Connections {
                    target: calendar
                    function onComposingChanged(): void {
                        if (!calendar.composing) return
                        eventTitle.clear()
                        timePicker.hour = (DateTime.clock.date.getHours() + 1) % 24
                        timePicker.minuteIndex = 0
                        eventSheet.reminder = 15
                    }
                }
                function add(): void {
                    const title = eventTitle.text.trim()
                    if (!title) return
                    const dayDate = calendar.selectedDate
                    const when = new Date(dayDate.getFullYear(), dayDate.getMonth(), dayDate.getDate(), timePicker.hour, timePicker.minuteIndex * 5)
                    Events.addEvent(title, "", when.toISOString(), "general", "normal", eventSheet.reminder, "none")
                    calendar.composing = false
                }

                IrisField {
                    id: eventTitle
                    Layout.fillWidth: true
                    implicitHeight: Math.round(40 * root.d)
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: IrisStyle.typeBody
                    onAccepted: eventSheet.add()
                    IrisText {
                        anchors.centerIn: parent
                        visible: eventTitle.text.length === 0
                        text: Translation.tr("Event name")
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeBody
                    }
                }

                IrisWheelPicker {
                    id: timePicker
                    Layout.alignment: Qt.AlignHCenter
                    columns: [{ count: 24 }, { count: 12, step: 5 }]
                    property int hour: 0
                    property int minuteIndex: 0
                    values: [timePicker.hour, timePicker.minuteIndex]
                    onMoved: (column, index) => column === 0 ? timePicker.hour = index : timePicker.minuteIndex = index
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4 * root.d
                    Repeater {
                        model: eventSheet.reminders
                        IrisButton {
                            required property var modelData
                            text: modelData.label
                            selected: eventSheet.reminder === modelData.minutes
                            quiet: !selected
                            implicitHeight: Math.round(28 * root.d)
                            buttonRadius: height / 2
                            buttonRadiusPressed: height / 2
                            onClicked: eventSheet.reminder = modelData.minutes
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8 * root.d
                    IrisButton {
                        Layout.fillWidth: true
                        text: Translation.tr("Cancel")
                        implicitHeight: Math.round(36 * root.d)
                        buttonRadius: height / 2
                        buttonRadiusPressed: height / 2
                        onClicked: calendar.composing = false
                    }
                    IrisButton {
                        Layout.fillWidth: true
                        text: Translation.tr("Add")
                        emphasized: true
                        enabled: eventTitle.text.trim().length > 0
                        implicitHeight: Math.round(36 * root.d)
                        buttonRadius: height / 2
                        buttonRadiusPressed: height / 2
                        onClicked: eventSheet.add()
                    }
                }
            }
        }
    }

    Component {
        id: weatherComponent
        Section {
            id: weather
            readonly property bool hasData: Weather.data.temp !== "--°C" && Weather.data.temp !== "--°F"
            readonly property bool night: Weather.isNightNow()
            readonly property string condition: weather.hasData
                ? (Icons.getWeatherIcon(Weather.data.wCode, weather.night) ?? "") : ""
            glyph: weather.condition.length > 0 ? weather.condition : weather.night ? "bedtime" : "partly_cloudy_day"
            tint: weather.condition.length > 0 ? IrisStyle.skyLight(weather.condition)
                : weather.night ? IrisStyle.identity.indigo : IrisStyle.identity.blue
            ink: IrisStyle.text
            title: Weather.showVisibleCity && Weather.visibleCity ? Weather.visibleCity : Translation.tr("Weather")
            detail: !weather.open && weather.hasData ? Weather.data.temp : ""
            actions: IrisIconButton {
                materialIcon: "refresh"
                enabled: Weather.enabled && !Weather.hasRunningRequests()
                Accessible.name: Translation.tr("Refresh weather")
                onClicked: Weather.forceRefresh()
            }
            summary: IrisText {
                Layout.fillWidth: true
                text: !Weather.enabled ? Translation.tr("Weather is off")
                    : weather.hasData ? Weather.data.description + "  ·  " + Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike)
                    : Translation.tr("Fetching your forecast…")
                color: IrisStyle.strongOf(weather.ink)
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            RowLayout {
                visible: Weather.enabled && weather.hasData
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText { text: Weather.data.temp; color: IrisStyle.text; font.family: IrisStyle.fontNumbers; font.pixelSize: 44 * IrisStyle.typeScale; font.weight: IrisStyle.weight(Font.Light) }
                    IrisText { Layout.fillWidth: true; text: Weather.data.description; color: IrisStyle.textSecondary; font.pixelSize: IrisStyle.typeLabel; wrapMode: Text.WordWrap }
                }
                MaterialSymbol { text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"; fill: 1; iconSize: 46 * root.d; color: weather.night ? IrisStyle.identity.lavender : IrisStyle.secondaryAccent }
            }
            RowLayout {
                visible: Weather.enabled && weather.hasData
                Layout.fillWidth: true
                IrisText { text: Translation.tr("Feels like %1").arg(Weather.data.tempFeelsLike); color: IrisStyle.textSecondary; font.pixelSize: IrisStyle.typeMeta }
                Item { Layout.fillWidth: true }
                MaterialSymbol { text: "humidity_percentage"; fill: 1; iconSize: 14 * root.d; color: IrisStyle.textTertiary }
                IrisText { text: Weather.data.humidity; color: IrisStyle.textSecondary; font.pixelSize: IrisStyle.typeMeta }
            }
            EmptyLabel { visible: !Weather.enabled; text: Translation.tr("Enable weather in Settings to see your forecast.") }
            EmptyLabel {
                visible: Weather.enabled && !weather.hasData
                text: Weather.hasRunningRequests() ? Translation.tr("Fetching your forecast…") : Translation.tr("Weather unavailable. Try refreshing.")
            }
        }
    }

    Component {
        id: notificationsComponent
        Section {
            id: notifications
            readonly property var latest: Notifications.list.length > 0 ? Notifications.list[Notifications.list.length - 1] : null
            property var unfoldedApps: ({})
            title: Translation.tr("Notifications")
            glyph: "notifications"
            tint: IrisStyle.identity.pink
            detail: Notifications.list.length > 0 ? String(Notifications.list.length) : ""
            actions: [
                IrisIconButton {
                    materialIcon: Notifications.manualDndActive ? "notifications_off" : "notifications_active"
                    selected: Notifications.manualDndActive
                    Accessible.name: Translation.tr("Do not disturb")
                    onClicked: Notifications.toggleSilent()
                },
                IrisIconButton {
                    visible: Notifications.list.length > 0
                    materialIcon: "clear_all"
                    Accessible.name: Translation.tr("Clear all")
                    onClicked: Notifications.discardAllNotifications()
                }
            ]
            summary: [
                EmptyLabel { visible: notifications.latest === null; text: Translation.tr("You're all caught up.") },
                RowLayout {
                    Layout.fillWidth: true
                    visible: notifications.latest !== null
                    spacing: 8 * root.d
                    IrisNotificationIcon {
                        size: Math.round(22 * root.d)
                        showImage: false
                        appName: String(notifications.latest?.appName ?? "")
                        appIcon: String(notifications.latest?.appIcon ?? "")
                        summary: String(notifications.latest?.summary ?? "")
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: String(notifications.latest?.summary ?? "")
                        textFormat: Text.PlainText
                        font.weight: IrisStyle.weight(Font.Medium)
                        font.pixelSize: IrisStyle.typeLabel
                        elide: Text.ElideRight
                    }
                }
            ]
            EmptyLabel { visible: Notifications.list.length === 0; text: Translation.tr("You're all caught up.") }
            Repeater {
                model: Notifications.appNameList
                NoticeStack {
                    required property string modelData
                    Layout.fillWidth: true
                    appName: modelData
                    unfolded: notifications.unfoldedApps[modelData] === true
                    onToggle: {
                        const next = Object.assign({}, notifications.unfoldedApps)
                        next[modelData] = !next[modelData]
                        notifications.unfoldedApps = next
                    }
                }
            }
        }
    }

    Component {
        id: focusComponent
        Section {
            id: focusTimer
            readonly property bool ticking: TimerService.pomodoroRunning && !TimerService.pomodoroPaused
            readonly property int secondsLeft: TimerService.pomodoroSecondsLeft
            readonly property real progress: TimerService.pomodoroLapDuration > 0 ? 1 - focusTimer.secondsLeft / TimerService.pomodoroLapDuration : 0
            readonly property string clock: Math.floor(focusTimer.secondsLeft / 60) + ":" + String(focusTimer.secondsLeft % 60).padStart(2, "0")
            readonly property string phase: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
                : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
            readonly property color phaseTint: TimerService.pomodoroBreak ? IrisStyle.success : IrisStyle.secondaryAccent
            title: Translation.tr("Focus timer")
            glyph: "timer"
            tint: IrisStyle.identity.orange
            detail: TimerService.pomodoroRunning && !focusTimer.open ? focusTimer.clock : ""
            summary: RowLayout {
                Layout.fillWidth: true
                spacing: 10 * root.d
                GaugeRing {
                    Layout.preferredWidth: Math.round(26 * root.d)
                    Layout.preferredHeight: Layout.preferredWidth
                    stroke: Math.round(3 * root.d)
                    tint: focusTimer.phaseTint
                    progress: focusTimer.progress
                }
                IrisText {
                    text: focusTimer.clock
                    color: focusTimer.ticking ? focusTimer.phaseTint : IrisStyle.text
                    font.family: IrisStyle.fontNumbers
                    font.pixelSize: 20 * IrisStyle.typeScale
                    font.weight: IrisStyle.weight(Font.Bold)
                }
                IrisText { Layout.fillWidth: true; text: focusTimer.phase; color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
                IrisIconButton {
                    materialIcon: focusTimer.ticking ? "pause" : "play_arrow"
                    Accessible.name: focusTimer.ticking ? Translation.tr("Pause") : Translation.tr("Start")
                    onClicked: TimerService.togglePomodoro()
                }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: Math.round(132 * root.d)
                GaugeRing {
                    anchors.centerIn: parent
                    width: Math.round(128 * root.d)
                    height: width
                    stroke: Math.round(8 * root.d)
                    tint: focusTimer.phaseTint
                    progress: focusTimer.progress
                }
                Column {
                    anchors.centerIn: parent
                    IrisText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: focusTimer.clock
                        font.family: IrisStyle.fontNumbers
                        font.pixelSize: 28 * IrisStyle.typeScale
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                    IrisText { anchors.horizontalCenter: parent.horizontalCenter; text: focusTimer.phase; color: focusTimer.phaseTint; font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold) }
                }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6 * root.d
                Repeater {
                    model: TimerService.cyclesBeforeLongBreak
                    Rectangle {
                        required property int index
                        width: Math.round(6 * root.d)
                        height: width
                        radius: width / 2
                        color: index < TimerService.pomodoroCycle % TimerService.cyclesBeforeLongBreak ? IrisStyle.secondaryAccent : IrisStyle.fillHover
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8 * root.d
                IrisButton {
                    Layout.fillWidth: true
                    text: Translation.tr("Reset")
                    implicitHeight: Math.round(36 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    onClicked: TimerService.resetPomodoro()
                }
                IrisButton {
                    Layout.fillWidth: true
                    emphasized: true
                    text: focusTimer.ticking ? Translation.tr("Pause") : Translation.tr("Start")
                    implicitHeight: Math.round(36 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    onClicked: TimerService.togglePomodoro()
                }
            }
        }
    }

    Component {
        id: mixerComponent
        Section {
            id: mixer
            readonly property var streams: Audio.outputAppNodes.filter(node => node?.audio)
            title: Translation.tr("Sound mixer")
            glyph: "graphic_eq"
            tint: IrisStyle.identity.indigo
            detail: mixer.streams.length > 0 ? String(mixer.streams.length) : ""
            summary: [
                EmptyLabel { visible: mixer.streams.length === 0; text: Translation.tr("No app is playing sound.") },
                Row {
                    visible: mixer.streams.length > 0
                    spacing: 6 * root.d
                    Repeater {
                        model: mixer.streams.slice(0, 8)
                        IrisImage {
                            required property var modelData
                            width: Math.round(22 * root.d)
                            height: width
                            source: Quickshell.iconPath(MprisController.streamIconName(modelData), "audio-x-generic")
                        }
                    }
                }
            ]
            EmptyLabel { visible: mixer.streams.length === 0; text: Translation.tr("No app is playing sound.") }
            Repeater {
                model: mixer.streams
                RowLayout {
                    id: stream
                    required property var modelData
                    readonly property bool muted: stream.modelData?.audio?.muted ?? false
                    Layout.fillWidth: true
                    spacing: 10 * root.d
                    IrisImage {
                        Layout.preferredWidth: Math.round(26 * root.d)
                        Layout.preferredHeight: Layout.preferredWidth
                        source: Quickshell.iconPath(MprisController.streamIconName(stream.modelData), "audio-x-generic")
                        opacity: stream.muted ? 0.45 : 1
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4 * root.d
                        IrisText {
                            Layout.fillWidth: true
                            text: Audio.appNodeDisplayName(stream.modelData)
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(Font.Medium)
                            elide: Text.ElideRight
                        }
                        IrisScrubber {
                            Layout.fillWidth: true
                            fillColor: stream.muted ? IrisStyle.muted : IrisStyle.text
                            value: Math.min(1, stream.modelData?.audio?.volume ?? 0)
                            onMoved: next => { if (stream.modelData?.audio) stream.modelData.audio.volume = next }
                        }
                    }
                    IrisIconButton {
                        materialIcon: stream.muted ? "volume_off" : "volume_up"
                        selected: stream.muted
                        Accessible.name: Translation.tr("Mute")
                        onClicked: if (stream.modelData?.audio) stream.modelData.audio.muted = !stream.muted
                    }
                }
            }
        }
    }

    Component {
        id: systemComponent
        Section {
            id: systemCard
            expandable: false
            title: Translation.tr("System")
            glyph: "monitor_heart"
            tint: IrisStyle.identity.teal
            readonly property bool polling: root.contentActive
            property bool holding: false
            function syncPolling(): void {
                if (systemCard.polling && !systemCard.holding) { ResourceUsage.keepAlive(); systemCard.holding = true }
                else if (!systemCard.polling && systemCard.holding) { ResourceUsage.releaseKeepAlive(); systemCard.holding = false }
            }
            onPollingChanged: systemCard.syncPolling()
            Component.onCompleted: systemCard.syncPolling()
            Component.onDestruction: if (systemCard.holding) ResourceUsage.releaseKeepAlive()
            RowLayout {
                Layout.fillWidth: true
                spacing: 4 * root.d
                Repeater {
                    model: [
                        { label: Translation.tr("CPU"), level: ResourceUsage.cpuUsage, value: Math.round(ResourceUsage.cpuUsage * 100) + "%", warn: 0.85 },
                        { label: Translation.tr("Memory"), level: ResourceUsage.memoryUsedPercentage, value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%", warn: 0.85 },
                        { label: Translation.tr("Heat"), level: ResourceUsage.tempPercentage, value: ResourceUsage.maxTemp + "°", warn: ResourceUsage.tempWarningThreshold / 100 },
                        { label: Translation.tr("Disk"), level: ResourceUsage.diskUsedPercentage, value: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%", warn: 0.9 }
                    ]
                    ColumnLayout {
                        id: gauge
                        required property var modelData
                        readonly property real level: Math.max(0, Math.min(1, Number(gauge.modelData.level) || 0))
                        readonly property color tint: gauge.level >= gauge.modelData.warn ? IrisStyle.danger : IrisStyle.accent
                        Layout.fillWidth: true
                        spacing: 4 * root.d
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Math.round(52 * root.d)
                            implicitHeight: implicitWidth
                            GaugeRing {
                                anchors.fill: parent
                                tint: gauge.tint
                                progress: gauge.level
                            }
                            IrisText {
                                anchors.centerIn: parent
                                text: gauge.modelData.value
                                font.family: IrisStyle.fontNumbers
                                font.pixelSize: IrisStyle.typeLabel
                                font.weight: IrisStyle.weight(Font.Bold)
                            }
                        }
                        IrisText { Layout.alignment: Qt.AlignHCenter; text: gauge.modelData.label; color: IrisStyle.muted; font.pixelSize: IrisStyle.typeFootnote }
                    }
                }
            }
        }
    }
}
