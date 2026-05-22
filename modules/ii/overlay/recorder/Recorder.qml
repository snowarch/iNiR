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
import qs.modules.ii.overlay
import qs.services

StyledOverlayWidget {
    id: root
    minimumWidth: 310
    minimumHeight: 160

    // Dynamic title: "Recorder" normally, "Recorder — 15:23" when recording
    title: RecorderStatus.isRecording
        ? Translation.tr("Recorder") + " — " + root.formatElapsed(RecorderStatus.elapsedSeconds)
        : Translation.tr("Recorder")

    // Get the effective save path (config or default XDG Videos)
    readonly property string effectiveSavePath: {
        const configPath = Config.options?.screenRecord?.savePath ?? "";
        if (configPath && configPath.length > 0) return configPath;
        const videosDir = FileUtils.trimFileProtocol(Directories.videos);
        return videosDir || `${FileUtils.trimFileProtocol(Directories.home)}/Videos`;
    }

    function formatElapsed(totalSec: int): string {
        const hours = Math.floor(totalSec / 3600);
        const minutes = Math.floor((totalSec % 3600) / 60);
        const seconds = totalSec % 60;
        const pad = (n) => n < 10 ? "0" + n : "" + n;
        if (hours > 0) return pad(hours) + ":" + pad(minutes) + ":" + pad(seconds);
        return pad(minutes) + ":" + pad(seconds);
    }

    function getDiskFreeText(): string {
        return _diskFreeText;
    }

    property string _diskFreeText: "..."
    property bool _diskInfoPending: false

    function refreshDiskInfo(): void {
        if (_diskInfoPending) return;
        _diskInfoPending = true;
        diskQueryProcess.running = true;
    }

    Process {
        id: diskQueryProcess
        command: ["/usr/bin/bash", "-c",
            "df -BG --output=avail \"" + root.effectiveSavePath + "\" 2>/dev/null | tail -1 | tr -d ' \\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._diskFreeText = text.trim();
                root._diskInfoPending = false;
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root._diskFreeText = "?";
                root._diskInfoPending = false;
            }
        }
    }

    contentItem: OverlayBackground {
        id: contentItem
        radius: root.contentRadius
        property real padding: 8

        ColumnLayout {
            id: contentColumn
            anchors.centerIn: parent
            spacing: 8

            // ── Recording indicator + timer (only when recording) ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                visible: RecorderStatus.isRecording
                height: 28
                radius: height / 2
                color: Appearance.colors.colErrorContainer

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: Appearance.colors.colError
                        SequentialAnimation on opacity {
                            running: RecorderStatus.isRecording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                        }
                    }

                    StyledText {
                        text: root.formatElapsed(RecorderStatus.elapsedSeconds)
                        color: Appearance.colors.colOnErrorContainer
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                    }

                    StyledText {
                        text: Translation.tr("Recording")
                        color: Appearance.colors.colOnErrorContainer
                        font.pixelSize: Appearance.font.pixelSize.small
                        opacity: 0.7
                    }
                }
            }

            // ── Action buttons row ──
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 8

                BigRecorderButton {
                    materialSymbol: "screenshot_region"
                    name: Translation.tr("Screenshot region")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "screenshot"]);
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
                    id: recordButton
                    materialSymbol: RecorderStatus.isRecording ? "stop_circle" : "screen_record"
                    name: RecorderStatus.isRecording
                        ? Translation.tr("Stop recording") : Translation.tr("Record region")
                    isRecording: RecorderStatus.isRecording
                    visible: !RecorderStatus.isRecording
                    onClicked: {
                        if (!RecorderStatus.isRecording) {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "recordWithSound"]);
                        }
                    }
                }

                BigRecorderButton {
                    id: fullscreenRecordButton
                    materialSymbol: RecorderStatus.isRecording ? "stop_circle" : "capture"
                    name: RecorderStatus.isRecording
                        ? Translation.tr("Stop recording") : Translation.tr("Record screen")
                    isRecording: RecorderStatus.isRecording
                    visible: !RecorderStatus.isRecording
                    onClicked: {
                        if (!RecorderStatus.isRecording) {
                            GlobalStates.overlayOpen = false;
                            Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]);
                        }
                    }
                }

                // Dedicated STOP button — only visible when recording
                BigRecorderButton {
                    materialSymbol: "stop_circle"
                    name: Translation.tr("Stop recording")
                    isRecording: true
                    visible: RecorderStatus.isRecording
                    onClicked: {
                        Quickshell.execDetached([Directories.recordScriptPath]);
                    }
                }
            }

            // ── Status bar ──
            RecorderStatusBar {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            // ── Separator before game mode section ──
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                height: 1
                color: Appearance.colors.colOutlineVariant
                opacity: 0.3
            }

            // ── Game Mode overrides (collapsible) ──
            RecorderGameModeSection {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            // ── Folder actions ──
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 8

                ActionButton {
                    materialSymbol: "folder_open"
                    labelText: Translation.tr("Open folder")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Qt.openUrlExternally(`file://${root.effectiveSavePath}`);
                    }
                }

                ActionButton {
                    materialSymbol: "drive_file_move"
                    labelText: Translation.tr("Change folder")
                    onClicked: folderDialog.open()
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

    // ── Sub-components ──

    component BigRecorderButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        property bool isRecording: false
        implicitHeight: 62
        implicitWidth: 62
        buttonRadius: height / 2

        colBackground: isRecording ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3
        colBackgroundHover: isRecording ? Appearance.colors.colError : Appearance.colors.colLayer3Hover
        colRipple: isRecording ? Appearance.colors.colErrorActive : Appearance.colors.colLayer3Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 26
            color: bigButton.isRecording ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer3
        }

        StyledToolTip {
            text: bigButton.name
        }
    }

    component ActionButton: RippleButton {
        id: actionBtn
        required property string materialSymbol
        required property string labelText
        implicitHeight: 30
        buttonRadius: height / 2
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colRipple: Appearance.colors.colLayer3Active

        contentItem: Row {
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: actionBtn.materialSymbol
                iconSize: 16
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: actionBtn.labelText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
            }
        }
    }

    component RecorderStatusBar: Item {
        id: statusBar
        implicitHeight: statusColumn.implicitHeight
        implicitWidth: statusColumn.implicitWidth

        ColumnLayout {
            id: statusColumn
            anchors.centerIn: parent
            spacing: 2

            // Mic + Volume row
            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: Audio.micMuted ? "mic_off" : "mic"
                        iconSize: 14
                        color: Audio.micMuted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Mic") + ": " + (Audio.micMuted ? Translation.tr("OFF") : Translation.tr("ON"))
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Audio.micMuted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Vol") + ": " + Math.round((Audio.sink?.audio?.volume ?? 1) * 100) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Disk + Path row
            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: "storage"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: root.getDiskFreeText() + " " + Translation.tr("free")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: "folder"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: {
                            const p = root.effectiveSavePath;
                            const parts = p.split("/");
                            return parts.length > 0 ? "~/" + parts[parts.length - 1] : p;
                        }
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                        opacity: 0.7
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Timer {
            interval: 10000
            running: GlobalStates.overlayOpen
            repeat: true
            onTriggered: root.refreshDiskInfo()
            Component.onCompleted: root.refreshDiskInfo()
        }
    }

    component RecorderGameModeSection: ColumnLayout {
        id: gameModeSection
        spacing: 4

        property bool _expanded: false

        // Header button
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            RippleButton {
                id: toggleBtn
                implicitHeight: 26
                buttonRadius: height / 2
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer3Hover
                colRipple: Appearance.colors.colLayer3Active
                onClicked: gameModeSection._expanded = !gameModeSection._expanded

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        text: "sports_esports"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Game Mode Overrides")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    MaterialSymbol {
                        text: gameModeSection._expanded ? "expand_less" : "expand_more"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Collapsible content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            spacing: 2
            visible: gameModeSection._expanded

            Behavior on visible {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            GameModeToggle {
                text: Translation.tr("Auto-hide OSD during fullscreen")
                configKey: "overlay.recorder.autoHideOnFullscreen"
                defaultVal: true
            }

            GameModeToggle {
                text: Translation.tr("Suppress notifications")
                configKey: "overlay.recorder.suppressToasts"
                defaultVal: true
            }

            GameModeToggle {
                text: Translation.tr("Disable Niri animations")
                configKey: "overlay.recorder.disableNiriAnims"
                defaultVal: false
            }
        }
    }

    component GameModeToggle: Row {
        id: gmToggle
        required property string text
        required property string configKey
        property bool defaultVal: false

        spacing: 8
        Layout.fillWidth: true

        StyledText {
            text: gmToggle.text
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
            Layout.fillWidth: true
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        RippleButton {
            id: checkBox
            implicitWidth: 18
            implicitHeight: 18
            buttonRadius: 3
            toggled: {
                const keys = gmToggle.configKey.split(".");
                let val = Config.options;
                for (let i = 0; val && i < keys.length; i++) val = val[keys[i]];
                return val !== undefined ? val : gmToggle.defaultVal;
            }
            colBackgroundToggled: Appearance.colors.colPrimary
            colBackground: Appearance.colors.colLayer3
            colBackgroundHover: Appearance.colors.colLayer3Hover

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: 12
                visible: checkBox.toggled
                color: Appearance.colors.colOnPrimary
            }

            onClicked: {
                Config.setNestedValue(gmToggle.configKey, !checkBox.toggled);
            }
        }
    }
}
