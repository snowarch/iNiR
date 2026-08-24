<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>A complete desktop shell for Niri, built on Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.29.1-blue?style=flat-square" alt="Version"></a>
  <a href="https://github.com/snowarch/inir/stargazers"><img src="https://img.shields.io/github/stars/snowarch/inir?style=flat-square" alt="Stars"></a>
  <a href="https://discord.gg/pAPTfAhZUJ"><img src="https://img.shields.io/badge/Discord-join-5865F2?style=flat-square&logo=discord&logoColor=white" alt="Discord"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/wiki/INSTALL">Install</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/KEYBINDS">Keybinds</a> &bull;
  <a href="https://github.com/snowarch/inir/wiki/IPC">IPC Reference</a> &bull;
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
<summary><b>Material ii</b>: floating bar, sidebars, Material Design aesthetic</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b>: bottom taskbar, action center, Windows 11 vibes</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

> [!WARNING]
> Not for low-spec machines.
> You can strip it down a lot though. Turn off effects, drop panels, flatten the design. Settings or `config.json`, whichever you prefer.

## Features

**Two panel families**, switchable on the fly with `Super+Shift+W`:
- **Material ii**: floating bar, sidebars, dock, and 7 visual styles (Material, Cards, Aurora, iNiR, Angel, ZZZ, Cookie Shapes)
- **Waffle**: Windows 11-inspired taskbar, start menu, action center, notification center

**Automatic theming**. Pick a wallpaper and everything adapts:
- Shell colors via Material You, propagated to GTK3/4, Qt, terminals, Firefox, Discord, SDDM
- 10 theming targets covering terminals, editors, browsers, Spicetify, Steam, Cava and more
- Theme presets: Gruvbox, Catppuccin, Rosé Pine, and custom

**Built for Niri.** Hyprland code survives from the fork but is not tested.

**Kira**, the mascot, lives on your desktop if you want her there. Off by default, art pack is a separate download.

<details>
<summary><b>Full feature list</b></summary>

### Theming and appearance

- **7 visual styles**: Material (solid), Cards, Aurora (glass blur), iNiR (TUI-inspired), Angel (neo-brutalism), ZZZ (poster plates), Cookie Shapes (animated shape morphing)
- **Dynamic wallpaper colors** via Material You, propagated system-wide
- **10 terminal and TUI tools auto-themed**: foot, kitty, alacritty, ghostty, wezterm, starship, fuzzel, btop, lazygit, yazi
- **App theming**: GTK3/4, Qt (via plasma-integration and darkly), Firefox (MaterialFox), Discord/Vesktop (System24), Zed, Spicetify, Steam, SDDM
- **Theme presets**: Gruvbox, Catppuccin, Rosé Pine, and more, or create your own
- **Video wallpapers**: mp4/webm/gif with optional blur, or frozen first frame for performance
- **Desktop widgets**: clock (multiple styles), weather, media controls on the wallpaper layer

### Bar

- **6 bar styles**: classic, islands, scenic, frame, Material 3 capsules, and pill
- **Pill bar**: a morphing centre island that opens on hover into workspaces, launcher, mixer, media, calendar and a screen recorder
- **Modular layout** with a drag editor in Settings, so any module can go anywhere
- **Vertical bar** for the people who want the screen edge back

### Sidebars and widgets (Material ii)

Left sidebar (app drawer):
- **AI Chat**: live model catalogs across Ollama, LM Studio, OpenRouter, Gemini, Groq, Mistral, Cerebras, Anthropic, OpenAI and OpenCode
- **YT Music**: cookie-less InnerTube player with search, queue, radio and synced lyrics
- **Wallhaven browser**: search and apply wallpapers directly
- **Anime tracker**: AniList integration with schedule view
- **Translator**: via Gemini or translate-shell
- **Draggable widgets**: crypto, media player, quick notes, status rings, weekly calendar

Right sidebar:
- **Calendar** with event integration
- **Notification center**
- **Quick toggles**: WiFi, Bluetooth, night light, DND, power profiles, WARP VPN, EasyEffects
- **Volume mixer** with per-app control
- **Bluetooth and WiFi** device management
- **Pomodoro timer**, **todo list**, **calculator**, **notepad**
- **System monitor**: CPU, RAM, temperature

### Tools

- **Workspace overview**: adapted for Niri's scrolling model, with app search and calculator
- **Dashboard hub**: configurable three-column overlay with agenda, notifications, todo, notes, media and weather
- **Workspace edge strip**: hover rail with live workspace previews and drag-to-reorder
- **Window switcher**: an animated Alt-Tab across all workspaces, opt-in since Niri ships its own now
- **Clipboard manager**: history with search and image preview
- **Region tools**: screenshots, screen recording, OCR, reverse image search
- **Cheatsheet**: keybind viewer pulled from your Niri config
- **Media controls**: full MPRIS player with multiple layout presets
- **On-screen display**: volume, brightness, and media OSD
- **Song recognition**: Shazam-style identification via SongRec
- **Voice input**: local whisper.cpp when installed, or a connected Groq, Gemini or OpenAI backend

### System

- **GUI settings**: configure everything without touching files
- **GameMode**: auto-disables effects for fullscreen apps
- **Auto-updates**: `inir update` with rollback, migrations, and user change preservation
- **Lock screen** and **session screen** (logout/reboot/shutdown/suspend)
- **Polkit agent**, **on-screen keyboard**, **autostart manager** backed by niri's own startup file
- **Kira**: pixel-art cat girl who wanders the screen edges, reacts to what you do, and has a chaos mode. Opt-in, separate ~32 MiB art pack under `./setup` › Extras
- **15 languages** with auto-detection
- **Night light**: scheduled or manual
- **Weather**: Open-Meteo, supports GPS, manual coordinates, or city name
- **Battery management**: configurable thresholds, auto-suspend on critical
- **Custom event sounds** with a master volume and per-event audio files
- **Shell update checker**: notifies when new versions are available

</details>

---

## Quick Start

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install       # interactive, asks before each step
./setup install -y    # automatic, no questions asked
```

The installer handles dependencies, system config and theming. After install, run `inir run` to start the shell, or log out and back in.

```bash
inir run                        # launch the shell
inir settings                   # open settings GUI
inir logs                       # check runtime logs
inir doctor                     # auto-diagnose and fix
inir update                     # pull + migrate + restart
```

Other ways in, if `./setup install` isn't what you want:

```bash
./setup                 # TUI menu, pick what you want
sudo make install       # system-wide instead of your home
./setup rollback        # undo the last update
```

**Distros:** Arch gets the automated installer. Everything else installs by hand, the [package list](https://github.com/snowarch/inir/wiki/PACKAGES) tells you what you need.

---

## Keybinds

| Key | Action |
|-----|--------|
| <kbd>Super</kbd> + <kbd>Space</kbd> | Overview: search apps, navigate workspaces |
| <kbd>Super</kbd> + <kbd>V</kbd> | Clipboard history |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Screenshot a region |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>X</kbd> | OCR a region |
| <kbd>Super</kbd> + <kbd>,</kbd> | Settings |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>W</kbd> | Switch panel family |
| <kbd>Super</kbd> + <kbd>/</kbd> | Cheatsheet, in case you forget the rest |

Full list: [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS)

---

## Wallpapers

15 wallpapers ship bundled. For more, check [iNiR-Walls](https://github.com/snowarch/iNiR-Walls), a curated collection that works well with the Material You pipeline.

---

## Documentation

Everything user-facing lives in the [Wiki](https://github.com/snowarch/inir/wiki).

| Page | What's in it |
|---|---|
| [Install](https://github.com/snowarch/inir/wiki/INSTALL) | Getting it running |
| [Setup](https://github.com/snowarch/inir/wiki/SETUP) | Updates, migrations, rollback |
| [Keybinds](https://github.com/snowarch/inir/wiki/KEYBINDS) | Every shortcut |
| [IPC](https://github.com/snowarch/inir/wiki/IPC) | Targets you can bind or script |
| [Packages](https://github.com/snowarch/inir/wiki/PACKAGES) | Every dependency and why it's there |
| [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) | What's known broken, and workarounds |
| [Architecture](ARCHITECTURE.md) | How the code is put together |

---

## Troubleshooting

```bash
inir logs                       # check recent runtime logs
inir restart                    # restart the active runtime
inir repair                     # doctor + restart + filtered log check
./setup doctor                  # auto-diagnose and fix common problems
./setup rollback                # undo the last update
```

Check [Limitations](https://github.com/snowarch/inir/wiki/LIMITATIONS) before opening an issue. If you'd rather just ask someone, Discord is faster.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code patterns, and pull request guidelines.

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland): illogical-impulse, the Hyprland dots iNiR forked from
- [**Gakuseei**](https://github.com/Gakuseei): [Ricelin](https://github.com/Gakuseei/Ricelin), where the pill bar and the washi and flame look come from
- [**Quickshell**](https://quickshell.outfoxxed.me/): the framework this runs on
- [**Niri**](https://github.com/YaLTeR/niri): the compositor it's built for

GPL-3.0, same as end-4's dots. Copyright (C) 2025-2026 snowarch.

---

<p align="center">
  <img src="https://raw.githubusercontent.com/snowarch/inir-mascot/main/inir-mascot-hero-banner.png" alt="iNiR mascot leaning on the iNiR logotype" width="720">
</p>

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributors</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">GPL-3.0 License</a>
</p>
