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
    property real radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.large
    Behavior on radius {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    property real screenX: 0
    property real screenY: 0
    
    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    PlayerBase {
        id: playerBase
        player: root.player
    }
    
    // Theme seed for the whole player. Defaults to the album-art colour (floating popup
    // keeps that). Desktop host overrides it with the wallpaper seed for cohesion.
    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.themeSourceColor }
    
    StyledRectangularShadow { 
        target: card
        visible: !Appearance.zzzEverywhere
            && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
    }
    
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : root.radius
        color: Appearance.zzzEverywhere ? Appearance.zzz.paper : "transparent"
        border.width: Appearance.zzzEverywhere ? Appearance.zzz.borderThick : 0
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : "transparent"
        // Organic morph on style/shape switch (organic-transitions)
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
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
            cache: false
            smooth: true
            mipmap: true
            visible: playerBase.displayedArtFilePath !== ""
            
            opacity: Appearance.zzzEverywhere ? 0.32 : 1
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.zzzEverywhere ? 0.2 : 0.3
                blurMax: 32
                saturation: Appearance.zzzEverywhere ? 0.32 : 0.5
            }
        }
        
        // Fallback color when no art
        Rectangle {
            anchors.fill: parent
            visible: !playerBase.downloaded
            color: Appearance.inirEverywhere 
                ? playerBase.inirLayer1
                : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 64
                color: Appearance.inirEverywhere 
                    ? playerBase.inirTextSecondary 
                    : Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
            }
        }

        ZzzTechFrame {
            anchors.fill: parent
            visible: Appearance.zzzEverywhere
            label: "NOW PLAYING"
            index: "ART"
            accentColor: blendedColors?.colPrimary ?? Appearance.zzz.accent
            margin: 12
            showTicks: false
        }

        // Dark gradient overlay for text visibility
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop {
                    position: 0.6
                    color: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.bg0, 0.58) : ColorUtils.transparentize("black", 0.5)
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                }
                GradientStop {
                    position: 1.0
                    color: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.bg0, 0.24) : ColorUtils.transparentize("black", 0.2)
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                }
            }
        }
        
        // Visualizer overlay
        WaveVisualizer {
            visible: root.vizType === "wave" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 40
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            color: ColorUtils.transparentize(root.themeSourceColor, 0.3)
        }
        CavaVisualizer {
            visible: root.vizType === "bars" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 40
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000; smoothing: 2
            barCount: 32; barSpacing: 2; barRadius: 2; barMinHeight: 1
            colorLow: ColorUtils.transparentize(root.themeSourceColor, 0.3)
            colorMed: ColorUtils.transparentize(root.themeSourceColor, 0.1)
            colorHigh: root.themeSourceColor
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
                titleColor: Appearance.zzzEverywhere ? Appearance.zzz.ink : "white"
                artistColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : ColorUtils.transparentize("white", 0.3)
                titleSize: Appearance.font.pixelSize.larger
                artistSize: Appearance.font.pixelSize.normal
                slideDirection: playerBase.slideDirection
            }
            
            // Progress bar
            PlayerProgress {
                Layout.fillWidth: true
                implicitHeight: 18
                position: playerBase.effectivePosition
                length: playerBase.effectiveLength
                canSeek: playerBase.effectiveCanSeek
                isPlaying: playerBase.effectiveIsPlaying
                highlightColor: Appearance.zzzEverywhere ? (blendedColors?.colPrimary ?? Appearance.zzz.accent) : "white"
                trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack : ColorUtils.transparentize("white", 0.6)
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
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : "white"
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                PlayerControls {
                    canGoPrevious: playerBase.effectiveCanGoPrevious
                    canGoNext: playerBase.effectiveCanGoNext
                    isPlaying: playerBase.effectiveIsPlaying
                    buttonSize: 36
                    playButtonSize: 48
                    iconSize: 24
                    playIconSize: 28
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
                    buttonColor: Appearance.zzzEverywhere ? Appearance.zzz.paperAlt : ColorUtils.transparentize("black", 0.5)
                    buttonHoverColor: Appearance.zzzEverywhere ? ColorUtils.mix(Appearance.zzz.paperAlt, Appearance.zzz.signal, 0.92) : ColorUtils.transparentize("black", 0.3)
                    buttonRippleColor: Appearance.zzzEverywhere ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.32) : ColorUtils.transparentize("white", 0.5)
                    iconColor: Appearance.zzzEverywhere ? Appearance.zzz.ink : "white"
                    playIconColor: Appearance.zzzEverywhere ? (blendedColors?.colPrimary ?? Appearance.zzz.accent) : "white"
                    onPreviousClicked: playerBase.previous()
                    onPlayPauseClicked: playerBase.togglePlaying()
                    onNextClicked: playerBase.next()
                }
                
                Item { Layout.fillWidth: true }
                
                StyledText {
                    text: StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink : "white"
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
        }
    }
}
