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

    // Screen share: any video node linked
    readonly property bool screenShareActive: (Pipewire.links?.values ?? []).some(link => {
        const src = link?.source?.name ?? "";
        const tgt = link?.target?.name ?? "";
        return src === "niri" || tgt === "niri";
    })
    
    // Count connected outputs for screen cast feature
    property int connectedOutputs: 1
    
    Process {
        id: outputCountProcess
        command: ["niri", "msg", "outputs"]
        running: CompositorService.isNiri
        
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split('\n');
                root.connectedOutputs = lines.filter(line => line.trim().startsWith('Output "')).length;
            }
        }
    }

    RowLayout {
        id: rowLayout

        spacing: 4
        anchors.centerIn: parent

        Loader {
            active: Config.options?.bar?.utilButtons?.showScreenSnip ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "region", "screenshot"])
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
            sourceComponent: CircleUtilButton {
                id: screenRecordButton
                Layout.alignment: Qt.AlignVCenter

                // Track recording state
                property bool isRecording: Persistent.states.screenRecord?.active ?? false

                onClicked: {
                    if (isRecording) {
                        // Stop recording - send SIGINT to wf-recorder
                        Quickshell.execDetached(["pkill", "-SIGINT", "wf-recorder"])
                        Quickshell.execDetached(["notify-send", "-i", "media-record", "Screen Recording", "Recording stopped"])
                        Persistent.states.screenRecord.active = false
                    } else {
                        // Start recording
                        Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"])
                        Quickshell.execDetached(["notify-send", "-i", "media-record", "Screen Recording", "Recording started"])
                        Persistent.states.screenRecord.active = true
                    }
                }

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: screenRecordButton.isRecording ? 1 : 1
                        text: "videocam"
                        iconSize: Appearance.font.pixelSize.large
                        color: screenRecordButton.isRecording
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                    }

                    // Pulsating indicator dot when recording
                    Rectangle {
                        visible: screenRecordButton.isRecording
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

                        SequentialAnimation on opacity {
                            running: screenRecordButton.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 800 }
                            NumberAnimation { to: 1.0; duration: 800 }
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
                            : (Appearance.inirEverywhere ? Appearance.inir.colOnLayer2
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

        // Screen casting control/indicator (PR #29 by levpr1c, enhanced)
        // With 2+ monitors: Interactive button for dynamic cast (mirroring)
        // With 1 monitor: Passive indicator showing active screencasts
        Loader {
            active: (Config.options?.bar?.utilButtons?.showScreenCast ?? false) 
                    && CompositorService.isNiri
            visible: active
            sourceComponent: CircleUtilButton {
                id: screenCastButton
                Layout.alignment: Qt.AlignVCenter
                
                // Behavior depends on monitor count
                readonly property bool isMultiMonitor: root.connectedOutputs >= 2
                
                // Multi-monitor: use persistent state for dynamic cast control
                // Single monitor: use screenShareActive for passive indication
                readonly property bool isCasting: isMultiMonitor 
                    ? Persistent.states.screenCast.active
                    : root.screenShareActive
                
                // Only clickable with multiple monitors
                enabled: isMultiMonitor
                opacity: isMultiMonitor ? 1.0 : (isCasting ? 1.0 : 0.6)
                
                onClicked: {
                    if (!isMultiMonitor) return // Safety check
                    
                    if (isCasting) {
                        // Stop casting to the monitor
                        Quickshell.execDetached(["niri", "msg", "action", "clear-dynamic-cast-target"])
                        
                        // Send notification with "video off" icon
                        Quickshell.execDetached(["notify-send", "-i", "camera-video-off", "Screen Casting", "Casting stopped"])
                        
                        Persistent.states.screenCast.active = false
                    } else {
                        // Use configured output (default HDMI-A-1)
                        const output = Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1"
                        
                        Quickshell.execDetached(["niri", "msg", "action", "set-dynamic-cast-monitor", output])
                        
                        // Send notification with "display" icon
                        Quickshell.execDetached(["notify-send", "-i", "video-display", "Screen Casting", `Casting started on ${output}`])
                        
                        Persistent.states.screenCast.active = true
                    }
                }
                
                Item {
                    anchors.fill: parent
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        // Fill the icon when casting is active (matches mic button behavior)
                        fill: screenCastButton.isCasting ? 1 : 0
                        text: "visibility"
                        iconSize: Appearance.font.pixelSize.large
                        
                        // Switch to error color when active
                        color: screenCastButton.isCasting
                            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
                            : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                    }
                    
                    // Pulsating indicator dot
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
                        
                        // Infinite blinking animation
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
