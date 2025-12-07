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

    visible: anyActive
    implicitWidth: anyActive ? contentRow.implicitWidth + 16 : 0
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: GlobalStates.sidebarRightOpen = true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
        }
    }

    // Background pill
    Rectangle {
        anchors.centerIn: parent
        width: contentRow.implicitWidth + 12
        height: contentRow.implicitHeight + 8
        radius: Appearance.rounding.full
        color: root.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1
        visible: root.anyActive

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4
        visible: root.anyActive

        MaterialSymbol {
            text: root.iconName
            iconSize: Appearance.font.pixelSize.normal
            color: root.accentColor
            Layout.alignment: Qt.AlignVCenter

            SequentialAnimation on opacity {
                running: root.pomodoroActive && !(TimerService?.pomodoroBreak ?? false)
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: root.timeText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Tooltip
    TimerIndicatorTooltip {
        hoverTarget: root
    }
}
