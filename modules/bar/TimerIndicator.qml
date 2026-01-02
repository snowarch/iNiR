import qs
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Compact timer indicator for the ii bar.
 * Shows when pomodoro, countdown, or stopwatch is active.
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

    readonly property bool anyActive: pomodoroActive || countdownActive || stopwatchActive

    readonly property bool showPinnedIdle: pinnedToBar && !anyActive

    readonly property bool currentRunning: {
        if (root.pomodoroActive) return root.pomodoroRunning && !(TimerService?.pomodoroPaused ?? false)
        if (root.countdownActive) return root.countdownRunning && !(TimerService?.countdownPaused ?? false)
        if (root.stopwatchActive) return root.stopwatchRunning && !(TimerService?.stopwatchPaused ?? false)
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
        return ""
    }

    readonly property string iconName: {
        if (pomodoroActive)
            return (TimerService?.pomodoroBreak ?? false) ? "coffee" : "target"
        if (countdownActive)
            return "hourglass_top"
        if (stopwatchActive)
            return "timer"
        return "schedule"
    }

    readonly property color accentColor: {
        if (pomodoroActive) {
            return (TimerService?.pomodoroBreak ?? false) 
                ? (Appearance.colors.colTertiary ?? Appearance.m3colors.m3tertiary) 
                : Appearance.colors.colPrimary
        }
        if (countdownActive)
            return Appearance.m3colors.m3secondary
        return Appearance.colors.colOnLayer1
    }

    visible: anyActive || showPinnedIdle
    implicitWidth: (anyActive || showPinnedIdle) ? pill.width + 4 : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    function openTimerPanel(): void {
        GlobalStates.sidebarRightOpen = true
 
        if (Persistent?.states?.sidebar?.bottomGroup) {
            Persistent.states.sidebar.bottomGroup.tab = 3
            Persistent.states.sidebar.bottomGroup.collapsed = false
        }
 
        if (Persistent?.states?.timer) {
            if (root.pomodoroActive) {
                Persistent.states.timer.tab = 0
            } else if (root.countdownActive) {
                Persistent.states.timer.tab = 1
            } else if (root.stopwatchActive) {
                Persistent.states.timer.tab = 2
            }
        }
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
            }
            return
        }

        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton) {
            root.openTimerPanel()
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
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
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer2Active
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurfaceActive
                return Appearance.colors.colLayer1Active
            }
            if (root.paused) {
                // Always show dark background when paused (like hover state)
                if (Appearance.inirEverywhere) return root.containsMouse ? Appearance.inir.colLayer2Active : Appearance.inir.colLayer2Hover
                if (Appearance.auroraEverywhere) return root.containsMouse ? Appearance.aurora.colSubSurfaceActive : Appearance.aurora.colElevatedSurface
                return root.containsMouse ? Appearance.colors.colLayer2Active : Appearance.colors.colLayer2Hover
            }
            if (root.containsMouse) {
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora.colSubSurface
                return Appearance.colors.colLayer1Hover
            }
            return "transparent"
        }

        Behavior on color { ColorAnimation { duration: 100 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
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

        MaterialSymbol {
            visible: root.paused
            text: "pause"
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colOnLayer1Inactive
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Tooltip
    TimerIndicatorTooltip {
        hoverTarget: root
        pomodoroActive: root.pomodoroActive
        countdownActive: root.countdownActive
        stopwatchActive: root.stopwatchActive
        paused: root.paused
        pinnedIdle: root.showPinnedIdle
    }
}
