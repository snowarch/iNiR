import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3

    implicitWidth: isMaterial && !root.vertical ? flow.implicitWidth : root.vertical ? Appearance.sizes.verticalBarWidth - 14 : flow.implicitWidth + 4
    implicitHeight: isMaterial && root.vertical ? flow.implicitHeight: isMaterial ? 32 : root.vertical ? flow.implicitHeight + 4 : Appearance.sizes.barHeight

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: isMaterial ? 2 : 4

        Loader {
            active: Config.options.bar.m3.utilButtons.showScreenSnip
            visible: active
            sourceComponent: isMaterial ? screenSnipM3 : legacyScreenSnip
        }

        Component {
            id: screenSnipM3
            UtilButton {
                toolTipText: Translation.tr("Take screenshot")
                iconText: "screenshot_region"
                onClicked: GlobalActions.runById("screenshot", "")
            }
        }

        Component {
            id: legacyScreenSnip
            CircleUtilButton {
                onClicked: GlobalActions.runById("screenshot", "")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1; text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showColorPicker
            visible: active
            sourceComponent: isMaterial ? colorPickerM3 : legacyColorPicker
        }
        Component {
            id: colorPickerM3
            UtilButton {
                toolTipText: Translation.tr("Pick a color")
                iconText: "colorize"
                onClicked: GlobalActions.runById("color-picker", "")
            }
        }
        Component {
            id: legacyColorPicker
            CircleUtilButton {
                onClicked: GlobalActions.runById("color-picker", "")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1; text: "colorize"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showScreenRecord
            visible: active
            sourceComponent: isMaterial ? screenRecordM3 : legacyScreenRecord
        }

        Component {
            id: legacyScreenRecord
            Item {
                id: recordingItem
                implicitWidth: btn.implicitWidth + timerRevealer.implicitWidth
                implicitHeight: btn.implicitHeight

                property bool isRecording: RecorderStatus.isRecording
                property int elapsedSeconds: 0

                onIsRecordingChanged: {
                    if (!isRecording) elapsedSeconds = 0
                }

                function formatTime(s) {
                    return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
                }

                Timer {
                    interval: 1000
                    repeat: true
                    running: recordingItem.isRecording
                    onTriggered: recordingItem.elapsedSeconds++
                }

                CircleUtilButton {
                    id: btn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    colBackground: recordingItem.isRecording ? Appearance.colors.colPrimaryContainer : "transparent"
                    buttonRadius: recordingItem.isRecording ? Appearance.rounding.normal : implicitHeight / 2
                    onClicked: GlobalActions.runById("screen-record", "")

                    Behavior on colBackground { ColorAnimation { duration: 200 } }
                    Behavior on buttonRadius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    MaterialSymbol {
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 1
                        text: recordingItem.isRecording ? "stop_circle" : "screen_record"
                        iconSize: Appearance.font.pixelSize.large
                        color: recordingItem.isRecording ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                Revealer {
                    id: timerRevealer
                    anchors.left: btn.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: btn.verticalCenter
                    reveal: recordingItem.isRecording && !root.vertical

                    StyledText {
                        width: implicitWidth
                        text: recordingItem.formatTime(recordingItem.elapsedSeconds)
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.features: { "tnum": 1 }
                        font.letterSpacing: -0.3
                        color: Appearance.colors.colOnLayer2
                        rightPadding: 8
                        Component.onCompleted: width = implicitWidth
                    }
                }
            }
        }

        Component {
            id: screenRecordM3
            UtilButton {
                toolTipText: RecorderStatus.isRecording ? Translation.tr("Stop recording") : Translation.tr("Start recording")
                iconText: RecorderStatus.isRecording ? "stop_circle" : "screen_record"
                forceHovered: RecorderStatus.isRecording
                onClicked: GlobalActions.runById("screen-record", "")
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showKeyboardToggle
            visible: active
            sourceComponent: isMaterial ? keyboardM3 : legacyKeyboard
        }
        Component {
            id: keyboardM3
            UtilButton {
                toolTipText: Translation.tr("On-screen keyboard")
                iconText: "keyboard"
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
            }
        }
        Component {
            id: legacyKeyboard
            CircleUtilButton {
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0; text: "keyboard"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showWallpaperToggle
            visible: active
            sourceComponent: isMaterial ? wallpaperM3 : legacyWallpaper
        }
        Component {
            id: wallpaperM3
            UtilButton {
                toolTipText: Translation.tr("Choose wallpaper")
                iconText: "imagesmode"
                onClicked: GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
            }
        }
        Component {
            id: legacyWallpaper
            CircleUtilButton {
                onClicked: GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0; text: "imagesmode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showMicToggle
            visible: active
            sourceComponent: isMaterial ? micM3 : legacyMic
        }
        Component {
            id: micM3
            UtilButton {
                toolTipText: Pipewire.defaultAudioSource?.audio?.muted ? Translation.tr("Unmute microphone") : Translation.tr("Mute microphone")
                iconText: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                onClicked: GlobalActions.runById("toggle-mic-mute", "")
            }
        }
        Component {
            id: legacyMic
            CircleUtilButton {
                onClicked: GlobalActions.runById("toggle-mic-mute", "")
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showDarkModeToggle
            visible: active
            sourceComponent: isMaterial ? darkModeM3 : legacyDarkMode
        }
        Component {
            id: darkModeM3
            UtilButton {
                toolTipText: Appearance.m3colors.darkmode ? Translation.tr("Use light mode") : Translation.tr("Use dark mode")
                iconText: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                onClicked: MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode)
            }
        }
        Component {
            id: legacyDarkMode
            CircleUtilButton {
                onClicked: MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode)
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options.bar.m3.utilButtons.showPerformanceProfileToggle
            visible: active
            sourceComponent: isMaterial ? perfM3 : legacyPerf
        }
        Component {
            id: perfM3
            UtilButton {
                toolTipText: Translation.tr("Change performance profile")
                iconText: switch(PowerProfiles.profile) {
                    case PowerProfile.PowerSaver: return "energy_savings_leaf"
                    case PowerProfile.Balanced: return "airwave"
                    case PowerProfile.Performance: return "local_fire_department"
                }
                onClicked: (e) => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
            }
        }
        Component {
            id: legacyPerf
            CircleUtilButton {
                onClicked: (e) => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "airwave"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
