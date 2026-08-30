import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: screenCorners
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    property var actionForCorner: ({
        [RoundCorner.CornerEnum.TopLeft]: outputName => GlobalStates.toggleSidebarLeft(outputName),
        [RoundCorner.CornerEnum.BottomLeft]: outputName => GlobalStates.toggleSidebarLeft(outputName),
        [RoundCorner.CornerEnum.TopRight]: outputName => GlobalStates.toggleSidebarRight(outputName),
        [RoundCorner.CornerEnum.BottomRight]: outputName => GlobalStates.toggleSidebarRight(outputName)
    })

    component CornerPanelWindow: PanelWindow {
        id: cornerPanelWindow
        property var screen: QsWindow.window?.screen
        property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
        property bool fullscreen
        property var corner

        // Separate conditions for clarity
        readonly property int fakeRoundingMode: Config?.options?.appearance?.fakeScreenRounding ?? 0
        readonly property bool showFakeRounding: fakeRoundingMode === 1 || (fakeRoundingMode === 2 && !fullscreen)
        readonly property bool cornerOpenEnabled: Config?.options?.sidebar?.cornerOpen?.enable ?? false
        readonly property bool cornerOpenAtBottom: Config?.options?.sidebar?.cornerOpen?.bottom ?? false
        readonly property bool cornerOpenMatchesPosition: cornerOpenAtBottom === cornerWidget.isBottom
        readonly property bool shouldShowCornerOpen: cornerOpenEnabled
            && cornerOpenMatchesPosition && !fullscreen
        readonly property string orbitCorner: Config.options?.orbit?.hotCorner ?? "topRight"
        readonly property string cornerName: cornerWidget.isTopLeft ? "topLeft"
            : cornerWidget.isTopRight ? "topRight"
            : cornerWidget.isBottomLeft ? "bottomLeft" : "bottomRight"
        readonly property bool shouldShowOrbitHotCorner: CompositorService.isNiri
            && (Config.options?.panelFamily ?? "ii") !== "waffle"
            && (Config.options?.orbit?.enable ?? true)
            && (Config.options?.orbit?.hotCornerEnable ?? true)
            && cornerName === orbitCorner
            && !fullscreen
        readonly property bool shouldShowSidebarCornerOpen: shouldShowCornerOpen
            && !shouldShowOrbitHotCorner

        visible: !fullscreen && (showFakeRounding || shouldShowSidebarCornerOpen || shouldShowOrbitHotCorner)

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: orbitHotCornerLoader.active ? orbitHotCornerLoader
                : (sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null)
        }
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        anchors {
            top: cornerWidget.isTopLeft || cornerWidget.isTopRight
            left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
            bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
            right: cornerWidget.isTopRight || cornerWidget.isBottomRight
        }
        margins {
            right: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.right) * -1
            bottom: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.bottom) * -1
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            rightVisualMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.right) * 1
            bottomVisualMargin: ((Config.options?.interactions?.deadPixelWorkaround?.enable ?? false) && cornerPanelWindow.anchors.bottom) * 1

            // Size for fake rounding visual (0 if disabled)
            // ZZZ square = sharp console silhouette → no fake screen rounding;
            // ZZZ round (anime) keeps the soft corner like the other styles.
            readonly property int roundingSize: cornerPanelWindow.showFakeRounding
                ? (Appearance.zzzEverywhere ? (Appearance.zzz.round ? Appearance.rounding.screenRounding : 0)
                                            : Appearance.rounding.screenRounding)
                : 0
            // Size for corner open interaction area
            readonly property int cornerOpenWidth: Config.options?.sidebar?.cornerOpen?.cornerRegionWidth ?? 20
            readonly property int cornerOpenHeight: Config.options?.sidebar?.cornerOpen?.cornerRegionHeight ?? 20
            readonly property int orbitHotCornerSize: Math.max(4, Math.min(40,
                Config.options?.orbit?.hotCornerSize ?? 12))

            implicitSize: roundingSize
            implicitWidth: Math.max(roundingSize,
                cornerPanelWindow.shouldShowSidebarCornerOpen ? cornerOpenWidth : 0,
                cornerPanelWindow.shouldShowOrbitHotCorner ? orbitHotCornerSize : 0)
            implicitHeight: Math.max(roundingSize,
                cornerPanelWindow.shouldShowSidebarCornerOpen ? cornerOpenHeight : 0,
                cornerPanelWindow.shouldShowOrbitHotCorner ? orbitHotCornerSize : 0)

            Loader {
                id: orbitHotCornerLoader
                active: cornerPanelWindow.shouldShowOrbitHotCorner
                anchors {
                    top: cornerWidget.isTop ? parent.top : undefined
                    bottom: cornerWidget.isBottom ? parent.bottom : undefined
                    left: cornerWidget.isLeft ? parent.left : undefined
                    right: cornerWidget.isRight ? parent.right : undefined
                }

                sourceComponent: MouseArea {
                    id: orbitHotCornerArea
                    implicitWidth: cornerWidget.orbitHotCornerSize
                    implicitHeight: cornerWidget.orbitHotCornerSize
                    hoverEnabled: true
                    property bool armed: true
                    property bool atCorner: false

                    function triggerOrbit(): void {
                        if (!armed || !atCorner)
                            return
                        armed = false
                        orbitDwellTimer.stop()
                        GlobalStates.openOrbit(cornerPanelWindow.screen?.name ?? "")
                    }

                    onPositionChanged: mouse => {
                        const atX = cornerWidget.isRight ? mouse.x >= width - 2 : mouse.x <= 2
                        const atY = cornerWidget.isTop ? mouse.y <= 2 : mouse.y >= height - 2
                        atCorner = atX && atY
                        if (!atCorner) {
                            armed = true
                            orbitDwellTimer.stop()
                            return
                        }
                        if (!armed)
                            return
                        const dwell = Config.options?.orbit?.hotCornerDwellMs ?? 0
                        if (dwell <= 0)
                            triggerOrbit()
                        else if (!orbitDwellTimer.running)
                            orbitDwellTimer.restart()
                    }
                    onExited: {
                        atCorner = false
                        orbitDwellTimer.stop()
                        if (!GlobalStates.overviewOpen || GlobalStates.overviewMode !== "orbit")
                            armed = true
                    }

                    Timer {
                        id: orbitDwellTimer
                        interval: Math.max(1, Config.options?.orbit?.hotCornerDwellMs ?? 0)
                        onTriggered: orbitHotCornerArea.triggerOrbit()
                    }
                }
            }

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: cornerPanelWindow.shouldShowSidebarCornerOpen
                anchors {
                    top: (cornerWidget.isTopLeft || cornerWidget.isTopRight) ? parent.top : undefined
                    bottom: (cornerWidget.isBottomLeft || cornerWidget.isBottomRight) ? parent.bottom : undefined
                    left: (cornerWidget.isLeft) ? parent.left : undefined
                    right: (cornerWidget.isTopRight || cornerWidget.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: cornerWidget.cornerOpenWidth
                    implicitHeight: cornerWidget.cornerOpenHeight
                    hoverEnabled: true
                    onPositionChanged: {
                        if (Config.options?.sidebar?.cornerOpen?.clickless ?? false) return;
                        if (!(Config.options?.sidebar?.cornerOpen?.clicklessCornerEnd ?? false)) return;
                        const verticalOffset = Config.options?.sidebar?.cornerOpen?.clicklessCornerVerticalOffset ?? 10;
                        const correctX = (cornerWidget.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerWidget.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerWidget.isTop && mouseArea.mouseY > verticalOffset || cornerWidget.isBottom && mouseArea.mouseY < mouseArea.height - verticalOffset);
                        if (correctX && correctY)
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                    }
                    onEntered: {
                        if (Config.options?.sidebar?.cornerOpen?.clickless ?? false)
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                    }
                    onPressed: {
                        if (!(Config.options?.sidebar?.cornerOpen?.clickless ?? false)) {
                            screenCorners.actionForCorner[cornerPanelWindow.corner](cornerPanelWindow.screen?.name ?? "");
                            if (Config.options?.background?.effects?.ripple?.hotcorners ?? true) {
                                GlobalStates.requestRipple(0, 0, cornerPanelWindow.screen.name);
                            }
                        }
                    }
                    onScrollDown: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerWidget.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness - 0.05);
                        else {
                            Audio.decrementVolume();
                        }
                    }
                    onScrollUp: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerWidget.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness + 0.05);
                        else {
                            Audio.incrementVolume();
                        }
                    }
                    onMovedAway: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerWidget.isLeft)
                            GlobalStates.osdBrightnessOpen = false;
                        else
                            GlobalStates.osdVolumeOpen = false;
                    }

                    Loader {
                        active: Config.options?.sidebar?.cornerOpen?.visualize ?? false
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData
            property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(modelData) : null

            // Hide when fullscreen
            property list<HyprlandWorkspace> workspacesForMonitor: CompositorService.isHyprland
                ? Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
                : []
            property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
            property bool fullscreen: {
                if (CompositorService.isHyprland) {
                    return activeWorkspaceWithFullscreen != undefined;
                }
                // Corners only stop being painted; they never unmap a surface
                // or change the exclusive zone, so they can safely follow
                // automatic fullscreen detection.
                if (CompositorService.isNiri)
                    return GameMode.hasFullscreenOnOutput(modelData?.name ?? "")
                return false;
            }

            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.TopLeft
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.TopRight
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.BottomLeft
                fullscreen: monitorScope.fullscreen
            }
            CornerPanelWindow {
                screen: modelData
                corner: RoundCorner.CornerEnum.BottomRight
                fullscreen: monitorScope.fullscreen
            }
        }
    }
}
