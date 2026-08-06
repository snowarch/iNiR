# Default Keybinds

These are the default keybinds shipped with iNiR. They live in `~/.config/niri/config.d/70-binds.kdl` after install.

Change them. Break them. Make them yours. We won't judge.

---

## iNiR Shell

| Key | Action |
|-----|--------|
| `Mod+Space` | iNiR overview / app launcher |
| `Mod+Tab` | Niri overview (native compositor) |
| `Super+G` | Floating tools (notes, images, crosshair, resources) |
| `Alt+Tab` | Niri Recent Windows (next) |
| `Alt+Shift+Tab` | Niri Recent Windows (previous) |
| `Mod+V` | Clipboard history |
| `Mod+/` | Cheatsheet |
| `Mod+,` | Settings |
| `Mod+Alt+L` | Lock screen |
| `Ctrl+Alt+T` | Wallpaper selector |
| `Mod+Shift+W` | Cycle panel family (ii ↔ waffle) |
| `Mod+Shift+Q` | Session / power dialog |

---

## Region Tools

| Key | Action |
|-----|--------|
| `Mod+Shift+S` | Region screenshot |
| `Mod+Shift+X` | Region OCR |
| `Mod+Shift+A` | Region image search |
| `Mod+Shift+R` | Region screen recording (with audio) |
| `Print` | Full screenshot (Niri native) |
| `Ctrl+Print` | Screenshot current screen |
| `Alt+Print` | Screenshot current window |

---

## Window Management

| Key | Action |
|-----|--------|
| `Mod+Q` | Close window (with confirmation) |
| `Mod+D` | Maximize column (keeps gaps) |
| `Mod+F` | Toggle fullscreen |
| `Mod+A` | Toggle floating / tiling |
| `Mod+Shift+V` | Switch focus between floating and tiling layers |

### Focus

| Key | Action |
|-----|--------|
| `Mod+Left/H` | Focus column left |
| `Mod+Right/L` | Focus column right |
| `Mod+Up/K` | Focus window up |
| `Mod+Down/J` | Focus window down |
| `Mod+Home` | Focus first column |
| `Mod+End` | Focus last column |

### Move

| Key | Action |
|-----|--------|
| `Mod+Shift+Left/H` | Move column left |
| `Mod+Shift+Right/L` | Move column right |
| `Mod+Shift+Up/K` | Move window up |
| `Mod+Shift+Down/J` | Move window down |
| `Mod+Ctrl+Home` | Move column to first |
| `Mod+Ctrl+End` | Move column to last |

---

## Column Layout

Niri arranges windows in an infinite horizontal strip. These binds control column sizing and stacking.

| Key | Action |
|-----|--------|
| `Mod+R` | Cycle preset column widths (⅓ → ½ → ⅔) |
| `Mod+Ctrl+R` | Reset window height |
| `Mod+C` | Center focused column |
| `Mod+Minus` | Shrink column width 10% |
| `Mod+Equal` | Grow column width 10% |
| `Mod+Shift+Minus` | Shrink window height 10% |
| `Mod+Shift+Equal` | Grow window height 10% |
| `Mod+[` | Consume/expel window left (stack or unstack) |
| `Mod+]` | Consume/expel window right (stack or unstack) |

---

## Multi-Monitor

| Key | Action |
|-----|--------|
| `Mod+Ctrl+Left` | Focus monitor left |
| `Mod+Ctrl+Right` | Focus monitor right |
| `Mod+Ctrl+Up` | Focus monitor up |
| `Mod+Ctrl+Down` | Focus monitor down |
| `Mod+Ctrl+Shift+Left` | Move column to monitor left |
| `Mod+Ctrl+Shift+Right` | Move column to monitor right |
| `Mod+Ctrl+Shift+Up` | Move column to monitor up |
| `Mod+Ctrl+Shift+Down` | Move column to monitor down |

---

## Workspaces

| Key | Action |
|-----|--------|
| `Mod+1-9` | Focus workspace 1-9 |
| `Mod+Ctrl+1-9` | Move column to workspace 1-9 |
| `Mod+Page_Down` | Focus workspace down |
| `Mod+Page_Up` | Focus workspace up |
| `Mod+Ctrl+Page_Down` | Move column to workspace down |
| `Mod+Ctrl+Page_Up` | Move column to workspace up |
| `Mod+WheelScrollDown` | Focus workspace down (mouse) |
| `Mod+WheelScrollUp` | Focus workspace up (mouse) |

---

## Applications

| Key | Action |
|-----|--------|
| `Mod+T` / `Mod+Return` | Terminal |
| `Super+E` | File manager (Nautilus) |
| `Super+W` | Browser |

---

## Session & System

| Key | Action |
|-----|--------|
| `Mod+Shift+E` | Quit Niri |
| `Mod+Shift+O` | Power off monitors |
| `Mod+Escape` | Toggle keyboard shortcuts inhibit |

---

## Media & Hardware Keys

All media/volume/brightness keys are routed through iNiR IPC for OSD feedback.

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume up |
| `XF86AudioLowerVolume` | Volume down |
| `XF86AudioMute` | Toggle mute |
| `XF86AudioMicMute` | Toggle mic mute |
| `XF86AudioPlay/Pause` | Play/pause |
| `XF86AudioNext` | Next track |
| `XF86AudioPrev` | Previous track |
| `XF86MonBrightnessUp` | Brightness up |
| `XF86MonBrightnessDown` | Brightness down |
| `Ctrl+Mod+Space` / `Mod+Shift+P` | Play/pause (keyboard) |
| `Mod+Alt+N` / `Mod+Shift+N` | Next track (keyboard) |
| `Mod+Alt+P` / `Mod+Shift+B` | Previous track (keyboard) |
| `Mod+Shift+M` | Toggle mute (keyboard) |

---

## Customizing

Keybinds live in `~/.config/niri/config.d/70-binds.kdl`. Add personal overrides in `90-user-extra.kdl` (never touched by updates).

The distributed Alt-Tab uses Niri's native `recent-windows` surface. Its
preview timing, highlight and size are tuned in `config.d/20-layout-and-overview.kdl`.
The iNiR switcher remains available from Settings, but is disabled by default
so two window switchers do not compete for the same keys.

See [IPC.md](IPC.md) for all available iNiR targets you can bind.

```kdl
// In 90-user-extra.kdl
binds {
    Super+P { spawn "inir" "session" "toggle"; }
}
```

Niri auto-reloads on save. If it doesn't pick up a change, force it:

```bash
niri msg action load-config-file
```
