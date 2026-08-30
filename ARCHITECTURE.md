# iNiR Architecture

> A complete desktop shell built on [Quickshell](https://quickshell.org/) for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

**Version**: 2.29.3 · **Stack**: QML (Quickshell), Bash, Python, Go

Originally forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse). Secondary Hyprland support is maintained.

---

## Entry Point

`shell.qml` → `ShellRoot` (Quickshell-specific root, not Item/Window).

Startup flow:
1. Environment pragmas configure Qt scale, WebEngine, etc.
2. Singleton services force-instantiated via dummy property bindings
3. `Config.ready` triggers panel loading
4. Theme and icon services applied via `Qt.callLater`
5. Hyprsunset, first-run wizard, and conflict killer loaded

## Panel Families

Two mutually exclusive UI families, switchable at runtime (`Super+Shift+W`):

| | **Material ii** | **Waffle** |
|---|---|---|
| Active when | `panelFamily !== "waffle"` | `panelFamily === "waffle"` |
| Visual tokens | `Appearance.*` | `Looks.*` |
| Styles | material, cards, aurora, inir, angel, zzz, cookie | Single fluent style |
| Bar | Top (or vertical; bar.appearanceStyle selects classic/islands/scenic/frame, pill, or m3) | Bottom (Win11 taskbar) |
| App launcher | Overview | StartMenu with search |
| Right panel | SidebarRight | ActionCenter + NotificationCenter |
| Panels | ii (iiBar, iiDock, iiSidebarLeft, ...) | w (wBar, wStartMenu, wActionCenter, ... + shared ii panels) |

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```
Loads when ALL conditions are true: `Config.ready` + identifier in `enabledPanels` array + `extraCondition`.

Style dispatch priority: **cookie > zzz > angel > inir > aurora > material** (`Appearance.qml`: `cookieEverywhere`/`zzzEverywhere`/`angelEverywhere`/`inirEverywhere`/`auroraEverywhere` are `globalStyle` checks; `auroraEverywhere` is also true when `globalStyle === "angel"`, so angel must be checked before aurora wherever both matter). Cards is a material variant (no separate dispatch).

## Directory Structure

```
shell.qml                     # Root entry — loads services, selects panel family
ShellIiPanels.qml             # Material Design family
ShellWafflePanels.qml         # Windows 11 family
GlobalStates.qml              # Runtime UI state (panel open/closed booleans)
FamilyTransitionOverlay.qml   # Animated family switch
settings.qml                  # Settings GUI (separate Quickshell config)
waffleSettings.qml            # Waffle-specific settings GUI
welcome.qml                   # First-run wizard
killDialog.qml                # Process kill confirmation

modules/                      # UI module directories
├── common/                   # Shared infrastructure
│   ├── Appearance.qml        # ii visual tokens
│   ├── Config.qml            # Central config (JsonAdapter)
│   └── widgets/              # Reusable widgets + qmldir
├── bar/                      # Top bar (ii family)
├── barM3/                    # Material 3 bar — independent layout model, bar.appearanceStyle "m3"
├── background/               # Wallpaper backdrop + desktop widgets + desktop items
├── sidebarLeft/              # AI chat, YT Music, widgets
├── sidebarRight/             # Toggles, calendar, tools
├── settings/                 # All config UI pages
├── dock/                     # App dock (all 4 positions)
├── overview/                 # Workspace overview + app search
├── wallpaperLauncher/        # Shared compact wallpaper carousel
├── waffle/                   # Windows 11 family
│   ├── bar/                  # Bottom taskbar
│   ├── startMenu/            # Start menu with search
│   ├── actionCenter/         # Quick settings
│   ├── notificationCenter/   # Notification list + calendar
│   ├── looks/Looks.qml       # Waffle visual tokens
│   └── [13 more subdirs]
└── [more modules]

services/                     # Runtime singletons (+ services/deferred/)
├── qmldir                    # Service module registration
├── Audio.qml                 # PipeWire volume, mute, per-app mixer
├── NiriService.qml           # Niri compositor IPC
├── CompositorService.qml     # Compositor detection (Niri vs Hyprland)
├── Network.qml               # NetworkManager integration
├── Weather.qml               # Weather polling + privacy-aware location
├── BluetoothStatus.qml       # BlueZ device management
├── Translation.qml           # i18n string lookup
├── DevNavigation.qml         # Session-only semantic UI navigation + dev IPC
└── [more services]

scripts/                      # Shell/fish/python helpers
├── inir                      # CLI launcher (bash, IPC + lifecycle commands)
├── colors/                   # Color generation pipeline
│   ├── applycolor.sh         # Orchestrator
│   ├── generate_colors_material.py  # Material You color generation + template rendering
│   ├── modules/              # Per-app theming (terminals, GTK, etc.)
│   └── lib/                  # Shared infrastructure
└── [more scripts]

sdata/                        # Install/update lifecycle
├── lib/                      # Shared bash libraries
├── migrations/               # Numbered scripts
├── subcmd-install/           # Install phases
└── subcmd-uninstall/         # Uninstall phases

defaults/                     # Shipped defaults
├── config.json               # Default config
├── niri/                     # Niri config templates
└── [GTK, KDE, fuzzel, etc.]

translations/                 # i18n strings (15 languages)
distro/arch/                  # Arch PKGBUILDs (dependency manifests)
assets/                       # Icons, wallpapers, systemd unit, desktop entry
docs/                         # User documentation
```

## Config System

| Aspect | Details |
|--------|---------|
| Schema | `modules/common/Config.qml` — JsonAdapter |
| Defaults | `defaults/config.json` |
| User file | `~/.config/illogical-impulse/config.json` (legacy namespace from fork origin) |
| Read | `Config.options.path.to.key` — schema-declared properties are typed QML properties with defaults |
| Write | `Config.setNestedValue("path.to.key", value)` — writes + fires `configChanged()` signal |
| Ready gate | `Config.ready` — true after JSON loaded (or created if missing) |
| Hot-reload | `watchChanges: true` — external edits auto-apply |
| Debounce | 50ms for both reads and writes |

**Sync rule**: when adding a new config key, update together:
1. `modules/common/Config.qml` — schema definition and shell default
2. Consumer(s) — read/write the key
3. Settings UI in every family that owns the behavior
4. `defaults/config.json` only when the curated fresh-install preference differs

## Key Singletons

| Singleton | Dependents | Domain |
|-----------|-----------|--------|
| `Config` | shell-wide | All config read/write |
| `Appearance` | ii/shared UI | All ii module visuals |
| `Translation` | shell-wide | All i18n strings |
| `GlobalStates` | panel loaders | Panel visibility state |
| `DevNavigation` | shell + navigable surfaces | Development-only semantic UI traversal |
| `Looks` | waffle modules | Waffle visual tokens |
| `NiriService` | compositor modules | Niri IPC, workspaces, windows |
| `Audio` | medium | PipeWire volume, mute, per-app mixer |
| `CompositorService` | medium | Compositor detection (Niri/Hyprland) |
| `Weather` | medium | Weather polling + privacy-aware location |
| `Network` | medium | NetworkManager integration |
| `Wallpapers` | medium | Wallpaper management + theming pipeline |
| `DesktopItems` | background | Desktop item persistence + undo (desktop-items.json) |
| `DesktopWidgetLayout` | background | Per-output widget layout (`background.widgets.outputOverrides`) |
| `LyricsService` | media | Synchronized lyrics for media controls |

All three wallpaper pickers (grid, coverflow, launcher) apply through
`Wallpapers.applySelectionTarget()`, so the owning wallpaper engine and theming
pipeline behave identically for each. The launcher's live preview goes through
`Wallpapers.previewWallpaper()`: static images are offered to `AwwwBackend`,
while the same transient path is exposed to the internal background renderer
for videos, GIFs, parallax, or systems without awww. Neither path writes config
or regenerates colours, and cancelling resynchronizes the configured wallpaper.
No picker draws the desktop wallpaper directly.

`modules/background/Background.qml` is the per-output desktop surface: it renders
the wallpaper and hosts the desktop widgets and desktop items. `DesktopWidgetLayout`
maps each widget instance to its output through `Config.options.background.widgets.outputOverrides`
plus `screenList`/`layerOrder`; `DesktopItems` persists icons to
`Directories.stateUserPath/desktop-items.json` (schema v1) with an undo tombstone,
and `modules/background/desktopItems/` provides the icon delegate, drop coordinator
and image-choice surfaces. Layout editing runs through the shell-wide
`ShellEditSession` service and `modules/common/widgets/ShellLayoutEditorWindow.qml`.

These are **stability boundaries** — prefer add-only changes, verify all dependents before reshaping.

## IPC System

Handlers registered via `IpcHandler { target: "name" }` in QML.

Called externally: `inir <target> <function> [args]`

The always-instantiated `dev` target provides session-only semantic navigation
for lazy UI. Its functions are:
- `list()` — returns all registered destinations as JSON
- `open(destination)` — navigates to a named surface/view
- `close()` — closes all navigable surfaces
- `current()` — returns the current destination or `"closed"`

All functions must declare return types (`string`, `int`, `bool`, `real`, `color`, `void`).

Full reference: [docs/IPC.md](docs/IPC.md).

## Theming Pipeline

Colors flow: wallpaper image → `generate_colors_material.py` (materialyoucolor) → `colors.json` → `MaterialThemeLoader` → `Appearance` tokens → UI.

Theme generation orchestrated by `scripts/colors/applycolor.sh`, which runs per-app modules in parallel:
- Terminals (foot, kitty, alacritty)
- Starship prompt
- Fuzzel launcher
- GTK3/4
- Firefox (pywalfox)
- VS Code, Zed, OpenCode (Go generators)
- SDDM login theme
- btop, lazygit, yazi

## Distribution

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup                  # Interactive TUI installer
./setup install -y       # Fully automated
./setup update           # Pull + sync + migrate + restart
./setup doctor           # Diagnose + auto-fix
./setup rollback         # Restore previous snapshot
```

Two install modes tracked in `version.json`:
- **Repo-sync**: `./setup install` → syncs to `~/.config/quickshell/inir/`
- **Package-managed**: `make install` → copies to `/usr/share/quickshell/inir/`

User config for the running QML shell lives at `~/.config/illogical-impulse/config.json` (legacy namespace, persistent across updates). NOTE: the shell scripts/CLI default to `~/.config/inir/` with a legacy fallback — the two sides are not yet unified.

### Multi-Distro Support

| Distro | Strategy |
|--------|----------|
| **Arch** | pacman + AUR helper for fonts |
| **Fedora** | dnf + COPR repos (quickshell, niri) |
| **Debian/Ubuntu** | apt + compile from source (niri, quickshell) |
| **Generic** | Guidance-only dependency checking |

### Migrations

Location: `sdata/migrations/` — numbered scripts (check `ls sdata/migrations/`
for the current maximum).
- Append-only — never rename, reorder, or delete existing migrations
- Idempotent — may run again if state is lost
- Next number: check `ls sdata/migrations/` and use highest + 1

## Daily Development

```bash
inir run                    # Launch the shell
inir restart                # Graceful restart
inir logs | tail -50        # Check for errors
inir status                 # Installation/repository diagnostic summary
inir doctor                 # Auto-diagnose + fix
inir settings               # Open settings GUI

# IPC calls
inir <target> <function> [args...]
inir overview toggle
inir audio volumeUp
```

Never run raw `qs kill -c inir` / `qs -c inir` by hand — iNiR runs under
`inir.service` (systemd --user); a bare `qs` invocation kills or duplicates
the live session outside systemd's supervision. `inir restart` is the only
correct way to force a restart.

## Known Harmless Warnings

These log messages are safe to ignore:
- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth adapter
- `failed to register listener: ...PolicyKit1...` — another polkit agent running
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic
- `Cannot open: file:///...coverart/...` — missing album art cache
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — expected when running on Niri
