import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.sidebarRight.calendar
import qs.modules.sidebarRight.todo
import qs.modules.sidebarRight.pomodoro
import qs.modules.sidebarRight.notepad
import qs.modules.sidebarRight.calculator
import qs.modules.sidebarRight.sysmon
import qs.modules.sidebarRight.screenTime
import qs.modules.sidebarRight.events
import qs.modules.sidebarRight.weather
import QtQuick
import QtQuick.Layouts
// import Qt5Compat.GraphicalEffects // Might not be available, using standard Rectangle gradient instead

Rectangle {
    id: root
    radius: Appearance.zzzEverywhere ? Appearance.zzz.cardRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.rounding.normal
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    color: Appearance.zzzEverywhere ? "transparent"
         : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
         : Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent"
         : Appearance.colors.colLayer1
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.width: Appearance.zzzEverywhere ? 0 : (Appearance.angelEverywhere ? 0 : (Appearance.inirEverywhere ? 1 : 0))
    Behavior on border.width {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    border.color: Appearance.zzzEverywhere ? "transparent"
        : Appearance.angelEverywhere ? "transparent"
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    Behavior on border.color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    clip: true

    AngelPartialBorder { targetRadius: root.radius; coverage: 0.5 }
    visible: tabs.length > 0
    implicitHeight: (tabs.length > 0) ? (collapsed ? collapsedBottomWidgetGroupRow.implicitHeight : bottomWidgetGroupRow.implicitHeight) : 0

    Behavior on implicitHeight {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    property int selectedTab: Persistent.states?.sidebar?.bottomGroup?.tab ?? 0
    property bool collapsed: Persistent.states?.sidebar?.bottomGroup?.collapsed ?? false
    
    property var allTabs: [
        {"type": "calendar", "name": Translation.tr("Calendar"), "icon": "calendar_month", "widget": calendarWidget},
        {"type": "events", "name": Translation.tr("Events"), "icon": "event_upcoming", "widget": eventsWidgetComponent},
        {"type": "todo", "name": Translation.tr("To Do"), "icon": "done_outline", "widget": todoWidget},
        {"type": "notepad", "name": Translation.tr("Notepad"), "icon": "edit_note", "widget": notepadWidget},
        {"type": "calculator", "name": Translation.tr("Calc"), "icon": "calculate", "widget": calculatorWidget},
        {"type": "sysmon", "name": Translation.tr("System"), "icon": "monitor_heart", "widget": sysMonWidget},
        {"type": "weather", "name": Translation.tr("Weather"), "icon": "light_mode", "widget": weatherWidget},
        {"type": "timer", "name": Translation.tr("Timer"), "icon": "schedule", "widget": pomodoroWidget},
        {"type": "screentime", "name": Translation.tr("Screen Time"), "icon": "av_timer", "widget": screenTimeWidget},
    ]

    property int configVersion: 0
    Connections {
        target: Config
        function onConfigChanged() { root.configVersion++ }
    }

    function handleRequestedWidget(): void {
        const w = GlobalStates.sidebarRightRequestedWidget
        if (!w) return
        const idx = root.tabs.findIndex(t => t.type === w)
        if (idx !== -1) {
            root.setCollapsed(false)
            Persistent.states.sidebar.bottomGroup.tab = idx
        }
        GlobalStates.sidebarRightRequestedWidget = ""
    }

    Component.onCompleted: handleRequestedWidget()

    Connections {
        target: GlobalStates
        function onSidebarRightRequestedWidgetChanged() {
            root.handleRequestedWidget()
        }
    }

    // Signal to open events dialog (propagated from EventsWidget)
    signal openEventsDialog(var editEvent)

    // Events component
    Component {
        id: eventsWidgetComponent
        EventsWidget {
            anchors.fill: parent
            anchors.margins: 5
            onOpenEventsDialog: (editEvent) => root.openEventsDialog(editEvent)
        }
    }

    readonly property var enabledWidgets: {
        root.configVersion // Force dependency
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "weather", "timer"]
    }

    property var tabs: allTabs.filter(tab => {
        if (tab.type === "screentime" && !(Config.options?.sidebar?.screenTime?.enable ?? false))
            return false
        return enabledWidgets.includes(tab.type)
    })

    property string currentTabType: ""
    onSelectedTabChanged: {
        if (tabs[selectedTab]) currentTabType = tabs[selectedTab].type
    }

    onTabsChanged: {
        // Try to restore previous selection by type
        if (currentTabType) {
            const newIndex = tabs.findIndex(t => t.type === currentTabType)
            if (newIndex !== -1) {
                const currentTab = Persistent.states?.sidebar?.bottomGroup?.tab ?? 0
                if (currentTab !== newIndex) {
                    Persistent.states.sidebar.bottomGroup.tab = newIndex
                }
                return
            }
        }

        // If not found or no previous selection, clamp index
        const currentTab = Persistent.states?.sidebar?.bottomGroup?.tab ?? 0
        if (currentTab >= tabs.length) {
            Persistent.states.sidebar.bottomGroup.tab = Math.max(0, tabs.length - 1)
        }

        // Update current type for the new selection (fallback)
        const safeTab = Persistent.states?.sidebar?.bottomGroup?.tab ?? 0
        if (tabs[safeTab]) {
            currentTabType = tabs[safeTab].type
        }
    }


    function focusActiveItem() {
        // Find the current tab item in the StackLayout and force focus on its loaded widget
        for (var i = 0; i < tabStack.children.length; i++) {
            var child = tabStack.children[i]
            if (child.tabIndex === root.selectedTab && child.tabLoader && child.tabLoader.item) {
                child.tabLoader.item.forceActiveFocus()
                break
            }
        }
    }

    function setCollapsed(state: bool): void {
        const next = Boolean(state)
        if ((Persistent.states?.sidebar?.bottomGroup?.collapsed ?? false) === next)
            return
        Persistent.states.sidebar.bottomGroup.collapsed = next
        if (!next) Qt.callLater(root.focusActiveItem)
    }

    // Scroll navigation for tabs
    WheelHandler {
        target: root
        enabled: !root.collapsed
        orientation: Qt.Vertical
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                Persistent.states.sidebar.bottomGroup.tab = Math.min(root.selectedTab + 1, root.tabs.length - 1)
            } else if (event.angleDelta.y > 0) {
                Persistent.states.sidebar.bottomGroup.tab = Math.max(root.selectedTab - 1, 0)
            }
        }
    }

    // The thing when collapsed
    RowLayout {
        id: collapsedBottomWidgetGroupRow
        opacity: collapsed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                id: collapsedBottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        spacing: 15

        CalendarHeaderButton {
            Layout.topMargin: 10
            Layout.bottomMargin: 10
            Layout.leftMargin: 25
            Layout.rightMargin: 0
            forceCircle: true
            downAction: () => {
                root.setCollapsed(false)
            }
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
        }

        StyledText {
            property int remainingTasks: Todo.list.filter(task => !task.done).length;
            Layout.margins: 10
            Layout.leftMargin: 0
            text: Translation.tr("%1   •   %2 tasks").arg(DateTime.collapsedCalendarFormat).arg(remainingTasks)
            font.pixelSize: Appearance.font.pixelSize.large
            font.family: Appearance.zzzEverywhere ? Appearance.font.family.numbers : Appearance.font.family.main
            color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }

    // The thing when expanded
    RowLayout {
        id: bottomWidgetGroupRow

        opacity: collapsed ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                id: bottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        anchors.fill: parent
        spacing: 10

        // Navigation rail
        Item {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.leftMargin: 10
            Layout.topMargin: 10
            width: tabBar.implicitWidth + 5

            // Collapse button (Fixed at top)
            CalendarHeaderButton {
                id: collapseBtn
                visible: true
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.left: undefined
                anchors.leftMargin: 0
                forceCircle: true
                // Bgless: nav-rail icon button shows only the colored symbol at rest;
                // a plate would read as the wrong "groove" background. Hover keeps feedback.
                colBackground: "transparent"
                downAction: () => {
                    root.setCollapsed(true)
                }
                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }

            // Scrollable tab buttons
            Flickable {
                id: railFlickable
                anchors.top: collapseBtn.bottom
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                contentHeight: tabColumn.implicitHeight
                clip: true
                // Only steal drags when there's actually something to scroll —
                // otherwise the Flickable eats quick taps on the nav icons and the
                // section doesn't open. (No visible plate now, so misses are obvious.)
                interactive: contentHeight > height
                pressDelay: 0

                ColumnLayout {
                    id: tabColumn
                    width: parent.width
                    spacing: 0

                    // Spacer to center vertically when content is small
                    Item {
                        Layout.fillHeight: true
                        visible: railFlickable.contentHeight < railFlickable.height
                    }

                    NavigationRailTabArray {
                        id: tabBar
                        Layout.alignment: Qt.AlignLeft
                        Layout.leftMargin: 5
                        // Override default topMargin of 25 to restore original vertical positioning
                        Layout.topMargin: 0
                        currentIndex: root.selectedTab
                        expanded: false
                        Repeater {
                            model: root.tabs
                            NavigationRailButton {
                                showToggledHighlight: false
                                toggled: root.selectedTab == index
                                buttonText: modelData.name
                                buttonIcon: modelData.icon
                                onPressed: {
                                    Persistent.states.sidebar.bottomGroup.tab = index
                                }
                            }
                        }
                    }

                    // Spacer to center vertically when content is small
                    Item {
                        Layout.fillHeight: true
                        visible: railFlickable.contentHeight < railFlickable.height
                    }
                }
            }

            // Gradient fades - Top
            Rectangle {
                anchors.top: railFlickable.top
                anchors.left: railFlickable.left
                anchors.right: railFlickable.right
                height: 20
                opacity: (railFlickable.contentY > 0 && !Appearance.auroraEverywhere && !Appearance.zzzEverywhere) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Appearance.zzzEverywhere ? Appearance.zzz.chrome : Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Gradient fades - Bottom
            Rectangle {
                anchors.bottom: railFlickable.bottom
                anchors.left: railFlickable.left
                anchors.right: railFlickable.right
                height: 20
                opacity: (railFlickable.contentHeight > railFlickable.height && railFlickable.contentY < (railFlickable.contentHeight - railFlickable.height) && !Appearance.auroraEverywhere && !Appearance.zzzEverywhere) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop {
                        position: 1.0
                        color: Appearance.zzzEverywhere ? Appearance.zzz.chrome : Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1
                        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    }
                }
            }
        }

        // Content area. Height must go through Layout.preferredHeight (not a raw
        // height binding the RowLayout fights): it feeds the row's implicitHeight,
        // which feeds the group's implicitHeight, which sizes the whole panel when
        // the collapse-when-empty mode shrinks the sidebar. A raw height binding
        // painted this tall but reported ~0, so the shrunken panel clipped the group.
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            Layout.preferredHeight: (tabs.length > 0) ? Math.max(300, ...tabStack.children.map(child => child.tabLoader?.item?.implicitHeight || child.tabLoader?.implicitHeight || 0)) : 0
            Layout.alignment: Qt.AlignVCenter
            property int realIndex: root.selectedTab
            property int animationDuration: Appearance.animation.elementMoveFast.duration * 1.5
            currentIndex: root.selectedTab

            // Switch the tab on halfway of the anim duration
            Connections {
                target: root
                function onSelectedTabChanged() {
                    delayedStackSwitch.start()
                    tabStack.realIndex = root.selectedTab
                    Qt.callLater(() => root.focusActiveItem())
                }
            }
            Timer {
                id: delayedStackSwitch
                interval: tabStack.animationDuration / 2
                repeat: false
                onTriggered: {
                    tabStack.currentIndex = root.selectedTab
                }
            }

            Repeater {
                model: tabs
                Item {
                    id: tabItem
                    property int tabIndex: index
                    property string tabType: modelData.type
                    property int animDistance: 5
                    property var tabLoader: tabLoader
                    // Opacity: show up only when being animated to
                    opacity: (tabStack.currentIndex === tabItem.tabIndex && tabStack.realIndex === tabItem.tabIndex) ? 1 : 0
                    // Y: animate both outgoing and incoming tabs
                    y: (tabStack.realIndex === tabItem.tabIndex) ? 0 : (tabStack.realIndex < tabItem.tabIndex) ? animDistance : -animDistance
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: tabStack.animationDuration / 2
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: tabStack.animationDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                    Loader {
                        id: tabLoader
                        anchors.fill: parent
                        sourceComponent: modelData.widget
                        focus: root.selectedTab === tabItem.tabIndex
                    }
                }
            }
        }
    }

    // Navigate to Events tab by type
    function switchToEventsTab(): void {
        const eventsIndex = root.tabs.findIndex(t => t.type === "events")
        if (eventsIndex !== -1) {
            Persistent.states.sidebar.bottomGroup.tab = eventsIndex
        }
    }

    // Calendar component
    Component {
        id: calendarWidget

        CalendarWidget {
            anchors.fill: parent
            anchors.margins: 5
            onDayWithEventsClicked: (date) => root.switchToEventsTab()
            onOpenEventsDialog: (editEvent) => root.openEventsDialog(editEvent)
        }
    }

    // To Do component
    Component {
        id: todoWidget
        TodoWidget {
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // Notepad component
    Component {
        id: notepadWidget
        NotepadWidget {
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // Calculator component
    Component {
        id: calculatorWidget
        CalculatorWidget {
            compactMode: false
            centerContentVertically: false
            expandedInPanel: root.currentTabType === "calculator"
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // SysMon component
    Component {
        id: sysMonWidget
        SysMonWidget {
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // Pomodoro component
    Component {
        id: pomodoroWidget
        PomodoroWidget {
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // Screen Time component
    Component {
        id: screenTimeWidget
        ScreenTimeWidget {
            anchors.fill: parent
            anchors.margins: 5
        }
    }

    // Weather component — reports NO implicit height so it never drives the
    // shared bottom-group height (which is max() across all tabs). It fills the
    // group's default height and scrolls its content internally.
    Component {
        id: weatherWidget
        StyledFlickable {
            anchors.fill: parent
            anchors.margins: 5
            contentHeight: weatherDetail.implicitHeight
            clip: true
            WeatherDetailWidget {
                id: weatherDetail
                width: parent.width
            }
        }
    }
}
