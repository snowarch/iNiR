# Architecture Overview

iNiR is one QML process on [Niri](https://github.com/YaLTeR/niri). This repository is the base: the services, the
config, the kit, the surfaces every look shares, setup and update. Everything you see on top of it (the families,
Designs, themes, widgets, web apps) is a plugin from [inir-hub](https://github.com/snowarch/inir-hub).

```
Your apps
   |
iNiR: the base (services, config, shared surfaces) + the family you picked, from the hub
   |
qs-rs: Quickshell in Rust, with its own Qt (Quickshell when qs-rs can't start)
   |
Niri (windows, rendering, input)
```

## The pieces

Each part is its own repository and reaches your machine prebuilt; nothing compiles on it.

| Piece | Job | Reaches you through |
|---|---|---|
| iNiR (this repo) | The base, in QML, plus setup and update | `git clone` + `./setup install`, then `inir update` |
| [inir-hub](https://github.com/snowarch/inir-hub) | Every plugin: the three families, components, themes, widgets, web apps | [inir.space/hub](https://inir.space/hub); setup and update install the families your config uses |
| [qs-rs](https://github.com/snowarch/qs-rs) | The runtime: Quickshell rewritten in Rust, bundled with its own Qt | A release bundle, pinned by sha256 in `sdata/prebuilt.json` |
| [inir-accel](https://github.com/snowarch/inir-accel) | What the shell runs in the background: colours, thumbnails, sensors, search | A release binary, pinned the same way |
| [inir-cli](https://github.com/snowarch/inir-cli) | The `inir` command: IPC, doctor, update, `inir hub` | A release binary, pinned the same way |
| [inir-site](https://github.com/snowarch/inir-site) | [inir.space](https://inir.space): these docs, the hub catalogue, the release manifest | Built from every repo's `docs/` and the hub's main branch |

## The base and the plugins

- **Material (ii)**: the default. Bar on an edge, sidebars, overview, nine global styles.
- **Waffle**: Windows 11 layouts, with a taskbar at the bottom.
- **iRiS**: one Island that sits on any edge or becomes a full-width bar, plus a Dock.

Only one family runs at a time; Super+Shift+W cycles them. A plugin is a folder with a `plugin.json`, installed to
`~/.local/share/inir/plugins/<id>` and linked at its `provides` path (a family at `modules/<id>`).
`services/Plugins.qml` lists them and hands the base their parts by name; a part a family doesn't declare comes back
empty and the base falls back:

```text
shell.qml             -> Plugins.part(family, "critical")      first frame
shell.qml             -> Plugins.part(family, "panels")        everything else
shell.qml             -> Plugins.part(id, "panel")             a component's panel, worn with the families it lists
settings.qml          -> Plugins.part(family, "settingsApp")   its Settings window (iRiS keeps Settings in the shell)
welcome.qml           -> Plugins.part(family, "welcome")       its own steps in the first-run wizard
shared surfaces       -> Plugins.part(family, "lockSurface")   what a family draws on a shared surface
ShellLayoutController -> Plugins.part(family, "layout")        where its bar, dock and sidebars sit
Config                -> Plugins.part(family, "config")        the schema of its own config section
```

The base never names a family. What it honours for one is declared in that family's `plugin.json` or answered by the
family's verbs (`GlobalStates.familyVerb`). A family may use `modules/shared`, `modules/common` and `services`;
nothing uses a family. Each family's config subtree (`material.*`, `waffles.*`, `iris.*`) ships with it and stays
untouched while it is not installed; the shell's own sections hold what every family shares. See
[Panel Families](PANEL_FAMILIES.md) and [Hub](HUB.md).

## How a start goes

1. `shell.qml` forces the startup-critical singletons and IPC routers and waits for `Config.ready`.
2. It applies the theme and loads the family's `critical` part: the surfaces of the first frame.
3. After that frame (`GlobalStates.deferredPanelsReady`) it loads the family's `panels` part. Each panel exists only
   while it is enabled (`enabledPanels`) and its conditions hold.
4. Background services start staggered after the first paint; scripts and inir-accel do the work that should not live
   in QML.

The full timeline is in [Runtime and Boot](RUNTIME.md).

## Where code goes

| Path | What |
|---|---|
| `shell.qml`, `settings.qml`, `welcome.qml`, `killDialog.qml` | Entries: the shell, the Settings window, the first-run wizard, the close dialog |
| `GlobalStates.qml`, `qmldir` | Transient state (what is open, the lock, the family transition), never saved |
| `services/` | UI-less state: audio, network, Niri, media, notifications, wallpapers, theme; `deferred/` after the first frame |
| `modules/common/` | The kit: `Config`, `Appearance`, widgets, functions, the wizard's pages |
| `modules/shared/` | Surfaces more than one family loads: background and desktop widgets, lock, overview, clipboard, region selector, session screen, overlay, OSK |
| `modules/<family>/` | The installed families, linked in from the hub (not in this repository) |
| `scripts/` | What runs on your machine: the `inir` launcher, colour generation and app theming, media and capture helpers |
| `setup`, `sdata/` | Install, update, uninstall, doctor, distro data, the pinned binaries (`prebuilt.json`) |
| `defaults/` | The fresh-install profile: `config.json`, the Niri config, colour templates |
| `dots/` | The app configs setup offers (terminals, fish, Kvantum, the SDDM theme) |
| `assets/` | Fonts the base draws with, icons, the factory wallpaper, Kira's poses |
| `translations/` | The strings the base shows, 18 languages; a family keeps its own |
| `nix/`, `flake.nix`, `Makefile` | Nix and packaged installs |
| `docs/` | These pages, published at [inir.space/docs](https://inir.space/docs) |

A new look, Design, theme or widget is a plugin in inir-hub, never a folder here.

## Config

- Schema: `modules/common/ConfigOptions.qml` (a `JsonAdapter` that `Config.qml` fills from your file), plus each
  family's subtree from its `plugin.json`. `defaults/config.json` is the fresh-install profile.
- Your file: `~/.config/inir/config.json`, only the keys you changed. A key that moves reaches your file at load
  (`ConfigMigrations.js`); setup never overwrites it.
- Read `Config.options.path.to.key`; write only with `Config.setNestedValue("path.to.key", value)`.

See [Config System](CONFIG_SYSTEM.md).

## IPC

`IpcHandler { target: "name" }` in QML, called as `inir <target> <function> [args]`. Every function declares its
return type. A `///` comment above the handler and above each function says what it does; the [IPC page](IPC.md),
`inir help` and tab completion are built from those comments.

## Colours

```
Wallpaper
  -> switchwall.sh -> inir-accel material-colors
  -> colors.json
  -> MaterialThemeLoader
  -> each family's tokens (Appearance, Looks, IrisStyle)
  -> every surface, then external apps (scripts/colors/applycolor.sh)
```

Built-in presets skip the wallpaper step and set colours directly. Apps are themed from `scripts/colors/targets/` and
each installed plugin's `colors/targets/`. See [Theming Architecture](THEMING_ARCHITECTURE.md).

## Install and update

```bash
git clone https://github.com/snowarch/inir.git && cd inir
./setup install          # interactive; -y for no questions
inir update              # snapshot, pull, plugins and binaries, sync, restart
./setup rollback         # back to a snapshot
```

- **repo-copy**: the normal install. The checkout is the update source; the runtime is synced to
  `~/.config/quickshell/inir/`.
- **repo-link**: the runtime points at the checkout itself.
- **package-managed**: `make install`, a distro package or Nix owns the runtime and its updates.

An update fetches the plugins and binaries you need before touching anything, so a missing one stops it with the old
shell intact; a shell that won't start after it rolls back to the snapshot. The systemd unit is wired through a wants
link on `niri.service`, not `graphical-session.target`, so it never starts under another desktop. See
[Install](INSTALL.md) and [Setup and Update](SETUP.md).

## Running it

```bash
inir restart             # the shell runs as inir.service; never a bare `qs`
inir logs | tail -50
inir doctor
```

## What a change reaches

The shared contracts reach everyone: the config schema and defaults, the tokens, the startup order (`shell.qml`),
`GlobalStates.qml`, and any service many surfaces use. A change to one panel or one settings page stays local. If it
changes what people see, these docs change with it.
