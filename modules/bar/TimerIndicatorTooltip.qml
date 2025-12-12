import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

StyledPopup {
    id: root

    property bool pomodoroActive: TimerService?.pomodoroRunning ?? false
    property bool countdownActive: TimerService?.countdownRunning ?? false
    property bool stopwatchActive: TimerService?.stopwatchRunning ?? false

    property bool paused: false

    property bool pinnedIdle: false

    readonly property string timeDisplay: {
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
            const ms = Math.floor((total % 100) / 10)
            return `${mins.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}.${ms}`
        }
        return "00:00"
    }

    readonly property string modeText: {
        if (pinnedIdle) return Translation.tr("Timer")
        if (pomodoroActive) {
            const isLongBreak = TimerService?.pomodoroLongBreak ?? false
            const isBreak = TimerService?.pomodoroBreak ?? false
            if (isLongBreak) return Translation.tr("Long break")
            if (isBreak) return Translation.tr("Break")
            return Translation.tr("Focus")
        }
        if (countdownActive) return Translation.tr("Countdown")
        if (stopwatchActive) return Translation.tr("Stopwatch")
        return ""
    }

    readonly property string statusText: root.paused ? Translation.tr("Paused") : ""

    readonly property string hintText: pinnedIdle
        ? Translation.tr("Click to open timer settings")
        : ""

    readonly property string iconName: {
        if (pomodoroActive) return (TimerService?.pomodoroBreak ?? false) ? "coffee" : "target"
        if (countdownActive) return "hourglass_top"
        if (stopwatchActive) return "timer"
        return "schedule"
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 4

        // Header row - mode icon + text
        Row {
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: root.iconName
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.statusText.length > 0 ? `${root.modeText} • ${root.statusText}` : root.modeText
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        StyledText {
            visible: root.hintText.length > 0
            text: root.hintText
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.small
        }

        // Time display row
        RowLayout {
            spacing: 5
            Layout.fillWidth: true
            visible: !root.pinnedIdle

            MaterialSymbol {
                text: "schedule"
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.large
            }

            StyledText {
                text: Translation.tr("Time remaining:")
                color: Appearance.colors.colOnSurfaceVariant
                visible: root.pomodoroActive || root.countdownActive
            }

            StyledText {
                text: Translation.tr("Elapsed:")
                color: Appearance.colors.colOnSurfaceVariant
                visible: root.stopwatchActive
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurfaceVariant
                text: root.timeDisplay
                font.weight: Font.Medium
            }
        }

        // Pomodoro cycle row
        RowLayout {
            visible: root.pomodoroActive
            spacing: 5
            Layout.fillWidth: true

            MaterialSymbol {
                text: "replay"
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.large
            }

            StyledText {
                text: Translation.tr("Cycle:")
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurfaceVariant
                text: "%1 / %2"
                    .arg((TimerService?.pomodoroCycle ?? 0) + 1)
                    .arg(TimerService?.cyclesBeforeLongBreak ?? 4)
            }
        }

        // Stopwatch laps row
        RowLayout {
            visible: root.stopwatchActive && (TimerService?.stopwatchLaps?.length ?? 0) > 0
            spacing: 5
            Layout.fillWidth: true

            MaterialSymbol {
                text: "flag"
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.large
            }

            StyledText {
                text: Translation.tr("Laps:")
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                color: Appearance.colors.colOnSurfaceVariant
                text: TimerService?.stopwatchLaps?.length ?? 0
            }
        }
    }
}
