# Services Catalogue

About 100 QML singletons hold the state and system work that UI should not own. `services/qmldir` registers the eager ones and `services/deferred/qmldir` the ones loaded after the first frame (see [Runtime and Boot](RUNTIME.md)). Modules use them by name.

Before you change a service, find its consumers and prefer additive changes:

```bash
grep -r "ServiceName\." modules/ services/
```

## IPC targets

Only a service with an `IpcHandler` answers `inir <target> <function>`. Some handlers live outside `services/`: `customWidgets` is in `shell.qml`. To list every target:

```bash
grep -rl IpcHandler --include=*.qml . | xargs grep -oP 'target:\s*"\K[^"]+'
```

A new target carries a `///` comment right above its `IpcHandler` (what it is for; a ```kdl block in it becomes its example) and one above each function. The [IPC](IPC.md) page, `inir help` and tab completion are built from those comments:

```qml
/// Volume and mute control.
IpcHandler {
    target: "audio"

    /// Toggle speaker mute
    function mute(): void { root.toggleMute() }
}
```

## Compositor and windows

| Service | Purpose | IPC |
|---|---|---|
| `NiriService` | Niri socket: outputs, workspaces, windows, layouts | `keyboard` |
| `NiriKeybinds` | Niri keybinds, parsed by `inir-accel niri-keybinds` | |
| `CompositorService` | Picks Niri or Hyprland from the socket environment | |
| `HyprlandData`, `HyprlandKeybinds`, `HyprlandXkb` | Legacy Hyprland paths, not maintained | |
| `ShellLayoutController` | Where the active family keeps its bar, dock and sidebars, and the room they take; each family answers through its `layout` part | |
| `ShellEditSession` | Edit mode for moving shell pieces to the edges | `shellLayout` |
| `MinimizedWindows` | Minimised windows, moved to a separate workspace | `minimize` |
| `TaskbarApps`, `WindowPreviewService` | Dock and taskbar apps; window previews | |

## Desktop and widgets

| Service | Purpose | IPC |
|---|---|---|
| `DesktopItems`, `DesktopArrange`, `DesktopEditStage`, `DesktopEditHistory`, `DesktopPresets`, `DesktopWidgetLayout` | Desktop edit mode | |
| `DesktopWidgetStacks` | Widgets stacked in one spot, rotating or paging | `widgetStacks` |
| `CustomWidgets` | User widgets: scan, create, remove | `customWidgets` (in `shell.qml`) |
| `WidgetPowerManager` | Pauses widget rendering in game mode, fullscreen, present, edit | `widgetpower` |
| `LivePins` | A window, or a part of it, kept on screen live. Niri and Umbriel, through qs-rs | `livePins` |

## Audio, media and network

| Service | Purpose | IPC |
|---|---|---|
| `Audio` | PipeWire devices, volume, mute, per-app mixer | `audio` |
| `MprisController` | MPRIS players, grace period between tracks | `mpris` |
| `YtMusic` | YouTube Music through mpv and yt-dlp | `ytmusic` |
| `InnerTube`, `MpvIpc`, `CavaService` (deferred) | Browsing via `inir-accel innertube`; mpv JSON socket; shared cava | |
| `Network` | NetworkManager through `nmcli` | `network` |
| `Vpn` | OpenVPN, WireGuard, IPsec and Tailscale | `vpn` |
| `BluetoothStatus` | Adapter and devices through `Quickshell.Bluetooth` | `bluetooth` |
| `DeviceEvents` | Devices plugged in, connected or lost, one event at a time | `connections` |
| `Privacy` | Microphone and screen sharing, from PipeWire links | `privacy` |

## Power and hardware

| Service | Purpose | IPC |
|---|---|---|
| `Idle` | swayidle timeouts. `idle.onBattery.enable` adds shorter ones | |
| `Battery` | UPower: charge, state, charge limit | `battery` |
| `Brightness` | `brightnessctl` for laptops, `ddcutil` for external monitors | `brightness` |
| `PowerProfilePersistence` | Restores the power profile at startup, when a power profiles daemon is running | |
| `GameMode` | Fullscreen detection, automatic or manual | `gamemode` |
| `GamePerformanceService` | Focused game detection, optional MangoHud CSV | |
| `ResourceUsage` | CPU, RAM, GPU, temperature, disk. Stops after `resources.autoStopDelay` | |
| `ScreenTime` | Focused-app usage, only with `screenTime.enable` | |
| `MemoryPressureService` | Watches the JS heap (Qt V4 memfd leak), offers a restart | `memory` |

## Theming and appearance

| Service | Purpose | IPC |
|---|---|---|
| `ThemeService` | Applies presets, regenerates from the wallpaper | `globalStyle`, `colorMode` |
| `MaterialThemeLoader` | Loads `colors.json` into Material 3 tokens, syncs SDDM | `loginScreen` |
| `Lume` | Keeps content readable over whatever is behind it | |
| `WallpaperLuma` | Brightness and unevenness of the wallpaper under a rect | |
| `Wallpapers`, `WallpaperListener` | Selection, per-monitor and backdrop resolution | |
| `AwwwBackend` | awww animated wallpaper daemon | |
| `IconThemeService`, `FontSyncService` | Icon and font sync to GTK, KDE and Qt | |
| `NiriAnimationPresets` | Presets matched to `config.d/60-animations.kdl` | `niriAnimations` |
| `GowallService` (deferred) | Palette extraction with gowall | |

`ThemePresets` is not a service. It lives in `modules/common/ThemePresets.qml`: 49 presets and Auto.

## Data and storage

| Service | Purpose | IPC |
|---|---|---|
| `Notifications` | Storage, popups, grouping, do not disturb | `notifications` |
| `LiveActivities` | Notifications with progress, shown as activities | |
| `Cliphist` (deferred) | Clipboard history | `cliphistService` |
| `Shelf` (deferred) | Recent clips, screenshots and dropped files | |
| `Events`, `CalendarSync` | Local events in JSON; ICS feeds through `curl` | |
| `Weather` | Open-Meteo, from GPS, coordinates or a city | |
| `WorldClock` | Timezones for the world clock widgets | |
| `Todo`, `Notepad` | Todo list with JSON and markdown sync; plain notes | |
| `KeyringStorage` (deferred) | API keys in GNOME Keyring, through `secret-tool` | |
| `DateTime`, `SystemInfo` | Date and uptime; distro and desktop detection | |

## Session and system

| Service | Purpose | IPC |
|---|---|---|
| `Autostart` | The managed section of `config.d/50-startup.kdl` | `autostart` |
| `TrayService` | System tray, with workarounds for Vesktop and Steam | |
| `ConflictKiller` | Stops conflicting tray and notification daemons at startup | |
| `Hyprsunset` | Night light through wlsunset (Niri) or hyprsunset | |
| `EasyEffects` (deferred) | Audio effects toggle, native or Flatpak | |
| `PolkitService` | PolicyKit agent | |
| `SessionWarnings` (deferred) | Warns about running package managers before logout | |
| `FirstRunExperience` | First-run check; applies a bundled wallpaper, runs `inir welcome` | |
| `MascotMood` | Mood for the mascot | `mascotMood` |

## Applications and content

| Service | Purpose | IPC |
|---|---|---|
| `AppLauncher`, `AppSearch` | Default apps; desktop entry search | |
| `AppCatalog` | Curated catalogue with multi-distro installs | `appCatalog` |
| `Hub` | Community hub, installs through `inir hub` (inir-cli) | `hub` |
| `LauncherSearch` (deferred) | Overview search with prefix routing | |
| `GlobalActions` | Registry of keyboard-driven actions | `globalActions` |
| `PackageSearch` (deferred) | Package search: pacman with AUR, or XBPS | `packageSearch` |
| `Ai` | Gemini, OpenAI, Mistral, OpenRouter, Ollama; tools and streaming | `ai` |
| `VoiceSearch` | Recording and Gemini transcription | `voiceSearch` |
| `AnimeService`, `NewsService` (deferred) | AniList; Google News RSS | |
| `Booru`, `Wallhaven` | Image board and wallpaper search | |
| `Emojis`, `LatexRenderer`, `Ydotool` (deferred) | Emoji data; LaTeX through MicroTeX; virtual input | |

## Utilities

| Service | Purpose | IPC |
|---|---|---|
| `TimerService` | Countdown, Pomodoro and stopwatch | `timer` |
| `Undo` | The way back for the last removal, offered on a notice | `undo` |
| `Updates` | Package updates: `checkupdates` on Arch, `xbps-install -nu` on Void | |
| `ShellUpdates` | iNiR updates from git: commits behind the remote | `shellUpdate` |
| `Translation` | Strings from the 18 catalogues in `translations/`, plus each installed plugin's own | |
| `DevNavigation` | Development navigation: loads lazy surfaces and Settings pages by name | `dev` |

## Contributor rules

- Add-only changes to public APIs. A rename breaks every consumer.
- New services go in `services/qmldir`, or in `services/deferred/qmldir` if they can wait.
- Eager services run at startup, so keep their timers, polling and file I/O cheap.
