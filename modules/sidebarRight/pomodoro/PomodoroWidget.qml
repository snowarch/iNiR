import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int currentTab: Persistent.states?.timer?.tab ?? 0
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Timer"), "icon": "hourglass_empty"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"}
    ]

    // These are keybinds for stopwatch, timer and pomodoro
    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) { // Switch tabs
            if (event.key === Qt.Key_PageDown) {
                currentTab = Math.min(currentTab + 1, root.tabButtonList.length - 1)
            } else if (event.key === Qt.Key_PageUp) {
                currentTab = Math.max(currentTab - 1, 0)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) { // Pause/resume with Space or S
            if (currentTab === 0) {
                TimerService.togglePomodoro()
            } else if (currentTab === 1) {
                TimerService.toggleCountdown()
            } else {
                TimerService.toggleStopwatch()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_R) { // Reset with R
            if (currentTab === 0) {
                TimerService.resetPomodoro()
            } else if (currentTab === 1) {
                TimerService.resetCountdown()
            } else {
                TimerService.stopwatchReset()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) { // Record lap with L
            TimerService.stopwatchRecordLap()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SecondaryTabBar {
                id: tabBar
                Layout.fillWidth: true
                currentIndex: currentTab
                onCurrentIndexChanged: {
                    currentTab = currentIndex
                    if (Persistent?.states?.timer) {
                        Persistent.states.timer.tab = currentIndex
                    }
                }

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
                        buttonText: modelData.name
                        buttonIcon: modelData.icon
                    }
                }
            }

            IconToolbarButton {
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

        Item { // Tab indicator
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
                property real fullTabSize: root.width / tabCount;
                property real targetWidth: tabBar.contentItem.children[0].children[tabBar.currentIndex].tabContentWidth

                implicitWidth: targetWidth
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                }

                x: tabBar.currentIndex * fullTabSize + (fullTabSize - targetWidth) / 2

                color: Appearance.colors.colPrimary
                radius: height / 2

                Behavior on x {
                    enabled: tabIndicator.enableIndicatorAnimation
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Behavior on implicitWidth {
                    enabled: tabIndicator.enableIndicatorAnimation
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }
        }

        Rectangle { // Tabbar bottom border
            id: tabBarBottomBorder
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 10
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: currentTab
            onCurrentIndexChanged: {
                tabIndicator.enableIndicatorAnimation = true
                currentTab = currentIndex
                if (Persistent?.states?.timer) {
                    Persistent.states.timer.tab = currentIndex
                }
            }

            // Tabs
            PomodoroTimer {}
            CountdownTimer {}
            Stopwatch {}
        }
    }
}
