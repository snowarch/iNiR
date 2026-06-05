# Modules Catalog

UI components organized by panel family. Modules handle rendering and interaction. They don't own global state, they read from services and config singletons.

## How modules load

Every visible panel is wrapped in a `PanelLoader` inside either `ShellIiPanels.qml` (Material ii) or `ShellWafflePanels.qml` (Waffle). A panel loads when:

1. `Config.ready` is true
2. Its identifier is in the `enabledPanels` config array
3. Its `extraCondition` (if any) is satisfied

Users can disable any panel from Settings without touching config files.

## Material ii Panels

### Core

| Module | Panel ID | Description |
|--------|----------|-------------|
| `bar/` | `iiBar` | Top bar. Workspaces, clock, system indicators, tray, weather. ~35 QML files. |
| `verticalBar/` | `iiVerticalBar` | Vertical bar variant for left/right edge placement. |
| `dock/` | `iiDock` | Application dock. Supports all 4 edges (top/bottom/left/right). |
| `background/` | `iiBackground` | Desktop wallpaper layer. Parallax, blur, desktop widget canvas. |

### Sidebars

| Module | Panel ID | Description |
|--------|----------|-------------|
| `sidebarLeft/` | `iiSidebarLeft` | AI chat (Gemini/OpenAI/Ollama), YT Music player, Wallhaven browser, anime tracker, Reddit feed, translator, draggable widgets, World Clock. |
| `sidebarRight/` | `iiSidebarRight` | Quick toggles, calendar with external sync, notification center, volume mixer, Bluetooth/WiFi management, pomodoro timer, todo, calculator, notepad, system monitor, Screen Time. |

### Overlays

| Module | Panel ID | Description |
|--------|----------|-------------|
| `overview/` | `iiOverview` | Workspace overview with app search, calculator, and global actions. |
| `ii/` | `iiOverlay` | Notification overlays and ii-specific UI elements. |
| `clipboard/` | `iiClipboard` | Clipboard history browser with search and image preview. |
| `cheatsheet/` | `iiCheatsheet` | Keybind viewer pulled from compositor config. |
| `controlPanel/` | `iiControlPanel` | Quick settings panel. |
| `mediaControls/` | `iiMediaControls` | MPRIS media player popup with multiple layout presets. |
| `wallpaperSelector/` | `iiWallpaperSelector` | Wallpaper browser with directory navigation. |
| `sessionScreen/` | `iiSessionScreen` | Logout, reboot, shutdown, suspend screen. |

### System

| Module | Panel ID | Description |
|--------|----------|-------------|
| `notificationPopup/` | `iiNotificationPopup` | Notification toast popups. |
| `onScreenDisplay/` | `iiOnScreenDisplay` | Volume and brightness OSD. |
| `onScreenKeyboard/` | `iiOnScreenKeyboard` | Virtual keyboard. |
| `lock/` | `iiLock` | Lock screen with PAM authentication and fingerprint support. |
| `polkit/` | `iiPolkit` | PolicyKit authentication dialog. |
| `regionSelector/` | `iiRegionSelector` | Screenshot and screen recording region selection. |
| `screenCorners/` | `iiScreenCorners` | Hot corners. |
| `tilingOverlay/` | `iiTilingOverlay` | Tiling hints overlay. |
| `shellUpdate/` | `iiShellUpdate` | Shell update notification banner. |
| `recordingOsd/` | `iiRecordingOsd` | Screen recording indicator (disabled by default). |

## Waffle Panels

### Core

| Module | Panel ID | Description |
|--------|----------|-------------|
| `waffle/bar/` | `wBar` | Bottom taskbar. Start button, pinned apps, open windows, system tray, clock. |
| `waffle/background/` | `wBackground` | Desktop wallpaper layer (waffle variant). |

### Primary Overlays

| Module | Panel ID | Description |
|--------|----------|-------------|
| `waffle/startMenu/` | `wStartMenu` | Start menu with app grid, search, pinned apps, recommendations. |
| `waffle/actionCenter/` | `wActionCenter` | Quick settings. WiFi, Bluetooth, volume, brightness, toggles, Screen Time entry point. |
| `waffle/notificationCenter/` | `wNotificationCenter` | Notification list with calendar and external event integration. |
| `waffle/taskview/` | `wTaskView` | Task view (workspace overview with window previews). |
| `waffle/widgets/` | `wWidgets` | Desktop widgets panel. |

### System

| Module | Panel ID | Description |
|--------|----------|-------------|
| `waffle/notificationPopup/` | `wNotificationPopup` | Notification popups (Fluent style). |
| `waffle/onScreenDisplay/` | `wOnScreenDisplay` | Volume/brightness OSD (Fluent style). |
| `waffle/lock/` | `wLock` | Lock screen (Fluent variant). |
| `waffle/polkit/` | `wPolkit` | PolicyKit dialog (Fluent variant). |
| `waffle/sessionScreen/` | `wSessionScreen` | Session screen (Fluent variant). |

### Design System

| Module | Description |
|--------|-------------|
| `waffle/looks/` | `Looks.qml` - complete visual token system. Colors, typography, motion, rounding. |
| `waffle/settings/` | Waffle-specific settings pages. |

## Shared Infrastructure

### modules/common/ (~178 files)

The foundation everything else builds on.

| Component | What it is |
|-----------|-----------|
| **Config.qml** | Configuration singleton. ~60 config sections. [Details](CONFIG_SYSTEM.md) |
| **Appearance.qml** | ii visual tokens. ~500 properties covering colors, rounding, typography, animation. |
| **Directories.qml** | Centralized path resolution. Config, cache, data, scripts, media directories. |
| **widgets/** | 130+ reusable widgets registered in `widgets/qmldir`. Layout, input, display, media, and specialized components. |
| **ThemePresets.qml** | 44 built-in theme presets. |
| **StylePresets.qml** | Style variant definitions. |

## Current notable modules

### Bar layout editor

The ii bar is driven by `Config.options.bar.layout`, split into five zones:

`left`, `centerLeft`, `center`, `centerRight`, `right`

The Settings page uses `BarModuleOrderEditor.qml` to reorder modules and drag available modules into zones. `workspaces` stays the centered pivot. The old `modulesLayout`, `edgeModulesLayout`, and `modulesPlacement` keys are deprecated compatibility baggage, not the runtime source of truth.

Migration `028-bar-modular-layout` exists but is disabled. The bar has a built-in classic fallback, so existing users do not need config rewrites just to update. Good. We learned.

### Screen Time

`services/ScreenTime.qml` tracks focused app usage when `sidebar.screenTime.enable` is true.

Visible surfaces:

- `modules/sidebarRight/screenTime/ScreenTimeWidget.qml`
- `modules/waffle/actionCenter/screenTime/ScreenTimePage.qml`

It stores local daily JSON under the iNiR state directory. It has daily totals, app totals, hourly buckets, and per-app hourly drill-down. It is off by default and hidden from sidebar layouts while disabled.

### World Clock

`modules/sidebarLeft/widgets/WorldClockWidget.qml` is a sidebar-left widget configured through `sidebar.widgets.worldClock_settings`.

If no timezones are configured, it suggests useful zones from the user's locale/system timezone. If the user configures timezones, Settings owns the explicit list and order.

### Shared panels

Some panels work under both families. They keep their `ii` prefix but load in waffle mode too:

`iiCheatsheet`, `iiOnScreenKeyboard`, `iiOverlay`, `iiOverview`, `iiRegionSelector`, `iiScreenCorners`, `iiWallpaperSelector`, `iiClipboard`, `iiRecordingOsd`

## For contributors

1. Check the AGENTS.md in the module directory you're editing (if one exists)
2. Identify which family owns the module before making visual changes
3. Use the correct token system: `Appearance.*` for ii, `Looks.*` for waffle
4. Register new panels in the appropriate panels file
5. Register new shared widgets in `modules/common/widgets/qmldir`
6. If touching shared modules, test under both families
