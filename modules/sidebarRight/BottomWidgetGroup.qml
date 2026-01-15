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
import QtQuick
import QtQuick.Layouts
// import Qt5Compat.GraphicalEffects // Might not be available, using standard Rectangle gradient instead

Rectangle {
    id: root
    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? "transparent"
         : Appearance.colors.colLayer1
    border.width: Appearance.inirEverywhere ? 1 : 0
    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    clip: true
    visible: tabs.length > 0
    implicitHeight: visible ? (collapsed ? collapsedBottomWidgetGroupRow.implicitHeight : bottomWidgetGroupRow.implicitHeight) : 0
    property int selectedTab: Persistent.states?.sidebar?.bottomGroup?.tab ?? 0
    property bool collapsed: Persistent.states?.sidebar?.bottomGroup?.collapsed ?? false
    property var allTabs: [
        {"type": "calendar", "name": Translation.tr("Calendar"), "icon": "calendar_month", "widget": calendarWidget},
        {"type": "todo", "name": Translation.tr("To Do"), "icon": "done_outline", "widget": todoWidget},
        {"type": "notepad", "name": Translation.tr("Notepad"), "icon": "edit_note", "widget": notepadWidget},
        {"type": "calculator", "name": Translation.tr("Calc"), "icon": "calculate", "widget": calculatorWidget},
        {"type": "sysmon", "name": Translation.tr("System"), "icon": "monitor_heart", "widget": sysMonWidget},
        {"type": "timer", "name": Translation.tr("Timer"), "icon": "schedule", "widget": pomodoroWidget},
    ]

    property int configVersion: 0
    Connections {
        target: Config
        function onConfigChanged() { root.configVersion++ }
    }

    readonly property var enabledWidgets: {
        root.configVersion // Force dependency
        return Config.options?.sidebar?.right?.enabledWidgets ?? ["calendar", "todo", "notepad", "calculator", "sysmon", "timer"]
    }

    property var tabs: allTabs.filter(tab => enabledWidgets.includes(tab.type))

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

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
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

    function setCollapsed(state) {
        Persistent.states.sidebar.bottomGroup.collapsed = state
        if (collapsed) {
            bottomWidgetGroupRow.opacity = 0
        }
        else {
            collapsedBottomWidgetGroupRow.opacity = 0
        }
        collapseCleanFadeTimer.start()
    }

    Timer {
        id: collapseCleanFadeTimer
        interval: Appearance.animation.elementMove.duration / 2
        repeat: false
        onTriggered: {
            if(collapsed) collapsedBottomWidgetGroupRow.opacity = 1
            else bottomWidgetGroupRow.opacity = 1
        }
    }

    // Scroll navigation for tabs
    WheelHandler {
        target: root
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
            NumberAnimation {
                id: collapsedBottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        spacing: 15

        CalendarHeaderButton {
            Layout.margins: 10
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
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                }
            }
        }

        StyledText {
            property int remainingTasks: Todo.list.filter(task => !task.done).length;
            Layout.margins: 10
            Layout.leftMargin: 0
            // text: `${DateTime.collapsedCalendarFormat}   •   ${remainingTasks} task${remainingTasks > 1 ? "s" : ""}`
            text: Translation.tr("%1   •   %2 tasks").arg(DateTime.collapsedCalendarFormat).arg(remainingTasks)
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
        }
    }

    // The thing when expanded
    RowLayout {
        id: bottomWidgetGroupRow

        opacity: collapsed ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
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
            // Original width was tabBar.width (56). We need to account for leftMargin of 5 inside.
            width: tabBar.implicitWidth + 5

            // Collapse button (Fixed at top)
            CalendarHeaderButton {
                id: collapseBtn
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 0
                forceCircle: true
                downAction: () => {
                    root.setCollapsed(true)
                }
                contentItem: Item {
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }
                }
            }

            // Scrollable tab buttons
            Flickable {
                id: railFlickable
                anchors.top: collapseBtn.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                contentHeight: tabColumn.implicitHeight
                clip: true
                interactive: true

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
                visible: railFlickable.contentY > 0 && !Appearance.auroraEverywhere
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Gradient fades - Bottom
            Rectangle {
                anchors.bottom: railFlickable.bottom
                anchors.left: railFlickable.left
                anchors.right: railFlickable.right
                height: 20
                visible: railFlickable.contentHeight > railFlickable.height && railFlickable.contentY < (railFlickable.contentHeight - railFlickable.height) && !Appearance.auroraEverywhere
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.colors.colLayer1 }
                }
            }
        }

        // Content area
        StackLayout {
            id: tabStack
            Layout.fillWidth: true
            // Use fixed/max height to prevent jumps, relying on internal scrolling if needed
            // height: Math.min(500, Math.max(300, ...tabStack.children.map(child => child.tabLoader?.item?.implicitHeight || child.tabLoader?.implicitHeight || 300)))
            // Restore implicit height behavior as requested ("como lo era originalmente")
            // Added min 300 to prevent collapse during dynamic tab switching, ONLY if there are tabs
            height: (tabs.length > 0) ? Math.max(300, ...tabStack.children.map(child => child.tabLoader?.item?.implicitHeight || child.tabLoader?.implicitHeight || 0)) : 0
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

    // Calendar component
    Component {
        id: calendarWidget

        CalendarWidget {
            anchors.fill: parent
            anchors.margins: 5
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
}
