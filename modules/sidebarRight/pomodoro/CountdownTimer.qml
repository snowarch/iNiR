import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    property bool editMode: !TimerService.countdownRunning && TimerService.countdownSecondsLeft === TimerService.countdownDuration

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 200
            implicitHeight: 200

            CircularProgress {
                anchors.fill: parent
                lineWidth: 8
                value: TimerService.countdownDuration > 0 ? TimerService.countdownSecondsLeft / TimerService.countdownDuration : 0
                implicitSize: 200
                enableAnimation: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (!root.editMode) return;
                    const delta = wheel.angleDelta.y > 0 ? 60 : -60;
                    const newDuration = Math.max(60, Math.min(5940, TimerService.countdownDuration + delta));
                    TimerService.setCountdownDuration(newDuration);
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                // Editable time display with separate minutes and seconds
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0
                    visible: root.editMode

                    // Minutes input
                    Rectangle {
                        id: minutesBox
                        width: 54
                        height: 54
                        color: minutesInput.activeFocus 
                            ? Appearance.colors.colPrimaryContainer 
                            : "transparent"
                        radius: Appearance.rounding.small
                        border.width: minutesInput.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        TextInput {
                            id: minutesInput
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: Math.floor(TimerService.countdownDuration / 60).toString().padStart(2, '0')
                            font.pixelSize: Math.round(38 * Appearance.fontSizeScale)
                            font.family: Appearance.font.family.main
                            color: Appearance.m3colors.m3onSurface
                            horizontalAlignment: Text.AlignHCenter
                            validator: IntValidator { bottom: 0; top: 99 }
                            selectByMouse: true
                            onEditingFinished: {
                                const mins = parseInt(text) || 0;
                                const secs = parseInt(secondsInput.text) || 0;
                                TimerService.setCountdownDuration(mins * 60 + secs);
                            }
                            onActiveFocusChanged: {
                                if (activeFocus) selectAll();
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                const delta = wheel.angleDelta.y > 0 ? 1 : -1;
                                const currentMins = parseInt(minutesInput.text) || 0;
                                const newMins = Math.max(0, Math.min(99, currentMins + delta));
                                const secs = parseInt(secondsInput.text) || 0;
                                TimerService.setCountdownDuration(newMins * 60 + secs);
                            }
                        }
                    }

                    StyledText {
                        text: ":"
                        font.pixelSize: Math.round(38 * Appearance.fontSizeScale)
                        color: Appearance.m3colors.m3onSurface
                    }

                    // Seconds input
                    Rectangle {
                        id: secondsBox
                        width: 54
                        height: 54
                        color: secondsInput.activeFocus 
                            ? Appearance.colors.colPrimaryContainer 
                            : "transparent"
                        radius: Appearance.rounding.small
                        border.width: secondsInput.activeFocus ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        TextInput {
                            id: secondsInput
                            anchors.centerIn: parent
                            width: parent.width - 8
                            text: Math.floor(TimerService.countdownDuration % 60).toString().padStart(2, '0')
                            font.pixelSize: Math.round(38 * Appearance.fontSizeScale)
                            font.family: Appearance.font.family.main
                            color: Appearance.m3colors.m3onSurface
                            horizontalAlignment: Text.AlignHCenter
                            validator: IntValidator { bottom: 0; top: 59 }
                            selectByMouse: true
                            onEditingFinished: {
                                const mins = parseInt(minutesInput.text) || 0;
                                const secs = Math.min(59, parseInt(text) || 0);
                                TimerService.setCountdownDuration(mins * 60 + secs);
                            }
                            onActiveFocusChanged: {
                                if (activeFocus) selectAll();
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: (wheel) => {
                                const delta = wheel.angleDelta.y > 0 ? 1 : -1;
                                const mins = parseInt(minutesInput.text) || 0;
                                const currentSecs = parseInt(secondsInput.text) || 0;
                                const newSecs = Math.max(0, Math.min(59, currentSecs + delta));
                                TimerService.setCountdownDuration(mins * 60 + newSecs);
                            }
                        }
                    }
                }

                // Static time display when running/paused
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.editMode
                    text: {
                        const totalSeconds = TimerService.countdownSecondsLeft;
                        const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
                        const seconds = Math.floor(totalSeconds % 60).toString().padStart(2, '0');
                        return `${minutes}:${seconds}`;
                    }
                    font.pixelSize: Math.round(40 * Appearance.fontSizeScale)
                    color: Appearance.m3colors.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.editMode ? Translation.tr("Tap to edit") : TimerService.countdownRunning ? Translation.tr("Running") : Translation.tr("Paused")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 6
            visible: root.editMode

            Repeater {
                model: [
                    { label: "1m", seconds: 60 },
                    { label: "5m", seconds: 300 },
                    { label: "10m", seconds: 600 },
                    { label: "15m", seconds: 900 },
                    { label: "30m", seconds: 1800 }
                ]

                RippleButton {
                    required property var modelData
                    implicitHeight: 30
                    implicitWidth: 45
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                    onClicked: TimerService.setCountdownDuration(modelData.seconds)

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: root.editMode ? 10 : 0
            spacing: 10

            RippleButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 90
                onClicked: TimerService.toggleCountdown()
                enabled: TimerService.countdownDuration > 0
                colBackground: TimerService.countdownRunning 
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer)
                    : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.countdownRunning 
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover)
                    : Appearance.colors.colPrimaryHover
                colRipple: TimerService.countdownRunning 
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive)
                    : Appearance.colors.colPrimaryActive

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    color: TimerService.countdownRunning 
                        ? (Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnSecondaryContainer)
                        : Appearance.colors.colOnPrimary
                    text: TimerService.countdownRunning ? Translation.tr("Pause") : TimerService.countdownSecondsLeft === TimerService.countdownDuration ? Translation.tr("Start") : Translation.tr("Resume")
                }
            }

            RippleButton {
                Layout.preferredHeight: 35
                Layout.preferredWidth: 90
                onClicked: TimerService.resetCountdown()
                enabled: TimerService.countdownSecondsLeft < TimerService.countdownDuration || TimerService.countdownRunning
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                    : Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
                    : Appearance.colors.colErrorContainerHover
                colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                    : Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Reset")
                    color: Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2
                        : Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}
