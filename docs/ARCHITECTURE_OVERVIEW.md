# Architecture Overview

How iNiR is put together, from the highest level down to the part that matters for your question.

## The 30-second version

The core shell is one Quickshell/QML runtime. Bars, panels, config and most service state live in that process, while system integration deliberately crosses into D-Bus, compositor sockets and helper subprocesses/daemons where that work does not belong in QML.

```
Your apps
   |
iNiR shell (bar, panels, notifications, settings, everything)
   |
Quickshell (QML shell framework)
   |
Niri compositor (windows, rendering, input)
   |
Wayland protocol --> GPU
```

## Entry point

`shell.qml` is the root. It's a `ShellRoot` (Quickshell-specific, not a regular QML Item). On load it:

1. Force-instantiates critical singletons (Idle, PowerProfilePersistence)
2. Waits for `Config.ready` (JSON config loaded from disk)
3. Applies the current theme
4. Loads the selected family's small critical host for first-frame surfaces
5. After the entry frame, enables deferred services and the thin `ShellIiPanels.qml` / `ShellWafflePanels.qml` / `ShellIrisPanels.qml` wrapper, which loads the corresponding `modules/*/Shell*PanelsImpl.qml`

Boot phases are recorded to `~/.cache/inir/last-boot.json`; `inir status` can report the measured phase breakdown instead of relying on a fixed startup-time claim.

## Three panel families

The shell has three separate visual identities that share the same services layer:

**Material ii** uses the shared `Appearance` system with nine global styles: material, cards, aurora, inir, angel, regalia, zzz, cookie and editorial. Bar at the top/edge. Sidebars from the edges. Overview launcher.

**Waffle** uses Windows 11 Fluent Design. Taskbar at the bottom. Start menu. Action center. Notification center. Its layout/components remain Waffle-owned while `Looks` can adapt colors/material semantics from the selected global style.

**iRiS** uses its own `IrisStyle` system. Its Island can live on any edge or become a full-width bar, the Dock can move independently, and pieces can attach to the chassis or float on the desktop. Studio and shareable Themes edit the family without changing ii or Waffle.

They're mutually exclusive at runtime. Switch with `Super+Shift+W`. All three read from the same Config singleton and shared services, while their presentation stays family-owned through `Appearance.*`, `Looks.*` or `IrisStyle.*`.

More details: [Panel Families](PANEL_FAMILIES.md)

## Services layer

70+ QML singletons handle everything that isn't pure UI:

- **Compositor IPC**: NiriService talks to Niri via socket, gets workspace/window/output state
- **System integration**: Audio (PipeWire), Network (NetworkManager), Bluetooth (BlueZ), Battery (UPower)
- **Data management**: Notifications, clipboard history, events, weather, calendar sync
- **Theming**: MaterialThemeLoader watches `colors.json`, ThemeService orchestrates the pipeline
- **Content**: AI chat (Gemini/OpenAI/Ollama), YT Music player, anime tracking

Services are registered in `services/qmldir` and available everywhere as singletons.

Full catalog: [Services Catalog](SERVICES.md)

## Config system

One JSON file, one QML schema, one write method:

- **Schema**: `modules/common/Config.qml` (~60 top-level sections)
- **User file**: `~/.config/inir/config.json` (canonical; legacy installs are preserved through the compatibility resolver/symlink)
- **Defaults**: `defaults/config.json`
- **Write**: `Config.setNestedValue("section.key", value)` (the only way that persists)
- **Read**: `Config.options?.section?.key ?? fallback`

Users configure everything through the graphical Settings UI. The JSON file is an implementation detail they shouldn't need to touch.

More details: [Config System](CONFIG_SYSTEM.md)

## Theming pipeline

Pick a wallpaper and the entire system follows:

```
Wallpaper image
   |
generate_colors_material.py (Material You color extraction)
   |
colors.json (full Material 3 palette)
   |
MaterialThemeLoader (QML file watcher)
   |
Appearance tokens (400+ color/size/animation properties)
   |
Every UI component
   |
External apps (GTK, terminals, Firefox, VS Code, Discord...)
```

The pipeline also supports 46 built-in theme presets (Catppuccin, Gruvbox, Nord, etc.) that bypass wallpaper extraction and inject colors directly.

More details: [Theming Architecture](THEMING_ARCHITECTURE.md)

## Directory structure

A simplified map of what lives where:

| Directory | What's in it | Risk level |
|-----------|-------------|------------|
| `modules/common/` | Config, Appearance, shared widgets | Critical |
| `services/` | 70+ system integration singletons | High |
| `scripts/inir` | CLI launcher (~3600 lines of bash) | High |
| `sdata/` | Install, update, migrations | High |
| `defaults/` | Shipped default config and app configs | Medium |
| `modules/bar/` | Top bar (ii family) | Normal |
| `modules/waffle/` | Complete Windows 11 family | Normal |
| `modules/sidebar/` | Physical sidebar hosts and live layout behavior | High |
| `modules/sidebarLeft/` | Semantic feature content: AI chat, YT Music, widgets | Normal |
| `modules/sidebarRight/` | Semantic system content: toggles, calendar, tools | Normal |
| `translations/` | i18n strings (18 locales) | Low |

Full breakdown: [Project Map](PROJECT_MAP.md)

## Distribution

iNiR ships as a git repo with an interactive installer:

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

Three install topologies are recognized:

- **repo-copy**: normal `./setup install`, with the checkout as update source and a synchronized runtime at `~/.config/quickshell/inir/`
- **repo-link**: development/runtime points at the checkout itself
- **package-managed**: `make install`, distro packages or Nix own a system-prefix runtime and its updates

Updates: `./setup update` or `inir update` (git pull + sync + migrate + restart).

The systemd service wires to the compositor via wants links, not `graphical-session.target` (which would also start on KDE/GNOME).

More details: [Installation](INSTALL.md), [Setup & Update](SETUP.md)
