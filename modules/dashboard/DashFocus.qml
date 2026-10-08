pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

DashCard {
    id: root
    title: Translation.tr("Focus")
    icon: "timer"
    readonly property int secondsLeft: Math.max(0, TimerService.pomodoroSecondsLeft)
    readonly property string phase: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
        : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
    readonly property bool ticking: TimerService.pomodoroRunning && !TimerService.pomodoroPaused

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        CircularProgress {
            implicitSize: root.compact ? 76 : 92
            lineWidth: 4
            value: Math.max(0, Math.min(1, root.secondsLeft / Math.max(1, TimerService.pomodoroLapDuration)))
            colPrimary: root.colAccent
            colSecondary: ColorUtils.applyAlpha(root.colSubtext, 0.15)
            enableAnimation: root.visible

            StyledText {
                anchors.centerIn: parent
                text: Math.floor(root.secondsLeft / 60).toString().padStart(2, "0")
                    + ":" + (root.secondsLeft % 60).toString().padStart(2, "0")
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: root.colText
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            StyledText {
                Layout.fillWidth: true
                text: TimerService.pomodoroPaused ? Translation.tr("Paused") : root.phase
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Session %1 of %2").arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 36
            buttonRadius: root.radius
            colBackground: ColorUtils.applyAlpha(root.colAccent, 0.12)
            colBackgroundHover: ColorUtils.applyAlpha(root.colAccent, 0.2)
            colRipple: ColorUtils.applyAlpha(root.colAccent, 0.25)
            onClicked: TimerService.togglePomodoro()
            Accessible.name: actionLabel.text
            contentItem: StyledText {
                id: actionLabel
                text: root.ticking ? Translation.tr("Pause")
                    : TimerService.pomodoroRunning ? Translation.tr("Resume") : Translation.tr("Start focus")
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.colAccent
                elide: Text.ElideRight
            }
        }

        RippleButton {
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: root.radius
            enabled: TimerService.pomodoroRunning || TimerService.pomodoroBreak || TimerService.pomodoroCycle > 0
            opacity: enabled ? 1 : 0.4
            colBackground: "transparent"
            colBackgroundHover: ColorUtils.applyAlpha(root.colSubtext, 0.12)
            onClicked: TimerService.resetPomodoro()
            Accessible.name: Translation.tr("Reset")
            contentItem: MaterialSymbol {
                text: "restart_alt"
                iconSize: 20
                color: root.colSubtext
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            StyledToolTip { text: Translation.tr("Reset") }
        }
    }
}
