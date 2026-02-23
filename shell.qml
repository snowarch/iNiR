//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import qs.modules.common
import qs.modules.altSwitcher
import qs.modules.closeConfirm
import qs.modules.settings

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    function _log(msg: string): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(msg);
    }

    // Force singleton instantiation
    property var _idleService: Idle
    property var _gameModeService: GameMode
    property var _windowPreviewService: WindowPreviewService
    property var _weatherService: Weather
    property var _powerProfilePersistence: PowerProfilePersistence
    property var _voiceSearchService: VoiceSearch
    property var _fontSyncService: FontSyncService

    Component.onCompleted: {
        root._log("[Shell] Initializing singletons");
        Hyprsunset.load();
        FirstRunExperience.load();
        ConflictKiller.load();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root._log("[Shell] Config ready, applying theme");
                Qt.callLater(() => ThemeService.applyCurrentTheme());
                Qt.callLater(() => IconThemeService.ensureInitialized());
                // Only reset enabledPanels if it's empty or undefined (first run / corrupted config)
                if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0) {
                    const family = Config.options?.panelFamily ?? "inir"
                    if (root.families.includes(family)) {
                        Config.options.enabledPanels = root.panelFamilies[family]
                    }
                }
                // Migration: Ensure waffle family has wBackdrop instead of inirBackdrop
                root.migrateEnabledPanels();
            }
        }
    }

    // Migrate enabledPanels for users upgrading from older versions
    property bool _migrationDone: false
    function migrateEnabledPanels() {
        if (_migrationDone) return;
        _migrationDone = true;

        const family = Config.options?.panelFamily ?? "inir";
        let panels = [...(Config.options?.enabledPanels ?? [])];
        let changed = false;

        // Ensure all base panels for current family are present (adds new panels from updates)
        const basePanels = root.panelFamilies[family] ?? [];
        for (const panel of basePanels) {
            if (!panels.includes(panel)) {
                root._log("[Shell] Adding new panel to enabledPanels: " + panel);
                panels.push(panel);
                changed = true;
            }
        }

        if (family === "waffle") {
            // If waffle family has inirBackdrop but not wBackdrop, migrate
            const hasInirBackdrop = panels.includes("inirBackdrop");
            const hasWBackdrop = panels.includes("wBackdrop");

            if (hasInirBackdrop && !hasWBackdrop) {
                root._log("[Shell] Migrating enabledPanels: replacing inirBackdrop with wBackdrop for waffle family");
                panels = panels.filter(p => p !== "inirBackdrop");
                panels.push("wBackdrop");
                changed = true;
            }
        }

        if (changed) {
            Config.options.enabledPanels = panels;
        }
    }

    // IPC for settings - overlay mode or separate window based on config
    // Note: waffle family ALWAYS uses its own window (waffleSettings.qml), never the Material overlay
    IpcHandler {
        target: "settings"
        function open(): void {
            const isWaffle = Config.options?.panelFamily === "waffle"
                && Config.options?.waffles?.settings?.useMaterialStyle !== true

            if (isWaffle) {
                // Waffle always opens its own Win11-style settings window
                Quickshell.execDetached(["/usr/bin/qs", "-n", "-p",
                    Quickshell.shellPath("waffleSettings.qml")])
            } else if (Config.options?.settingsUi?.overlayMode ?? false) {
                // inir overlay mode — toggle inline panel
                GlobalStates.settingsOverlayOpen = !GlobalStates.settingsOverlayOpen
            } else {
                // inir window mode (default) — launch separate process
                Quickshell.execDetached(["/usr/bin/qs", "-n", "-p",
                    Quickshell.shellPath("settings.qml")])
            }
        }
        function toggle(): void {
            open()
        }
    }

    // Settings overlay panel (loaded only when overlay mode is enabled)
    LazyLoader {
        active: Config.ready && (Config.options?.settingsUi?.overlayMode ?? false)
        component: SettingsOverlay {}
    }

    // === Panel Loaders ===
    // AltSwitcher IPC router (material/waffle)
    LazyLoader { active: Config.ready; component: AltSwitcher {} }

    // Load ONLY the active family panels to reduce startup time.
    LazyLoader {
        active: Config.ready && (Config.options?.panelFamily ?? "inir") !== "waffle"
        component: ShellInirPanels { }
    }

    LazyLoader {
        active: Config.ready && (Config.options?.panelFamily ?? "inir") === "waffle"
        component: ShellWafflePanels { }
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; component: CloseConfirm {} }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // === Panel Families ===
    // Note: inirAltSwitcher is always loaded (not in families) as it acts as IPC router
    // for the unified "altSwitcher" target, redirecting to wAltSwitcher when waffle is active
    property list<string> families: ["inir", "waffle"]
    property var panelFamilies: ({
        "inir": [
            "inirBar", "inirBackground", "inirBackdrop", "inirCheatsheet", "inirControlPanel", "inirDock", "inirLock",
            "inirMediaControls", "inirNotificationPopup", "inirOnScreenDisplay", "inirOnScreenKeyboard",
            "inirOverlay", "inirOverview", "inirPolkit", "inirRegionSelector", "inirScreenCorners",
            "inirSessionScreen", "inirSidebarLeft", "inirSidebarRight", "inirTilingOverlay", "inirVerticalBar",
            "inirWallpaperSelector", "inirClipboard"
        ],
        "waffle": [
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wLock", "wPolkit", "wSessionScreen",
            // Shared modules that work with waffle
            // Note: wTaskView is experimental and NOT included by default
            // Note: wAltSwitcher is always loaded when waffle is active (not in this list)
            "inirCheatsheet", "inirControlPanel", "inirLock", "inirOnScreenKeyboard", "inirOverlay", "inirOverview", "inirPolkit",
            "inirRegionSelector", "inirScreenCorners", "inirSessionScreen", "inirTilingOverlay", "inirWallpaperSelector", "inirClipboard"
        ]
    })

    // === Panel Family Transition ===
    property string _pendingFamily: ""
    property bool _transitionInProgress: false

    function _ensureFamilyPanels(family: string): void {
        const basePanels = root.panelFamilies[family] ?? []
        const currentPanels = Config.options?.enabledPanels ?? []

        if (basePanels.length === 0) return
        if (currentPanels.length === 0) {
            Config.options.enabledPanels = [...basePanels]
            return
        }

        const merged = [...currentPanels]
        for (const panel of basePanels) {
            if (!merged.includes(panel)) merged.push(panel)
        }
        Config.options.enabledPanels = merged
    }

    function cyclePanelFamily() {
        const currentFamily = Config.options?.panelFamily ?? "inir"
        const currentIndex = families.indexOf(currentFamily)
        const nextIndex = (currentIndex + 1) % families.length
        const nextFamily = families[nextIndex]

        // Determine direction: inir -> waffle = left, waffle -> inir = right
        const direction = nextIndex > currentIndex ? "left" : "right"
        root.startFamilyTransition(nextFamily, direction)
    }

    function setPanelFamily(family: string) {
        const currentFamily = Config.options?.panelFamily ?? "inir"
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
            root._ensureFamilyPanels(targetFamily)
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
            root._ensureFamilyPanels(_pendingFamily)
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
