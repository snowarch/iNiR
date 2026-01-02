import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overlay
import qs.services

StyledOverlayWidget {
    id: root
    title: Translation.tr("Discord")
    minimumWidth: 280
    minimumHeight: 140
    showCenterButton: true

    contentItem: OverlayBackground {
        id: bg
        radius: root.contentRadius
        property real padding: 8

        ColumnLayout {
            anchors {
                fill: parent
                margins: bg.padding
            }
            spacing: 10

            RowLayout {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: 10

                BigActionButton {
                    materialSymbol: "forum"
                    name: "Open Discord"
                    onClicked: {
                        GlobalStates.overlayOpen = false
                        const cmd = Config.options?.apps?.discord ?? "discord"
                        ShellExec.execCmd(cmd)
                    }
                }

                BigActionButton {
                    materialSymbol: (Audio.source?.audio?.muted ?? false) ? "mic_off" : "mic"
                    name: "Toggle mic (global)"
                    active: Audio.source?.audio?.muted ?? false
                    onClicked: {
                        if (Audio.source?.audio) {
                            Audio.toggleMicMute()
                        }
                    }
                }

                BigActionButton {
                    materialSymbol: (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
                    name: "Toggle deafen (global)"
                    active: Audio.sink?.audio?.muted ?? false
                    onClicked: {
                        if (Audio.sink?.audio) {
                            Audio.toggleMute()
                        }
                    }
                }
            }
        }
    }

    component BigActionButton: RippleButton {
        id: bigButton
        required property string materialSymbol
        required property string name
        // Para botones tipo toggle (mic/sink)
        property bool active: false

        implicitHeight: 66
        implicitWidth: 66
        buttonRadius: height / 2

        colBackground: Appearance.colors.colLayer3
        colBackgroundHover: Appearance.colors.colLayer3Hover
        colRipple: Appearance.colors.colLayer3Active

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: bigButton.materialSymbol
            iconSize: 28
            color: bigButton.active ? Appearance.colors.colError : Appearance.colors.colOnSurface
        }

        StyledToolTip {
            text: bigButton.name
        }
    }
}
