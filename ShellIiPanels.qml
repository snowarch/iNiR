import qs.modules.alarm
import qs.modules.background
import qs.modules.bar
import qs.modules.bootGreeting
import qs.modules.cheatsheet
import qs.modules.controlPanel
import qs.modules.dashboard
import qs.modules.dock
import qs.modules.lock
import qs.modules.mascot
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.pill
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.sidebarLeft
import qs.modules.sidebarRight
import qs.modules.tilingOverlay
import qs.modules.verticalBar
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.shellUpdate
import qs.modules.workspaceStrip
import "modules/clipboard" as ClipboardModule

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: panelsRoot

    // Immediate panels — visible at first frame or must catch early events
    // Uses `active` which loads synchronously (required for first-frame visibility)
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Deferred panels — loaded asynchronously after first frame to reduce boot contention
    // Uses `loading` to pre-load in spare frame time, then `activeAsync` to activate without blocking
    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        // Start spare-frame incubation only after the immediate shell has
        // produced its entry frame. Activation remains in the deferred phase.
        loading: Config.ready && GlobalStates.shellEntryReady
            && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
        // Activate async when deferred phase is ready (doesn't block UI)
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Interaction panels keep their tiny router here and instantiate the
    // fullscreen visual tree only while open (plus its exit animation).
    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property bool keepLoaded: false
        // Resumable surfaces stay resident only after their first real use.
        // This preserves in-session work without paying their boot cost.
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 300
        property bool resident: open || keepLoaded
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open || onDemandLoader.keepLoaded
        }
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)

        onOpenChanged: {
            if (open) {
                used = true
                closeGrace.stop()
                resident = true
            } else if (!keepLoaded && !(retainAfterUse && used)) {
                closeGrace.restart()
            }
        }
        onKeepLoadedChanged: {
            if (keepLoaded) {
                closeGrace.stop()
                resident = true
            } else if (!open) {
                if (!(retainAfterUse && used))
                    closeGrace.restart()
            }
        }

        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    // === Immediate panels (first frame + early event capture) ===
    // bar.appearanceStyle picks the horizontal bar's look. classic/islands/scenic/
    // frame are variants of Bar.qml itself; "pill" swaps in a different bar
    // entirely, so it is resolved here rather than inside Bar.qml.
    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool barPill: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"

    PanelLoader { identifier: "iiBar"; extraCondition: !panelsRoot.barVertical && !panelsRoot.barPill; component: Bar {} }
    PanelLoader { identifier: "iiBar"; extraCondition: !panelsRoot.barVertical && panelsRoot.barPill; component: PillBar {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: panelsRoot.barVertical; component: VerticalBar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    // The pill bar hosts its own toast and OSD faces, so the standalone popup and
    // OSD panels would double every notification and every volume flash. Turning
    // the pill's faces off (bar.pill.toasts / bar.pill.osd) hands each duty back
    // to the standalone panel instead of silencing it.
    PanelLoader { identifier: "iiNotificationPopup"; extraCondition: !panelsRoot.barPill || !(Config.options?.bar?.pill?.toasts ?? true); component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; extraCondition: !panelsRoot.barPill || !(Config.options?.bar?.pill?.osd ?? true); component: OnScreenDisplay {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    // The ringing surface deliberately sits outside the notification pipeline:
    // Notifications.popupInhibited would swallow it with the sidebar open, in
    // quiet hours or in game mode. See AlarmRingingPanel.qml.
    DeferredPanelLoader { identifier: "iiAlarmRinging"; component: AlarmRingingPanel {} }
    DeferredPanelLoader { identifier: "iiBootGreeting"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; component: Cheatsheet {} }
    OnDemandPanelLoader {
        identifier: "iiControlPanel"
        open: GlobalStates.controlPanelOpen
        keepLoaded: Config.options?.controlPanel?.keepLoaded ?? false
        component: ControlPanel {}
    }
    OnDemandPanelLoader {
        identifier: "iiDashboard"
        open: GlobalStates.dashboardOpen
        keepLoaded: Config.options?.dashboard?.keepLoaded ?? false
        component: Dashboard {}
    }
    DeferredPanelLoader { identifier: "iiLock"; component: Lock {} }
    // MediaControls already gates its heavy tree; a second on-demand loader
    // races the same open state and can skip the entrance transition.
    DeferredPanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; component: OnScreenKeyboard {} }
    OnDemandPanelLoader {
        identifier: "iiOverlay"
        open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
        component: Overlay {}
    }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; component: Overview {} }
    DeferredPanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    // Keep the lightweight selector root resident. The root already lazily
    // instantiates RegionSelection/AnnotationEditor; wrapping it in a second
    // on-demand loader races the first cold IPC invocation and dismisses it.
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    OnDemandPanelLoader { identifier: "iiSessionScreen"; open: GlobalStates.sessionOpen; component: SessionScreen {} }

    // One input-only backdrop owns outside clicks for either sidebar. It maps
    // only while needed: the surface is fully transparent and sits below the
    // sidebar hosts, so keeping a fullscreen swapchain while both are closed
    // has no visual or interaction value.
    PanelWindow {
        id: dualSidebarBackdrop
        visible: GlobalStates.sidebarLeftOpen
            || GlobalStates.sidebarRightOpen
        updatesEnabled: GlobalStates.sidebarLeftOpen
            || GlobalStates.sidebarRightOpen
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "quickshell:dualSidebarBackdrop"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item { id: emptyDualSidebarMask; width: 0; height: 0 }
        mask: Region {
            item: GlobalStates.sidebarLeftOpen || GlobalStates.sidebarRightOpen
                ? dualSidebarBackdropArea : emptyDualSidebarMask
        }

        MouseArea {
            id: dualSidebarBackdropArea
            anchors.fill: parent
            enabled: GlobalStates.sidebarLeftOpen || GlobalStates.sidebarRightOpen
            onClicked: {
                GlobalStates.sidebarLeftOpen = false
                GlobalStates.sidebarRightOpen = false
            }
        }
    }

    // Sidebar windows stay mapped as transparent, input-empty hosts. Niri can
    // otherwise animate each layer-shell map before the configured QML entrance
    // begins, making a bar click look unrelated to the selected preset.
    DeferredPanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    DeferredPanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        component: TilingOverlay {}
    }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; component: WallpaperCoverflow {} }
    OnDemandPanelLoader { identifier: "iiClipboard"; open: GlobalStates.clipboardOpen; retainAfterUse: true; closeGraceMs: 250; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiShellUpdate"; open: ShellUpdates.overlayOpen; closeGraceMs: 250; component: ShellUpdateOverlay {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; component: RecordingOsd {} }
    DeferredPanelLoader { identifier: "iiWorkspaceStrip"; component: WorkspaceStrip {} }
    DeferredPanelLoader { identifier: "iiMascotCompanion"; extraCondition: Config.options?.mascot?.enable ?? false; component: MascotCompanion {} }

    IpcHandler {
        target: "controlPanel"
        function toggle(): void { GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen }
        function close(): void { GlobalStates.controlPanelOpen = false }
        function open(): void { GlobalStates.controlPanelOpen = true }
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen }
        function close(): void { GlobalStates.dashboardOpen = false }
        function open(): void { GlobalStates.dashboardOpen = true }
    }

    IpcHandler {
        target: "sidebarLeft"
        function toggle(): void { GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen }
        function close(): void { GlobalStates.sidebarLeftOpen = false }
        function open(): void { GlobalStates.sidebarLeftOpen = true }
        function expand(): void {
            GlobalStates.aiChatDetached = false
            GlobalStates.sidebarLeftOpen = true
            GlobalStates.sidebarLeftExpanded = true
        }
        function compact(): void { GlobalStates.sidebarLeftExpanded = false }
        function status(): string {
            return JSON.stringify({
                open: GlobalStates.sidebarLeftOpen,
                expanded: GlobalStates.sidebarLeftExpanded,
                detached: GlobalStates.aiChatDetached,
            })
        }
        function detach(): void {
            GlobalStates.sidebarLeftOpen = false
            GlobalStates.sidebarLeftExpanded = false
            GlobalStates.aiChatDetached = true
        }
        function attach(): void {
            GlobalStates.aiChatDetached = false
            GlobalStates.sidebarLeftExpanded = false
            GlobalStates.sidebarLeftOpen = true
        }
    }

    IpcHandler {
        target: "sidebarRight"
        function toggle(): void { GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen }
        function close(): void { GlobalStates.sidebarRightOpen = false }
        function open(): void { GlobalStates.sidebarRightOpen = true }
    }

    IpcHandler {
        target: "mediaControls"
        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            if (GlobalStates.mediaControlsOpen) Notifications.timeoutAll()
        }
        function close(): void { GlobalStates.mediaControlsOpen = false }
        function open(): void {
            GlobalStates.mediaControlsOpen = true
            Notifications.timeoutAll()
        }
    }

    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "controlPanelToggle"
            description: "Toggles control panel on press"
            onPressed: GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut { name: "oskToggle"; description: "Toggles on screen keyboard on press"; onPressed: GlobalStates.oskOpen = !GlobalStates.oskOpen }
            GlobalShortcut { name: "oskOpen"; description: "Opens on screen keyboard on press"; onPressed: GlobalStates.oskOpen = true }
            GlobalShortcut { name: "oskClose"; description: "Closes on screen keyboard on press"; onPressed: GlobalStates.oskOpen = false }
            GlobalShortcut { name: "overlayToggle"; description: "Toggles overlay on press"; onPressed: GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
            GlobalShortcut { name: "sessionToggle"; description: "Toggles session screen on press"; onPressed: GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
            GlobalShortcut { name: "sessionOpen"; description: "Opens session screen on press"; onPressed: GlobalStates.sessionOpen = true }
            GlobalShortcut { name: "sessionClose"; description: "Closes session screen on press"; onPressed: GlobalStates.sessionOpen = false }
            GlobalShortcut { name: "cheatsheetToggle"; description: "Toggles cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
            GlobalShortcut { name: "cheatsheetOpen"; description: "Opens cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = true }
            GlobalShortcut { name: "cheatsheetClose"; description: "Closes cheatsheet on press"; onPressed: GlobalStates.cheatsheetOpen = false }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "mediaControlsToggle"
                description: "Toggles media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            }
            GlobalShortcut {
                name: "mediaControlsOpen"
                description: "Opens media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = true
            }
            GlobalShortcut {
                name: "mediaControlsClose"
                description: "Closes media controls on press"
                onPressed: GlobalStates.mediaControlsOpen = false
            }
            GlobalShortcut {
                name: "mediaControlsPlayPause"
                description: "Toggles play/pause when media controls are open"
                onPressed: {
                    const player = MprisController.activePlayer
                    if (GlobalStates.mediaControlsOpen && player?.canTogglePlaying)
                        player.togglePlaying()
                }
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarLeftToggle"
                description: "Toggles left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
            }
            GlobalShortcut {
                name: "sidebarLeftOpen"
                description: "Opens left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = true
            }
            GlobalShortcut {
                name: "sidebarLeftClose"
                description: "Closes left sidebar on press"
                onPressed: GlobalStates.sidebarLeftOpen = false
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarRightToggle"
                description: "Toggles right sidebar on press"
                onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
            }
            GlobalShortcut {
                name: "sidebarRightOpen"
                description: "Opens right sidebar on press"
                onPressed: GlobalStates.sidebarRightOpen = true
            }
            GlobalShortcut {
                name: "sidebarRightClose"
                description: "Closes right sidebar on press"
                onPressed: GlobalStates.sidebarRightOpen = false
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "dashboardToggle"
            description: "Toggles the dashboard on press"
            onPressed: GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen
        }
    }

    LazyLoader {
        active: Config.ready && (Config.options?.background?.effects?.ripple?.enable ?? false)
        component: Variants {
            model: Quickshell.screens

            PanelWindow {
                id: rippleWindow
                required property ShellScreen modelData
                screen: modelData
                focusable: false
                color: "transparent"
                visible: ripple.playing

                WlrLayershell.namespace: "quickshell:charging-ripple"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                implicitWidth: modelData.width
                implicitHeight: modelData.height

                FluidRipple {
                    id: ripple
                    anchors.fill: parent
                    color: Appearance.colors.colPrimary
                    duration: Config.options?.background?.effects?.ripple?.rippleDuration ?? 3000

                    Component.onCompleted: {
                        if (Config.options?.background?.effects?.ripple?.reload ?? true) {
                            spawn();
                        }
                    }

                    Connections {
                        target: Battery
                        function onIsPluggedInChanged() {
                            if (Config.options?.background?.effects?.ripple?.charging ?? true) {
                                ripple.spawn();
                            }
                        }
                    }

                    Connections {
                        target: NiriService
                        function onInOverviewChanged() {
                            if (NiriService.inOverview && (Config.options?.background?.effects?.ripple?.overview ?? true)) {
                                if (rippleWindow.modelData.name === NiriService.currentOutput) {
                                    ripple.spawn(0, 0);
                                }
                            }
                        }
                    }

                    Connections {
                        target: GlobalStates
                        function onScreenLockedChanged() {
                            if (GlobalStates.screenLocked && (Config.options?.background?.effects?.ripple?.lock ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onSessionOpenChanged() {
                            if (GlobalStates.sessionOpen && (Config.options?.background?.effects?.ripple?.session ?? true)) {
                                ripple.spawn();
                            }
                        }

                        function onRequestRipple(x: real, y: real, screenName: string) {
                            if (rippleWindow.modelData.name === screenName) {
                                ripple.spawn(x, y);
                            }
                        }
                    }
                }
            }
        }
    }

    // Dedicated shell-layout editor. It is intentionally created after the ii
    // panel tree so its overlay window stays above bar, dock and sidebars.
    ShellLayoutEditorWindow {
        family: "ii"
        styleKey: Appearance.globalStyle
        accentColor: Appearance.colors.colPrimary
        surfaceColor: Appearance.colors.colLayer1
        elevatedSurfaceColor: Appearance.colors.colLayer2
        textColor: Appearance.colors.colOnLayer1
        secondaryTextColor: Appearance.colors.colSubtext
        borderColor: Appearance.colors.colLayer0Border
        fontFamily: Appearance.font.family.main
        titlePixelSize: Appearance.font.pixelSize.normal
        bodyPixelSize: Appearance.font.pixelSize.smaller
        smallPixelSize: Appearance.font.pixelSize.smallest
        panelRadius: Appearance.rounding.large
        controlRadius: Appearance.rounding.full
        animationDuration: Appearance.animationsEnabled
            ? Appearance.animation.elementMoveFast.duration : 0
    }
}
