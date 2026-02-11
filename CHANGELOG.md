# Changelog

All notable changes to iNiR will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.9.0] - 2026-02-11

### Added
- **Shell update overlay**: New layer-shell panel with commit log, changelog preview, and local modifications detection
- **Shell update details**: Click bar indicator to open detailed overlay instead of direct update
- **Weather manual location**: City name input, manual lat/lon coordinates, and GPS support via geoclue
- **Weather geocoding**: Forward geocoding (city → coords) and reverse geocoding (coords → display name) via Nominatim
- **Waffle themes redesign**: Theme cards with live color preview circles, quick-apply, inline rename, import/export
- **WWaffleStylePage options**: Start menu scale slider, clock format options, bar sizing controls (height, icon size, corner radius), desktop peek section
- **Waffle pages icon audit**: Replaced generic icons with descriptive FluentIcons across all settings pages
- **Ko-fi funding**: Added ko_fi to FUNDING.yml

### Changed
- **Waffle settings isolation**: Waffle family always opens its own Win11-style settings window, simplified IPC toggle logic
- **Win11 visual polish**: Redesigned waffle settings widgets with shadows, compact sizing, animated transitions using Looks.transition tokens
- **Weather priority**: Manual coords > manual city > GPS > IP auto-detect
- **ShellUpdates service**: Added overlay state management, manifest parsing, IPC handlers (toggle/open/close/check/update/dismiss)

### Fixed
- **Config schema sync**: Added 6 missing altSwitcher properties, enableAnimation for WaffleBackground, noVisualUi and taskView.closeOnSelect defaults
- **Settings bugs**: Fixed BarConfig layout property name, WaffleConfig bindings and spacing
- **YtMusic persistence**: Connection state and resolvedBrowserArg now persist across restarts
- **YtMusic cookies**: Always use --cookies-from-browser instead of intermediate cookie files, resolve Firefox fork profile paths
- **YtMusic debugging**: Added stderr capture and logging for mpv, converted shell commands to proper array-based Process commands
- **Waffle start menu overflow**: Added clip, Flickable wrapper, min/max height constraints, reduced recommended items from 6 to 4

## [2.8.2] - 2026-02-09

### Added
- **Dock screen filtering**: `screenList` config option for per-monitor dock control, matching bar behavior (thanks @ainia for the reminder)

### Fixed
- **Dock animations**: Resolved flickering during app launch and drag operations (PR #40 by @Legnatbird)

## [2.8.1] - 2026-02-08

### Added
- **Settings search**: Granular per-option search index with spotlight scroll-to navigation
- **Terminal detection**: Auto-detect installed terminals in color config section on first expand
- **Crypto cache**: Persist crypto widget prices and sparkline data across shell restarts
- **Notification options**: `ignoreAppTimeout` and `scaleOnHover` config properties

### Changed
- **Bar center layout**: Both center groups now share effective width so workspaces stay perfectly centered regardless of active utility button count
- **Screen cast toggle (PR #29)**: Simplified to always-interactive toggle with configurable output; removed monitor count detection overhead

### Fixed
- **Media player duplication**: Bottom overlay now uses `displayPlayers` with title/position dedup, matching bar popup behavior
- **Notification popup animations**: Differentiated popup vs sidebar behavior — popups use instant height changes to avoid Wayland resize stair-stepping, with height buffer and clip to prevent content overflow
- **Hardcoded animations**: Replaced raw `NumberAnimation`/`ColorAnimation` with `Appearance.animation` and `Looks.transition` design tokens across TimerIndicator, KeyboardKey, BarMediaPlayerItem, ThemePresetCard, TilingOverlay, and WidgetsContent
- **Screen cast settings**: Added null safety, `setNestedValue` for output field, synced defaults with Config.qml schema
- **Shell updates**: Prevented double repository search fallback when version.json exists but lacks `repo_path`

## [2.8.0] - 2026-02-04

### Added
- **Screen cast toggle**: Bar utility button for Niri screen casting with configurable output (PR #29 by @levpr1c)
- **System sounds volume control**: Configurable volume for timer, pomodoro, and battery notification sounds

### Changed
- **Video wallpapers**: Replaced mpvpaper with Qt Multimedia for native video wallpaper support

### Fixed
- **Terminal color theming**: Auto-fix for Alacritty v0.13+ import order requirement - colors now update correctly with wallpaper changes (Issue #30)
- **Package installation**: Replaced non-existent `matugen-bin` AUR package with `matugen` from official Arch repos (Issue #32)
- **Waffle background**: Added missing optional chaining in config access to prevent startup errors

## [2.7.0] - 2026-01-21

### Added
- **Bar module toggles**: Individual enable/disable options for bar modules (resources, media, workspaces, clock, utility buttons, battery, sidebar buttons)
- **Region search**: Google Lens action via IPC (`region.googleLens`)

### Changed
- **Media player pipeline**: Centralized filtering/deduping via `MprisController.displayPlayers` for consistent behavior across widgets
- **Cava visualizer**: Debounced process activation to avoid rapid stop/start loops

### Fixed
- **Shell performance**: Reduced stutter by rebuilding MPRIS player lists imperatively instead of hot bindings
- **Bar stability**: Null-safe config access for bar components to prevent startup `ReferenceError`
- **Darkly theme generation**: Adaptive clamping to prevent icons/colors from collapsing to pure black/white

## [2.6.0] - 2026-01-11

### Added
- **User modification detection**: Setup now detects user-modified files and preserves them during updates
- **Themes UI favorites**: Star your favorite color themes for quick access in settings
- **Quick Access section**: Combined favorites + recently used themes in compact grid
- **Temperature sensor support**: Extended hwmon detection for older hardware (k10temp, coretemp, etc.)
- **Control Panel**: New unified control panel with modular sections
- **Tiling Overlay**: Visual overlay for tiling operations
- **Tools tab**: New tools section in settings
- **GIF wallpaper support**: Native animated GIF wallpapers with performance optimizations
- **Video wallpaper support**: Video files as wallpapers in wallpaper selector
- **Calculator widget**: Calculator in sidebar left
- **System monitor widget**: System stats widget in sidebar
- **Bar media popup**: Quick media controls popup from bar
- **YouTube Music overhaul**: New player card, track items, account sync, and library import
- **FontSyncService**: Automatic font synchronization service
- **CavaProcess widget**: Reusable cavo visualizer component
- **Terminal config generator**: Auto-generate terminal color schemes from theme

### Changed
- **Anime API**: Switched from Jikan/MAL to AniList API for better reliability
- **Themes UI**: Compact 3-column grid layout with scroll, single-select tag filters
- **Control Panel**: Modularized into separate section components
- **Audio service**: Simplified architecture with improved sidebar widgets
- **Cava visualizers**: Improved with config generator script
- **Aurora dark mode**: Better contrast and color handling
- **Session screen**: Added blurred wallpaper background like lock screen

### Fixed
- **Vertical bar hug mode**: Fixed layout issues with hug corner style
- **Aurora blur corners**: Fixed missing blur in vertical bar Aurora style
- **Dock recreation**: Dock now properly recreates when bar position changes
- **Media popup cava**: Removed problematic cava from bar media popup
- **Hardcoded colors**: Replaced hex colors with ColorUtils for proper theming
- **Notification widgets**: Improved notification item and action button styling
- **Lock surfaces**: Improved backdrop and lock surface rendering
- **YtMusic crashes**: Fixed config race condition and JSON structure issues
- **YtMusic sync**: Resolved synchronization issues and improved UI/UX
- **Bar Aurora corners**: Added opaque background to match bar appearance
- **Bluetooth null guard**: Added safety check for bluetooth service
- **Various UI fixes**: Misc improvements across bar, overview, and settings

## [2.5.0] - 2026-01-03

### Added
- **Reddit tab**: Browse subreddits in sidebar left (disabled by default)
- **Anime Schedule tab**: View anime schedule, seasonal, and top airing from Jikan API (disabled by default)
- **NerdIconMap entries**: Added collections, photo_library, live_tv, tv, movie icons

### Changed
- Wallhaven tab icon changed to `collections` for better Nerd Font glyph in inir style
- Card style toggle now available for inir global style

### Fixed
- Inir button colors in Reddit/Anime tabs using valid color properties
- AnimeCard type badge and genre tags with proper inir container colors
- Optional chaining in Workspaces.qml (`bar?.workspaces`)
- Number style selector disabled when 'Always show numbers' is off

## [2.4.0] - 2026-01-02

### Added
- **Timer pause persistence**: Pomodoro, stopwatch, and countdown now persist pause state across restarts
- **ContextCard timer idle view**: Navigate between Focus/Timer/Stopwatch with slide animations
- **Dock showOnDesktop option**: Control dock visibility when no window is focused
- **Quick Launch editor**: Inline editor in settings to customize quick launch shortcuts
- **Context card weather toggle**: Option to hide weather in context card
- **Cover art blur transition**: Smooth blur effect when track changes

### Changed
- Region search now uses 0x0.st (uguu.se was down)
- Settings search includes Global Style entries
- Faster settings page preloading for search indexing
- Search results show breadcrumb path with chevron icons

### Fixed
- Dock context menu now keeps dock visible while open
- StyledPopup supports buttonHovered fallback for RippleButton
- WeekStrip scroll fixed with acceptedButtons: Qt.NoButton
- NotificationAppIcon safer image error handling
- Aurora colors for workspaces occupied indicator
- Calendar other-month text color in aurora style
- ConfigSelectionArray includes option names in search

## [2.3.0] - 2026-01-01

### Added
- **Dock multi-position**: Dock can now be placed at top, bottom, left, or right
- **Aurora style**: Glass effect with wallpaper blur for panels and popups
- **Inir style**: TUI-inspired style with accent borders and darker colors
- **Voice search**: Voice input with Gemini transcription
- **QuickWallpaper widget**: Quick wallpaper picker in sidebar
- **Wallpaper fill modes**: Stretch, fit, fill, tile options
- **Free OpenRouter models**: Dynamically loaded free AI models
- **Weather forecast**: wttr.in fallback with forecast display
- **Separate dock icon theme**: Independent icon theme for dock

### Changed
- Sidebar animations improved with slide effects
- Lock screen now falls back to swaylock on Niri (avoids crash)
- Cover art download now has retry with exponential backoff
- Improved transparency system for aurora style

### Fixed
- Cover art URLs no longer use query strings (Qt Image compatibility)
- Sidebar widget buttons now work during drag detection
- Aurora style uses solid colors for popups without blur
- Weather retries on startup network issues
- NiriKeybinds config watcher debounced
- Network monitor delayed until component ready
- Dock binding loops and hover behavior
- Lock activates before suspend when configured
- Calendar respects locale's firstDayOfWeek

## [2.2.0] - 2025-12-14

### Added
- Snapshot system for time-machine style rollbacks
- `./setup rollback` command to restore previous states
- Auto git fetch and pull in update command
- Doctor now auto-starts shell if not running
- Fish shell added to core dependencies
- EasyEffects added to audio dependencies

### Changed
- Simplified setup to 4 commands: install, update, doctor, rollback
- Update now checks remote for new commits before syncing
- Update creates snapshot automatically before applying changes
- Doctor now fixes issues automatically (uv pip, version tracking, manifest)
- Removed redundant commands (install-deps, migrate, status, changelog, restore)

### Fixed
- Doctor now uses `uv pip` instead of `pip` for Python package checks
- Update now properly restarts shell after sync
- Backup directory no longer created when empty

## [2.1.0] - 2025-12-14

### Added
- New versioning system with proper version tracking
- `./setup status` command shows installed vs available version
- `./setup changelog` command to view recent changes
- Smart update detection - only syncs when there are actual changes
- Version comparison with remote repository
- Cached remote version checks (1 hour TTL)

### Changed
- Improved `./setup update` to check for changes before syncing
- Better migration system with clearer separation from installation
- Enhanced status output with pending migrations count

### Fixed
- Pomodoro timer now properly syncs with Config changes
- Volume slider maintains sync with external changes (keybinds)
- GameMode state now persists across shell restarts

## [2.0.0] - 2025-12-10

### Added
- Migration system for safe config updates
- `./setup migrate` command for interactive config migrations
- Automatic backups before any config modification
- `./setup restore` command to restore from backups
- Support for both Material (ii) and Fluent (waffle) panel families

### Changed
- `./setup update` now only syncs QML code, never touches user configs
- Migrations are now optional and interactive
- Improved first-run detection and handling

### Philosophy
- User configs are sacred - never modified without explicit consent
- Transparency - users see exactly what will change
- Reversibility - automatic backups, easy restore

## [1.0.0] - 2025-11-01

### Added
- Initial release of iNiR
- Material Design (ii) panel family
- Windows 11 style (waffle) panel family
- System tray with smart activation
- Notifications with Do Not Disturb
- Media controls (MPRIS)
- Workspace management
- Quick settings panel
- Lockscreen
- Game mode for reduced latency
- Hot-reload for development

---

For older changes, see git history: `git log --oneline`
