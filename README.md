<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>A complete desktop shell for Niri, built on Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/snowarch/inir/releases"><img src="https://img.shields.io/badge/version-2.17.0-blue?style=flat-square" alt="Version"></a>
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
  <sub>Languages: <a href="README.md">English</a> · <a href="README.es.md">Español</a> · <a href="README.ru.md">Русский</a></sub>
</p>

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

<details>
<summary><b>Full feature list</b></summary>

### Sidebars & Widgets (Material ii)

Left sidebar (app drawer):
- AI Chat (Gemini, Mistral, OpenRouter, Ollama)
- YT Music player with search and queue
- Wallhaven browser — search and apply wallpapers
- Anime tracker (AniList), Reddit feed, Translator
- Draggable widgets: crypto, media, notes, calendar

Right sidebar:
- Calendar with events, notifications center
- Quick toggles: WiFi, Bluetooth, night light, DND, power profiles, WARP VPN, EasyEffects
- Volume mixer (per-app), Bluetooth & WiFi managers
- Pomodoro timer, todo list, calculator, notepad, system monitor

### Tools

- Workspace overview adapted for Niri's scrolling model
- Alt+Tab window switcher across all workspaces
- Clipboard manager with image preview
- Screenshot, screen recording, OCR, reverse image search
- Keybind cheatsheet from Niri config
- MPRIS media controls, OSD, song recognition, voice search

### System

- GUI settings — configure everything without config files
- GameMode — auto-disables effects for fullscreen apps
- Auto-updates with rollback, migrations, and change preservation
- Lock screen, session screen, polkit agent, on-screen keyboard
- 15+ languages with auto-detection
- Night light, weather, battery management

</details>

---

## Quick Start

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```

Install once with `./setup install`. After that, use `inir` for everything:

```bash
inir run                        # Launch the shell
inir settings                   # Open settings GUI
inir logs                       # Check runtime logs
inir doctor                     # Auto-diagnose and fix
inir status                     # Runtime health check
inir update                     # Pull + migrate + restart
```

**Other install methods:**

| Method | Command |
|--------|---------|
| System install | `sudo make install && inir run` |
| Advanced TUI | `./setup` |
| Rollback | `./setup rollback` |

**Arch only** for the automated installer. Manual guide for other distros: [docs/INSTALL.md](docs/INSTALL.md).

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
inir logs                       # Check recent runtime logs
inir restart                    # Restart the active runtime
inir repair                     # Doctor + restart + filtered log check
inir test-local --with-runtime  # Validate launcher + runtime + logs
./setup doctor                  # Auto-diagnose and fix common problems
./setup rollback                # Undo the last update
```

Check [LIMITATIONS.md](docs/LIMITATIONS.md) before opening an issue.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, code patterns, and pull request guidelines.

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland) — original illogical-impulse for Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — the framework powering this shell
- [**Niri**](https://github.com/YaLTeR/niri) — the scrolling tiling Wayland compositor

---

<p align="center">
  <a href="https://github.com/snowarch/inir/graphs/contributors">Contributors</a> &bull;
  <a href="CHANGELOG.md">Changelog</a> &bull;
  <a href="LICENSE">MIT License</a>
</p>
