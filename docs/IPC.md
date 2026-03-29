# IPC Reference

iNiR exposes IPC targets you can call from Niri keybinds, scripts, or your terminal.

From terminal (for testing, or showing off):

```bash
inir <target> <function>
```

In Niri config (for actual keybinds):

```kdl
bind "Key" { spawn "inir" "<target>" "<function>"; }
```

For low-level debugging, `inir ipc <target> <function>` still works.

---

## Available Targets

Everything ii can do, exposed for your scripting pleasure.

### overview

Toggle the workspace overview panel. The one with all your windows looking tiny and organized.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overview |

```kdl
bind "Mod+Space" { spawn "inir" "overview" "toggle"; }
```

---

### overlay

The central overlay. Search, quick actions, widgets. The thing that pops up and makes you feel productive.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close overlay |

```kdl
bind "Super+G" { spawn "inir" "overlay" "toggle"; }
```

---

### clipboard

Clipboard history panel. Because Ctrl+V only remembers one thing, and that's not enough for power users.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close panel |
| `open` | Open panel |
| `close` | Close panel |

```kdl
bind "Super+V" { spawn "inir" "clipboard" "toggle"; }
```

---

### altSwitcher

Alt+Tab window switcher. Works across workspaces, unlike some other implementations we won't name.

| Function | Description |
|----------|-------------|
| `toggle` | Toggle switcher |
| `open` | Open switcher |
| `close` | Close switcher |
| `next` | Focus next window |
| `previous` | Focus previous window |

```kdl
bind "Alt+Tab" { spawn "inir" "altSwitcher" "next"; }
bind "Alt+Shift+Tab" { spawn "inir" "altSwitcher" "previous"; }
```

---

### region

Region selection tools. Screenshots, OCR, recording. Draw a box, get stuff done.

| Function | Description |
|----------|-------------|
| `screenshot` | Take a region screenshot |
| `search` | Image search (Google Lens) |
| `ocr` | OCR text recognition |
| `record` | Record region (no audio) |
| `recordWithSound` | Record region with audio |

```kdl
bind "Super+Shift+S" { spawn "inir" "region" "screenshot"; }
bind "Super+Shift+X" { spawn "inir" "region" "ocr"; }
bind "Super+Shift+A" { spawn "inir" "region" "search"; }
```

---

### voiceSearch

Voice search using Gemini API. Records from microphone, transcribes with Gemini, opens Google search.

| Function | Description |
|----------|-------------|
| `start` | Start recording |
| `stop` | Stop recording |
| `toggle` | Toggle recording |

```kdl
bind "Super+Shift+V" { spawn "inir" "voiceSearch" "toggle"; }
```

---

### session

Power menu. Logout, suspend, reboot, shutdown. The "I'm done for today" buttons.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close session menu |

```kdl
bind "Super+Shift+E" { spawn "inir" "session" "toggle"; }
```

---

### lock

Lock screen. For when you need to pretend you're working.

| Function | Description |
|----------|-------------|
| `activate` | Lock the screen |

```kdl
bind "Super+Alt+L" allow-when-locked=true { spawn "inir" "lock" "activate"; }
```

---

### cheatsheet

Keyboard shortcuts reference. For when you forget what you just configured five minutes ago.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close cheatsheet |

```kdl
bind "Super+Slash" { spawn "inir" "cheatsheet" "toggle"; }
```

---

### closeConfirm

Close window confirmation dialog. Shows a prompt before closing the focused window. Useful if you're the type who accidentally closes things and then regrets it.

| Function | Description |
|----------|-------------|
| `trigger` | Show close confirmation for focused window |
| `close` | Dismiss the dialog without closing |

```kdl
bind "Mod+Q" repeat=false { spawn "inir" "close-window"; }
```

By default, confirmation is disabled (closes immediately). Enable it in settings or config:

```json
"closeConfirm": {
  "enabled": true
}
```

---

### settings

Open the settings window. GUI config so you don't have to edit JSON like it's 2005.

| Function | Description |
|----------|-------------|
| `open` | Open settings window |

```kdl
bind "Super+Comma" { spawn "inir" "settings"; }
```

---

### sidebarLeft

Left sidebar (AI chat, apps).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close left sidebar |

---

### sidebarRight

Right sidebar (quick toggles, notepad, settings).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close right sidebar |

---

### bar

Top bar visibility.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide bar |

---

### globalActions

Command palette / action registry. Search and execute shell actions from scripts or keybinds.

| Function | Description |
|----------|-------------|
| `run <id> [args]` | Execute action by ID (e.g. `toggle-mute`, `install-package vim`) |
| `list [category]` | List all actions, optionally filtered by category |
| `search <query>` | Fuzzy search actions by name/description/keywords |
| `open` | Open the overview in action mode |

Categories: `system`, `appearance`, `tools`, `media`, `settings`, `custom`.

```kdl
bind "Super+Slash" { spawn "inir" "globalActions" "open"; }
bind "Super+M" { spawn "inir" "globalActions" "run" "toggle-mute"; }
```

---

### wallpaperSelector

Wallpaper picker grid.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close wallpaper selector |

```kdl
bind "Ctrl+Alt+T" { spawn "inir" "wallpaperSelector" "toggle"; }
```

---

### coverflowSelector

Wallpaper coverflow (3D card) picker.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close coverflow selector |
| `open` | Open coverflow selector |
| `close` | Close coverflow selector |

---

### mediaControls

Floating media controls panel.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close media controls |

---

### osk

On-screen keyboard.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide on-screen keyboard |

---

### audio

Volume and mute control.

| Function | Description |
|----------|-------------|
| `volumeUp` | Increase volume |
| `volumeDown` | Decrease volume |
| `mute` | Toggle speaker mute |
| `micMute` | Toggle microphone mute |

---

### zoom

Screen zoom. Accessibility feature, or for reading tiny text without squinting.

| Function | Description |
|----------|-------------|
| `zoomIn` | Increase zoom level |
| `zoomOut` | Decrease zoom level |

---

### brightness

Display brightness control.

| Function | Description |
|----------|-------------|
| `increment` | Increase brightness |
| `decrement` | Decrease brightness |

---

### mpris

Media player control. Automatically detects and uses YtMusic controls when active, otherwise uses the active MPRIS player.

| Function | Description |
|----------|-------------|
| `pauseAll` | Pause all players |
| `playPause` | Toggle play/pause (uses YtMusic if active) |
| `previous` | Previous track (uses YtMusic if active) |
| `next` | Next track (uses YtMusic if active) |

```kdl
bind "Ctrl+Mod+Space" { spawn "inir" "mpris" "playPause"; }
bind "Mod+Alt+N" { spawn "inir" "mpris" "next"; }
bind "Mod+Alt+P" { spawn "inir" "mpris" "previous"; }
```

---

### ytmusic

Direct YtMusic player control. Use these if you want to control YtMusic specifically, regardless of what other players are active.

| Function | Description |
|----------|-------------|
| `playPause` | Toggle YtMusic play/pause |
| `next` | Play next track in YtMusic |
| `previous` | Play previous track in YtMusic |
| `stop` | Stop YtMusic playback |

```kdl
bind "Mod+M+Space" { spawn "inir" "ytmusic" "playPause"; }
```

---

### osdVolume

On-screen volume indicator.

| Function | Description |
|----------|-------------|
| `trigger` | Show volume OSD |

---

### cliphistService

Clipboard history service. The backend that makes clipboard panel work. You probably don't need to call this directly.

| Function | Description |
|----------|-------------|
| `update` | Refresh clipboard history |

---

### gamemode

Performance mode for gaming. Auto-detects fullscreen apps and disables animations/effects. Can also be toggled manually for those stubborn games that don't go fullscreen properly.

| Function | Description |
|----------|-------------|
| `toggle` | Toggle gamemode on/off |
| `activate` | Force enable gamemode |
| `deactivate` | Force disable gamemode |
| `status` | Print current status to logs |

```kdl
bind "Super+F12" { spawn "inir" "gamemode" "toggle"; }
```

---

### panelFamily

Switch between panel styles. ii supports two visual styles: Material ii (default) and Waffle (Windows 11-like).

| Function | Description |
|----------|-------------|
| `cycle` | Cycle to next panel family (ii → waffle → ii) |
| `set` | Set specific family ("ii" or "waffle") |

```kdl
bind "Mod+Shift+W" { spawn "inir" "panelFamily" "cycle"; }
```

---

### notifications

Notification management.

| Function | Description |
|----------|-------------|
| `test` | Send test notifications |
| `clearAll` | Dismiss all notifications |
| `toggleSilent` | Toggle Do Not Disturb mode |

---

### minimize

Window minimization (Niri workaround - moves windows to hidden workspace).

| Function | Description |
|----------|-------------|
| `minimize` | Minimize focused window |
| `restore` | Restore a minimized window by ID |

---

## Waffle-Specific Targets

These targets only work when using the Waffle (Windows 11) panel style.

### search

Waffle start menu / search.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close start menu |
| `open` | Open start menu |
| `close` | Close start menu |

---

### wactionCenter

Waffle action center (quick settings).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close action center |

---

### wnotificationCenter

Waffle notification center.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close notification center |

---

### wwidgets

Waffle widgets panel.

| Function | Description |
|----------|-------------|
| `toggle` | Open/close widgets |
| `open` | Open widgets |
| `close` | Close widgets |

---

### wbar

Waffle taskbar visibility.

| Function | Description |
|----------|-------------|
| `toggle` | Show/hide taskbar |
| `open` | Show taskbar |
| `close` | Hide taskbar |

---

### taskview

Waffle task view (Win+Tab style).

| Function | Description |
|----------|-------------|
| `toggle` | Open/close task view |
