pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Wayland

Variants {
    id: root
    // Only create backdrop windows if enabled
    model: (Config.options?.waffles?.background?.backdrop?.enable ?? true) ? Quickshell.screens : []

    PanelWindow {
        id: backdropWindow
        required property var modelData

        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell:wBackdrop"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: "transparent"
        visible: !GameMode.shouldHidePanels

        // Multi-monitor wallpaper support
        readonly property string _perMonitorMainPath: {
            if (WallpaperListener.multiMonitorEnabled) {
                const monName = WallpaperListener.getMonitorName(backdropWindow.modelData)
                const data = WallpaperListener.effectivePerMonitor[monName]
                if (data && data.path) return data.path
            }
            return Config.options?.background?.wallpaperPath ?? ""
        }

        // Waffle backdrop config
        readonly property var wBackdrop: Config.options?.waffles?.background?.backdrop ?? {}

        readonly property int backdropBlurRadius: wBackdrop.blurRadius ?? 32
        readonly property int thumbnailBlurStrength: Config.options?.waffles?.background?.effects?.thumbnailBlurStrength ?? (Config.options?.background?.effects?.thumbnailBlurStrength ?? 50)
        readonly property bool enableAnimatedBlur: wBackdrop.enableAnimatedBlur ?? false
        readonly property int backdropDim: wBackdrop.dim ?? 35
        readonly property real backdropSaturation: (wBackdrop.saturation ?? 0) / 100.0
        readonly property real backdropContrast: (wBackdrop.contrast ?? 0) / 100.0
        readonly property bool vignetteEnabled: wBackdrop.vignetteEnabled ?? false
        readonly property real vignetteIntensity: wBackdrop.vignetteIntensity ?? 0.5
        readonly property real vignetteRadius: wBackdrop.vignetteRadius ?? 0.7
        readonly property bool enableAnimation: wBackdrop.enableAnimation ?? false

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
            const useBackdropOwn = !(wBackdrop.useMainWallpaper ?? true);
            if (useBackdropOwn) {
                // Per-monitor backdrop takes priority, then global backdrop
                const perMonBd = _perMonitorBackdropPath
                if (perMonBd) return perMonBd
                if (wBackdrop.wallpaperPath) return wBackdrop.wallpaperPath
            }
            const wBg = Config.options?.waffles?.background ?? {};
            if (wBg.useMainWallpaper ?? true) {
                return _perMonitorMainPath;
            }
            return wBg.wallpaperPath || _perMonitorMainPath;
        }
        
        readonly property bool wallpaperIsVideo: {
            const lowerPath = wallpaperPathRaw.toLowerCase();
            return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov");
        }
        
        readonly property bool wallpaperIsGif: {
            return wallpaperPathRaw.toLowerCase().endsWith(".gif");
        }

        readonly property string effectiveWallpaperPath: wallpaperPathRaw

        // Build proper file:// URL
        readonly property string wallpaperUrl: {
            const path = effectiveWallpaperPath;
            if (!path) return "";
            if (path.startsWith("file://")) return path;
            return "file://" + path;
        }

        Item {
            anchors.fill: parent
            clip: true

            // Blur edge compensation: MultiEffect fades at boundaries because the
            // Gaussian kernel has no pixels beyond the item edge. To fix this, all
            // wallpaper source items are oversized by blurMax (64px) on every side,
            // and this parent clips the result to exact screen bounds.
            readonly property int blurOverflow: 64

            // Static wallpaper with crossfade transitions (shares waffle workspace transition settings)
            WallpaperCrossfader {
                id: wallpaper
                anchors.fill: parent
                anchors.margins: -parent.blurOverflow
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperUrl && !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo
                    ? backdropWindow.wallpaperUrl
                    : ""
                sourceSize: Qt.size(backdropWindow.screen?.width ?? 1920, backdropWindow.screen?.height ?? 1080)
                visible: !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo
                // Use waffle transition settings
                transitionBaseDuration: Config.options?.waffles?.background?.transition?.duration ?? 800
                transitionType: Config.options?.waffles?.background?.transition?.type ?? "crossfade"
                transitionDirection: Config.options?.waffles?.background?.transition?.direction ?? "right"
                enableTransitions: Config.options?.waffles?.background?.transition?.enable ?? true
            }

            // Animated GIF wallpaper
            // Always loaded for GIFs: plays when animation enabled, frozen (first frame) when disabled
            AnimatedImage {
                id: gifWallpaper
                anchors.fill: parent
                anchors.margins: -parent.blurOverflow
                fillMode: Image.PreserveAspectCrop
                source: backdropWindow.wallpaperIsGif
                    ? (backdropWindow.wallpaperPathRaw.startsWith("file://")
                        ? backdropWindow.wallpaperPathRaw
                        : "file://" + backdropWindow.wallpaperPathRaw)
                    : ""
                asynchronous: true
                cache: false
                // No sourceSize for GIFs - let Qt handle native size for performance
                visible: backdropWindow.wallpaperIsGif
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
                anchors.margins: -parent.blurOverflow
                visible: backdropWindow.wallpaperIsVideo
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

                layer.enabled: Appearance.effectsEnabled && backdropWindow.enableAnimatedBlur && backdropWindow.backdropBlurRadius > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: (backdropWindow.backdropBlurRadius * Math.max(0, Math.min(1, backdropWindow.thumbnailBlurStrength / 100))) / 100.0
                    blurMax: 64
                    saturation: backdropWindow.backdropSaturation
                    contrast: backdropWindow.backdropContrast
                }
            }

            // Blur effect (only for static images)
            MultiEffect {
                anchors.fill: wallpaper
                source: wallpaper
                visible: wallpaper.ready && !backdropWindow.wallpaperIsGif && !backdropWindow.wallpaperIsVideo
                blurEnabled: backdropWindow.backdropBlurRadius > 0
                blur: backdropWindow.backdropBlurRadius / 100.0
                blurMax: 64
                saturation: backdropWindow.backdropSaturation
                contrast: backdropWindow.backdropContrast
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: backdropWindow.backdropDim / 100.0
            }

            // Vignette effect
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
