//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.background
import qs.modules.bar
import qs.modules.cheatsheet
import qs.modules.dock
import qs.modules.lock
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.onScreenKeyboard
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.sidebarLeft
import qs.modules.sidebarRight
import qs.modules.verticalBar
import qs.modules.wallpaperSelector
import qs.modules.altSwitcher
import qs.modules.ii.overlay
import qs.modules.closeConfirm
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
import qs.services

ShellRoot {
    id: root

    // Force singleton instantiation
    property var _idleService: Idle
    property var _gameModeService: GameMode
    property var _windowPreviewService: WindowPreviewService

    Component.onCompleted: {
        console.log("[Shell] Initializing singletons");
        Hyprsunset.load();
        FirstRunExperience.load();
        ConflictKiller.load();
        Cliphist.refresh();
        Wallpapers.load();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                console.log("[Shell] Config ready, applying theme");
                ThemeService.applyCurrentTheme();
                // Only reset enabledPanels if it's empty or undefined (first run / corrupted config)
                if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0) {
                    const family = Config.options?.panelFamily ?? "ii"
                    if (root.families.includes(family)) {
                        Config.options.enabledPanels = root.panelFamilies[family]
                    }
                }
                // Migration: Ensure waffle family has wBackdrop instead of iiBackdrop
                root.migrateEnabledPanels();
            }
        }
    }

    // Migrate enabledPanels for users upgrading from older versions
    property bool _migrationDone: false
    function migrateEnabledPanels() {
        if (_migrationDone) return;
        _migrationDone = true;
        
        const family = Config.options?.panelFamily ?? "ii";
        const panels = Config.options?.enabledPanels ?? [];
        
        if (family === "waffle") {
            // If waffle family has iiBackdrop but not wBackdrop, migrate
            const hasIiBackdrop = panels.includes("iiBackdrop");
            const hasWBackdrop = panels.includes("wBackdrop");
            
            if (hasIiBackdrop && !hasWBackdrop) {
                console.log("[Shell] Migrating enabledPanels: replacing iiBackdrop with wBackdrop for waffle family");
                const newPanels = panels.filter(p => p !== "iiBackdrop");
                newPanels.push("wBackdrop");
                Config.options.enabledPanels = newPanels;
            }
        }
    }

    // IPC for settings
    IpcHandler {
        target: "settings"
        function open(): void {
            // Use waffle settings if enabled and panel family is waffle
            if (Config.options?.panelFamily === "waffle" && Config.options?.waffles?.settings?.useMaterialStyle !== true) {
                waffleSettingsProcess.running = true
            } else {
                settingsProcess.running = true
            }
        }
    }
    Process {
        id: settingsProcess
        command: ["qs", "-n", "-p", Quickshell.shellPath("settings.qml")]
    }
    Process {
        id: waffleSettingsProcess
        command: ["qs", "-n", "-p", Quickshell.shellPath("waffleSettings.qml")]
    }

    // === Panel Loaders ===
    // ii style (Material)
    PanelLoader { identifier: "iiBar"; extraCondition: !(Config.options?.bar?.vertical ?? false); component: Bar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    PanelLoader { identifier: "iiLock"; component: Lock {} }
    PanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    PanelLoader { identifier: "iiNotificationPopup"; component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; component: OnScreenDisplay {} }
    PanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    PanelLoader { identifier: "iiOverview"; component: Overview {} }
    PanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    PanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    PanelLoader { identifier: "iiSessionScreen"; component: SessionScreen {} }
    PanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    PanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: Config.options?.bar?.vertical ?? false; component: VerticalBar {} }
    PanelLoader { identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }
    // Material ii AltSwitcher - handles IPC when panelFamily !== "waffle"
    LazyLoader { active: Config.ready; component: AltSwitcher {} }
    PanelLoader { identifier: "iiClipboard"; component: ClipboardModule.ClipboardPanel {} }

    // Waffle style (Windows 11)
    PanelLoader { identifier: "wBar"; component: WaffleBarModule.WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wStartMenu"; component: WaffleStartMenu {} }
    PanelLoader { identifier: "wActionCenter"; component: WaffleActionCenter {} }
    PanelLoader { identifier: "wNotificationCenter"; component: WaffleNotificationCenter {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }
    PanelLoader { identifier: "wWidgets"; extraCondition: Config.options?.waffles?.modules?.widgets ?? true; component: WaffleWidgets {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && Config.options?.panelFamily === "waffle"; component: WaffleClipboardModule.WaffleClipboard {} }
    // Waffle AltSwitcher - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && Config.options?.panelFamily === "waffle"; component: WaffleAltSwitcherModule.WaffleAltSwitcher {} }
    // Waffle TaskView - experimental, disabled by default
    PanelLoader { identifier: "wTaskView"; component: WaffleTaskViewModule.WaffleTaskView {} }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; component: CloseConfirm {} }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // === PanelLoader Component ===
    // Uses LazyLoader - panels load when active and enabled
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // === Panel Families ===
    // Note: iiAltSwitcher is always loaded (not in families) as it acts as IPC router
    // for the unified "altSwitcher" target, redirecting to wAltSwitcher when waffle is active
    property list<string> families: ["ii", "waffle"]
    property var panelFamilies: ({
        "ii": [
            "iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiDock", "iiLock", 
            "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard", 
            "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners", 
            "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiVerticalBar", 
            "iiWallpaperSelector", "iiClipboard"
        ],
        "waffle": [
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets",
            // Shared modules that work with waffle
            // Note: wTaskView is experimental and NOT included by default
            // Note: wAltSwitcher is always loaded when waffle is active (not in this list)
            "iiCheatsheet", "iiLock", "iiOnScreenKeyboard", "iiOverlay", "iiOverview", "iiPolkit", 
            "iiRegionSelector", "iiScreenCorners", "iiSessionScreen", "iiWallpaperSelector", "iiClipboard"
        ]
    })

    // === Panel Family Transition ===
    property string _pendingFamily: ""
    property bool _transitionInProgress: false

    function cyclePanelFamily() {
        const currentFamily = Config.options?.panelFamily ?? "ii"
        const currentIndex = families.indexOf(currentFamily)
        const nextIndex = (currentIndex + 1) % families.length
        const nextFamily = families[nextIndex]
        
        // Determine direction: ii -> waffle = left, waffle -> ii = right
        const direction = nextIndex > currentIndex ? "left" : "right"
        root.startFamilyTransition(nextFamily, direction)
    }

    function setPanelFamily(family: string) {
        const currentFamily = Config.options?.panelFamily ?? "ii"
        if (families.includes(family) && family !== currentFamily) {
            const currentIndex = families.indexOf(currentFamily)
            const nextIndex = families.indexOf(family)
            const direction = nextIndex > currentIndex ? "left" : "right"
            root.startFamilyTransition(family, direction)
        }
    }

    function startFamilyTransition(targetFamily: string, direction: string) {
        if (_transitionInProgress) return
        
        // If animation is disabled, switch instantly
        if (!(Config.options?.familyTransitionAnimation ?? true)) {
            Config.options.panelFamily = targetFamily
            Config.options.enabledPanels = panelFamilies[targetFamily]
            return
        }
        
        _transitionInProgress = true
        _pendingFamily = targetFamily
        GlobalStates.familyTransitionDirection = direction
        GlobalStates.familyTransitionActive = true
    }

    function applyPendingFamily() {
        if (_pendingFamily && families.includes(_pendingFamily)) {
            Config.options.panelFamily = _pendingFamily
            Config.options.enabledPanels = panelFamilies[_pendingFamily]
        }
        _pendingFamily = ""
    }

    function finishFamilyTransition() {
        _transitionInProgress = false
        GlobalStates.familyTransitionActive = false
    }

    // Family transition overlay
    FamilyTransitionOverlay {
        onExitComplete: root.applyPendingFamily()
        onEnterComplete: root.finishFamilyTransition()
    }

    IpcHandler {
        target: "panelFamily"
        function cycle(): void { root.cyclePanelFamily() }
        function set(family: string): void { root.setPanelFamily(family) }
    }
}
