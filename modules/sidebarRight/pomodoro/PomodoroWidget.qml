import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property bool compactMode: false
    property bool centerMode: true
    property int currentTab: Persistent.states?.timer?.tab ?? 0
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Timer"), "icon": "hourglass_empty"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"},
        // Appended, never inserted: the tab index is persisted, so inserting
        // would silently move every existing user to a different tab.
        {"name": Translation.tr("Alarms"), "icon": "alarm"}
    ]

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder 
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colOutlineVariant

    // Four tabs no longer fit this bar with labels at sidebar width: the
    // labels ran into the icons. Measured against the widest label so the tabs
    // stay uniform — either they all show text or none do.
    TextMetrics {
        id: widestTabLabel
        font.pixelSize: Appearance.font.pixelSize.small
        font.family: Appearance.font.family.main
        text: root.tabButtonList.reduce((widest, tab) => tab.name.length > widest.length ? tab.name : widest, "")
    }
    readonly property bool tabTextFits: tabBar.width / root.tabButtonList.length
        >= widestTabLabel.width + Appearance.font.pixelSize.huge + 33

    // currentTab is a pure binding on the persisted value, so every tab change
    // must write Persistent rather than assign currentTab — assigning would
    // break the binding, and the bar indicator (which switches tabs by writing
    // Persistent) would silently stop working from then on.
    function setTab(index: int): void {
        if (Persistent?.states?.timer)
            Persistent.states.timer.tab = Math.max(0, Math.min(index, root.tabButtonList.length - 1))
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                root.setTab(root.currentTab + 1)
            } else if (event.key === Qt.Key_PageUp) {
                root.setTab(root.currentTab - 1)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) {
            // Explicit per tab, no trailing else: on the alarms tab these are
            // letters someone is typing into a name, not stopwatch controls.
            if (currentTab === 0) TimerService.togglePomodoro()
            else if (currentTab === 1) TimerService.toggleCountdown()
            else if (currentTab === 2) TimerService.toggleStopwatch()
            else return
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            if (currentTab === 0) TimerService.resetPomodoro()
            else if (currentTab === 1) TimerService.resetCountdown()
            else if (currentTab === 2) TimerService.stopwatchReset()
            else return
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            if (currentTab === 3) return
            TimerService.stopwatchRecordLap()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab bar row with pin button
        Item {
            Layout.fillWidth: true
            implicitHeight: tabBar.height

            SecondaryTabBar {
                id: tabBar
                anchors.left: parent.left
                anchors.right: pinButton.left
                anchors.rightMargin: 6
                currentIndex: currentTab
                onCurrentIndexChanged: root.setTab(currentIndex)

                background: Item {
                    WheelHandler {
                        onWheel: (event) => {
                            if (event.angleDelta.y < 0)
                                tabBar.currentIndex = Math.min(tabBar.currentIndex + 1, root.tabButtonList.length - 1)
                            else if (event.angleDelta.y > 0)
                                tabBar.currentIndex = Math.max(tabBar.currentIndex - 1, 0)
                        }
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    }
                }

                Repeater {
                    model: root.tabButtonList
                    delegate: SecondaryTabButton {
                        selected: (index == currentTab)
                        buttonText: root.tabTextFits ? modelData.name : ""
                        buttonIcon: modelData.icon

                        StyledToolTip {
                            // The only label left once the text is dropped.
                            extraVisibleCondition: !root.tabTextFits
                            text: modelData.name
                        }
                    }
                }
            }

            IconToolbarButton {
                id: pinButton
                anchors.right: parent.right
                anchors.verticalCenter: tabBar.verticalCenter
                text: "push_pin"
                toggled: Persistent.states?.timer?.pinnedToBar ?? false
                onClicked: {
                    if (Persistent?.states?.timer) {
                        Persistent.states.timer.pinnedToBar = !toggled
                    }
                }

                StyledToolTip {
                    text: Translation.tr("Pin timer to bar\nKeeps the timer indicator visible in the bar even when no timer is running")
                }
            }
        }

        Item {
            id: tabIndicator
            Layout.fillWidth: true
            height: 3
            property bool enableIndicatorAnimation: false
            Connections {
                target: root
                function onCurrentTabChanged() {
                    tabIndicator.enableIndicatorAnimation = true
                }
            }

            Rectangle {
                id: indicator
                property int tabCount: root.tabButtonList.length
                property real fullTabSize: tabBar.width / tabCount
                property real targetWidth: tabBar.contentItem?.children[0]?.children[tabBar.currentIndex]?.tabContentWidth ?? 50

                implicitWidth: targetWidth
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                x: tabBar.currentIndex * fullTabSize + (fullTabSize - targetWidth) / 2
                color: Appearance.colors.colPrimary
                radius: height / 2

                Behavior on x {
                    enabled: tabIndicator.enableIndicatorAnimation && Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
                Behavior on implicitWidth {
                    enabled: tabIndicator.enableIndicatorAnimation && Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }
            }
        }

        Rectangle { // No full-width grey track — only the colored active indicator reads.
            Layout.fillWidth: true
            height: 1
            color: "transparent"
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 6
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            clip: true
            currentIndex: currentTab
            onCurrentIndexChanged: {
                tabIndicator.enableIndicatorAnimation = true
                root.setTab(currentIndex)
            }

            // A SwipeView keeps every page alive and enabled, so Tab walks
            // into the pages the user cannot see: from the tab bar it landed
            // on the pomodoro controls, and reaching the alarm rows meant
            // tabbing blind through three off-screen pages, pressing Space on
            // an invisible timer button on the way. Disabling the pages that
            // are not showing takes them out of the tab chain and nothing
            // else — the timers themselves live in TimerService, not here.
            PomodoroTimer {
                enabled: SwipeView.isCurrentItem
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
            CountdownTimer {
                enabled: SwipeView.isCurrentItem
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
            Stopwatch {
                enabled: SwipeView.isCurrentItem
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
            AlarmList {
                enabled: SwipeView.isCurrentItem
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
        }
    }
}
