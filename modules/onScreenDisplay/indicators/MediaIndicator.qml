import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root

    property var track: MprisController.activeTrack
    property bool isPlaying: MprisController.isPlaying
    readonly property string effectiveTitle: MprisController.isYtMusicActive ? YtMusic.currentTitle : (track?.title ?? "")
    readonly property string effectiveArtist: MprisController.isYtMusicActive ? YtMusic.currentArtist : (track?.artist ?? "")

    implicitWidth: mediaCard.implicitWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: mediaCard.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow {
        target: mediaCard
    }

    GlassBackground {
        id: mediaCard
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
        fallbackColor: Appearance.colors.colLayer0
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: auroraEverywhere || inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : Appearance.colors.colLayer0Border
        implicitWidth: contentRow.implicitWidth + 24
        implicitHeight: contentRow.implicitHeight + 24

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 12

            // Album art — fills height, stays square (BarMediaPlayerItem pattern)
            Rectangle {
                Layout.fillHeight: true
                implicitWidth: height
                radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                color: Appearance.colors.colLayer1
                clip: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: MediaArtwork.displaySource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: MediaArtwork.ready && status === Image.Ready

                    layer.enabled: true
                    layer.effect: GE.OpacityMask {
                        maskSource: Rectangle {
                            width: albumArt.width
                            height: albumArt.height
                            radius: Appearance.rounding.small
                        }
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    iconSize: Appearance.font.pixelSize.huge
                    color: Appearance.colors.colSubtext
                    visible: !MediaArtwork.ready || albumArt.status !== Image.Ready
                }
            }

            // Track info + controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: root.effectiveTitle || Translation.tr("No media playing")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.effectiveArtist
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }

                Item { Layout.fillHeight: true }

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
                            fill: 1
                            color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                        }
                    }

                    RippleButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        buttonRadius: Appearance.rounding.full
                        enabled: MprisController.canTogglePlaying
                        colBackground: Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        onClicked: MprisController.togglePlaying()

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            iconSize: 18
                            fill: 1
                            color: parent.enabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
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
                            fill: 1
                            color: parent.enabled ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                        }
                    }

                }
            }
        }
    }
}
