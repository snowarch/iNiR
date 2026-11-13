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
import qs.modules.shared.overlay
import qs.services

// Capture: the two recordings lead (a region, the whole screen), or the running one with its time and Stop; then the
// stills, what audio goes in, and where it all lands.
StyledOverlayWidget {
    id: root
    resizable: false

    readonly property bool recording: RecorderStatus.isRecording
    factColor: OverlayLook.colError

    readonly property string savePath: {
        const configured = String(Config.getNestedValue("screenRecord.savePath", ""))
        if (configured.length > 0) return configured
        const videos = FileUtils.trimFileProtocol(Directories.videos)
        return videos || `${FileUtils.trimFileProtocol(Directories.home)}/Videos`
    }
    readonly property string screenshotPath: Directories.screenshotsPath
    readonly property string audioMode: RecorderStatus.configuredAudioMode
    readonly property string liveAudioMode: root.recording ? RecorderStatus.effectiveAudioMode : root.audioMode
    readonly property var audioModes: [
        { value: "none", label: "None", glyph: "volume_off", long: "No audio" },
        { value: "system", label: "System", glyph: "volume_up", long: "System audio" },
        { value: "microphone", label: "Mic", glyph: "mic", long: "Microphone" },
        { value: "both", label: "Both", glyph: "instant_mix", long: "System + mic" }
    ]
    function audioLabel(mode: string): string {
        const found = root.audioModes.find(m => m.value === mode)
        return Translation.tr(found ? found.long : "System audio")
    }

    // Free space where recordings land, read while the bench is open.
    property string diskFree: ""
    Process {
        id: diskQuery
        command: ["df", "-BG", "--output=avail", root.savePath]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.diskFree = lines.length > 1 ? lines[lines.length - 1].trim() : ""
            }
        }
    }
    Timer {
        interval: 10000
        running: root.benchOpen && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!diskQuery.running) diskQuery.running = true
    }

    property string folderTarget: "recordings"
    property bool _dialogShown: false
    function chooseFolder(target: string): void {
        root.folderTarget = target
        folderDialog.open()
    }
    function syncDialog(): void {
        const shown = Boolean(folderDialog.visible)
        if (shown === root._dialogShown) return
        root._dialogShown = shown
        OverlayContext.setNativeDialogVisible("recorder-folder", shown)
    }
    function openFolder(path: string, label: string): void {
        GlobalStates.overlayOpen = false
        ShellExec.openDirectory(path, label)
    }

    FolderDialog {
        id: folderDialog
        title: root.folderTarget === "screenshots" ? Translation.tr("Select screenshots folder") : Translation.tr("Select recordings folder")
        currentFolder: `file://${root.folderTarget === "screenshots" ? root.screenshotPath : root.savePath}`
        onAccepted: {
            const path = FileUtils.trimFileProtocol(selectedFolder.toString())
            Config.setNestedValue(root.folderTarget === "screenshots" ? "regionSelector.savePath" : "screenRecord.savePath", path)
        }
        onVisibleChanged: root.syncDialog()
    }
    Component.onDestruction: if (root._dialogShown) OverlayContext.setNativeDialogVisible("recorder-folder", false)

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(340 * root.d)
        implicitHeight: column.implicitHeight

        ColumnLayout {
            id: column
            anchors.fill: parent
            spacing: Math.round(8 * root.d)

            // The lead: two recordings, or the one running.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(92 * root.d)

                RowLayout {
                    anchors.fill: parent
                    spacing: Math.round(8 * root.d)
                    opacity: root.recording ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: FamilyStyle.revealDuration } }
                    CaptureTile {
                        glyph: "screen_record"
                        label: Translation.tr("Record region")
                        detail: root.audioLabel(root.audioMode)
                        onClicked: OverlayContext.recordRegion()
                    }
                    CaptureTile {
                        glyph: "capture"
                        label: Translation.tr("Record screen")
                        detail: root.audioLabel(root.audioMode)
                        onClicked: OverlayContext.recordScreen()
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: root.recording ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: FamilyStyle.revealDuration } }
                    radius: OverlayLook.roundingNormal
                    color: OverlayLook.colErrorContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(16 * root.d)
                        anchors.rightMargin: Math.round(12 * root.d)
                        spacing: Math.round(12 * root.d)

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Math.round(10 * root.d)
                            implicitHeight: implicitWidth
                            radius: width / 2
                            color: OverlayLook.colError
                            SequentialAnimation on opacity {
                                running: root.recording && root.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0
                            StyledText {
                                text: OverlayContext.elapsed(RecorderStatus.elapsedSeconds)
                                color: OverlayLook.colOnErrorContainer
                                font.family: OverlayLook.fontNumbers
                                font.features: ({ "tnum": 1 })
                                font.pixelSize: OverlayLook.typeFigure
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: Translation.tr("Recording") + " · " + root.audioLabel(root.liveAudioMode)
                                    + (RecorderStatus.audioFallback ? " · " + Translation.tr("Fallback") : "")
                                color: OverlayLook.colOnErrorContainer
                                opacity: 0.75
                                font.family: OverlayLook.fontMain
                                font.pixelSize: OverlayLook.typeMeta
                            }
                        }
                        OverlayButton {
                            Layout.alignment: Qt.AlignVCenter
                            size: Math.round(36 * root.d)
                            strong: true
                            tint: OverlayLook.colError
                            glyph: "stop"
                            label: Translation.tr("Stop")
                            tip: Translation.tr("Stop recording")
                            onClicked: OverlayContext.stopRecording()
                        }
                    }
                }
            }

            // Stills
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)
                OverlayButton {
                    Layout.fillWidth: true
                    filled: true
                    size: Math.round(36 * root.d)
                    glyphSize: Math.round(18 * root.d)
                    glyph: "screenshot_region"
                    label: Translation.tr("Screenshot")
                    tip: Translation.tr("Screenshot region")
                    onClicked: OverlayContext.screenshotRegion()
                }
                OverlayButton {
                    Layout.fillWidth: true
                    filled: true
                    size: Math.round(36 * root.d)
                    glyphSize: Math.round(18 * root.d)
                    glyph: "content_copy"
                    label: Translation.tr("Copy screen")
                    tip: Translation.tr("Clipboard only")
                    onClicked: OverlayContext.copyScreen()
                }
            }

            // Audio, and what it will pick up
            OverlaySegments {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(4 * root.d)
                enabled: !root.recording
                opacity: enabled ? 1 : 0.5
                accessibleName: Translation.tr("Audio")
                options: root.audioModes
                current: root.audioMode
                onPicked: value => RecorderStatus.setConfiguredAudioMode(value)
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(14 * root.d)
                Fact {
                    visible: root.liveAudioMode === "system" || root.liveAudioMode === "both"
                    glyph: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                    text: Math.round((Audio.sink?.audio?.volume ?? 1) * 100) + "%"
                    warn: Audio.sink?.audio?.muted ?? false
                }
                Fact {
                    visible: root.liveAudioMode === "microphone" || root.liveAudioMode === "both"
                    glyph: Audio.micMuted ? "mic_off" : "mic"
                    text: Audio.micMuted ? Translation.tr("OFF") : Translation.tr("ON")
                    warn: Audio.micMuted
                }
                Fact {
                    visible: root.diskFree.length > 0
                    glyph: "storage"
                    text: root.diskFree + " " + Translation.tr("free")
                }
            }

            Item { Layout.fillHeight: true }

            // Where it lands
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: OverlayLook.colHairline
            }
            FolderRow {
                glyph: "movie"
                title: Translation.tr("Recordings")
                path: root.savePath
                onOpenRequested: root.openFolder(root.savePath, Translation.tr("Open recordings folder"))
                onChangeRequested: root.chooseFolder("recordings")
            }
            FolderRow {
                glyph: "image"
                title: Translation.tr("Screenshots")
                path: root.screenshotPath
                onOpenRequested: root.openFolder(root.screenshotPath, Translation.tr("Open screenshots folder"))
                onChangeRequested: root.chooseFolder("screenshots")
            }
        }
    }

    component CaptureTile: RippleButton {
        id: tile
        property string glyph
        property string label
        property string detail
        Layout.fillWidth: true
        Layout.fillHeight: true
        padding: 0
        rippleEnabled: !OverlayLook.own && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
        buttonRadius: OverlayLook.roundingNormal
        colBackground: OverlayLook.colLayer2
        colBackgroundHover: OverlayLook.colLayer2Hover
        colRipple: OverlayLook.colLayer2Active
        Accessible.name: tile.label
        contentItem: Item {
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(12 * root.d)
                spacing: Math.round(1 * root.d)
                MaterialSymbol {
                    text: tile.glyph
                    iconSize: Math.round(24 * root.d)
                    fill: 1
                    color: OverlayLook.colError
                }
                Item { width: 1; height: Math.round(5 * root.d) }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.label
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeBody
                    font.weight: Font.DemiBold
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.detail
                    color: OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeMeta
                }
            }
        }
    }

    component Fact: Row {
        id: factRow
        property string glyph
        property string text
        property bool warn: false
        spacing: Math.round(4 * root.d)
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            text: factRow.glyph
            iconSize: Math.round(14 * root.d)
            color: factRow.warn ? OverlayLook.colError : OverlayLook.colSubtext
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: factRow.text
            color: factRow.warn ? OverlayLook.colError : OverlayLook.colSubtext
            font.family: OverlayLook.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: OverlayLook.typeMeta
        }
    }

    component FolderRow: RowLayout {
        id: folderRow
        property string glyph
        property string title
        property string path
        signal openRequested()
        signal changeRequested()
        Layout.fillWidth: true
        spacing: Math.round(8 * root.d)
        MaterialSymbol {
            Layout.leftMargin: Math.round(4 * root.d)
            text: folderRow.glyph
            iconSize: Math.round(16 * root.d)
            color: OverlayLook.colSubtext
        }
        StyledText {
            text: folderRow.title
            color: OverlayLook.colOnLayer1
            font.family: OverlayLook.fontMain
            font.pixelSize: OverlayLook.typeMeta
            font.weight: Font.Medium
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: Directories.shortHomePath(folderRow.path)
            color: OverlayLook.colSubtext
            font.family: OverlayLook.fontMain
            font.pixelSize: OverlayLook.typeMeta
        }
        OverlayButton {
            size: Math.round(26 * root.d)
            glyph: "folder_open"
            tip: Translation.tr("Open folder")
            onClicked: folderRow.openRequested()
        }
        OverlayButton {
            size: Math.round(26 * root.d)
            glyph: "drive_file_move"
            tip: Translation.tr("Change folder")
            onClicked: folderRow.changeRequested()
        }
    }
}
