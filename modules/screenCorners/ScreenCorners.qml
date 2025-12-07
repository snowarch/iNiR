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
        [RoundCorner.CornerEnum.TopLeft]: () => GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen,
        [RoundCorner.CornerEnum.BottomLeft]: () => GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen,
        [RoundCorner.CornerEnum.TopRight]: () => GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen,
        [RoundCorner.CornerEnum.BottomRight]: () => GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
    })

    component CornerPanelWindow: PanelWindow {
        id: cornerPanelWindow
        property var screen: QsWindow.window?.screen
        property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
        property bool fullscreen
        visible: ((Config?.options?.appearance?.fakeScreenRounding ?? 0) === 1 || ((Config?.options?.appearance?.fakeScreenRounding ?? 0) === 2 && !fullscreen))
        property var corner

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

            implicitSize: Appearance.rounding.screenRounding
            implicitHeight: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitHeight)
            implicitWidth: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitWidth)

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: {
                    if (!(Config.options?.sidebar?.cornerOpen?.enable ?? false)) return false;
                    if (cornerPanelWindow.fullscreen) return false;
                    // Disable corner interactions during GameMode to avoid input capture
                    if (GameMode.active) return false;
                    return ((Config.options?.sidebar?.cornerOpen?.bottom ?? false) == cornerWidget.isBottom);
                }
                anchors {
                    top: (cornerWidget.isTopLeft || cornerWidget.isTopRight) ? parent.top : undefined
                    bottom: (cornerWidget.isBottomLeft || cornerWidget.isBottomRight) ? parent.bottom : undefined
                    left: (cornerWidget.isLeft) ? parent.left : undefined
                    right: (cornerWidget.isTopRight || cornerWidget.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: Config.options?.sidebar?.cornerOpen?.cornerRegionWidth ?? 20
                    implicitHeight: Config.options?.sidebar?.cornerOpen?.cornerRegionHeight ?? 20
                    hoverEnabled: true
                    onPositionChanged: {
                        if (!(Config.options?.sidebar?.cornerOpen?.clicklessCornerEnd ?? false)) return;
                        const verticalOffset = Config.options?.sidebar?.cornerOpen?.clicklessCornerVerticalOffset ?? 10;
                        const correctX = (cornerWidget.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerWidget.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerWidget.isTop && mouseArea.mouseY > verticalOffset || cornerWidget.isBottom && mouseArea.mouseY < mouseArea.height - verticalOffset);
                        if (correctX && correctY)
                            screenCorners.actionForCorner[cornerPanelWindow.corner]();
                    }
                    onEntered: {
                        if (Config.options?.sidebar?.cornerOpen?.clickless ?? false)
                            screenCorners.actionForCorner[cornerPanelWindow.corner]();
                    }
                    onPressed: {
                        screenCorners.actionForCorner[cornerPanelWindow.corner]();
                    }
                    onScrollDown: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerWidget.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness - 0.05);
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume -= step;
                        }
                    }
                    onScrollUp: {
                        if (!(Config.options?.sidebar?.cornerOpen?.valueScroll ?? false))
                            return;
                        if (cornerWidget.isLeft)
                            cornerPanelWindow.brightnessMonitor.setBrightness(cornerPanelWindow.brightnessMonitor.brightness + 0.05);
                        else {
                            const currentVolume = Audio.value;
                            const step = currentVolume < 0.1 ? 0.01 : 0.02 || 0.2;
                            Audio.sink.audio.volume = Math.min(1, Audio.sink.audio.volume + step);
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
                if (CompositorService.isNiri && typeof NiriService !== "undefined" && NiriService.outputs && NiriService.windows && NiriService.workspaces) {
                    try {
                        const outputName = modelData?.name || "";
                        if (!outputName)
                            return false;
                        const outputInfo = NiriService.outputs[outputName];
                        const logical = outputInfo ? outputInfo.logical : null;
                        if (!logical)
                            return false;
                        const lw = logical.width;
                        const lh = logical.height;
                        if (!(lw > 0 && lh > 0))
                            return false;

                        const windows = NiriService.windows;
                        const wss = NiriService.workspaces;
                        for (let i = 0; i < windows.length; ++i) {
                            const w = windows[i];
                            // Check if window is fullscreen via is_fullscreen property first
                            if (w.is_fullscreen === true) {
                                const ws = wss[w.workspace_id];
                                if (ws && ws.output === outputName && ws.is_active) {
                                    return true;
                                }
                            }
                            // Fallback: check by size comparison
                            const ws = wss[w.workspace_id];
                            if (!ws || ws.output !== outputName || !ws.is_active)
                                continue;
                            const layout = w.layout;
                            const size = layout && layout.tile_size ? layout.tile_size : null;
                            if (!size || size.length < 2)
                                continue;
                            const ww = size[0];
                            const wh = size[1];
                            if (!(ww > 0 && wh > 0))
                                continue;
                            const areaWindow = ww * wh;
                            const areaOutput = lw * lh;
                            // More aggressive threshold for games
                            if (areaWindow >= areaOutput * 0.90) {
                                return true;
                            }
                        }
                    } catch (e) {}
                    return false;
                }
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
