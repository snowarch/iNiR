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
import "root:modules/common/functions/md5.js" as MD5

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: backdropWindow
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:inirBackdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"

        // Material inir backdrop config (independent)
        readonly property var inirBackdrop: Config.options?.background?.backdrop ?? {}

        readonly property int backdropBlurRadius: inirBackdrop.blurRadius ?? 32
        readonly property int thumbnailBlurStrength: Config.options?.background?.effects?.thumbnailBlurStrength ?? 50
        readonly property bool enableAnimatedBlur: inirBackdrop.enableAnimatedBlur ?? false
        readonly property int backdropDim: inirBackdrop.dim ?? 35
        readonly property real backdropSaturation: inirBackdrop.saturation ?? 0
        readonly property real backdropContrast: inirBackdrop.contrast ?? 0
        readonly property bool vignetteEnabled: inirBackdrop.vignetteEnabled ?? false
        readonly property real vignetteIntensity: inirBackdrop.vignetteIntensity ?? 0.5
        readonly property real vignetteRadius: inirBackdrop.vignetteRadius ?? 0.7
        readonly property bool useAuroraStyle: inirBackdrop.useAuroraStyle ?? false
        readonly property real auroraOverlayOpacity: inirBackdrop.auroraOverlayOpacity ?? 0.38
        readonly property bool enableAnimation: inirBackdrop.enableAnimation ?? false

        // Per-monitor main wallpaper path (resolves per-monitor when multi-monitor enabled)
        readonly property string _perMonitorMainPath: {
            if (WallpaperListener.multiMonitorEnabled) {
                const monName = WallpaperListener.getMonitorName(backdropWindow.modelData)
                const data = WallpaperListener.effectivePerMonitor[monName]
                if (data && data.path) return data.path
            }
            return Config.options?.background?.wallpaperPath ?? ""
        }

        // Per-monitor backdrop path (if multi-monitor enabled and monitor has custom backdrop)
        readonly property string _perMonitorBackdropPath: {
            if (WallpaperListener.multiMonitorEnabled) {
                const monName = WallpaperListener.getMonitorName(backdropWindow.modelData)
                const data = WallpaperListener.effectivePerMonitor[monName]
                if (data && data.backdropPath) return data.backdropPath
            }
            return ""
        }

        // Raw wallpaper path (before thumbnail substitution)
        readonly property string wallpaperPathRaw: {
            const useMain = inirBackdrop.useMainWallpaper ?? true;
            const mainPath = _perMonitorMainPath;
            // Per-monitor backdrop takes priority, then global backdrop, then main wallpaper
            if (!useMain) {
                const perMonBd = _perMonitorBackdropPath
                if (perMonBd) return perMonBd
                const globalBd = inirBackdrop.wallpaperPath || ""
                if (globalBd) return globalBd
            }
            return mainPath;
        }
        
        readonly property bool wallpaperIsVideo: {
            const lowerPath = wallpaperPathRaw.toLowerCase();
            return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov");
        }
        
        readonly property bool wallpaperIsGif: {
            return wallpaperPathRaw.toLowerCase().endsWith(".gif");
        }

        readonly property string effectiveWallpaperPath: wallpaperPathRaw

        // For ColorQuantizer: needs an image source (can't decode video files)
        // Uses first-frame cache for videos, config thumbnail as fallback
        readonly property string colorSourcePath: {
            if (wallpaperIsVideo) {
                const _dep = Wallpapers.videoFirstFrames // reactive binding
                const ff = Wallpapers.getVideoFirstFramePath(wallpaperPathRaw)
                // Cache-bust so ColorQuantizer reloads when the first frame appears.
                if (ff) return ff + "?ff=1"
                Wallpapers.ensureVideoFirstFrame(wallpaperPathRaw)
                return Wallpapers._videoThumbDir + "/" + MD5.hash(wallpaperPathRaw) + ".jpg?ff=0"
            }
            return wallpaperPathRaw
        }

        // Color quantizer for aurora-style adaptive colors
        ColorQuantizer {
            id: backdropColorQuantizer
            source: backdropWindow.colorSourcePath 
                ? (backdropWindow.colorSourcePath.startsWith("file://") 
                    ? backdropWindow.colorSourcePath 
                    : "file://" + backdropWindow.colorSourcePath)
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

            // Static Image (non-GIF, non-video images only)
            Image {
                id: wallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.effectiveWallpaperPath && !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo
                    ? (backdropWindow.effectiveWallpaperPath.startsWith("file://") 
                        ? backdropWindow.effectiveWallpaperPath 
                        : "file://" + backdropWindow.effectiveWallpaperPath)
                    : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: !backdropWindow.useAuroraStyle && !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo

                layer.enabled: Appearance.effectsEnabled && backdropWindow.backdropBlurRadius > 0 && !backdropWindow.useAuroraStyle
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: backdropWindow.backdropBlurRadius / 100.0
                    blurMax: 64
                    saturation: backdropWindow.backdropSaturation
                    contrast: backdropWindow.backdropContrast
                }
            }
            
            // Animated GIF wallpaper
            // Always loaded for GIFs: plays when animation enabled, frozen (first frame) when disabled
            AnimatedImage {
                id: gifWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperIsGif && backdropWindow.wallpaperPathRaw
                    ? (backdropWindow.wallpaperPathRaw.startsWith("file://")
                        ? backdropWindow.wallpaperPathRaw
                        : "file://" + backdropWindow.wallpaperPathRaw)
                    : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: !backdropWindow.useAuroraStyle && backdropWindow.wallpaperIsGif
                playing: visible && backdropWindow.enableAnimation

                layer.enabled: Appearance.effectsEnabled && backdropWindow.enableAnimatedBlur && backdropWindow.backdropBlurRadius > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: (backdropWindow.backdropBlurRadius * Math.max(0, Math.min(1, backdropWindow.thumbnailBlurStrength / 100))) / 100.0
                    blurMax: 64
                    saturation: backdropWindow.backdropSaturation
                    contrast: backdropWindow.backdropContrast
                }
            }

            // Video wallpaper
            // Always loaded for videos: plays when animation enabled, frozen (paused) when disabled
            Video {
                id: videoWallpaper
                anchors.fill: parent
                visible: !backdropWindow.useAuroraStyle && backdropWindow.wallpaperIsVideo
                source: {
                    if (!backdropWindow.wallpaperIsVideo) return "";
                    const path = backdropWindow.wallpaperPathRaw;
                    if (!path) return "";
                    return path.startsWith("file://") ? path : ("file://" + path);
                }
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true

                readonly property bool shouldPlay: backdropWindow.enableAnimation

                function pauseAndShowFirstFrame() {
                    pause()
                    seek(0) // Ensure first frame is displayed when paused
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && !shouldPlay) {
                        pauseAndShowFirstFrame()
                    }
                    if (playbackState === MediaPlayer.StoppedState && visible && shouldPlay) {
                        play()
                    }
                }

                onShouldPlayChanged: {
                    if (visible && backdropWindow.wallpaperIsVideo) {
                        if (shouldPlay) play()
                        else pauseAndShowFirstFrame()
                    }
                }

                onVisibleChanged: {
                    if (visible && backdropWindow.wallpaperIsVideo) {
                        if (shouldPlay) play()
                        else pauseAndShowFirstFrame()
                    } else {
                        pause()
                    }
                }

                layer.enabled: Appearance.effectsEnabled && backdropWindow.enableAnimatedBlur && backdropWindow.backdropBlurRadius > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: (backdropWindow.backdropBlurRadius * Math.max(0, Math.min(1, backdropWindow.thumbnailBlurStrength / 100))) / 100.0
                    blurMax: 64
                    saturation: backdropWindow.backdropSaturation
                    contrast: backdropWindow.backdropContrast
                }
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
                visible: backdropWindow.useAuroraStyle && status === Image.Ready && !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo

                layer.enabled: Appearance.effectsEnabled
                layer.effect: MultiEffect {
                    source: auroraWallpaper
                    anchors.fill: source
                    saturation: Appearance.angelEverywhere
                        ? Appearance.angel.blurSaturation
                        : (Appearance.effectsEnabled ? 0.2 : 0)
                    blurEnabled: Appearance.effectsEnabled
                    blurMax: 100
                    blur: Appearance.effectsEnabled ? 1 : 0
                }
            }
            
            // Aurora-style for GIFs
            AnimatedImage {
                id: auroraGifWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperIsGif ? gifWallpaper.source : ""
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: backdropWindow.useAuroraStyle && backdropWindow.wallpaperIsGif
                playing: visible && backdropWindow.enableAnimation

                layer.enabled: Appearance.effectsEnabled && backdropWindow.enableAnimatedBlur
                layer.effect: MultiEffect {
                    source: auroraGifWallpaper
                    anchors.fill: source
                    saturation: Appearance.angelEverywhere
                        ? Appearance.angel.blurSaturation
                        : (Appearance.effectsEnabled ? 0.2 : 0)
                    blurEnabled: Appearance.effectsEnabled
                    blurMax: 100
                    blur: Appearance.effectsEnabled ? 1 : 0
                }
            }

            // Aurora-style for Videos
            Video {
                id: auroraVideoWallpaper
                anchors.fill: parent
                visible: backdropWindow.useAuroraStyle && backdropWindow.wallpaperIsVideo
                source: videoWallpaper.source
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true

                readonly property bool shouldPlay: backdropWindow.enableAnimation

                function pauseAndShowFirstFrame() {
                    pause()
                    seek(0)
                }

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.PlayingState && !shouldPlay) {
                        pauseAndShowFirstFrame()
                    }
                    if (playbackState === MediaPlayer.StoppedState && visible && shouldPlay) {
                        play()
                    }
                }

                onShouldPlayChanged: {
                    if (visible && backdropWindow.wallpaperIsVideo) {
                        if (shouldPlay) play()
                        else pauseAndShowFirstFrame()
                    }
                }

                onVisibleChanged: {
                    if (visible && backdropWindow.wallpaperIsVideo) {
                        if (shouldPlay) play()
                        else pauseAndShowFirstFrame()
                    } else {
                        pause()
                    }
                }

                layer.enabled: Appearance.effectsEnabled && backdropWindow.enableAnimatedBlur
                layer.effect: MultiEffect {
                    source: auroraVideoWallpaper
                    anchors.fill: source
                    saturation: Appearance.angelEverywhere
                        ? Appearance.angel.blurSaturation
                        : (Appearance.effectsEnabled ? 0.2 : 0)
                    blurEnabled: Appearance.effectsEnabled
                    blurMax: 100
                    blur: Appearance.effectsEnabled ? 1 : 0
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
                readonly property bool isVertical: Config.options?.bar?.vertical ?? false
                readonly property bool isBarAtTop: !isVertical && !(Config.options?.bar?.bottom ?? false)
                readonly property bool isBarAtLeft: isVertical && !(Config.options?.bar?.bottom ?? false)
                readonly property bool barVignetteEnabled: Config.options?.bar?.vignette?.enabled ?? false
                readonly property real barVignetteIntensity: Config.options?.bar?.vignette?.intensity ?? 0.6
                readonly property real barVignetteRadius: Config.options?.bar?.vignette?.radius ?? 0.5

                anchors {
                    left: isVertical ? (isBarAtLeft ? parent.left : undefined) : parent.left
                    right: isVertical ? (isBarAtLeft ? undefined : parent.right) : parent.right
                    top: isVertical ? parent.top : (isBarAtTop ? parent.top : undefined)
                    bottom: isVertical ? parent.bottom : (isBarAtTop ? undefined : parent.bottom)
                }

                width: isVertical ? Math.max(200, backdropWindow.modelData.width * barVignetteRadius) : undefined
                height: isVertical ? undefined : Math.max(200, backdropWindow.modelData.height * barVignetteRadius)
                visible: barVignetteEnabled
                
                gradient: Gradient {
                    orientation: barVignette.isVertical ? Gradient.Horizontal : Gradient.Vertical
                    
                    GradientStop { 
                        position: 0.0
                        color: (barVignette.isBarAtTop || barVignette.isBarAtLeft)
                            ? Qt.rgba(0, 0, 0, barVignette.barVignetteIntensity)
                            : "transparent"
                    }
                    GradientStop { 
                        position: barVignette.barVignetteRadius
                        color: "transparent"
                    }
                    GradientStop { 
                        position: 1.0
                        color: (barVignette.isBarAtTop || barVignette.isBarAtLeft)
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
