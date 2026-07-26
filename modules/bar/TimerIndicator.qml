import qs
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Compact timer indicator for the ii bar.
 * Shows when pomodoro, countdown, or stopwatch is active, or an alarm is armed.
 */
MouseArea {
    id: root

    readonly property bool pinnedToBar: Persistent.states?.timer?.pinnedToBar ?? false

    readonly property bool pomodoroRunning: TimerService?.pomodoroRunning ?? false
    readonly property bool countdownRunning: TimerService?.countdownRunning ?? false
    readonly property bool stopwatchRunning: TimerService?.stopwatchRunning ?? false

    readonly property bool pomodoroActive: pomodoroRunning || (TimerService?.pomodoroSecondsLeft ?? 0) < (TimerService?.pomodoroLapDuration ?? 0)
    readonly property bool countdownFinished: !countdownRunning && (TimerService?.countdownSecondsLeft ?? 0) <= 0
        && (TimerService?.countdownDuration ?? 0) > 0

    readonly property bool countdownActive: !countdownFinished && (countdownRunning
        || (TimerService?.countdownSecondsLeft ?? 0) < (TimerService?.countdownDuration ?? 0))
    readonly property bool stopwatchActive: stopwatchRunning || (TimerService?.stopwatchTime ?? 0) > 0 || ((TimerService?.stopwatchLaps?.length ?? 0) > 0)

    // The next armed alarm as { alarm, at, snoozed }, or null.: the
    // schedule is AlarmService's and nothing here recomputes it. upcomingRings
    // rather than upcoming, so a snoozed alarm shows when it will actually go
    // off instead of the scheduled slot it is standing in front of. Recomputed
    // only when the records change, a snooze moves, or the shell clock ticks —
    // the same minute cadence the alarm poll runs at — and the result is a fixed
    // clock time, so the pill's width cannot oscillate between occurrences.
    // `loaded` keeps a still-empty list at startup from reading as "no alarms"
    // .
    readonly property var nextAlarm: (AlarmService?.loaded ?? false)
        ? (AlarmService.upcomingRings(DateTime.clock.date.getTime())[0] ?? null)
        : null
    readonly property bool alarmActive: root.nextAlarm !== null

    readonly property bool anyActive: pomodoroActive || countdownActive || stopwatchActive || alarmActive

    readonly property bool showPinnedIdle: pinnedToBar && !anyActive

    readonly property bool currentRunning: {
        if (root.pomodoroActive) return root.pomodoroRunning && !(TimerService?.pomodoroPaused ?? false)
        if (root.countdownActive) return root.countdownRunning && !(TimerService?.countdownPaused ?? false)
        if (root.stopwatchActive) return root.stopwatchRunning && !(TimerService?.stopwatchPaused ?? false)
        // An armed alarm has no paused state; it must not render as one.
        if (root.alarmActive) return true
        return false
    }

    readonly property bool paused: root.anyActive && !root.currentRunning

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
        if (alarmActive) {
            return Qt.locale().toString(new Date(root.nextAlarm.at), Config.options?.time?.format ?? "hh:mm")
        }
        return ""
    }

    readonly property string iconName: {
        if (pomodoroActive)
            return (TimerService?.pomodoroBreak ?? false) ? "coffee" : "target"
        if (countdownActive)
            return "hourglass_top"
        if (stopwatchActive)
            return "timer"
        if (alarmActive)
            return "alarm"
        return "schedule"
    }

    readonly property color accentColor: {
        if (Appearance.zzzEverywhere) {
            if (pomodoroActive)
                return (TimerService?.pomodoroBreak ?? false) ? Appearance.zzz.secondary : Appearance.zzz.accent
            if (countdownActive)
                return Appearance.zzz.secondary
            return Appearance.zzz.ink
        }
        if (pomodoroActive) {
            return (TimerService?.pomodoroBreak ?? false)
                ? Appearance.colors.colTertiary
                : Appearance.colors.colPrimary
        }
        if (countdownActive)
            return Appearance.colors.colSecondary
        return Appearance.colors.colOnLayer1
    }

    visible: implicitWidth > 0
    implicitWidth: (anyActive || showPinnedIdle) ? pill.width + 4 : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    function openTimerPanel(): void {
        // Choose the inner tab before the panel is shown, so it opens already on
        // the right one instead of visibly switching afterwards.
        if (Persistent?.states?.timer) {
            if (root.pomodoroActive) {
                Persistent.states.timer.tab = 0
            } else if (root.countdownActive) {
                Persistent.states.timer.tab = 1
            } else if (root.stopwatchActive) {
                Persistent.states.timer.tab = 2
            } else if (root.alarmActive) {
                Persistent.states.timer.tab = 3
            }
        }

        // Both sidebar layouts — the bottom group and the compact rail — select a
        // widget by id from this one signal, and each unfolds itself. A hardcoded
        // tab index only ever matched the bottom group, and drifts with the user's
        // enabledWidgets order. WeatherBar.qml:42 is the precedent.
        GlobalStates.sidebarRightRequestedWidget = "timer"
        GlobalStates.sidebarRightOpen = true
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) {
            if (!root.anyActive && root.showPinnedIdle) {
                root.openTimerPanel()
                return
            }

            if (root.pomodoroActive) {
                TimerService.togglePomodoro()
            } else if (root.countdownActive) {
                TimerService.toggleCountdown()
            } else if (root.stopwatchActive) {
                TimerService.toggleStopwatch()
            } else if (root.alarmActive) {
                // Nothing to toggle — an alarm is armed or it is not.
                root.openTimerPanel()
            }
            return
        }

        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
            root.openTimerPanel()
        }
    }

    Behavior on implicitWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Background pill
    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 12
        height: contentRow.implicitHeight + 8
        radius: height / 2
        scale: root.pressed ? 0.95 : 1.0
        color: {
            if (root.pressed) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardActive
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.paused) {
                if (Appearance.angelEverywhere) return root.containsMouse ? Appearance.angel.colGlassCardActive : Appearance.angel.colGlassCardHover
                if (Appearance.inirEverywhere) return root.containsMouse ? Appearance.inir.colLayer2Active : Appearance.inir.colLayer2Hover
                if (Appearance.auroraEverywhere) return root.containsMouse ? Appearance.aurora.colSubSurfaceActive : Appearance.aurora.colElevatedSurface
                return root.containsMouse ? Appearance.colors.colLayer2Active : Appearance.colors.colLayer2Hover
            }
            if (root.containsMouse) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCard
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            return "transparent"
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: pill
        spacing: 4

        MaterialSymbol {
            text: root.showPinnedIdle ? "schedule" : root.iconName
            iconSize: Appearance.font.pixelSize.normal
            color: root.paused
                ? (Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colOnLayer1Inactive)
                : root.accentColor
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on opacity {
                running: root.pomodoroActive && root.pomodoroRunning && !(TimerService?.pomodoroBreak ?? false)
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: root.showPinnedIdle ? Translation.tr("Timer") : root.timeText
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.paused
                ? (Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colOnLayer1Inactive)
                : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.paused ? pauseIcon.implicitWidth : 0
            implicitHeight: pauseIcon.implicitHeight
            opacity: root.paused ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            MaterialSymbol {
                id: pauseIcon
                anchors.centerIn: parent
                text: "pause"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colOnLayer1Inactive
            }
        }
    }

    // Tooltip
    TimerIndicatorTooltip {
        hoverTarget: root
        pomodoroActive: root.pomodoroActive
        countdownActive: root.countdownActive
        stopwatchActive: root.stopwatchActive
        alarmActive: root.alarmActive
        alarmName: root.nextAlarm ? AlarmService.displayName(root.nextAlarm.alarm) : ""
        alarmAt: root.nextAlarm ? root.nextAlarm.at : -1
        alarmSnoozed: root.nextAlarm ? (root.nextAlarm.snoozed ?? false) : false
        paused: root.paused
        pinnedIdle: root.showPinnedIdle
    }
}
