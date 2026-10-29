# Architecture Overview

iNiR is one Quickshell (QML) process. Bars, panels, config and most service state live in it. Work that does not
belong in QML goes to D-Bus, the compositor socket, or helper scripts.

```
Your apps
   |
iNiR: the base (services, config, shared surfaces) + one family from the Hub
   |
Quickshell
   |
Niri (windows, rendering, input)
```

## The base and the plugins

This repo is the base. The looks are plugins from [inir-hub](https://github.com/snowarch/inir-hub): the three
families, iRiS Designs, themes, widgets and web apps. A fresh install brings the three families, `inir update` keeps
the plugins you have current, and each one is linked into the shell at its path (a family at `modules/<id>`).

- **Material (ii)**: the default. Bar on an edge, sidebars, overview, nine global styles.
- **Waffle**: Windows 11 layouts, with a taskbar at the bottom.
- **iRiS**: one Island that sits on any edge or becomes a full-width bar, plus a Dock.

Only one family runs at a time; Super+Shift+W cycles them. All three read the same `Config` and services, and each
keeps its own tokens: `Appearance.*` for Material and shared code, `Looks.*` for Waffle, `IrisStyle.*` for iRiS. See
[Panel Families](PANEL_FAMILIES.md).

## How a start goes

1. `shell.qml` forces the startup-critical singletons and waits for `Config.ready`.
2. It applies the theme and loads the family's `critical` part: the surfaces of the first frame.
3. After that frame it loads the family's `panels` part. Each panel exists only while it is enabled
   (`enabledPanels`) and its conditions hold.
4. Panels read shared state from services; scripts do the work that should not live in QML.

The full timeline is in [Runtime and Boot](RUNTIME.md).

## Services and config

About 100 singletons in `services/` own compositor IPC, audio, network, notifications, theming and content. See
[Services Catalogue](SERVICES.md).

- Schema: `modules/common/ConfigOptions.qml` (`Config.qml` reads and writes it), plus each family's part. Defaults: `defaults/config.json`.
- Your file: `~/.config/inir/config.json`.
- Write with `Config.setNestedValue("section.key", value)`. Read with `Config.options?.section?.key ?? fallback`.
- Transient state (what is open, the lock, the family transition) lives in `GlobalStates.qml` and is never saved.

See [Config System](CONFIG_SYSTEM.md).

## Theming pipeline

```
Wallpaper
  -> switchwall.sh -> inir-accel material-colors
  -> colors.json
  -> MaterialThemeLoader
  -> each family's tokens
  -> every surface, then external apps
```

Built-in presets skip the wallpaper step and set colours directly. See [Theming Architecture](THEMING_ARCHITECTURE.md).

## Directory map

| Path | Contents | Risk |
|---|---|---|
| `shell.qml`, `settings.qml`, `welcome.qml` | Startup and family loading, the Settings window, the first-run wizard | High |
| `services/Plugins.qml` | Which plugins are installed and the parts each hands the base | High |
| `modules/common/` | Config, Appearance, Directories, shared widgets | High |
| `services/` | System integration singletons | High |
| `scripts/inir` | The launcher; it hands commands to the `inir` binary when one is installed | High |
| `setup`, `sdata/` | Install, update, distro data | High |
| `modules/shared/` | Surfaces that two or more families load | Normal |
| `modules/<family>/` | The installed families, linked in from the Hub | Normal |
| `defaults/`, `dots/` | Shipped config, Niri config, app configs | Medium |
| `translations/` | 18 locales | Low |
| `docs/` | These pages | Low |

## What a change reaches

The shared contracts reach everyone: the config schema and defaults (`Config.qml`, `defaults/config.json`), the
tokens (`Appearance.qml`, `Looks`, `IrisStyle`), the startup order (`shell.qml`), `GlobalStates.qml`, and any service
many surfaces use. A change to one panel or one settings page stays local. If it changes what people see, update
these docs.

## Install and update

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

- **repo-copy**: the normal install. The checkout is the update source, and a synced runtime lives in
  `~/.config/quickshell/inir/`.
- **repo-link**: the runtime points at the checkout itself.
- **package-managed**: `make install`, a distro package or Nix owns the runtime and its updates.

Update with `./setup update` or `inir update`. The systemd unit is wired through a wants link on `niri.service`, not
`graphical-session.target`, so it never starts under another desktop. See [Install](INSTALL.md) and
[Setup and Update](SETUP.md).
