pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "timers"
    defaultConfig: ({
        placementStrategy: "free", vertical: false,
        widgetScale: 100, widgetOpacity: 100,
        showBackground: false, useBlur: false, showBorder: false,
        backgroundOpacity: 0, borderWidth: 0, borderOpacity: 0.16,
        cornerRadius: -1, colorMode: "auto", dim: 0,
        x: 360, y: 420
    })

    readonly property bool vertical: Boolean(root._readConfigKey("vertical") ?? false)
    readonly property real cardWidth: Math.round(136 * root.scaleFactor)
    readonly property real cardHeight: Math.round(120 * root.scaleFactor)
    readonly property real cardSpacing: Math.round(12 * root.scaleFactor)

    implicitWidth: timerGrid.implicitWidth
    implicitHeight: timerGrid.implicitHeight
    visibleWhenLocked: true
    needsColText: false
    draggable: GlobalStates.widgetEditMode && !GlobalStates.screenLocked && !root.locked

    function formatSeconds(seconds: real): string {
        const total = Math.max(0, Math.floor(Number(seconds) || 0))
        const minutes = Math.floor(total / 60).toString().padStart(2, "0")
        const secs = (total % 60).toString().padStart(2, "0")
        return minutes + ":" + secs
    }

    function addCountdownMinutes(minutes: int): void {
        const next = Math.min(24 * 60 * 60,
            Math.max(60, TimerService.countdownSecondsLeft + minutes * 60))
        TimerService.setCountdownDuration(next)
    }

    editPopoverContent: Component {
        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignHCenter

            Repeater {
                model: [
                    { label: "Horizontal", icon: "view_week", value: false },
                    { label: "Vertical", icon: "view_agenda", value: true }
                ]
                SelectionGroupButton {
                    required property var modelData
                    leftmost: true
                    rightmost: true
                    buttonIcon: modelData.icon
                    buttonText: Translation.tr(modelData.label)
                    toggled: root.vertical === modelData.value
                    onClicked: Config.setNestedValue("background.widgets.timers.vertical", modelData.value)
                }
            }
        }
    }

    component TimerCard: Rectangle {
        id: timerCard

        required property string icon
        required property string value
        required property string label
        required property bool running
        required property bool paused
        required property int shape
        required property string semanticRole
        property var toggleAction: () => {}
        property var resetAction: () => {}
        default property alias footerData: footerSlot.data

        readonly property color face: root.widgetSemanticContainer(timerCard.semanticRole)
        readonly property color ink: root.widgetSemanticOnContainer(timerCard.semanticRole)

        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: Math.min(Appearance.rounding.verylarge, height / 3)
        color: timerCard.face
        border.width: root.showBorder ? Math.max(1, Math.round(root.borderWidth)) : 0
        border.color: ColorUtils.applyAlpha(timerCard.ink, root.borderOpacity)

        StyledRectangularShadow {
            target: timerCard
            visible: Appearance.effectsEnabled && !Appearance.gameModeMinimal
            z: -2
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: timerCard.resetAction()
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(12 * root.scaleFactor)
            spacing: Math.round(4 * root.scaleFactor)

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: timerCard.label
                    color: ColorUtils.applyAlpha(timerCard.ink, 0.68)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                RippleButton {
                    Layout.preferredWidth: Math.round(34 * root.scaleFactor)
                    Layout.preferredHeight: Math.round(34 * root.scaleFactor)
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.applyAlpha(timerCard.ink, 0.10)
                    colBackgroundHover: ColorUtils.applyAlpha(timerCard.ink, 0.16)
                    colRipple: ColorUtils.applyAlpha(timerCard.ink, 0.20)
                    releaseAction: () => timerCard.toggleAction()
                    contentItem: MaterialShapeWrappedMaterialSymbol {
                        anchors.centerIn: parent
                        shape: timerCard.shape
                        color: "transparent"
                        colSymbol: timerCard.ink
                        text: timerCard.running && !timerCard.paused ? "pause" : timerCard.icon
                        iconSize: Math.round(17 * root.scaleFactor)
                        fill: 1
                        padding: 0
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledText {
                text: timerCard.value
                color: timerCard.ink
                font.pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                font.weight: Font.Bold
                font.family: Appearance.font.family.numbers
                font.features: ({ "tnum": 1 })
            }

            Item {
                id: footerSlot
                Layout.fillWidth: true
                Layout.preferredHeight: children.length > 0
                    ? Math.round(22 * root.scaleFactor) : 0
            }
        }
    }

    Grid {
        id: timerGrid
        columns: root.vertical ? 1 : 3
        spacing: root.cardSpacing

        TimerCard {
            icon: TimerService.pomodoroBreak ? "coffee" : "target"
            value: root.formatSeconds(TimerService.pomodoroSecondsLeft)
            label: TimerService.pomodoroLongBreak ? Translation.tr("Long break")
                : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
            running: TimerService.pomodoroRunning
            paused: TimerService.pomodoroPaused
            shape: MaterialShape.Shape.Flower
            semanticRole: root.widgetTertiaryRole
            toggleAction: () => TimerService.togglePomodoro()
            resetAction: () => TimerService.resetPomodoro()
        }

        TimerCard {
            icon: "timer"
            value: root.formatSeconds(TimerService.stopwatchTime / 100)
            label: Translation.tr("Stopwatch")
            running: TimerService.stopwatchRunning
            paused: TimerService.stopwatchPaused
            shape: MaterialShape.Shape.Sunny
            semanticRole: root.widgetSecondaryRole
            toggleAction: () => TimerService.toggleStopwatch()
            resetAction: () => TimerService.stopwatchReset()
        }

        TimerCard {
            icon: "hourglass_top"
            value: root.formatSeconds(TimerService.countdownSecondsLeft)
            label: Translation.tr("Countdown")
            running: TimerService.countdownRunning
            paused: TimerService.countdownPaused
            shape: MaterialShape.Shape.Bun
            semanticRole: root.widgetPrimaryRole
            toggleAction: () => TimerService.toggleCountdown()
            resetAction: () => TimerService.resetCountdown()

            RowLayout {
                anchors.fill: parent
                spacing: Math.round(4 * root.scaleFactor)

                Repeater {
                    model: [1, 5]
                    Rectangle {
                        id: minuteButton
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.full
                        color: ColorUtils.applyAlpha(root.primaryInk, 0.10)

                        StyledText {
                            anchors.centerIn: parent
                            text: "+" + modelData + "m"
                            color: root.primaryInk
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                            font.weight: Font.DemiBold
                        }

                        TapHandler {
                            onTapped: root.addCountdownMinutes(minuteButton.modelData)
                        }
                    }
                }
            }
        }
    }

    readonly property color primaryInk: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
}
