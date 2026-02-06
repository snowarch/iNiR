pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.common.models
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: backdropWindow
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:iiBackdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"

        // Material ii backdrop config (independent)
        readonly property var iiBackdrop: Config.options?.background?.backdrop ?? {}
        
        readonly property int backdropBlurRadius: iiBackdrop.blurRadius ?? 32
        readonly property int thumbnailBlurStrength: Config.options?.background?.effects?.thumbnailBlurStrength ?? 50
        readonly property int backdropDim: iiBackdrop.dim ?? 35
        readonly property real backdropSaturation: iiBackdrop.saturation ?? 0
        readonly property real backdropContrast: iiBackdrop.contrast ?? 0
        readonly property bool vignetteEnabled: iiBackdrop.vignetteEnabled ?? false
        readonly property real vignetteIntensity: iiBackdrop.vignetteIntensity ?? 0.5
        readonly property real vignetteRadius: iiBackdrop.vignetteRadius ?? 0.7
        readonly property bool useAuroraStyle: iiBackdrop.useAuroraStyle ?? false
        readonly property real auroraOverlayOpacity: iiBackdrop.auroraOverlayOpacity ?? 0.38
        readonly property bool enableAnimation: iiBackdrop.enableAnimation ?? false

        // Raw wallpaper path (before thumbnail substitution)
        readonly property string wallpaperPathRaw: {
            const useMain = iiBackdrop.useMainWallpaper ?? true;
            const mainPath = Config.options?.background?.wallpaperPath ?? "";
            const backdropPath = iiBackdrop.wallpaperPath || "";
            return useMain ? mainPath : (backdropPath || mainPath);
        }
        
        readonly property bool wallpaperIsVideo: {
            const lowerPath = wallpaperPathRaw.toLowerCase();
            return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov");
        }
        
        readonly property bool wallpaperIsGif: {
            return wallpaperPathRaw.toLowerCase().endsWith(".gif");
        }

        // Effective path: returns thumbnail if animation is disabled, otherwise raw path
        readonly property string effectiveWallpaperPath: {
            const selectedPath = wallpaperPathRaw;
            
            // If animation is enabled, use raw path for videos/GIFs
            if (backdropWindow.enableAnimation && (backdropWindow.wallpaperIsVideo || backdropWindow.wallpaperIsGif)) {
                return selectedPath;
            }
            
            // If animation is disabled, use thumbnail for videos/GIFs
            if (backdropWindow.wallpaperIsVideo || backdropWindow.wallpaperIsGif) {
                const backdropThumbnail = iiBackdrop.thumbnailPath ?? "";
                const mainThumbnail = Config.options?.background?.thumbnailPath ?? "";
                return backdropThumbnail || mainThumbnail || selectedPath;
            }
            
            return selectedPath;
        }

        // Color quantizer for aurora-style adaptive colors
        ColorQuantizer {
            id: backdropColorQuantizer
            source: backdropWindow.effectiveWallpaperPath 
                ? (backdropWindow.effectiveWallpaperPath.startsWith("file://") 
                    ? backdropWindow.effectiveWallpaperPath 
                    : "file://" + backdropWindow.effectiveWallpaperPath)
                : ""
            depth: 0
            rescaleSize: 10
        }

        readonly property color wallpaperDominantColor: (backdropColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary)
        readonly property QtObject blendedColors: AdaptedMaterialScheme {
            color: CF.ColorUtils.mix(backdropWindow.wallpaperDominantColor, Appearance.colors.colPrimaryContainer, 0.8) || Appearance.m3colors.m3secondaryContainer
        }

        Item {
            anchors.fill: parent

            // Static Image (for non-animated wallpapers)
            Image {
                id: wallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.effectiveWallpaperPath && !backdropWindow.wallpaperIsGif && !(backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo)
                    ? (backdropWindow.effectiveWallpaperPath.startsWith("file://") 
                        ? backdropWindow.effectiveWallpaperPath 
                        : "file://" + backdropWindow.effectiveWallpaperPath)
                    : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: !backdropWindow.useAuroraStyle && !backdropWindow.wallpaperIsGif && !(backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo)

                layer.enabled: Appearance.effectsEnabled && backdropWindow.backdropBlurRadius > 0 && !backdropWindow.useAuroraStyle && !backdropWindow.wallpaperIsGif
                layer.effect: MultiEffect {
                    blurEnabled: true
                    // For videos/GIFs (when using thumbnails), apply thumbnailBlurStrength
                    blur: (backdropWindow.wallpaperIsVideo || backdropWindow.wallpaperIsGif)
                        ? (backdropWindow.backdropBlurRadius * Math.max(0, Math.min(1, backdropWindow.thumbnailBlurStrength / 100))) / 100.0
                        : backdropWindow.backdropBlurRadius / 100.0
                    blurMax: 64
                    saturation: backdropWindow.backdropSaturation
                    contrast: backdropWindow.backdropContrast
                }
            }
            
            // Animated GIF support (when enableAnimation is true)
            AnimatedImage {
                id: gifWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.enableAnimation && backdropWindow.wallpaperIsGif && backdropWindow.effectiveWallpaperPath
                    ? (backdropWindow.effectiveWallpaperPath.startsWith("file://") 
                        ? backdropWindow.effectiveWallpaperPath 
                        : "file://" + backdropWindow.effectiveWallpaperPath)
                    : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: !backdropWindow.useAuroraStyle && backdropWindow.enableAnimation && backdropWindow.wallpaperIsGif
                playing: visible
                
                // Note: Blur is disabled for GIFs to maintain performance
            }

            // Video wallpaper support (when enableAnimation is true)
            Video {
                id: videoWallpaper
                anchors.fill: parent
                visible: !backdropWindow.useAuroraStyle && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo
                source: {
                    if (!backdropWindow.enableAnimation || !backdropWindow.wallpaperIsVideo) return "";
                    const path = backdropWindow.effectiveWallpaperPath;
                    if (!path) return "";
                    return path.startsWith("file://") ? path : ("file://" + path);
                }
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true
                
                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.StoppedState && visible && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo) {
                        play()
                    }
                }
                
                onVisibleChanged: {
                    if (visible && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo) {
                        play()
                    } else {
                        pause()
                    }
                }
                
                // Note: Blur is disabled for videos to maintain performance
            }

            // Aurora-style blur (same as sidebars)
            Image {
                id: auroraWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperIsGif ? gifWallpaper.source : wallpaper.source
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: backdropWindow.useAuroraStyle && status === Image.Ready && !backdropWindow.wallpaperIsGif && !(backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo)

                layer.enabled: Appearance.effectsEnabled
                layer.effect: StyledBlurEffect {
                    source: auroraWallpaper
                }
            }
            
            // Aurora-style for GIFs (without blur to maintain performance)
            AnimatedImage {
                id: auroraGifWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.enableAnimation && backdropWindow.wallpaperIsGif ? gifWallpaper.source : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: backdropWindow.useAuroraStyle && backdropWindow.enableAnimation && backdropWindow.wallpaperIsGif
                playing: visible
            }

            // Aurora-style for Videos (without blur to maintain performance)
            Video {
                id: auroraVideoWallpaper
                anchors.fill: parent
                visible: backdropWindow.useAuroraStyle && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo
                source: videoWallpaper.source
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true
                
                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.StoppedState && visible && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo) {
                        play()
                    }
                }
                
                onVisibleChanged: {
                    if (visible && backdropWindow.enableAnimation && backdropWindow.wallpaperIsVideo) {
                        play()
                    } else {
                        pause()
                    }
                }
            }

            // Aurora-style color overlay
            Rectangle {
                anchors.fill: parent
                visible: backdropWindow.useAuroraStyle
                color: CF.ColorUtils.transparentize(
                    (backdropWindow.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0Base), 
                    backdropWindow.auroraOverlayOpacity
                )
            }

            // Legacy dim overlay (non-aurora)
            Rectangle {
                anchors.fill: parent
                visible: !backdropWindow.useAuroraStyle
                color: "black"
                opacity: backdropWindow.backdropDim / 100.0
            }

            // Vignette effect at bar level
            Rectangle {
                id: barVignette
                anchors {
                    left: parent.left
                    right: parent.right
                    top: isBarAtTop ? parent.top : undefined
                    bottom: isBarAtTop ? undefined : parent.bottom
                }
                
                readonly property bool isBarAtTop: !(Config.options?.bar?.bottom ?? false)
                readonly property bool barVignetteEnabled: Config.options?.bar?.vignette?.enabled ?? false
                readonly property real barVignetteIntensity: Config.options?.bar?.vignette?.intensity ?? 0.6
                readonly property real barVignetteRadius: Config.options?.bar?.vignette?.radius ?? 0.5
                
                height: Math.max(200, backdropWindow.modelData.height * barVignetteRadius)
                visible: barVignetteEnabled
                
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    
                    GradientStop { 
                        position: 0.0
                        color: barVignette.isBarAtTop 
                            ? Qt.rgba(0, 0, 0, barVignette.barVignetteIntensity)
                            : "transparent"
                    }
                    GradientStop { 
                        position: barVignette.barVignetteRadius
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 1.0
                        color: barVignette.isBarAtTop
                            ? "transparent"
                            : Qt.rgba(0, 0, 0, barVignette.barVignetteIntensity)
                    }
                }
            }
            
            // Legacy vignette effect (bottom gradient)
            Rectangle {
                anchors.fill: parent
                visible: backdropWindow.vignetteEnabled
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: backdropWindow.vignetteRadius; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, backdropWindow.vignetteIntensity) }
                }
            }
        }
    }
}
