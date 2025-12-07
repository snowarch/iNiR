import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

/**
 * Waffle-style timer indicator for the taskbar.
 * Shows when pomodoro, countdown, or stopwatch is active.
 */
BarButton {
    id: root

    readonly property bool pomodoroActive: TimerService?.pomodoroRunning ?? false
    readonly property bool countdownActive: TimerService?.countdownRunning ?? false
    readonly property bool stopwatchActive: TimerService?.stopwatchRunning ?? false
    readonly property bool anyActive: pomodoroActive || countdownActive || stopwatchActive

    readonly property string timeText: {
        if (pomodoroActive) {
            const secs = TimerService?.pomodoroSecondsLeft ?? 0
            const mins = Math.floor(secs / 60).toString().padStart(2, '0')
            const s = Math.floor(secs % 60).toString().padStart(2, '0')
            return `${mins}:${s}`
        }
        if (countdownActive) {
            const secs = TimerService?.countdownSecondsLeft ?? 0
            const mins = Math.floor(secs / 60).toString().padStart(2, '0')
            const s = Math.floor(secs % 60).toString().padStart(2, '0')
            return `${mins}:${s}`
        }
        if (stopwatchActive) {
            const total = TimerService?.stopwatchTime ?? 0
            const secs = Math.floor(total / 100)
            const mins = Math.floor(secs / 60)
            const s = secs % 60
            return `${mins.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
        }
        return ""
    }

    readonly property string iconName: {
        if (pomodoroActive) return (TimerService?.pomodoroBreak ?? false) ? "drink-coffee" : "target"
        if (countdownActive) return "hourglass-half"
        if (stopwatchActive) return "timer"
        return "drink-coffee"
    }

    visible: anyActive

    onClicked: GlobalStates.waffleWidgetsOpen = !GlobalStates.waffleWidgetsOpen

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: timerRow.implicitWidth
        implicitHeight: timerRow.implicitHeight

        Row {
            id: timerRow
            anchors.centerIn: parent
            spacing: 6

            FluentIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.iconName

                SequentialAnimation on opacity {
                    running: root.pomodoroActive && !(TimerService?.pomodoroBreak ?? false)
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }

            WText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeText
            }
        }
    }

    BarToolTip {
        extraVisibleCondition: root.shouldShowTooltip
        text: {
            if (root.pomodoroActive) {
                const isLongBreak = TimerService?.pomodoroLongBreak ?? false
                const isBreak = TimerService?.pomodoroBreak ?? false
                const cycle = (TimerService?.pomodoroCycle ?? 0) + 1
                const totalCycles = TimerService?.cyclesBeforeLongBreak ?? 4
                const mode = isLongBreak ? Translation.tr("Long break") : isBreak ? Translation.tr("Break") : Translation.tr("Focus")
                return `Pomodoro: ${mode} (${cycle}/${totalCycles})`
            }
            if (root.countdownActive) return Translation.tr("Countdown timer")
            if (root.stopwatchActive) return Translation.tr("Stopwatch")
            return ""
        }
    }
}
