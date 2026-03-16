---
trigger: model_decision
description: Pull when you need the authoritative startup flow, panel-family architecture, config system, directory structure, or shell loading model for iNiR.
---

# iNiR Architecture — Verified from source code

## What is iNiR

Linux desktop shell built with Quickshell (QML-based Wayland shell framework).
Treat **iNiR** as the authoritative product identity. It descends from end-4's illogical-impulse and targets Niri first, with secondary Hyprland support.
Production software — used daily on real desktops. Changes affect real users.

Legacy user config path: `~/.config/illogical-impulse/config.json` (still loaded by Config.qml via FileView + JsonAdapter).

## Entry Point: shell.qml

Root type: `ShellRoot` (Quickshell-specific, not Item/Window).

Startup flow:
1. Environment pragmas set QT_SCALE_FACTOR=1, disable WebEngine cookies, etc.
2. Singleton services force-instantiated via dummy property bindings
3. `Config.ready` triggers panel loading
4. `ThemeService.applyCurrentTheme()` and `IconThemeService.ensureInitialized()` deferred via `Qt.callLater`
5. `Hyprsunset.load()`, `FirstRunExperience.load()`, `ConflictKiller.load()` called

## Panel Families: ii vs waffle

Two mutually exclusive panel families loaded via `LazyLoader`:
- `ShellIiPanels` active when `panelFamily !== "waffle"` — Material Design family (23 panels)
- `ShellWafflePanels` active when `panelFamily === "waffle"` — Windows 11 family (24 panels, mixes waffle + shared ii)

Switching families: `shell.qml → startFamilyTransition()` → `FamilyTransitionOverlay` drives animation → `applyPendingFamily()` writes config mid-animation → panels swap → `finishFamilyTransition()`.

## Panel Loading Pattern

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when ALL true: `Config.ready` + `identifier in Config.options.enabledPanels` + `extraCondition`.

`enabledPanels` is a top-level array in config (not nested). Users can manually remove panel identifiers to disable them.

## ii Family Panels (23)

iiBar, iiBackground, iiBackdrop, iiCheatsheet, iiControlPanel, iiDock, iiLock, iiMediaControls, iiNotificationPopup, iiOnScreenDisplay, iiOnScreenKeyboard, iiOverlay, iiOverview, iiPolkit, iiRegionSelector, iiScreenCorners, iiSessionScreen, iiSidebarLeft, iiSidebarRight, iiTilingOverlay, iiVerticalBar, iiWallpaperSelector, iiCoverflowSelector, iiClipboard

## waffle Family Panels (24)

wBar, wBackground, wBackdrop, wStartMenu, wActionCenter, wNotificationCenter, wNotificationPopup, wOnScreenDisplay, wWidgets, wLock, wPolkit, wSessionScreen + shared ii panels: iiCheatsheet, iiControlPanel, iiLock, iiOnScreenKeyboard, iiOverlay, iiOverview, iiPolkit, iiRegionSelector, iiScreenCorners, iiSessionScreen, iiTilingOverlay, iiWallpaperSelector, iiCoverflowSelector, iiClipboard

## Config System (Config.qml, 1385 lines)

- `Config.options` — alias to JsonAdapter (THE access point, 51 top-level sections)
- `Config.ready` — bool, true after JSON loaded (or created if missing)
- `Config.setNestedValue(path, value)` — writes + fires `configChanged()` signal
- `Config.flushWrites()` — bypass 50ms debounce, write immediately
- File: `~/.config/illogical-impulse/config.json`
- Auto-creates file + parent dirs if missing
- Hot-reload: `watchChanges: true` — external edits auto-apply
- Debounce: 50ms for both reads and writes

Top-level config sections: enabledPanels, panelFamily, familyTransitionAnimation, policies, ai, appearance, performance, powerProfiles, idle, modules, gameMode, reloadToasts, audio, apps, background, bar, battery, closeConfirm, conflictKiller, crosshair, display, dock, interactions, language, light, lock, media, networking, notifications, osd, osk, overlay, overview, altSwitcher, regionSelector, resources, musicRecognition, voiceSearch, search, sidebar, sounds, time, wallpaperSelector, screenRecord, windows, settingsUi, hacks, tray, updates, shellUpdates, welcomeWizard, waffles, workSafety

## GlobalStates (GlobalStates.qml, 204 lines)

Panel visibility booleans (all `property bool`, default `false` except `barOpen: true`):

barOpen, crosshairOpen, sidebarLeftOpen, sidebarRightOpen, mediaControlsOpen, osdBrightnessOpen, osdVolumeOpen, osdMediaOpen, oskOpen, overlayOpen, overviewOpen, altSwitcherOpen, clipboardOpen, settingsOverlayOpen, regionSelectorOpen, screenLocked, sessionOpen, wallpaperSelectorOpen, cheatsheetOpen, coverflowSelectorOpen, controlPanelOpen, workspaceShowNumbers

Waffle-specific: searchOpen, waffleActionCenterOpen, waffleNotificationCenterOpen, waffleWidgetsOpen, waffleAltSwitcherOpen, waffleClipboardOpen, waffleTaskViewOpen

Key behaviors:
- Waffle panels are mutually exclusive (opening one closes others) unless `allowMultiplePanels` config
- Opening sidebarRight auto-dismisses notifications (`Notifications.timeoutAll()` + `markAllRead()`)
- `screenZoom` is Hyprland-only (calls `hyprctl`)
- `primaryScreen` is computed from `Config.options.display.primaryMonitor`

## Directory Structure

```
shell.qml                    # Root entry point
GlobalStates.qml             # Global UI state singleton
modules/                     # 30 UI modules
├── common/                  # Shared: Appearance, Config, widgets (126), functions
├── bar/                     # Top bar (ii family)
├── dock/                    # App dock
├── sidebarLeft/             # Left sidebar (AI, apps, webapps)
├── sidebarRight/            # Right sidebar (toggles, notepad, calendar)
├── overview/                # Workspace overview
├── waffle/                  # Windows 11-style family (bar, start menu, action center, etc.)
├── settings/                # Multi-page settings UI
├── lock/                    # Lock screen
├── notificationPopup/       # Toast notifications
├── onScreenDisplay/         # OSD (volume, brightness)
└── [24 more modules]
services/                    # 59 singleton services
defaults/config.json         # Default config (1106 lines, 51 sections)
translations/                # i18n (15+ languages)
scripts/                     # Setup, theming, system integration
sdata/                       # Distribution: PKGBUILDs, install libs, dist-arch/fedora/debian
```
