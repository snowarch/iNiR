pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.modules.mediaControls.components
import qs.modules.iris.style
import "../components"

// AIRISU's Control Center, «control 操作» (AIRISU.md › Anatomía, board Desktop): a wide head, four switch tiles parted
// by 1 px fillets with the chosen ones on the gofun plate, meters of 20 segments, the record playing with a vermilion
// seal, and the spec sheet at the foot. IrisControlCenter keeps the body, its placement, the morph and the field; this
// is only what the body holds, laid edge to edge (the manifest asks for no padding).
Item {
    id: root
    property var targetScreen
    readonly property real d: Airisu.d
    readonly property var monitor: Brightness.getMonitorForScreen(root.targetScreen)
    readonly property real brightness: Number(root.monitor?.brightness ?? Number.NaN)
    readonly property var player: MprisController.activePlayer ?? null
    onVisibleChanged: if (visible) root.monitor?.refresh()
    implicitHeight: column.implicitHeight

    NetworkToggle { id: network }
    BluetoothToggle { id: bluetooth }

    component Fillet: ARule { Layout.fillWidth: true }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 0

        AHeader {
            Layout.fillWidth: true
            Layout.margins: Airisu.pad
            Layout.topMargin: Math.round(22 * root.d)
            Layout.bottomMargin: Math.round(16 * root.d)
            caption: Translation.tr("Panel")
            title: Translation.tr("control")
            kanji: "操作"
        }

        // Four switches, two by two, the fillets between them and none round them: the body's edge is the frame.
        Fillet {}
        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 0
            columnSpacing: 0
            ATile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Network.ethernet && !Network.wifi ? Translation.tr("Ethernet") : Translation.tr("Wi-Fi")
                // A cable's name is NetworkManager's "Wired connection 1": it says nothing, so a cable reads Connected.
                status: !network.toggled ? Translation.tr("Off") : Network.ethernet && !Network.wifi ? Translation.tr("Connected") : (Network.networkName || Translation.tr("On"))
                on: network.toggled
                onClicked: network.mainAction()
                onAltClicked: { GlobalStates.controlPanelOpen = false; network.altAction() }
            }
            ARule { vertical: true; Layout.fillHeight: true }
            ATile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Translation.tr("Bluetooth")
                status: !bluetooth.available ? Translation.tr("Unavailable")
                    : !bluetooth.toggled ? Translation.tr("Off")
                    : BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("On")
                on: bluetooth.toggled
                available: bluetooth.available
                onClicked: bluetooth.mainAction()
                onAltClicked: { GlobalStates.controlPanelOpen = false; bluetooth.altAction() }
            }
            ARule { Layout.columnSpan: 3; Layout.fillWidth: true }
            ATile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Translation.tr("Do not disturb")
                status: Notifications.silent ? Translation.tr("On") : Translation.tr("Off")
                on: Notifications.silent
                onClicked: Notifications.silent = !Notifications.silent
            }
            ARule { vertical: true; Layout.fillHeight: true }
            ATile {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                title: Translation.tr("Record")
                status: RecorderStatus.isRecording ? Translation.tr("Recording") : Translation.tr("Screen and sound")
                live: RecorderStatus.isRecording
                onClicked: {
                    const recording = RecorderStatus.isRecording
                    Quickshell.execDetached(["/usr/bin/bash", Directories.recordScriptPath].concat(recording ? ["--stop"] : ["--fullscreen", "--sound"]))
                    RecorderStatus.scheduleQuickCheck()
                    if (!recording) GlobalStates.controlPanelOpen = false
                }
            }
        }
        Fillet {}

        // Levels: the name, the figure wide at the right, the meter under them.
        Repeater {
            model: [
                { id: "volume", label: Translation.tr("Volume") },
                { id: "brightness", label: Translation.tr("Brightness") }
            ]
            delegate: ColumnLayout {
                id: level
                required property var modelData
                required property int index
                readonly property bool ready: level.modelData.id === "brightness" ? Boolean(root.monitor?.ready) && Number.isFinite(root.brightness) : true
                readonly property bool muted: level.modelData.id === "volume" && (Audio.sink?.audio?.muted ?? false)
                readonly property real value: !level.ready ? 0 : level.modelData.id === "brightness" ? root.brightness : Math.min(1, Audio.value ?? 0)
                Layout.fillWidth: true
                Layout.leftMargin: Airisu.pad
                Layout.rightMargin: Airisu.pad
                Layout.topMargin: level.index === 0 ? Math.round(18 * root.d) : Math.round(14 * root.d)
                Layout.bottomMargin: level.index === 1 ? Math.round(18 * root.d) : 0
                spacing: Math.round(8 * root.d)
                opacity: level.ready ? 1 : 0.45
                RowLayout {
                    Layout.fillWidth: true
                    AText {
                        Layout.fillWidth: true
                        text: level.modelData.label
                        size: IrisStyle.typeBody
                        font.weight: Font.Bold
                        TapHandler { enabled: level.modelData.id === "volume"; onTapped: Audio.toggleMute() }
                    }
                    AText {
                        voice: level.muted ? "mono" : "wide"
                        size: level.muted ? IrisStyle.typeCaption : IrisStyle.typeHeadline
                        text: level.muted ? Translation.tr("Muted") : Math.round(level.value * 100)
                        color: level.muted ? Airisu.sealText : Airisu.gofun
                    }
                }
                AMeter {
                    Layout.fillWidth: true
                    value: level.value
                    interactive: level.ready
                    onMoved: next => {
                        if (level.modelData.id === "brightness") root.monitor?.setBrightness(next)
                        else Audio.setSinkVolume(next)
                    }
                }
            }
        }

        // What is playing: the cover, the title wide, and the seal that pauses it.
        Fillet { visible: media.visible }
        Item {
            id: media
            visible: root.player !== null
            Layout.fillWidth: true
            implicitHeight: Math.round(72 * root.d) + Airisu.pad * 2 - Math.round(8 * root.d)
            PlayerBase { id: playing; player: root.player; positionUpdatesActive: false }
            Rectangle {
                id: cover
                anchors.left: parent.left
                anchors.leftMargin: Airisu.pad
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(72 * root.d)
                height: width
                color: Airisu.sumi
                Image {
                    anchors.fill: parent
                    source: playing.displayedArtFilePath.startsWith("/") ? `file://${playing.displayedArtFilePath}` : playing.displayedArtFilePath
                    sourceSize.width: width
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: cover.right
                anchors.leftMargin: Math.round(16 * root.d)
                anchors.right: seal.left
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * root.d)
                AText { width: parent.width; voice: "wide"; size: IrisStyle.typeHeadline; text: playing.effectiveTitle || Translation.tr("Nothing playing") }
                AText { width: parent.width; text: playing.effectiveArtist; color: Airisu.data; font.weight: Font.Normal; visible: text.length > 0 }
            }
            ASeal {
                id: seal
                anchors.right: parent.right
                anchors.rightMargin: Airisu.pad
                anchors.verticalCenter: parent.verticalCenter
                glyph: playing.effectiveIsPlaying ? "pause" : "play_arrow"
                onClicked: MprisController.togglePlaying()
            }
        }
        Fillet {}

        ASpec {
            Layout.fillWidth: true
            Layout.margins: Airisu.pad
            Layout.topMargin: Math.round(18 * root.d)
            Layout.bottomMargin: Math.round(22 * root.d)
            rows: [
                { label: Translation.tr("Compositor"), value: CompositorService.isNiri ? "niri" : "—" },
                { label: Translation.tr("Family"), value: `iRiS / ${IrisDesign.name}` },
                { label: Translation.tr("Uptime"), value: DateTime.uptime },
                { label: Translation.tr("Build"), value: "NIGHT SPEC", live: true }
            ]
        }
    }
}
