pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin
    visible: mode !== "none"

    readonly property string mode: {
        if (TimerService.pomodoroRunning || TimerService.stopwatchRunning || TimerService.countdownRunning)
            return "timer"
        if (Weather.enabled && Weather.data.temp && !Weather.data.temp.startsWith("--"))
            return "weather"
        return "none"
    }

    StyledRectangularShadow { target: card; visible: !Appearance.auroraEverywhere }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width
        implicitHeight: stack.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? "transparent" 
             : Appearance.colors.colLayer1
        border.width: Appearance.auroraEverywhere ? 0 : 1
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border

        StackLayout {
            id: stack
            anchors.fill: parent
            anchors.margins: 12
            currentIndex: root.mode === "timer" ? 0 : 1

            // Timer View
            ColumnLayout {
                id: timerView
                spacing: 6

                readonly property string activeTimer: TimerService.pomodoroRunning ? "pomodoro" :
                    TimerService.stopwatchRunning ? "stopwatch" : "countdown"
                readonly property bool isPaused: timerView.activeTimer === "pomodoro" ? (TimerService.pomodoroPaused ?? false) :
                    timerView.activeTimer === "stopwatch" ? (TimerService.stopwatchPaused ?? false) : (TimerService.countdownPaused ?? false)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: timerView.activeTimer === "pomodoro" ? "search_activity" :
                              timerView.activeTimer === "stopwatch" ? "timer" : "hourglass_empty"
                        iconSize: 18
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: timerView.activeTimer === "pomodoro" ?
                              (TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")) :
                              timerView.activeTimer === "stopwatch" ? Translation.tr("Stopwatch") :
                              Translation.tr("Timer")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    Item { Layout.fillWidth: true }

                    // Pause/Resume button
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                        colRipple: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                        onClicked: {
                            if (timerView.activeTimer === "pomodoro") TimerService.pomodoroPaused = !TimerService.pomodoroPaused
                            else if (timerView.activeTimer === "stopwatch") TimerService.stopwatchPaused = !TimerService.stopwatchPaused
                            else TimerService.countdownPaused = !TimerService.countdownPaused
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: timerView.isPaused ? "play_arrow" : "pause"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        StyledToolTip { text: timerView.isPaused ? Translation.tr("Resume") : Translation.tr("Pause") }
                    }

                    // Stop button
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colErrorContainer
                        colRipple: Appearance.colors.colError
                        onClicked: {
                            if (timerView.activeTimer === "pomodoro") TimerService.stopPomodoro()
                            else if (timerView.activeTimer === "stopwatch") TimerService.stopStopwatch()
                            else TimerService.stopCountdown()
                        }

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "stop"
                                iconSize: 16
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        StyledToolTip { text: Translation.tr("Stop") }
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        if (timerView.activeTimer === "pomodoro")
                            return formatMmSs(TimerService.pomodoroSecondsLeft)
                        if (timerView.activeTimer === "stopwatch")
                            return formatStopwatch(TimerService.stopwatchTime)
                        return formatMmSs(TimerService.countdownSecondsLeft)
                    }
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.5
                    font.weight: Font.Light
                    font.family: Appearance.font.family.monospace
                    color: timerView.isPaused ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    animateChange: true

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }

                StyledProgressBar {
                    id: timerProgress
                    Layout.fillWidth: true
                    visible: timerView.activeTimer !== "stopwatch"
                    value: timerView.activeTimer === "pomodoro"
                        ? TimerService.pomodoroSecondsLeft / (TimerService.pomodoroLapDuration || 1)
                        : TimerService.countdownSecondsLeft / (TimerService.countdownDuration || 1)
                    highlightColor: timerView.isPaused ? Appearance.colors.colSubtext : Appearance.colors.colPrimary
                    trackColor: Appearance.colors.colSecondaryContainer

                    Behavior on highlightColor {
                        enabled: Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(timerProgress)
                    }
                }
            }

            // Weather View - Minimalist
            ColumnLayout {
                spacing: Appearance.inirEverywhere ? 10 : 8

                // Main row: icon + temp + feels like
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Weather icon (no background)
                    MaterialSymbol {
                        text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: 36
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    }

                    // Temperature
                    StyledText {
                        text: Weather.data.temp
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.3
                        font.weight: Font.Medium
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }

                    // Description
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.data.description || Translation.tr("Weather")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Weather.data.city
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }
                    }

                    // Refresh button
                    RippleButton {
                        implicitWidth: 28; implicitHeight: 28
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover 
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                        onClicked: Weather.fetchWeather()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "refresh"
                                iconSize: 16
                                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                            }
                        }

                        StyledToolTip { text: Translation.tr("Refresh weather") }
                    }
                }

                // Details row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    WeatherStat { icon: "humidity_percentage"; value: Weather.data.humidity; tip: Translation.tr("Humidity") }
                    WeatherStat { icon: "air"; value: Weather.data.wind; tip: Translation.tr("Wind") }
                    WeatherStat { 
                        icon: "thermostat"
                        value: Weather.data.tempFeelsLike
                        tip: Translation.tr("Feels like")
                        visible: Weather.data.tempFeelsLike && !Weather.data.tempFeelsLike.startsWith("--")
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    component WeatherStat: Item {
        property string icon
        property string value
        property string tip: ""
        implicitWidth: statRow.implicitWidth
        implicitHeight: statRow.implicitHeight

        RowLayout {
            id: statRow
            spacing: 4

            MaterialSymbol {
                text: icon
                iconSize: 14
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
            StyledText {
                text: value
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.numbers
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            }
        }

        MouseArea {
            id: statHover
            anchors.fill: parent
            hoverEnabled: true
        }

        StyledToolTip {
            text: tip
            extraVisibleCondition: false
            alternativeVisibleCondition: statHover.containsMouse && tip !== ""
        }
    }

    function formatMmSs(s) {
        const m = Math.floor(s / 60)
        const sec = s % 60
        return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`
    }

    function formatStopwatch(cs) {
        const totalS = Math.floor(cs / 100)
        const m = Math.floor(totalS / 60)
        const s = totalS % 60
        const c = cs % 100
        return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}.${c.toString().padStart(2, '0')}`
    }
}
