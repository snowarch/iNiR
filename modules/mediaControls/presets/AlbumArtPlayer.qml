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
 * AlbumArtPlayer - Artwork-focused design with large cover art
 * Emphasizes album artwork with overlay controls
 */
Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.large
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
        color: "transparent"
        clip: true
        
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }
        
        // Full cover art background with blur
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            visible: playerBase.displayedArtFilePath !== ""
            
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.3
                blurMax: 32
                saturation: 0.5
            }
        }
        
        // Fallback color when no art
        Rectangle {
            anchors.fill: parent
            visible: !playerBase.downloaded
            color: Appearance.inirEverywhere 
                ? playerBase.inirLayer1
                : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 64
                color: Appearance.inirEverywhere 
                    ? playerBase.inirTextSecondary 
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
            }
        }
        
        // Dark gradient overlay for text visibility
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.6; color: ColorUtils.transparentize("black", 0.5) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize("black", 0.2) }
            }
        }
        
        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(playerBase.artDominantColor, 0.3)
        }
        
        // Controls overlay at bottom
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            spacing: 8
            
            // Title & Artist
            PlayerInfo {
                Layout.fillWidth: true
                title: playerBase.effectiveTitle
                artist: playerBase.effectiveArtist
                titleColor: "white"
                artistColor: ColorUtils.transparentize("white", 0.3)
                titleSize: Appearance.font.pixelSize.larger
                artistSize: Appearance.font.pixelSize.normal
            }
            
            // Progress bar
            PlayerProgress {
                Layout.fillWidth: true
                implicitHeight: 18
                position: playerBase.effectivePosition
                length: playerBase.effectiveLength
                canSeek: playerBase.effectiveCanSeek
                isPlaying: playerBase.effectiveIsPlaying
                highlightColor: "white"
                trackColor: ColorUtils.transparentize("white", 0.6)
                onSeekRequested: seconds => playerBase.seek(seconds)
            }
            
            // Time + controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                StyledText {
                    text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    color: "white"
                }
                
                Item { Layout.fillWidth: true }
                
                PlayerControls {
                    isPlaying: playerBase.effectiveIsPlaying
                    buttonSize: 36
                    playButtonSize: 48
                    iconSize: 24
                    playIconSize: 28
                    buttonRadius: Appearance.rounding.full
                    buttonColor: ColorUtils.transparentize("black", 0.5)
                    buttonHoverColor: ColorUtils.transparentize("black", 0.3)
                    buttonRippleColor: ColorUtils.transparentize("white", 0.5)
                    iconColor: "white"
                    playIconColor: "white"
                    onPreviousClicked: playerBase.previous()
                    onPlayPauseClicked: playerBase.togglePlaying()
                    onNextClicked: playerBase.next()
                }
                
                Item { Layout.fillWidth: true }
                
                StyledText {
                    text: StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    color: "white"
                }
            }
        }
    }
}
