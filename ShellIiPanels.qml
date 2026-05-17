import qs.modules.background
import qs.modules.bar
import qs.modules.cheatsheet
import qs.modules.controlPanel
import qs.modules.dock
import qs.modules.lock
import qs.modules.mediaControls
import qs.modules.notificationPopup
import qs.modules.onScreenDisplay
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
import qs.modules.ii.overlay
import qs.modules.shellUpdate
import "modules/clipboard" as ClipboardModule
import "modules/keepass" as KeepassModule

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "."

Item {
    id: panelsRoot

    // Force KeePass singleton to instantiate so its IpcHandler is always active,
    // even when iiKeepass is absent from enabledPanels (singletons are lazy by default).
    readonly property bool _keepassReady: KeePass.available

    // Immediate panels — visible at first frame or must catch early events
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Deferred panels — loaded after first frame to reduce boot contention
    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // === Immediate panels (first frame + early event capture) ===
    PanelLoader { identifier: "iiBar"; extraCondition: !(Config.options?.bar?.vertical ?? false); component: Bar {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: Config.options?.bar?.vertical ?? false; component: VerticalBar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    PanelLoader { identifier: "iiNotificationPopup"; component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; component: OnScreenDisplay {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    DeferredPanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    DeferredPanelLoader { identifier: "iiControlPanel"; component: ControlPanel {} }
    DeferredPanelLoader { identifier: "iiLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    DeferredPanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    DeferredPanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    DeferredPanelLoader { identifier: "iiOverview"; component: Overview {} }
    DeferredPanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    DeferredPanelLoader { identifier: "iiSessionScreen"; component: SessionScreen {} }
    DeferredPanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    DeferredPanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    DeferredPanelLoader { identifier: "iiTilingOverlay"; component: TilingOverlay {} }
    DeferredPanelLoader { identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }
    DeferredPanelLoader { identifier: "iiCoverflowSelector"; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; component: ClipboardModule.ClipboardPanel {} }
    DeferredPanelLoader { identifier: "iiShellUpdate"; component: ShellUpdateOverlay {} }
    DeferredPanelLoader { identifier: "iiRecordingOsd"; component: RecordingOsd {} }
    DeferredPanelLoader { identifier: "iiKeepass"; component: KeepassModule.KeepassPanel {} }

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
}
