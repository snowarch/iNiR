//@ pragma UseQApplication
//@ pragma ShellId inir
// DISABLED: webapps — requires quickshell-webengine rebuild, re-enable when ready
//-@ pragma EnableQtWebEngineQuick
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QT_LOGGING_RULES=quickshell.dbus.properties=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale
// DISABLED: webapps — requires quickshell-webengine rebuild
//-@ pragma Env QTWEBENGINE_CHROMIUM_FLAGS=--disable-features=ThirdPartyCookieBlocking,StorageAccessAPI

import qs.modules.common
import qs.modules.settings

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    id: root

    readonly property bool disableHotReload: Quickshell.env("INIR_DISABLE_HOT_RELOAD") === "1"
        || Quickshell.env("INIR_DISABLE_HOT_RELOAD") === "true"

    function _log(msg: string): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(msg);
    }

    // Force singleton instantiation — startup-critical only
    property var _idleService: Idle
    property var _powerProfilePersistence: PowerProfilePersistence
    property var _devNavigationService: DevNavigation
    property var _shellEditSessionService: ShellEditSession
    // Acquire org.kde.StatusNotifierWatcher before graphical-session.target
    // releases XDG autostart applications. The systemd unit uses Type=dbus.
    property var _trayService: TrayService
    property var _globalActionsService

    // Deferred singletons — initialized after first frame to reduce boot contention
    // Tier 3: T+500ms (display/interaction services)
    property var _gameModeService
    property var _windowPreviewService
    property var _weatherService
    property var _voiceSearchService
    property var _fontSyncService
    property var _cavaThemeService
    // Screen Time must exist for the whole enabled session, not only after its
    // sidebar page is first opened. It is explicitly materialized after the
    // first frame and when the user enables tracking later.
    property var _screenTimeService
    function _ensureScreenTimeService(): void {
        if (GlobalStates.deferredPanelsReady
                && (Config.options?.sidebar?.screenTime?.enable ?? false))
            root._screenTimeService = ScreenTime
    }
    // Tier 4: T+1500ms (background features - updates, sync, content services)
    property var _shellUpdatesService
    property var _autostartService
    property var _calendarSyncService
    property var _todoService
    property var _notepadService

    // Boot phase timing (ms since epoch). Written to ~/.cache/inir/last-boot.json
    // when the deferred phase finishes. `inir status` reads this back to show users
    // exactly where their startup time goes — systemd → qs launch → QML completed →
    // Config ready → shell entry → deferred services. Useful for triaging "15-20s startup"
    // reports without asking the user to run journalctl.
    property real _bootCompletedAt: 0
    property real _bootConfigReadyAt: 0
    property real _bootShellEntryAt: 0
    property real _bootDeferredAt: 0
    readonly property string _bootCachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/inir/last-boot.json"

    Component.onCompleted: {
        root._bootCompletedAt = Date.now();
        console.info("[Boot] T+0ms: Component.onCompleted (shell.qml ready)");
        Quickshell.watchFiles = !disableHotReload;
        
        // Tier 0: startup-critical singletons (no delay)
        root._log("[Boot] Tier 0: startup-critical singletons");
        FirstRunExperience.load();
        ConflictKiller.load();
        // Force MemoryPressureService instantiation for IPC (#164)
        void MemoryPressureService.enabled;
        // Same reason: GlobalActions owns the `globalActions` IPC target and is
        // otherwise only constructed when the command palette first opens, so
        // scripts and keybinds got "Target not found" until then. Tier 0 also
        // keeps the gap after a config reload as short as every other handler's.
        root._globalActionsService = GlobalActions;
        DevNavigation.registerSettingsPages(SettingsPageRegistry.pages);
        
        // Reset shell entry state (hot-reload may preserve singletons)
        GlobalStates.shellEntryReady = false;
        GlobalStates.deferredPanelsReady = false;
        
        if (Config.ready) {
            root._bootConfigReadyAt = Date.now();
            console.info("[Boot] T+" + (root._bootConfigReadyAt - root._bootCompletedAt) + "ms: Config.ready (immediate)");
            // Config was already ready before this root was (re)built (hot-reload / preserved
            // singletons). onReadyChanged won't fire, so apply theme + icons here too,
            // otherwise the shell comes up with stale/unthemed colors and icons.
            Qt.callLater(() => ThemeService.applyCurrentTheme());
            Qt.callLater(() => IconThemeService.ensureInitialized());
            shellEntryTimer.start();
        }
    }

    // Shell entry animation: panels start hidden, slide in after a brief delay
    // 200ms is enough for LazyLoader panels to be created on warm cache;
    // on cold boot the progressive slide-in is better UX than extra blank time
    // Tier 1-2: Implicit — UI-critical services load with panels (Audio, Battery, etc.)
    Timer {
        id: shellEntryTimer
        interval: Appearance.animationsEnabled ? 200 : 0
        repeat: false
        onTriggered: {
            if (!root._bootShellEntryAt) root._bootShellEntryAt = Date.now();
            console.info("[Boot] T+" + (root._bootShellEntryAt - root._bootCompletedAt) + "ms: shellEntryReady (first frame)");
            GlobalStates.shellEntryReady = true;
            deferredInitTimer.start();
        }
    }

    // Deferred initialization: load non-critical services and panels after the first frame
    // is rendered, spreading startup work over time to reduce the boot contention burst
    // Tier 3: T+500ms — display/interaction services needed soon after first frame
    Timer {
        id: deferredInitTimer
        interval: 500
        repeat: false
        onTriggered: {
            root._log("[Boot] T+" + (Date.now() - root._bootCompletedAt) + "ms: Tier 3 (display/interaction)");
            root._gameModeService = GameMode;
            root._windowPreviewService = WindowPreviewService;
            root._weatherService = Weather;
            root._voiceSearchService = VoiceSearch;
            root._fontSyncService = FontSyncService;
            root._cavaThemeService = CavaTheme;
            Hyprsunset.load();
            GlobalStates.deferredPanelsReady = true;
            root._ensureScreenTimeService();
            // Boot greeting: show once per session (singleton preserves bootGreetingDone across hot-reload)
            if (!GlobalStates.bootGreetingDone && (Config.options?.bootGreeting?.enable ?? true)) {
                GlobalStates.bootGreetingOpen = true;
            }
            if (!root._bootDeferredAt) {
                root._bootDeferredAt = Date.now();
            }
            // Kick off Tier 4 loading
            lateFeaturesTimer.start();
        }
    }

    Connections {
        target: Config
        function onConfigChanged(): void {
            root._ensureScreenTimeService()
        }
    }

    // Tier 4: T+1500ms — background features that can wait (updates, sync, content)
    // These services do background work (network requests, file I/O) that doesn't affect UX
    property real _bootLateFeaturesAt: 0
    Timer {
        id: lateFeaturesTimer
        interval: 1000  // +1000ms after Tier 3 = T+1500ms total
        repeat: false
        onTriggered: {
            root._log("[Boot] T+" + (Date.now() - root._bootCompletedAt) + "ms: Tier 4 (background features)");
            root._shellUpdatesService = ShellUpdates;
            root._autostartService = Autostart;
            root._calendarSyncService = CalendarSync;
            root._todoService = Todo;
            root._notepadService = Notepad;
            root._bootLateFeaturesAt = Date.now();
            root._writeBootPhase();
        }
    }

    // Persist boot phase timestamps so `inir status` can report startup breakdown
    // without asking the user to run journalctl. Only written once per boot — hot-reloads
    // overwrite (which is intentional, latest run is what matters for diagnostics).
    function _writeBootPhase(): void {
        if (!root._bootCompletedAt) return;
        const data = {
            componentCompletedAt: Math.floor(root._bootCompletedAt),
            configReadyAt: Math.floor(root._bootConfigReadyAt),
            shellEntryAt: Math.floor(root._bootShellEntryAt),
            deferredReadyAt: Math.floor(root._bootDeferredAt),
            lateFeaturesAt: Math.floor(root._bootLateFeaturesAt),
            // Deltas for easier analysis
            deltas: {
                configReady: Math.floor(root._bootConfigReadyAt - root._bootCompletedAt),
                shellEntry: Math.floor(root._bootShellEntryAt - root._bootConfigReadyAt),
                deferred: Math.floor(root._bootDeferredAt - root._bootShellEntryAt),
                lateFeatures: Math.floor(root._bootLateFeaturesAt - root._bootDeferredAt)
            },
            shellPid: Quickshell.processId,
            writtenAt: Math.floor(Date.now())
        };
        bootPhaseWriter.setText(JSON.stringify(data, null, 2));
    }

    FileView {
        id: bootPhaseWriter
        path: root._bootCachePath
        printErrors: false
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                if (!root._bootConfigReadyAt) {
                    root._bootConfigReadyAt = Date.now();
                    console.info("[Boot] T+" + (root._bootConfigReadyAt - root._bootCompletedAt) + "ms: Config.ready (async)");
                }
                root._log("[Boot] Applying theme and icon theme");
                Qt.callLater(() => ThemeService.applyCurrentTheme());
                Qt.callLater(() => IconThemeService.ensureInitialized());
                // Kick off shell entry animation after panels have been created.
                // Tier 3 is scheduled by shellEntryTimer so its 500 ms delay is
                // measured from the first frame, not concurrently with it.
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

        // Only add genuinely NEW panels (from updates), not panels the user deliberately disabled.
        // knownPanels tracks what the user has seen. If a panel is in knownPanels but not in
        // enabledPanels, the user removed it — don't re-add.
        const basePanels = root.panelFamilies[family] ?? [];
        let known = [...(Config.options?.knownPanels ?? [])];
        const isFirstRun = known.length === 0;

        if (isFirstRun) {
            // First boot with this logic — seed knownPanels with ALL families' panels.
            // This prevents re-adding panels that existing users already disabled,
            // including across family switches.
            const allPanels = [];
            for (const fam of root.families) {
                for (const p of (root.panelFamilies[fam] ?? [])) {
                    if (!allPanels.includes(p)) allPanels.push(p);
                }
            }
            Config.setNestedValue("knownPanels", allPanels);
        } else {
            // Subsequent boots: only add panels that are new (not in knownPanels)
            let knownChanged = false;
            for (const panel of basePanels) {
                if (!known.includes(panel)) {
                    // Genuinely new panel from an update
                    if (!panels.includes(panel)) {
                        root._log("[Shell] Adding new panel to enabledPanels: " + panel);
                        panels.push(panel);
                        changed = true;
                    }
                    known.push(panel);
                    knownChanged = true;
                }
            }
            if (knownChanged) {
                Config.setNestedValue("knownPanels", known);
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

    // IPC target "bar" — registered once here (always loaded) instead of inside
    // Bar.qml / VerticalBar.qml. Both ii bars are instantiated together, so a
    // per-bar handler collided and Quickshell dropped one with a warning. All
    // three bars only toggle GlobalStates.barOpen, so a single shared handler is
    // family-agnostic and serves the horizontal bar, vertical bar and waffle.
    IpcHandler {
        target: "bar"
        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }
        function close(): void {
            GlobalStates.barOpen = false
        }
        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    // ii interaction routers stay resident with the root so commands remain
    // available while the heavier family panel tree is deferred.
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
        function toggle(): void { GlobalStates.toggleSidebarLeft("") }
        function close(): void { GlobalStates.closeSidebarLeft() }
        function open(): void { GlobalStates.openSidebarLeft("") }
        function expand(): void {
            GlobalStates.aiChatDetached = false
            GlobalStates.openSidebarLeft("")
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
            GlobalStates.openSidebarLeft("")
        }
    }

    IpcHandler {
        target: "sidebarRight"
        function toggle(): void { GlobalStates.toggleSidebarRight("") }
        function close(): void { GlobalStates.closeSidebarRight() }
        function open(): void { GlobalStates.openSidebarRight("") }
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

    // Waffle interaction routers are also root-owned so commands remain
    // available while the heavier Waffle host is deferred.
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
        function _isWaffle(): bool { return (Config.options?.panelFamily ?? "ii") === "waffle" }
        function toggle(): void {
            if (_isWaffle()) { GlobalStates.waffleTaskViewOpen = !GlobalStates.waffleTaskViewOpen; return }
            if (CompositorService.isNiri) GlobalStates.toggleOrbit("")
        }
        function close(): void {
            if (_isWaffle()) { GlobalStates.waffleTaskViewOpen = false; return }
            if (GlobalStates.overviewMode === "orbit") GlobalStates.closeOverview()
        }
        function open(): void {
            if (_isWaffle()) { GlobalStates.waffleTaskViewOpen = true; return }
            if (CompositorService.isNiri) GlobalStates.openOrbit("")
        }
    }

    IpcHandler {
        target: "orbit"
        function toggle(): void { if (CompositorService.isNiri) GlobalStates.toggleOrbit("") }
        function close(): void { if (GlobalStates.overviewMode === "orbit") GlobalStates.closeOverview() }
        function open(): void { if (CompositorService.isNiri) GlobalStates.openOrbit("") }
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

    // One owner for settingsNav, here rather than inside a chrome. Both overlay
    // layouts used to declare this target themselves; switching layouts leaves
    // the outgoing host alive for a moment, so Quickshell saw two registrations
    // and silently dropped one — the caller then hit whichever survived. Routing
    // through GlobalStates keeps the target valid no matter which chrome, or
    // none, is loaded.
    IpcHandler {
        target: "settingsNav"
        function page(index: int): void {
            GlobalStates.openSettingsPage(index)
        }
        function count(): int { return SettingsPageRegistry.pages.length }
        function current(): int { return GlobalStates.settingsOverlayCurrentPage }
    }

    // Settings overlay panel (loaded only when overlay mode is enabled).
    // overlayStyle picks the chrome; two sibling loaders instead of a
    // conditional `component:` so only the selected one is ever constructed.
    // Any unrecognised style falls back to the nav rail.
    LazyLoader {
        active: Config.ready && (Config.options?.settingsUi?.overlayMode ?? false)
            && (Config.options?.settingsUi?.overlayStyle ?? "rail") !== "focus"
        component: SettingsOverlay {}
    }

    LazyLoader {
        active: Config.ready && (Config.options?.settingsUi?.overlayMode ?? false)
            && (Config.options?.settingsUi?.overlayStyle ?? "rail") === "focus"
        component: SettingsFocus {}
    }

    // === Panel Loaders ===
    // Keep one permanent IPC router so mode/family changes never overlap two
    // `altSwitcher` handlers during Loader teardown. The heavy ii visual tree is
    // present only for visual ii presets; the router handles no-UI cycling and
    // forwards visual commands to ii internally or to Waffle's family module.
    readonly property bool iiAltSwitcherNoVisual:
        (Config.options?.altSwitcher?.noVisualUi ?? false)
        && (Config.options?.altSwitcher?.preset ?? "default") !== "skew"

    LazyLoader {
        active: Config.ready
        source: "modules/altSwitcher/AltSwitcherNoVisual.qml"
    }

    LazyLoader {
        active: Config.ready
            && (Config.options?.panelFamily ?? "ii") !== "waffle"
            && !root.iiAltSwitcherNoVisual
        source: "modules/altSwitcher/AltSwitcher.qml"
    }

    // Load ONLY the active family panels to reduce startup time.
    // Using `source:` instead of `component:` to avoid parsing inactive family at compile time.
    // This saves ~135 file parses when using ii family (waffle not parsed) and vice versa.
    // Family-agnostic IPC routers. Both panel files used to instantiate their
    // own copy, so during a family switch — when the outgoing loader is still
    // being torn down — two instances existed and Quickshell dropped one
    // handler per target (region, tiling, wallpaperSelector, coverflowSelector).
    // One owner here is valid whichever family is loaded.
    LazyLoader { active: Config.ready; source: "modules/regionSelector/RegionSelectorRouter.qml" }
    LazyLoader { active: Config.ready; source: "modules/tilingOverlay/TilingOverlayRouter.qml" }
    LazyLoader { active: Config.ready; source: "modules/wallpaperSelector/WallpaperSelectorRouter.qml" }

    // Same reason as the routers: both panel files declared these, so every
    // family switch registered them twice and Quickshell kept whichever won the
    // race — sometimes the handler belonging to the family being torn down.
    // The four below were byte-identical in both files; only overview differs,
    // so it branches here instead of existing twice.
    IpcHandler {
        target: "osk"
        function toggle(): void { GlobalStates.oskOpen = !GlobalStates.oskOpen }
        function close(): void { GlobalStates.oskOpen = false }
        function open(): void { GlobalStates.oskOpen = true }
    }

    IpcHandler {
        target: "overlay"
        function toggle(): void { GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
    }

    IpcHandler {
        target: "session"
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        function close(): void { GlobalStates.sessionOpen = false }
        function open(): void { GlobalStates.sessionOpen = true }
    }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
        function close(): void { GlobalStates.cheatsheetOpen = false }
        function open(): void { GlobalStates.cheatsheetOpen = true }
    }

    IpcHandler {
        target: "clipboard"
        function _isWaffle(): bool { return (Config.options?.panelFamily ?? "ii") === "waffle" }
        function open(): void {
            if (_isWaffle()) GlobalStates.waffleClipboardOpen = true
            else GlobalStates.clipboardOpen = true
        }
        function close(): void {
            if (_isWaffle()) GlobalStates.waffleClipboardOpen = false
            else GlobalStates.clipboardOpen = false
        }
        function toggle(): void {
            if (_isWaffle()) GlobalStates.waffleClipboardOpen = !GlobalStates.waffleClipboardOpen
            else GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen
        }
    }

    IpcHandler {
        target: "overview"
        function _isWaffle(): bool { return (Config.options?.panelFamily ?? "ii") === "waffle" }
        function _usePillLauncher(): bool {
            return !_isWaffle()
                && (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"
                && (Config.options?.bar?.pill?.superSpaceLauncher ?? "overview") === "pill"
        }
        function toggle(): void {
            if (_isWaffle()) { GlobalStates.searchOpen = !GlobalStates.searchOpen; return }
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("toggle", "launcher"); return }
            GlobalStates.overviewSearchPrefix = ""
            GlobalStates.toggleOverview("")
        }
        function close(): void {
            if (_isWaffle()) { GlobalStates.searchOpen = false; return }
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("close", "launcher"); return }
            GlobalStates.overviewOpen = false
        }
        function open(): void {
            if (_isWaffle()) { GlobalStates.searchOpen = true; return }
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("open", "launcher"); return }
            GlobalStates.overviewSearchPrefix = ""
            GlobalStates.openOverview("")
        }
        function toggleReleaseInterrupt(): void { GlobalStates.superReleaseMightTrigger = false }
        function clipboardToggle(): void {
            const prefix = Config.options?.search?.prefix?.clipboard ?? ";"
            if (_isWaffle()) {
                LauncherSearch.ensurePrefix(prefix)
                GlobalStates.searchOpen = true
                return
            }
            if (GlobalStates.overviewOpen && GlobalStates.overviewSearchPrefix.length > 0) {
                GlobalStates.overviewOpen = false
            } else {
                GlobalStates.overviewSearchPrefix = prefix
                GlobalStates.openOverview("")
            }
        }
        function actionOpen(): void {
            const prefix = Config.options?.search?.prefix?.action ?? "/"
            if (_isWaffle()) {
                LauncherSearch.ensurePrefix(prefix)
                GlobalStates.searchOpen = true
                return
            }
            GlobalStates.overviewSearchPrefix = prefix
            GlobalStates.openOverview("")
        }
    }

    LazyLoader {
        loading: Config.ready && (Config.options?.panelFamily ?? "ii") !== "waffle"
        activeAsync: Config.ready && (Config.options?.panelFamily ?? "ii") !== "waffle"
        source: "modules/ii/critical/ShellIiCriticalPanels.qml"
    }

    LazyLoader {
        readonly property bool enabled: Config.ready
            && GlobalStates.deferredPanelsReady
            && (Config.options?.panelFamily ?? "ii") !== "waffle"
        loading: enabled
        activeAsync: enabled
        source: "ShellIiPanels.qml"
    }

    LazyLoader {
        loading: Config.ready && (Config.options?.panelFamily ?? "ii") === "waffle"
        activeAsync: Config.ready && (Config.options?.panelFamily ?? "ii") === "waffle"
        source: "modules/waffle/critical/ShellWaffleCriticalPanels.qml"
    }

    LazyLoader {
        readonly property bool enabled: Config.ready
            && GlobalStates.deferredPanelsReady
            && (Config.options?.panelFamily ?? "ii") === "waffle"
        loading: enabled
        activeAsync: enabled
        source: "ShellWafflePanels.qml"
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; source: "modules/closeConfirm/CloseConfirm.qml" }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // === Panel Families ===
    // AltSwitcher controller selection lives above the family loaders. Waffle
    // receives the lightweight shared router; ii receives either that controller
    // or the full visual tree according to its no-visual setting.
    property list<string> families: ["ii", "waffle"]
    property var panelFamilies: ({
        "ii": [
            "iiBar", "iiBackground", "iiBackdrop", "iiBootGreeting", "iiCheatsheet", "iiControlPanel", "iiDock", "iiLock",
            "iiMediaControls", "iiNotificationPopup", "iiOnScreenDisplay", "iiOnScreenKeyboard",
            "iiOverlay", "iiOverview", "iiPolkit", "iiRegionSelector", "iiScreenCorners",
            "iiSessionScreen", "iiSidebarLeft", "iiSidebarRight", "iiTilingOverlay", "iiVerticalBar",
            "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard", "iiShellUpdate", "iiRecordingOsd", "iiDashboard",
            "iiMascotCompanion"
        ],
        "waffle": [
            "wBar", "wBackground", "wBackdrop", "wStartMenu", "wActionCenter", "wNotificationCenter", "wNotificationPopup", "wOnScreenDisplay", "wWidgets", "wTaskView", "wLock", "wPolkit", "wSessionScreen",
            // Shared modules that work with waffle
            // WaffleAltSwitcher is family-local and loaded by ShellWafflePanels;
            // the shared `altSwitcher` target reaches it through the lightweight router.
            "iiBootGreeting", "iiCheatsheet", "iiOnScreenKeyboard", "iiOverlay", "iiOverview",
            "iiRegionSelector", "iiScreenCorners", "iiWallpaperSelector", "iiWallpaperLauncher", "iiCoverflowSelector", "iiClipboard",
            "iiMascotCompanion"
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

        // Update knownPanels so the new family's panels are tracked before the user can disable them
        const known = [...(Config.options?.knownPanels ?? [])]
        let knownChanged = false
        for (const panel of basePanels) {
            if (!known.includes(panel)) {
                known.push(panel)
                knownChanged = true
            }
        }
        if (knownChanged) Config.setNestedValue("knownPanels", known)
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
        // A transition that never finished used to wedge every later switch:
        // the guard stayed true, so this returned silently, and because the
        // overlay was never armed its own watchdog could not run either. If the
        // overlay is not actually up, the flag is stale — clear it and proceed.
        if (_transitionInProgress && !GlobalStates.familyTransitionActive) {
            console.warn("[FamilyTransition] stale in-progress flag cleared")
            _transitionInProgress = false
        }
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

    // Family transition overlay stays absent outside a real family switch, so
    // the inactive family's visual tree and font/token imports are not retained.
    Loader {
        active: Config.ready
            && (GlobalStates.familyTransitionActive || root._transitionInProgress)
        source: "FamilyTransitionOverlay.qml"
        onLoaded: {
            item.exitComplete.connect(root.applyPendingFamily)
            item.enterComplete.connect(root.finishFamilyTransition)
        }
    }

    IpcHandler {
        target: "panelFamily"
        function cycle(): void { root.cyclePanelFamily() }
        function set(family: string): void { root.setPanelFamily(family) }
    }
}
