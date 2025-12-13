import qs.modules.background
import qs.modules.bar
import qs.modules.cheatsheet
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
import qs.modules.verticalBar
import qs.modules.wallpaperSelector
import qs.modules.ii.overlay
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

    // ii style (Material)
    PanelLoader { identifier: "iiBar"; extraCondition: !(Config.options?.bar?.vertical ?? false); component: Bar {} }
    PanelLoader { identifier: "iiBackground"; component: Background {} }
    PanelLoader { identifier: "iiBackdrop"; extraCondition: Config.options?.background?.backdrop?.enable ?? false; component: Backdrop {} }
    PanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    PanelLoader { identifier: "iiDock"; extraCondition: Config.options?.dock?.enable ?? true; component: Dock {} }
    PanelLoader { identifier: "iiLock"; component: Lock {} }
    PanelLoader { identifier: "iiMediaControls"; component: MediaControls {} }
    PanelLoader { identifier: "iiNotificationPopup"; component: NotificationPopup {} }
    PanelLoader { identifier: "iiOnScreenDisplay"; component: OnScreenDisplay {} }
    PanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    PanelLoader { identifier: "iiOverview"; component: Overview {} }
    PanelLoader { identifier: "iiPolkit"; component: Polkit {} }
    PanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    PanelLoader { identifier: "iiSessionScreen"; component: SessionScreen {} }
    PanelLoader { identifier: "iiSidebarLeft"; component: SidebarLeft {} }
    PanelLoader { identifier: "iiSidebarRight"; component: SidebarRight {} }
    PanelLoader { identifier: "iiVerticalBar"; extraCondition: Config.options?.bar?.vertical ?? false; component: VerticalBar {} }
    PanelLoader { identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }

    PanelLoader { identifier: "iiClipboard"; component: ClipboardModule.ClipboardPanel {} }
}
