pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.notificationPopup
import qs.modules.iris.onScreenDisplay
import qs.modules.iris.session
import qs.modules.iris.polkit
import qs.modules.iris.style
import qs.modules.iris.pieces
import qs.modules.iris.settings
import qs.modules.iris.lock
import qs.modules.iris.sidebar
import qs.modules.background
import qs.modules.lock

Item {
    id: root

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
        readonly property bool enabledPanel: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
        loading: enabledPanel && GlobalStates.shellEntryReady
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady
    }

    component OnDemandPanelLoader: LazyLoader {
        id: loader
        required property string identifier
        required property bool open
        property bool extraCondition: true
        property bool requireEnabledPanel: true
        property int closeGraceMs: IrisStyle.revealDuration + 30
        property bool resident: open
        property Timer closeGrace: Timer {
            interval: loader.closeGraceMs
            onTriggered: loader.resident = loader.open
        }
        readonly property bool enabledPanel: Config.ready
            && (!requireEnabledPanel || (Config.options?.enabledPanels ?? []).includes(identifier))
            && extraCondition

        onOpenChanged: {
            if (open) {
                closeGrace.stop()
                resident = true
            } else {
                closeGrace.restart()
            }
        }

        loading: enabledPanel && resident
        activeAsync: enabledPanel && GlobalStates.deferredPanelsReady && resident
    }

    IrisSidebarEdge { side: "left" }
    IrisSidebarEdge { side: "right" }

    OnDemandPanelLoader {
        identifier: "irisSidebarLeft"
        requireEnabledPanel: false
        open: GlobalStates.sidebarLeftOpen
        extraCondition: Config.options?.iris?.sidebars?.left?.enable ?? true
        closeGraceMs: IrisStyle.settleDuration + 80
        component: IrisSidebar { side: "left" }
    }

    OnDemandPanelLoader {
        identifier: "irisSidebarRight"
        requireEnabledPanel: false
        open: GlobalStates.sidebarRightOpen
        extraCondition: Config.options?.iris?.sidebars?.right?.enable ?? true
        closeGraceMs: IrisStyle.settleDuration + 80
        component: IrisSidebar { side: "right" }
    }

    OnDemandPanelLoader {
        identifier: "irisNotificationPopup"
        open: (Notifications.popupList?.length ?? 0) > 0
        closeGraceMs: IrisStyle.settleDuration * 2 + 160
        extraCondition: (Config.options?.iris?.modules?.notificationPopup ?? true)
            && (!(Config.options?.enabledPanels ?? []).includes("irisBar")
                || (CompositorService.isNiri && GameMode.hasFullscreenOnOutput(GlobalStates.focusedScreen?.name ?? "") && !NiriService.inOverview
                    && (Config.options?.iris?.notifications?.fullscreen ?? true)))
        component: IrisNotificationPopup {}
    }

    OnDemandPanelLoader {
        identifier: "irisSettings"
        requireEnabledPanel: false
        open: GlobalStates.settingsOverlayOpen || GlobalStates.irisSettingsWarm
        closeGraceMs: IrisStyle.settleDuration + 120
        component: IrisSettings {}
    }

    LazyLoader {
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady
            && CompositorService.isNiri
            && (Config.options?.background?.backdrop?.enable ?? false)
        source: "../background/Backdrop.qml"
    }

    LazyLoader {
        activeAsync: Config.ready && GlobalStates.deferredPanelsReady
            && (Config.options?.enabledPanels ?? []).includes("irisBackground")
            && (Config.options?.iris?.modules?.desktopWidgets ?? true)
        component: Background {}
    }

    PanelLoader {
        identifier: "irisOnScreenDisplay"
        extraCondition: (Config.options?.iris?.modules?.osd ?? true)
            && (!GlobalStates.barOpen
                || (CompositorService.isNiri && GameMode.hasFullscreenOnOutput(GlobalStates.focusedScreen?.name ?? "") && !NiriService.inOverview)
                || !(Config.options?.enabledPanels ?? []).includes("irisBar")
                || ((Config.options?.iris?.bar?.screenList ?? []).length > 0
                    && !(Config.options.iris.bar.screenList).includes(GlobalStates.focusedScreen?.name ?? "")))
        component: IrisOSD {}
    }

    OnDemandPanelLoader {
        identifier: "irisSessionScreen"
        open: GlobalStates.sessionOpen
        extraCondition: Config.options?.iris?.modules?.sessionScreen ?? true
        component: IrisSessionScreen {}
    }

    DeferredPanelLoader {
        identifier: "irisLock"
        extraCondition: Config.options?.iris?.modules?.lock ?? true
        component: Lock {}
    }

    DeferredPanelLoader {
        identifier: "irisPolkit"
        extraCondition: Config.options?.iris?.modules?.polkit ?? true
        component: IrisPolkit {}
    }

    OnDemandPanelLoader {
        identifier: "irisOverlay"
        open: GlobalStates.overlayOpen
        requireEnabledPanel: false
        closeGraceMs: IrisStyle.settleDuration + 120
        source: "../ii/overlay/Overlay.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisCheatsheet"
        open: GlobalStates.cheatsheetOpen
        requireEnabledPanel: false
        source: "../cheatsheet/Cheatsheet.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisOnScreenKeyboard"
        open: GlobalStates.oskOpen
        requireEnabledPanel: false
        source: "../onScreenKeyboard/OnScreenKeyboard.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisRegionSelector"
        open: GlobalStates.regionSelectorOpen || GlobalStates.annotationEditorOpen
        requireEnabledPanel: false
        source: "../regionSelector/RegionSelector.qml"
    }


    OnDemandPanelLoader {
        identifier: "irisLockRehearsal"
        open: GlobalStates.irisLockEdit
        requireEnabledPanel: false
        component: IrisLockRehearsal {}
    }

    OnDemandPanelLoader {
        identifier: "irisWallpaperLauncher"
        open: GlobalStates.wallpaperLauncherOpen
        requireEnabledPanel: false
        source: "../wallpaperLauncher/WallpaperLauncher.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisCoverflowSelector"
        open: GlobalStates.coverflowSelectorOpen
        requireEnabledPanel: false
        source: "../wallpaperSelector/WallpaperCoverflow.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisRecordingOsd"
        open: RecorderStatus.isRecording
        requireEnabledPanel: false
        extraCondition: !(GlobalStates.barOpen
            && (Config.options?.enabledPanels ?? []).includes("irisBar"))
        source: "../recordingOsd/RecordingOsd.qml"
    }

    OnDemandPanelLoader {
        identifier: "irisTilingOverlay"
        open: GlobalStates.tilingOverlayPickerOpen || GlobalStates.tilingOverlayOsdOpen
        requireEnabledPanel: false
        source: "../tilingOverlay/TilingOverlay.qml"
    }
}
