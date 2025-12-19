# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## What this repo is
A **Quickshell** configuration (“ii on Niri”) that runs as a desktop shell on the **Niri** compositor.

Key entrypoints:
- `shell.qml`: main `ShellRoot` entry.
- `settings.qml` / `waffleSettings.qml`: settings UI (spawned as a separate `qs -n -p ...` process).
- `setup`: installer/updater that syncs this repo into `~/.config/quickshell/ii/`.

## Common commands

### Install / update / rollback
The repo’s `./setup` script is the main workflow for install and updates:

```bash
./setup                 # interactive menu
./setup install          # install deps + system setup + config files
./setup update           # pull + sync QML/scripts/assets into ~/.config/quickshell/ii + restart shell
./setup doctor           # diagnose and auto-fix common issues
./setup rollback         # restore from snapshots created by updates

# also supported (see ./setup -h)
./setup migrate
./setup status
```

Options: `-y/--yes` (skip prompts), `-q/--quiet`, `-h/--help`.

After installing/updating Niri config, reload Niri’s config:

```bash
niri msg action load-config-file
```

IMPORTANT WORKFLOW NOTE: If you edit this repo directly (instead of editing `~/.config/quickshell/ii/`), run `./setup update` to sync your changes into the live Quickshell config directory.

### Run / restart the shell
Run (expects the config to be installed at `~/.config/quickshell/ii/`):

```bash
qs -c ii
```

Restart without restarting Niri:

```bash
qs kill -c ii && qs -c ii
```

View logs:

```bash
qs log -c ii
```

### IPC (for quick manual testing)
From terminal:

```bash
qs -c ii ipc call <target> <function>
```

Docs:
- IPC targets/functions: `docs/IPC.md`
- Default keybinds: `docs/KEYBINDS.md`

Quick IPC target index (grep implementation via `rg -n 'target: "<name>"'`):
- Core: `overview`, `overlay`, `clipboard`, `altSwitcher`, `region`, `session`, `lock`, `settings`, `cheatsheet`, `closeConfirm`
- System: `audio`, `brightness`, `mpris`, `gamemode`, `notifications`, `minimize`, `bar`, `wallpaperSelector`, `mediaControls`, `osk`, `osd`, `osdVolume`, `zoom`
- Waffle-only: `search`, `wactionCenter`, `wnotificationCenter`, `wwidgets`, `wbar`, `taskview`

### QML formatting / linting
There’s a `.qmlformat.ini` in the repo; you can try Qt’s tools if they’re available:

```bash
qmllint shell.qml
qmlformat --inplace shell.qml
```

In practice, runtime smoke-testing is the most reliable check:

```bash
qs kill -c ii && qs -c ii
qs log -c ii
```

### Python deps (region tools, image ops, etc.)
Python deps are listed in `requirements.txt`:

```bash
uv pip install -r requirements.txt
```

One-off helper (used to parse Niri keybinds into JSON for the cheatsheet):

```bash
./scripts/parse_niri_keybinds.py                # reads ~/.config/niri/config.kdl
./scripts/parse_niri_keybinds.py /path/to/config.kdl
```

### Translation tooling
Translation files live under `translations/` and are managed by `translations/tools/manage-translations.sh`:

```bash
translations/tools/manage-translations.sh --help
translations/tools/manage-translations.sh status
translations/tools/manage-translations.sh update
translations/tools/manage-translations.sh update -l zh_CN
translations/tools/manage-translations.sh clean
translations/tools/manage-translations.sh sync
```

## Big-picture architecture

### Startup flow (shell entry)
`shell.qml` is the runtime root:
- Forces instantiation of a few service singletons.
- Waits for `Config.ready` (see `modules/common/Config.qml`).
- Applies theme on config ready via `ThemeService.applyCurrentTheme()`.
- Loads exactly one “panel family” via `LazyLoader`:
  - `ShellIiPanels.qml` when `Config.options.panelFamily !== "waffle"`
  - `ShellWafflePanels.qml` when `Config.options.panelFamily === "waffle"`
- Exposes IPC:
  - `target: "settings"` opens `settings.qml` or `waffleSettings.qml` in a standalone `qs -n -p ...` process.
  - `target: "panelFamily"` cycles/sets the active family.
- Manages animated family switching via `FamilyTransitionOverlay.qml` + `GlobalStates.qml`.

### Panel system: families + enabled panel IDs
Panels are loaded dynamically from two config values:
- `Config.options.panelFamily`: active “style family” (`"ii"` or `"waffle"`).
- `Config.options.enabledPanels`: list of string identifiers.

`ShellIiPanels.qml` and `ShellWafflePanels.qml` are the central mapping layer from identifier → component.

This pattern is intentional:
- Most UI work lives in `modules/`.
- Most backend state/IO lives in `services/` singletons.

### Module architecture (how most panels are built)
Most panel modules follow a common shape:
- A top-level `Scope {}` (Quickshell) that owns state and IPC.
- One or more `PanelWindow {}` instances created either:
  - per-monitor via `Variants { model: Quickshell.screens ... }` (e.g. bars and overview), or
  - as a single overlay window toggled by a `Loader`/`LazyLoader`.
- Visibility is usually driven by a `GlobalStates.*Open` boolean (instead of creating/destroying windows directly).
- “Click outside to close” behavior is handled by:
  - `CompositorFocusGrab` (Hyprland-only), plus
  - a fallback full-screen `MouseArea` hit-test on Niri.

Concrete examples:
- Bar (Material ii): `modules/bar/Bar.qml` creates a per-screen `PanelWindow` under `WlrLayershell.namespace: "quickshell:bar"` and supports auto-hide behavior.
- Overview: `modules/overview/Overview.qml` is a full-screen overlay per screen and integrates with compositor state (`CompositorService` + `NiriService`).
- Overlay: `modules/ii/overlay/Overlay.qml` keeps the window loaded for instant open and uses a `mask` region based on `OverlayContext.clickableWidgets`.
- Sidebars: `modules/sidebarLeft/SidebarLeft.qml` and `modules/sidebarRight/SidebarRight.qml` are panel windows that toggle via IPC and close-on-backdrop-click.
- Region tools: `modules/regionSelector/RegionSelector.qml` is per-screen, driven by `GlobalStates.regionSelectorOpen` and exposes IPC functions (`region.screenshot/search/ocr/record/...`).

### Waffle family modules (Windows 11-style)
The waffle family is still the same shell process, but uses its own panel windows and state flags. Most waffle panels follow:
- A full-screen click-outside overlay window + the actual panel window.
- `GlobalStates.<wafflePanel>Open` booleans for visibility.

Examples:
- Start menu: `modules/waffle/startMenu/WaffleStartMenu.qml` (IPC target: `search`).
- Action center: `modules/waffle/actionCenter/WaffleActionCenter.qml` (IPC target: `wactionCenter`).
- Taskbar: `modules/waffle/bar/WaffleBar.qml` (IPC target: `wbar`).

The core “look & feel” building blocks for waffle live under `modules/waffle/looks/` (acrylic rectangles, Fluent icons, W* widgets), and are widely reused by waffle submodules.

### Config system (JSON-backed singleton)
`modules/common/Config.qml` is a `pragma Singleton` that:
- Persists JSON via `Quickshell.Io.FileView` + a large `JsonAdapter` schema.
- Exposes the live config object as `Config.options`.

The setup docs describe on-disk destinations:
- QML code: `~/.config/quickshell/ii/`
- User config JSON: `~/.config/illogical-impulse/config.json` (see `docs/SETUP.md`)

### Compositor integration (Niri + remnants of Hyprland support)
Compositor detection/switching is centralized in `services/CompositorService.qml`.

Niri integration is primarily in `services/NiriService.qml`:
- Reads `NIRI_SOCKET` and uses `DankSocket` to subscribe to Niri’s event stream.
- Calls `niri msg -j outputs` for output metadata.

If you’re touching anything workspace/window-related (overview, task switchers, workspace indicators), start with:
- `services/NiriService.qml`
- `services/CompositorService.qml` (sorting and compositor abstraction)

### Theme / Material You pipeline
Theme selection is orchestrated by `services/ThemeService.qml`:
- Reads `Config.options.appearance.theme`.
- `"auto"` delegates to `services/MaterialThemeLoader.qml`.
- Non-auto themes apply via `ThemePresets.applyPreset(...)`.

`services/MaterialThemeLoader.qml` watches the generated material theme JSON and writes colors into the `Appearance` singleton.

### Setup/update mechanics (how changes reach a running system)
`./setup update`:
- Optionally pulls remote changes.
- Syncs `*.qml` + `modules/`, `services/`, `scripts/`, `assets/`, `translations/` into `~/.config/quickshell/ii/`.
- Restarts the shell when it’s running in a graphical session.
- Creates snapshots so `./setup rollback` can restore a previous working state.

If you change code and don’t see it reflected at runtime:
- Ensure you’re editing the files actually being loaded (either develop directly in `~/.config/quickshell/ii/`, or run `./setup update` to sync).
- Restart the shell: `qs kill -c ii && qs -c ii`.

### Autostart (user systemd units)
The autostart system is implemented in `services/Autostart.qml` and can:
- Launch `.desktop` entries via `gtk-launch`.
- Launch shell commands (`bash -lc ...`).
- Manage per-user systemd units under `~/.config/systemd/user/`.

Important implementation notes for contributors:
- Unit creation is serialized to avoid races between directory creation, file writes, and `systemctl --user daemon-reload` / `enable --now`.
- Unit deletion avoids shell interpolation and only deletes units that contain the `# ii-autostart` marker header.
- Deletion operations are also serialized to avoid overlapping `systemctl` operations.

## Repo layout (high level)
- `modules/`: UI modules (Material ii + Waffle family modules live under separate namespaces).
- `services/`: singleton backends (compositor state, theming, notifications, clipboard integration, etc.).
- `scripts/`: helper scripts invoked by modules/services.
- `sdata/`: setup implementation (shared libs in `sdata/lib/`, migrations in `sdata/migrations/`, Arch package lists in `sdata/dist-arch/`).
- `defaults/`: default/preset resources (e.g. AI prompt presets in `defaults/ai/`).
- `translations/`: translation JSON + tooling.
- `dots/`: config files that `./setup install` can copy into `~/.config/` (Niri config, matugen templates, etc.).

## Other docs worth knowing exist
- `docs/LIMITATIONS.md`: compositor/feature caveats (Niri vs inherited Hyprland behaviors).
- `docs/OPTIMIZATION.md`: repo-specific QML/Quickshell performance notes (typed props, qualified lookups, LazyLoader semantics).
- `docs/VESKTOP.md`: how Vesktop/Discord theming regen works + manual regen commands.

## Project-specific preferences
- Prefer that **Waybar does not autostart** when KDE starts (avoid adding Waybar autostart changes under `dots/` unless explicitly requested).
