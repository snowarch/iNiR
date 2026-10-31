# iNiR Architecture

A desktop shell for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor, written in QML. This repo is the
base: the services, the kit, the surfaces every look shares, setup and update. The looks themselves (Material,
Waffle, iRiS), their Designs, themes and widgets are plugins from [inir-hub](https://github.com/snowarch/inir-hub).

## The pieces

| Piece | Job |
|---|---|
| iNiR (this repo) | The base, in QML, plus setup and update |
| [inir-hub](https://github.com/snowarch/inir-hub) | Every plugin: the three families, Designs, themes, widgets, web apps ([inir.space/hub](https://inir.space/hub)) |
| [qs-rs](https://github.com/snowarch/qs-rs) | Quickshell rewritten in Rust; iNiR runs on stock Quickshell today |
| [inir-accel](https://github.com/snowarch/inir-accel) | The native helpers the shell spawns: the palette solver, the editor theme generators, faster stand-ins for Python ones |
| [inir-cli](https://github.com/snowarch/inir-cli) | The `inir` command, `inir hub` included |

## How a start goes

1. `shell.qml` (a `ShellRoot`) sets the Qt policy and starts the startup-critical singletons and IPC routers.
2. `Config.ready` applies the theme and picks the family (`panelFamily`).
3. That family's `critical` part draws the first frame (bar, background, dock).
4. After that frame, `GlobalStates.deferredPanelsReady` loads its `panels` part; heavy surfaces load on demand
   (`PanelLoader`, `DeferredPanelLoader`, `OnDemandPanelLoader`, gated by `enabledPanels`).
5. Background services start staggered after the first paint.

## Plugins

A plugin is a folder with a `plugin.json`. A fresh install brings the three families from the hub, an update the
plugins you already have; each goes into `~/.local/share/inir/plugins/<id>` and link each at its `provides` path (a family at `modules/<id>`);
`services/Plugins.qml` lists them and hands out their files by name (a part the family doesn't declare comes
back empty, and the base falls back):

```text
shell.qml        -> Plugins.part(family, "critical")      first frame
shell.qml        -> Plugins.part(family, "panels")        everything else
settings.qml     -> Plugins.part(family, "settingsApp")   its Settings window (iRiS keeps Settings in the shell)
welcome.qml      -> Plugins.part(family, "welcome")       its own steps in the first-run wizard
shared surfaces  -> Plugins.part(family, "lockSurface")   what a family draws on a shared surface
ShellLayoutController -> Plugins.part(family, "layout")  where its bar, dock and sidebars sit, the room they take
Config           -> Plugins.part(family, "config")        the schema of its own config section
```

The base never names a family. What it honours for one is declared in that family's `plugin.json` (panels, settings
slots, each one a config key the base reads through `Plugins.setting`, optionally held by a `when` key of the family's
own; flags, its config subtree) or answered by the family's verbs (`GlobalStates.familyVerb`). A family may use
`modules/shared`, `modules/common` and `services`; nothing uses a family. Each family's config subtree (`material.*`,
`waffles.*`, `iris.*`) ships with it and is kept untouched while it is not installed; the shell's own sections hold
what every family shares. A shared surface that needs the active family's version of a setting reads
`Config.family` (that family's subtree), never another family's keys.

## Where code goes

| Folder | What |
|---|---|
| `shell.qml`, `settings.qml`, `welcome.qml` | Entries: compose the shell, the Settings window, the first-run wizard |
| `services/` | UI-less state (audio, network, Niri, media, notifications, wallpapers, theme); `deferred/` after the first frame |
| `modules/common/` | The kit: `Config`, `Appearance`, widgets, functions, the wizard's pages |
| `modules/shared/` | Surfaces more than one family loads: background and desktop widgets, lock, overview, clipboard, region selector, session screen, overlay, OSK |
| `scripts/` | What runs on your machine: the `inir` launcher, colour generation and app theming, media and capture helpers |
| `sdata/`, `setup` | Install, update, uninstall, doctor |
| `defaults/`, `dots/` | The fresh-install config and the app configs setup offers |
| `translations/` | Every visible string, one catalogue per language |
| `docs/` | User docs, published at [inir.space/docs](https://inir.space/docs) |

A new look, Design, theme or widget is a plugin in inir-hub, never a folder here.

## Config

- Schema: `modules/common/ConfigOptions.qml` (a `JsonAdapter` that `Config.qml` fills from your file), plus each family's own subtree from its `plugin.json`.
- Your file: `~/.config/inir/config.json`, only the keys you changed. `defaults/config.json` is the fresh-install profile.
- Read `Config.options.path.to.key`; write only with `Config.setNestedValue("path.to.key", value)`.
- A new key: schema, its readers, its Settings row in each family that shows it, and `defaults/config.json` when a
  fresh install needs a value. Setup never overwrites your config.

## IPC

`IpcHandler { target: "name" }` in QML, called as `inir <target> <function> [args]`. Every function declares its
return type. A `///` comment above the handler and above each function says what it does; the IPC page on
inir.space, `inir help` and tab completion are built from those comments.

## Colours

Wallpaper -> `switchwall.sh` -> `inir-accel material-colors` -> `colors.json` -> `MaterialThemeLoader` -> each family's
tokens (`Appearance`, `Looks`, `IrisStyle`). `scripts/colors/applycolor.sh` themes the apps listed in
`scripts/colors/targets/`.

## Install and update

```bash
git clone https://github.com/snowarch/inir.git && cd inir
./setup install          # interactive; -y for no questions
./setup update           # snapshot, pull, plugins, sync, restart
./setup rollback         # back to a snapshot
```

The checkout is the update source; the runtime is synced to `~/.config/quickshell/inir/`. Update fetches the
plugins you have before touching anything, so a missing one stops it with the old shell intact. There are no
migrations: what an older version left in a config, the update sets right in place.

## Running it

```bash
inir restart             # the shell runs as inir.service; never a bare `qs`
inir logs | tail -50
inir doctor
```

Harmless warnings: `DBusObjectManagerInterface for "org.bluez"` (no Bluetooth adapter), `failed to register
listener ... PolicyKit1` (another polkit agent), `QSGPlainTexture: Mipmap settings changed`, a missing cover-art
cache file, `$HYPRLAND_INSTANCE_SIGNATURE is unset` on Niri.
