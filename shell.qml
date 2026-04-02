//@ pragma UseQApplication
// DISABLED: webapps — requires quickshell-webengine rebuild, re-enable when ready
//-@ pragma EnableQtWebEngineQuick
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale
// DISABLED: webapps — requires quickshell-webengine rebuild
//-@ pragma Env QTWEBENGINE_CHROMIUM_FLAGS=--disable-features=ThirdPartyCookieBlocking,StorageAccessAPI

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
        Quickshell.watchFiles = true;
        root._log("[Shell] Initializing singletons");
        Hyprsunset.load();
        FirstRunExperience.load();
        ConflictKiller.load();
        // Reset shell entry state (hot-reload may preserve singletons)
        GlobalStates.shellEntryReady = false;
        if (Config.ready) shellEntryTimer.start();
    }

    // Shell entry animation: panels start hidden, slide in after a brief delay
    // 400ms ensures LazyLoader panels are created and rendered in hidden state first
    Timer {
        id: shellEntryTimer
        interval: Appearance.animationsEnabled ? 400 : 0
        repeat: false
        onTriggered: GlobalStates.shellEntryReady = true
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                root._log("[Shell] Config ready, applying theme");
                Qt.callLater(() => ThemeService.applyCurrentTheme());
                Qt.callLater(() => IconThemeService.ensureInitialized());
                // Kick off shell entry animation after panels have been created
                shellEntryTimer.start();
                // Only reset enabledPanels if it's empty or undefined (first run / corrupted config)
                if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0) {
                    const family = Config.options?.panelFamily ?? "ii"
                    if (root.families.includes(family)) {
                        Config.setNestedValue("enabledPanels", root.panelFamilies[family])
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
            // If waffle family has iiBackdrop but not wBackdrop, migrate
            const hasIiBackdrop = panels.includes("iiBackdrop");
            const hasWBackdrop = panels.includes("wBackdrop");

            if (hasIiBackdrop && !hasWBackdrop) {
                root._log("[Shell] Migrating enabledPanels: replacing iiBackdrop with wBackdrop for waffle family");
                panels = panels.filter(p => p !== "iiBackdrop");
                panels.push("wBackdrop");
                changed = true;
            }
        }

        const legacyPinnedApps = ["org.gnome.Nautilus", "firefox", "foot"];
        const currentPinnedApps = Config.options?.dock?.pinnedApps ?? [];
        if (currentPinnedApps.length === legacyPinnedApps.length
                && currentPinnedApps.every((panel, idx) => panel === legacyPinnedApps[idx])) {
            root._log("[Shell] Migrating dock.pinnedApps default terminal from foot to kitty");
            Config.setNestedValue("dock.pinnedApps", ["org.gnome.Nautilus", "firefox", "kitty"])
        }

        if (changed)
            Config.setNestedValue("enabledPanels", panels)
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
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"),
                    "waffle-settings-window"])
            } else if (Config.options?.settingsUi?.overlayMode ?? false) {
                // ii overlay mode — toggle inline panel
                GlobalStates.settingsOverlayOpen = !GlobalStates.settingsOverlayOpen
            } else {
                // ii window mode (default) — launch separate process
                Quickshell.execDetached([Quickshell.shellPath("scripts/inir"),
                    "settings-window"])
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
            "iiBar", "iiBackground", "iiBackdrop", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock",
            "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard",
            "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners",
            "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar",
            "iiWallpaperSelector", "iiCoverflowSelector", "iiClipboard"
        ],
        "waffle": [
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wTaskView", "wLock", "wPolkit", "wSessionScreen",
            // Shared modules that work with waffle
            // Note: wAltSwitcher is always loaded when waffle is active (not in this list)
            "iiCheatsheet", "iiControlPanel", "iiOnScreenKeyboard", "iiOverlay", "iiOverview",
            "iiRegionSelector", "iiScreenCorners", "iiTilingOverlay", "iiWallpaperSelector", "iiCoverflowSelector", "iiClipboard"
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
            Config.setNestedValue("enabledPanels", [...basePanels])
            return
        }

        const merged = [...currentPanels]
        for (const panel of basePanels) {
            if (!merged.includes(panel)) merged.push(panel)
        }
        Config.setNestedValue("enabledPanels", merged)
    }

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
            Config.setNestedValue("panelFamily", targetFamily)
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
            Config.setNestedValue("panelFamily", _pendingFamily)
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
