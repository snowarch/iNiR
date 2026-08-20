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
    }

    readonly property var surfaceNames: ["power", "media", "battery", "calendar", "link", "mixer", "sysmon", "clipboard", "glance", "launcher", "recorder"]
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

    function openTrayMenu(item, anchorX, hostWindow) {
        trayMenu.s = hostWindow ? hostWindow.s : 1;
        trayMenu.hostWindow = hostWindow;
        trayMenu.open(item, anchorX);
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

            readonly property real s: modelData ? (modelData.height / 1080) * root.uiScale : 1
            readonly property real topGapPx: 8 * root.topGap * s
            readonly property real restHeight: (Config.options?.bar?.pill?.barMode ?? false) ? 58 * s : 38 * s
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

            screen: modelData
            visible: !GlobalStates.widgetEditMode
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: GlobalStates.widgetEditMode ? 0
                : (useGameZone ? gameBarH : reservedH)
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

            readonly property real s: modelData ? (modelData.height / 1080) * root.uiScale : 1
            readonly property real topGapPx: 8 * root.topGap * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            readonly property bool modal: surfaceOpen || pill.held

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
            mask: modal ? fullRegion : (pill.fsHide ? emptyOverlay : pillRegion)
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
                id: fullRegion
                width: overlay.width
                height: overlay.height
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
                    onHoveredChanged: pill.hovered = hovered
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
                    anchors.topMargin: pill.mode === "game" ? 0 : overlay.topGapPx
                    anchors.horizontalCenter: parent.horizontalCenter

                    trayMenuOpen: trayMenu.shown

                    onRequestSurface: (name) => {
                        root.openMon = overlay.modelData.name;
                        root.openSurface = name;
                    }
                    onRequestClose: root.close()
                    onTrayMenuRequested: (item, anchorX) => root.openTrayMenu(item, anchorX, overlay)
                }
            }
        }
    }
}
