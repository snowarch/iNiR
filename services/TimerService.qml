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
    property bool pomodoroPaused: Persistent.states?.timer?.pomodoro?.paused ?? false
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
    property bool stopwatchPaused: Persistent.states?.timer?.stopwatch?.paused ?? false
    property int stopwatchTime: 0
    property int stopwatchStart: Persistent.states?.timer?.stopwatch?.start ?? 0
    property var stopwatchLaps: Persistent.states?.timer?.stopwatch?.laps ?? []

    // Countdown Timer
    property bool countdownRunning: Persistent.states?.timer?.countdown?.running ?? false
    property bool countdownPaused: Persistent.states?.timer?.countdown?.paused ?? false
    property int countdownDuration: Persistent.states?.timer?.countdown?.duration ?? 300
    property int countdownSecondsLeft: countdownDuration

    // Initialize when Persistent is ready
    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready) {
                // Reset local state if not running (don't write to Persistent, just sync local vars)
                if (!root.stopwatchRunning) {
                    root.stopwatchTime = 0
                }
                if (!root.countdownRunning) {
                    root.countdownSecondsLeft = root.countdownDuration
                }
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

            Quickshell.execDetached(["/usr/bin/notify-send", "Pomodoro", notificationMessage, "-a", "Shell"]);
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
        running: root.pomodoroRunning && !root.pomodoroPaused
        repeat: true
        onTriggered: refreshPomodoro()
    }

    function togglePomodoro() {
        if (pomodoroRunning) {
            Persistent.states.timer.pomodoro.paused = !pomodoroPaused;
            if (!pomodoroPaused) {
                // Resuming - adjust start time
                Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds() + pomodoroSecondsLeft - pomodoroLapDuration;
            }
        } else {
            Persistent.states.timer.pomodoro.running = true;
            Persistent.states.timer.pomodoro.paused = false;
            Persistent.states.timer.pomodoro.start = getCurrentTimeInSeconds() + pomodoroSecondsLeft - pomodoroLapDuration;
        }
    }

    function stopPomodoro() {
        resetPomodoro();
    }

    function resetPomodoro() {
        Persistent.states.timer.pomodoro.running = false;
        Persistent.states.timer.pomodoro.paused = false;
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
        interval: 33
        running: root.stopwatchRunning && !root.stopwatchPaused
        repeat: true
        onTriggered: refreshStopwatch()
    }

    function toggleStopwatch() {
        if (root.stopwatchRunning) {
            Persistent.states.timer.stopwatch.paused = !stopwatchPaused;
            if (!stopwatchPaused) {
                // Resuming - adjust start time
                Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
            }
        } else {
            if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
            Persistent.states.timer.stopwatch.running = true;
            Persistent.states.timer.stopwatch.paused = false;
            Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
        }
    }

    function stopStopwatch() {
        stopwatchReset();
    }

    function stopwatchPause() {
        Persistent.states.timer.stopwatch.paused = true;
    }

    function stopwatchResume() {
        if (stopwatchTime === 0) Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.paused = false;
        Persistent.states.timer.stopwatch.start = getCurrentTimeIn10ms() - stopwatchTime;
        if (!stopwatchRunning) Persistent.states.timer.stopwatch.running = true;
    }

    function stopwatchReset() {
        stopwatchTime = 0;
        Persistent.states.timer.stopwatch.laps = [];
        Persistent.states.timer.stopwatch.running = false;
        Persistent.states.timer.stopwatch.paused = false;
    }

    function stopwatchRecordLap() {
        Persistent.states.timer.stopwatch.laps.push(stopwatchTime);
    }

    // Countdown Timer
    function refreshCountdown() {
        const elapsed = getCurrentTimeInSeconds() - Persistent.states.timer.countdown.start;
        countdownSecondsLeft = Math.max(0, countdownDuration - elapsed);
        
        if (countdownSecondsLeft <= 0 && countdownRunning) {
            Persistent.states.timer.countdown.running = false;
            Persistent.states.timer.countdown.paused = false;
            Quickshell.execDetached(["/usr/bin/notify-send", "Timer", Translation.tr("Time's up!"), "-a", "Shell", "-i", "alarm-symbolic"]);
            if (Config.options?.sounds?.timer ?? false) {
                Audio.playSystemSound("alarm-clock-elapsed");
            }
        }
    }

    Timer {
        id: countdownTimer
        interval: 200
        running: root.countdownRunning && !root.countdownPaused
        repeat: true
        onTriggered: refreshCountdown()
    }

    function toggleCountdown(): void {
        if (countdownRunning) {
            Persistent.states.timer.countdown.paused = !countdownPaused;
            if (!countdownPaused) {
                // Resuming - adjust start time
                Persistent.states.timer.countdown.start = getCurrentTimeInSeconds() - (countdownDuration - countdownSecondsLeft);
            }
        } else {
            Persistent.states.timer.countdown.running = true;
            Persistent.states.timer.countdown.paused = false;
            Persistent.states.timer.countdown.start = getCurrentTimeInSeconds() - (countdownDuration - countdownSecondsLeft);
        }
    }

    function stopCountdown(): void {
        resetCountdown();
    }

    function resetCountdown(): void {
        Persistent.states.timer.countdown.running = false;
        Persistent.states.timer.countdown.paused = false;
        countdownSecondsLeft = countdownDuration;
        Persistent.states.timer.countdown.start = getCurrentTimeInSeconds();
    }

    function setCountdownDuration(seconds: int): void {
        Persistent.states.timer.countdown.duration = seconds;
        countdownDuration = seconds;
        if (!countdownRunning) {
            countdownSecondsLeft = seconds;
        }
    }
}
