# Keybinds

These are the shortcuts that ship with iNiR. Super is the Windows key. Niri's config calls it `Mod`.

## iNiR tools

| Key | Action |
|---|---|
| Super+Space | iNiR overview and app launcher |
| Super+V | Clipboard history |
| Super+Comma | Settings |
| Super+Slash | Cheatsheet |
| Super+G | Floating tools: crosshair, notes, resources and more |
| Super+Alt+L | Lock screen |
| Super+Ctrl+Shift+L | Refocus the lock screen, if input stops working after suspend |
| Ctrl+Alt+T | Wallpaper selector |
| Super+Shift+W | Cycle the panel family: Material ii, Waffle, iRiS |
| Super+Shift+Q | Session and power dialog |
| Ctrl+Alt+F | EasyEffects equalizer. Enable it first in Settings › Modules › Optional |

## Region tools

| Key | Action |
|---|---|
| Super+Shift+S | Region tools, opening the action you chose last |
| Ctrl+Shift+S | Region tools menu |
| Super+Shift+X | Region OCR |
| Super+Shift+A | Region search with Google Lens |
| Super+Shift+R | Record a region with sound |
| Print | Niri screenshot: pick an area, a screen or a window |
| Ctrl+Print or Super+Print | Screenshot of the current screen |
| Alt+Print | Screenshot of the current window |

## Windows

| Key | Action |
|---|---|
| Super+Q | Close window, with a confirmation dialog |
| Super+D | Maximise the column, keeping the gaps |
| Super+F | Fullscreen |
| Super+A | Toggle floating and tiling |
| Super+Shift+V | Switch focus between floating and tiling |
| Alt+Tab / Alt+Shift+Tab | Next / previous window, in Niri's switcher |
| Super+Tab | Niri's overview |
| Super+Escape | Turn keyboard shortcut inhibit on or off, for apps like remote desktop clients |
| Super+Shift+E | Quit Niri, with a confirmation |
| Super+Shift+O | Power off the monitors |

## Columns and sizes

| Key | Action |
|---|---|
| Super+R | Cycle preset column widths: 1/3, 1/2, 2/3 |
| Super+C | Centre the focused column |
| Super+Ctrl+R | Reset window height |
| Super+Minus / Super+Equal | Narrow or widen the column by 10% |
| Super+Shift+Minus / Super+Shift+Equal | Shorten or heighten the window by 10% |
| Super+[ / Super+] | Stack the window from the left or right into this column, or unstack it |

## Focus and moving

| Key | Action |
|---|---|
| Super+Left / Super+Right (or H / L) | Focus column left / right |
| Super+Up / Super+Down (or K / J) | Focus window up / down |
| Super+Home / Super+End | Focus first / last column |
| Super+Mouse wheel left / right | Focus column left / right |
| Super+Shift+Left / Super+Shift+Right (or H / L) | Move column left / right |
| Super+Shift+Up / Super+Shift+Down (or K / J) | Move window up / down |
| Super+Ctrl+Home / Super+Ctrl+End | Move column to first / last position |

## Monitors

| Key | Action |
|---|---|
| Super+Ctrl+Left / Right / Up / Down | Focus the monitor in that direction |
| Super+Ctrl+Shift+Left / Right / Up / Down | Move the column to the monitor in that direction |

## Workspaces

| Key | Action |
|---|---|
| Super+1 to Super+9 | Focus workspace 1 to 9 |
| Super+Ctrl+1 to Super+Ctrl+9 | Move column to workspace 1 to 9 |
| Super+Page Down / Super+Page Up | Focus workspace down / up |
| Super+Ctrl+Page Down / Super+Ctrl+Page Up | Move column to workspace down / up |
| Super+Mouse wheel down / up | Focus workspace down / up |
| Super+Ctrl+Mouse wheel down / up | Move column to workspace down / up |

## Apps

| Key | Action |
|---|---|
| Super+T or Super+Return | Terminal |
| Super+E | File manager (Nautilus) |
| Super+W | Browser |

## Media and hardware

| Key | Action |
|---|---|
| Volume up / down / mute keys | Volume, with the on-screen display |
| Mic mute key | Toggle microphone mute |
| Brightness up / down keys | Screen brightness |
| Play/Pause, Next, Previous keys | Media playback |
| Super+Ctrl+Space or Super+Shift+P | Play or pause |
| Super+Alt+N or Super+Shift+N | Next track |
| Super+Alt+P or Super+Shift+B | Previous track |
| Super+Shift+M | Toggle mute |

## Your own keybinds

Keybinds are set in Niri's config. Put your own binds in `~/.config/niri/config.d/90-user-extra.kdl`. iNiR leaves that file alone when it updates.

To use iNiR's own Alt+Tab switcher, pick it in Settings › Panels › Tools › Alt+Tab. Waffle has the same choice in Settings › Waffle Style › Alt+Tab Switcher.
