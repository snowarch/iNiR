import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: card.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
             : Appearance.colors.colLayer0
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : Appearance.auroraEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder 
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        implicitHeight: contentRow.implicitHeight + 18

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 20
                topMargin: 9
                bottomMargin: 9
            }
            spacing: 12

            // Animated mic icon
            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: VoiceSearch.transcribing ? "cloud_upload" : "mic"
                    iconSize: 24
                    fill: 1
                    color: Appearance.colors.colPrimary

                    // Pulse animation while recording
                    SequentialAnimation on scale {
                        running: VoiceSearch.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.15; duration: 400; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                    }
                }
            }

            // Status text
            StyledText {
                Layout.fillWidth: true
                text: VoiceSearch.transcribing 
                    ? Translation.tr("Transcribing...")
                    : Translation.tr("Listening...")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
            }

            // Animated dots for recording
            Row {
                spacing: 4
                visible: VoiceSearch.recording

                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        radius: 3
                        color: Appearance.colors.colPrimary

                        SequentialAnimation on opacity {
                            running: VoiceSearch.recording
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 150 }
                            NumberAnimation { to: 1; duration: 250 }
                            NumberAnimation { to: 0.3; duration: 250 }
                            PauseAnimation { duration: (2 - index) * 150 }
                        }
                    }
                }
            }

            // Spinner for transcribing
            Item {
                visible: VoiceSearch.transcribing
                implicitWidth: 20
                implicitHeight: 20
                
                CircularProgress {
                    anchors.fill: parent
                    lineWidth: 2
                    value: 0.25
                    colPrimary: Appearance.colors.colPrimary
                    colSecondary: Appearance.colors.colLayer1
                    
                    RotationAnimation on rotation {
                        running: VoiceSearch.transcribing
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
            }
        }
    }
}
