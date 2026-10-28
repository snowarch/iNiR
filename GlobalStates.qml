pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    // Shell entry animation gate — starts false, set true after delay so panels slide in
    property bool shellEntryReady: false
    // Deferred panel loading gate — non-critical panels wait for this before activating
    property bool deferredPanelsReady: false
    // Startup lifecycle — singleton preserves one-shot state across hot reloads.
    property bool bootGreetingOpen: false
    property bool bootGreetingDone: false
    property bool startupLockDone: false
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    property string sidebarLeftTargetOutput: ""
    property bool sidebarLeftExpanded: false
    // A left-sidebar feature requests the panel stay open through implicit closes
    // (backdrop click / focus loss) and yield keyboard focus — e.g. the InnerTune
    // device-flow login, where the user must type a code into an external browser.
    property bool sidebarLeftHoldOpen: false
    property bool aiChatDetached: false
    property bool sidebarRightOpen: false
    property string sidebarRightTargetOutput: ""
    property bool mediaControlsOpen: false
    property bool equalizerOpen: false
    property string equalizerTargetOutput: ""
    readonly property bool equalizerEnabled: (Config.options?.enabledPanels ?? []).includes("iiEqualizer")

    function openEqualizer(outputName: string): void {
        if (!root.equalizerEnabled)
            return
        const requested = String(outputName ?? "")
        equalizerTargetOutput = requested.length > 0
            ? requested
            : String(root.focusedScreen?.name ?? root.primaryScreen?.name ?? "")
        equalizerOpen = true
    }

    function closeEqualizer(): void {
        equalizerOpen = false
    }

    function toggleEqualizer(outputName: string): void {
        if (!root.equalizerEnabled) {
            closeEqualizer()
            return
        }
        if (equalizerOpen) {
            closeEqualizer()
            return
        }
        openEqualizer(outputName)
    }
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool osdMicOpen: false
    property bool osdMediaOpen: false
    property string osdMediaAction: "play" // "play", "pause", "next", "previous"
    signal osdMediaActionTriggered(string action)
    // Media keys give feedback when the OSD shows it, or always under a family that shows it its own way (`mediaFeedback`).
    readonly property bool userMediaFeedback: Plugins.flag(Plugins.active, "mediaFeedback")
        || (Config.options?.osd?.mediaEnabled ?? true)

    function showMediaAction(action: string): void {
        const normalized = String(action ?? "")
        if (!["play", "pause", "next", "previous"].includes(normalized))
            return
        root.osdMediaAction = normalized
        root.osdMediaOpen = true
        root.osdMediaActionTriggered(normalized)
    }

    property bool osdKeyboardLayoutOpen: false
    property bool osdConnectionOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    property string overviewMode: "default"
    property string overviewTargetOutput: ""
    property string overviewSearchPrefix: ""
    property bool orbitPocketRequested: false
    property bool orbitStudioRequested: false
    property bool orbitLensRequested: false
    property string orbitLensRequestedQuery: ""
    property string orbitStageOverride: ""
    property var orbitRuntimeStatus: ({ open: false })
    signal orbitNavigateRequested(int direction)
    signal pillSurfaceCommand(string command, string surface)
    property bool altSwitcherOpen: false
    signal altSwitcherCommand(string command)
    property int activeContextMenuCount: 0
    property var activeContextMenu: null
    property bool clipboardOpen: false
    // True only while iNiR asks Niri for internal window-preview frames.
    property bool windowPreviewCaptureActive: false
    // The active family's own answers to the shared verbs (taskview, orbit, overview, clipboard, family.leave), set by
    // its `critical` part: { owner: id, target: { verb: function } }. A verb it leaves out keeps Material's behaviour;
    // a family with verbs (flag `verbs`) that hasn't loaded them yet answers nothing rather than Material's.
    property var familyVerbs: ({})
    function familyVerb(target: string, name: string): var {
        const verbs = root.familyVerbs?.owner === Plugins.active ? root.familyVerbs : null
        if (!verbs) return Plugins.flag(Plugins.active, "verbs") ? () => "" : null
        const verb = verbs[target]?.[name]
        return typeof verb === "function" ? verb : null
    }

    property bool settingsOverlayOpen: false
    property int settingsOverlayRequestedPage: -1 // Set before opening to navigate to a specific page
    property string settingsOverlayRequestedKey: "" // The same page by name, for a Settings that keeps its own pages
    property string settingsOverlayRequestedSection: ""
    // The page names of the Settings in use, in order, given by its host (`settingsHost`): callers name a page
    // ("widgets", "orbit"), never its position, which moves whenever a page is added.
    property var settingsPageKeys: []
    property int settingsOverlayCurrentPage: -1 // Published by whichever overlay chrome is loaded
    // iRiS Settings as a window: open or toggle with it mapped but not focused brings it forward instead.
    property bool settingsWindowBehind: false
    property int settingsRaiseRequest: 0
    property var _settingsNativeDialogs: ({})
    readonly property bool settingsNativeDialogOpen:
        Object.keys(root._settingsNativeDialogs).length > 0

    // A Settings page by its name ("widgets", "orbit", "about"), in the family's own Settings.
    function openSettingsAt(key: string, section): void {
        root._openSettings(root.settingsPageKeys.indexOf(key), key, section)
    }

    function openSettingsPage(index: int, section): void {
        root._openSettings(index, String(root.settingsPageKeys[index] ?? ""), section)
    }

    // Inside the shell when the Settings in use has no window, or brings an overlay (`settingsHost`) and the person
    // asked for it; its own window otherwise.
    function _settingsInShell(): bool {
        const family = Plugins.settingsFamily
        if (Plugins.part(family, "settingsApp").length === 0) return true
        return Plugins.part(family, "settingsHost").length > 0 && (Config.options?.settingsUi?.overlayMode ?? false)
    }

    function _openSettings(index: int, key: string, section): void {
        const requestedSection = String(section ?? "")
        if (root._settingsInShell()) {
            // The name goes last: iRiS Settings acts when it changes, with the section already there.
            root.settingsOverlayRequestedSection = requestedSection
            root.settingsOverlayRequestedPage = index
            root.settingsOverlayRequestedKey = key
            if (root.settingsOverlayOpen) root.settingsRaiseRequest++
            root.settingsOverlayOpen = true
        } else {
            // Each window knows its pages by name; the number is for callers that only have one.
            const args = ["/usr/bin/env", `QS_SETTINGS_PAGE=${key.length > 0 ? key : index}`]
            if (requestedSection.length > 0)
                args.push(`QS_SETTINGS_SECTION=${requestedSection}`)
            args.push(Quickshell.shellPath("scripts/inir"), "settings-window")
            Quickshell.execDetached(args)
        }
    }

    function openSettings(): void {
        if (root._settingsInShell()) {
            if (root.settingsOverlayOpen) root.settingsRaiseRequest++
            root.settingsOverlayOpen = true
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings-window"])
        }
    }

    function toggleSettings(): void {
        if (root._settingsInShell()) {
            if (root.settingsOverlayOpen && root.settingsWindowBehind) root.settingsRaiseRequest++
            else root.settingsOverlayOpen = !root.settingsOverlayOpen
        } else {
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings-window", "--toggle"])
        }
    }

    function setSettingsNativeDialogVisible(dialogKey: string, visible: bool): void {
        const key = String(dialogKey ?? "").trim()
        if (!key) return
        const next = Object.assign({}, root._settingsNativeDialogs)
        if (visible)
            next[key] = true
        else
            delete next[key]
        root._settingsNativeDialogs = next
    }

    property bool regionSelectorOpen: false
    property bool japaneseLookupOpen: false
    property bool japaneseLookupExpanded: false
    property var japaneseLookupResult: ({})
    property string japaneseLookupScreen: ""
    property real japaneseLookupX: 0
    property real japaneseLookupY: 0
    property real japaneseLookupWidth: 0
    property real japaneseLookupHeight: 0
    property var regionSelectorAction: 0
    property var regionSelectorMode: 0
    // Explicit screenshot callers must remain deterministic. The dedicated
    // Niri binds for screenshot, OCR and visual search are separate contracts;
    // opening one must never inherit state left by another tool.
    function openRegionScreenshot(): void {
        regionSelectorAction = 0
        regionSelectorMode = 0
        regionSelectorOpen = true
    }

    // The unified snip menu may restore the last toolbar choice. Raw ordinals
    // mirror RegionSelection's enums: action 0 Shot, 1 Edit, 2 Search, 3 OCR
    // (record and 6 Pin are never restored); mode 0 rectangle, 1 circle.
    function openRememberedRegionTool(): void {
        let action = 0
        let mode = 0
        if (Config.options?.regionSelector?.rememberSnipChoice ?? true) {
            const savedAction = Config.options?.regionSelector?.lastAction ?? 0
            const savedMode = Config.options?.regionSelector?.lastMode ?? 0
            if (savedAction >= 0 && savedAction <= 3) action = savedAction
            if (savedMode === 1) mode = savedMode
        }
        regionSelectorAction = action
        regionSelectorMode = mode
        regionSelectorOpen = true
    }
    property bool tilingOverlayPickerOpen: false
    property bool tilingOverlayOsdOpen: false
    // Native screenshot annotation editor (Edit action)
    property bool annotationEditorOpen: false
    property string annotationEditorPath: ""
    property string annotationEditorScreenName: ""
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    property string wallpaperSelectorSource: ""
    property string wallpaperSelectorQuery: ""
    property string wallpaperSelectorKind: ""
    // `inir wallpaperSelector move <step>`: the gallery moves its selection as the arrow keys do.
    signal wallpaperSelectorMoveRequested(int step)
    property var wallpaperSelectorSeries: null
    property string wallpaperSelectorKindActive: "all"
    property bool wallpaperLauncherOpen: false
    property string wallpaperLauncherMode: "static"
    property bool widgetEditMode: false
    // Finding a widget while arranging (the iRiS widget bar); `inir background widgetSearch` drives the same state.
    property bool widgetSearchOpen: false
    property string widgetSearchText: ""
    signal widgetSearchCommand(string verb)
    // Arrow keys while arranging under iRiS: the chassis owns the keyboard and hands the step to the selected widget.
    signal desktopWidgetNudge(int dx, int dy)
    property string selectedDesktopWidget: ""
    property string selectedDesktopItem: ""
    property string desktopWidgetQuickControls: ""
    // A shelf page asked for by whoever opens the arranging mode (Settings' Desktops row); the shelf takes it and clears it.
    property string desktopShelfPage: ""
    property bool shellLayoutEditMode: false

    function setWidgetEditMode(enabled: bool): void {
        if (enabled) {
            shellLayoutEditMode = false
        }
        else {
            selectedDesktopWidget = ""
            selectedDesktopItem = ""
            desktopWidgetQuickControls = ""
            widgetSearchOpen = false
            widgetSearchText = ""
        }
        widgetEditMode = enabled
    }

    function selectDesktopWidget(instanceKey: string): void {
        if (!widgetEditMode)
            return
        selectedDesktopWidget = String(instanceKey ?? "")
        selectedDesktopItem = ""
    }

    function clearDesktopWidgetSelection(): void {
        selectedDesktopWidget = ""
        selectedDesktopItem = ""
        desktopWidgetQuickControls = ""
    }

    function selectDesktopItem(instanceKey: string): void {
        selectedDesktopItem = String(instanceKey ?? "")
        selectedDesktopWidget = ""
    }

    function clearDesktopItemSelection(): void {
        selectedDesktopItem = ""
    }

    function requestDesktopWidgetQuickControls(instanceKey: string): void {
        if (!widgetEditMode)
            return
        const key = String(instanceKey ?? "")
        selectedDesktopWidget = key
        desktopWidgetQuickControls = key
    }

    function setShellLayoutEditMode(enabled: bool): void {
        if (enabled) {
            widgetEditMode = false
            selectedDesktopWidget = ""
            selectedDesktopItem = ""
            desktopWidgetQuickControls = ""
        }
        shellLayoutEditMode = enabled
    }
    // Navigate sidebar right to a specific widget by type (e.g. "notepad", "calendar")
    property string sidebarRightRequestedWidget: ""
    // Dialog requests from other panels (e.g. left sidebar → right sidebar)
    property bool requestWifiDialog: false
    property bool requestBluetoothDialog: false
    // Selection targets: "main", "backdrop", and a family's own wallpaper and backdrop: "<id>", "<id>-backdrop"
    property string wallpaperSelectionTarget: "main"
    // Target monitor for wallpaper selector (set before opening, avoids config timing issues)
    property string wallpaperSelectorTargetMonitor: ""
    onWallpaperSelectorOpenChanged: {
        // Reset selection target when selector closes without selection
        if (!wallpaperSelectorOpen) {
            wallpaperSelectionTarget = "main";
            wallpaperSelectorTargetMonitor = "";
            // Also reset Config targets if they were set
            if (Config.options?.wallpaperSelector?.selectionTarget &&
                Config.options.wallpaperSelector.selectionTarget !== "main") {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            }
            if (Config.options?.wallpaperSelector?.targetMonitor) {
                Config.setNestedValue("wallpaperSelector.targetMonitor", "")
            }
        }
    }
    onWallpaperLauncherOpenChanged: {
        if (!wallpaperLauncherOpen) {
            // Restore the configured wallpaper if the user browsed away without applying.
            Wallpapers.cancelWallpaperPreview()
            wallpaperSelectionTarget = "main"
            wallpaperSelectorTargetMonitor = ""
            if (Config.options?.wallpaperSelector?.selectionTarget
                    && Config.options.wallpaperSelector.selectionTarget !== "main")
                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            if (Config.options?.wallpaperSelector?.targetMonitor)
                Config.setNestedValue("wallpaperSelector.targetMonitor", "")
        }
    }
    property bool cheatsheetOpen: false
    property bool coverflowSelectorOpen: false
    onCoverflowSelectorOpenChanged: {
        if (!coverflowSelectorOpen) {
            wallpaperSelectionTarget = "main";
            wallpaperSelectorTargetMonitor = "";
            if (Config.options?.wallpaperSelector?.selectionTarget &&
                Config.options.wallpaperSelector.selectionTarget !== "main") {
                Config.setNestedValue("wallpaperSelector.selectionTarget", "main")
            }
            if (Config.options?.wallpaperSelector?.targetMonitor) {
                Config.setNestedValue("wallpaperSelector.targetMonitor", "")
            }
        }
    }
    property bool controlPanelOpen: false
    // The active family's desktop menu, asked to open at a point of an output (the family's own `desktopMenu` IPC).
    signal familyDesktopMenuRequested(string outputName, real x, real y)
    // A surface on screen shows seconds (a lock rehearsed while unlocked): the clock ticks each second meanwhile.
    property bool clockShowsSeconds: false
    property bool dashboardOpen: false
    property bool workspaceShowNumbers: false
    property var activeBooruImageMenu: null  // Track which BooruImage has its menu open
    property var activeTaskViewMenu: null  // Track which WindowThumbnail has its menu open
    // The palette search (a family's Start or Spotlight).
    property bool searchOpen: false
    // What the active family publishes about its own panels: a bit per open panel, its quick settings, its
    // notification list on screen.
    property int familyPanelsOpen: 0
    property bool familyQuickSettingsOpen: false
    property bool familyNotificationsOpen: false
    // Panel family transition animation state
    property bool familyTransitionActive: false
    property string familyTransitionDirection: "left" // "left" = current exits left, new enters from right
    property string familyTransitionTarget: ""

    signal requestRipple(real x, real y, string screenName)

    // User-configured fallback for singular panels such as wallpaper pickers.
    // Empty string uses the first available Quickshell screen.
    readonly property var primaryScreen: {
        const name = Config.options?.display?.primaryMonitor ?? ""
        if (name.length > 0) {
            const s = Quickshell.screens.find(scr => scr.name === name)
            if (s) return s
        }
        return Quickshell.screens[0]
    }

    // Focus-following screen for singular interactive surfaces. Keep this
    // separate from primaryScreen: the latter is a user fallback, while this
    // follows the compositor and only falls back when focus cannot be resolved.
    readonly property var focusedScreen: {
        let name = ""
        if (CompositorService.isNiri)
            name = NiriService.currentOutput ?? ""
        else if (CompositorService.isHyprland)
            name = Hyprland.focusedMonitor?.name ?? ""
        return Quickshell.screens.find(screen => (screen?.name ?? "") === name)
            ?? root.primaryScreen
            ?? Quickshell.screens[0]
            ?? null
    }

    function connectedOutputNames(allowedOutputs): var {
        const connected = Quickshell.screens
            .map(screen => String(screen?.name ?? ""))
            .filter(name => name.length > 0)
        if (!Array.isArray(allowedOutputs) || allowedOutputs.length === 0)
            return connected
        const enabled = connected.filter(name => allowedOutputs.includes(name))
        return enabled.length > 0 ? enabled : connected
    }

    function resolveOutputName(requestedOutput, allowedOutputs): string {
        const names = root.connectedOutputNames(allowedOutputs)
        if (names.length === 0)
            return ""
        const requested = String(requestedOutput ?? "")
        if (requested.length > 0 && names.includes(requested))
            return requested
        const focused = String(root.focusedScreen?.name ?? "")
        if (focused.length > 0 && names.includes(focused))
            return focused
        const primary = String(root.primaryScreen?.name ?? "")
        if (primary.length > 0 && names.includes(primary))
            return primary
        return names[0]
    }

    readonly property string overviewPresentationOutput:
        root.resolveOutputName(root.overviewTargetOutput, [])
    // Material's screen list for the side panels; a family with its own (`sidebarsAnyScreen`) ignores it.
    readonly property var sidebarScreenList: Plugins.flag(Plugins.active, "sidebarsAnyScreen")
        ? [] : (Config.options?.sidebar?.screenList ?? [])
    readonly property string sidebarLeftPresentationOutput:
        root.resolveOutputName(root.sidebarLeftTargetOutput,
            root.sidebarScreenList)
    readonly property string sidebarRightPresentationOutput:
        root.resolveOutputName(root.sidebarRightTargetOutput,
            root.sidebarScreenList)

    function openOverview(outputName): void {
        overviewMode = "default"
        overviewTargetOutput = root.resolveOutputName(outputName, [])
        overviewOpen = true
    }

    function closeOverview(): void {
        overviewOpen = false
        orbitPocketRequested = false
        orbitStudioRequested = false
        orbitLensRequested = false
        orbitLensRequestedQuery = ""
        orbitStageOverride = ""
        orbitRuntimeStatus = ({ open: false })
    }

    function toggleOverview(outputName): void {
        const resolved = root.resolveOutputName(outputName, [])
        if (overviewOpen && overviewMode === "default" && overviewPresentationOutput === resolved)
            root.closeOverview()
        else
            root.openOverview(resolved)
    }

    function openOrbit(outputName): void {
        if (!CompositorService.isNiri || !(Config.options?.orbit?.enable ?? true))
            return
        overviewMode = "orbit"
        overviewSearchPrefix = ""
        overviewTargetOutput = root.resolveOutputName(outputName, [])
        overviewOpen = true
    }

    function openOrbitView(outputName, view: string): void {
        if (!CompositorService.isNiri || !(Config.options?.orbit?.enable ?? true))
            return
        orbitStageOverride = view === "orbital" ? "orbital" : "stage"
        root.openOrbit(outputName)
    }

    function openOrbitPocket(outputName): void {
        if (!CompositorService.isNiri)
            return
        orbitPocketRequested = true
        root.openOrbit(outputName)
    }

    function openOrbitStudio(outputName): void {
        if (!CompositorService.isNiri)
            return
        orbitStudioRequested = true
        root.openOrbit(outputName)
    }

    function openOrbitLens(outputName, query: string): void {
        if (!CompositorService.isNiri)
            return
        orbitLensRequestedQuery = query
        orbitLensRequested = true
        root.openOrbit(outputName)
    }

    function toggleOrbit(outputName): void {
        const resolved = root.resolveOutputName(outputName, [])
        if (overviewOpen && overviewMode === "orbit" && overviewPresentationOutput === resolved)
            root.closeOverview()
        else
            root.openOrbit(resolved)
    }

    function toggleOrbitStageView(): void {
        if (!overviewOpen || overviewMode !== "orbit")
            return
        const configured = Config.options?.orbit?.stageMode === "orbital" ? "orbital" : "stage"
        const current = orbitStageOverride.length > 0 ? orbitStageOverride : configured
        orbitStageOverride = current === "orbital" ? "stage" : "orbital"
    }

    function openTaskView(outputName): void { root.openOrbit(outputName) }
    function toggleTaskView(outputName): void { root.toggleOrbit(outputName) }

    // The family may keep a side panel shut (its verb `sidebar.opens`); one still loading answers no yes/no and allows it.
    function _sidebarOpens(side: string): bool {
        const opens = root.familyVerb("sidebar", "opens")
        const answer = opens ? opens(side) : true
        return typeof answer === "boolean" ? answer : true
    }

    function openSidebarLeft(outputName): void {
        if (!root._sidebarOpens("left")) return
        sidebarLeftTargetOutput = root.resolveOutputName(outputName,
            root.sidebarScreenList)
        sidebarLeftOpen = true
    }

    function closeSidebarLeft(): void {
        sidebarLeftOpen = false
    }

    function toggleSidebarLeft(outputName): void {
        const resolved = root.resolveOutputName(outputName,
            root.sidebarScreenList)
        if (sidebarLeftOpen && sidebarLeftPresentationOutput === resolved)
            root.closeSidebarLeft()
        else
            root.openSidebarLeft(resolved)
    }

    function openSidebarRight(outputName): void {
        if (!root._sidebarOpens("right")) return
        sidebarRightTargetOutput = root.resolveOutputName(outputName,
            root.sidebarScreenList)
        sidebarRightOpen = true
    }

    function closeSidebarRight(): void {
        sidebarRightOpen = false
    }

    function toggleSidebarRight(outputName): void {
        const resolved = root.resolveOutputName(outputName,
            root.sidebarScreenList)
        if (sidebarRightOpen && sidebarRightPresentationOutput === resolved)
            root.closeSidebarRight()
        else
            root.openSidebarRight(resolved)
    }

    onOverviewOpenChanged: {
        if (overviewOpen && overviewTargetOutput.length === 0)
            overviewTargetOutput = root.resolveOutputName("", [])
    }

    onSidebarLeftOpenChanged: {
        if (sidebarLeftOpen && sidebarLeftTargetOutput.length === 0)
            sidebarLeftTargetOutput = root.resolveOutputName("",
                root.sidebarScreenList)
    }

    onSidebarRightOpenChanged: {
        if (sidebarRightOpen && sidebarRightTargetOutput.length === 0)
            sidebarRightTargetOutput = root.resolveOutputName("",
                root.sidebarScreenList)
        if (sidebarRightOpen) {
            Notifications.timeoutAll()
            Notifications.markAllRead()
        }
    }

    property real screenZoom: 1
    onScreenZoomChanged: {
        // Niri doesn't have native zoom support like Hyprland's cursor:zoom_factor
        // The IPC handler still works but zoom is Hyprland-only for now
        if (!CompositorService.isHyprland)
            return;
        Quickshell.execDetached(["hyprctl", "keyword", "cursor:zoom_factor", root.screenZoom.toString()]);
    }
    Behavior on screenZoom {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: GlobalShortcut {
            name: "workspaceNumber"
            description: "Hold to show workspace numbers, release to show icons"

            onPressed: {
                root.superDown = true
            }
            onReleased: {
                root.superDown = false
            }
        }
    }

    /// Screen zoom. Accessibility feature, or for reading tiny UI without pretending your monitor is the problem.
    IpcHandler {
		target: "zoom"

		/// Increase compositor zoom
		function zoomIn(): void {
            screenZoom = Math.min(screenZoom + 0.4, 3.0)
        }

        /// Decrease compositor zoom
        function zoomOut(): void {
            screenZoom = Math.max(screenZoom - 0.4, 1)
        }
	}
}
