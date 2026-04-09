<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>A complete desktop shell for Niri, built on Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.18.0-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
</p>

<p align="center">
  <a href="docs/INSTALL.md">Install</a> &bull;
  <a href="docs/KEYBINDS.md">Keybinds</a> &bull;
  <a href="docs/IPC.md">IPC Reference</a> &bull;
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a> &bull;
  <a href="CONTRIBUTING.md">Contributing</a>
</p>

<p align="center">
  <sub>
    <a href="README.md">English</a> · <a href="docs/readme/README.es.md">Español</a> · <a href="docs/readme/README.ru.md">Русский</a> · <a href="docs/readme/README.zh.md">中文</a> · <a href="docs/readme/README.ja.md">日本語</a> · <a href="docs/readme/README.pt.md">Português</a> · <a href="docs/readme/README.fr.md">Français</a> · <a href="docs/readme/README.de.md">Deutsch</a> · <a href="docs/readme/README.ko.md">한국어</a> · <a href="docs/readme/README.hi.md">हिन्दी</a> · <a href="docs/readme/README.ar.md">العربية</a> · <a href="docs/readme/README.it.md">Italiano</a>
  </sub>
</p>

---

<details>
<summary><b>🤔 New here? Click if you have no idea what any of this is</b></summary>

### What is this?

iNiR is your entire desktop. The bar at the top, the dock, notifications, settings, wallpapers, all of it. Not a theme, not dotfiles you paste. A full shell that runs on Linux.

### What do I need to run it?

A compositor. That's the thing that handles your windows and puts pixels on screen. iNiR is made for [Niri](https://github.com/YaLTeR/niri) (a tiling Wayland compositor). There's some old Hyprland code from when this was a fork of end-4's dots, but Niri is what I actually use and test.

The shell runs on [Quickshell](https://quickshell.outfoxxed.me/), a framework for building shells in QML (Qt's UI language). You don't need to know any of that to use it though, everything is configurable through the GUI or a JSON file.

### How it all connects

```
your apps
   ↓
iNiR (shell: bar, sidebars, dock, notifications, settings...)
   ↓
Quickshell (runs QML shells)
   ↓
Niri (compositor: windows, rendering)
   ↓
Wayland → GPU
```

### Is it stable?

It's a personal project that got out of hand. I use it daily, lots of people in the Discord do too. But stuff breaks sometimes, code is messy in places, I'm learning as I go.

If something doesn't work, `inir doctor` fixes most things. Discord is active if that doesn't help. Just don't expect polished software, this is one person's rice that others happen to like.

### Why does it exist?

I wanted my desktop to look and work a certain way and nothing else did exactly that. Started as end-4's Hyprland dots, became a full rewrite for Niri with way more features.

### Words you'll see around

- **Shell**: the UI layer (bar, panels, overlays)
- **Compositor**: manages windows, draws to screen (Niri, Hyprland, Sway...)
- **Wayland**: Linux display protocol (the new one, replaces X11)
- **QML**: Qt's declarative UI language, what iNiR is written in
- **Material You**: Google's color system that makes palettes from images (that's the auto-theming)
- **ii / waffle**: the two panel styles. ii = Material Design vibes, waffle = Windows 11 vibes. `Super+Shift+W` switches between them

</details>

---

## Screenshots

<details open>
<summary><b>Material ii</b> — floating bar, sidebars, Material Design aesthetic</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — bottom taskbar, action center, Windows 11 vibes</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Features

**Two panel families**, switchable on the fly with `Super+Shift+W`:
- **Material ii** — floating bar, sidebars, dock, 5 visual styles (material, cards, aurora, inir, angel)
- **Waffle** — Windows 11-inspired taskbar, start menu, action center, notification center

**Automatic theming** — pick a wallpaper and everything adapts:
- Shell colors via Material You, propagated to GTK3/4, Qt, terminals, Firefox, Discord, SDDM
- 10 terminal tools auto-themed (foot, kitty, alacritty, starship, fuzzel, btop, lazygit, yazi)
- Theme presets: Gruvbox, Catppuccin, Rosé Pine, and custom

**Compositor** — built for Niri.

<details>
<summary><b>Full feature list</b></summary>

### Theming & Appearance

Pick a wallpaper and the entire system follows — shell, GTK/Qt apps, terminals, Firefox, Discord, SDDM login screen. All automatic.

- **5 visual styles** — Material (solid), Cards, Aurora (glass blur), iNiR (TUI-inspired), Angel (neo-brutalism)
- **Dynamic wallpaper colors** via Material You — propagated system-wide
- **10 terminal tools auto-themed** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **App theming** — GTK3/4, Qt (via plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Theme presets** — Gruvbox, Catppuccin, Rosé Pine, and more — or create your own
- **Video wallpapers** — mp4/webm/gif with optional blur, or frozen first frame for performance
- **SDDM login theme** — Material You colors synced to your wallpaper
- **Desktop widgets** — clock (multiple styles), weather, media controls on the wallpaper layer

### Sidebars & Widgets (Material ii)

Left sidebar (app drawer):
- **AI Chat** — Gemini, Mistral, OpenRouter, or local models via Ollama
- **YT Music** — full player with search, queue, and controls
- **Wallhaven browser** — search and apply wallpapers directly
- **Anime tracker** — AniList integration with schedule view
- **Reddit feed** — browse subreddits inline
- **Translator** — via Gemini or translate-shell
- **Draggable widgets** — crypto, media player, quick notes, status rings, weekly calendar

Right sidebar:
- **Calendar** with event integration
- **Notification center**
- **Quick toggles** — WiFi, Bluetooth, night light, DND, power profiles, WARP VPN, EasyEffects
- **Volume mixer** — per-app control
- **Bluetooth & WiFi** device management
- **Pomodoro timer**, **todo list**, **calculator**, **notepad**
- **System monitor** — CPU, RAM, temperature

### Tools

- **Workspace overview** — adapted for Niri's scrolling model, with app search and calculator
- **Window switcher** — Alt+Tab across all workspaces
- **Clipboard manager** — history with search and image preview
- **Region tools** — screenshots, screen recording, OCR, reverse image search
- **Cheatsheet** — keybind viewer pulled from your Niri config
- **Media controls** — full MPRIS player with multiple layout presets
- **On-screen display** — volume, brightness, and media OSD
- **Song recognition** — Shazam-style identification via SongRec
- **Voice search** — record and search via Gemini

### System

- **GUI settings** — configure everything without touching files
- **GameMode** — auto-disables effects for fullscreen apps
- **Auto-updates** — `inir update` with rollback, migrations, and user change preservation
- **Lock screen** and **session screen** (logout/reboot/shutdown/suspend)
- **Polkit agent**, **on-screen keyboard**, **autostart manager**
- **9 languages** — auto-detection, with AI-assisted translation generation
- **Night light** — scheduled or manual
- **Weather** — Open-Meteo, supports GPS, manual coordinates, or city name
- **Battery management** — configurable thresholds, auto-suspend on critical
- **Shell update checker** — notifies when new versions are available

</details>

---

## Quick Start

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive — asks before each step
./setup install -y    # automatic — no questions asked
```

The installer handles dependencies, system config, theming — everything. After install, run `inir run` to start the shell, or log out and back in.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

**Supported distros:** Arch (automated installer). Other distros can install manually — see [PACKAGES.md](docs/PACKAGES.md).

| Method | Command |
|--------|---------|
| System install | `sudo make install && inir run` |
| TUI menu | `./setup` |
| Rollback | `./setup rollback` |

---

## Keybinds

| Key | Action |
|-----|--------|
| `Super+Space` | Overview — search apps, navigate workspaces |
| `Alt+Tab` | Window switcher |
| `Super+V` | Clipboard history |
| `Super+Shift+S` | Screenshot region |
| `Super+Shift+X` | OCR region |
| `Super+,` | Settings |
| `Super+Shift+W` | Switch panel family |

Full list: [docs/KEYBINDS.md](docs/KEYBINDS.md)

---

## Wallpapers

15 wallpapers ship bundled. For more, check [iNiR-Walls](https://github.com/snowarch/iNiR-Walls) — a curated collection that works well with the Material You pipeline.

---

## Documentation

| | |
|---|---|
| [INSTALL.md](docs/INSTALL.md) | Installation guide |
| [SETUP.md](docs/SETUP.md) | Setup commands — updates, migrations, rollback |
| [KEYBINDS.md](docs/KEYBINDS.md) | All keyboard shortcuts |
| [IPC.md](docs/IPC.md) | IPC targets for scripting and keybinds |
| [PACKAGES.md](docs/PACKAGES.md) | Every dependency and why it's there |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | Known limitations and workarounds |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical architecture overview |

---

## Troubleshooting

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Check [LIMITATIONS.md](docs/LIMITATIONS.md) before opening an issue.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code patterns, and pull request guidelines.

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland): original illogical-impulse for Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/): the framework powering this shell
- [**Niri**](https://github.com/YaLTeR/niri): the scrolling tiling Wayland compositor

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributors</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">MIT License</a>
</p>
