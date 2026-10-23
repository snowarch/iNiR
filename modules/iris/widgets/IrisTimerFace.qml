pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.bar.island

IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetTimers")

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
            tint: root.nothing ? (TimerService.pomodoroRunning && !TimerService.pomodoroPaused ? root.signal : root.ink)
                : TimerService.pomodoroBreak ? IrisStyle.identity.green : root.highlight
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
            // Nothing: a timer is ink until it runs; running, it is the one live thing and wears the signal.
            tint: root.nothing ? (TimerService.countdownRunning && !TimerService.countdownPaused ? root.signal : root.ink) : root.highlight
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
            radius: IrisStyle.capsule(width)
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
                tone: root.live(root.lead) || root.lead.paused ? root.ink : root.inkSecondary
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

    // Medium: each timer on its own tile, as the gauges of the weather and vitals cards: what it is, its figure, the
    // play key and how far the lap has gone. A running tile takes its colour.
    RowLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(8)
        Repeater {
            model: root.small ? [] : root.timers
            Rectangle {
                id: tile
                required property var modelData
                readonly property bool running: root.live(tile.modelData)
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                radius: root.innerRadius
                color: tile.running ? Qt.alpha(tile.modelData.tint, 0.16) : root.fillQuiet
                Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                Accessible.role: Accessible.Button
                Accessible.name: tile.modelData.label + ", " + tile.modelData.value

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.dp(10)
                    spacing: root.dp(2)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.dp(4)
                        MaterialSymbol {
                            text: tile.modelData.glyph
                            fill: 1
                            iconSize: root.px(13)
                            color: tile.running ? tile.modelData.tint : root.inkSecondary
                        }
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            text: tile.modelData.label
                            size: 11.5
                            weight: Font.DemiBold
                            color: tile.running ? root.ink : root.inkSecondary
                        }
                    }
                    FaceFigure {
                        face: root
                        Layout.fillWidth: true
                        text: tile.modelData.value
                        size: 24
                        tone: tile.running || tile.modelData.paused ? root.ink : root.inkSecondary
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.dp(8)
                        Rectangle {
                            implicitWidth: root.dp(30)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: tile.running ? tile.modelData.tint : keyHover.hovered ? root.fillHover : root.fill
                            scale: keyTap.pressed ? IrisStyle.pressScale(0.9) : 1
                            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: tile.running ? "pause" : "play_arrow"
                                fill: 1
                                iconSize: root.px(17)
                                color: tile.running ? root.onFill(tile.modelData.tint) : root.ink
                            }
                            HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: keyTap
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                gesturePolicy: TapHandler.WithinBounds
                                onTapped: (point, button) => button === Qt.RightButton ? root.reset(tile.modelData.key) : root.toggle(tile.modelData.key)
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: root.dp(4)
                            radius: height / 2
                            color: root.fill
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, tile.modelData.progress))
                                height: parent.height
                                radius: height / 2
                                color: tile.modelData.tint
                                Behavior on width { enabled: root.moving; NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
                WheelHandler {
                    enabled: tile.modelData.key === "countdown" && !tile.modelData.running
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => TimerService.adjustCountdownDuration(event.angleDelta.y > 0 ? 60 : -60)
                }
            }
        }
    }
}
