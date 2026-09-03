pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// Separate Material 3 bar selected by `bar.appearanceStyle === "m3"`.
// It replaces modules/bar/Bar.qml entirely while active (see ShellIiPanels),
// so it deliberately registers no IPC target and no GlobalShortcut: "bar" is
// owned by shell.qml and the shortcuts by modules/bar/Bar.qml. Toggling
// GlobalStates.barOpen through either still drives this bar.
Scope {
    id: bar
    property bool showBarBackground: Config.options.bar.m3.showBackground

    Variants {
        // For each monitor
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            const matched = screens.filter(screen => {
                const screenName = screen?.name ?? "";
                return screenName.length > 0 && list.includes(screenName);
            });
            return matched.length > 0 ? matched : screens;
        }
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData

                Timer {
                    id: showBarTimer
                    interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }
                property bool superShow: false
                readonly property bool autoHideEnabled: Config.options?.bar?.autoHide?.enable ?? false
                readonly property bool pushWindowsWhenShown: Config.options?.bar?.autoHide?.pushWindows ?? false
                readonly property bool overviewOwnsEdge: GlobalStates.overviewOpen
                    || (CompositorService.isNiri && NiriService.inOverview)
                readonly property string outputName: barRoot.screen?.name ?? ""
                readonly property real layerGap: Config.options.bar.m3.cornerStyle === 3
                    ? Config.options.bar.m3.gapsOut : 0
                readonly property real shownExclusiveZone: Appearance.sizes.baseBarHeight
                    + (Config.options.bar.m3.cornerStyle === 1 ? Config.options.bar.m3.gapsOut : 0)
                    + (Config.options.bar.m3.cornerStyle === 2 ? -6 : 0)
                property bool contextMenuHold: false
                property bool leftSidebarHold: false
                property bool rightSidebarHold: false
                property bool mediaControlsHold: false
                property bool controlPanelHold: false
                readonly property bool interactionHold: contextMenuHold || leftSidebarHold
                    || rightSidebarHold || mediaControlsHold || controlPanelHold
                readonly property bool pointerShow: !overviewOwnsEdge && hoverRegion.containsMouse
                property bool mustShow: pointerShow || superShow || interactionHold
                property bool reservationActive: false
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: !autoHideEnabled ? shownExclusiveZone
                    : (pushWindowsWhenShown && reservationActive ? shownExclusiveZone : 0)
                WlrLayershell.namespace: "quickshell:bar"
                // Upstream raised the bar to Overlay only while a Hyprland
                // special workspace sat over a fullscreen window. Niri has no
                // special workspace, so the bar stays on Top and fullscreen
                // windows cover it, which is what iNiR's own bar does too.
                WlrLayershell.layer: WlrLayer.Top
                implicitHeight: Appearance.sizes.barHeight + Appearance.rounding.screenRounding
                    + (barRoot.autoHideEnabled ? barRoot.layerGap : 0)
                // When Overlay-layer, bar shares a layer with the screen-corner click zones (ScreenCorners.qml)
                // and same-layer overlap is resolved by stacking, not layer priority - bar was winning and
                // swallowing the tiny corner-open hit rects. Carve them out of the bar's own mask so clicks
                // reach the corners underneath. Only relevant on the edge the bar and corners share.
                // The corner-open cutout only mattered while the bar was raised
                // to Overlay and shared a layer with the screen-corner click
                // zones. On Top layer the corners are already above it.
                property int cornerOpenCutHeight: autoHideEnabled
                    ? Math.max(1, Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2) + layerGap : 0
                mask: Region {
                    item: hoverMaskRegion
                    // Keep a fixed screen-edge hit strip while barContent is
                    // translated off-screen. Anchoring the only hit region to
                    // the moving bar made M3 hide correctly but unable to reveal
                    // reliably on some layer-shell/compositor combinations.
                    Region {
                        item: autoHideEdgeRegion
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: 0
                        y: Config.options.bar.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.edgeCornerReserve(true)
                        height: barRoot.cornerOpenCutHeight
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: barRoot.width - barRoot.edgeCornerReserve(false)
                        y: Config.options.bar.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.edgeCornerReserve(false)
                        height: barRoot.cornerOpenCutHeight
                    }
                }
                color: "transparent"

                function edgeCornerName(left: bool): string {
                    const bottom = Config.options?.bar?.bottom ?? false
                    return bottom ? (left ? "bottomLeft" : "bottomRight")
                        : (left ? "topLeft" : "topRight")
                }

                function edgeCornerReserve(left: bool): real {
                    if (!autoHideEnabled)
                        return 0
                    const corner = edgeCornerName(left)
                    let reserve = 0
                    if (CompositorService.isNiri && NiriService.isOverviewHotCornerActive(outputName, corner))
                        reserve = Math.max(reserve, 12)
                    const orbitEnabled = CompositorService.isNiri
                        && (Config.options?.panelFamily ?? "ii") !== "waffle"
                        && (Config.options?.orbit?.enable ?? true)
                        && (Config.options?.orbit?.hotCornerEnable ?? true)
                    if (orbitEnabled && String(Config.options?.orbit?.hotCorner ?? "topRight") === corner)
                        reserve = Math.max(reserve, Config.options?.orbit?.hotCornerSize ?? 12)
                    const sidebarCornerEnabled = Config.options?.sidebar?.cornerOpen?.enable ?? false
                    const sidebarCornerBottom = Config.options?.sidebar?.cornerOpen?.bottom ?? false
                    if (sidebarCornerEnabled && sidebarCornerBottom === (Config.options?.bar?.bottom ?? false))
                        reserve = Math.max(reserve, Config.options?.sidebar?.cornerOpen?.cornerRegionWidth ?? 20)
                    return reserve
                }

                function syncReservation(): void {
                    reservationShowTimer.stop()
                    reservationHideTimer.stop()
                    if (!autoHideEnabled || !pushWindowsWhenShown) {
                        reservationActive = false
                        return
                    }
                    if (interactionHold) {
                        reservationActive = true
                        return
                    }
                    if (pointerShow)
                        reservationShowTimer.restart()
                    else if (reservationActive)
                        reservationHideTimer.restart()
                }

                onPointerShowChanged: syncReservation()
                onInteractionHoldChanged: syncReservation()
                onAutoHideEnabledChanged: syncReservation()
                onPushWindowsWhenShownChanged: syncReservation()
                Component.onCompleted: syncReservation()

                Timer {
                    id: reservationShowTimer
                    interval: Appearance.animationsEnabled ? Appearance.animation.elementMoveEnter.duration : 1
                    onTriggered: {
                        if (barRoot.autoHideEnabled && barRoot.pushWindowsWhenShown
                                && (barRoot.pointerShow || barRoot.interactionHold))
                            barRoot.reservationActive = true
                    }
                }

                Timer {
                    id: reservationHideTimer
                    interval: Appearance.animationsEnabled ? Appearance.animation.elementMoveEnter.duration : 1
                    onTriggered: {
                        if (!barRoot.pointerShow && !barRoot.interactionHold)
                            barRoot.reservationActive = false
                    }
                }

                Connections {
                    target: GlobalStates
                    function onActiveContextMenuCountChanged(): void {
                        if (GlobalStates.activeContextMenuCount <= 0)
                            barRoot.contextMenuHold = false
                        else if (barRoot.pointerShow)
                            barRoot.contextMenuHold = true
                    }
                    function onSidebarLeftOpenChanged(): void {
                        if (!GlobalStates.sidebarLeftOpen)
                            barRoot.leftSidebarHold = false
                        else if (barRoot.pointerShow
                                && GlobalStates.sidebarLeftPresentationOutput === barRoot.outputName)
                            barRoot.leftSidebarHold = true
                    }
                    function onSidebarRightOpenChanged(): void {
                        if (!GlobalStates.sidebarRightOpen)
                            barRoot.rightSidebarHold = false
                        else if (barRoot.pointerShow
                                && GlobalStates.sidebarRightPresentationOutput === barRoot.outputName)
                            barRoot.rightSidebarHold = true
                    }
                    function onMediaControlsOpenChanged(): void {
                        if (!GlobalStates.mediaControlsOpen)
                            barRoot.mediaControlsHold = false
                        else if (barRoot.pointerShow)
                            barRoot.mediaControlsHold = true
                    }
                    function onControlPanelOpenChanged(): void {
                        if (!GlobalStates.controlPanelOpen)
                            barRoot.controlPanelHold = false
                        else if (barRoot.pointerShow)
                            barRoot.controlPanelHold = true
                    }
                }

                Item {
                    id: autoHideEdgeRegion
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: !Config.options.bar.bottom ? parent.top : undefined
                        bottom: Config.options.bar.bottom ? parent.bottom : undefined
                    }
                    height: barRoot.autoHideEnabled
                        ? Math.max(1, Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2) + barRoot.layerGap : 0
                }

                // Positioning
                anchors {
                    top: !Config.options.bar.bottom
                    bottom: Config.options.bar.bottom
                    left: true
                    right: true
                }

                margins {
                    top: barRoot.anchors.top && !barRoot.autoHideEnabled
                        ? barRoot.layerGap : 0
                    right: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) ? -1 : 0
                    bottom: barRoot.anchors.bottom
                        ? ((Config.options.interactions.deadPixelWorkaround.enable ? -1 : 0)
                            + (!barRoot.autoHideEnabled ? barRoot.layerGap : 0))
                        : 0
                }

                MouseArea  {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors {
                        fill: parent
                        rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * 1
                        bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * 1
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -Config.options.bar.autoHide.hoverRegionWidth
                            bottomMargin: -Config.options.bar.autoHide.hoverRegionWidth
                        }
                    }

                    RoundCorner {
                        id: leftPillCorner
                        visible: barContent.centerOnly && showBarBackground && Config.options.bar.m3.cornerStyle === 0
                        x: barContent.centerPillX - implicitSize
                        implicitSize: Appearance.rounding.screenRounding
                        color: Appearance.colors.colLayer0
                        corner: RoundCorner.CornerEnum.TopRight

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: leftPillCorner
                                anchors.top: undefined
                                anchors.bottom: barContent.bottom
                            }
                            PropertyChanges {
                                target: leftPillCorner
                                corner: RoundCorner.CornerEnum.BottomRight
                            }
                        }
                        AnchorChanges {
                            target: leftPillCorner
                            anchors.top: barContent.top
                            anchors.bottom: undefined
                        }
                    }

                    BarContent {
                        id: barContent

                        implicitHeight: Appearance.sizes.barHeight
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: barRoot.autoHideEnabled
                                ? (!mustShow ? -Appearance.sizes.barHeight : barRoot.layerGap)
                                : 0
                            bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
                            rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                        }
                        Behavior on anchors.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: barRoot.autoHideEnabled
                                    ? (!mustShow ? -Appearance.sizes.barHeight : barRoot.layerGap)
                                    : 0
                            }
                        }
                    }

                    RoundCorner {
                        id: rightPillCorner
                        visible: barContent.centerOnly && showBarBackground && Config.options.bar.m3.cornerStyle === 0
                        x: barContent.centerPillX + barContent.centerPillWidth
                        implicitSize: Appearance.rounding.screenRounding
                        color: Appearance.colors.colLayer0
                        corner: RoundCorner.CornerEnum.TopLeft

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: rightPillCorner
                                anchors.top: undefined
                                anchors.bottom: barContent.bottom
                            }
                            PropertyChanges {
                                target: rightPillCorner
                                corner: RoundCorner.CornerEnum.BottomLeft
                            }
                        }
                        AnchorChanges {
                            target: rightPillCorner
                            anchors.top: barContent.top
                            anchors.bottom: undefined
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: Appearance.rounding.screenRounding
                        active: showBarBackground && Config.options.bar.m3.cornerStyle === 0 && !barContent.centerOnly// Hug

                        states: State {
                            name: "bottom"
                            when: Config.options.bar.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            implicitHeight: Appearance.rounding.screenRounding
                            RoundCorner {
                                id: leftCorner
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: Config.options.bar.bottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            RoundCorner {
                                id: rightCorner
                                anchors {
                                    right: parent.right
                                    top: !Config.options.bar.bottom ? parent.top : undefined
                                    bottom: Config.options.bar.bottom ? parent.bottom : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: showBarBackground ? Appearance.colors.colLayer0 : "transparent"

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: Config.options.bar.bottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
