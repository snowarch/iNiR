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
import qs.modules.inir.overlay
import qs.modules.shellUpdate
import "modules/clipboard" as ClipboardModule

import QtQuick
import Quickshell
import qs.modules.common

Item {
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // inir style (Material)
    PanelLoader { identifier: "inirBar"; extraCondition: !(Config.options?.bar?.vertical ?? false); component: Bar {} }
    PanelLoader { identifier: "inirBackground"; component: Background {} }
    PanelLoader { identifier: "inirBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "inirCheatsheet"; component: Cheatsheet {} }
    PanelLoader { identifier: "inirDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    PanelLoader { identifier: "inirLock"; component: Lock {} }
    PanelLoader { identifier: "inirMediaControls"; component: MediaControls {} }
    PanelLoader { identifier: "inirNotificationPopup"; component: NotificationPopup {} }
    PanelLoader { identifier: "inirOnScreenDisplay"; component: OnScreenDisplay {} }
    PanelLoader { identifier: "inirOnScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "inirOverlay"; component: Overlay {} }
    PanelLoader { identifier: "inirOverview"; component: Overview {} }
    PanelLoader { identifier: "inirPolkit"; component: Polkit {} }
    PanelLoader { identifier: "inirRegionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "inirScreenCorners"; component: ScreenCorners {} }
    PanelLoader { identifier: "inirSessionScreen"; component: SessionScreen {} }
    PanelLoader { identifier: "inirSidebarLeft"; component: SidebarLeft {} }
    PanelLoader { identifier: "inirSidebarRight"; component: SidebarRight {} }
    PanelLoader { identifier: "inirTilingOverlay"; component: TilingOverlay {} }
    PanelLoader { identifier: "inirVerticalBar"; extraCondition: Config.options?.bar?.vertical ?? false; component: VerticalBar {} }
    PanelLoader { identifier: "inirWallpaperSelector"; component: WallpaperSelector {} }

    PanelLoader { identifier: "inirClipboard"; component: ClipboardModule.ClipboardPanel {} }
    PanelLoader { identifier: "inirControlPanel"; component: ControlPanel {} }
    PanelLoader { identifier: "inirShellUpdate"; component: ShellUpdateOverlay {} }
}
