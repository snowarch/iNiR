<p align="center">
  <img src="https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8" alt="iNiR" width="800">
</p>

<p align="center">
  🌐 <b>Languages:</b> <a href="README.md">English</a> | <a href="README.es.md">Español</a> | <a href="README.ru.md">Русский</a>
</p>

<h1 align="center">iNiR</h1>

<p align="center">
  <b>A feature-rich Quickshell configuration for the Niri compositor</b><br>
  <sub>Fork of end-4's illogical-impulse, reimagined for Niri</sub>
</p>

<p align="center">
  <a href="docs/INSTALL.md">Installation</a> •
  <a href="docs/KEYBINDS.md">Keybinds</a> •
  <a href="docs/IPC.md">IPC Reference</a> •
  <a href="https://discord.gg/pAPTfAhZUJ">Discord</a>
</p>

---

## Features

- **Two panel families** — Material Design or Windows 11 style, switchable on the fly
- **Five visual styles** — Material (solid), Cards, Aurora (glass blur), Inir (TUI-inspired), Angel (neo-brutalism glass)
- **Workspace overview** — Adapted for Niri's scrolling workspace model
- **Window switcher** — Alt+Tab that works across all workspaces
- **Region tools** — Screenshots, screen recording, OCR, reverse image search
- **Clipboard manager** — Searchable history with image preview
- **Dynamic theming** — Matugen extracts colors from your wallpaper
- **Theme presets** — Gruvbox, Catppuccin, and more, or build your own
- **GameMode** — Auto-disables effects when fullscreen apps are detected
- **GUI Settings** — Configure everything without touching JSON

---

## Screenshots

<details open>
<summary><b>Material ii</b> — Floating bar, sidebars, Material Design aesthetic</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/1fe258bc-8aec-4fd9-8574-d9d7472c3cc8) | ![](https://github.com/user-attachments/assets/3ce2055b-648c-45a1-9d09-705c1b4a03b7) |
| ![](https://github.com/user-attachments/assets/ea2311dc-769e-44dc-a46d-37cf8807d2cc) | ![](https://github.com/user-attachments/assets/da6beb4a-ccee-40ba-a372-5eea77b595f8) |
| ![](https://github.com/user-attachments/assets/ba866063-b26a-47cb-83c8-d77bd033bf8b) | ![](https://github.com/user-attachments/assets/88e76566-061b-4f8c-a9a8-53c157950138) |

</details>

<details>
<summary><b>Waffle</b> — Bottom taskbar, action center, Windows 11 vibes</summary>

| | |
|:---:|:---:|
| ![](https://github.com/user-attachments/assets/5c5996e7-90eb-4789-9921-0d5fe5283fa3) | ![](https://github.com/user-attachments/assets/fadf9562-751e-4138-a3a1-b87b31114d44) |

</details>

---

## Quick Start

**Arch Linux:**

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup install
```

**Other distros:** See [docs/INSTALL.md](docs/INSTALL.md) for manual installation.

**Updating:**

```bash
./setup update
```

Your configs stay untouched. New features are offered as optional migrations.

---

## Default Keybinds

| Key | Action |
|-----|--------|
| `Super+Space` | Overview (search + workspace navigation) |
| `Alt+Tab` | Window switcher |
| `Super+V` | Clipboard history |
| `Super+Shift+S` | Region screenshot |
| `Super+Shift+X` | Region OCR |
| `Super+,` | Settings |
| `Super+Shift+W` | Cycle panel families |

Full list: [docs/KEYBINDS.md](docs/KEYBINDS.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [INSTALL.md](docs/INSTALL.md) | Installation guide |
| [SETUP.md](docs/SETUP.md) | Setup commands, updates, migrations, uninstall |
| [KEYBINDS.md](docs/KEYBINDS.md) | Keyboard shortcuts |
| [IPC.md](docs/IPC.md) | IPC targets for custom bindings |
| [PACKAGES.md](docs/PACKAGES.md) | Required packages |
| [LIMITATIONS.md](docs/LIMITATIONS.md) | Known limitations |

---

## Troubleshooting

```bash
qs log -c ii                    # Check logs
qs kill -c ii && qs -c ii       # Restart shell
./setup doctor                  # Auto-fix common issues
./setup rollback                # Undo last update
```

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland) — Original illogical-impulse for Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) — The framework powering this shell
- [**Niri**](https://github.com/YaLTeR/niri) — The scrolling tiling Wayland compositor

---

<p align="center">
  <sub>This is a personal project. It works on my machine. YMMV.</sub>
</p>
