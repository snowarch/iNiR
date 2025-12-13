//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.altSwitcher
import qs.modules.closeConfirm

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
    // AltSwitcher IPC router (material/waffle)
    LazyLoader { active: Config.ready; component: AltSwitcher {} }

    // Load ONLY the active family panels to reduce startup time.
    LazyLoader {
        active: Config.ready && (Config.options?.panelFamily ?? "ii") !== "waffle"
        component: ShellIiPanels { }
    }

    LazyLoader {
        active: Config.ready && (Config.options?.panelFamily ?? "ii") === "waffle"
        component: ShellWafflePanels { }
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; component: CloseConfirm {} }

    // Shared (always loaded via ToastManager)
    ToastManager {}

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
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wLock", "wPolkit", "wSessionScreen",
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
            const prevPanels = Config.options?.enabledPanels ?? []
            const basePanels = panelFamilies[targetFamily] ?? []
            const prefix = targetFamily === "waffle" ? "w" : "ii"
            const extras = prevPanels.filter(p => p.startsWith(prefix) && !basePanels.includes(p))
            Config.options.panelFamily = targetFamily
            Config.options.enabledPanels = [...basePanels, ...extras]
            return
        }
        
        _transitionInProgress = true
        _pendingFamily = targetFamily
        GlobalStates.familyTransitionDirection = direction
        GlobalStates.familyTransitionActive = true
    }

    function applyPendingFamily() {
        if (_pendingFamily && families.includes(_pendingFamily)) {
            const prevPanels = Config.options?.enabledPanels ?? []
            const basePanels = panelFamilies[_pendingFamily] ?? []
            const prefix = _pendingFamily === "waffle" ? "w" : "ii"
            const extras = prevPanels.filter(p => p.startsWith(prefix) && !basePanels.includes(p))
            Config.options.panelFamily = _pendingFamily
            Config.options.enabledPanels = [...basePanels, ...extras]
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
