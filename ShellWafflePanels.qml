import qs.modules.bootGreeting
import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.mascot
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.tilingOverlay
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.workspaceStrip
import "modules/clipboard" as ClipboardModule

import qs.modules.waffle.actionCenter
import qs.modules.waffle.altSwitcher as WaffleAltSwitcherModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services
import qs.services.deferred
import "."

Item {
    id: root

    readonly property var waffleAltSwitcherOptions:
        Config.options?.waffles?.altSwitcher ?? ({})
    readonly property string waffleAltSwitcherPreset:
        root.waffleAltSwitcherOptions.preset ?? "thumbnails"
    readonly property bool waffleAltSwitcherVisual:
        root.waffleAltSwitcherPreset !== "none"
        && !((root.waffleAltSwitcherOptions.noVisualUi ?? false)
            && root.waffleAltSwitcherPreset !== "skew")

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

    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 250
        // Retained Waffle surfaces are a bounded warm cache, not a permanent
        // session allocation. This releases start/action-center trees after a
        // long idle period while keeping ordinary reopen latency effectively warm.
        property int retainIdleMs: 5 * 60 * 1000
        property bool resident: open
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
        }
        property Timer retainIdle: Timer {
            interval: onDemandLoader.retainIdleMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open
        }
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
        onOpenChanged: {
            if (open) {
                used = true
                closeGrace.stop()
                retainIdle.stop()
                resident = true
            } else if (retainAfterUse && used) {
                retainIdle.restart()
            } else {
                closeGrace.restart()
            }
        }
        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    // === Immediate panels (first frame + early event capture) ===
    PanelLoader { identifier: "wBar"; component: WaffleBarModule.WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    OnDemandPanelLoader { identifier: "wStartMenu"; open: GlobalStates.searchOpen; retainAfterUse: true; component: WaffleStartMenu {} }
    OnDemandPanelLoader { identifier: "wActionCenter"; open: GlobalStates.waffleActionCenterOpen; retainAfterUse: true; component: WaffleActionCenter {} }
    OnDemandPanelLoader { identifier: "wNotificationCenter"; open: GlobalStates.waffleNotificationCenterOpen; component: WaffleNotificationCenter {} }
    OnDemandPanelLoader { identifier: "wWidgets"; open: GlobalStates.waffleWidgetsOpen && (Config.options?.waffles?.modules?.widgets ?? true); component: WaffleWidgets {} }
    DeferredPanelLoader { identifier: "wLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "wPolkit"; component: Polkit {} }
    OnDemandPanelLoader { identifier: "wSessionScreen"; open: GlobalStates.sessionOpen; component: SessionScreen {} }
    OnDemandPanelLoader { identifier: "wTaskView"; open: GlobalStates.waffleTaskViewOpen; component: WaffleTaskViewModule.WaffleTaskView {} }

    // Shared modules that work with waffle (all deferred — user-triggered)
    DeferredPanelLoader { identifier: "iiBootGreeting"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; component: Cheatsheet {} }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; component: OnScreenKeyboard {} }
    OnDemandPanelLoader { identifier: "iiOverlay"; open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets; component: Overlay {} }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; component: Overview {} }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    // RegionSelector owns its own lazy content. Keep this root resident so a
    // first cold IPC call cannot race two nested on-demand loaders.
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; extraCondition: Config.options?.panelFamily !== "waffle"; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; component: RecordingOsd {} }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        component: TilingOverlay {}
    }
    DeferredPanelLoader { identifier: "iiWorkspaceStrip"; component: WorkspaceStrip {} }
    DeferredPanelLoader { identifier: "iiMascotCompanion"; extraCondition: Config.options?.mascot?.enable ?? false; component: MascotCompanion {} }

    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader {
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"
        component: WaffleClipboardModule.WaffleClipboard {}
    }

    IpcHandler {
        target: "search"
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        function close(): void { GlobalStates.searchOpen = false }
        function open(): void { GlobalStates.searchOpen = true }
    }
    IpcHandler {
        target: "wactionCenter"
        function toggle(): void { GlobalStates.waffleActionCenterOpen = !GlobalStates.waffleActionCenterOpen }
        function close(): void { GlobalStates.waffleActionCenterOpen = false }
        function open(): void { GlobalStates.waffleActionCenterOpen = true }
    }
    IpcHandler {
        target: "wnotificationCenter"
        function toggle(): void { GlobalStates.waffleNotificationCenterOpen = !GlobalStates.waffleNotificationCenterOpen }
        function close(): void { GlobalStates.waffleNotificationCenterOpen = false }
        function open(): void { GlobalStates.waffleNotificationCenterOpen = true }
    }
    IpcHandler {
        target: "wwidgets"
        function toggle(): void { GlobalStates.waffleWidgetsOpen = !GlobalStates.waffleWidgetsOpen }
        function close(): void { GlobalStates.waffleWidgetsOpen = false }
        function open(): void { GlobalStates.waffleWidgetsOpen = true }
    }
    IpcHandler {
        target: "taskview"
        function toggle(): void { GlobalStates.waffleTaskViewOpen = !GlobalStates.waffleTaskViewOpen }
        function close(): void { GlobalStates.waffleTaskViewOpen = false }
        function open(): void { GlobalStates.waffleTaskViewOpen = true }
    }
    // Shared IPC targets and family-agnostic routers now live in shell.qml,
    // registered once instead of once per family. See the comment there.

    // Waffle AltSwitcher - handles IPC when panelFamily === "waffle"
    LazyLoader {
        loading: Config.ready && GlobalStates.shellEntryReady
            && Config.options?.panelFamily === "waffle"
            && root.waffleAltSwitcherVisual
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady
            && Config.options?.panelFamily === "waffle"
            && root.waffleAltSwitcherVisual
        component: WaffleAltSwitcherModule.WaffleAltSwitcher {}
    }

    // Dedicated editor overlay, created after Waffle panels so its HUD remains
    // above the taskbar and other persistent surfaces.
    WaffleBackgroundModule.WaffleShellEditHud {}
}
