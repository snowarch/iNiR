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
    minimumWidth: 400
    minimumHeight: Math.max(250, contentColumn.implicitHeight)

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
    readonly property string effectiveScreenshotPath: Directories.screenshotsPath
    readonly property string audioMode: RecorderStatus.configuredAudioMode
    readonly property string statusAudioMode: RecorderStatus.isRecording ? RecorderStatus.effectiveAudioMode : audioMode
    property string folderDialogTarget: "recordings"
    property bool _folderDialogEngaged: false

    function audioModeLabel(mode: string): string {
        switch (mode) {
        case "none": return Translation.tr("No audio")
        case "microphone": return Translation.tr("Microphone")
        case "both": return Translation.tr("System + mic")
        default: return Translation.tr("System audio")
        }
    }

    function audioModeIcon(mode: string): string {
        switch (mode) {
        case "none": return "volume_off"
        case "microphone": return "mic"
        case "both": return "instant_mix"
        default: return "volume_up"
        }
    }

    function setAudioMode(mode: string): void {
        RecorderStatus.setConfiguredAudioMode(mode)
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

    function openFolderDialog(target: string): void {
        root.folderDialogTarget = target
        folderDialog.open()
    }

    function syncFolderDialogLayer(): void {
        const visible = Boolean(folderDialog.visible)
        if (visible === root._folderDialogEngaged) return
        root._folderDialogEngaged = visible
        OverlayContext.setNativeDialogVisible("recorder-folder", visible)
    }

    Process {
        id: diskQueryProcess
        command: ["/usr/bin/df", "-BG", "--output=avail", root.effectiveSavePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root._diskFreeText = lines.length > 1 ? lines[lines.length - 1].trim() : "?"
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
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            width: Math.min(parent.width - 20, 620)
            spacing: 10

            // ── Recording indicator + timer (only when recording) ──
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                opacity: RecorderStatus.isRecording ? 1 : 0
                visible: opacity > 0
                implicitHeight: RecorderStatus.isRecording ? 28 : 0
                Layout.preferredHeight: implicitHeight
                radius: Math.min(width, height) / 2
                color: Appearance.colors.colErrorContainer

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on implicitHeight {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                }

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

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: 42
                elevation: 2
                outlined: false

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    StyledText {
                        text: Translation.tr("Audio")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        Layout.leftMargin: 4
                    }

                    Item { Layout.fillWidth: true }

                    RecorderAudioButton {
                        audioModeValue: "none"
                        materialSymbol: "volume_off"
                        labelText: Translation.tr("No audio")
                    }
                    RecorderAudioButton {
                        audioModeValue: "system"
                        materialSymbol: "volume_up"
                        labelText: Translation.tr("System audio")
                    }
                    RecorderAudioButton {
                        audioModeValue: "microphone"
                        materialSymbol: "mic"
                        labelText: Translation.tr("Microphone")
                    }
                    RecorderAudioButton {
                        audioModeValue: "both"
                        materialSymbol: "instant_mix"
                        labelText: Translation.tr("System + microphone")
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                RecorderActionButton {
                    Layout.fillWidth: true
                    materialSymbol: "screenshot_region"
                    labelText: Translation.tr("Screenshot region")
                    detailText: Translation.tr("Save + copy")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "screenshot"]);
                    }
                }

                RecorderActionButton {
                    Layout.fillWidth: true
                    materialSymbol: "content_copy"
                    labelText: Translation.tr("Copy screen")
                    detailText: Translation.tr("Clipboard only")
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached(["/usr/bin/bash", "-c", "/usr/bin/grim - | /usr/bin/wl-copy"]);
                    }
                }

                RecorderActionButton {
                    Layout.fillWidth: true
                    visible: !RecorderStatus.isRecording
                    materialSymbol: "screen_record"
                    labelText: Translation.tr("Record region")
                    detailText: root.audioModeLabel(root.audioMode)
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "region", "recordWithSound"]);
                    }
                }

                RecorderActionButton {
                    Layout.fillWidth: true
                    visible: !RecorderStatus.isRecording
                    materialSymbol: "capture"
                    labelText: Translation.tr("Record screen")
                    detailText: root.audioModeLabel(root.audioMode)
                    onClicked: {
                        GlobalStates.overlayOpen = false;
                        Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]);
                        RecorderStatus.scheduleQuickCheck();
                    }
                }

                RecorderActionButton {
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    visible: RecorderStatus.isRecording
                    materialSymbol: "stop_circle"
                    labelText: Translation.tr("Stop recording")
                    detailText: root.formatElapsed(RecorderStatus.elapsedSeconds)
                    destructive: true
                    onClicked: {
                        Quickshell.execDetached([Directories.recordScriptPath, "--stop"]);
                        RecorderStatus.scheduleQuickCheck();
                    }
                }
            }

            // ── Status bar ──
            RecorderStatusBar {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: destinationsColumn.implicitHeight + 16
                elevation: 2
                outlined: false

                ColumnLayout {
                    id: destinationsColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    StyledText {
                        text: Translation.tr("Capture folders")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer2
                    }

                    DestinationRow {
                        titleText: Translation.tr("Recordings")
                        pathText: Directories.shortHomePath(root.effectiveSavePath)
                        onOpenRequested: {
                            GlobalStates.overlayOpen = false
                            ShellExec.openDirectory(root.effectiveSavePath, Translation.tr("Open recordings folder"))
                        }
                        onChangeRequested: root.openFolderDialog("recordings")
                    }

                    DestinationRow {
                        titleText: Translation.tr("Screenshots")
                        pathText: Directories.shortHomePath(root.effectiveScreenshotPath)
                        onOpenRequested: {
                            GlobalStates.overlayOpen = false
                            ShellExec.openDirectory(root.effectiveScreenshotPath, Translation.tr("Open screenshots folder"))
                        }
                        onChangeRequested: root.openFolderDialog("screenshots")
                    }
                }
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: root.folderDialogTarget === "screenshots"
            ? Translation.tr("Select screenshots folder")
            : Translation.tr("Select recordings folder")
        currentFolder: `file://${root.folderDialogTarget === "screenshots" ? root.effectiveScreenshotPath : root.effectiveSavePath}`
        onAccepted: {
            const path = FileUtils.trimFileProtocol(selectedFolder.toString());
            Config.setNestedValue(root.folderDialogTarget === "screenshots"
                ? "regionSelector.savePath" : "screenRecord.savePath", path);
        }
    }

    Connections {
        target: folderDialog
        function onVisibleChanged(): void { root.syncFolderDialogLayer() }
    }

    Component.onDestruction: {
        if (root._folderDialogEngaged)
            OverlayContext.setNativeDialogVisible("recorder-folder", false)
    }

    // ── Sub-components ──

    component RecorderAudioButton: RippleButton {
        id: audioButton
        required property string audioModeValue
        required property string materialSymbol
        required property string labelText
        readonly property bool modeSelected: root.audioMode === audioModeValue
        implicitWidth: 72
        implicitHeight: 28
        buttonRadius: height / 2
        colBackground: modeSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer3
        colBackgroundHover: modeSelected ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3Hover
        colRipple: modeSelected ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer3Active
        onClicked: root.setAudioMode(audioModeValue)

        contentItem: Row {
            anchors.centerIn: parent
            spacing: 4

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: audioButton.materialSymbol
                iconSize: 15
                color: audioButton.modeSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: audioButton.audioModeValue === "both" ? Translation.tr("Both")
                    : audioButton.audioModeValue === "microphone" ? Translation.tr("Mic")
                    : audioButton.audioModeValue === "system" ? Translation.tr("System")
                    : Translation.tr("None")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: audioButton.modeSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer3
            }
        }

        StyledToolTip {
            text: audioButton.labelText
        }
    }

    component RecorderActionButton: RippleButton {
        id: actionButton
        required property string materialSymbol
        required property string labelText
        required property string detailText
        property bool destructive: false
        implicitHeight: 54
        buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.roundSmall
            : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
            : Appearance.rounding.normal
        colBackground: destructive ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3
        colBackgroundHover: destructive ? Appearance.colors.colError : Appearance.colors.colLayer3Hover
        colRipple: destructive ? Appearance.colors.colErrorActive : Appearance.colors.colLayer3Active

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MaterialSymbol {
                text: actionButton.materialSymbol
                iconSize: 22
                color: actionButton.destructive
                    ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer3
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: actionButton.labelText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: actionButton.destructive
                        ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer3
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: actionButton.detailText
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: actionButton.destructive
                        ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                    opacity: 0.78
                    elide: Text.ElideRight
                }
            }
        }
    }

    component DestinationRow: RowLayout {
        id: destinationRow
        required property string titleText
        required property string pathText
        signal openRequested()
        signal changeRequested()
        Layout.fillWidth: true
        spacing: 6

        MaterialSymbol {
            text: "folder"
            iconSize: 15
            color: Appearance.colors.colOnLayer2
        }

        StyledText {
            text: destinationRow.titleText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
        }

        StyledText {
            Layout.fillWidth: true
            text: destinationRow.pathText
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
        }

        RippleButton {
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: height / 2
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer3Hover
            colRipple: Appearance.colors.colLayer3Active
            onClicked: destinationRow.openRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "folder_open"
                iconSize: 15
                color: Appearance.colors.colOnLayer2
            }
            StyledToolTip { text: Translation.tr("Open folder") }
        }

        RippleButton {
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: height / 2
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer3Hover
            colRipple: Appearance.colors.colLayer3Active
            onClicked: destinationRow.changeRequested()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "drive_file_move"
                iconSize: 15
                color: Appearance.colors.colOnLayer2
            }
            StyledToolTip { text: Translation.tr("Change folder") }
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

            // Capture profile + relevant live source state
            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: root.audioModeIcon(root.statusAudioMode)
                        iconSize: 14
                        color: root.statusAudioMode === "none" ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Translation.tr("Audio") + ": " + root.audioModeLabel(root.statusAudioMode)
                            + (RecorderStatus.isRecording && RecorderStatus.audioFallback ? " · " + Translation.tr("Fallback") : "")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.statusAudioMode === "none" ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    visible: root.statusAudioMode === "system" || root.statusAudioMode === "both"
                    spacing: 4
                    MaterialSymbol {
                        text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        iconSize: 14
                        color: Audio.sink?.audio?.muted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Math.round((Audio.sink?.audio?.volume ?? 1) * 100) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Audio.sink?.audio?.muted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    visible: root.statusAudioMode === "microphone" || root.statusAudioMode === "both"
                    spacing: 4
                    MaterialSymbol {
                        text: Audio.micMuted ? "mic_off" : "mic"
                        iconSize: 14
                        color: Audio.micMuted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Audio.micMuted ? Translation.tr("OFF") : Translation.tr("ON")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Audio.micMuted ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

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

}
