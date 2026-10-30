//@ pragma UseQApplication
//@ pragma ShellId inir
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QT_LOGGING_RULES=quickshell.dbus.properties=false;quickshell.dbus.objectmanager.warning=false;qt.qpa.wayland.textinput.warning=false
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale
// Web apps (sidebar): logins like Discord's need third-party cookies
//@ pragma Env QTWEBENGINE_CHROMIUM_FLAGS=--disable-features=ThirdPartyCookieBlocking,StorageAccessAPI

import qs.modules.common

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.services.deferred

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
    property var _packageSearchService

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
    // `inir undo` answers only once the singleton exists, before anything was removed.
    property var _undoService
    // The community hub answers `inir hub …` from any family; it does nothing until asked.
    property var _hubService
    property var _niriAnimationPresetsService
    property var _calendarSyncService
    property var _todoService
    property var _notepadService

    function _ensureDeferredFamilyServices(): void {
        root._gameModeService = GameMode
        root._fontSyncService = FontSyncService
        if (!Plugins.flag(Plugins.active, "lazyServices")) {
            root._windowPreviewService = WindowPreviewService
            root._weatherService = Weather
            root._voiceSearchService = VoiceSearch
            root._cavaThemeService = CavaTheme
        }
    }

    function _ensureLateFamilyServices(): void {
        root._shellUpdatesService = ShellUpdates
        root._autostartService = Autostart
        root._undoService = Undo
        root._hubService = Hub
        root._niriAnimationPresetsService = NiriAnimationPresets
        if (!Plugins.flag(Plugins.active, "lazyServices")) {
            root._calendarSyncService = CalendarSync
            root._todoService = Todo
            root._notepadService = Notepad
        }
    }

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

    // No hot reload while the screen is locked: a reload tears the session lock down while it is held and leaves the compositor locked
    // with no password prompt. Edits load on the next change or restart.
    Binding {
        target: Quickshell
        property: "watchFiles"
        value: !root.disableHotReload && !GlobalStates.screenLocked
    }
    Connections {
        target: Quickshell
        function onWatchFilesChanged(): void { console.info("[Boot] hot reload", Quickshell.watchFiles ? "on" : "off") }
    }

    Component.onCompleted: {
        root._bootCompletedAt = Date.now();
        console.info("[Boot] T+0ms: Component.onCompleted (shell.qml ready)");
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
        // Public packageSearch IPC must exist before any package UI is opened.
        root._packageSearchService = PackageSearch;
        
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
            // The wallpaper is the first thing anyone sees: its daemon starts with the first frame, not
            // when a late surface first asks for the backend (2.3 s later).
            void AwwwBackend.enabled;
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
            root._ensureDeferredFamilyServices();
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
            if (GlobalStates.deferredPanelsReady)
                root._ensureDeferredFamilyServices()
            if (root._bootLateFeaturesAt > 0)
                root._ensureLateFamilyServices()
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
            root._ensureLateFamilyServices();
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
                root._settlePanels();
            }
        }
    }

    Connections {
        target: Plugins
        function onReadyChanged() { root._settlePanels() }
    }

    // The panel lists come from each family's plugin.json: they settle once both the config and the plugins are read.
    function _settlePanels(): void {
        if (!Config.ready || !Plugins.ready || root._migrationDone) return
        // Only reset enabledPanels if it's empty or undefined (first run / corrupted config)
        if (!Config.options?.enabledPanels || Config.options.enabledPanels.length === 0) {
            const panels = Plugins.panels(Config.options?.panelFamily ?? "ii")
            if (panels.length > 0)
                Config.setNestedValue("enabledPanels", panels)
        }
        root.migrateEnabledPanels();
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
        const basePanels = Plugins.panels(family);
        let known = [...(Config.options?.knownPanels ?? [])];
        const isFirstRun = known.length === 0;

        if (isFirstRun) {
            // First boot with this logic — seed knownPanels with ALL families' panels.
            // This prevents re-adding panels that existing users already disabled,
            // including across family switches.
            const allPanels = [];
            for (const fam of Plugins.families) {
                for (const p of Plugins.panels(fam)) {
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

        // A family that never ran (setup's family pick written straight to the file, a hand edit) has none of its
        // panels: the fresh profile only lists Material's, and iRiS came up as a bare wallpaper.
        if (basePanels.length > 0 && !basePanels.some(p => panels.includes(p))) {
            root._log("[Shell] First start of " + family + ": enabling its panels");
            panels.push(...basePanels.filter(p => !panels.includes(p)));
            changed = true;
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
    // family-agnostic and serves the horizontal bar, vertical bar and any family's bar.
    /// Top bar visibility.
    IpcHandler {
        target: "bar"
        /// How wide the song title gets in Material's bar, 120 to 640 px (the window title gives way); empty to read
        /// it
        function mediaWidth(px: string): string {
            const value = parseInt(px)
            if (value >= 120 && value <= 640) Config.setNestedValue("bar.media.maxWidth", value)
            else if (px.length > 0) return "Use a width from 120 to 640 px"
            return String(value >= 120 && value <= 640 ? value : (Config.options?.bar?.media?.maxWidth ?? 220))
        }
        /// Show/hide bar
        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }
        /// Hide bar
        function close(): void {
            GlobalStates.barOpen = false
        }
        /// Show bar
        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    // Shared OSD entrypoint. Family OSDs observe GlobalStates, so the command
    // remains available even while a family-specific visual tree is deferred.
    /// On-screen volume indicator.
    IpcHandler {
        target: "osdVolume"
        /// Show volume OSD
        function trigger(): void { GlobalStates.osdVolumeOpen = true }
        /// Hide volume OSD
        function hide(): void { GlobalStates.osdVolumeOpen = false }
        /// Toggle volume OSD
        function toggle(): void { GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen }
    }

    /// On-screen feedback for any family. The active family's OSD or Island decides where it is drawn.
    ///
    /// ```kdl
    /// Mod+Shift+K { spawn "inir" "osd" "keyboard"; }
    /// ```
    IpcHandler {
        target: "osd"
        /// Show the volume level
        function volume(): void { GlobalStates.osdVolumeOpen = true }
        /// Show the brightness level
        function brightness(): void { GlobalStates.osdBrightnessOpen = true }
        /// Show the microphone level
        function mic(): void { GlobalStates.osdMicOpen = true }
        /// Show the keyboard layout
        function keyboard(): void { GlobalStates.osdKeyboardLayoutOpen = true }
        /// Show now playing with a transport action: `play`, `pause`, `next` or `previous`
        function media(action: string): string {
            const normalized = action.length === 0 ? "play" : action
            if (!["play", "pause", "next", "previous"].includes(normalized))
                return "Unknown action: play, pause, next or previous"
            GlobalStates.showMediaAction(normalized)
            return normalized
        }
        /// Hide whatever is showing
        function hide(): void {
            GlobalStates.osdVolumeOpen = false
            GlobalStates.osdBrightnessOpen = false
            GlobalStates.osdMicOpen = false
            GlobalStates.osdMediaOpen = false
            GlobalStates.osdKeyboardLayoutOpen = false
        }
    }

    // Keep the SDK command available without paying for widget discovery at
    // startup. The singleton is instantiated only when this IPC is actually
    // used (or a Settings/bar consumer requests it).
    /// Custom widget management. Create, list, reload, and remove user-installed widgets from
    /// `~/.config/inir/widgets/`.
    IpcHandler {
        target: "customWidgets"
        /// Re-scan widgets directory and reload all custom widgets
        function reload(): string {
            CustomWidgets.reload()
            return "Reloading custom widgets..."
        }
        /// List all discovered custom widgets (JSON output)
        function list(): string {
            return JSON.stringify(CustomWidgets.widgets.map(w => ({
                id: w.id, name: w.name, version: w.version,
                valid: w.valid, path: w.dirPath
            })), null, 2)
        }
        /// Create a new widget scaffold in the widgets directory
        function create(name: string): string {
            if (!name || name.length === 0) return "Usage: inir customWidgets create <name>"
            CustomWidgets.create(name)
            return `Creating widget "${name}" in ${CustomWidgets.widgetsDir}/${name}/...`
        }
        /// Remove a custom widget by ID
        function remove(widgetId: string): string {
            if (!widgetId || widgetId.length === 0) return "Usage: inir customWidgets remove <id>"
            CustomWidgets.remove(widgetId)
            return `Removing widget "${widgetId}"...`
        }
    }

    // ii interaction routers stay resident with the root so commands remain
    // available while the heavier family panel tree is deferred.
    /// Quick settings panel. Toggles, sliders, and system controls without opening full settings.
    IpcHandler {
        target: "controlPanel"
        /// Open/close control panel
        function toggle(): void { GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen }
        /// Close control panel
        function close(): void { GlobalStates.controlPanelOpen = false }
        /// Open control panel
        function open(): void { GlobalStates.controlPanelOpen = true }
    }

    /// Centered welcome hub panel (ii family): greeting, clock, notifications, media, weather, calendar, todo, system
    /// usage and GitHub activity.
    IpcHandler {
        target: "dashboard"
        /// Open/close dashboard
        function toggle(): void { GlobalStates.dashboardOpen = !GlobalStates.dashboardOpen }
        /// Close dashboard
        function close(): void { GlobalStates.dashboardOpen = false }
        /// Open dashboard
        function open(): void { GlobalStates.dashboardOpen = true }
    }

    /// Left sidebar: AI chat and apps in Material; the customizable Focus panel in iRiS. In iRiS, `open`, `close` and
    /// `toggle` use the family-owned panel; AI detach and expanded-layout actions apply to Material.
    IpcHandler {
        target: "sidebarLeft"
        /// Open/close left sidebar
        function toggle(): void { GlobalStates.toggleSidebarLeft("") }
        /// Hide left sidebar
        function close(): void { GlobalStates.closeSidebarLeft() }
        /// Show left sidebar
        function open(): void { GlobalStates.openSidebarLeft("") }
        /// Open the sidebar in its wide Ctrl+O layout
        function expand(): void {
            GlobalStates.aiChatDetached = false
            GlobalStates.openSidebarLeft("")
            GlobalStates.sidebarLeftExpanded = true
        }
        /// Return the sidebar to its normal width
        function compact(): void { GlobalStates.sidebarLeftExpanded = false }
        /// Return open, expanded and detached state as JSON
        function status(): string {
            return JSON.stringify({
                open: GlobalStates.sidebarLeftOpen,
                expanded: GlobalStates.sidebarLeftExpanded,
                detached: GlobalStates.aiChatDetached,
            })
        }
        /// Move AI chat into its Ctrl+P standalone window
        function detach(): void {
            GlobalStates.sidebarLeftOpen = false
            GlobalStates.sidebarLeftExpanded = false
            GlobalStates.aiChatDetached = true
        }
        /// Return AI chat from the standalone window to the sidebar
        function attach(): void {
            GlobalStates.aiChatDetached = false
            GlobalStates.sidebarLeftExpanded = false
            GlobalStates.openSidebarLeft("")
        }
    }

    /// Right sidebar: quick toggles, notepad and settings in Material; the customizable Today panel in iRiS.
    IpcHandler {
        target: "sidebarRight"
        /// Open/close right sidebar
        function toggle(): void { GlobalStates.toggleSidebarRight("") }
        /// Hide right sidebar
        function close(): void { GlobalStates.closeSidebarRight() }
        /// Show right sidebar
        function open(): void { GlobalStates.openSidebarRight("") }
    }

    /// Floating media controls panel.
    IpcHandler {
        target: "mediaControls"
        /// Open/close media controls
        function toggle(): void {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
            if (GlobalStates.mediaControlsOpen) Notifications.timeoutAll()
        }
        /// Hide media controls
        function close(): void { GlobalStates.mediaControlsOpen = false }
        /// Show media controls
        function open(): void {
            GlobalStates.mediaControlsOpen = true
            Notifications.timeoutAll()
        }
    }

    /// Waffle start menu / search.
    IpcHandler {
        target: "search"
        /// Open/close start menu
        function toggle(): void { GlobalStates.searchOpen = !GlobalStates.searchOpen }
        /// Close start menu
        function close(): void { GlobalStates.searchOpen = false }
        /// Open start menu
        function open(): void { GlobalStates.searchOpen = true }
    }

    // Shared verbs: the active family answers first (GlobalStates.familyVerbs), Material's behaviour otherwise.
    /// Compatibility entry point for task navigation. On Waffle it opens the Waffle Task View; on ii/Niri it routes
    /// to Orbit.
    IpcHandler {
        target: "taskview"
        /// Open/close the active family's task navigator
        function toggle(): void {
            const verb = GlobalStates.familyVerb("taskview", "toggle")
            if (verb) verb()
            else if (CompositorService.isNiri) GlobalStates.toggleOrbit("")
        }
        /// Close the active family's task navigator
        function close(): void {
            const verb = GlobalStates.familyVerb("taskview", "close")
            if (verb) verb()
            else if (GlobalStates.overviewMode === "orbit") GlobalStates.closeOverview()
        }
        /// Open the active family's task navigator
        function open(): void {
            const verb = GlobalStates.familyVerb("taskview", "open")
            if (verb) verb()
            else if (CompositorService.isNiri) GlobalStates.openOrbit("")
        }
    }

    /// Niri-only session navigator. On ii it presents nearby workspaces and readable window previews, with MRU Trail
    /// navigation and temporary Stash parking. On iRiS it is the Island growing into one strip per workspace, with a
    /// search that lights up the windows that match; `stage`, `orbital`, `studio` and `toggleView` are ii's and do
    /// nothing there, `pocket` and `find` open Orbit, and `next` and `previous` move Niri to the workspace below or
    /// above.
    IpcHandler {
        target: "orbit"
        function _family(name: string): bool {
            const verb = GlobalStates.familyVerb("orbit", name)
            if (verb) verb()
            return verb !== null
        }
        /// Open/close Orbit
        function toggle(): void { if (!_family("toggle") && CompositorService.isNiri) GlobalStates.toggleOrbit("") }
        /// Close Orbit if it is active
        function close(): void { if (!_family("close") && GlobalStates.overviewMode === "orbit") GlobalStates.closeOverview() }
        /// Open Orbit on the focused output
        function open(): void { if (!_family("open") && CompositorService.isNiri) GlobalStates.openOrbit("") }
        /// Open Orbit directly into Pocket
        function pocket(): void { if (!_family("pocket") && CompositorService.isNiri) GlobalStates.openOrbitPocket("") }
        /// Open Orbit directly into the live Studio editor
        function studio(): void { if (!_family("studio") && CompositorService.isNiri) GlobalStates.openOrbitStudio("") }
        /// Open Orbit Focus Lens and filter session windows by app or title
        function find(query: string): void {
            const verb = GlobalStates.familyVerb("orbit", "find")
            if (verb) verb(query)
            else if (CompositorService.isNiri) GlobalStates.openOrbitLens("", query)
        }
        /// Open Orbit in the classic Stage view for this session
        function stage(): void { if (!_family("stage") && CompositorService.isNiri) GlobalStates.openOrbitView("", "stage") }
        /// Open Orbit in the Orbital workspace view for this session
        function orbital(): void { if (!_family("orbital") && CompositorService.isNiri) GlobalStates.openOrbitView("", "orbital") }
        /// Switch Niri to the next workspace while Orbit stays open
        function next(): void { if (!_family("next") && CompositorService.isNiri) GlobalStates.orbitNavigateRequested(1) }
        /// Switch Niri to the previous workspace while Orbit stays open
        function previous(): void { if (!_family("previous") && CompositorService.isNiri) GlobalStates.orbitNavigateRequested(-1) }
        /// Print the effective Orbit runtime state used by diagnostics and visual audits
        function status(): string {
            const verb = GlobalStates.familyVerb("orbit", "status")
            if (verb) return verb()
            const outputName = NiriService.currentOutput ?? ""
            const orbitCorner = Config.options?.orbit?.hotCorner ?? "topRight"
            return JSON.stringify(Object.assign({}, GlobalStates.orbitRuntimeStatus, {
                studioRequested: GlobalStates.orbitStudioRequested,
                pocketRequested: GlobalStates.orbitPocketRequested,
                lensRequested: GlobalStates.orbitLensRequested,
                hotCorner: {
                    orbit: orbitCorner,
                    activationDistance: Config.options?.orbit?.hotCornerActivationDistance ?? 2,
                    output: outputName,
                    niri: NiriService.overviewHotCornersForOutput(outputName),
                    conflict: NiriService.isOverviewHotCornerActive(outputName, orbitCorner),
                    detectionReady: NiriService.overviewHotCornersReady,
                    detectionError: NiriService.overviewHotCornersError
                }
            }))
        }
        /// Switch the open Orbit session between Stage and Orbital
        function toggleView(): void {
            if (_family("toggleView") || !CompositorService.isNiri) return
            if (GlobalStates.overviewOpen && GlobalStates.overviewMode === "orbit")
                GlobalStates.toggleOrbitStageView()
            else
                GlobalStates.openOrbit("")
        }
    }

    // IPC for settings: inside the shell or its own window, as the Settings in use allows (GlobalStates).
    /// Open or toggle the settings window. GUI config so you don't have to edit JSON by hand.
    ///
    /// ```kdl
    /// Super+Comma { spawn "inir" "settings"; }
    /// ```
    IpcHandler {
        target: "settings"
        /// Open the settings window
        function open(): void {
            GlobalStates.openSettings()
        }
        /// Toggle settings in the active host (overlay or window)
        function toggle(): void {
            GlobalStates.toggleSettings()
        }
        /// Switch to overlay mode and open Settings
        function openOverlay(): void {
            Config.setNestedValue("settingsUi.overlayMode", true)
            GlobalStates.settingsOverlayOpen = true
        }
        /// Switch to overlay mode, open Settings and keep the page, or jump to a page by its number
        function openOverlayAt(index: int): void {
            if (index >= 0)
                GlobalStates.settingsOverlayRequestedPage = index
            Config.setNestedValue("settingsUi.overlayMode", true)
            GlobalStates.settingsOverlayOpen = true
        }
        /// Switch to standalone Window mode and open page `index`
        function openWindowAt(index: int): void {
            const args = ["/usr/bin/env"]
            if (index >= 0)
                args.push(`QS_SETTINGS_PAGE=${index}`)
            args.push(Quickshell.shellPath("scripts/inir"), "settings-window")
            Quickshell.execDetached(args)
            Config.setNestedValue("settingsUi.overlayMode", false)
            GlobalStates.settingsOverlayOpen = false
        }
        /// Kept for scripts from before Settings had one layout: opens the overlay at page `index`
        function setOverlayStyle(style: string, index: int): void {
            openOverlayAt(index)
        }
    }

    // One owner for settingsNav, here rather than inside a chrome. Both overlay
    // layouts used to declare this target themselves; switching layouts leaves
    // the outgoing host alive for a moment, so Quickshell saw two registrations
    // and silently dropped one — the caller then hit whichever survived. Routing
    // through GlobalStates keeps the target valid no matter which chrome, or
    // none, is loaded.
    /// Navigate the settings overlay to a specific page (same as clicking the nav rail). `inir settings` toggles the
    /// current Settings host; use the `settings` IPC target above when you need explicit open/toggle semantics.
    ///
    /// ```sh
    /// inir ipc settingsNav page 5
    /// ```
    IpcHandler {
        target: "settingsNav"
        /// Open the overlay and jump to a page by its number
        function page(index: int): void {
            GlobalStates.openSettingsPage(index)
        }
        /// Open a page at its named section; for example `inir settingsNav section 28 sidebars`
        function section(index: int, name: string): void {
            GlobalStates.openSettingsPage(index, name)
        }
        // A page by its key ("hub", "themes"…) in the family's own Settings.
        /// Open a page by its name in the family's own Settings, for example `inir settingsNav open hub`
        function open(key: string): string {
            const keys = GlobalStates.settingsPageKeys
            if (keys.length > 0 && keys.indexOf(key) < 0)
                return `no page ${key}`
            GlobalStates.openSettingsAt(key, "")
            return key
        }
        /// Number of settings pages
        function count(): int { return GlobalStates.settingsPageKeys.length }
        /// Current page index, or `-1` when no page is open
        function current(): int { return GlobalStates.settingsOverlayCurrentPage }
    }

    // The Settings in use may keep a host in the shell (its plugin.json part `settingsHost`): page names, overlay.
    FamilyPartLoader { family: Plugins.settingsFamily; part: "settingsHost"; when: Config.ready }

    // === Panel Loaders ===
    // Keep one permanent IPC router so mode/family changes never overlap two
    // `altSwitcher` handlers during Loader teardown. The heavy ii visual tree is
    // present only for visual ii presets; the router handles no-UI cycling and
    // forwards visual commands to ii internally or to the active family's own.
    readonly property bool iiAltSwitcherNoVisual:
        (Config.options?.altSwitcher?.noVisualUi ?? false)
        && (Config.options?.altSwitcher?.preset ?? "default") !== "skew"

    LazyLoader {
        active: Config.ready
        source: "modules/shared/altSwitcher/AltSwitcherNoVisual.qml"
    }

    LazyLoader {
        active: Config.ready
            && (Config.options?.panelFamily ?? "ii") === "ii"
            && !root.iiAltSwitcherNoVisual
        source: "modules/shared/altSwitcher/AltSwitcher.qml"
    }

    // Load ONLY the active family panels to reduce startup time.
    // Using `source:` instead of `component:` to avoid parsing inactive family at compile time.
    // Only the active family's files are parsed (~135 fewer).
    // Family-agnostic IPC routers. Both panel files used to instantiate their
    // own copy, so during a family switch — when the outgoing loader is still
    // being torn down — two instances existed and Quickshell dropped one
    // handler per target (region, tiling, wallpaperSelector, coverflowSelector).
    // One owner here is valid whichever family is loaded.
    LazyLoader { active: Config.ready; source: "modules/shared/regionSelector/RegionSelectorRouter.qml" }
    // Live snips kept above the windows (those on the desktop are drawn by Background): only while one exists, and
    // only where windows can be streamed (qs-rs on niri).
    LazyLoader { active: Config.ready && LivePins.supported && LivePins.pins.some(pin => pin.onTop); source: "modules/shared/livePins/LivePinLayer.qml" }
    LazyLoader { active: Config.ready && LivePins.framing; source: "modules/shared/livePins/LivePinFramer.qml" }
    // A hidden window per screen otherwise, for a lookup most people never make.
    LazyLoader { active: Config.ready && GlobalStates.japaneseLookupOpen; source: "modules/shared/japaneseLookup/JapaneseLookup.qml" }
    LazyLoader { active: Config.ready; source: "modules/shared/tilingOverlay/TilingOverlayRouter.qml" }
    LazyLoader { active: Config.ready; source: "modules/shared/wallpaperSelector/WallpaperSelectorRouter.qml" }

    // Same reason as the routers: both panel files declared these, so every
    // family switch registered them twice and Quickshell kept whichever won the
    // race — sometimes the handler belonging to the family being torn down.
    // The four below were byte-identical in both files; only overview differs,
    // so it branches here instead of existing twice.
    /// On-screen keyboard.
    IpcHandler {
        target: "osk"
        /// Show/hide on-screen keyboard
        function toggle(): void { GlobalStates.oskOpen = !GlobalStates.oskOpen }
        /// Hide on-screen keyboard
        function close(): void { GlobalStates.oskOpen = false }
        /// Show on-screen keyboard
        function open(): void { GlobalStates.oskOpen = true }
    }

    /// Floating tools (Super+G): notes, images, crosshair, recorder, resources and other pinnable desktop tools.
    ///
    /// ```kdl
    /// Super+G { spawn "inir" "overlay" "toggle"; }
    /// ```
    IpcHandler {
        target: "overlay"
        /// Open/close Floating tools
        function toggle(): void { GlobalStates.overlayOpen = !GlobalStates.overlayOpen }
        /// Show or hide one floating tool by id (`crosshair`, `fpsLimiter`, `floatingImage`, `recorder`, `resources`,
        /// `notes`, `discord`, `volumeMixer`, `notifications`, `gamePerformance`): `on`, `off` or `toggle`
        function tool(identifier: string, action: string): string {
            const state = Persistent.states.overlay
            if (!state || typeof state[identifier] !== "object") return "Unknown tool"
            const open = state.open.includes(identifier)
            const wanted = action === "on" ? true : action === "off" ? false : !open
            if (wanted && !open) state.open.push(identifier)
            else if (!wanted && open) state.open = state.open.filter(id => id !== identifier)
            return wanted ? "on" : "off"
        }
    }

    /// Power menu. Logout, suspend, reboot, shutdown. The "I'm done for today" buttons.
    ///
    /// ```kdl
    /// Super+Shift+E { spawn "inir" "session" "toggle"; }
    /// ```
    IpcHandler {
        target: "session"
        /// Open/close session menu
        function toggle(): void { GlobalStates.sessionOpen = !GlobalStates.sessionOpen }
        /// Hide session screen
        function close(): void { GlobalStates.sessionOpen = false }
        /// Show session screen
        function open(): void { GlobalStates.sessionOpen = true }
    }

    /// Keyboard shortcuts reference. For when you forget what you just configured five minutes ago.
    ///
    /// ```kdl
    /// Super+Slash { spawn "inir" "cheatsheet" "toggle"; }
    /// ```
    IpcHandler {
        target: "cheatsheet"
        /// Open/close cheatsheet
        function toggle(): void { GlobalStates.cheatsheetOpen = !GlobalStates.cheatsheetOpen }
        /// Hide cheatsheet overlay
        function close(): void { GlobalStates.cheatsheetOpen = false }
        /// Show cheatsheet overlay
        function open(): void { GlobalStates.cheatsheetOpen = true }
    }

    /// Clipboard history panel. Because Ctrl+V only remembers one thing, and that's not enough for power users.
    ///
    /// ```kdl
    /// Super+V repeat=false { spawn "inir" "clipboard" "toggle"; }
    /// ```
    IpcHandler {
        target: "clipboard"
        /// Open panel
        function open(): void {
            const verb = GlobalStates.familyVerb("clipboard", "open")
            if (verb) verb()
            else GlobalStates.clipboardOpen = true
        }
        /// Close panel
        function close(): void {
            const verb = GlobalStates.familyVerb("clipboard", "close")
            if (verb) verb()
            else GlobalStates.clipboardOpen = false
        }
        /// Open/close panel
        function toggle(): void {
            const verb = GlobalStates.familyVerb("clipboard", "toggle")
            if (verb) verb()
            else GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen
        }
    }

    /// Toggle the workspace overview panel. The one with all your windows looking tiny and organized.
    ///
    /// ```kdl
    /// Mod+Space { spawn "inir" "overview" "toggle"; }
    /// ```
    IpcHandler {
        target: "overview"
        function _family(name: string): bool {
            const verb = GlobalStates.familyVerb("overview", name)
            if (verb) verb()
            return verb !== null
        }
        function _usePillLauncher(): bool {
            return (Config.options?.panelFamily ?? "ii") === "ii"
                && (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"
                && (Config.options?.bar?.pill?.superSpaceLauncher ?? "overview") === "pill"
        }
        /// Open/close overview
        function toggle(): void {
            if (_family("toggle")) return
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("toggle", "launcher"); return }
            GlobalStates.overviewSearchPrefix = ""
            GlobalStates.toggleOverview("")
        }
        /// Close overview
        function close(): void {
            if (_family("close")) return
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("close", "launcher"); return }
            GlobalStates.overviewOpen = false
        }
        /// Open overview
        function open(): void {
            if (_family("open")) return
            if (_usePillLauncher()) { GlobalStates.pillSurfaceCommand("open", "launcher"); return }
            GlobalStates.overviewSearchPrefix = ""
            GlobalStates.openOverview("")
        }
        /// Clear the super-key release interrupt flag
        function toggleReleaseInterrupt(): void { GlobalStates.superReleaseMightTrigger = false }
        /// Open clipboard search, or close if already open
        function clipboardToggle(): void {
            if (_family("clipboardToggle")) return
            const prefix = Config.options?.search?.prefix?.clipboard ?? ";"
            if (GlobalStates.overviewOpen && GlobalStates.overviewSearchPrefix.length > 0) {
                GlobalStates.overviewOpen = false
            } else {
                GlobalStates.overviewSearchPrefix = prefix
                GlobalStates.openOverview("")
            }
        }
        /// Open overview in action search mode
        function actionOpen(): void {
            if (_family("actionOpen")) return
            const prefix = Config.options?.search?.prefix?.action ?? "/"
            GlobalStates.overviewSearchPrefix = prefix
            GlobalStates.openOverview("")
        }
    }

    // Each installed family's panels, found through its plugin.json: the critical ones with the config, the rest
    // once the first frame is out. Only the chosen family loads.
    Variants {
        model: Plugins.families
        Scope {
            id: family
            required property string modelData
            readonly property bool chosen: Config.ready && Plugins.ready && !root._familyPanelsSuspended
                && (Config.options?.panelFamily ?? "ii") === family.modelData
            readonly property bool panelsWanted: family.chosen && GlobalStates.deferredPanelsReady
            // A part gets its source the first time it's wanted and keeps it: a LazyLoader compiles its source as soon
            // as it has one (every family's parts compiled before the first frame), and dropping the source would delete
            // the component under a load still running. Going back to a family is instant.
            property bool criticalUsed: false
            property bool panelsUsed: false
            onChosenChanged: {
                if (!family.chosen) return
                family.criticalUsed = true
                if (root._transitionInProgress) Qt.callLater(family.finishNow)
            }
            // Under the switch's curtain nothing is on screen to keep smooth, so the parts finish at once instead of in
            // the incubator's 10 ms slices between frames: Material stood after 3.7 s fresh, 9.6 s on a shell
            // reloaded all day.
            // Reading item while it loads completes it (LazyLoader docs, both runtimes).
            function finishNow() {
                void criticalParts.item
                void panelParts.item
            }
            onPanelsWantedChanged: if (family.panelsWanted) family.panelsUsed = true
            // The switch's curtain lifts once the chosen family stands: lifted on the swap alone, Material was still
            // building its panels on screen for a second or two (his 10-30: "se lagea todo").
            Binding { when: family.chosen; target: root; property: "_familyUp"; value: family.up }
            // A part that doesn't compile leaves the person without panels: the update reads these lines and rolls the
            // family back (robust-update.sh, restart_shell_and_verify). The type loader compiles it once for both.
            function checkPart(url: string) {
                if (url === "") return
                const part = Qt.createComponent(url, Component.PreferSynchronous)
                if (part.status === Component.Error)
                    console.error(`[Plugins] family ${family.modelData} failed to load: ${part.errorString().trim()}`)
                part.destroy()
            }
            readonly property string criticalSource: criticalParts.source
            readonly property string panelsSource: panelParts.source
            readonly property bool up: panelParts.item !== null
            onCriticalSourceChanged: {
                if (family.criticalSource !== "")
                    console.info(`[Plugins] family ${family.modelData} loading`)
                family.checkPart(family.criticalSource)
            }
            onPanelsSourceChanged: family.checkPart(family.panelsSource)
            onUpChanged: if (family.up) console.info(`[Plugins] family ${family.modelData} loaded`)
            Component.onCompleted: {
                family.criticalUsed = family.criticalUsed || family.chosen
                family.panelsUsed = family.panelsUsed || family.panelsWanted
            }

            // loading reads the source too: neither runtime starts a load asked for before its component came
            LazyLoader {
                id: criticalParts
                source: family.criticalUsed ? Plugins.part(family.modelData, "critical") : ""
                loading: family.chosen && criticalParts.source !== ""
                activeAsync: family.chosen && criticalParts.source !== ""
            }

            LazyLoader {
                id: panelParts
                source: family.panelsUsed ? Plugins.part(family.modelData, "panels") : ""
                loading: family.panelsWanted && panelParts.source !== ""
                activeAsync: family.panelsWanted && panelParts.source !== ""
            }
        }
    }

    // Close confirmation dialog (always loaded, handles IPC)
    LazyLoader { active: Config.ready; source: "modules/shared/closeConfirm/CloseConfirm.qml" }

    // Shared (always loaded via ToastManager)
    ToastManager {}

    // Installed families in the order the switch walks them (familyCycle), the rest after; each lists its panels in
    // its plugin.json (`enabledPanels`).
    readonly property list<string> families: {
        const installed = Plugins.families
        const cycle = Array.from(Config.options?.familyCycle ?? []).filter(family => installed.includes(family))
        return [...new Set(cycle), ...installed.filter(family => !cycle.includes(family))]
    }

    // === Panel Family Transition ===
    property string _pendingFamily: ""
    property bool _transitionInProgress: false
    property bool _transitionUsesOverlay: false
    property bool _familyPanelsSuspended: false
    property string _familySwapTarget: ""
    property real _transitionStartedAt: 0
    property bool _familyUp: false
    property bool _familyRestartPending: false

    function _ensureFamilyPanels(family: string): void {
        const basePanels = Plugins.panels(family)
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
        const wanted = Array.from(Config.options?.familyCycle ?? families)
        const order = wanted.filter((family, index) => families.includes(family) && wanted.indexOf(family) === index)
        if (order.length === 0) return
        const at = order.indexOf(currentFamily)
        const nextFamily = order[(at + 1) % order.length]
        if (nextFamily === currentFamily) return
        const currentIndex = families.indexOf(currentFamily)
        const nextIndex = families.indexOf(nextFamily)

        // Later in the cycle slides left, earlier slides right.
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
        if (_transitionInProgress && _transitionUsesOverlay && !GlobalStates.familyTransitionActive) {
            console.warn("[FamilyTransition] stale in-progress flag cleared")
            _transitionInProgress = false
            _transitionUsesOverlay = false
        }
        if (_transitionInProgress) return
        const leave = GlobalStates.familyVerb("family", "leave")
        if (leave) leave()

        // Qt 6.11 can segfault during layer-shell teardown; restart the supervised shell.
        const qt611LayerShellRisk = Quickshell.hasQtVersion(6, 11)
            && !Quickshell.hasQtVersion(6, 12)
        if (qt611LayerShellRisk) {
            _transitionInProgress = true
            _transitionUsesOverlay = false
            root._restartIntoFamily(targetFamily)
            return
        }

        // Keep old and new layer-shell trees out of the same Wayland dispatch.
        if (!(Config.options?.familyTransitionAnimation ?? true)) {
            _transitionInProgress = true
            _transitionUsesOverlay = false
            root._warmFamily(targetFamily)
            root.beginSerializedFamilySwap(targetFamily)
            return
        }

        _transitionInProgress = true
        _transitionUsesOverlay = true
        _transitionStartedAt = Date.now()
        _pendingFamily = targetFamily
        GlobalStates.familyTransitionTarget = targetFamily
        GlobalStates.familyTransitionDirection = direction
        GlobalStates.familyTransitionActive = true
    }

    // The target's parts compile in the loader thread while the old family leaves, and the swap waits for them: its
    // loaders would compile them on the GUI thread, a stall on a family not used yet this session.
    property var _familyWarm: []
    property int _familyWarmWaits: 0
    readonly property bool _familyWarming: root._familyWarm.some(component => component.status === Component.Loading)
    function _warmFamily(family: string): void {
        root._familyWarmWaits = 0
        root._familyWarm = ["critical", "panels"].map(part => Plugins.part(family, part)).filter(url => url !== "")
            .map(url => Qt.createComponent(url, Component.Asynchronous))
    }

    function _restartIntoFamily(targetFamily: string): void {
        if (root._familyRestartPending) return
        const basePanels = Plugins.panels(targetFamily)
        if (basePanels.length === 0) {
            root._transitionInProgress = false
            return
        }

        root._familyRestartPending = true
        Quickshell.execDetached([
            Quickshell.shellPath("scripts/lib/accel-run"),
            "switch-family",
            targetFamily,
            JSON.stringify(basePanels),
            Quickshell.shellPath("scripts/inir")
        ])
        familyRestartFallbackTimer.restart()
    }

    Timer {
        id: familyRestartFallbackTimer
        interval: 8000
        repeat: false
        onTriggered: {
            root._familyRestartPending = false
            root._transitionInProgress = false
            root._transitionUsesOverlay = false
        }
    }

    function beginSerializedFamilySwap(targetFamily: string): void {
        if (root._familyPanelsSuspended) return
        if (!targetFamily || !families.includes(targetFamily)) return

        root._familySwapTarget = targetFamily
        root._familyPanelsSuspended = true
        familyUnloadSettleTimer.restart()
    }

    function applyPendingFamily() {
        if (!_pendingFamily || !families.includes(_pendingFamily)) return
        if (root._familyPanelsSuspended) return

        const targetFamily = _pendingFamily
        _pendingFamily = ""
        // No warm-up under the curtain: its compile held the GUI thread (1.2 s for iRiS before the curtain, 10-29), and
        // under it both switches to Material after a reload stood still until the watchdog, 6.9 s (his 10-30). The
        // panels compile once as they load, the way every boot does (1.2 s for Material), and the curtain holds for it.
        root.beginSerializedFamilySwap(targetFamily)
    }

    Timer {
        id: familyUnloadSettleTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!root._familySwapTarget || !root.families.includes(root._familySwapTarget)) {
                root._familyPanelsSuspended = false
                return
            }
            Config.setNestedValue("panelFamily", root._familySwapTarget)
            root._ensureFamilyPanels(root._familySwapTarget)
            familyLoadSettleTimer.restart()
        }
    }

    Timer {
        id: familyLoadSettleTimer
        interval: 120
        repeat: false
        onTriggered: {
            // The warm-up can only save what loading the family on the GUI thread costs (~0.9 s for Material, his log
            // 10-30), so it is waited for about that long: a 5 s cap held Material's switch 6.4 s behind the curtain
            // and tripped the overlay's watchdog.
            if (root._familyWarming && root._familyWarmWaits++ < 20) {
                familyLoadSettleTimer.interval = 50
                familyLoadSettleTimer.restart()
                return
            }
            if (root._familyWarmWaits > 0) console.info(`[FamilyTransition] warm-up waited ${root._familyWarmWaits * 50} ms${root._familyWarming ? " (still compiling)" : ""}`)
            familyLoadSettleTimer.interval = 120
            const directSwap = !root._transitionUsesOverlay
            root._familyPanelsSuspended = false
            root._familyWarm = []
            root._familySwapTarget = ""
            if (directSwap) {
                root._transitionInProgress = false
                root._transitionUsesOverlay = false
            }
        }
    }

    Timer {
        id: familyFinishSettleTimer
        interval: 50
        repeat: false
        onTriggered: root.finishFamilyTransition()
    }

    function finishFamilyTransition() {
        // Keep the transition cover until the serialized family swap finishes.
        if (root._familyPanelsSuspended) {
            familyFinishSettleTimer.restart()
            return
        }
        if (_transitionStartedAt > 0) console.info(`[FamilyTransition] ${Config.options?.panelFamily ?? ""} stood after ${Date.now() - _transitionStartedAt} ms`)
        _transitionStartedAt = 0
        _transitionInProgress = false
        _transitionUsesOverlay = false
        GlobalStates.familyTransitionActive = false
        GlobalStates.familyTransitionTarget = ""
    }

    // Do not retain the inactive family's visual imports outside a transition.
    Loader {
        active: Config.ready
            && root._transitionUsesOverlay
            && (GlobalStates.familyTransitionActive || root._transitionInProgress)
        source: "FamilyTransitionOverlay.qml"
        onLoaded: {
            // the curtain lifts once the new family stands, not on a fixed hold while its panels still build
            item.swapPending = Qt.binding(() => root._pendingFamily !== "" || root._familyPanelsSuspended || !root._familyUp)
            item.exitComplete.connect(root.applyPendingFamily)
            item.enterComplete.connect(root.finishFamilyTransition)
        }
    }

    /// Switch between the three shell families: Material ii (default), Waffle (Windows 11-like), and iRiS (the Island
    /// family).
    ///
    /// ```kdl
    /// Mod+Shift+W { spawn "inir" "panelFamily" "cycle"; }
    /// ```
    IpcHandler {
        target: "panelFamily"
        /// Switch to the next family in the switch list (`familyCycle`, in its order; all three by default, set in
        /// any family's Settings)
        function cycle(): void { root.cyclePanelFamily() }
        /// Set specific family ("ii", "waffle", or "iris")
        function set(family: string): void { root.setPanelFamily(family) }
    }
}
