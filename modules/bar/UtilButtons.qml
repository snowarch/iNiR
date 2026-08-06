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
    readonly property color neutralIconColor: Appearance.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2
    readonly property color dangerIconColor: Appearance.zzzEverywhere ? Appearance.zzz.signal
        : Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
    // Exact content width — self-inflating (+spacing*2) made every group that
    // ends with these buttons read asymmetric: the group's own padding is the
    // spacing authority, modules must not add their own.
    implicitWidth: rowLayout.implicitWidth
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
                onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "screenshot"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.neutralIconColor
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

                property bool isRecording: RecorderStatus.isRecording

                CircleUtilButton {
                    id: screenRecordButton
                    anchors.fill: parent

                    onClicked: {
                        const args = [Directories.recordScriptPath]
                        if (recordButtonWrapper.isRecording)
                            args.push("--stop")
                        else
                            args.push("--fullscreen", "--sound")
                        Quickshell.execDetached(args)
                        RecorderStatus.scheduleQuickCheck()
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
                                ? root.dangerIconColor
                                : root.neutralIconColor
                        }

                        // Pulsating indicator dot when recording
                        Rectangle {
                            scale: recordButtonWrapper.isRecording ? 1 : 0
                            visible: scale > 0
                            width: 6
                            height: 6
                            radius: 3
                            color: root.dangerIconColor
                            anchors {
                                top: parent.top
                                right: parent.right
                            }

                            Behavior on scale {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Appearance.animation.elementMoveFast.type
                                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                }
                            }

                            SequentialAnimation on opacity {
                                running: recordButtonWrapper.isRecording
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: Appearance.animation.elementMove.duration * 2 }
                                NumberAnimation { to: 1.0; duration: Appearance.animation.elementMove.duration * 2 }
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
                    color: root.neutralIconColor
                }
            }
        }

        Loader {
            active: Config.options?.bar?.utilButtons?.showNotepad ?? true
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    GlobalStates.sidebarRightRequestedWidget = "notepad"
                    GlobalStates.openSidebarRight(root.QsWindow.window?.screen?.name ?? "")
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "edit_note"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.neutralIconColor
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
                    color: root.neutralIconColor
                }
            }
        }

        // Keyboard layout switch (Niri only)
        Loader {
            active: (Config.options?.bar?.utilButtons?.showKeyboardLayoutSwitch ?? false)
                    && CompositorService.isNiri
                    && NiriService.hasMultipleKeyboardLayouts
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: NiriService.switchLayout()
                Item {
                    anchors.fill: parent
                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: 0
                        text: "language"
                        iconSize: Appearance.font.pixelSize.large
                        color: root.neutralIconColor
                    }
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

                readonly property bool isMuted: Audio.micMuted
                readonly property bool isInUse: (Privacy.micActive || (Audio?.micBeingAccessed ?? false))

                onClicked: Audio.toggleMicMute()

                Item {
                    anchors.fill: parent

                    MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Qt.AlignHCenter
                        fill: micButton.isInUse ? 1 : 0
                        animateFill: true
                        text: micButton.isMuted ? "mic_off" : "mic"
                        iconSize: Appearance.font.pixelSize.large
                        color: micButton.isInUse && !micButton.isMuted
                            ? root.dangerIconColor
                            : (Appearance.angelEverywhere ? Appearance.angel.colText
                             : Appearance.inirEverywhere ? Appearance.inir.colOnLayer2
                             : Appearance.zzzEverywhere ? Appearance.zzz.accent
                             : Appearance.auroraEverywhere ? Appearance.colors.colOnSurface
                             : Appearance.colors.colOnLayer2)
                    }

                    Rectangle {
                        scale: micButton.isInUse && !micButton.isMuted ? 1 : 0
                        visible: scale > 0
                        width: 6
                        height: 6
                        radius: 3
                        color: root.dangerIconColor
                        anchors { top: parent.top; right: parent.right }

                        Behavior on scale {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        SequentialAnimation on opacity {
                            running: micButton.isInUse && !micButton.isMuted
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: Appearance.animation.elementMove.duration * 2 }
                            NumberAnimation { to: 1.0; duration: Appearance.animation.elementMove.duration * 2 }
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
                        animateFill: true
                        text: "visibility"
                        iconSize: Appearance.font.pixelSize.large
                        color: screenCastButton.isCasting
                            ? root.dangerIconColor
                            : root.neutralIconColor
                    }

                    Rectangle {
                        scale: screenCastButton.isCasting ? 1 : 0
                        visible: scale > 0
                        width: 6
                        height: 6
                        radius: 3
                        color: root.dangerIconColor
                        anchors {
                            top: parent.top
                            right: parent.right
                        }

                        Behavior on scale {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        SequentialAnimation on opacity {
                            running: screenCastButton.isCasting
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: Appearance.animation.elementMove.duration * 2 }
                            NumberAnimation { to: 1.0; duration: Appearance.animation.elementMove.duration * 2 }
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
                    MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode)
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.neutralIconColor
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
                    color: root.neutralIconColor
                }
            }
        }
    }
}
