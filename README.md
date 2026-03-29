<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<p align="center">
  🌐 <b>Languages:</b> <a href="README.md">English</a> | <a href="README.es.md">Español</a> | <a href="README.ru.md">Русский</a>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>A complete desktop shell built on Quickshell for the Niri compositor</b><br>
  <sub>Originally forked from end-4's illogical-impulse — evolved into its own thing</sub>
</p>

<p align="center">
  <a href="docs/INSTALL.md">Install</a> •
  <a href="docs/KEYBINDS.md">Keybinds</a> •
  <a href="docs/IPC.md">IPC Reference</a> •
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
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

### Theming & Appearance

Pick a wallpaper and everything adapts — the shell, GTK/Qt apps, terminals, Firefox, Discord, even the SDDM login screen. All automatic.

- **5 visual styles** — Material (solid), Cards, Aurora (glass blur), iNiR (TUI-inspired), Angel (neo-brutalism)
- **Dynamic wallpaper colors** via matugen — propagate to the entire system
- **10 terminal tools auto-themed** — foot, kitty, alacritty, starship, fuzzel, pywalfox, btop, lazygit, yazi
- **App theming** — GTK3/4, Qt (via plasma-integration + darkly), Firefox (MaterialFox), Discord/Vesktop (System24)
- **Theme presets** — Gruvbox, Catppuccin, Rosé Pine, and more — or make your own
- **Video wallpapers** — mp4/webm/gif with optional blur, or frozen first-frame for performance
- **SDDM login theme** — Material You colors synced with your wallpaper
- **Desktop widgets** — clock (multiple styles), weather, media controls on the wallpaper layer

### Two Panel Families

Switch between them on the fly with `Super+Shift+W`:

- **Material ii** — floating bar (top/bottom, 4 corner styles), sidebars, dock (all 4 positions), control panel, vertical bar variant
- **Waffle** — Windows 11-inspired bottom taskbar, start menu, action center, notification center, widget panel, task view

### Sidebars & Widgets (Material ii)

The left sidebar doubles as an app drawer:

- **AI Chat** — Gemini, Mistral, OpenRouter, or local models via Ollama
- **YT Music** — full player with search, queue, and playback controls
- **Wallhaven browser** — search and apply wallpapers directly
- **Anime tracker** — AniList integration with schedule view
- **Reddit feed** — browse subreddits inline
- **Translator** — powered by Gemini or translate-shell
- **Draggable widgets** — crypto prices, media player, quick notes, status rings, week calendar

The right sidebar covers everyday essentials:

- **Calendar** with event integration
- **Notifications** center
- **Quick toggles** — WiFi, Bluetooth, night light, DND, power profiles, WARP VPN, EasyEffects (Android or classic layout)
- **Volume mixer** — per-app volume control
- **Bluetooth & WiFi** device managers
- **Pomodoro timer**, **todo list**, **calculator**, **notepad**
- **System monitor** — CPU, RAM, temp

### Tools

- **Workspace overview** — adapted for Niri's scrolling model, with app search and calculator
- **Window switcher** — Alt+Tab across all workspaces
- **Clipboard manager** — searchable history with image preview
- **Region tools** — screenshots, screen recording, OCR text extraction, reverse image search
- **Cheatsheet** — keybind viewer pulled from your Niri config
- **Media controls** — full MPRIS player with multiple layout presets
- **On-screen display** — volume, brightness, and media OSD
- **Song recognition** — Shazam-like identification via SongRec
- **Voice search** — record and search via Gemini

### System

- **GUI settings** — configure everything without touching config files
- **GameMode** — auto-disables effects when fullscreen apps are detected
- **Auto-updates** — `inir update` with rollback, migrations, and user-change preservation
- **Lock screen** and **session screen** (logout/reboot/shutdown/suspend)
- **Polkit agent**, **on-screen keyboard**, **autostart manager**
- **15+ languages** — auto-detected, with AI-assisted translation generation
- **Night light** — scheduled or manual blue light filter
- **Weather** — Open-Meteo, supports GPS, manual coords, or city name
- **Battery management** — configurable thresholds, auto-suspend at critical
- **Shell update checker** — notifies when new versions are available

---

## Quick Start

**Most people only need this:**

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
inir run
```

Install once with `./setup install`. After that, use `inir` for daily launching and runtime actions. Maintenance commands like `inir update`, `inir doctor`, and `inir status` are convenience wrappers that delegate back to `setup`.

**Daily commands:**

```bash
inir run
inir settings
inir doctor
inir logs
inir repair
inir status
```

**Packaging-style local install:**

```bash
sudo make install
inir run
```

This installs the shell payload like a packaged application instead of relying only on the repo-sync model.

**Other distros:** The installer fully supports Arch only. Manual installation guide in [docs/INSTALL.md](docs/INSTALL.md).

**Updating:**

```bash
inir update
```

If you want the advanced TUI menu, run `./setup`.

`inir update` and `./setup update` use the same update flow. Use `inir update` as the normal launcher-facing command, and `./setup` when you want the underlying maintenance entrypoint or the interactive menu.

Your configs stay untouched. New features come as optional migrations. Rollback included if something breaks (`./setup rollback`).

**Local validation of the distribution/runtime layer:**

```bash
make test-local
inir test-local
inir test-local --with-runtime
```

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

Full list and customization guide: [docs/KEYBINDS.md](docs/KEYBINDS.md)

---

## Documentation

| | |
|---|---|
| [INSTALL.md](docs/INSTALL.md) | Installation guide |
| [SETUP.md](docs/SETUP.md) | Setup commands — updates, migrations, rollback, uninstall |
| [KEYBINDS.md](docs/KEYBINDS.md) | All keyboard shortcuts |
| [IPC.md](docs/IPC.md) | IPC targets for scripting and custom keybinds |
| [PACKAGES.md](docs/PACKAGES.md) | Every package and why it's there |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | Known limitations and workarounds |
| [OPTIMIZATION.md](docs/OPTIMIZATION.md) | QML performance guide for contributors |

---

## Troubleshooting

```bash
inir logs                       # Check recent runtime logs
inir restart                    # Restart the active runtime
inir status                     # See runtime path, update mode, and health
inir repair                     # Doctor + restart + filtered log check
inir test-local --with-runtime  # Validate launcher + runtime + logs
./setup doctor                  # Auto-diagnose and fix common problems
./setup rollback                # Undo the last update
```

Check [LIMITATIONS.md](docs/LIMITATIONS.md) before opening an issue — it might already be documented.

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland) — original illogical-impulse for Hyprland, where this all started
- [**Quickshell**](https://quickshell.outfoxxed.me/) — the framework powering this shell
- [**Niri**](https://github.com/YaLTeR/niri) — the scrolling tiling Wayland compositor

---

<p align="center">
  <sub>This is a personal project. It works on my machine. YMMV.</sub>
</p>
