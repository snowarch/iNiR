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

    property bool showTimerIdle: false
    readonly property bool timerActive: TimerService.pomodoroRunning || TimerService.stopwatchRunning || TimerService.countdownRunning
    readonly property bool weatherEnabled: (Config.options?.sidebar?.widgets?.contextShowWeather ?? true) && Weather.enabled && Weather.data.temp && !Weather.data.temp.startsWith("--")

    // Reset showTimerIdle when timer starts
    onTimerActiveChanged: if (timerActive) showTimerIdle = false

    readonly property string mode: {
        if (timerActive) return "timer"
        if (showTimerIdle) return "timerIdle"
        if (weatherEnabled) return "weather"
        if (!(Config.options?.sidebar?.widgets?.contextShowWeather ?? true)) return "timerIdle"
        return "none"
    }

    StyledRectangularShadow { target: card; visible: !Appearance.auroraEverywhere }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width
        implicitHeight: stack.implicitHeight + 16
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? "transparent" 
             : Appearance.colors.colLayer1
        border.width: Appearance.auroraEverywhere ? 0 : 1
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border

        StackLayout {
            id: stack
            anchors.fill: parent
            anchors.margins: 8
            currentIndex: root.mode === "timer" ? 0 : root.mode === "weather" ? 1 : 2

            // Fade transition between views
            Behavior on currentIndex {
                enabled: Appearance.animationsEnabled
                SequentialAnimation {
                    PropertyAnimation { target: stack; property: "opacity"; to: 0; duration: 100 }
                    PropertyAction { }
                    PropertyAnimation { target: stack; property: "opacity"; to: 1; duration: 150 }
                }
            }

            // ═══════════════════════════════════════════
            // TIMER ACTIVE VIEW
            // ═══════════════════════════════════════════
            ColumnLayout {
                id: timerView
                spacing: 6

                readonly property string activeTimer: TimerService.pomodoroRunning ? "pomodoro" :
                    TimerService.stopwatchRunning ? "stopwatch" : "countdown"
                readonly property bool isPaused: activeTimer === "pomodoro" ? (TimerService.pomodoroPaused ?? false) :
                    activeTimer === "stopwatch" ? (TimerService.stopwatchPaused ?? false) : (TimerService.countdownPaused ?? false)

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: timerView.activeTimer === "pomodoro" 
                            ? (TimerService.pomodoroBreak ? "coffee" : "target")
                            : timerView.activeTimer === "stopwatch" ? "timer" : "hourglass_top"
                        iconSize: 16
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: timerView.activeTimer === "pomodoro" 
                            ? (TimerService.pomodoroBreak 
                                ? (TimerService.pomodoroLongBreak ? Translation.tr("Long Break") : Translation.tr("Break"))
                                : Translation.tr("Focus"))
                            : timerView.activeTimer === "stopwatch" ? Translation.tr("Stopwatch")
                            : Translation.tr("Timer")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }

                    // Cycle badge for pomodoro
                    Rectangle {
                        visible: timerView.activeTimer === "pomodoro"
                        implicitWidth: cycleText.implicitWidth + 8
                        implicitHeight: 16
                        radius: 8
                        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : Appearance.colors.colSecondaryContainer

                        StyledText {
                            id: cycleText
                            anchors.centerIn: parent
                            text: "%1/%2".arg(TimerService.pomodoroCycle + 1).arg(TimerService.cyclesBeforeLongBreak)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                                : Appearance.colors.colOnSecondaryContainer
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Controls
                    RowLayout {
                        spacing: 2

                        SmallIconButton {
                            iconName: timerView.isPaused ? "play_arrow" : "pause"
                            onClicked: {
                                if (timerView.activeTimer === "pomodoro") TimerService.togglePomodoro()
                                else if (timerView.activeTimer === "stopwatch") TimerService.toggleStopwatch()
                                else TimerService.toggleCountdown()
                            }
                            StyledToolTip { text: timerView.isPaused ? Translation.tr("Resume") : Translation.tr("Pause") }
                        }

                        SmallIconButton {
                            iconName: "stop"
                            onClicked: {
                                if (timerView.activeTimer === "pomodoro") TimerService.stopPomodoro()
                                else if (timerView.activeTimer === "stopwatch") TimerService.stopStopwatch()
                                else TimerService.stopCountdown()
                            }
                            StyledToolTip { text: Translation.tr("Stop") }
                        }
                    }
                }

                // Time display
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        if (timerView.activeTimer === "pomodoro") return formatTime(TimerService.pomodoroSecondsLeft)
                        if (timerView.activeTimer === "stopwatch") return formatStopwatch(TimerService.stopwatchTime)
                        return formatTime(TimerService.countdownSecondsLeft)
                    }
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.4
                    font.weight: Font.Light
                    font.family: Appearance.font.family.monospace
                    color: timerView.isPaused 
                        ? (Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colSubtext)
                        : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1)
                }

                // Progress
                StyledProgressBar {
                    Layout.fillWidth: true
                    visible: timerView.activeTimer !== "stopwatch"
                    value: timerView.activeTimer === "pomodoro"
                        ? TimerService.pomodoroSecondsLeft / (TimerService.pomodoroLapDuration || 1)
                        : TimerService.countdownSecondsLeft / (TimerService.countdownDuration || 1)
                    highlightColor: timerView.isPaused 
                        ? (Appearance.inirEverywhere ? Appearance.inir.colTextMuted : Appearance.colors.colSubtext)
                        : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                    trackColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colSecondaryContainer
                }
            }

            // ═══════════════════════════════════════════
            // WEATHER VIEW
            // ═══════════════════════════════════════════
            ColumnLayout {
                spacing: 6

                // Main row: icon + temp + description
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    MaterialSymbol {
                        text: Icons.getWeatherIcon(Weather.data.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: 36
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Weather.data.temp
                        font.pixelSize: Appearance.font.pixelSize.huge * 1.3
                        font.weight: Font.Medium
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }

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

                    SmallIconButton {
                        iconName: "refresh"
                        onClicked: Weather.fetchWeather()
                        StyledToolTip { text: Translation.tr("Refresh") }
                    }

                    SmallIconButton {
                        iconName: "timer"
                        onClicked: root.showTimerIdle = true
                        StyledToolTip { text: Translation.tr("Timer") }
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

            // ═══════════════════════════════════════════
            // TIMER IDLE VIEW (when weather disabled)
            // ═══════════════════════════════════════════
            ColumnLayout {
                id: idleView
                spacing: 6

                property int tab: Persistent.states?.timer?.tab ?? 0
                property int _prevTab: 0
                readonly property var tabs: [
                    { icon: "target", label: Translation.tr("Focus") },
                    { icon: "hourglass_empty", label: Translation.tr("Timer") },
                    { icon: "timer", label: Translation.tr("Stopwatch") }
                ]

                onTabChanged: {
                    // Trigger slide animation
                    contentItem.slideDirection = tab > _prevTab ? 1 : -1
                    contentItem.opacity = 0
                    contentItem.x = contentItem.slideDirection * 20
                    slideInAnim.start()
                    _prevTab = tab
                }

                // Header with icon and label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: idleView.tabs[idleView.tab].icon
                        iconSize: 16
                        fill: 1
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary 
                            : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                            : Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: idleView.tabs[idleView.tab].label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                    }

                    Item { Layout.fillWidth: true }

                    // Back to weather (only if weather is available)
                    SmallIconButton {
                        visible: root.weatherEnabled
                        iconName: "cloud"
                        onClicked: root.showTimerIdle = false
                        StyledToolTip { text: Translation.tr("Weather") }
                    }

                    // Navigation arrows
                    Row {
                        spacing: 0

                        SmallIconButton {
                            iconName: "chevron_left"
                            opacity: idleView.tab > 0 ? 1 : 0.3
                            enabled: idleView.tab > 0
                            onClicked: { idleView.tab--; if (Persistent?.states?.timer) Persistent.states.timer.tab = idleView.tab }
                        }

                        SmallIconButton {
                            iconName: "chevron_right"
                            opacity: idleView.tab < 2 ? 1 : 0.3
                            enabled: idleView.tab < 2
                            onClicked: { idleView.tab++; if (Persistent?.states?.timer) Persistent.states.timer.tab = idleView.tab }
                        }
                    }
                }

                // Time display - centered, clickeable
                Item {
                    id: contentItem
                    property int slideDirection: 1
                    Layout.fillWidth: true
                    Layout.preferredHeight: timeRow.implicitHeight + 16

                    ParallelAnimation {
                        id: slideInAnim
                        NumberAnimation { target: contentItem; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
                        NumberAnimation { target: contentItem; property: "x"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        id: timeRow
                        anchors.centerIn: parent
                        spacing: 10

                        StyledText {
                            text: idleView.tab === 0 ? formatTime(TimerService.focusTime)
                                : idleView.tab === 1 ? formatTime(TimerService.countdownDuration)
                                : "00:00.00"
                            font.pixelSize: Appearance.font.pixelSize.huge * 1.5
                            font.weight: Font.Light
                            font.family: Appearance.font.family.monospace
                            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                        }

                        Rectangle {
                            implicitWidth: playIcon.implicitWidth + 12
                            implicitHeight: playIcon.implicitHeight + 8
                            radius: height / 2
                            color: timeMouseArea.containsMouse
                                ? (Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                    : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                                    : Appearance.colors.colPrimary)
                                : (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                    : Appearance.colors.colSecondaryContainer)
                            Behavior on color { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                            MaterialSymbol {
                                id: playIcon
                                anchors.centerIn: parent
                                text: "play_arrow"
                                iconSize: 18
                                color: timeMouseArea.containsMouse
                                    ? Appearance.colors.colOnPrimary
                                    : (Appearance.inirEverywhere ? Appearance.inir.colText
                                        : Appearance.auroraEverywhere ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnSecondaryContainer)
                                Behavior on color { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                            }
                        }
                    }

                    MouseArea {
                        id: timeMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (idleView.tab === 0) TimerService.togglePomodoro()
                            else if (idleView.tab === 1) TimerService.toggleCountdown()
                            else TimerService.toggleStopwatch()
                        }
                        onWheel: (wheel) => {
                            if (idleView.tab === 1) {
                                const d = wheel.angleDelta.y > 0 ? 60 : -60
                                TimerService.setCountdownDuration(Math.max(60, Math.min(5940, TimerService.countdownDuration + d)))
                            }
                        }
                    }

                    StyledToolTip {
                        extraVisibleCondition: timeMouseArea.containsMouse
                        text: idleView.tab === 1 
                            ? Translation.tr("Scroll to adjust") 
                            : ""
                        visible: idleView.tab === 1 && timeMouseArea.containsMouse
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════
    // INLINE COMPONENTS
    // ═══════════════════════════════════════════

    component SmallIconButton: RippleButton {
        property string iconName
        implicitWidth: 26; implicitHeight: 26
        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : 13
        colBackground: "transparent"
        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
            : Appearance.colors.colLayer2Hover
        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
            : Appearance.colors.colLayer2Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: iconName
            iconSize: 16
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
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
            visible: statHover.containsMouse && tip !== ""
        }
    }

    function formatTime(s) {
        const m = Math.floor(s / 60)
        const sec = s % 60
        return `${m.toString().padStart(2, '0')}:${sec.toString().padStart(2, '0')}`
    }

    function formatStopwatch(cs) {
        const totalS = Math.floor(cs / 100)
        const m = Math.floor(totalS / 60)
        const s = totalS % 60
        const ms = cs % 100
        return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}.${ms.toString().padStart(2, '0')}`
    }
}
