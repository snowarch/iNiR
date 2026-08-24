pragma ComponentBehavior: Bound

import qs.modules.bootGreeting
import qs.modules.lock
import qs.modules.mascot
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.tilingOverlay
import qs.modules.wallpaperSelector
import qs.modules.wallpaperLauncher
import qs.modules.ii.overlay
import qs.modules.shellUpdate
import qs.modules.workspaceStrip
import qs.modules.clipboard as ClipboardModule

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: panelsRoot

    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        loading: enabledPanel
        activeAsync: enabledPanel
    }

    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        loading: Config.ready && GlobalStates.shellEntryReady
            && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    component OnDemandPanelLoader: LazyLoader {
        id: onDemandLoader
        required property string identifier
        required property bool open
        property bool keepLoaded: false
        property bool retainAfterUse: false
        property bool used: false
        property int closeGraceMs: 300
        property int retainIdleMs: 5 * 60 * 1000
        property bool resident: open || keepLoaded
        property Timer closeGrace: Timer {
            interval: onDemandLoader.closeGraceMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open || onDemandLoader.keepLoaded
        }
        property Timer retainIdle: Timer {
            interval: onDemandLoader.retainIdleMs
            onTriggered: onDemandLoader.resident = onDemandLoader.open || onDemandLoader.keepLoaded
        }
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)

        onOpenChanged: {
            if (open) {
                used = true
                closeGrace.stop()
                retainIdle.stop()
                resident = true
            } else if (!keepLoaded) {
                if (retainAfterUse && used)
                    retainIdle.restart()
                else
                    closeGrace.restart()
            }
        }
        onKeepLoadedChanged: {
            if (keepLoaded) {
                closeGrace.stop()
                retainIdle.stop()
                resident = true
            } else if (!open) {
                if (retainAfterUse && used)
                    retainIdle.restart()
                else
                    closeGrace.restart()
            }
        }

        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool barPill: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"
    readonly property bool barM3: (Config.options?.bar?.appearanceStyle ?? "classic") === "m3"
    readonly property bool barStock: !panelsRoot.barPill && !panelsRoot.barM3
    readonly property bool pillHostActive: panelsRoot.barPill
        && !panelsRoot.barVertical
        && (Config.options?.enabledPanels ?? []).includes("iiBar")
    readonly property bool pillToastTakeover: panelsRoot.pillHostActive
        && (Config.options?.bar?.pill?.toasts ?? true)
    readonly property bool pillOsdTakeover: panelsRoot.pillHostActive
        && (Config.options?.bar?.pill?.osd ?? true)

    function screensFor(list: var): var {
        const screens = Quickshell.screens
        if (!list || list.length === 0)
            return screens
        const matched = screens.filter(screen => {
            const screenName = screen?.name ?? ""
            return screenName.length > 0 && list.includes(screenName)
        })
        return matched.length > 0 ? matched : screens
    }

    readonly property var pillHostScreens: panelsRoot.pillHostActive
        ? panelsRoot.screensFor(Config.options?.bar?.screenList ?? []) : []
    readonly property var pillHostScreenNames: panelsRoot.pillHostScreens.map(screen => screen?.name ?? "")
    readonly property var notificationScreens: panelsRoot.screensFor(Config.options?.notifications?.screenList ?? [])
    readonly property var osdScreens: panelsRoot.screensFor(Config.options?.osd?.screenList ?? [])
    readonly property bool notificationStandaloneNeeded: !panelsRoot.pillToastTakeover
        || panelsRoot.notificationScreens.some(screen => !panelsRoot.pillHostScreenNames.includes(screen?.name ?? ""))
    readonly property bool osdStandaloneNeeded: !panelsRoot.pillOsdTakeover
        || panelsRoot.osdScreens.some(screen => !panelsRoot.pillHostScreenNames.includes(screen?.name ?? ""))

    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; source: "../background/Backdrop.qml" }
    PanelLoader {
        identifier: "iiNotificationPopup"
        extraCondition: panelsRoot.notificationStandaloneNeeded
        component: NotificationPopup {
            excludedScreenNames: panelsRoot.pillToastTakeover ? panelsRoot.pillHostScreenNames : []
        }
    }
    PanelLoader {
        identifier: "iiOnScreenDisplay"
        extraCondition: panelsRoot.osdStandaloneNeeded
        component: OnScreenDisplay {
            excludedScreenNames: panelsRoot.pillOsdTakeover ? panelsRoot.pillHostScreenNames : []
        }
    }

    DeferredPanelLoader { identifier: "iiBootGreeting"; component: BootGreeting {} }
    OnDemandPanelLoader { identifier: "iiCheatsheet"; open: GlobalStates.cheatsheetOpen; source: "../cheatsheet/Cheatsheet.qml" }
    OnDemandPanelLoader {
        identifier: "iiControlPanel"
        open: GlobalStates.controlPanelOpen
        keepLoaded: Config.options?.controlPanel?.keepLoaded ?? false
        source: "../controlPanel/ControlPanel.qml"
    }
    OnDemandPanelLoader {
        identifier: "iiDashboard"
        open: GlobalStates.dashboardOpen
        keepLoaded: Config.options?.dashboard?.keepLoaded ?? false
        source: "../dashboard/Dashboard.qml"
    }
    DeferredPanelLoader { identifier: "iiLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    OnDemandPanelLoader { identifier: "iiOnScreenKeyboard"; open: GlobalStates.oskOpen; component: OnScreenKeyboard {} }
    OnDemandPanelLoader {
        identifier: "iiOverlay"
        open: GlobalStates.overlayOpen || OverlayContext.hasPinnedWidgets
        component: Overlay {}
    }
    OnDemandPanelLoader { identifier: "iiOverview"; open: GlobalStates.overviewOpen; retainAfterUse: true; closeGraceMs: 300; source: "../overview/Overview.qml" }
    DeferredPanelLoader { identifier: "iiPolkit"; component: Polkit {} }

    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    OnDemandPanelLoader { identifier: "iiSessionScreen"; open: GlobalStates.sessionOpen; component: SessionScreen {} }

    Variants {
        model: panelsRoot.screensFor(Config.options?.sidebar?.screenList ?? [])

        PanelWindow {
            id: dualSidebarBackdrop
            required property var modelData
            readonly property bool leftPresented: GlobalStates.sidebarLeftOpen
                && GlobalStates.sidebarLeftPresentationOutput === (modelData?.name ?? "")
            readonly property bool rightPresented: GlobalStates.sidebarRightOpen
                && GlobalStates.sidebarRightPresentationOutput === (modelData?.name ?? "")
            screen: modelData
            visible: leftPresented || rightPresented
            updatesEnabled: leftPresented || rightPresented
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
                item: dualSidebarBackdrop.leftPresented || dualSidebarBackdrop.rightPresented
                    ? dualSidebarBackdropArea : emptyDualSidebarMask
            }

            MouseArea {
                id: dualSidebarBackdropArea
                anchors.fill: parent
                enabled: dualSidebarBackdrop.leftPresented || dualSidebarBackdrop.rightPresented
                onClicked: {
                    if (dualSidebarBackdrop.leftPresented)
                        GlobalStates.closeSidebarLeft()
                    if (dualSidebarBackdrop.rightPresented)
                        GlobalStates.closeSidebarRight()
                }
            }
        }
    }

    DeferredPanelLoader { identifier: "iiSidebarLeft"; source: "../sidebarLeft/SidebarLeft.qml" }
    DeferredPanelLoader { identifier: "iiSidebarRight"; source: "../sidebarRight/SidebarRight.qml" }

    OnDemandPanelLoader {
        identifier: "iiTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        closeGraceMs: 250
        component: TilingOverlay {}
    }

    OnDemandPanelLoader { identifier: "iiWallpaperSelector"; open: GlobalStates.wallpaperSelectorOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperSelector {} }
    OnDemandPanelLoader { identifier: "iiWallpaperLauncher"; open: GlobalStates.wallpaperLauncherOpen; retainAfterUse: true; closeGraceMs: 250; component: WallpaperLauncher {} }
    OnDemandPanelLoader { identifier: "iiCoverflowSelector"; open: GlobalStates.coverflowSelectorOpen; retainAfterUse: true; closeGraceMs: 300; component: WallpaperCoverflow {} }
    OnDemandPanelLoader { identifier: "iiClipboard"; open: GlobalStates.clipboardOpen; retainAfterUse: true; closeGraceMs: 250; component: ClipboardModule.ClipboardPanel {} }
    OnDemandPanelLoader { identifier: "iiShellUpdate"; open: ShellUpdates.overlayOpen; closeGraceMs: 250; component: ShellUpdateOverlay {} }
    OnDemandPanelLoader { identifier: "iiRecordingOsd"; open: RecorderStatus.isRecording; closeGraceMs: 250; component: RecordingOsd {} }
    DeferredPanelLoader { identifier: "iiWorkspaceStrip"; component: WorkspaceStrip {} }
    DeferredPanelLoader { identifier: "iiMascotCompanion"; extraCondition: Config.options?.mascot?.enable ?? false; component: MascotCompanion {} }

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
                onPressed: GlobalStates.toggleSidebarLeft("")
            }
            GlobalShortcut {
                name: "sidebarLeftOpen"
                description: "Opens left sidebar on press"
                onPressed: GlobalStates.openSidebarLeft("")
            }
            GlobalShortcut {
                name: "sidebarLeftClose"
                description: "Closes left sidebar on press"
                onPressed: GlobalStates.closeSidebarLeft()
            }
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "sidebarRightToggle"
                description: "Toggles right sidebar on press"
                onPressed: GlobalStates.toggleSidebarRight("")
            }
            GlobalShortcut {
                name: "sidebarRightOpen"
                description: "Opens right sidebar on press"
                onPressed: GlobalStates.openSidebarRight("")
            }
            GlobalShortcut {
                name: "sidebarRightClose"
                description: "Closes right sidebar on press"
                onPressed: GlobalStates.closeSidebarRight()
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
