pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.overlay

// A call beside the game: mic and sound at a click, and the call's own volume against the game's while Discord
// (or a client of it) is talking.
StyledOverlayWidget {
    id: root
    resizable: false

    readonly property var clientPattern: /discord|vesktop|webcord|legcord|armcord|equibop|dorion/i
    function isClient(node: var): bool {
        const props = node?.properties ?? {}
        return root.clientPattern.test([props["application.process.binary"], props["application.name"], node?.name].join(" "))
    }
    readonly property var callNode: Audio.outputAppNodes.find(node => root.isClient(node)) ?? null
    readonly property bool inCall: Audio.inputAppNodes.some(node => root.isClient(node))
    readonly property bool micMuted: Audio.micMuted
    readonly property bool soundMuted: Audio.sink?.audio?.muted ?? false
    readonly property real callLevel: root.callNode?.audio?.volume ?? 0
    readonly property bool callMuted: root.callNode?.audio?.muted ?? false

    PwObjectTracker { objects: root.callNode ? [root.callNode] : [] }

    fact: root.inCall ? Translation.tr("In a call") : ""
    factColor: OverlayLook.colSuccess
    titlebarActionSymbol: "open_in_new"
    titlebarActionTooltip: Translation.tr("Open Discord")
    onTitlebarActionClicked: {
        GlobalStates.overlayOpen = false
        ShellExec.execCmd(Config.options?.apps?.discord ?? "discord")
    }

    contentItem: Item {
        anchors.fill: parent
        implicitWidth: Math.round(300 * root.d)
        implicitHeight: Math.round(156 * root.d)

        ColumnLayout {
            anchors.fill: parent
            spacing: Math.round(10 * root.d)

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(8 * root.d)
                VoiceTile {
                    glyph: root.micMuted ? "mic_off" : "mic"
                    label: Translation.tr("Microphone")
                    detail: root.micMuted ? Translation.tr("Muted") : (Audio.source ? Audio.friendlyDeviceName(Audio.source) : Translation.tr("On"))
                    toggled: root.micMuted
                    onClicked: Audio.toggleMicMute()
                }
                VoiceTile {
                    glyph: root.soundMuted ? "headset_off" : "headphones"
                    label: Translation.tr("Sound")
                    detail: root.soundMuted ? Translation.tr("Muted") : (Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : Translation.tr("On"))
                    toggled: root.soundMuted
                    enabled: Audio.sink?.audio !== undefined
                    onClicked: Audio.toggleMute()
                }
            }

            // The call against the game: only while Discord plays something.
            RowLayout {
                Layout.fillWidth: true
                visible: root.callNode !== null
                spacing: Math.round(8 * root.d)
                OverlayButton {
                    size: Math.round(28 * root.d)
                    glyph: root.callMuted ? "volume_off" : "record_voice_over"
                    tint: OverlayLook.colError
                    toggled: root.callMuted
                    tip: root.callMuted ? Translation.tr("Unmute") : Translation.tr("Mute")
                    onClicked: if (root.callNode?.audio) root.callNode.audio.muted = !root.callNode.audio.muted
                }
                StyledText {
                    text: Translation.tr("Call volume")
                    color: OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeMeta
                }
                OverlaySlider {
                    Layout.fillWidth: true
                    opacity: root.callMuted ? 0.45 : 1
                    value: root.callLevel
                    stepSize: 0.01
                    onMoved: value => { if (root.callNode?.audio) root.callNode.audio.volume = Math.max(0, Math.min(1, value)) }
                }
                StyledText {
                    Layout.preferredWidth: Math.round(34 * root.d)
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(root.callLevel * 100) + "%"
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: OverlayLook.typeMeta
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.callNode === null
                elide: Text.ElideRight
                text: Translation.tr("The call's volume shows here while Discord plays.")
                color: OverlayLook.colFaint
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeFootnote
            }
        }
    }

    // A switch drawn as a tile: red while it silences something.
    component VoiceTile: RippleButton {
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
        colBackgroundToggled: OverlayLook.colErrorContainer
        colBackgroundToggledHover: ColorUtils.mix(OverlayLook.colErrorContainer, OverlayLook.colOnErrorContainer, 0.9)
        colRippleToggled: ColorUtils.mix(OverlayLook.colErrorContainer, OverlayLook.colOnErrorContainer, 0.8)
        Accessible.role: Accessible.CheckBox
        Accessible.name: tile.label
        Accessible.checked: tile.toggled
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
                    color: tile.toggled ? OverlayLook.colOnErrorContainer : OverlayLook.colPrimary
                }
                Item { width: 1; height: Math.round(5 * root.d) }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.label
                    color: tile.toggled ? OverlayLook.colOnErrorContainer : OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeBody
                    font.weight: Font.DemiBold
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.detail
                    color: tile.toggled ? OverlayLook.colOnErrorContainer : OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeMeta
                }
            }
        }
    }
}
