# Default Keybinds

These are the default keybinds shipped with inir. They live in `~/.config/niri/config.kdl` after install.

Change them. Break them. Make them yours. We won't judge.

---

## inir Controls

| Key | Action |
|-----|--------|
| `Mod+Tab` | Niri overview (native compositor) |
| `Mod+Space` | inir overview (daemon) |
| `Super+G` | inir overlay (search, widgets) |
| `Alt+Tab` | inir window switcher (next) |
| `Alt+Shift+Tab` | inir window switcher (previous) |
| `Super+V` | Clipboard history |
| `Super+/` | Cheatsheet |
| `Super+,` | Settings |
| `Super+Alt+L` | Lock screen |
| `Ctrl+Alt+T` | Wallpaper selector |
| `Mod+Shift+W` | Cycle panel family (inir ↔ waffle) |

---

## Region Tools

| Key | Action |
|-----|--------|
| `Super+Shift+S` | Region screenshot |
| `Super+Shift+X` | Region OCR |
| `Super+Shift+A` | Region image search |
| `Print` | Full screenshot (native) |
| `Ctrl+Print` | Screenshot current screen |
| `Alt+Print` | Screenshot current window |

---

## Window Management

| Key | Action |
|-----|--------|
| `Super+Q` | Close window (with optional confirmation) |
| `Super+D` | Maximize column |
| `Super+F` | Toggle fullscreen |
| `Super+A` | Toggle floating |

### Focus

| Key | Action |
|-----|--------|
| `Super+Left/H` | Focus left |
| `Super+Right/L` | Focus right |
| `Super+Up/K` | Focus up |
| `Super+Down/J` | Focus down |

### Move

| Key | Action |
|-----|--------|
| `Super+Shift+Left/H` | Move left |
| `Super+Shift+Right/L` | Move right |
| `Super+Shift+Up/K` | Move up |
| `Super+Shift+Down/J` | Move down |

---

## Workspaces

| Key | Action |
|-----|--------|
| `Super+1-9` | Focus workspace 1-9 |
| `Super+Shift+1-5` | Move window to workspace 1-5 |

---

## Applications

| Key | Action |
|-----|--------|
| `Super+T` / `Super+Return` | Terminal (foot) |
| `Super+E` | File manager (nautilus) |

---

## System

| Key | Action |
|-----|--------|
| `Super+Shift+E` | Quit Niri |
| `Super+Shift+O` | Power off monitors |
| `Super+Escape` | Toggle keyboard shortcuts inhibit |

---

## Media Keys

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioPlay` | Play/pause (via inir IPC) |
| `XF86AudioNext` | Next track (via inir IPC) |
| `XF86AudioPrev` | Previous track (via inir IPC) |
| `XF86MonBrightnessUp` | Brightness up (via inir IPC) |
| `XF86MonBrightnessDown` | Brightness down (via inir IPC) |

---

## Customizing

Edit `~/.config/niri/config.kdl` to change keybinds. See [IPC.md](IPC.md) for all available inir targets you can bind.

Example (because you're definitely going to ask):

```kdl
binds {
    // Your custom binds
    Super+P { spawn "qs" "-c" "inir" "ipc" "call" "session" "toggle"; }
}
```

Then reload Niri so it actually notices:

```bash
niri msg action load-config-file
```

If your keybind doesn't work, you probably forgot to reload. Don't worry, we've all been there.
