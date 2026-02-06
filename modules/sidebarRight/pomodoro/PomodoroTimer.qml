import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    // Style helpers
    readonly property color _colLayer: Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colLayer2
    readonly property color _colLayerHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colLayer2Hover
    readonly property color _colLayerActive: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
    readonly property color _colText: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer2

    property bool settingsOpen: false

    StyledFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true

        ColumnLayout {
            id: contentColumn
            width: flickable.width
            spacing: 0

            // The Pomodoro timer circle
            CircularProgress {
                Layout.alignment: Qt.AlignHCenter
                lineWidth: 8
                value: {
                    return TimerService.pomodoroSecondsLeft / TimerService.pomodoroLapDuration;
                }
                implicitSize: 200
                enableAnimation: true

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            let minutes = Math.floor(TimerService.pomodoroSecondsLeft / 60).toString().padStart(2, '0');
                            let seconds = Math.floor(TimerService.pomodoroSecondsLeft % 60).toString().padStart(2, '0');
                            return `${minutes}:${seconds}`;
                        }
                        font.pixelSize: Math.round(40 * Appearance.fontSizeScale)
                        color: Appearance.m3colors.m3onSurface
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: TimerService.pomodoroLongBreak ? Translation.tr("Long break") : TimerService.pomodoroBreak ? Translation.tr("Break") : Translation.tr("Focus")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                }

                Rectangle {
                    radius: Appearance.rounding.full
                    color: root._colLayer

                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                    }
                    implicitWidth: 36
                    implicitHeight: implicitWidth

                    StyledText {
                        id: cycleText
                        anchors.centerIn: parent
                        color: root._colText
                        text: TimerService.pomodoroCycle + 1
                    }
                }
            }

            // Start/Pause + Reset buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                RippleButton {
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: TimerService.pomodoroRunning ? Translation.tr("Pause") : (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume")
                        color: TimerService.pomodoroRunning
                            ? (Appearance.inirEverywhere ? Appearance.inir.colText
                                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnSecondaryContainer)
                            : Appearance.colors.colOnPrimary
                    }
                    implicitHeight: 35
                    implicitWidth: 90
                    font.pixelSize: Appearance.font.pixelSize.larger
                    onClicked: TimerService.togglePomodoro()
                    colBackground: TimerService.pomodoroRunning
                        ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer)
                        : Appearance.colors.colPrimary
                    colBackgroundHover: TimerService.pomodoroRunning
                        ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover)
                        : Appearance.colors.colPrimaryHover
                    colRipple: TimerService.pomodoroRunning
                        ? (Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive)
                        : Appearance.colors.colPrimaryActive
                }

                RippleButton {
                    implicitHeight: 35
                    implicitWidth: 90

                    onClicked: TimerService.resetPomodoro()
                    enabled: (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration) || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak

                    font.pixelSize: Appearance.font.pixelSize.larger
                    colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                        : Appearance.colors.colErrorContainer
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
                        : Appearance.colors.colErrorContainerHover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                        : Appearance.colors.colErrorContainerActive

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Reset")
                        color: Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2
                            : Appearance.colors.colOnErrorContainer
                    }
                }
            }

            // Settings toggle — only when timer is stopped
            RippleButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                visible: !TimerService.pomodoroRunning
                implicitWidth: 36
                implicitHeight: 36
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: root._colLayerHover
                colRipple: root._colLayerActive
                onClicked: root.settingsOpen = !root.settingsOpen

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.settingsOpen ? "keyboard_arrow_up" : "settings"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }

                StyledToolTip {
                    text: Translation.tr("Customize timer")
                }
            }

            // ── Collapsible settings section ──
            ColumnLayout {
                id: settingsPanel
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 6
                visible: root.settingsOpen && !TimerService.pomodoroRunning

                // Brief explanation of the Pomodoro technique
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Focus → Break → Focus → Break → ... → Long break")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.bottomMargin: 4
                }

                // Inline component: a single adjustable value row
                component AdjustRow: RowLayout {
                    id: adjustRow
                    property string icon
                    property string label
                    property string valueText
                    property int currentValue
                    property int minValue
                    property int maxValue
                    property int step
                    property string configPath

                    Layout.fillWidth: true
                    spacing: 0

                    MaterialSymbol {
                        text: adjustRow.icon
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                        Layout.rightMargin: 6
                    }

                    StyledText {
                        text: adjustRow.label
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        Layout.fillWidth: true
                    }

                    RippleButton {
                        implicitWidth: 30; implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: root._colLayerHover
                        colRipple: root._colLayerActive
                        enabled: adjustRow.currentValue > adjustRow.minValue
                        onClicked: Config.setNestedValue(adjustRow.configPath, adjustRow.currentValue - adjustRow.step)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "remove"
                            iconSize: 18
                            color: enabled ? root._colText : Appearance.colors.colSubtext
                        }
                    }

                    Rectangle {
                        implicitWidth: 52
                        implicitHeight: 26
                        radius: Appearance.rounding.small
                        color: root._colLayer

                        StyledText {
                            anchors.centerIn: parent
                            text: adjustRow.valueText
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: root._colText
                        }
                    }

                    RippleButton {
                        implicitWidth: 30; implicitHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: root._colLayerHover
                        colRipple: root._colLayerActive
                        enabled: adjustRow.currentValue < adjustRow.maxValue
                        onClicked: Config.setNestedValue(adjustRow.configPath, adjustRow.currentValue + adjustRow.step)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            iconSize: 18
                            color: enabled ? root._colText : Appearance.colors.colSubtext
                        }
                    }
                }

                AdjustRow {
                    icon: "target"
                    label: Translation.tr("Focus")
                    valueText: Translation.tr("%1 min").arg(TimerService.focusTime / 60)
                    currentValue: TimerService.focusTime; minValue: 300; maxValue: 7200; step: 300
                    configPath: "time.pomodoro.focus"
                }

                AdjustRow {
                    icon: "coffee"
                    label: Translation.tr("Break")
                    valueText: Translation.tr("%1 min").arg(TimerService.breakTime / 60)
                    currentValue: TimerService.breakTime; minValue: 60; maxValue: 1800; step: 60
                    configPath: "time.pomodoro.breakTime"
                }

                AdjustRow {
                    icon: "weekend"
                    label: Translation.tr("Long break")
                    valueText: Translation.tr("%1 min").arg(TimerService.longBreakTime / 60)
                    currentValue: TimerService.longBreakTime; minValue: 300; maxValue: 3600; step: 300
                    configPath: "time.pomodoro.longBreak"
                }

                AdjustRow {
                    icon: "replay"
                    label: Translation.tr("Cycles")
                    valueText: TimerService.cyclesBeforeLongBreak.toString()
                    currentValue: TimerService.cyclesBeforeLongBreak; minValue: 2; maxValue: 8; step: 1
                    configPath: "time.pomodoro.cyclesBeforeLongBreak"
                }

                // Sound toggle
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    MaterialSymbol {
                        text: (Config.options?.sounds?.pomodoro ?? false) ? "volume_up" : "volume_off"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                        Layout.rightMargin: 6
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Sound")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    Switch {
                        checked: Config.options?.sounds?.pomodoro ?? false
                        onCheckedChanged: Config.setNestedValue("sounds.pomodoro", checked)
                    }
                }
            }
        }
    }
}
