pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common

import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Simple Pomodoro time manager.
 */
Singleton {
    id: root

    // Pomodoro config - use explicit properties to ensure reactivity
    property int focusTime: 1500
    property int breakTime: 300
    property int longBreakTime: 900
    property int cyclesBeforeLongBreak: 4

    // Helper to sync all pomodoro values from Config
    function _syncPomodoroConfig() {
        root.focusTime = Config.options?.time?.pomodoro?.focus ?? 1500
        root.breakTime = Config.options?.time?.pomodoro?.breakTime ?? 300
        root.longBreakTime = Config.options?.time?.pomodoro?.longBreak ?? 900
        root.cyclesBeforeLongBreak = Config.options?.time?.pomodoro?.cyclesBeforeLongBreak ?? 4
    }

    // Sync pomodoro config from Config.options.time.pomodoro
    Connections {
        target: Config.options?.time?.pomodoro ?? null
        function onFocusChanged() { root._syncPomodoroConfig() }
        function onBreakTimeChanged() { root._syncPomodoroConfig() }
        function onLongBreakChanged() { root._syncPomodoroConfig() }
        function onCyclesBeforeLongBreakChanged() { root._syncPomodoroConfig() }
    }

    // Re-sync when Config becomes ready or options change
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._syncPomodoroConfig()
        }
    }

    // Also sync when time object changes (in case pomodoro object is recreated)
    Connections {
        target: Config.options?.time ?? null
        function onPomodoroChanged() { root._syncPomodoroConfig() }
    }

    Component.onCompleted: {
        if (Config.ready) root._syncPomodoroConfig()
    }

    property bool pomodoroRunning: Persistent.states?.timer?.pomodoro?.running ?? false
    property bool pomodoroBreak: Persistent.states?.timer?.pomodoro?.isBreak ?? false
    property bool pomodoroLongBreak: pomodoroBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak)
    property int pomodoroLapDuration: pomodoroLongBreak ? longBreakTime : pomodoroBreak ? breakTime : focusTime
    property int pomodoroSecondsLeft: pomodoroLapDuration
    property int pomodoroCycle: Persistent.states?.timer?.pomodoro?.cycle ?? 0

    // When focusTime changes and timer is not running, reset pomodoroSecondsLeft
    onFocusTimeChanged: {
        if (!pomodoroRunning && !pomodoroBreak) {
            pomodoroSecondsLeft = focusTime
        }
    }
    onBreakTimeChanged: {
        if (!pomodoroRunning && pomodoroBreak && !pomodoroLongBreak) {
            pomodoroSecondsLeft = breakTime
        }
    }
    onLongBreakTimeChanged: {
        if (!pomodoroRunning && pomodoroLongBreak) {
            pomodoroSecondsLeft = longBreakTime
        }
    }

    property bool stopwatchRunning: Persistent.states?.timer?.stopwatch?.running ?? false
    property int stopwatchTime: 0
    property int stopwatchStart: Persistent.states?.timer?.stopwatch?.start ?? 0
    property var stopwatchLaps: Persistent.states?.timer?.stopwatch?.laps ?? []

    // Countdown Timer
    property bool countdownRunning: Persistent.states?.timer?.countdown?.running ?? false
    property int countdownDuration: Persistent.states?.timer?.countdown?.duration ?? 300
    property int countdownSecondsLeft: countdownDuration

    function _timerStateReady(): bool {
        // Be strict: our functions below assume the nested objects exist.
        return !!(Persistent.ready
                  && Persistent.states?.timer
                  && Persistent.states.timer.pomodoro
                  && Persistent.states.timer.stopwatch
                  && Persistent.states.timer.countdown)
    }

    // Initialize when Persistent is ready
    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.ready)
                return

            // Reset local state if not running (don't write to Persistent, just sync local vars)
            if (!root.stopwatchRunning) {
                root.stopwatchTime = 0
            } else {
                // Refresh from persisted start
                root.stopwatchTime = root.getCurrentTimeIn10ms() - root.stopwatchStart
            }

            if (!root.countdownRunning) {
                root.countdownSecondsLeft = root.countdownDuration
            } else {
                root.refreshCountdown()
            }

            if (root.pomodoroRunning) {
                root.refreshPomodoro()
            }
        }
    }

    function getCurrentTimeInSeconds() {  // Pomodoro uses Seconds
        return Math.floor(Date.now() / 1000);
    }

    function getCurrentTimeIn10ms() {  // Stopwatch uses 10ms
        return Math.floor(Date.now() / 10);
    }

    // Pomodoro
    function refreshPomodoro() {
        if (!root._timerStateReady())
            return

        // Work <-> break ?
        if (getCurrentTimeInSeconds() >= Persistent.states.timer.pomodoro.start + pomodoroLapDuration) {
            // Reset counts
            Persistent.states.timer.pomodoro.isBreak = !Persistent.states.timer.pomodoro.isBreak;
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();

            // Send notification
            let notificationMessage;
            if (Persistent.states.timer.pomodoro.isBreak && (pomodoroCycle + 1 == cyclesBeforeLongBreak)) {
                notificationMessage = Translation.tr(`🌿 Long break: %1 minutes`).arg(Math.floor(longBreakTime / 60));
            } else if (Persistent.states.timer.pomodoro.isBreak) {
                notificationMessage = Translation.tr(`☕ Break: %1 minutes`).arg(Math.floor(breakTime / 60));
            } else {
                notificationMessage = Translation.tr(`🔴 Focus: %1 minutes`).arg(Math.floor(focusTime / 60));
            }

            Quickshell.execDetached(["notify-send", "Pomodoro", notificationMessage, "-a", "Shell"]);
            if (Config.options?.sounds?.pomodoro ?? false) {
                Audio.playSystemSound("alarm-clock-elapsed")
            }

            if (!pomodoroBreak) {
                Persistent.states.timer.pomodoro.cycle = (Persistent.states.timer.pomodoro.cycle + 1) % root.cyclesBeforeLongBreak;
            }
        }

        pomodoroSecondsLeft = pomodoroLapDuration - (getCurrentTimeInSeconds() - Persistent.states.timer.pomodoro.start);
    }

    Timer {
        id: pomodoroTimer
        interval: 200
        running: root.pomodoroRunning
        repeat: true
        onTriggered: refreshPomodoro()
    }

    function togglePomodoro() {
        if (!root._timerStateReady())
            return

        Persistent.states.timer.pomodoro.running = !pomodoroRunning;
        if (Persistent.states.timer.pomodoro.running) {
            // Start/Resume
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds() + pomodoroSecondsLeft - pomodoroLapDuration;
        }
    }

    function resetPomodoro() {
        if (!root._timerStateReady())
            return

        Persistent.states.timer.pomodoro.running = false;
        Persistent.states.timer.pomodoro.isBreak = false;
        Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds();
        Persistent.states.timer.pomodoro.cycle = 0;
        refreshPomodoro();
    }

    // Stopwatch
    function refreshStopwatch() {  // Stopwatch stores time in 10ms
        stopwatchTime = getCurrentTimeIn10ms() - stopwatchStart;
    }

    Timer {
        id: stopwatchTimer
        interval: 10
        running: root.stopwatchRunning
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning)
            stopwatchPause();
        else
            stopwatchResume();
    }

    function stopwatchPause() {
        if (!root._timerStateReady())
            return

        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchResume() {
        if (!root._timerStateReady())
            return

        if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = true;
        Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
    }

    function stopwatchReset() {
        if (!root._timerStateReady()) {
            stopwatchTime = 0;
            return
        }

        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
    }

    function stopwatchRecordLap() {
        if (!root._timerStateReady())
            return

        Persistent.states.timer.stopwatch.laps.push(stopwatchTime);
    }

    // Countdown Timer
    function refreshCountdown() {
        if (!root._timerStateReady())
            return

        const elapsed = getCurrentTimeInSeconds() - Persistent.states.timer.countdown.start;
        countdownSecondsLeft = Math.max(0, countdownDuration - elapsed);

        if (countdownSecondsLeft <= 0 && countdownRunning) {
            Persistent.states.timer.countdown.running = false;
            Quickshell.execDetached(["notify-send", "Timer", Translation.tr("Time's up!"), "-a", "Shell", "-i", "alarm-symbolic"]);
            if (Config.options?.sounds?.timer ?? false) {
                Audio.playSystemSound("alarm-clock-elapsed");
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 200
        running: root.countdownRunning
        repeat: true
        onTriggered: refreshCountdown()
    }

    function toggleCountdown(): void {
        if (!root._timerStateReady())
            return

        Persistent.states.timer.countdown.running = !countdownRunning;
        if (Persistent.states.timer.countdown.running) {
            Persistent.states.timer.countdown.start = getCurrentTimeInSeconds() - (countdownDuration - countdownSecondsLeft);
        }
    }

    function resetCountdown(): void {
        if (!root._timerStateReady()) {
            countdownSecondsLeft = countdownDuration
            return
        }

        Persistent.states.timer.countdown.running = false;
        countdownSecondsLeft = countdownDuration;
        Persistent.states.timer.countdown.start = getCurrentTimeInSeconds();
    }

    function setCountdownDuration(seconds: int): void {
        countdownDuration = seconds;

        if (!root._timerStateReady()) {
            if (!countdownRunning)
                countdownSecondsLeft = seconds
            return
        }

        Persistent.states.timer.countdown.duration = seconds;
        if (!countdownRunning) {
            countdownSecondsLeft = seconds;
        }
    }
}
