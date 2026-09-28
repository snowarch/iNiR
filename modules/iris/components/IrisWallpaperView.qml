pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property var screen: null
    readonly property string monitorName: WallpaperListener.getMonitorName(root.screen)
    readonly property string configuredPath: Wallpapers.currentMainWallpaperPath(root.monitorName)
    property string path: Wallpapers.internalPreviewFor(root.monitorName, root.configuredPath)
    property bool active: true
    property bool live: true
    property bool provideTexture: false
    property bool asynchronous: true
    property int fillMode: Image.PreserveAspectCrop
    property size decodeSize: Qt.size(0, 0)

    readonly property bool isVideo: Wallpapers.isVideoFile(root.path)
    readonly property bool isGif: root.path.toLowerCase().endsWith(".gif")
    readonly property string stillUrl: root.active ? Wallpapers.stillUrlFor(root.path) : ""
    readonly property bool motion: root.shown
        && (Config.options?.background?.enableAnimation ?? true)
        && !GlobalStates.screenLocked && !Appearance._gameModeActive && !Wallpapers.batteryPauseActive
        && Wallpapers.videoMotionAllowedOn(root.monitorName)
    readonly property bool shown: root.live && (root.QsWindow.window?.visible ?? false)
    readonly property bool playsVideo: root.active && root.isVideo && root.shown
    readonly property bool animated: root.playsVideo || (root.active && root.isGif && root.shown)
    readonly property bool videoFrame: root.playsVideo && (videoLoader.item?.hasFrame ?? false)
    readonly property bool ready: root.isGif ? gif.status === AnimatedImage.Ready
        : still.status === Image.Ready || root.videoFrame

    // A moving wallpaper is a subtree: sampling it costs a pass per frame, so only samplers ask.
    readonly property Item textureItem: root.animated && root.provideTexture ? motionTexture.item : still
    readonly property Item stillItem: still

    Item {
        id: content
        anchors.fill: parent

        Image {
            id: still
            anchors.fill: parent
            visible: !root.isGif && !root.videoFrame && root.stillUrl.length > 0
            source: root.stillUrl
            fillMode: root.fillMode
            asynchronous: root.asynchronous
            cache: true
            sourceSize: root.decodeSize
            // Shown shrunk it needs mipmaps to stay sharp; a texture an effect samples must not have them.
            mipmap: !root.provideTexture
        }

        AnimatedImage {
            id: gif
            anchors.fill: parent
            visible: root.isGif && status === AnimatedImage.Ready
            source: root.active && root.isGif ? "file://" + FileUtils.trimFileProtocol(root.path) : ""
            fillMode: root.fillMode
            asynchronous: true
            cache: false
            playing: visible && root.motion
        }

        Loader {
            id: videoLoader
            anchors.fill: parent
            active: root.playsVideo
            visible: root.videoFrame
            sourceComponent: VideoCrossfader {
                source: root.path
                fillMode: root.fillMode
                shouldPlay: root.motion
                enableTransitions: false
                decodeHeight: root.decodeSize.height > 0 ? root.decodeSize.height : -1
            }
        }
    }

    Loader {
        id: motionTexture
        anchors.fill: parent
        active: root.animated && root.provideTexture
        visible: false
        sourceComponent: ShaderEffectSource {
            sourceItem: content
            live: true
            hideSource: false
            textureSize: root.decodeSize.width > 0 ? root.decodeSize
                : Qt.size(Math.max(1, Math.round(root.width)), Math.max(1, Math.round(root.height)))
        }
    }
}
