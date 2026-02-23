import qs
import qs.services
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
    property bool borderless: Config.options?.bar?.borderless ?? false
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options?.bar?.utilButtons?.showScreenSnip ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "region", "screenshot"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showScreenRecord ?? false
            visible: active
            sourceComponent: Item {
                id: recordButtonWrapper
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: screenRecordButton.implicitWidth
                implicitHeight: screenRecordButton.implicitHeight

                // Check if wf-recorder is actually running
                property bool isRecording: false

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        // Check if wf-recorder process exists using pgrep
                        checkProcess.running = true
                    }
                }

                Process {
                    id: checkProcess
                    command: ["pgrep", "-x", "wf-recorder"]
                    running: false

                    onExited: (exitCode, exitStatus) => {
                        recordButtonWrapper.isRecording = (exitCode === 0)
                    }
                }

                CircleUtilButton {
                    id: screenRecordButton
                    anchors.fill: parent

                    onClicked: {
                        // Let the script handle everything (notifications, state, etc)
                        Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"])
                    }

                    Item {
                        anchors.fill: parent

                        MaterialSymbol {
                            anchors.centerIn: parent
                            horizontalAlignment: Qt.AlignHCenter
                            fill: 1
                            text: "videocam"
                            iconSize: Appearance.font.pixelSize.large
                            color: recordButtonWrapper.isRecording
                                ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                                : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                        }

                        // Pulsating indicator dot when recording
                        Rectangle {
                            visible: recordButtonWrapper.isRecording
                            width: 6
                            height: 6
                            radius: 3
                            color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                            anchors {
                                top: parent.top
                                right: parent.right
                            }

                            SequentialAnimation on opacity {
                                running: recordButtonWrapper.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 800 }
                                NumberAnimation { to: 1.0; duration: 800 }
                            }
                        }
                    }
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showColorPicker ?? false
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "colorize"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showNotepad ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    GlobalStates.sidebarRightOpen = true
                    // Ensure bottom widget group is expanded and focused on Notepad tab (index 2)
                    Persistent.states.sidebar.bottomGroup.collapsed = false
                    Persistent.states.sidebar.bottomGroup.tab = 2
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "edit_note"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showKeyboardToggle ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "keyboard"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            readonly property bool micInUse: Privacy.micActive || (Audio?.micBeingAccessed ?? false)
            active: (Config.options?.bar?.utilButtons?.showMicToggle ?? false) || micInUse
            visible: active
            sourceComponent: CircleUtilButton {
                id: micButton
                Layout.alignment: Qt.AlignVCenter

                readonly property bool isMuted: Pipewire.defaultAudioSource?.audio?.muted ?? false
                readonly property bool isInUse: (Privacy.micActive || (Audio?.micBeingAccessed ?? false))

                onClicked: Quickshell.execDetached(["/usr/bin/wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: micButton.isInUse ? 1 : 0
                        text: micButton.isMuted ? "mic_off" : "mic"
                        iconSize: Appearance.font.pixelSize.large
                        color: micButton.isInUse && !micButton.isMuted
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.angelEverywhere ? Appearance.angel.colText
                             : Appearance.inirEverywhere ? Appearance.inir.colOnLayer2
                             : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface
                             : Appearance.colors.colOnLayer2)
                    }

                    Rectangle {
                        visible: micButton.isInUse && !micButton.isMuted
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                        anchors { top: parent.top; right: parent.right }

                        SequentialAnimation on opacity {
                            running: micButton.isInUse && !micButton.isMuted
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }
            }
        }

        // Screen casting toggle (PR #29 by levpr1c)
        // Toggles Niri dynamic casting to configured output
        Loader {
            active: (Config.options?.bar?.utilButtons?.showScreenCast ?? false)
                    && CompositorService.isNiri
            visible: active
            sourceComponent: CircleUtilButton {
                id: screenCastButton
                Layout.alignment: Qt.AlignVCenter

                readonly property bool isCasting: Persistent.states.screenCast.active

                onClicked: {
                    const output = Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1"

                    if (isCasting) {
                        Quickshell.execDetached(["niri", "msg", "action", "clear-dynamic-cast-target"])
                        Persistent.states.screenCast.active = false
                    } else {
                        Quickshell.execDetached(["niri", "msg", "action", "set-dynamic-cast-monitor", output])
                        Persistent.states.screenCast.active = true
                    }
                }

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: screenCastButton.isCasting ? 1 : 0
                        text: "visibility"
                        iconSize: Appearance.font.pixelSize.large
                        color: screenCastButton.isCasting
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                    }

                    Rectangle {
                        visible: screenCastButton.isCasting
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

                        SequentialAnimation on opacity {
                            running: screenCastButton.isCasting
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
                        }
                    }
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showDarkModeToggle ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"]);
                    } else {
                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"]);
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showPerformanceProfileToggle ?? false
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
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
                        case PowerProfile.Balanced: return "settings_slow_motion"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
                }
            }
        }
    }
}
