pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.inir.overlay
import qs.services

StyledOverlayWidget {
    id: root
    minimumWidth: 310
    minimumHeight: 160

    // Get the effective save path (config or default XDG Videos)
    readonly property string effectiveSavePath: {
        const configPath = Config.options?.screenRecord?.savePath ?? "";
        if (configPath && configPath.length > 0) return configPath;
        // Default to XDG Videos directory
        const videosDir = FileUtils.trimFileProtocol(Directories.videos);
        return videosDir || `${FileUtils.trimFileProtocol(Directories.home)}/Videos`;
    }

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8
        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 10

            // Recording status indicator
            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 8
                visible: RecorderStatus.isRecording

                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: Appearance.colors.colError
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: RecorderStatus.isRecording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 500 }
                        NumberAnimation { to: 1.0; duration: 500 }
                    }
                }

                StyledText {
                    text: Translation.tr("Recording in progress...")
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.small
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 10

                BigRecorderButton {
                    materialSymbol: "screenshot_region"
                    name: Translation.tr("Screenshot region")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "region", "screenshot"]);
                    }
                }

                BigRecorderButton {
                    materialSymbol: "photo_camera"
                    name: Translation.tr("Screenshot")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["/usr/bin/bash", "-c", "/usr/bin/grim - | /usr/bin/wl-copy"]);
                    }
                }

                BigRecorderButton {
                    materialSymbol: RecorderStatus.isRecording ? "stop_circle" : "screen_record"
                    name: RecorderStatus.isRecording ? Translation.tr("Stop recording") : Translation.tr("Record region")
                    isRecording: RecorderStatus.isRecording && !isFullscreenRecording
                    onClicked: {
                        if (RecorderStatus.isRecording) {
                            // Stop recording
                            Quickshell.execDetached([Directories.recordScriptPath]);
                        } else {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached(["/usr/bin/qs", "-c", "inir", "ipc", "call", "region", "recordWithSound"]);
                        }
                    }
                    property bool isFullscreenRecording: false
                }
                
                BigRecorderButton {
                    id: fullscreenRecordButton
                    materialSymbol: RecorderStatus.isRecording ? "stop_circle" : "capture"
                    name: RecorderStatus.isRecording ? Translation.tr("Stop recording") : Translation.tr("Record screen")
                    isRecording: RecorderStatus.isRecording
                    onClicked: {
                        if (RecorderStatus.isRecording) {
                            // Stop recording
                            Quickshell.execDetached([Directories.recordScriptPath]);
                        } else {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]);
                        }
                    }
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 8

                RippleButton {
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Qt.openUrlExternally(`file://${root.effectiveSavePath}`);
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "folder_open"
                            iconSize: 20
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Open folder")
                        }
                    }
                }

                RippleButton {
                    buttonRadius: height / 2
                    colBackground: Appearance.colors.colLayer3
                    colBackgroundHover: Appearance.colors.colLayer3Hover
                    colRipple: Appearance.colors.colLayer3Active
                    onClicked: {
                        folderDialog.open();
                    }
                    contentItem: Row {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "drive_file_move"
                            iconSize: 20
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Change folder")
                        }
                    }
                }
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: Translation.tr("Select recordings folder")
        currentFolder: `file://${root.effectiveSavePath}`
        onAccepted: {
            const path = FileUtils.trimFileProtocol(selectedFolder.toString());
            Config.setNestedValue("screenRecord.savePath", path);
        }
    }

    component BigRecorderButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        property bool isRecording: false
        implicitHeight: 66
        implicitWidth: 66
        buttonRadius: height / 2

        colBackground: isRecording ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3
        colBackgroundHover: isRecording ? Appearance.colors.colError : Appearance.colors.colLayer3Hover
        colRipple: isRecording ? Appearance.colors.colErrorActive : Appearance.colors.colLayer3Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 28
            color: bigButton.isRecording ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer3
        }

        StyledToolTip {
            text: bigButton.name
        }
    }
}
