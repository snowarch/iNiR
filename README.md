# ii on Niri

A Quickshell shell for Niri. Fork of end-4's illogical-impulse, butchered to work on a different compositor.

> [!CAUTION]
> **Hey.** This is my personal rice. I put effort into it, but it's not a product - don't expect hand-holding or stability guarantees. If you're just here because "it looks cool" and have no clue what Niri even is, maybe check out something more beginner-friendly first. Your system, your responsibility.

> **Heads up:** almost everything here is configurable. Modules, colors, fonts, animations - if something bugs you, there's probably a toggle for it. Hit `Super+,` for settings before you rage-quit.

| Overview | Uglydesktop |
|:---|:---|
| ![Overview](https://github.com/user-attachments/assets/9faaad0e-a665-4747-9428-ea94756e1f0f) | ![Sidebars](https://github.com/user-attachments/assets/21e43f3e-d6d9-4625-8210-642f9c05509b) |

| Overlay/Search | Settings/Sidebar |
|:---|:---|
| ![Settings](https://github.com/user-attachments/assets/25700a1c-70e6-4456-b053-35cf83fcac7a) | ![Overlay](https://github.com/user-attachments/assets/1d5ca0f0-6ffb-46da-be1a-2d5e494089e7) |

---

## What is this

A shell. Bar at the top, sidebars on the sides, overlays that pop up when you press keys. The usual.

- **Bar** - clock, workspaces, tray, the stuff you expect
- **Sidebars** - left one has AI chat and wallpaper browser, right one has quick toggles and a notepad
- **Overview** - workspace grid, adapted for Niri's scrolling model
- **Alt+Tab** - window switcher that actually works across workspaces
- **Clipboard** - history panel with search (needs cliphist)
- **Region tools** - screenshots, screen recording, OCR, reverse image search
- **Wallpaper** - picker, video support, and matugen pulls colors from whatever you set
- **Theming** - presets like Gruvbox and Catppuccin, or build your own with the custom theme editor. Fonts are customizable too
- **Settings** - GUI config with search, so you don't have to edit JSON like a caveman
- **GameMode** - fullscreen app? Effects go bye-bye. Your games won't stutter
- **Idle** - screen off, lock, suspend timeouts. swayidle handles it, you configure it

### Two flavors, one shell

Can't decide on a look? Good news, you don't have to.

- **Material ii** - The OG. Floating bar, sidebars, that Material Design aesthetic.
- **Waffle** - Taskbar at the bottom, action center, tray overflow. For the "I kinda miss Windows" crowd.

Press `Mod+Shift+W` to cycle between styles, or go to Settings → Modules to mix and match.

---

## Documentation

Read these or suffer.

| Doc | What's in it |
|-----|--------------|
| [docs/INSTALL.md](docs/INSTALL.md) | How to install this thing |
| [docs/PACKAGES.md](docs/PACKAGES.md) | Every package the installer uses, by category |
| [docs/KEYBINDS.md](docs/KEYBINDS.md) | Default keyboard shortcuts |
| [docs/IPC.md](docs/IPC.md) | All IPC targets for custom keybindings |
| [docs/SETUP.md](docs/SETUP.md) | How the setup script works, updates, uninstall |
| [docs/LIMITATIONS.md](docs/LIMITATIONS.md) | Known limitations and what doesn't work |

---

## Quick Install

Arch-based? Run this:

```bash
git clone https://github.com/snowarch/quickshell-ii-niri.git
cd quickshell-ii-niri
./setup install -y
```

Not on Arch? Check [docs/INSTALL.md](docs/INSTALL.md) for manual steps.

---

## Updating

Already installed? Pull and sync:

```bash
cd quickshell-ii-niri
git pull
./setup update
```

Syncs QML and configs. Your customizations stay. Missing keybinds get added. Hot reload does the rest.

---

## Keybinds (the important ones)

These come configured by default:

| Key | What it does |
|-----|--------------|
| `Mod+Tab` | Niri overview (native) |
| `Mod+Space` (`Super+Space`) | ii overview (search/workspaces nav) |
| `Alt+Tab` | ii window switcher |
| `Super+G` | ii overlay ( widgets/utils) |
| `Super+V` | Clipboard history |
| `Super+Shift+S` | Region screenshot |
| `Super+Shift+X` | Region OCR |
| `Ctrl+Alt+T` | Wallpaper picker |
| `Super+/` | Keyboard shortcuts cheatsheet |
| `Super+,` | Settings |
| `Mod+Shift+W` | Cycle panel style (Material ↔ Waffle) |

Full list in [docs/KEYBINDS.md](docs/KEYBINDS.md).

---

## IPC (for nerds who want custom bindings)

ii exposes IPC targets you can bind to whatever keys you want. Syntax:

```kdl
bind "Key" { spawn "qs" "-c" "ii" "ipc" "call" "<target>" "<function>"; }
```

Main targets:

| Target | Functions |
|--------|-----------|
| `overview` | `toggle` |
| `overlay` | `toggle` |
| `clipboard` | `toggle`, `open`, `close` |
| `altSwitcher` | `next`, `previous`, `toggle` |
| `region` | `screenshot`, `ocr`, `search`, `record` |
| `session` | `toggle` |
| `lock` | `activate` |
| `cheatsheet` | `toggle` |
| `settings` | `open` |
| `sidebarLeft` | `toggle` |
| `sidebarRight` | `toggle` |
| `wallpaperSelector` | `toggle` |
| `panelFamily` | `cycle`, `set` |
| `mpris` | `playPause`, `next`, `previous` |
| `brightness` | `increment`, `decrement` |
| `gamemode` | `toggle`, `activate`, `deactivate`, `status` |
| `notifications` | `test`, `clearAll`, `toggleSilent` |

Full reference with examples: [docs/IPC.md](docs/IPC.md)

---

## Troubleshooting

Something broke? Shocking.

```bash
# Check the logs
qs log -c ii

# Restart ii without restarting Niri
qs kill -c ii && qs -c ii

# Nuclear option: reload everything
niri msg action load-config-file
```

If you're still stuck, the logs usually tell you what's missing. Usually.

---

## Fair warning

This is my daily driver. It works. Most of the time. I break things when I'm bored.

If you want something stable and polished, check out end-4's original ii for Hyprland instead. This fork is for people who like living dangerously on Niri.

---

## Credits

- [**end-4**](https://github.com/end-4/dots-hyprland) –  illogical-impulse for Hyprland
- [**Quickshell**](https://quickshell.outfoxxed.me/) – the framework that makes this possible
- [**Niri**](https://github.com/YaLTeR/niri) – the compositor that doesn't crash
