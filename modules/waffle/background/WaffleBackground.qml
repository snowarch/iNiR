pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions as CF
import qs.modules.waffle.looks
import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panelRoot
        required property var modelData

        // Waffle background config
        readonly property var wBg: Config.options?.waffles?.background ?? {}
        readonly property var wEffects: wBg.effects ?? {}

        // Wallpaper source
        readonly property string wallpaperSourceRaw: {
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.wallpaperPath ?? "";
            return wBg.wallpaperPath || Config.options?.background?.wallpaperPath || "";
        }

        readonly property string wallpaperThumbnail: {
            if (wBg.useMainWallpaper ?? true) return Config.options?.background?.thumbnailPath ?? "";
            return wBg.thumbnailPath || Config.options?.background?.thumbnailPath || "";
        }

        readonly property bool enableAnimation: wBg.enableAnimation ?? Config.options?.background?.enableAnimation ?? true
        readonly property bool enableAnimatedBlur: wEffects.enableAnimatedBlur ?? false
        readonly property int thumbnailBlurStrength: wEffects.thumbnailBlurStrength ?? Config.options?.background?.effects?.thumbnailBlurStrength ?? 70

        readonly property bool wallpaperIsVideo: {
            const lowerPath = wallpaperSourceRaw.toLowerCase();
            return lowerPath.endsWith(".mp4") || lowerPath.endsWith(".webm") || lowerPath.endsWith(".mkv") || lowerPath.endsWith(".avi") || lowerPath.endsWith(".mov");
        }

        readonly property bool wallpaperIsGif: {
            return wallpaperSourceRaw.toLowerCase().endsWith(".gif");
        }

        // Effective source: use thumbnail if animation disabled for videos/GIFs
        readonly property string wallpaperSource: {
            if (!panelRoot.enableAnimation && (panelRoot.wallpaperIsVideo || panelRoot.wallpaperIsGif)) {
                return panelRoot.wallpaperThumbnail || panelRoot.wallpaperSourceRaw;
            }
            return panelRoot.wallpaperSourceRaw;
        }

        readonly property string wallpaperUrl: {
            const path = wallpaperSource;
            if (!path) return "";
            if (path.startsWith("file://")) return path;
            return "file://" + path;
        }

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:wBackground"
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Hide when fullscreen
        property bool hasFullscreenWindow: {
            if (CompositorService.isNiri && NiriService.windows) {
                return NiriService.windows.some(w => w.is_focused && w.is_fullscreen)
            }
            return false
        }

        // Hide wallpaper (show only backdrop for overview)
        readonly property bool backdropOnly: wBg.backdrop?.hideWallpaper ?? false

        visible: !backdropOnly && (GlobalStates.screenLocked || !hasFullscreenWindow || !(wBg.hideWhenFullscreen ?? true))

        // Dynamic focus based on windows
        property bool hasWindowsOnCurrentWorkspace: {
            try {
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.windows && NiriService.workspaces) {
                    const allWs = Object.values(NiriService.workspaces);
                    if (!allWs || allWs.length === 0) return false;
                    const currentNumber = NiriService.getCurrentWorkspaceNumber();
                    const currentWs = allWs.find(ws => ws.idx === currentNumber);
                    if (!currentWs) return false;
                    return NiriService.windows.some(w => w.workspace_id === currentWs.id);
                }
                return false;
            } catch (e) { return false; }
        }

        property bool focusWindowsPresent: !GlobalStates.screenLocked && hasWindowsOnCurrentWorkspace
        property real focusPresenceProgress: focusWindowsPresent ? 1 : 0
        Behavior on focusPresenceProgress {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Blur progress
        property real blurProgress: {
            const blurEnabled = wEffects.enableBlur ?? false;
            const blurRadius = wEffects.blurRadius ?? 0;
            if (!blurEnabled || blurRadius <= 0) return 0;

            const blurStatic = Math.max(0, Math.min(100, Number(wEffects.blurStatic) || 0));
            const dynamicPart = (100 - blurStatic) * focusPresenceProgress;
            return (blurStatic + dynamicPart) / 100;
        }

        Item {
            anchors.fill: parent
            clip: true

            // Static Image (for non-animated wallpapers OR thumbnails when animation disabled)
            Image {
                id: wallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: panelRoot.wallpaperUrl && ((!panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo) || !panelRoot.enableAnimation)
                    ? panelRoot.wallpaperUrl
                    : ""
                asynchronous: true
                cache: true
                visible: ((!panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo) || !panelRoot.enableAnimation) && status === Image.Ready && !blurEffect.visible
            }

            // Animated GIF support (only when animation enabled)
            AnimatedImage {
                id: gifWallpaper
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: (panelRoot.wallpaperIsGif && panelRoot.enableAnimation) ? panelRoot.wallpaperUrl : ""
                asynchronous: true
                cache: true
                visible: panelRoot.wallpaperIsGif && panelRoot.enableAnimation && !blurEffect.visible
                playing: visible

                layer.enabled: Appearance.effectsEnabled && panelRoot.enableAnimatedBlur && (panelRoot.wEffects.blurRadius ?? 0) > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: ((panelRoot.wEffects.blurRadius ?? 32) * Math.max(0, Math.min(1, panelRoot.thumbnailBlurStrength / 100))) / 100.0
                    blurMax: 64
                }
            }

            // Video wallpaper (Qt Multimedia - only when animation enabled)
            Video {
                id: videoWallpaper
                anchors.fill: parent
                visible: panelRoot.wallpaperIsVideo && panelRoot.enableAnimation && !blurEffect.visible
                source: {
                    if (!panelRoot.wallpaperIsVideo || !panelRoot.enableAnimation) return "";
                    const url = panelRoot.wallpaperUrl;
                    if (!url) return "";
                    // Qt Multimedia needs file:// URL format
                    return url.startsWith("file://") ? url : ("file://" + url);
                }
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true

                onPlaybackStateChanged: {
                    if (playbackState === MediaPlayer.StoppedState && visible && panelRoot.wallpaperIsVideo && panelRoot.enableAnimation) {
                        play()
                    }
                }

                onVisibleChanged: {
                    if (visible && panelRoot.wallpaperIsVideo && panelRoot.enableAnimation) {
                        play()
                    } else {
                        pause()
                    }
                }

                layer.enabled: Appearance.effectsEnabled && panelRoot.enableAnimatedBlur && (panelRoot.wEffects.blurRadius ?? 0) > 0
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: ((panelRoot.wEffects.blurRadius ?? 32) * Math.max(0, Math.min(1, panelRoot.thumbnailBlurStrength / 100))) / 100.0
                    blurMax: 64
                }
            }

            // Blur effect - disabled for videos and GIFs (performance)
            MultiEffect {
                id: blurEffect
                anchors.fill: parent
                source: wallpaper
                visible: Appearance.effectsEnabled && panelRoot.blurProgress > 0 &&
                         !panelRoot.wallpaperIsGif && !panelRoot.wallpaperIsVideo &&
                         wallpaper.status === Image.Ready
                blurEnabled: visible
                blur: panelRoot.blurProgress * ((panelRoot.wEffects.blurRadius ?? 32) / 100.0)
                blurMax: 64
            }

            // Dim overlay
            Rectangle {
                anchors.fill: parent
                color: {
                    const baseN = Number(panelRoot.wEffects.dim) || 0;
                    const dynN = Number(panelRoot.wEffects.dynamicDim) || 0;
                    const extra = panelRoot.focusPresenceProgress > 0 ? dynN * panelRoot.focusPresenceProgress : 0;
                    const total = Math.max(0, Math.min(100, baseN + extra));
                    return Qt.rgba(0, 0, 0, total / 100);
                }
                Behavior on color {
                    animation: Looks.transition.color.createObject(this)
                }
            }
        }
    }
}
