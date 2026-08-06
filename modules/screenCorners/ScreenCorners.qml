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

        visible: !fullscreen && (showFakeRounding || shouldShowCornerOpen)

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null
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

            implicitSize: roundingSize
            implicitWidth: Math.max(roundingSize, cornerPanelWindow.shouldShowCornerOpen ? cornerOpenWidth : 0)
            implicitHeight: Math.max(roundingSize, cornerPanelWindow.shouldShowCornerOpen ? cornerOpenHeight : 0)

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: cornerPanelWindow.shouldShowCornerOpen
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
