import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        // The Pomodoro timer circle
        CircularProgress {
            Layout.alignment: Qt.AlignHCenter
            lineWidth: 8
            value: {
                return TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration;
            }
            implicitSize: 200
            enableAnimation: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        let minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, '0');
                        let seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, '0');
                        return `${minutes}:${seconds}`;
                    }
                    font.pixelSize: Math.round(40 * Appearance.fontSizeScale)
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: TimerService.pomodoroLongBreak ? Translation.tr("Long break") : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }

            Rectangle {
                radius: Appearance.rounding.full
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colLayer2
                
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                implicitWidth: 36
                implicitHeight: implicitWidth

                StyledText {
                    id: cycleText
                    anchors.centerIn: parent
                    color: Appearance.colors.colOnLayer2
                    text: TimerService.pomodoroCycle + 1
                }
            }
        }

        // The Start/Stop and Reset buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: TimerService.pomodoroRunning ? Translation.tr("Pause") : (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume")
                    color: TimerService.pomodoroRunning 
                        ? (Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnSecondaryContainer)
                        : Appearance.colors.colOnPrimary
                }
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                onClicked: TimerService.togglePomodoro()
                colBackground: TimerService.pomodoroRunning 
                    ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer)
                    : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.pomodoroRunning 
                    ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover)
                    : Appearance.colors.colPrimaryHover
                colRipple: TimerService.pomodoroRunning 
                    ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive)
                    : Appearance.colors.colPrimaryActive
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90

                onClicked: TimerService.resetPomodoro()
                enabled: (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration) || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak

                font.pixelSize: Appearance.font.pixelSize.larger
                colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                    : Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
                    : Appearance.colors.colErrorContainerHover
                colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                    : Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Reset")
                    color: Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2
                        : Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}
