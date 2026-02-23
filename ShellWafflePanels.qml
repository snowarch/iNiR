import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.onScreenKeyboard
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector
import qs.modules.inir.overlay
import "modules/clipboard" as ClipboardModule

import qs.modules.waffle.actionCenter
import qs.modules.waffle.altSwitcher as WaffleAltSwitcherModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import qs.modules.common

Item {
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Waffle style (Windows 11)
    PanelLoader { identifier: "wBar"; component: WaffleBarModule.WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wStartMenu"; component: WaffleStartMenu {} }
    PanelLoader { identifier: "wActionCenter"; component: WaffleActionCenter {} }
    PanelLoader { identifier: "wNotificationCenter"; component: WaffleNotificationCenter {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }
    PanelLoader { identifier: "wLock"; component: Lock {} }
    PanelLoader { identifier: "wWidgets"; extraCondition: Config.options?.waffles?.modules?.widgets ?? true; component: WaffleWidgets {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wPolkit"; component: Polkit {} }
    PanelLoader { identifier: "wSessionScreen"; component: SessionScreen {} }

    // Shared modules that work with waffle
    PanelLoader { identifier: "inirCheatsheet"; component: Cheatsheet {} }
    PanelLoader { identifier: "inirOnScreenKeyboard"; component: OnScreenKeyboard {} }
    PanelLoader { identifier: "inirOverlay"; component: Overlay {} }
    PanelLoader { identifier: "inirOverview"; component: Overview {} }
    PanelLoader { identifier: "inirPolkit"; component: Polkit {} }
    PanelLoader { identifier: "inirRegionSelector"; component: RegionSelector {} }
    PanelLoader { identifier: "inirScreenCorners"; component: ScreenCorners {} }
    PanelLoader { identifier: "inirSessionScreen"; component: SessionScreen {} }
    PanelLoader { identifier: "inirWallpaperSelector"; component: WallpaperSelector {} }
    PanelLoader { identifier: "inirClipboard"; component: ClipboardModule.ClipboardPanel {} }

    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && Config.options?.panelFamily === "waffle"; component: WaffleClipboardModule.WaffleClipboard {} }

    // Waffle AltSwitcher - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && Config.options?.panelFamily === "waffle"; component: WaffleAltSwitcherModule.WaffleAltSwitcher {} }

    // Waffle TaskView - experimental, disabled by default
    PanelLoader { identifier: "wTaskView"; component: WaffleTaskViewModule.WaffleTaskView {} }
}
