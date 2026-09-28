pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.bar.island

IrisWidgetFace {
    id: root

    readonly property var timers: [
        {
            key: "focus",
            glyph: TimerService.pomodoroBreak ? "coffee" : "target",
            label: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
                : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus"),
            value: root.widget.formatSeconds(TimerService.pomodoroSecondsLeft),
            running: TimerService.pomodoroRunning,
            paused: TimerService.pomodoroPaused,
            progress: 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration),
            tint: TimerService.pomodoroBreak ? IrisStyle.identity.green : root.highlight
        },
        {
            key: "stopwatch",
            glyph: "timer",
            label: Translation.tr("Stopwatch"),
            value: root.widget.formatSeconds(TimerService.stopwatchTime / 100),
            running: TimerService.stopwatchRunning,
            paused: TimerService.stopwatchPaused,
            progress: (TimerService.stopwatchTime / 100 % 60) / 60,
            tint: root.accent
        },
        {
            key: "countdown",
            glyph: "hourglass_top",
            label: Translation.tr("Timer"),
            value: root.widget.formatSeconds(TimerService.countdownSecondsLeft),
            running: TimerService.countdownRunning,
            paused: TimerService.countdownPaused,
            progress: 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration),
            tint: root.highlight
        }
    ]
    readonly property var lead: {
        const active = root.timers.filter(timer => timer.running && !timer.paused)
        const held = root.timers.filter(timer => timer.running || timer.paused)
        return active[0] ?? held[0] ?? root.timers[2]
    }

    function toggle(key: string): void {
        if (key === "focus") TimerService.togglePomodoro()
        else if (key === "stopwatch") TimerService.toggleStopwatch()
        else TimerService.toggleCountdown()
    }
    function reset(key: string): void {
        if (key === "focus") TimerService.resetPomodoro()
        else if (key === "stopwatch") TimerService.stopwatchReset()
        else TimerService.resetCountdown()
    }
    function live(timer: var): bool {
        return timer.running && !timer.paused
    }

    component Dial: Item {
        id: dial
        required property var timer
        Accessible.role: Accessible.Button
        Accessible.name: dial.timer.label + ", " + dial.timer.value
        ProgressRing {
            anchors.fill: parent
            progress: dial.timer.progress
            tint: dial.timer.tint
            stroke: Math.max(3, dial.width * 0.08)
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.62
            height: width
            radius: width / 2
            scale: dialTap.pressed ? IrisStyle.pressScale(0.92) : 1
            color: root.live(dial.timer) ? IrisStyle.tintFill(dial.timer.tint)
                : dialHover.hovered ? root.fillHover : root.fill
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.live(dial.timer) ? "pause" : "play_arrow"
                fill: 1
                iconSize: parent.width * 0.52
                color: root.live(dial.timer) ? dial.timer.tint : root.ink
            }
        }
        HoverHandler { id: dialHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: dialTap
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: (point, button) => button === Qt.RightButton ? root.reset(dial.timer.key) : root.toggle(dial.timer.key)
        }
        WheelHandler {
            enabled: dial.timer.key === "countdown" && !dial.timer.running
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => TimerService.adjustCountdownDuration(event.angleDelta.y > 0 ? 60 : -60)
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: root.lead.glyph
            text: root.lead.label
            tint: root.lead.tint
        }
        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(10)
            FaceFigure {
                face: root
                Layout.fillWidth: true
                text: root.lead.value
                size: 34
                color: root.live(root.lead) || root.lead.paused ? root.ink : root.inkSecondary
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: root.dp(8)
            spacing: root.dp(8)
            Dial {
                Layout.preferredWidth: root.dp(40)
                Layout.preferredHeight: root.dp(40)
                timer: root.lead
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.live(root.lead) ? Translation.tr("Running")
                    : root.lead.paused ? Translation.tr("Paused") : Translation.tr("Ready")
                color: root.inkTertiary
                size: 12
            }
            FaceAction {
                face: root
                visible: root.lead.running || root.lead.paused
                glyph: "restart_alt"
                name: Translation.tr("Reset")
                tint: root.inkSecondary
                onActivated: root.reset(root.lead.key)
            }
        }
    }

    RowLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(12)
        Repeater {
            model: root.small ? [] : root.timers
            ColumnLayout {
                id: column
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                spacing: root.dp(6)
                Dial {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.dp(62)
                    Layout.preferredHeight: root.dp(62)
                    timer: column.modelData
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: column.modelData.value
                    size: 16
                    weight: Font.DemiBold
                    color: root.live(column.modelData) || column.modelData.paused ? root.ink : root.inkSecondary
                    font.family: root.fontNumbers
                    font.features: ({ "tnum": 1 })
                }
                FaceText {
                    face: root
                    Layout.alignment: Qt.AlignHCenter
                    text: column.modelData.label
                    color: root.live(column.modelData) ? column.modelData.tint : root.inkTertiary
                    size: 11.5
                    weight: Font.DemiBold
                }
            }
        }
    }
}
