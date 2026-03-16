---
trigger: model_decision
description: Pull when you need exact singleton APIs, config persistence behavior, service properties, or IPC-relevant service contracts.
---

# iNiR Services API Reference (Verified from source code)

59 singletons in `services/qmldir`. Key APIs below.

## Core Infrastructure

### Config (modules/common/Config.qml) — 200 dependents
```
Config.options           : JsonAdapter alias — THE access point for all config
Config.ready             : bool — true after JSON loaded
Config.setNestedValue(path, value) : void — dot-string or array path, auto-coerces types
Config.flushWrites()     : void — bypass 50ms debounce
Config.configChanged()   : signal — fired on every write
```
File: `~/.config/illogical-impulse/config.json` (legacy user config path). Hot-reload via watchChanges.

### GlobalStates (root/GlobalStates.qml) — 129 dependents
```
Panel visibility booleans (all default false except barOpen: true):
  barOpen, crosshairOpen, sidebarLeftOpen, sidebarRightOpen, mediaControlsOpen,
  osdBrightnessOpen, osdVolumeOpen, osdMediaOpen, oskOpen, overlayOpen, overviewOpen,
  altSwitcherOpen, clipboardOpen, settingsOverlayOpen, regionSelectorOpen, screenLocked,
  sessionOpen, wallpaperSelectorOpen, cheatsheetOpen, coverflowSelectorOpen, controlPanelOpen

Waffle-specific (mutually exclusive unless allowMultiplePanels):
  searchOpen, waffleActionCenterOpen, waffleNotificationCenterOpen, waffleWidgetsOpen,
  waffleAltSwitcherOpen, waffleClipboardOpen, waffleTaskViewOpen

Other:
  osdMediaAction           : string — "play"|"pause"|"next"|"previous"
  superDown                : bool — Super key held
  superReleaseMightTrigger : bool
  workspaceShowNumbers     : bool
  wallpaperSelectionTarget : string — "main"|"backdrop"|"waffle"|"waffle-backdrop"
  wallpaperSelectorTargetMonitor : string
  familyTransitionActive   : bool
  familyTransitionDirection: string — "left"|"right"
  primaryScreen            : var — computed from display.primaryMonitor config
  screenZoom               : real — Hyprland only (hyprctl cursor:zoom_factor)
  requestRipple(x, y, screenName) : signal

Behaviors:
  - Opening waffle panel auto-closes others (unless allowMultiplePanels)
  - Opening sidebarRight auto-dismisses notifications (timeoutAll + markAllRead)
  - screenZoom is Hyprland-only
```

### Appearance (modules/common/Appearance.qml) — 352 dependents
See 02-theming.md for full token reference.

### Translation (services/Translation.qml) — 260 dependents
```
Translation.tr(text)     : string — lookup translation, fallback = key itself
Translation.translations : var (object) — bundled translations
Translation.generatedTranslations : var — user AI-generated translations
Translation.languageCode : string — active locale
Translation.availableLanguages : var (array)
Translation.allAvailableLanguages : var — union of bundled + generated
```

## Audio & Media

### Audio
```
Audio.value              : int — sink volume 0-100
Audio.sink               : PipewireNode — default output
Audio.source             : PipewireNode — default input
Audio.micBeingAccessed   : bool — privacy indicator
Audio.incrementVolume()  : void
Audio.decrementVolume()  : void
Audio.toggleMute()       : void
Audio.toggleMicMute()    : void
```

### MprisController
```
MprisController.players       : list — MPRIS player list
MprisController.trackedPlayer : var — currently tracked player
```

### YtMusic
```
YtMusic.currentTitle     : string
YtMusic.searchResults    : var
YtMusic.play(url)        : void
YtMusic.search(query)    : void
```

## System

### Battery
```
Battery.percentage       : int — 0-100
Battery.isCharging       : bool
Battery.isPluggedIn      : bool
Battery.isLow            : bool — below threshold
Battery.isCritical       : bool — below critical threshold
Battery.timeToFull       : int — seconds
Battery.timeToEmpty      : int — seconds
```

### Brightness
```
Brightness.monitors      : var — per-monitor brightness list
Brightness.increaseBrightness(monitorName?) : void
Brightness.decreaseBrightness(monitorName?) : void
```

### Network
```
Network.wifi             : var — wifi state object
Network.ethernet         : var — ethernet state object
Network.wifiNetworks     : var — scan results
Network.wifiEnabled      : bool
Network.toggleWifi()     : void
```

### ResourceUsage
```
ResourceUsage.cpuUsage              : real — 0-100
ResourceUsage.memoryUsedPercentage  : real — 0-100
ResourceUsage.gpuUsage              : real — nvidia-smi based
ResourceUsage.cpuTemp               : real
ResourceUsage.gpuTemp               : real
```

### BluetoothStatus
```
BluetoothStatus.available  : bool
BluetoothStatus.enabled    : bool
BluetoothStatus.connected  : bool
```

## Compositor

### CompositorService
```
CompositorService.isNiri       : bool
CompositorService.isHyprland   : bool
CompositorService.compositor   : string — "niri"|"hyprland"|"unknown"
CompositorService.sortedToplevels : var — windows sorted by focus
```

### NiriService
```
NiriService.workspaces     : var — workspace list
NiriService.windows        : var — window list
NiriService.activeWindow   : var — focused window
NiriService.currentOutput  : string — focused monitor name
NiriService.inOverview     : bool
NiriService.focusWindow(id): void
```

### MinimizedWindows (Niri-only)
```
MinimizedWindows.minimize(windowId)  : void — moves to workspace 99
MinimizedWindows.restore(windowId)   : void
MinimizedWindows.isMinimized(id)     : bool
```

## Theming

### ThemeService
```
ThemeService.currentTheme    : string — theme id
ThemeService.ready           : bool
ThemeService.setTheme(id)    : void — applies + external propagation
ThemeService.applyCurrentTheme() : void
ThemeService.recentThemes    : var — last 4 themes
ThemeService.scheduleEnabled : bool — time-based switching
```

### MaterialThemeLoader
```
MaterialThemeLoader.ready        : bool
MaterialThemeLoader.isAutoTheme  : bool — theme === "auto"
MaterialThemeLoader.reapplyTheme(): void
```

### IconThemeService
```
IconThemeService.availableThemes  : var
IconThemeService.smartIconName(name) : string — resolves icon with substitutions
IconThemeService.ensureInitialized() : void
```

## Panels & UI

### Notifications
```
Notifications.popups       : var — active popup list
Notifications.groups       : var — grouped notification list
Notifications.dismiss(id)  : void
Notifications.timeoutAll() : void
Notifications.markAllRead(): void
```

### Cliphist
```
Cliphist.entries           : var — clipboard history
Cliphist.fuzzyQuery(q)     : var — filtered results
Cliphist.paste(id)         : void
Cliphist.pasteText(id)     : void — paste via ydotool typing
```

### AppSearch
```
AppSearch.sloppySearch(query, apps) : var — fuzzy app search with substitution
```

### LauncherSearch
```
LauncherSearch.query       : string — current search text
LauncherSearch.results     : var — unified results
// Prefix dispatch: no prefix=apps, ;=clipboard, :=emoji, /=actions
```

### TaskbarApps
```
TaskbarApps.apps           : var — merged pinned + open apps
TaskbarApps.togglePin(appId) : void
```

## Data & Persistence

### Persistent (modules/common/Persistent.qml)
```
Persistent.ready           : bool
Persistent.states          : JsonAdapter — persistent state object
  .ai.model                : string — last AI model
  .ai.temperature          : real
  .cheatsheet.tabIndex     : int
  .sidebar.bottomGroup.tab : int
  .sidebar.compactGroup.tab: int
  .booru.allowNsfw         : bool
  .booru.provider          : string
  .idle.inhibit            : bool
  .gameMode.manualActive   : bool
  .overlay.open            : list<string> — open overlay widgets
  .overlay.[widget].{pinned, clickthrough, x, y, width, height}
  .timer.{tab, pomodoro, stopwatch, countdown}
  .screenCast.active       : bool
```
File: `Directories.state + "/states.json"` (resolved persistent state path). Hot-reload + 100ms debounce.

### Events
```
Events.list                : var — calendar events
Events.addEvent(event)     : void
Events.removeEvent(id)     : void
```

### Todo
```
Todo.list                  : var — todo items
Todo.addTask(text)         : void
Todo.markDone(id)          : void
Todo.removeTask(id)        : void
```

### Notepad
```
Notepad.text               : string
Notepad.setTextValue(text) : void
```

### KeyringStorage
```
KeyringStorage.setNestedField(path, value) : void
KeyringStorage.fetchKeyringData()          : void
// Stores API keys and secrets in gnome-keyring as JSON blob
```

## Background & Wallpaper

### Wallpapers
```
Wallpapers.effectiveWallpaperUrl : string — current wallpaper file:// URL
Wallpapers.set(path)             : void
Wallpapers.next()                : void
Wallpapers.random()              : void
```

### WallpaperListener
```
WallpaperListener.effectivePerMonitor : var — per-monitor wallpaper map
WallpaperListener.isVideoPath(path)   : bool
```

### Weather
```
Weather.data               : var — wttr.in parsed data
Weather.location           : string
Weather.enabled            : bool
```

## Power & Idle

### Idle
```
Idle.inhibit               : bool
Idle.toggleInhibit()       : void
// Wraps swayidle: screen-off → lock → suspend
```

### GameMode
```
GameMode.active            : bool — auto-detected or manual
GameMode.autoDetect        : bool
GameMode.toggle()          : void
// When active: disables animations, effects, reduces resource usage
```

### Hyprsunset
```
Hyprsunset.active          : bool
Hyprsunset.automatic       : bool — time-based
Hyprsunset.colorTemperature: int — Kelvin
Hyprsunset.load()          : void
```

## Directories (modules/common/Directories.qml)

Key paths:
```
Directories.home, .config, .state, .cache, .documents, .downloads, .pictures
Directories.assetsPath             = shellPath("assets")
Directories.scriptPath             = shellPath("scripts")
Directories.shellConfig            = ~/.config/illogical-impulse  (legacy config namespace)
Directories.shellConfigPath        = ~/.config/illogical-impulse/config.json
Directories.generatedMaterialThemePath = ~/.local/state/quickshell/user/generated/colors.json
Directories.todoPath               = ~/.local/state/quickshell/user/todo.json
Directories.notepadPath            = ~/.local/state/quickshell/user/notepad.txt
Directories.notificationsPath      = ~/.local/state/quickshell/user/notifications.json
Directories.coverArt               = ~/.cache/quickshell/media/coverart
Directories.wallpaperSwitchScriptPath = scripts/colors/switchwall.sh
Directories.recordScriptPath       = scripts/videos/record.sh
Directories.aiTranslationScriptPath = scripts/ai/gemini-translate.sh
Directories.aiChats                = ~/.local/state/quickshell/user/ai/chats
```
