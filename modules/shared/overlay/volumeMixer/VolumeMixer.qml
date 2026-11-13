pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.shared.overlay

// Sound without leaving the game: the device and its level, every app beneath with its own; the microphone the same
// way; what plays now.
StyledOverlayWidget {
    id: root

    readonly property int page: Math.max(0, Math.min(2, Persistent.states.overlay.volumeMixer?.tabIndex ?? 0))
    function percent(v: real): string { return Math.round(Math.max(0, v) * 100) + "%" }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(300 * root.d)
        implicitHeight: Math.round(320 * root.d)

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(10 * root.d)

            OverlaySegments {
                Layout.fillWidth: true
                accessibleName: Translation.tr("Volume")
                options: [
                    { value: 0, label: "Output", glyph: "media_output" },
                    { value: 1, label: "Input", glyph: "mic" },
                    { value: 2, label: "Music", glyph: "music_note" }
                ]
                current: root.page
                onPicked: value => Persistent.states.overlay.volumeMixer.tabIndex = value
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.page
                StreamPage { output: true }
                StreamPage { output: false }
                MusicPage {}
            }
        }
    }

    // A device, its level, and the apps that play (or record) through it.
    component StreamPage: ColumnLayout {
        id: page
        required property bool output
        property bool choosing: false
        readonly property var device: page.output ? Audio.defaultSink : Audio.source
        readonly property var devices: page.output ? Audio.outputDevices : Audio.inputDevices
        readonly property bool muted: page.output ? (Audio.sink?.audio?.muted ?? false) : Audio.micMuted
        readonly property real level: page.output ? Audio.value : Audio.micVolume
        // By name, so a row keeps its place: PipeWire lists streams in the order they last reshuffled.
        readonly property var apps: (page.output ? MprisController.mixerAppNodes : Audio.inputAppNodes).slice()
            .sort((a, b) => MprisController.streamDisplayName(a).localeCompare(MprisController.streamDisplayName(b)))
        // PipeWire empties the list for a moment when a stream comes or goes: the empty note waits for it to stay empty.
        property bool emptyShown: page.apps.length === 0
        onAppsChanged: {
            if (page.apps.length > 0) {
                page.emptyShown = false
                emptyWait.stop()
            } else {
                emptyWait.restart()
            }
        }
        Timer {
            id: emptyWait
            interval: 300
            onTriggered: page.emptyShown = page.apps.length === 0
        }
        onVisibleChanged: if (!page.visible) page.choosing = false
        spacing: Math.round(8 * root.d)

        RippleButton {
            id: deviceButton
            Layout.fillWidth: true
            implicitHeight: Math.round(48 * root.d)
            padding: 0
            rippleEnabled: !OverlayLook.own && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
            buttonRadius: OverlayLook.roundingSmall
            colBackground: OverlayLook.colLayer2
            colBackgroundHover: OverlayLook.colLayer2Hover
            colRipple: OverlayLook.colLayer2Active
            Accessible.name: page.output ? Translation.tr("Output device") : Translation.tr("Input device")
            onClicked: page.choosing = !page.choosing
            contentItem: RowLayout {
                spacing: Math.round(10 * root.d)
                MaterialSymbol {
                    Layout.leftMargin: Math.round(12 * root.d)
                    text: page.output ? "speaker" : "mic"
                    iconSize: Math.round(20 * root.d)
                    fill: 1
                    color: OverlayLook.colPrimary
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: page.output ? Translation.tr("Output device") : Translation.tr("Input device")
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Audio.friendlyDeviceName(page.device) || "–"
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeBody
                        font.weight: Font.DemiBold
                    }
                }
                MaterialSymbol {
                    Layout.rightMargin: Math.round(10 * root.d)
                    text: page.choosing ? "expand_less" : "expand_more"
                    iconSize: Math.round(18 * root.d)
                    color: OverlayLook.colSubtext
                }
            }
        }

        // Devices, in place of the level and the apps while choosing
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: page.choosing
            clip: true
            spacing: Math.round(2 * root.d)
            boundsBehavior: Flickable.StopAtBounds
            model: page.devices
            delegate: RippleButton {
                id: deviceRow
                required property var modelData
                readonly property bool current: deviceRow.modelData.id === page.device?.id
                width: ListView.view.width
                implicitHeight: Math.round(36 * root.d)
                padding: 0
                rippleEnabled: !OverlayLook.own && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
                buttonRadius: OverlayLook.roundingSmall
                colBackground: deviceRow.current ? OverlayLook.colToggle : ColorUtils.applyAlpha(OverlayLook.colLayer2, 0)
                colBackgroundHover: deviceRow.current ? OverlayLook.colToggleHover : OverlayLook.colLayer2Hover
                colRipple: OverlayLook.colLayer2Active
                onClicked: {
                    if (page.output) Audio.setDefaultSink(deviceRow.modelData)
                    else Audio.setDefaultSource(deviceRow.modelData)
                    page.choosing = false
                }
                contentItem: RowLayout {
                    spacing: Math.round(10 * root.d)
                    MaterialSymbol {
                        Layout.leftMargin: Math.round(12 * root.d)
                        text: deviceRow.current ? "check" : page.output ? "speaker" : "mic"
                        iconSize: Math.round(16 * root.d)
                        color: deviceRow.current ? OverlayLook.colOnToggle : OverlayLook.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Math.round(12 * root.d)
                        elide: Text.ElideRight
                        text: Audio.friendlyDeviceName(deviceRow.modelData)
                        color: deviceRow.current ? OverlayLook.colOnToggle : OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeBody
                        font.weight: deviceRow.current ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }

        // The device's level
        RowLayout {
            Layout.fillWidth: true
            visible: !page.choosing
            spacing: Math.round(8 * root.d)
            OverlayButton {
                size: Math.round(32 * root.d)
                glyph: page.output ? (page.muted ? "volume_off" : "volume_up") : (page.muted ? "mic_off" : "mic")
                tint: OverlayLook.colError
                toggled: page.muted
                tip: page.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                onClicked: page.output ? Audio.toggleMute() : Audio.toggleMicMute()
            }
            OverlaySlider {
                Layout.fillWidth: true
                opacity: page.muted ? 0.5 : 1
                stepSize: 0.01
                value: Math.min(1, page.level)
                onMoved: v => page.output ? Audio.setSinkVolume(v) : Audio.setSourceVolume(v)
                onCommitted: v => page.output ? Audio.setSinkVolume(v) : Audio.setSourceVolume(v)
            }
            StyledText {
                Layout.preferredWidth: Math.round(38 * root.d)
                horizontalAlignment: Text.AlignRight
                text: root.percent(page.level)
                color: page.muted ? OverlayLook.colError : OverlayLook.colOnLayer1
                font.family: OverlayLook.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: OverlayLook.typeMeta
                font.weight: Font.DemiBold
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const v = page.level + (event.angleDelta.y > 0 ? 0.05 : -0.05)
                    page.output ? Audio.setSinkVolume(v) : Audio.setSourceVolume(v)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: !page.choosing
            implicitHeight: 1
            color: OverlayLook.colHairline
        }

        StyledText {
            visible: !page.choosing
            Layout.leftMargin: Math.round(2 * root.d)
            text: Translation.tr("Apps")
            color: OverlayLook.colSubtext
            font.family: OverlayLook.fontMain
            font.pixelSize: OverlayLook.typeFootnote
            font.weight: Font.DemiBold
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !page.choosing
            clip: true
            spacing: Math.round(4 * root.d)
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: page.apps }
            delegate: AppRow {
                width: ListView.view.width
                capture: !page.output
            }
            StyledText {
                anchors.centerIn: parent
                opacity: page.emptyShown ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: FamilyStyle.revealDuration } }
                text: page.output ? Translation.tr("No apps playing audio") : Translation.tr("No apps using microphone")
                color: OverlayLook.colFaint
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeMeta
            }
        }
    }

    // One app: its icon, name and level, mute beside.
    component AppRow: Item {
        id: app
        required property var modelData
        property bool capture: false
        readonly property PwNode node: app.modelData
        readonly property bool muted: app.node?.audio?.muted ?? false
        readonly property real level: app.node?.audio?.volume ?? 0
        function setLevel(v: real): void {
            if (app.node?.audio) app.node.audio.volume = Math.max(0, Math.min(1, v))
        }
        implicitHeight: Math.round(44 * root.d)
        PwObjectTracker { objects: [app.node] }

        RowLayout {
            anchors.fill: parent
            spacing: Math.round(10 * root.d)
            Image {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Math.round(4 * root.d)
                sourceSize.width: Math.round(24 * root.d)
                sourceSize.height: Math.round(24 * root.d)
                opacity: app.muted ? 0.45 : 1
                source: app.node ? MprisController.streamIconSource(app.node, "image-missing") : ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Math.round(2 * root.d)
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: {
                            if (!app.node) return ""
                            const name = MprisController.streamDisplayName(app.node)
                            const detail = MprisController.streamDetail?.(app.node) ?? ""
                            return detail.length > 0 ? `${name} · ${detail}` : name
                        }
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: app.muted ? Translation.tr("Muted") : root.percent(app.level)
                        color: app.muted ? OverlayLook.colError : OverlayLook.colSubtext
                        font.family: OverlayLook.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
                OverlaySlider {
                    Layout.fillWidth: true
                    opacity: app.muted ? 0.45 : 1
                    stepSize: 0.01
                    value: Math.min(1, app.level)
                    onMoved: v => app.setLevel(v)
                    onCommitted: v => app.setLevel(v)
                }
            }
            OverlayButton {
                Layout.alignment: Qt.AlignVCenter
                size: Math.round(28 * root.d)
                glyph: app.capture ? (app.muted ? "mic_off" : "mic") : (app.muted ? "volume_off" : "volume_up")
                tint: OverlayLook.colError
                toggled: app.muted
                tip: app.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                onClicked: if (app.node?.audio) app.node.audio.muted = !app.node.audio.muted
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => app.setLevel(app.level + (event.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    // What plays now: its cover, title and time, the three controls; the wheel sets its own volume.
    component MusicPage: Item {
        id: music
        readonly property MprisPlayer player: MprisController.activePlayer
        readonly property bool hasPlayer: music.player !== null
        readonly property real length: MprisController.lengthOf(music.player)
        readonly property real position: MprisController.positionOf(music.player)
        readonly property bool seekable: (music.player?.canSeek ?? false) && !MprisController.isLive(music.player)
        // Where the thumb is while it is held; the player is asked to move only on release.
        property real heldFraction: -1
        readonly property real shownPosition: music.heldFraction >= 0 ? music.heldFraction * music.length : music.position
        onPlayerChanged: music.heldFraction = -1
        onVisibleChanged: if (music.visible) MediaArtwork.refresh()

        Timer {
            running: music.visible && MprisController.isPlaying
            interval: 1000
            repeat: true
            onTriggered: music.player?.positionChanged()
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: MprisController.canChangeVolume
            onWheel: event => MprisController.setVolume(MprisController.getVolume() + (event.angleDelta.y > 0 ? 0.05 : -0.05))
        }

        Column {
            anchors.centerIn: parent
            visible: !music.hasPlayer
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "music_off"
                iconSize: Math.round(28 * root.d)
                color: OverlayLook.colFaint
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("No media")
                color: OverlayLook.colFaint
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeMeta
            }
        }

        ColumnLayout {
            anchors.fill: parent
            visible: music.hasPlayer
            spacing: Math.round(10 * root.d)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(12 * root.d)
                Rectangle {
                    implicitWidth: Math.round(72 * root.d)
                    implicitHeight: implicitWidth
                    radius: OverlayLook.roundingSmall
                    color: OverlayLook.colLayer2
                    clip: true
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "music_note"
                        iconSize: Math.round(28 * root.d)
                        color: OverlayLook.colFaint
                    }
                    StyledImage {
                        id: cover
                        anchors.fill: parent
                        visible: MediaArtwork.displaySource !== "" && cover.status === Image.Ready
                        source: MediaArtwork.displaySource
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(2 * root.d)
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: StringUtils.cleanMusicTitle(MprisController.titleOf(music.player)) || Translation.tr("No media")
                        color: OverlayLook.colOnLayer1
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeLabel
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        visible: text.length > 0
                        text: MprisController.artistOf(music.player) || ""
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontMain
                        font.pixelSize: OverlayLook.typeMeta
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: music.length > 0
                spacing: Math.round(4 * root.d)
                OverlaySlider {
                    Layout.fillWidth: true
                    visible: music.seekable
                    stepSize: 0.001
                    value: Math.max(0, Math.min(1, music.position / Math.max(1, music.length)))
                    onMoved: v => music.heldFraction = v
                    onCommitted: v => {
                        MprisController.seek(music.player, v * music.length)
                        music.heldFraction = -1
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: !music.seekable
                    implicitHeight: Math.round(4 * root.d)
                    radius: height / 2
                    color: OverlayLook.colRecessed
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, music.position / Math.max(1, music.length)))
                        height: parent.height
                        radius: height / 2
                        color: OverlayLook.colPrimary
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: StringUtils.friendlyTimeForSeconds(music.shownPosition)
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(music.length)
                        color: OverlayLook.colSubtext
                        font.family: OverlayLook.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: OverlayLook.typeFootnote
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Math.round(12 * root.d)
                OverlayButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Math.round(38 * root.d)
                    glyph: "skip_previous"
                    filledGlyph: true
                    enabled: MprisController.canGoPrevious
                    tip: Translation.tr("Previous")
                    onClicked: MprisController.previous()
                }
                OverlayButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Math.round(48 * root.d)
                    strong: true
                    glyph: MprisController.isPlaying ? "pause" : "play_arrow"
                    glyphSize: Math.round(26 * root.d)
                    enabled: MprisController.canTogglePlaying
                    tip: MprisController.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                    onClicked: MprisController.togglePlaying()
                }
                OverlayButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Math.round(38 * root.d)
                    glyph: "skip_next"
                    filledGlyph: true
                    enabled: MprisController.canGoNext
                    tip: Translation.tr("Next")
                    onClicked: MprisController.next()
                }
            }
        }
    }
}
