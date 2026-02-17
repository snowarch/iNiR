pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.mediaControls.components

/**
 * MinimalPlayer - Minimalist design
 * Clean and simple, focuses on essentials
 */
Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
    property real screenX: 0
    property real screenY: 0
    
    PlayerBase {
        id: playerBase
        player: root.player
    }
    
    property QtObject blendedColors: AdaptedMaterialScheme { color: playerBase.artDominantColor }
    
    StyledRectangularShadow { 
        target: card
        visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
    }
    
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        color: Appearance.inirEverywhere ? playerBase.inirLayer1
             : Appearance.auroraEverywhere ? ColorUtils.transparentize(
                 blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7
               )
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        clip: true
        
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }
        
        // Subtle visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 25
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(playerBase.artDominantColor, 0.5)
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            
            // Small artwork
            PlayerArtwork {
                Layout.preferredWidth: 70
                Layout.preferredHeight: 70
                Layout.alignment: Qt.AlignVCenter
                artSource: playerBase.displayedArtFilePath
                downloaded: playerBase.downloaded
                artRadius: Appearance.inirEverywhere 
                    ? Appearance.inir.roundingSmall 
                    : Appearance.rounding.small
                placeholderColor: Appearance.inirEverywhere 
                    ? playerBase.inirLayer2 
                    : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                iconColor: Appearance.inirEverywhere 
                    ? playerBase.inirTextSecondary 
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                iconSize: 26
                enableBlurTransition: false
            }
            
            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                
                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(playerBase.effectiveTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere 
                        ? playerBase.inirText 
                        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: 6
                }
                
                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: playerBase.effectiveArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.inirEverywhere 
                        ? playerBase.inirTextSecondary 
                        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    elide: Text.ElideRight
                    visible: text !== ""
                }
                
                Item { Layout.fillHeight: true }
                
                // Progress bar
                PlayerProgress {
                    Layout.fillWidth: true
                    implicitHeight: 14
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: Appearance.inirEverywhere 
                        ? playerBase.inirPrimary
                        : Appearance.auroraEverywhere 
                            ? Appearance.colors.colPrimary
                            : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                    trackColor: Appearance.inirEverywhere 
                        ? playerBase.inirLayer2
                        : Appearance.auroraEverywhere 
                            ? Appearance.aurora.colElevatedSurface
                            : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    enableWavy: false
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }
                
                // Controls + time
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    PlayerControls {
                        buttonSize: 28
                        playButtonSize: 36
                        iconSize: 18
                        playIconSize: 20
                        isPlaying: playerBase.effectiveIsPlaying
                        buttonRadius: Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : Appearance.rounding.full
                        buttonHoverColor: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere 
                                ? Appearance.aurora.colSubSurface
                                : ColorUtils.transparentize(
                                    blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5
                                  )
                        buttonRippleColor: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere 
                                ? Appearance.aurora.colSubSurfaceActive
                                : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        iconColor: Appearance.inirEverywhere 
                            ? playerBase.inirText
                            : Appearance.auroraEverywhere 
                                ? Appearance.colors.colOnLayer0
                                : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        playIconColor: Appearance.inirEverywhere 
                            ? playerBase.inirPrimary
                            : Appearance.auroraEverywhere 
                                ? Appearance.colors.colOnLayer0
                                : Appearance.colors.colOnLayer1
                        onPreviousClicked: playerBase.previous()
                        onPlayPauseClicked: playerBase.togglePlaying()
                        onNextClicked: playerBase.next()
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Time display
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition) 
                            + " / " 
                            + StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere 
                            ? playerBase.inirTextSecondary 
                            : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    }
                }
            }
        }
    }
}
