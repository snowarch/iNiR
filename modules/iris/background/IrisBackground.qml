pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: panel
        required property var modelData

        readonly property string monitorName: WallpaperListener.getMonitorName(panel.modelData)
        readonly property string configuredPath: Wallpapers.currentMainWallpaperPath(panel.monitorName)
        readonly property string previewPath: Wallpapers.internalPreviewFor(panel.monitorName, panel.configuredPath)
        readonly property bool video: Wallpapers.isVideoFile(panel.previewPath)
        readonly property bool gif: panel.previewPath.toLowerCase().endsWith(".gif")
        readonly property string effectivePath: panel.video ? Wallpapers.stillUrlFor(panel.previewPath) : panel.previewPath
        readonly property bool motion: (Config.options?.background?.enableAnimation ?? true)
            && !GlobalStates.screenLocked && !Appearance._gameModeActive && !Wallpapers.batteryPauseActive
            && Wallpapers.videoMotionAllowedOn(panel.monitorName)
        // Scaling is Wallpapers.fillMode, as on every other desktop; awww only draws fill.
        readonly property string fillMode: Wallpapers.fillMode
        readonly property bool spanning: panel.fillMode === "span"
        readonly property bool externalWallpaper: AwwwBackend.supportsVisibleMainWallpaper(
            panel.configuredPath, panel.fillMode, false, false)
            && !Wallpapers.internalPreviewActive
        readonly property bool desktopMenuOpen: desktopMenu.active

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:iris-background"
        // The lightweight background is used specifically when desktop widgets
        // are disabled. Bare-desktop actions are shell actions, not widget
        // actions, so keep the surface pointer-capable and only request keyboard
        // focus while its menu is actually open.
        WlrLayershell.keyboardFocus: panel.desktopMenuOpen
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        // Fit and center leave bars: black, as awww draws them, never what awww still holds underneath.
        Rectangle {
            anchors.fill: parent
            color: "black" // iris-literal: letterbox bars, the same black awww pads with
            visible: (panel.fillMode === "fit" || panel.fillMode === "center")
                && !panel.externalWallpaper && panel.effectivePath.length > 0
        }

        // Span: this output's slice of one picture laid across the box around every screen.
        Item {
            id: canvas
            x: panel.spanning ? Wallpapers.spanArea.x - panel.modelData.x : 0
            y: panel.spanning ? Wallpapers.spanArea.y - panel.modelData.y : 0
            width: panel.spanning ? Wallpapers.spanArea.width : parent.width
            height: panel.spanning ? Wallpapers.spanArea.height : parent.height

            Image {
                anchors.fill: parent
                visible: !panel.externalWallpaper && panel.effectivePath.length > 0
                // Decoded at the size it is drawn; tile and center draw the picture at its own size.
                sourceSize: panel.fillMode === "tile" || panel.fillMode === "center" ? Qt.size(0, 0)
                    : Qt.size(canvas.width * (panel.screen?.devicePixelRatio ?? 1), canvas.height * (panel.screen?.devicePixelRatio ?? 1))
                source: {
                    const path = panel.effectivePath
                    if (!path || panel.externalWallpaper) return ""
                    return path.startsWith("file://") ? path : "file://" + FileUtils.trimFileProtocol(path)
                }
                fillMode: Wallpapers.imageFillFor(panel.fillMode)
                asynchronous: true
                cache: true
                smooth: true
                mipmap: false
            }

            AnimatedImage {
                anchors.fill: parent
                visible: panel.gif && status === AnimatedImage.Ready
                source: panel.gif ? "file://" + FileUtils.trimFileProtocol(panel.previewPath) : ""
                fillMode: Wallpapers.imageFillFor(panel.fillMode)
                asynchronous: true
                cache: false
                playing: visible && panel.motion
            }

            VideoCrossfader {
                anchors.fill: parent
                visible: panel.video
                source: panel.video ? panel.previewPath : ""
                fillMode: Wallpapers.videoFillFor(panel.fillMode)
                enableTransitions: Config.options?.background?.transition?.enable ?? true
                transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
                shouldPlay: panel.motion
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !panel.externalWallpaper && panel.effectivePath.length === 0
            color: IrisStyle.surfaceOpaque
        }

        MouseArea {
            anchors.fill: parent
            z: 20
            acceptedButtons: Qt.RightButton | Qt.LeftButton
            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (desktopMenu.active) desktopMenu.close()
                    return
                }
                desktopMenuAnchor.x = mouse.x
                desktopMenuAnchor.y = mouse.y
                desktopMenu.requestOpen()
            }
        }

        Item {
            id: desktopMenuAnchor
            z: 21
            width: 1
            height: 1
        }

        Connections {
            target: GlobalStates
            function onIrisDesktopMenuRequested(outputName: string, x: real, y: real): void {
                if (outputName !== (panel.modelData?.name ?? "")) return
                desktopMenuAnchor.x = x
                desktopMenuAnchor.y = y
                desktopMenu.requestOpen()
            }
        }

        IrisDesktopMenu {
            id: desktopMenu
            z: 22
            anchorItem: desktopMenuAnchor
            model: IrisDesktopActions.menu(panel.monitorName, panel.configuredPath, panel.previewPath)
        }
    }
}
