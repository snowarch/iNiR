---
trigger: model_decision
description: Pull when mapping modules, services, widgets, or choosing the authoritative runtime surface behind a feature.
---

# iNiR Modules & Services Map (Verified from source code)

## Modules (30 directories under modules/)

| Module | Entry Point | What it does |
|--------|-------------|-------------|
| **altSwitcher** | AltSwitcher.qml | Alt+Tab app switcher with presets, blur/glass, MRU ordering |
| **background** | Background.qml | Per-monitor desktop wallpaper layer with embedded clock/media/weather widgets |
| **bar** | Bar.qml | Horizontal top bar (ii family) per monitor, screen-filtered, hides during lock |
| **cheatsheet** | Cheatsheet.qml | Floating keybind reference + "periodic table" UI showcase |
| **clipboard** | ClipboardPanel.qml | Clipboard history (cliphist backend) with search and image previews |
| **closeConfirm** | CloseConfirm.qml | Intercept dialog before window close with grace period + debounce |
| **common** | *(library)* | Shared core: Appearance, Config, Persistent, Directories, Icons, Images, StylePresets, ThemePresets, ToastManager, 126 widgets, utility functions |
| **controlPanel** | ControlPanel.qml | Quick-access 380px popup for system toggles |
| **dashboard** | *(sub-panels)* | Media, Overview, Wallpapers, Weather sub-panel modules |
| **dock** | Dock.qml | App dock with pill/macOS styles, configurable position, pin state |
| **ii** | overlay/Overlay.qml | Desktop overlay with pinnable floating widgets (notes, mixer, FPS, recorder, Discord) |
| **lock** | Lock.qml | Lock screen with keyring unlock, per-monitor, compositor-aware |
| **mediaControls** | MediaControls.qml | Floating media popup with album art, MPRIS player list, Cava visualizer |
| **notificationPopup** | NotificationPopup.qml | Toast notifications in configurable corner, hidden during lock/GameMode |
| **onScreenDisplay** | OnScreenDisplay.qml | OSD for volume/brightness on focused monitor |
| **onScreenKeyboard** | OnScreenKeyboard.qml | Virtual keyboard with pin, ydotool key release on close |
| **overview** | Overview.qml | Workspace overview per monitor with live thumbnails, search, Niri+Hyprland |
| **polkit** | Polkit.qml | Polkit auth dialog full-screen overlay per monitor |
| **regionSelector** | RegionSelector.qml | Interactive screen region selector for screenshots |
| **screenCorners** | ScreenCorners.qml | Invisible corner hit-zones (toggle sidebars) + fake rounded corners |
| **sessionScreen** | SessionScreen.qml | Session menu (logout/shutdown/reboot/sleep) on focused monitor |
| **settings** | *(multi-page)* | Settings UI pages: general, interface, bar, background, angel editor, custom theme, about |
| **shellUpdate** | ShellUpdateOverlay.qml | Update overlay showing available updates + local mod diffs |
| **sidebarLeft** | SidebarLeft.qml | Left sliding panel (AI chat, app launcher, webapps) |
| **sidebarRight** | SidebarRight.qml | Right sliding panel (toggles, notepad, calendar, quick settings) |
| **tilingOverlay** | TilingOverlay.qml | Niri-only tiling layout picker OSD |
| **verticalBar** | VerticalBar.qml | Vertical variant of the bar for side-mounted layouts |
| **waffle** | bar/WaffleBar.qml | Windows 11-style family: bar, start menu, action center, backdrop, notification center, looks |
| **wallpaperSelector** | WallpaperSelector.qml | Per-monitor wallpaper picker with coverflow browsing |
| **gowallPanel** | *(empty)* | Stub/placeholder — no files |
| **surface** | *(empty)* | Structural stub — empty subdirectories |

## Services (59 singletons under services/)

| Service | What it does | Key API |
|---------|-------------|---------|
| **Ai** | LLM chat (Gemini, OpenAI, Mistral) | `models`, `responseFinished` signal |
| **AnimeService** | AniList GraphQL: schedule, seasonal, top-airing | `schedule`, `seasonalAnime` |
| **AppSearch** | Fuzzy app search + window-class→icon resolution | `sloppySearch`, substitution tables |
| **Audio** | PipeWire sink/source: volume, mute, mic detection | `value`, `sink`, `source`, `micBeingAccessed` |
| **Autostart** | User-configured autostart apps + systemd units | `entries`, `load()` |
| **AwwwBackend** | Animated wallpaper daemon (awww) | `active`, `available`, `transitionType` |
| **Battery** | UPower: charge, thresholds, notifications | `percentage`, `isCharging`, `isLow`, `isCritical` |
| **BluetoothStatus** | Bluetooth adapter + device info | `available`, `enabled`, `connected` |
| **Booru** | Image-board API (yande.re, Danbooru, Gelbooru) | `responses`, `tagSuggestion` signal |
| **Brightness** | Per-monitor brightnessctl/ddcutil | `monitors`, `increaseBrightness()` |
| **Cliphist** | Clipboard history (cliphist wrapper) | `entries`, `fuzzyQuery()`, `paste()` |
| **CompositorService** | Compositor detection + sorted toplevels | `isNiri`, `isHyprland`, `compositor` |
| **ConflictKiller** | Kill conflicting tray/notification daemons | `load()` |
| **DateTime** | Formatted clock/date/uptime strings | `time`, `date`, `shortDate`, `uptime` |
| **EasyEffects** | Audio processing control | `available`, `active`, `toggle()` |
| **Emojis** | Emoji list with fuzzy search | `list`, `fuzzyQuery()` |
| **Events** | Persistent calendar/event JSON store | `list`, `addEvent()`, `removeEvent()` |
| **FirstRunExperience** | First-launch wizard trigger | `load()` |
| **FontSyncService** | Sync typography to GTK/KDE | `mainFont`, `syncEnabled` |
| **GameMode** | Auto-detect fullscreen → disable effects | `active`, `autoDetect`, `toggle()` |
| **HyprlandKeybinds** | Parse Hyprland keybind config | `keybinds` |
| **HyprlandXkb** | Hyprland/Niri keyboard layout tracking | `currentLayoutName`, `currentLayoutCode` |
| **Hyprsunset** | Night-light (hyprsunset/wlsunset) | `active`, `automatic`, `colorTemperature` |
| **IconThemeService** | Icon theme management | `availableThemes`, `smartIconName()` |
| **Idle** | swayidle: screen-off/lock/suspend | `inhibit`, `toggleInhibit()` |
| **KeyringStorage** | Keyring-backed secret storage (JSON blob) | `setNestedField()`, `fetchKeyringData()` |
| **LatexRenderer** | LaTeX→SVG via MicroTeX with cache | `requestRender()`, `renderFinished` |
| **LauncherSearch** | Unified launcher search with debounce | `query`, prefix dispatch |
| **MaterialThemeLoader** | Loads generated Material colors into Appearance | `ready`, `reapplyTheme()` |
| **MinimizedWindows** | Niri minimize emulation (workspace 99) | `minimize()`, `restore()`, `isMinimized()` |
| **MprisController** | MPRIS media player tracking | `players`, `trackedPlayer` |
| **Network** | WiFi/ethernet via nmcli | `wifi`, `ethernet`, `wifiNetworks` |
| **NiriKeybinds** | Parse niri config.kdl keybind JSON | `keybinds`, `reload()` |
| **NiriService** | Niri IPC: workspaces, windows, outputs | `workspaces`, `windows`, `activeWindow` |
| **Notepad** | Simple persistent notepad | `text`, `setTextValue()` |
| **Notifications** | Notification daemon: groups, popups, history | `popups`, `groups`, `dismiss()` |
| **PolkitService** | Polkit auth agent wrapper | `active`, `cancel()`, `submit()` |
| **PowerProfilePersistence** | Restore UPower profile on startup | reads `powerProfiles.*` config |
| **Privacy** | Mic-in-use + screen-sharing detection | `micActive`, `screenSharing` |
| **RecorderStatus** | Screen recording active state | `isRecording` |
| **RedditService** | Reddit JSON API with cache | `posts`, `currentSubreddit` |
| **ResourceUsage** | CPU/RAM/GPU/temps monitor | `cpuUsage`, `memoryUsedPercentage` |
| **SessionWarnings** | Detect running package managers | `packageManagerRunning` |
| **ShellUpdates** | Git update checker + overlay | `hasUpdate`, `commitsBehind` |
| **SongRec** | Music recognition (songrec) | `running`, `toggleRunning()` |
| **SystemInfo** | OS release info | `distroName`, `username` |
| **TaskbarApps** | Merged pinned+open app list | `apps`, `togglePin()` |
| **ThemeService** | Theme orchestrator: matugen + propagation | `currentTheme`, `ready` |
| **TimerService** | Pomodoro timer | `focusTime`, `breakTime` |
| **Todo** | Persistent JSON to-do list | `list`, `addTask()`, `markDone()` |
| **Translation** | i18n strings (260 dependents) | `translations`, `tr()` |
| **TrayService** | System tray with smart filtering | `smartTray` |
| **Updates** | Arch package update checker | `available`, `count` |
| **VoiceSearch** | Audio transcription → search | `start()`, `transcriptionReady` |
| **Wallhaven** | Wallhaven.cc wallpaper search | `responses`, `tagSuggestion` |
| **WallpaperListener** | Per-monitor wallpaper path resolver | `effectivePerMonitor`, `isVideoPath()` |
| **Wallpapers** | High-level wallpaper management | `set()`, `next()`, `random()` |
| **Weather** | wttr.in weather (GPS/city/coords) | `data`, `location`, `enabled` |
| **WindowPreviewService** | Window screenshot cache | `captureForWindow()` |
| **Ydotool** | ydotool key injection wrapper | `press()`, `release()` |
| **YtMusic** | YouTube Music client via mpv | `currentTitle`, `searchResults` |

## Available Widgets (126 in modules/common/widgets/)

### Config widgets
ConfigRow, ConfigSelectionArray, ConfigSpinBox (icon: `icon`), ConfigSwitch (icon: `buttonIcon`), ConfigTimeInput

### Key Widget Property Gotchas
- `ConfigSwitch.buttonIcon` — NOT `icon`
- `ConfigSpinBox.icon` — NOT `buttonIcon`
- `MaterialSymbol.text` — the icon name goes in `text`, NOT `icon`
- `GlassBackground` requires `screenX`, `screenY` from parent (`mapToGlobal`)
