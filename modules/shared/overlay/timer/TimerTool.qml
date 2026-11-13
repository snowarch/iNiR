pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.overlay

// A timer, a stopwatch and focus sessions over the game, one at a time: the time left empties a ring around its
// figure, the stopwatch's ring sweeps each minute. The shell's own timers (TimerService), so the bar and sidebars
// show the same run. Pinned, only the ring and its controls stay.
StyledOverlayWidget {
    id: root
    resizable: false

    readonly property var modes: [
        { value: 0, label: "Timer" },
        { value: 1, label: "Stopwatch" },
        { value: 2, label: "Focus" }
    ]
    readonly property int mode: Math.max(0, Math.min(2, root.persistentStateEntry?.tabIndex ?? 0))
    // The bench closed on a pinned tool: what is set up stays out of the way.
    readonly property bool hud: root.actuallyPinned && !root.benchOpen

    readonly property var presets: [60, 300, 600, 1500, 2700]
    options: [
        { key: "time.pomodoro.focus", label: "Focus length", fallback: 1500,
            choices: [900, 1500, 2700, 3000].map(s => ({ value: s, label: Translation.tr("%1 min").arg(s / 60) })) },
        { key: "time.pomodoro.breakTime", label: "Break length", fallback: 300,
            choices: [300, 600, 900].map(s => ({ value: s, label: Translation.tr("%1 min").arg(s / 60) })) }
    ]

    function clock(seconds: int): string {
        const s = Math.max(0, seconds)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        const sec = String(s % 60).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec
    }

    // What the ring and its figure say for the chosen mode.
    readonly property bool running: [TimerService.countdownRunning, TimerService.stopwatchRunning, TimerService.pomodoroRunning][root.mode]
    readonly property bool paused: [TimerService.countdownPaused, TimerService.stopwatchPaused, TimerService.pomodoroPaused][root.mode]
    readonly property bool ticking: root.running && !root.paused
    readonly property bool countdownDone: !TimerService.countdownRunning && TimerService.countdownSecondsLeft <= 0
    readonly property int stopwatchSeconds: Math.floor(TimerService.stopwatchTime / 100)
    readonly property string figure: root.mode === 0 ? root.clock(TimerService.countdownSecondsLeft)
        : root.mode === 1 ? root.clock(root.stopwatchSeconds)
        : root.clock(TimerService.pomodoroSecondsLeft)
    readonly property real progress: root.mode === 0 ? TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration)
        : root.mode === 1 ? (root.stopwatchSeconds % 60) / 60
        : TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
    // Only what the figure and the mode don't already say.
    readonly property string caption: root.mode === 0 && root.countdownDone ? Translation.tr("Time's up")
        : root.paused ? Translation.tr("Paused")
        : root.mode !== 2 ? ""
        : TimerService.pomodoroLongBreak ? Translation.tr("Long break")
        : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
    readonly property color ringColor: root.mode === 2 && TimerService.pomodoroBreak ? OverlayLook.colSuccess
        : root.mode === 0 && root.countdownDone ? OverlayLook.colError : OverlayLook.colPrimary

    function toggle(): void {
        if (root.mode === 0) {
            if (root.countdownDone)
                TimerService.resetCountdown()
            TimerService.toggleCountdown()
        } else if (root.mode === 1) {
            TimerService.toggleStopwatch()
        } else {
            TimerService.togglePomodoro()
        }
    }
    function reset(): void {
        if (root.mode === 0) TimerService.resetCountdown()
        else if (root.mode === 1) TimerService.stopwatchReset()
        else TimerService.resetPomodoro()
    }
    function pickMode(value: int): void { root.persistentStateEntry.tabIndex = value }
    function setCountdown(seconds: int): void {
        TimerService.resetCountdown()
        TimerService.setCountdownDuration(seconds)
    }

    contentItem: Item {
        id: body
        anchors.fill: parent
        implicitWidth: Math.round(260 * root.d)
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Math.round(12 * root.d)

            // The ring, its figure inside.
            Item {
                id: dial
                readonly property int size: Math.round(188 * root.d)
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(4 * root.d)
                implicitWidth: dial.size
                implicitHeight: dial.size

                CircularProgress {
                    anchors.fill: parent
                    implicitSize: dial.size
                    lineWidth: Math.round(8 * root.d)
                    gapAngle: 360 / 40
                    value: Math.max(0, Math.min(1, root.progress))
                    animationDuration: 400
                    colPrimary: root.ringColor
                    colSecondary: OverlayLook.colRecessed
                }

                // Idle, the wheel sets the timer a minute at a time.
                WheelHandler {
                    enabled: root.mode === 0 && !TimerService.countdownRunning
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const steps = Math.round(event.angleDelta.y / 120)
                        if (steps !== 0) TimerService.adjustCountdownDuration(steps * 60)
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: Math.round(2 * root.d)
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        text: root.caption
                        color: root.mode === 0 && root.countdownDone ? OverlayLook.colError : OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                        font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        StyledText {
                            id: figureText
                            text: root.figure
                            color: OverlayLook.colOnLayer1
                            opacity: root.paused ? 0.6 : 1
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: Math.round(OverlayLook.typeFigure * 1.45)
                            font.weight: Font.DemiBold
                        }
                        // The stopwatch's hundredths, small, on the same baseline.
                        StyledText {
                            visible: root.mode === 1
                            anchors.baseline: figureText.baseline
                            text: "." + String(TimerService.stopwatchTime % 100).padStart(2, "0")
                            color: OverlayLook.colSubtext
                            font.family: OverlayLook.fontNumbers
                            font.features: ({ "tnum": 1 })
                            font.pixelSize: OverlayLook.typeLabel
                            font.weight: Font.DemiBold
                        }
                    }
                    // Under the figure: the set length, the laps, or the sessions of this round.
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: text.length > 0
                        text: root.mode === 0 ? (TimerService.countdownRunning ? Translation.tr("of %1").arg(root.clock(TimerService.countdownDuration)) : "")
                            : root.mode === 1 ? ((TimerService.stopwatchLaps?.length ?? 0) > 0 ? Translation.tr("Lap %1").arg(TimerService.stopwatchLaps.length + 1) : "")
                            : ""
                        color: OverlayLook.colFaint
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.mode === 2
                        topPadding: Math.round(4 * root.d)
                        spacing: Math.round(5 * root.d)
                        Repeater {
                            model: TimerService.cyclesBeforeLongBreak
                            Rectangle {
                                required property int index
                                readonly property bool done: index < TimerService.pomodoroCycle
                                readonly property bool now: index === TimerService.pomodoroCycle && !TimerService.pomodoroBreak
                                width: Math.round((now ? 14 : 6) * root.d)
                                height: Math.round(6 * root.d)
                                radius: height / 2
                                color: done || now ? root.ringColor : OverlayLook.colRecessed
                                Behavior on width { NumberAnimation { duration: FamilyStyle.moveDuration; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }
            }

            // Lengths to start from, while the timer is idle.
            OverlaySegments {
                Layout.fillWidth: true
                visible: root.mode === 0 && !TimerService.countdownRunning && !root.hud
                options: root.presets.map(s => ({ value: s, label: Translation.tr("%1 min").arg(s / 60) }))
                current: TimerService.countdownDuration
                accessibleName: Translation.tr("Length")
                onPicked: value => root.setCountdown(value)
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(14 * root.d)
                OverlayButton {
                    Layout.alignment: Qt.AlignVCenter
                    filled: true
                    glyph: "restart_alt"
                    tip: Translation.tr("Reset")
                    enabled: root.running || (root.mode === 1 && TimerService.stopwatchTime > 0) || (root.mode === 0 && root.countdownDone)
                    onClicked: root.reset()
                }
                OverlayButton {
                    Layout.alignment: Qt.AlignVCenter
                    strong: true
                    size: Math.round(48 * root.d)
                    glyph: root.ticking ? "pause" : "play_arrow"
                    tip: root.ticking ? Translation.tr("Pause") : root.paused ? Translation.tr("Resume") : Translation.tr("Start")
                    onClicked: root.toggle()
                }
                // The third place: a lap, or a minute more on a running timer.
                OverlayButton {
                    Layout.alignment: Qt.AlignVCenter
                    filled: true
                    readonly property bool applies: root.mode === 1 ? TimerService.stopwatchRunning : root.mode === 0 && TimerService.countdownRunning
                    opacity: applies ? 1 : 0
                    enabled: applies && root.ticking
                    glyph: root.mode === 1 ? "flag" : "more_time"
                    tip: root.mode === 1 ? Translation.tr("Lap") : Translation.tr("One minute more")
                    onClicked: root.mode === 1 ? TimerService.stopwatchRecordLap() : TimerService.adjustCountdownDuration(60)
                }
            }

            OverlaySegments {
                Layout.fillWidth: true
                visible: !root.hud
                options: root.modes
                current: root.mode
                accessibleName: Translation.tr("Mode")
                onPicked: value => root.pickMode(value)
            }
        }
    }
}
