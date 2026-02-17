pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
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
 * CompactPlayer - Compact design with smaller artwork
 * Ideal for limited space, similar to sidebar player
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
        
        // Background art
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: Appearance.inirEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.25 : 0.5)
            visible: playerBase.displayedArtFilePath !== ""
            
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.inirEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: Appearance.inirEverywhere ? 0.1 : 0.3
            }
        }
        
        // Gradient overlay for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { 
                    position: 0.35
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3
                    )
                }
                GradientStop { 
                    position: 1.0
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15
                    )
                }
            }
        }
        
        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 30
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(playerBase.artDominantColor, 0.4)
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            // Compact cover art
            PlayerArtwork {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 110
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
            }
            
            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2
                
                // Title & Artist
                PlayerInfo {
                    Layout.fillWidth: true
                    title: playerBase.effectiveTitle
                    artist: playerBase.effectiveArtist
                    titleColor: Appearance.inirEverywhere 
                        ? playerBase.inirText 
                        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    artistColor: Appearance.inirEverywhere 
                        ? playerBase.inirTextSecondary 
                        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    titleSize: Appearance.font.pixelSize.normal
                    artistSize: Appearance.font.pixelSize.smaller
                }
                
                Item { Layout.fillHeight: true }
                
                // Progress bar
                PlayerProgress {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: Appearance.inirEverywhere 
                        ? playerBase.inirPrimary
                        : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                    trackColor: Appearance.inirEverywhere 
                        ? playerBase.inirLayer2
                        : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }
                
                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere 
                            ? playerBase.inirText 
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    PlayerControls {
                        isPlaying: playerBase.effectiveIsPlaying
                        buttonRadius: Appearance.inirEverywhere 
                            ? Appearance.inir.roundingSmall 
                            : Appearance.rounding.full
                        buttonHoverColor: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Hover
                            : ColorUtils.transparentize(
                                blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5
                              )
                        buttonRippleColor: Appearance.inirEverywhere 
                            ? Appearance.inir.colLayer2Active
                            : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        iconColor: Appearance.inirEverywhere 
                            ? playerBase.inirText
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        playIconColor: Appearance.inirEverywhere 
                            ? playerBase.inirPrimary
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        onPreviousClicked: playerBase.previous()
                        onPlayPauseClicked: playerBase.togglePlaying()
                        onNextClicked: playerBase.next()
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.inirEverywhere 
                            ? playerBase.inirText 
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                }
            }
        }
    }
}
