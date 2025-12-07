import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var track: MprisController.activeTrack
    property bool isPlaying: MprisController.isPlaying

    implicitWidth: 340 + 2 * Appearance.sizes.elevationMargin
    implicitHeight: mediaCard.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow {
        target: mediaCard
    }

    Rectangle {
        id: mediaCard
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer0
        implicitHeight: contentRow.implicitHeight + 24

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 12

            // Album art
            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer1
                clip: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: root.track?.artUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: albumArt.width
                            height: albumArt.height
                            radius: Appearance.rounding.small
                        }
                    }
                }

                // Fallback icon
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colSubtext
                    visible: albumArt.status !== Image.Ready
                }
            }

            // Track info + controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: root.track?.title ?? Translation.tr("No media playing")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.track?.artist ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                Item { Layout.fillHeight: true }

                // Controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        enabled: MprisController.canGoPrevious
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        onClicked: MprisController.previous()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            iconSize: 18
                            color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        enabled: MprisController.canTogglePlaying
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        onClicked: MprisController.togglePlaying()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: 18
                            color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        enabled: MprisController.canGoNext
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        onClicked: MprisController.next()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 18
                            color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                        }
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
