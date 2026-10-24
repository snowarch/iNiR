pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

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

    // The key that starts and holds a timer: a plain disc, lit while it runs. A ring around it said the time a second
    // way and sat there full at rest.
    component Key: Rectangle {
        id: key
        required property var timer
        implicitHeight: key.implicitWidth
        radius: IrisStyle.capsule(width)
        scale: keyTap.pressed ? IrisStyle.pressScale(0.92) : 1
        color: root.live(key.timer) ? IrisStyle.tintFill(key.timer.tint) : keyHover.hovered ? root.fillHover : root.fill
        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Accessible.role: Accessible.Button
        Accessible.name: key.timer.label + ", " + key.timer.value
        MaterialSymbol {
            anchors.centerIn: parent
            text: root.live(key.timer) ? "pause" : "play_arrow"
            fill: 1
            iconSize: Math.round(key.width * 0.5)
            color: root.live(key.timer) ? key.timer.tint : root.ink
        }
        HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: keyTap
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: (point, button) => button === Qt.RightButton ? root.reset(key.timer.key) : root.toggle(key.timer.key)
        }
        WheelHandler {
            enabled: key.timer.key === "countdown" && !key.timer.running
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => TimerService.adjustCountdownDuration(event.angleDelta.y > 0 ? 60 : -60)
        }
    }

    function state(timer: var): string {
        return root.live(timer) ? Translation.tr("Running") : timer.paused ? Translation.tr("Paused") : Translation.tr("Ready")
    }
    readonly property var others: root.timers.filter(timer => timer.key !== root.lead.key)

    // Small and medium: the timer that matters leads (running, then held, then the countdown); medium lists the other
    // two beside it.
    RowLayout {
        visible: !root.large
        anchors.fill: parent
        spacing: root.dp(16)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            spacing: 0
            FaceHeader {
                face: root
                Layout.fillWidth: true
                glyph: root.lead.glyph
                text: root.lead.label
                tint: root.lead.tint
            }
            FaceFigure {
                face: root
                Layout.fillWidth: true
                text: root.lead.value
                size: root.small ? 36 : 40
                tone: root.live(root.lead) || root.lead.paused ? root.ink : root.inkSecondary
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillHeight: false
                Layout.fillWidth: true
                spacing: root.dp(8)
                Key {
                    implicitWidth: root.dp(40)
                    timer: root.lead
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: root.state(root.lead)
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
        // The other two share the height, each centred in its half (placed by y: a column of layouts bunched them
        // on the rule between them).
        Item {
            id: otherColumn
            visible: root.medium
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Repeater {
                model: root.medium ? root.others : []
                Item {
                    id: other
                    required property var modelData
                    required property int index
                    readonly property real pitch: otherColumn.height / Math.max(1, root.others.length)
                    y: Math.round(other.index * other.pitch)
                    width: otherColumn.width
                    height: Math.round((other.index + 1) * other.pitch) - y
                    Rectangle {
                        visible: other.index > 0
                        width: parent.width
                        height: 1
                        color: root.hairline
                    }
                    Column {
                        id: otherText
                        y: Math.round((parent.height - height) / 2)
                        width: parent.width - otherKey.width - root.dp(10)
                        FaceText {
                            face: root
                            width: Math.min(implicitWidth, otherText.width)
                            text: other.modelData.label
                            color: root.live(other.modelData) ? other.modelData.tint : root.inkSecondary
                            size: 12
                            weight: Font.DemiBold
                        }
                        FaceFigure {
                            face: root
                            text: other.modelData.value
                            size: 20
                            tone: root.live(other.modelData) || other.modelData.paused ? root.ink : root.inkSecondary
                        }
                    }
                    Key {
                        id: otherKey
                        implicitWidth: root.dp(32)
                        x: parent.width - width
                        y: Math.round((parent.height - height) / 2)
                        timer: other.modelData
                    }
                }
            }
        }
    }

    // Large: the three as rows, each its time leading, its name under it and its key at the end.
    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: 0
        FaceHeader {
            face: root
            Layout.fillWidth: true
            Layout.bottomMargin: root.dp(4)
            glyph: "timer"
            text: Translation.tr("Timers")
            tint: root.highlight
        }
        Repeater {
            model: root.large ? root.timers : []
            ColumnLayout {
                id: row
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                Rectangle {
                    visible: row.index > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: root.hairline
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: root.dp(12)
                    ColumnLayout {
                        Layout.fillHeight: false
                        Layout.fillWidth: true
                        spacing: 0
                        FaceText {
                            face: root
                            Layout.fillWidth: true
                            text: row.modelData.paused ? row.modelData.label + " · " + Translation.tr("Paused") : row.modelData.label
                            color: root.live(row.modelData) ? row.modelData.tint : root.inkSecondary
                            size: 12.5
                            weight: Font.DemiBold
                        }
                        FaceFigure {
                            face: root
                            text: row.modelData.value
                            size: 32
                            tone: root.live(row.modelData) || row.modelData.paused ? root.ink : root.inkSecondary
                        }
                    }
                    FaceAction {
                        face: root
                        visible: row.modelData.running || row.modelData.paused
                        glyph: "restart_alt"
                        name: Translation.tr("Reset")
                        tint: root.inkSecondary
                        onActivated: root.reset(row.modelData.key)
                    }
                    Key {
                        implicitWidth: root.dp(44)
                        timer: row.modelData
                    }
                }
            }
        }
    }
}
