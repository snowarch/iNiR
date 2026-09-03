pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Pill top shell. Each monitor carries two layer-shell windows:
 *
 *  - `reserve` is a zero-content strip that only claims an exclusive zone the
 *    height of the rest pill, so tiled windows always sit below the pill even
 *    while it is expanded or a surface is open.
 *  - `overlay` is a full-screen transparent Overlay layer hosting the single
 *    morphing pill anchored at top-centre. The pill never moves and is never
 *    re-parented; it just grows in place, so every surface grows out of the rest
 *    pill instead of popping up as a separate panel.
 *
 * Input is routed by the window mask. While the pill is collapsed the mask is the
 * pill rect only, so the rest of the screen clicks through to windows. While the
 * pill is expanded (hovered/pinned) or a surface is open the mask is cleared so
 * the whole layer catches clicks. A backdrop press dismisses.
 */
Scope {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property var autoHideShownByScreen: ({})

    function scaleForScreen(screen): real {
        if (!screen)
            return root.uiScale
        const shortEdge = Math.min(screen.width, screen.height)
        const resolutionScale = Math.max(0.78, Math.min(1.6, shortEdge / 1080))
        return resolutionScale * 1.1 * root.uiScale
    }

    function setAutoHideShown(screenName: string, shown: bool): void {
        if (!screenName || root.autoHideShownByScreen[screenName] === shown)
            return
        const next = Object.assign({}, root.autoHideShownByScreen)
        next[screenName] = shown
        root.autoHideShownByScreen = next
    }

    function close() {
        openMon = "";
        openSurface = "";
    }

    Connections {
        target: GlobalStates
        function onWidgetEditModeChanged(): void {
            if (GlobalStates.widgetEditMode)
                root.close()
        }
        function onPillSurfaceCommand(command: string, surface: string): void {
            if (command === "open")
                root.openSurfaceByName(surface)
            else if (command === "close")
                root.close()
            else if (command === "toggle") {
                if (root.openSurface === surface)
                    root.close()
                else
                    root.openSurfaceByName(surface)
            }
        }
    }

    readonly property var surfaceNames: ["power", "media", "battery", "calendar", "link", "mixer", "sysmon", "clipboard", "glance", "launcher", "recorder", "settings"]
    readonly property var targetScreens: {
        const screens = Quickshell.screens;
        const list = Config.options?.bar?.screenList ?? [];
        if (!list || list.length === 0)
            return screens;
        const matchedScreens = screens.filter(screen => {
            const screenName = screen?.name ?? "";
            return screenName.length > 0 && list.includes(screenName);
        });
        return matchedScreens.length > 0 ? matchedScreens : screens;
    }

    function focusedScreenName() {
        const focused = CompositorService.isNiri ? NiriService.currentOutput : (Hyprland.focusedMonitor?.name ?? "");
        if (focused.length > 0 && root.targetScreens.some(screen => screen.name === focused))
            return focused;
        return root.targetScreens.length > 0 ? root.targetScreens[0].name : "";
    }

    function openSurfaceByName(surface) {
        if (!surfaceNames.includes(surface)) {
            console.warn(`[Pill] Unknown surface '${surface}'. Valid: ${surfaceNames.join(", ")}`);
            return;
        }
        openMon = focusedScreenName();
        openSurface = surface;
    }

    /**
     * Same surface ladder the hover icons use, reachable from keybinds and the
     * CLI. The target only registers while the pill bar is the active bar style.
     */
    IpcHandler {
        target: "pill"

        function open(surface: string): void { root.openSurfaceByName(surface) }
        function close(): void { root.close() }
        function toggle(surface: string): void {
            if (root.openSurface === surface)
                root.close();
            else
                root.openSurfaceByName(surface);
        }
        function state(): string { return root.openSurface.length > 0 ? root.openSurface : "closed" }
    }

    readonly property real uiScale: Config.options?.bar?.pill?.scale ?? 1
    readonly property real topGap: Config.options?.bar?.pill?.topGap ?? 1
    readonly property real appGap: Config.options?.bar?.pill?.appGap ?? 1
    readonly property bool floatOverWindows:
        Config.options?.bar?.pill?.floatOverWindows ?? false

    function openTrayMenu(item, anchorX, anchorY, hostWindow) {
        trayMenu.s = hostWindow ? hostWindow.s : 1;
        trayMenu.hostWindow = hostWindow;
        trayMenu.open(item, anchorX, anchorY);
    }

    /**
     * One tray menu for the whole shell, declared here at the root Scope. Its
     * layer-shell window cannot live under the pill's Item tree: Qt would parent
     * it across threads and warn on every start.
     */
    PillTrayMenu {
        id: trayMenu
    }

    Variants {
        model: root.targetScreens

        PanelWindow {
            id: reserve
            required property var modelData

            readonly property real s: root.scaleForScreen(modelData)
            readonly property real topGapPx: 8 * root.topGap * s
            readonly property real restHeight: (Config.options?.bar?.pill?.barMode ?? false)
                ? Math.max(58, Config.options?.bar?.pill?.expandedHeight ?? 66) * s
                : Math.max(38, Config.options?.bar?.pill?.restHeight ?? 44) * s
            readonly property real gameBarH: 34 * s

            /**
             * Trimming the reserved band below the pill's bottom lets windows
             * climb, so app gap sets the pill-to-window air without touching the
             * compositor's own gaps.
             */
            readonly property real reservedH: Math.max(0, restHeight + topGapPx - 12 * (1 - root.appGap) * s)

            /**
             * Same per-screen fullscreen focus check as Pill.fsCovered: in niri
             * a fullscreen window only covers the monitor while it is the
             * focused tile. Scrolling to another window in the same workspace
             * unfocuses the fullscreen game without changing its size, so
             * GameMode.active stays true but the pill is no longer hidden.
             * The reserve band must then give the pill its full rest height,
             * not the thin game-face height.
             */
            readonly property string screenName: modelData ? modelData.name : ""
            readonly property bool fsCovered: {
                if (!CompositorService.isNiri)
                    return GameMode.hasAnyFullscreenWindow;
                const wins = NiriService.windows ?? [];
                for (const w of wins) {
                    const ws = NiriService.workspaces?.[w.workspace_id];
                    if (!(ws?.is_active ?? false))
                        continue;
                    if (screenName.length > 0 && ws.output !== screenName)
                        continue;
                    if (!w.is_focused)
                        continue;
                    if (GameMode.isWindowFullscreen(w))
                        return true;
                }
                return false;
            }
            /** Game-face height only when the pill is actually hidden by a
             * focused fullscreen window, or Game Mode was manually engaged. */
            readonly property bool useGameZone: GameMode.manuallyActivated || fsCovered
            readonly property bool autoHideEnabled: (Config.options?.bar?.autoHide?.enable ?? false)
                && !useGameZone
            readonly property bool autoHideShown: root.autoHideShownByScreen[screenName] ?? false

            screen: modelData
            visible: !GlobalStates.widgetEditMode
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: GlobalStates.widgetEditMode ? 0
                : useGameZone ? gameBarH
                : autoHideEnabled
                    ? ((Config.options?.bar?.autoHide?.pushWindows ?? false) && autoHideShown ? reservedH : 0)
                    : root.floatOverWindows ? 0 : reservedH
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: useGameZone ? gameBarH : reservedH

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    Variants {
        model: root.targetScreens

        PanelWindow {
            id: overlay
            required property var modelData

            readonly property real s: root.scaleForScreen(modelData)
            readonly property real topGapPx: 8 * root.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: surfaceOpen || pill.held
            readonly property bool autoHideEnabled: (Config.options?.bar?.autoHide?.enable ?? false)
                && !pill.fsHide
            readonly property bool transientMode: pill.mode !== "rest" && pill.mode !== "hover"
            property bool pointerReveal: false
            property bool leftSidebarHold: false
            property bool rightSidebarHold: false
            readonly property bool interactionHold: leftSidebarHold || rightSidebarHold || pill.trayMenuOpen
            readonly property bool overviewOwnsEdge: GlobalStates.overviewOpen
                || (CompositorService.isNiri && NiriService.inOverview)
            readonly property bool reservationWanted: !overviewOwnsEdge
                && (edgeRevealHover.revealHover || pill.hovered || surfaceOpen || pill.held || interactionHold)
            readonly property bool explicitReservationWanted: !overviewOwnsEdge
                && (surfaceOpen || pill.held || interactionHold)
            readonly property bool mustShow: !autoHideEnabled || pointerReveal
                || superShow || surfaceOpen || pill.held || pill.hoverLatch || transientMode || interactionHold
            readonly property bool autoHideHidden: autoHideEnabled && !mustShow
            property bool superShow: false
            property bool reservationShown: false

            function edgeCornerName(left: bool): string {
                return left ? "topLeft" : "topRight"
            }

            function edgeCornerReserve(left: bool): real {
                const corner = edgeCornerName(left)
                let reserve = 0
                if (CompositorService.isNiri && NiriService.isOverviewHotCornerActive(modelData?.name ?? "", corner))
                    reserve = Math.max(reserve, 12)
                const orbitEnabled = CompositorService.isNiri
                    && (Config.options?.panelFamily ?? "ii") !== "waffle"
                    && (Config.options?.orbit?.enable ?? true)
                    && (Config.options?.orbit?.hotCornerEnable ?? true)
                if (orbitEnabled && String(Config.options?.orbit?.hotCorner ?? "topRight") === corner)
                    reserve = Math.max(reserve, Config.options?.orbit?.hotCornerSize ?? 12)
                const sidebarCornerEnabled = Config.options?.sidebar?.cornerOpen?.enable ?? false
                const sidebarCornerBottom = Config.options?.sidebar?.cornerOpen?.bottom ?? false
                if (sidebarCornerEnabled && !sidebarCornerBottom)
                    reserve = Math.max(reserve, Config.options?.sidebar?.cornerOpen?.cornerRegionWidth ?? 20)
                return reserve
            }

            function syncReservation(): void {
                reservationShowTimer.stop()
                reservationHideTimer.stop()
                if (!autoHideEnabled || !(Config.options?.bar?.autoHide?.pushWindows ?? false)) {
                    reservationShown = false
                    root.setAutoHideShown(modelData?.name ?? "", false)
                    return
                }
                if (explicitReservationWanted) {
                    reservationShown = true
                    root.setAutoHideShown(modelData?.name ?? "", true)
                    return
                }
                if (reservationWanted)
                    reservationShowTimer.restart()
                else if (reservationShown)
                    reservationHideTimer.restart()
            }

            function syncPointerReveal(): void {
                if (edgeRevealHover.revealHover || pill.hovered) {
                    pointerHideGrace.stop()
                    pointerReveal = true
                } else if (pointerReveal) {
                    pointerHideGrace.restart()
                }
            }

            Timer {
                id: pointerHideGrace
                // Only bridges the screen edge to the centred pill. Once the
                // pointer reaches the pill, Pill.hoverLatch owns collapse timing.
                interval: 450
                repeat: false
                onTriggered: {
                    if (!edgeRevealHover.revealHover && !pill.hovered)
                        overlay.pointerReveal = false
                }
            }

            Timer {
                id: reservationShowTimer
                interval: Appearance.animationsEnabled ? Appearance.animation.elementMoveEnter.duration : 1
                onTriggered: {
                    if (overlay.autoHideEnabled && overlay.reservationWanted
                            && (Config.options?.bar?.autoHide?.pushWindows ?? false)) {
                        overlay.reservationShown = true
                        root.setAutoHideShown(modelData?.name ?? "", true)
                    }
                }
            }

            Timer {
                id: reservationHideTimer
                interval: Appearance.animationsEnabled ? Appearance.animation.elementMoveEnter.duration : 1
                onTriggered: {
                    if (!overlay.reservationWanted) {
                        overlay.reservationShown = false
                        root.setAutoHideShown(modelData?.name ?? "", false)
                    }
                }
            }

            Timer {
                id: showBarTimer
                interval: Config.options?.bar?.autoHide?.showWhenPressingSuper?.delay ?? 100
                repeat: false
                onTriggered: overlay.superShow = true
            }

            Connections {
                target: GlobalStates
                function onSuperDownChanged() {
                    if (!(Config.options?.bar?.autoHide?.showWhenPressingSuper?.enable ?? true))
                        return
                    if (GlobalStates.superDown)
                        showBarTimer.restart()
                    else {
                        showBarTimer.stop()
                        overlay.superShow = false
                    }
                }
                function onSidebarLeftOpenChanged() {
                    if (!GlobalStates.sidebarLeftOpen)
                        overlay.leftSidebarHold = false
                    else if ((pill.hovered || overlay.pointerReveal)
                            && GlobalStates.sidebarLeftPresentationOutput === (modelData?.name ?? ""))
                        overlay.leftSidebarHold = true
                }
                function onSidebarRightOpenChanged() {
                    if (!GlobalStates.sidebarRightOpen)
                        overlay.rightSidebarHold = false
                    else if ((pill.hovered || overlay.pointerReveal)
                            && GlobalStates.sidebarRightPresentationOutput === (modelData?.name ?? ""))
                        overlay.rightSidebarHold = true
                }
            }

            onReservationWantedChanged: syncReservation()
            onExplicitReservationWantedChanged: syncReservation()
            onAutoHideEnabledChanged: syncReservation()
            Component.onCompleted: syncReservation()

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: surfaceOpen || pill.held
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "inir-pill"

            anchors { top: true; left: true; right: true; bottom: true }

            // This is a screen-sized surface on the Overlay layer — it has to be,
            // so the pill can morph and drop its surfaces anywhere on screen. But
            // a mapped fullscreen overlay forces the compositor to composite every
            // frame, which costs a fullscreen game its direct-scanout path (games
            // dropped to ~20 FPS under the pill bar and only under the pill bar).
            // Hiding the pill ITEM was not enough: the surface stayed mapped and
            // kept the compositor composing. Unmap the window itself whenever a
            // fullscreen window covers this monitor — toasts and OSD clear fsHide
            // on their own, so they still reach the screen over a game.
            //
            // Stay mapped while the pill is still fading out (it hides on an
            // opacity Behavior, not instantly), or unmapping would cut the fade
            // into a pop. Mapping back is immediate, so the fade-in is intact.
            visible: !GlobalStates.widgetEditMode
                && (modal || !pill.fsHide || pill.opacity > 0.01)

            // While a fullscreen window owns this monitor the pill is hidden and
            // must not eat pointer input either.
            mask: modal ? fullRegion : (pill.fsHide ? emptyOverlay : interactiveRegion)
            Region { id: emptyOverlay }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                x: pill.x + (pill.width - baseW) / 2
                y: pill.y
                width: baseW + pill.inputPadRight
                height: Math.max(pill.height, pill.targetH)
            }
            Region {
                id: interactiveRegion
                x: pillRegion.x
                y: pillRegion.y
                width: pillRegion.width
                height: pillRegion.height
                Region { item: edgeRevealRegion }
                Region {
                    intersection: Intersection.Subtract
                    x: 0
                    y: 0
                    width: overlay.edgeCornerReserve(true)
                    height: edgeRevealRegion.height
                }
                Region {
                    intersection: Intersection.Subtract
                    x: overlay.width - overlay.edgeCornerReserve(false)
                    y: 0
                    width: overlay.edgeCornerReserve(false)
                    height: edgeRevealRegion.height
                }
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }

            Item {
                id: edgeRevealRegion
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: overlay.autoHideEnabled
                    ? Math.max(1, Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2) : 0
                MouseArea {
                    id: edgeRevealHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    readonly property bool inLeftReservedCorner: mouseX < overlay.edgeCornerReserve(true)
                    readonly property bool inRightReservedCorner: mouseX >= width - overlay.edgeCornerReserve(false)
                    readonly property bool revealHover: containsMouse && !inLeftReservedCorner
                        && !inRightReservedCorner && !overlay.overviewOwnsEdge
                    onRevealHoverChanged: overlay.syncPointerReveal()
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (overlay.surfaceOpen) {
                        const inside = mouse.x >= pillRegion.x && mouse.x <= pillRegion.x + pillRegion.width
                            && mouse.y >= pillRegion.y && mouse.y <= pillRegion.y + pillRegion.height;
                        if (!inside)
                            root.close();
                    } else {
                        pill.pinned = false;
                    }
                }
            }

            /**
             * The pill lives inside the FocusScope, not beside it. The scope's
             * HoverHandler only sees the pointer over the pill if it is an
             * ancestor: as a sibling, the pill's own MouseAreas swallow the moves
             * and `hovered` flickers off on every mouse step inside the pill.
             */
            FocusScope {
                id: spectrumScope
                anchors.fill: parent
                focus: overlay.surfaceOpen

                readonly property bool spectrumPlaying: MprisController.isPlaying || YtMusic.isPlaying
                readonly property bool spectrumOutputEnabled:
                    (Config.options?.bar?.visualizer?.multiMonitorMode ?? "primary") === "all"
                    || Quickshell.screens.length <= 1
                    || String(overlay.modelData?.name ?? "")
                        === String(GlobalStates.primaryScreen?.name ?? "")
                readonly property bool spectrumConfigured: (Config.options?.bar?.pill?.musicViz ?? true)
                    && spectrumOutputEnabled
                    && !Appearance.gameModeMinimal
                readonly property bool spectrumProcessWanted: spectrumConfigured && spectrumPlaying
                readonly property bool spectrumVisible: spectrumConfigured
                    && pillCava.audioSignalActive
                    && !pill.fsHide
                    && !overlay.surfaceOpen

                HoverHandler {
                    onHoveredChanged: {
                        pill.hovered = hovered
                        overlay.syncPointerReveal()
                    }
                }
                Keys.onEscapePressed: root.close()

                CavaProcess {
                    id: pillCava
                    active: spectrumScope.spectrumProcessWanted
                    sampleCount: pillWings.requestedSampleCount
                }

                PillSpectrumWings {
                    id: pillWings
                    anchors.fill: parent
                    pillItem: pill
                    active: spectrumScope.spectrumVisible
                    points: active ? pillCava.points : []
                    normalizationCeiling: active ? pillCava.normalizationCeiling : 100
                    s: overlay.s
                }

                Pill {
                    id: pill
                    s: overlay.s
                    screenName: overlay.modelData ? overlay.modelData.name : ""
                    barWindow: overlay
                    surface: overlay.surface

                    anchors.top: parent.top
                    anchors.topMargin: pill.mode === "game" ? 0
                        : overlay.autoHideHidden
                            ? -(pill.hoverH + overlay.topGapPx + 1)
                            : overlay.topGapPx
                    anchors.horizontalCenter: parent.horizontalCenter

                    Behavior on anchors.topMargin {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }

                    trayMenuOpen: trayMenu.shown

                    onRequestSurface: (name) => {
                        root.openMon = overlay.modelData.name;
                        root.openSurface = name;
                    }
                    onRequestClose: root.close()
                    onTrayMenuRequested: (item, anchorX, anchorY) => root.openTrayMenu(item, anchorX, anchorY, overlay)
                }
            }
        }
    }
}
