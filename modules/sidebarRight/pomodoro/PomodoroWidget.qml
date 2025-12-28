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

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                currentTab = Math.min(currentTab + 1, root.tabButtonList.length - 1)
            } else if (event.key === Qt.Key_PageUp) {
                currentTab = Math.max(currentTab - 1, 0)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) {
            if (currentTab === 0) TimerService.togglePomodoro()
            else if (currentTab === 1) TimerService.toggleCountdown()
            else TimerService.toggleStopwatch()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            if (currentTab === 0) TimerService.resetPomodoro()
            else if (currentTab === 1) TimerService.resetCountdown()
            else TimerService.stopwatchReset()
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
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
                    enabled: tabIndicator.enableIndicatorAnimation
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on implicitWidth {
                    enabled: tabIndicator.enableIndicatorAnimation
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }
        }

        Rectangle {
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

            PomodoroTimer {}
            CountdownTimer {}
            Stopwatch {}
        }
    }
}
