# Modules Catalogue

Modules are the UI. They render and orchestrate, and they read state from `services/`, `Config` and `GlobalStates` without owning it.

## Folders

| Folder | Holds |
|---|---|
| `modules/ii/` | Material (ii), a plugin from [inir-hub](https://github.com/snowarch/inir-hub) like the other two: bar, vertical bar, dock, sidebars, dashboard, control panel, notification popups, OSD, settings |
| `modules/waffle/` | Waffle: taskbar, start menu, action center, notification center, task view, widgets, `looks/` tokens, settings |
| `modules/iris/` | iRiS: bar, field, frame, dock, control, studio, settings, style. See [iRiS](IRIS.md) |
| `modules/shared/` | Surfaces that two or more families load: background, overview, clipboard, lock, mascot and more |
| `modules/common/` | The kit: `Config.qml`, `Appearance.qml`, `Directories.qml`, `ThemePresets.qml`, and `widgets/` (about 190 widgets, listed in `widgets/qmldir`) |

## How panels load

Loading has two stages. `shell.qml` loads one family's critical host first (`modules/{ii,waffle,iris}/critical/Shell*CriticalPanels.qml`). It holds only first-frame surfaces. When `GlobalStates.deferredPanelsReady` is set, it loads the family's `Shell*PanelsImpl.qml`. Both paths come from the family's `plugin.json` (`entries`), read by `services/Plugins.qml`: `shell.qml` never names a family. That impl declares `DeferredPanelLoader` and `OnDemandPanelLoader`.

A panel loads only when:

1. `Config.ready` is true.
2. Its ID is in `Config.options.enabledPanels`. A fresh install starts from `defaults/config.json`; a family running for the first time adds the list in its `plugin.json` (`enabledPanels`). Users switch panels off in Settings › Modules.
3. Any `extraCondition` holds.
4. Its open state or the deferred phase allows it.

## Material ii panel IDs

| Module | Panel ID |
|---|---|
| `ii/bar/` | `iiBar` |
| `ii/verticalBar/` | `iiVerticalBar` |
| `ii/dock/` | `iiDock` |
| `shared/background/` | `iiBackground` |
| `ii/sidebar/`, `ii/sidebarLeft/`, `ii/sidebarRight/` | `iiSidebarLeft`, `iiSidebarRight` |
| `ii/controlPanel/` | `iiControlPanel` |
| `ii/dashboard/` | `iiDashboard` |
| `ii/notificationPopup/`, `ii/onScreenDisplay/` | `iiNotificationPopup`, `iiOnScreenDisplay` |

`sidebar/` is the physical host. `sidebarLeft/` holds feature content (AI chat, YT Music, Wallhaven, translator, World Clock). `sidebarRight/` holds system content (quick toggles, calendar, notifications, mixer, Bluetooth and Wi-Fi, Screen Time). Either role can sit on either edge.

Surfaces in `modules/shared/` keep their `ii` IDs: `iiOverview`, `iiOverlay`, `iiClipboard`, `iiCheatsheet`, `iiMediaControls`, `iiWallpaperSelector`, `iiWallpaperLauncher`, `iiSessionScreen`, `iiOnScreenKeyboard`, `iiLock`, `iiPolkit`, `iiRegionSelector`, `iiScreenCorners`, `iiTilingOverlay`, `iiShellUpdate`, `iiRecordingOsd`, `iiWorkspaceStrip`, `iiMascotCompanion`, `iiBootGreeting`.

## Waffle panel IDs

| Module | Panel ID |
|---|---|
| `waffle/bar/` | `wBar` |
| `waffle/background/` | `wBackground` |
| `waffle/backdrop/` | `wBackdrop` |
| `waffle/startMenu/` | `wStartMenu` |
| `waffle/actionCenter/` | `wActionCenter` |
| `waffle/notificationCenter/` | `wNotificationCenter` |
| `waffle/taskview/` | `wTaskView` |
| `waffle/widgets/` | `wWidgets` |
| `waffle/notificationPopup/`, `waffle/onScreenDisplay/` | `wNotificationPopup`, `wOnScreenDisplay` |
| `waffle` presentation of shared lock, polkit and session screen | `wLock`, `wPolkit`, `wSessionScreen` |

`waffle/looks/Looks.qml` holds the Waffle tokens. Waffle owns its clipboard in `modules/waffle/clipboard/`.

## Bar layout

The ii bar reads `bar.layout`, which has five zones: `left`, `centerLeft`, `center`, `centerRight` and `right`. `workspaces` stays in the centre. The bar page is `modules/ii/settings/BarConfig.qml`.

`modulesLayout`, `edgeModulesLayout` and `modulesPlacement` are deprecated. `Config.qml` keeps them only so old files still load. Migration `028-bar-modular-layout` is disabled, because the bar falls back to its built-in layout and existing configs need no rewrite.

## Notable behaviour

- **Screen Time.** `services/ScreenTime.qml` runs only when `sidebar.screenTime.enable` is on, which is off by default. The widgets are `modules/ii/sidebarRight/screenTime/ScreenTimeWidget.qml` and `modules/waffle/actionCenter/screenTime/ScreenTimePage.qml`.
- **World Clock.** `modules/ii/sidebarLeft/widgets/WorldClockWidget.qml`, configured under `sidebar.widgets.worldClock_settings`.
- **Dock.** Scrolling an app icon cycles that app's windows (`modules/ii/dock/DockAppButton.qml`). `dock.notificationBadge` shows pending notifications on icons.
- **Clipboard.** `Ctrl+P` pins an entry. Pins are stored in `clipboard.pinned`.

## Contributor rules

1. Read [Architecture Overview](ARCHITECTURE_OVERVIEW.md) and find the family that owns the module. A family's code
   lives in inir-hub (`families/<id>`); the shell links it in at `modules/<id>`.
2. Use `Appearance.*` in ii and shared code, `Looks.*` in Waffle, and `IrisStyle.*` in iRiS.
3. Put first-frame surfaces in a `critical/` host. Everything else goes in the family's `Shell*PanelsImpl.qml`. Shell-wide IPC routers stay in `shell.qml`.
4. Register shared widgets in `modules/common/widgets/qmldir`.
5. If you touch a shared module, test every family that loads it.
