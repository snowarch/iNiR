pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.state

FooterRectangle {
    Layout.fillWidth: true
    implicitWidth: 0
    color: Looks.colors.bgPanelBody

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 16
            rightMargin: 16
            topMargin: 12
            bottomMargin: 12
        }
        spacing: 0

        SmallBorderedIconButton {
            visible: !TimerService.pomodoroRunning
            icon.name: "subtract"
            enabled: TimerService.focusTime > 300 // Minimum 5 minutes
            onClicked: Config.setNestedValue("time.pomodoro.focus", TimerService.focusTime - 300)
        }

        WTextWithFixedWidth {
            visible: !TimerService.pomodoroRunning
            implicitWidth: 81
            horizontalAlignment: Text.AlignHCenter
            color: Looks.colors.subfg
            text: Translation.tr("%1 mins").arg(`<font color="${Looks.colors.fg.toString()}">${TimerService.focusTime / 60}</font>`)
        }

        SmallBorderedIconButton {
            visible: !TimerService.pomodoroRunning
            icon.name: "add"
            enabled: TimerService.focusTime < 7200 // Maximum 2 hours
            onClicked: Config.setNestedValue("time.pomodoro.focus", TimerService.focusTime + 300)
        }

        WText {
            visible: TimerService.pomodoroRunning
            font.pixelSize: Looks.font.pixelSize.large
            text: Translation.tr("Focusing")
        }

        Item {
            Layout.fillWidth: true
        }

        SmallBorderedIconAndTextButton {
            iconName: TimerService.pomodoroRunning ? "stop" : "play"
            text: TimerService.pomodoroRunning ? Translation.tr("End session") : Translation.tr("Focus")

            onClicked: {
                if (TimerService.pomodoroRunning) {
                    TimerService.togglePomodoro();
                    TimerService.resetPomodoro();
                } else {
                    TimerService.togglePomodoro();
                    // Close notification center instead of toggling sidebar
                    WaffleState.notificationCenterOpen = false;
                }
            }
        }
    }
}
