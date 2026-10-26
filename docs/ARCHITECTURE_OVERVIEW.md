# Architecture Overview

iNiR is one Quickshell (QML) process. Bars, panels, config and most service state live in it. Work that does not belong in QML goes to D-Bus, the compositor socket, or helper scripts and daemons.

```
Your apps
   |
iNiR shell (QML, one panel family at a time)
   |
Quickshell
   |
Niri (windows, rendering, input)
```

## Entry point

`shell.qml` is the root `ShellRoot`. It forces the startup-critical singletons, waits for `Config.ready`, applies the theme and loads the selected family's critical host. After the first frame it loads that family's deferred panels. Boot timings are written to `~/.cache/inir/last-boot.json`, and `inir status` reports them. The full sequence is in [Runtime and Boot](RUNTIME.md).

## Three families

- **Material (ii)**: the default. Bar on an edge, sidebars, overview. Nine global styles: material, cards, aurora, inir, angel, regalia, zzz, cookie and editorial.
- **Waffle**: Windows 11 layouts, with a taskbar at the bottom. Its `Looks` palette follows the active global style.
- **iRiS**: one Island that sits on any edge or becomes a full-width bar, plus a Dock. Studio and Themes edit iRiS only.

Only one family runs at a time. Super+Shift+W cycles them. All three read the same `Config` and services, and each keeps its own presentation: `Appearance.*` for ii and shared code, `Looks.*` for Waffle, `IrisStyle.*` for iRiS. See [Panel Families](PANEL_FAMILIES.md).

## Services and config

About 100 singletons in `services/` own compositor IPC, audio, network, notifications, theming and content. See [Services Catalogue](SERVICES.md).

- Schema: `modules/common/Config.qml`. Defaults: `defaults/config.json`, 70 top-level sections.
- User file: `~/.config/inir/config.json`. The shell reads it through `~/.config/illogical-impulse/`, which migration 019 links to `~/.config/inir/`.
- Write with `Config.setNestedValue("section.key", value)`. Read with `Config.options?.section?.key ?? fallback`.

See [Config System](CONFIG_SYSTEM.md).

## Theming pipeline

```
Wallpaper
  -> scripts/colors/generate_colors_material.py
  -> colors.json
  -> MaterialThemeLoader
  -> Appearance tokens
  -> every surface, then external apps
```

The 49 built-in presets, plus Auto, skip the wallpaper step and set colours directly. See [Theming Architecture](THEMING_ARCHITECTURE.md).

## Directory map

| Path | Contents | Risk |
|---|---|---|
| `modules/common/` | Config, Appearance, Directories, shared widgets | High |
| `services/` | System integration singletons | High |
| `scripts/inir` | Launcher and CLI in bash, about 5,000 lines | High |
| `sdata/` | Install, update, migrations, distro data | High |
| `modules/ii/sidebar/` | Physical sidebar hosts and live layout | High |
| `modules/shared/` | Surfaces that two or more families load | Normal |
| `modules/ii/`, `modules/waffle/`, `modules/iris/` | Family composition and surfaces | Normal |
| `defaults/` | Shipped config and app configs | Medium |
| `translations/` | 18 locales | Low |

The full breakdown is in [Project Map](PROJECT_MAP.md).

## Install and update

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

There are three install topologies:

- **repo-copy**: the normal install. The checkout is the update source, and a synced runtime lives in `~/.config/quickshell/inir/`.
- **repo-link**: the runtime points at the checkout itself.
- **package-managed**: `make install`, a distro package or Nix owns the runtime and its updates.

Update with `./setup update` or `inir update`. The systemd unit is wired through a wants link on `niri.service`, not `graphical-session.target`, so it never starts under another desktop.

See [Install](INSTALL.md) and [Setup and Update](SETUP.md).
