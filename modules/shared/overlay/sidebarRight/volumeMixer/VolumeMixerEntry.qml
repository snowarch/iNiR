import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Rectangle {
    id: root
    required property PwNode node
    // Flat: a row of a dialog that is already a card (Material's sidebar); otherwise a card of its own (the overlay).
    property bool flat: false
    // A stream that records: its mute glyph is a microphone.
    property bool capture: false
    readonly property bool muted: root.node?.audio?.muted ?? false

    function setVolume(value: real): void {
        const clamped = Math.max(0, Math.min(slider.to, value))
        if (root.node === Audio.sink) {
            Audio.setSinkVolume(clamped)
        } else if (root.node === Audio.source) {
            Audio.setSourceVolume(clamped)
        } else if (root.node?.audio) {
            root.node.audio.volume = clamped
        }
    }

    function stepVolume(delta: real): void {
        root.setVolume((root.node?.audio?.volume ?? 0) + delta)
    }

    PwObjectTracker {
        objects: [root.node]
    }

    implicitHeight: rowLayout.implicitHeight + (root.flat ? 0 : Appearance.sizes.spacingMedium * 2)
    radius: Appearance.rounding.small
    color: root.flat ? "transparent" : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colLayer2

    RowLayout {
        id: rowLayout
        anchors {
            fill: parent
            margins: root.flat ? 0 : Appearance.sizes.spacingMedium
        }
        spacing: root.flat ? 6 : Appearance.sizes.spacingMedium

        Rectangle {
            Layout.preferredWidth: root.flat ? 36 : 40
            Layout.preferredHeight: root.flat ? 36 : 40
            radius: Appearance.rounding.small
            color: root.flat ? "transparent" : Appearance.colors.colLayer3

            Image {
                anchors.centerIn: parent
                sourceSize.width: root.flat ? 36 : 24
                sourceSize.height: root.flat ? 36 : 24
                opacity: root.muted ? 0.5 : 1
                source: root.node ? MprisController.streamIconSource(root.node, "image-missing") : ""
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.flat ? -4 : 4

            RowLayout {
                Layout.fillWidth: true
                
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.flat ? Appearance.colMetadataText : Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    text: {
                        if (!root.node)
                            return ""
                        const app = MprisController.streamDisplayName(root.node)
                        const detail = MprisController.streamDetail?.(root.node) ?? ""
                        return detail.length > 0 ? `${app} • ${detail}` : app
                    }
                }
                
                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.features: { "tnum": 1 }
                    color: root.muted ? Appearance.colors.colError : Appearance.colors.colSubtext
                    text: root.muted ? Translation.tr("Muted") : Math.round((root.node?.audio.volume ?? 0) * 100) + "%"
                }
            }

            StyledSlider {
                id: slider
                Layout.fillWidth: true
                opacity: root.muted ? 0.45 : 1
                configuration: StyledSlider.Configuration.S
                property real modelValue: root.node?.audio.volume ?? 0
                to: (root.node === Audio.sink) ? 1.5 : 1

                Binding {
                    target: slider
                    property: "value"
                    value: slider.modelValue
                    when: !slider.pressed && !slider._userInteracting
                }
                onMoved: root.setVolume(value)
            }
        }

        RippleButton {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            buttonRadius: Appearance.rounding.full
            Layout.alignment: Qt.AlignVCenter
            colBackground: root.muted ? Appearance.colors.colErrorContainer : "transparent"
            colBackgroundHover: root.muted ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer3Hover
            colRipple: Appearance.colors.colLayer3Active
            onClicked: if (root.node?.audio) root.node.audio.muted = !root.node.audio.muted
            StyledToolTip {
                text: root.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
            }

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.capture ? (root.muted ? "mic_off" : "mic") : (root.muted ? "volume_off" : "volume_up")
                iconSize: Appearance.font.pixelSize.normal
                color: root.muted ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnLayer2
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            if (!root.node?.audio)
                return
            const verticalDelta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
            if (verticalDelta === 0)
                return
            root.stepVolume(verticalDelta > 0 ? 0.05 : -0.05)
            event.accepted = true
        }
    }
}
